# Module 1 — Private DNS Design

## Private Namespace

Domain: cnproject.test

The `.test` namespace is used for the private project environment.

## DNS Records

| Hostname | Type | Address | Purpose |
|---|---|---|---|
| app.cnproject.test | A | 10.7.29.220 | Application entry point |
| api.cnproject.test | A | 10.7.29.220 | API entry point |

## DNS Server

DNS server: 10.7.29.220

Protocol: DNS over UDP/TCP port 53.

## Forwarding

Queries outside the private cnproject.test namespace are forwarded to 8.8.8.8.

## Resolver Integration

macOS uses a scoped resolver for cnproject.test.

Nameserver: 10.7.29.220
