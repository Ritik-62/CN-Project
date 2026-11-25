# Phase 1 Baseline Checkpoint

- **Branch**: `phase2-single-mac`
- **Backup Branch**: `phase1-backup`
- **Commit Checkpoint**: `560da04` ("Add comprehensive project README")
- **Timestamp**: 2026-11-25T19:01:00+05:30
- **Hardware Target**: 1 Physical Apple Silicon MacBook Pro

## Preserved Phase 1 Components

1. **Backend A**:
   - Path: `backends/backend-a/server.py`
   - Port: `3001`
   - Identifier: `X-Backend: A`
   - Status: Untouched and syntax verified

2. **Backend B**:
   - Path: `backends/backend-b/server.py`
   - Port: `3002`
   - Identifier: `X-Backend: B`
   - Status: Untouched and syntax verified

3. **Certificates & Keys**:
   - Custom CA: `config/nginx/certs/cnproject-ca.crt` (private key ignored by git)
   - Edge SAN Cert: `config/nginx/certs/app.cnproject.test.crt`
   - Domain: `app.cnproject.test`, `api.cnproject.test`

4. **Phase 1 Evidence**:
   - `evidence/module-3/` (TLS and cache verification)
   - `evidence/module-4/` (DNS and HTTPS flow pcapng captures and failure logs)
