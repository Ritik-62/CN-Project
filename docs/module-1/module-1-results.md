# Module 1 — Results and Acceptance

## Implementation Status

Core network and private DNS implementation: PASS

## Network Baseline

- Active interface: en0 (Wi-Fi)
- IPv4 address: 10.7.29.220
- Subnet: 10.7.0.0/19
- Default gateway: 10.7.0.1
- Gateway connectivity: PASS

## DNS Service

- dnsmasq installed: PASS
- Configuration syntax validation: PASS
- dnsmasq service running: PASS
- DNS port 53 listening: PASS

## Private DNS

- app.cnproject.test -> 10.7.29.220: PASS
- api.cnproject.test -> 10.7.29.220: PASS
- Direct dnsmasq queries: PASS
- macOS scoped resolver: PASS
- Native macOS hostname resolution: PASS
- External DNS forwarding: PASS

## Final Verification

The macOS scoped resolver for cnproject.test uses 10.7.29.220.

Both private project hostnames resolve successfully to 10.7.29.220.

## Troubleshooting Evidence

An earlier plain dig query used the global DNS resolver and returned NXDOMAIN for the private hostname. This result is retained as troubleshooting evidence.

The macOS scoped resolver was subsequently verified using scutil and native hostname resolution using dscacheutil.

## Acceptance Checklist

- [x] Network interface identified
- [x] IPv4 address identified
- [x] Subnet identified
- [x] Default gateway identified
- [x] Gateway connectivity verified
- [x] dnsmasq installed
- [x] dnsmasq configuration validated
- [x] dnsmasq listening on port 53
- [x] Private DNS records created
- [x] Direct DNS queries verified
- [x] macOS scoped resolver configured
- [x] Native hostname resolution verified
- [x] DNS evidence collected
- [x] Single-Mac adaptation documented
- [ ] Final topology diagram

## Current Status

Module 1 implementation and verification are complete. The module is closed after the final topology diagram and documentation review are completed.
