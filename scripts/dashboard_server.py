#!/usr/bin/env python3
"""
CN-Project Phase 2: Centralized Network Operations Dashboard
Lightweight, native Python server providing real-time infrastructure telemetry,
interactive service orchestration, and diagnostic metrics.
"""

import os
import sys
import json
import time
import socket
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 8000
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def check_socket(host, port, timeout=0.4):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect((host, port))
        s.close()
        return True
    except Exception:
        return False

def check_dns(host, port, domain="app.cnproject.test"):
    try:
        cmd = ["dig", f"@{host}", "-p", str(port), domain, "+short", "+time=1", "+tries=1"]
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=1.2).decode().strip()
        ans = [line for line in out.splitlines() if line and not line.startswith(";")]
        return bool(ans), ans[0] if ans else "No Answer"
    except Exception:
        return False, "Unreachable"

def get_pid(pidfile):
    if os.path.exists(pidfile):
        try:
            with open(pidfile) as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return pid
        except Exception:
            return None
    return None

def collect_telemetry():
    t_start = time.time()

    # 1. Machine 1: DNS
    primary_dns_sock = check_socket("127.0.0.1", 5355)
    primary_dns_ok, primary_dns_ans = check_dns("127.0.0.1", 5355)
    backup_dns_sock = check_socket("127.0.0.1", 5354)
    backup_dns_ok, backup_dns_ans = check_dns("127.0.0.1", 5354)
    cache_dns_sock = check_socket("127.0.0.1", 5356)
    cache_dns_ok, cache_dns_ans = check_dns("127.0.0.1", 5356)

    # 2. Machine 2: Main Edge
    main_edge_sock = check_socket("127.0.0.1", 8443)
    main_edge_pid = get_pid("/tmp/nginx-main.pid")

    # 3. Machine 3: Backend A
    backend_a_sock = check_socket("127.0.0.1", 3001)
    backend_a_pid = get_pid("/tmp/backend-a.pid")

    # 4. Machine 4: Backend B & Standby Edge
    backend_b_sock = check_socket("127.0.0.1", 3002)
    backend_b_pid = get_pid("/tmp/backend-b.pid")
    standby_edge_sock = check_socket("127.0.0.1", 9443)
    standby_edge_pid = get_pid("/tmp/nginx-standby.pid")

    # Authoritative records
    hosts_path = os.path.join(PROJECT_ROOT, "config/dnsmasq/records.hosts")
    records = []
    if os.path.exists(hosts_path):
        with open(hosts_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    records.append(line)

    dns_synced = (primary_dns_ans == backup_dns_ans) if (primary_dns_ok and backup_dns_ok) else False

    # Active edge detection
    active_edge = "Main (8443)" if "127.0.0.1" in primary_dns_ans else "Standby (9443)" if "127.0.0.2" in primary_dns_ans else "Custom"

    data = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "scan_duration_ms": round((time.time() - t_start) * 1000, 1),
        "topology": {
            "machine_1_dns": {
                "name": "Machine 1: DNS Subsystem",
                "primary_dns": {
                    "port": 5355,
                    "status": "UP" if primary_dns_ok else "DOWN",
                    "answer": primary_dns_ans,
                    "pid": get_pid("/tmp/dnsmasq-primary.pid")
                },
                "backup_dns": {
                    "port": 5354,
                    "status": "UP" if backup_dns_ok else "DOWN",
                    "answer": backup_dns_ans,
                    "pid": get_pid("/tmp/dnsmasq-backup.pid")
                },
                "caching_resolver": {
                    "port": 5356,
                    "status": "UP" if cache_dns_ok else "DOWN",
                    "answer": cache_dns_ans,
                    "pid": get_pid("/tmp/dnsmasq-cache.pid")
                },
                "synchronized": dns_synced
            },
            "machine_2_main_edge": {
                "name": "Machine 2: Main Edge Reverse Proxy",
                "port_https": 8443,
                "port_http": 8080,
                "status": "UP" if main_edge_sock else "DOWN",
                "pid": main_edge_pid,
                "tls": "TLSv1.2 / TLSv1.3 Active (Port 8443)"
            },
            "machine_3_backend_a": {
                "name": "Machine 3: Backend Server A",
                "port": 3001,
                "status": "UP" if backend_a_sock else "DOWN",
                "pid": backend_a_pid,
                "identity": "X-Backend: A"
            },
            "machine_4_backend_b_standby": {
                "name": "Machine 4: Backend B & Standby Edge",
                "backend_b": {
                    "port": 3002,
                    "status": "UP" if backend_b_sock else "DOWN",
                    "pid": backend_b_pid,
                    "identity": "X-Backend: B"
                },
                "standby_edge": {
                    "port_https": 9443,
                    "port_http": 9080,
                    "status": "UP" if standby_edge_sock else "DOWN",
                    "pid": standby_edge_pid,
                    "tls": "TLSv1.2 / TLSv1.3 Active (Port 9443)"
                }
            }
        },
        "routing": {
            "authoritative_records": records,
            "active_edge": active_edge,
            "dns_ttl": "30s"
        }
    }
    return data

DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CN-Project NOC Dashboard | Phase 2 Single Mac</title>
<style>
  :root {
    --bg: #0f172a; --panel: #1e293b; --border: #334155; --text: #f8fafc;
    --text-muted: #94a3b8; --accent: #38bdf8; --success: #22c55e;
    --danger: #ef4444; --warning: #f59e0b;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace; }
  body { background: var(--bg); color: var(--text); padding: 24px; }
  header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); padding-bottom: 16px; margin-bottom: 24px; }
  h1 { font-size: 22px; color: var(--accent); display: flex; align-items: center; gap: 10px; }
  .badge { padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: bold; }
  .badge-up { background: rgba(34, 197, 94, 0.2); color: var(--success); border: 1px solid var(--success); }
  .badge-down { background: rgba(239, 68, 68, 0.2); color: var(--danger); border: 1px solid var(--danger); }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 18px; margin-bottom: 24px; }
  .card { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 18px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3); }
  .card-title { font-size: 14px; text-transform: uppercase; color: var(--text-muted); font-weight: bold; margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; }
  .metric-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 13px; }
  .metric-row:last-child { border-bottom: none; }
  .val { font-weight: bold; }
  .controls { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 20px; }
  button { background: #2563eb; color: white; border: none; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 500; transition: background 0.2s; }
  button:hover { background: #1d4ed8; }
  button.danger { background: #dc2626; }
  button.danger:hover { background: #b91c1c; }
  button.warn { background: #d97706; }
  button.warn:hover { background: #b45309; }
  .log-console { background: #000; color: #a3e635; padding: 14px; border-radius: 8px; font-size: 12px; height: 180px; overflow-y: auto; font-family: monospace; border: 1px solid var(--border); margin-top: 14px; }
</style>
</head>
<body>
<header>
  <div>
    <h1><span>🛡️</span> CN-Project Phase 2 Network Operations Center</h1>
    <p style="color:var(--text-muted); font-size:13px; margin-top:4px;">Single-Mac 4-Machine Logical Simulation | Target: Apple Silicon MacBook</p>
  </div>
  <div style="text-align:right;">
    <div id="live-time" style="font-size:13px; font-weight:bold; color:var(--accent);">Loading...</div>
    <div style="font-size:11px; color:var(--text-muted);">Polling every 2s</div>
  </div>
</header>

<div class="grid">
  <!-- Machine 1: DNS -->
  <div class="card">
    <div class="card-title">Machine 1: DNS Subsystem <span id="m1-badge" class="badge badge-up">SCANNING</span></div>
    <div class="metric-row"><span>Primary DNS (:5355)</span><span id="dns-primary-val" class="val">-</span></div>
    <div class="metric-row"><span>Backup DNS (:5354)</span><span id="dns-backup-val" class="val">-</span></div>
    <div class="metric-row"><span>Caching Resolver (:5356)</span><span id="dns-cache-val" class="val">-</span></div>
    <div class="metric-row"><span>Sync Status</span><span id="dns-sync-val" class="val">-</span></div>
    <div class="metric-row"><span>Authoritative TTL</span><span class="val">30 seconds</span></div>
  </div>

  <!-- Machine 2: Main Edge -->
  <div class="card">
    <div class="card-title">Machine 2: Main Edge <span id="m2-badge" class="badge badge-up">SCANNING</span></div>
    <div class="metric-row"><span>HTTPS Reverse Proxy</span><span id="main-edge-status" class="val">-</span></div>
    <div class="metric-row"><span>Binding Sockets</span><span class="val">:8443 SSL / :8080 HTTP</span></div>
    <div class="metric-row"><span>TLS Termination</span><span class="val">app.cnproject.test</span></div>
    <div class="metric-row"><span>Passive Health Checks</span><span class="val">max_fails=1 fail_timeout=5s</span></div>
    <div class="metric-row"><span>Edge Header</span><span class="val" style="color:var(--accent);">X-Edge: Main</span></div>
  </div>

  <!-- Machine 3: Backend A -->
  <div class="card">
    <div class="card-title">Machine 3: Backend Server A <span id="m3-badge" class="badge badge-up">SCANNING</span></div>
    <div class="metric-row"><span>Service Port</span><span class="val">TCP 3001</span></div>
    <div class="metric-row"><span>Process Health</span><span id="backend-a-status" class="val">-</span></div>
    <div class="metric-row"><span>Upstream Identifier</span><span class="val">X-Backend: A</span></div>
    <div class="metric-row"><span>Isolation Policy</span><span class="val">Edge-Token Verified</span></div>
  </div>

  <!-- Machine 4: Backend B & Standby Edge -->
  <div class="card">
    <div class="card-title">Machine 4: Backend B & Standby <span id="m4-badge" class="badge badge-up">SCANNING</span></div>
    <div class="metric-row"><span>Backend B (:3002)</span><span id="backend-b-status" class="val">-</span></div>
    <div class="metric-row"><span>Standby Edge (:9443)</span><span id="standby-edge-status" class="val">-</span></div>
    <div class="metric-row"><span>Active Traffic Route</span><span id="active-edge-val" class="val" style="color:var(--accent);">-</span></div>
    <div class="metric-row"><span>Edge Header</span><span class="val" style="color:var(--accent);">X-Edge: Standby</span></div>
  </div>
</div>

<div class="card">
  <div class="card-title">Interactive Service Controls & Demonstrations</div>
  <div class="controls">
    <button onclick="runAction('test-dns-failover')">Run DNS Failover Test</button>
    <button onclick="runAction('test-dns-ttl')">Run DNS TTL Test</button>
    <button onclick="runAction('test-isolation')">Run Service Isolation Test</button>
    <button onclick="runAction('test-ha')">Run HA Failover Test</button>
    <button onclick="runAction('test-migration')">Run Edge Migration Test</button>
    <button class="warn" onclick="runAction('cutover-standby')">Cutover to Standby Edge</button>
    <button onclick="runAction('cutover-main')">Restore Main Edge</button>
    <button onclick="runAction('flush-cache')">Flush DNS Cache</button>
    <button class="danger" onclick="runAction('diagnose')">Run Diagnostic Engine</button>
    <button class="warn" onclick="runAction('recover-all')">Master Recover All</button>
  </div>
  <div class="log-console" id="log-box">[Console initialized. Ready for operations...]</div>
</div>

<script>
function log(msg) {
  const box = document.getElementById('log-box');
  const d = new Date().toLocaleTimeString();
  box.innerHTML += `\\n[${d}] ${msg}`;
  box.scrollTop = box.scrollHeight;
}

function updateBadge(id, status) {
  const el = document.getElementById(id);
  el.textContent = status;
  el.className = 'badge ' + (status === 'UP' ? 'badge-up' : 'badge-down');
}

async function fetchStatus() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();
    document.getElementById('live-time').textContent = data.timestamp;

    const t = data.topology;
    // M1
    updateBadge('m1-badge', t.machine_1_dns.primary_dns.status);
    document.getElementById('dns-primary-val').textContent = `${t.machine_1_dns.primary_dns.status} (${t.machine_1_dns.primary_dns.answer})`;
    document.getElementById('dns-backup-val').textContent = `${t.machine_1_dns.backup_dns.status} (${t.machine_1_dns.backup_dns.answer})`;
    document.getElementById('dns-cache-val').textContent = `${t.machine_1_dns.caching_resolver.status} (${t.machine_1_dns.caching_resolver.answer})`;
    document.getElementById('dns-sync-val').textContent = t.machine_1_dns.synchronized ? "SYNCHRONIZED (OK)" : "OUT OF SYNC";

    // M2
    updateBadge('m2-badge', t.machine_2_main_edge.status);
    document.getElementById('main-edge-status').textContent = t.machine_2_main_edge.status + ` (PID ${t.machine_2_main_edge.pid || 'N/A'})`;

    // M3
    updateBadge('m3-badge', t.machine_3_backend_a.status);
    document.getElementById('backend-a-status').textContent = t.machine_3_backend_a.status + ` (PID ${t.machine_3_backend_a.pid || 'N/A'})`;

    // M4
    updateBadge('m4-badge', t.machine_4_backend_b_standby.backend_b.status);
    document.getElementById('backend-b-status').textContent = t.machine_4_backend_b_standby.backend_b.status + ` (PID ${t.machine_4_backend_b_standby.backend_b.pid || 'N/A'})`;
    document.getElementById('standby-edge-status').textContent = t.machine_4_backend_b_standby.standby_edge.status + ` (PID ${t.machine_4_backend_b_standby.standby_edge.pid || 'N/A'})`;
    document.getElementById('active-edge-val').textContent = data.routing.active_edge;
  } catch (e) {
    console.error(e);
  }
}

async function runAction(act) {
  log(`Executing action: ${act}...`);
  try {
    const res = await fetch(`/api/action?cmd=${act}`);
    const j = await res.json();
    log(`Result (${act}): ${j.output || j.message}`);
    fetchStatus();
  } catch (e) {
    log(`Action ${act} failed: ${e}`);
  }
}

setInterval(fetchStatus, 2000);
fetchStatus();
</script>
</body>
</html>
"""

class DashboardHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/" or url.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(DASHBOARD_HTML.encode())

        elif url.path == "/api/status":
            data = collect_telemetry()
            body = json.dumps(data, indent=2).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        elif url.path == "/api/action":
            qs = parse_qs(url.query)
            cmd = qs.get("cmd", [""])[0]
            out = "Unknown command"

            if cmd == "test-dns-failover":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/test_dns_failover.sh")], timeout=30).decode()
            elif cmd == "test-dns-ttl":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/test_dns_ttl.sh")], timeout=55).decode()
            elif cmd == "test-isolation":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/test_service_isolation.sh")], timeout=30).decode()
            elif cmd == "test-ha":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/test_ha_failover.sh")], timeout=45).decode()
            elif cmd == "test-migration":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/test_edge_migration.sh")], timeout=30).decode()
            elif cmd == "cutover-standby":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/manage_dns.sh"), "set-record", "127.0.0.2"]).decode()
            elif cmd == "cutover-main":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/manage_dns.sh"), "reset-records"]).decode()
            elif cmd == "flush-cache":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/manage_dns.sh"), "flush-cache"]).decode()
            elif cmd == "diagnose":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/diagnose_stack.sh")], timeout=20).decode()
            elif cmd == "recover-all":
                out = subprocess.check_output([os.path.join(PROJECT_ROOT, "scripts/fault_manager.sh"), "recover-all"]).decode()

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "command": cmd, "output": out[-1000:] if len(out) > 1000 else out}).encode())

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # suppress default noisy stdout logging
        pass

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", PORT), DashboardHandler)
    print(f"CN-Project Phase 2 Dashboard listening at http://127.0.0.1:{PORT}/", flush=True)
    server.serve_forever()
