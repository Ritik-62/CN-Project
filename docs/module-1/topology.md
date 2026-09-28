# Module 1 — Network and DNS Topology

Private LAN: 10.7.0.0/19

MacBook Pro — 10.7.29.220 — en0 (Wi-Fi)
    |
    +-- dnsmasq :53
    |      |
    |      +-- app.cnproject.test -> 10.7.29.220
    |      +-- api.cnproject.test -> 10.7.29.220
    |
    +-- macOS scoped resolver: cnproject.test -> 10.7.29.220
    |
    +-- Default gateway: 10.7.0.1

External DNS forwarding: 8.8.8.8

Single-Mac adaptation: one physical Mac is used to represent the logical project host and DNS service.
