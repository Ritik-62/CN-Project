# Module 1 — Single-Mac Adaptation

## Constraint

The original project design assumes multiple physical machines on a private LAN.

This implementation is being developed by a single developer using one physical Mac.

## Adaptation

The Mac acts as the current logical project host and service endpoint.

Current logical mapping:

MacBook Pro
10.7.29.220
|
+-- dnsmasq :53
|
+-- app.cnproject.test
|
+-- api.cnproject.test

Both project hostnames currently resolve to the same LAN address.

## Scope

This adaptation validates the DNS architecture, hostname resolution, service binding, and protocol workflow on one physical host.

It does not claim to reproduce the original requirement for multiple independent physical client machines.

If physical multi-host validation is required for grading, additional machines or isolated virtual machines can be introduced later.

## Rationale

The single-host design allows the project to establish and validate the required networking foundation before introducing backend services, nginx, TLS, caching, and packet-capture demonstrations.
