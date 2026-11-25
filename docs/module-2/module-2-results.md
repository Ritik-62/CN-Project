# Module 2 — Backend Services & Reverse Proxy Load Balancing

## Scope
Module 2 covers the Phase 1 build tasks for:
- Task C: Backend Services (Backend A on port 3001, Backend B on port 3002)
- Task D: Edge Reverse Proxy and Load Balancer (nginx upstream round-robin)

---

## 1. Backend Services Architecture
Two independent HTTP REST backend services were built using Python's standard library:

1. **Backend A**:
   - Location: `backends/backend-a/server.py`
   - Port: `3001`
   - Custom Header: `X-Backend: A`
   - Endpoints: `GET /` (Plaintext), `GET /api/status` (JSON), `GET /health`

2. **Backend B**:
   - Location: `backends/backend-b/server.py`
   - Port: `3002`
   - Custom Header: `X-Backend: B`
   - Endpoints: `GET /` (Plaintext), `GET /api/status` (JSON), `GET /health`

---

## 2. nginx Load Balancing
nginx proxies incoming requests across both upstream backends in round-robin sequence:

```nginx
upstream cnproject_backends {
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
}
```

Repeated requests alternate responses between `X-Backend: A` and `X-Backend: B`.

## Verification Status
- Backend A: **PASS**
- Backend B: **PASS**
- nginx Load Balancing: **PASS**
