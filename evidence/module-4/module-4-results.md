# Module 4 — Complete Protocol Flow, Wireshark & Failure Demonstrations

## Scope

Module 4 covers the Phase 1 requirements for:

- Task G — Complete Protocol Flow Evidence
- Packet-level DNS, TCP and TLS observation
- Layer-by-layer protocol analysis
- Required failure demonstrations

The project flow is:

Client → Private DNS → nginx → Backend A / Backend B

---

## Task G — Complete Protocol Flow

### DNS Resolution

The client queries the private DNS server for:

`app.cnproject.test`

Observed DNS result:

`app.cnproject.test → 10.7.29.220`

The DNS exchange was captured using TShark on the loopback interface.

Observed packets:

1. DNS query for `A app.cnproject.test`
2. DNS response containing `A 10.7.29.220`

This confirms that the private DNS service resolves the project hostname to the nginx host address.

### TCP Connection

After DNS resolution, the client connects to nginx on TCP port 443.

The packet capture showed the TCP three-way handshake:

1. SYN
2. SYN, ACK
3. ACK

This establishes the TCP connection between the client and the HTTPS service.

### TLS Handshake

The HTTPS connection then performs a TLS handshake.

The capture showed:

- TLS Client Hello
- SNI: `app.cnproject.test`
- TLS 1.3 Server Hello
- Encrypted TLS application data

The presence of the hostname in the Client Hello confirms that the client requested the intended application domain.

### HTTPS Application Data

After the TLS handshake, application data was exchanged as encrypted TLS 1.3 Application Data.

The HTTP response was successfully received by the client:

```text
HTTP/1.1 200 OK
X-Backend: B
X-Cache-Status: MISS
Cache-Control: public, max-age=60

Backend B - CN Project