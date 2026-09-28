# Module 1 — DNS Configuration

## dnsmasq

The private DNS service is implemented using dnsmasq.

## Configuration

listen-address=10.7.29.220
bind-interfaces
address=/app.cnproject.test/10.7.29.220
address=/api.cnproject.test/10.7.29.220
server=8.8.8.8
no-resolv

## Service Binding

dnsmasq listens on 10.7.29.220:53 for DNS traffic.

## Private Records

app.cnproject.test -> 10.7.29.220
api.cnproject.test -> 10.7.29.220

## macOS Scoped Resolver

domain: cnproject.test
nameserver: 10.7.29.220

## Verification

Direct DNS queries returned NOERROR with authoritative answers from 10.7.29.220:53.

Native macOS hostname resolution returned:
app.cnproject.test -> 10.7.29.220
api.cnproject.test -> 10.7.29.220
