# Project Documentation Index

This directory contains the complete technical documentation for the Computer Networks project across Phase 1 and Phase 2.

All implementations run on **one physical Apple Silicon MacBook**, simulating four logical network nodes via isolated daemon processes and loopback socket bindings on `127.0.0.1`.

---

## Master Documentation Suite

| Document | Primary Focus | Target Audience |
| :--- | :--- | :--- |
| [`PHASE2_FINAL_REPORT.md`](PHASE2_FINAL_REPORT.md) | Master academic report covering all 10 required sections, Phase 1 vs Phase 2 comparative analysis, and operational findings. | Course Instructors & Academic Evaluators |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | End-to-end network topology, single-Mac simulation mappings, and Mermaid sequence diagrams for failover and DNS. | Network Architects & Systems Engineers |
| [`TESTING_AND_EVIDENCE.md`](TESTING_AND_EVIDENCE.md) | Step-by-step reproduction commands, verification outputs, and packet capture evidence for Extensions A through F. | Evaluators & QA Engineers |
| [`CONFIGURATION_GUIDE.md`](CONFIGURATION_GUIDE.md) | Exhaustive configuration guide covering ports, dnsmasq configs, nginx blocks, and environment secrets. | DevOps & Deployment Teams |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Systematic Layer 1–7 diagnostic hierarchy, root-cause decision tree, and automated recovery procedures. | Site Reliability Engineers & NOC Operators |
| [`VIVA_QUESTIONS.md`](VIVA_QUESTIONS.md) | 30 comprehensive viva voce examination questions and answers spanning DNS, TCP, TLS, and High Availability. | Oral Examination Preparation |
| [`FINAL_PRESENTATION.md`](FINAL_PRESENTATION.md) | 12-slide structured presentation outline for oral project defense and live demonstration. | Presentation & Demo Evaluators |
| [`PHASE1_BASELINE_README.md`](PHASE1_BASELINE_README.md) | Complete unedited original Phase 1 project narrative, module breakdowns, and initial request flow. | Baseline Reference & History |

---

## Detailed Phase 2 Engineering Specifications (`docs/phase-2/`)

For in-depth architectural and testing documentation for each individual Phase 2 extension:

- [`phase-2/phase-2-architecture.md`](phase-2/phase-2-architecture.md) — Unified Phase 2 architectural overview and single-Mac trade-offs.
- [`phase-2/backup-dns-architecture.md`](phase-2/backup-dns-architecture.md) & [`testing`](phase-2/backup-dns-testing.md) — Extension A: Redundant backup DNS resolver.
- [`phase-2/dns-ttl-architecture.md`](phase-2/dns-ttl-architecture.md) & [`testing`](phase-2/dns-ttl-testing.md) — Extension B: DNS 30-second TTL and caching forwarder.
- [`phase-2/service-isolation.md`](phase-2/service-isolation.md) — Extension C: Application-layer token service isolation.
- [`phase-2/high-availability-failover.md`](phase-2/high-availability-failover.md) — Extension D: Upstream passive health checks and passive failover routing.
- [`phase-2/edge-migration.md`](phase-2/edge-migration.md) — Extension E: Controlled standby edge cutover and rollback.
- [`phase-2/troubleshooting-guide.md`](phase-2/troubleshooting-guide.md) — Extension F: Diagnostic engine and fault manager details.
- [`phase-2/final-engineering-audit.md`](phase-2/final-engineering-audit.md) — Comprehensive engineering and security audit log.

---

## Phase 1 Module Documentation

- [`module-1/`](module-1/) — Network Foundation & Private DNS.
- [`module-2/module-2-results.md`](module-2/module-2-results.md) — Backend services and initial reverse proxy configuration.
- [`module-3/`](module-3/) — HTTPS, TLS termination, and proxy caching.
