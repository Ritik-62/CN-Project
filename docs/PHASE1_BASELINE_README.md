# Private Network Service Platform

## Computer Networks Course Project

> **The application stays simple. The network is the project.**

This project is a practical implementation of a small private network service platform.  
The main purpose of the project is not to build a complicated web application, but to understand what actually happens when a client opens a web service using a private domain name.

A simple request such as:

```text
https://app.cnproject.test/

looks very small from the user's point of view.

But internally, many networking steps take place:

Domain Name
     ↓
DNS Resolution
     ↓
TCP Connection
     ↓
TLS Handshake
     ↓
HTTPS Request
     ↓
nginx Reverse Proxy
     ↓
Load Balancing
     ↓
Backend Service
     ↓
HTTP Response

This project was built to configure, observe, capture and explain each of these stages.

1. Project Objective

The objective of this Computer Networks project is to build a small private service environment and understand the complete journey of a network request.

The project focuses on:

Private networking
Private DNS
TCP
HTTPS
TLS
Reverse proxying
Load balancing
HTTP caching
Packet analysis
Failure diagnosis

The important part of this project is not only that the service works.

The important part is being able to answer:

How does the client find the server?
Which DNS server answers the request?
Which IP address is returned?
How is the TCP connection established?
What happens during the TLS handshake?
Where is HTTPS terminated?
How does nginx decide which backend receives the request?
How can we identify Backend A and Backend B?
What happens when one backend fails?
What happens when both backends fail?
What happens when DNS is wrong?
How can packet captures prove that the network is working?

This project was developed with these questions in mind.

2. Original Project Requirement

The course project describes a private network environment in which a client should be able to:

Use a private domain name.
Resolve that domain through a private DNS server.
Establish an HTTPS connection.
Reach an nginx reverse proxy/load balancer.
Receive a response from one of two backend services.
Observe the request at packet level.
Demonstrate caching.
Diagnose selected network failures.

The original recommended architecture uses multiple Macs with different roles.

For this implementation, the same networking concepts were reproduced on a single Apple Silicon Mac using separate local services and ports.

This was done so that the complete Phase 1 networking flow could be built and observed without requiring multiple physical machines.

3. Project Architecture

The logical architecture of this project is:

                         CLIENT
                    curl / Browser
                           |
                           |
                     DNS Query
                           |
                           v
                +----------------------+
                |     Private DNS      |
                |       dnsmasq        |
                |        Port 53       |
                +----------+-----------+
                           |
                           |
              app.cnproject.test
                           |
                           v
                +----------------------+
                |        nginx         |
                | Reverse Proxy / LB   |
                |      HTTPS :443      |
                |      HTTP Cache      |
                +----------+-----------+
                           |
                  +--------+--------+
                  |                 |
                  v                 v
          +---------------+  +---------------+
          |   Backend A   |  |   Backend B   |
          |    :3001      |  |    :3002      |
          |    Python     |  |    Python     |
          +---------------+  +---------------+

The complete request path is:

Client
  ↓
Private DNS
  ↓
nginx
  ↓
Backend A / Backend B
  ↓
Response
4. Single-Mac Adaptation

The original project recommends a multi-machine setup:

Mac 1 → DNS
Mac 2 → nginx / Edge
Mac 3 → Backend A
Mac 4 → Backend B

For this implementation, these roles were logically reproduced on one Mac:

Single Mac
│
├── dnsmasq
│   └── Private DNS :53
│
├── nginx
│   └── HTTPS / Reverse Proxy / Load Balancer :443
│
├── Backend A
│   └── HTTP :3001
│
└── Backend B
    └── HTTP :3002

This keeps the networking concepts separate while allowing the complete request flow to be demonstrated locally.

The backend applications were intentionally kept simple because the course project evaluates the network more than application complexity.

5. Environment Used
Component	Details
Operating System	macOS 15.6.1
Architecture	Apple Silicon / arm64
Network Interface	Wi-Fi (en0)
Private IPv4	10.7.29.220
Subnet Mask	255.255.224.0
Prefix	/19
Default Gateway	10.7.0.1
Private DNS	dnsmasq
Reverse Proxy	nginx
Backend A	Python HTTP server
Backend B	Python HTTP server
Backend A Port	3001
Backend B Port	3002
HTTPS Port	443
Packet Analysis	TShark / Wireshark
Private Domain	cnproject.test

The IP address above belongs to the local network used during development and testing.

6. Why the .test Domain Was Used

The project requires a private domain under the reserved .test namespace.

The following project domains were created:

app.cnproject.test
api.cnproject.test

The .local namespace was intentionally not used because macOS uses .local for mDNS-related functionality.

Using .test keeps the project namespace clearly separated from normal public DNS.

7. Module 1 — Network Foundation and Private DNS

The first part of the project was to establish the network foundation and private DNS.

Network Baseline

The local machine was checked for:

IPv4 address
subnet mask
gateway
active interface
connectivity

The active Wi-Fi interface was:

en0

The private IPv4 address used during the project was:

10.7.29.220

The subnet was:

255.255.224.0

which corresponds to:

/19

The default gateway was:

10.7.0.1

Basic connectivity was also tested before moving to higher-level services.

8. Private DNS with dnsmasq

A local DNS service was created using dnsmasq.

The project DNS records are:

app.cnproject.test  → 10.7.29.220
api.cnproject.test  → 10.7.29.220

This means the client does not need to directly type the IP address.

Instead of:

https://10.7.29.220/

the intended access method is:

https://app.cnproject.test/

This is important because DNS and the actual network connection are two different steps.

DNS answers:

"Where is this service?"

TCP/HTTPS then answers:

"Can I connect to that service?"
DNS Verification

The private DNS server can be tested using:

dig @10.7.29.220 app.cnproject.test +noall +answer

The expected answer is:

app.cnproject.test.    A    10.7.29.220

The DNS service was also tested using macOS hostname-resolution tools.

9. DNS Packet Evidence

DNS was not only tested from the command line.

It was also captured at packet level using TShark.

The saved capture is:

evidence/module-4/dns-capture.pcapng

The capture contains two important packets:

Packet 1
DNS Query
A app.cnproject.test

followed by:

Packet 2
DNS Response
A app.cnproject.test → 10.7.29.220

The saved capture can be inspected using:

tshark -r evidence/module-4/dns-capture.pcapng

This gives packet-level proof that the DNS request and response actually occurred.

10. Module 2 — Backend Services

Two simple backend services were created.

The backend applications are intentionally small.

Their job is simply to provide a visible response so that nginx load balancing can be observed.

Backend A

Backend A runs on:

Port: 3001

The root endpoint is:

GET /

Example response:

Backend A - CN Project

The status endpoint is:

GET /api/status

Example JSON response:

{
  "backend": "A",
  "status": "ok"
}

Backend A also returns:

X-Backend: A

This header makes it easy to identify which backend served the request.

Backend B

Backend B runs on:

Port: 3002

The root endpoint is:

GET /

Example response:

Backend B - CN Project

The status endpoint is:

GET /api/status

Example JSON response:

{
  "backend": "B",
  "status": "ok"
}

Backend B also returns:

X-Backend: B
11. Why the Backends Are Simple

The backend application is not the main focus of this project.

A complicated application would add unnecessary complexity.

Instead, the backends were kept small so that the network behavior is easy to observe.

The important questions are:

Can nginx reach Backend A?
Can nginx reach Backend B?
Can nginx distribute requests?
What happens when Backend A stops?
What happens when both backends stop?

This keeps the project focused on Computer Networks concepts.

12. Module 2 — nginx Reverse Proxy and Load Balancer

nginx acts as the edge service.

The client does not directly communicate with Backend A or Backend B.

Instead:

Client
   |
   | HTTPS
   v
nginx :443
   |
   +----------> Backend A :3001
   |
   +----------> Backend B :3002

This makes nginx the single entry point for the application.

The client only needs to know:

app.cnproject.test

It does not need to know which backend is currently handling the request.

13. Load Balancing

Both backend services are configured as nginx upstream servers.

The project uses nginx's normal round-robin behavior.

Repeated requests can therefore be served by different backends.

For example:

Request 1 → X-Backend: A
Request 2 → X-Backend: B
Request 3 → X-Backend: A
Request 4 → X-Backend: B

The X-Backend header provides visible evidence of this behavior.

This demonstrates the basic purpose of a load balancer:

The client sees one service, while the edge decides which backend handles the request.

14. Module 3 — HTTPS and TLS

HTTPS was configured at the nginx layer.

The HTTPS service listens on:

TCP 443

The TLS certificate was generated for:

app.cnproject.test
api.cnproject.test

The certificate contains Subject Alternative Names (SANs) for the project domains.

The certificate was added to the macOS trust store.

Therefore the final HTTPS request can be performed normally without bypassing certificate verification.

Example:

curl -i https://app.cnproject.test/

The final demonstration does not depend on:

curl -k

because certificate trust was configured properly.

15. Understanding the TLS Handshake

The HTTPS connection can be understood as:

Client                         nginx
  |                              |
  |------ ClientHello ---------->|
  |                              |
  |<----- ServerHello -----------|
  |<----- Certificate -----------|
  |                              |
  |<----- TLS negotiation -------|
  |                              |
  |==== Encrypted Data =========>|
  |<=== Encrypted Data ==========|

The packet capture shows:

TLS Client Hello
Server Hello
TLS 1.3 traffic
Encrypted application data

The Client Hello contains:

SNI = app.cnproject.test

This confirms that the client requested the expected hostname during TLS negotiation.

16. HTTPS Packet Capture

The actual HTTPS packet capture is stored here:

evidence/module-4/https-flow-capture.pcapng

The capture contains 26 packets.

Important parts include:

TCP Three-Way Handshake

Packets 1–3:

SYN
SYN/ACK
ACK

This establishes the TCP connection.

TLS Client Hello

Packet 5:

TLS Client Hello
SNI = app.cnproject.test
TLS Server Hello

Packet 7:

TLS 1.3 Server Hello
Encrypted Application Data

The following TLS packets contain encrypted application data.

TCP Connection Termination

The end of the capture contains:

FIN/ACK
ACK
FIN/ACK
ACK

The saved capture can be inspected using:

tshark -r evidence/module-4/https-flow-capture.pcapng

It can also be opened directly in Wireshark.

17. TCP Three-Way Handshake

The HTTPS capture provides a direct example of the TCP three-way handshake.

Conceptually:

Client                         Server
  |                              |
  |---------- SYN -------------->|
  |<--------- SYN/ACK -----------|
  |---------- ACK -------------->|
  |                              |
  |       Connection Ready       |

The capture also shows the port numbers.

For example:

49977 → 443
443 → 49977

Here:

49977 is the client's ephemeral source port.
443 is the HTTPS service port.

This connects the packet capture to the transport-layer concepts covered in the course.

18. HTTP Caching

HTTP caching was implemented through nginx.

The response contains:

Cache-Control: public, max-age=60

The nginx response also exposes:

X-Cache-Status

During testing, cache states such as:

EXPIRED

and:

HIT

were observed.

The basic behavior is:

First Request
     |
     v
nginx
     |
     v
Backend
     |
     v
Response stored in cache

A repeated request can then become:

Client
  |
  v
nginx
  |
  | Cache HIT
  v
Cached Response

This demonstrates why HTTP caching can reduce repeated backend requests.

Cache evidence is stored in:

evidence/module-3/cache-verification.txt
19. Complete Protocol Flow

One of the main goals of the project was to understand one request from beginning to end.

The complete flow is:

1. DNS
   Client asks:
   "What IP belongs to app.cnproject.test?"

              ↓

2. DNS Response
   10.7.29.220

              ↓

3. TCP
   Client connects to port 443

              ↓

4. TCP Three-Way Handshake
   SYN
   SYN/ACK
   ACK

              ↓

5. TLS
   ClientHello
   ServerHello
   Certificate / TLS negotiation

              ↓

6. HTTPS
   Encrypted application data

              ↓

7. nginx
   Receives HTTPS request

              ↓

8. Load Balancing
   nginx selects Backend A or Backend B

              ↓

9. Backend
   Generates HTTP response

              ↓

10. nginx
    Returns response to client

              ↓

11. TCP Connection
    FIN/ACK termination

This is the central networking flow demonstrated by the project.

20. Failure Demonstrations

The project also includes controlled failures.

The reason for doing this was to learn how to identify the affected layer rather than simply restarting everything.

20.1 Wrong DNS Server

The private domain was queried using public DNS:

8.8.8.8

The result was:

NXDOMAIN

This happened because the public DNS server does not know about the private project domain.

Evidence:

evidence/module-4/wrong-dns-server.txt
20.2 Wrong DNS Record

The private DNS server was queried for:

wrong.cnproject.test

The result was:

NXDOMAIN

The DNS server was reachable, but the requested record did not exist.

Evidence:

evidence/module-4/wrong-dns-record.txt
20.3 Backend A Failure

Backend A was stopped while Backend B remained running.

The nginx HTTPS endpoint continued to respond through Backend B.

Observed:

HTTP/1.1 200 OK
X-Backend: B

This demonstrates that the edge can continue serving through the remaining backend.

Evidence:

evidence/module-4/backend-a-failure.txt
20.4 Both Backends Failure

Both backends were stopped while nginx remained running.

The client could still reach nginx, but nginx had no available upstream backend.

The response was:

HTTP/1.1 502 Bad Gateway

This is useful because it shows that:

nginx is reachable

does not necessarily mean:

backend service is healthy

Evidence:

evidence/module-4/both-backends-failure.txt
20.5 Wrong Destination Port

The client attempted to connect to:

8444

instead of:

443

The connection failed because no service was listening on that destination port.

Evidence:

evidence/module-4/wrong-destination-port.txt
21. Layer-by-Layer Troubleshooting

The failures helped establish a systematic troubleshooting method.

When the application does not work, the following order can be followed:

DNS
 ↓
TCP
 ↓
TLS
 ↓
nginx
 ↓
Backend
 ↓
HTTP

For example:

Symptom	First Layer to Check
Domain does not resolve	DNS
Wrong IP returned	DNS
Connection refused / timeout on a port	TCP / Service Port
Certificate problem	TLS
nginx returns 502	Backend / Upstream
Wrong backend response	nginx / Load Balancing
Cache behavior unexpected	HTTP / nginx cache

This is more useful than randomly changing configuration because each layer can be tested independently.

22. Tools Used

The following tools were used during the project:

Tool	Purpose
macOS networking tools	Network/interface inspection
ping	Basic connectivity testing
dig	DNS testing
dscacheutil	macOS DNS/hostname verification
scutil	macOS DNS configuration inspection
dnsmasq	Private DNS
Python	Simple backend services
nginx	Reverse proxy and load balancer
OpenSSL	TLS certificate generation
curl	HTTP/HTTPS testing
TShark	Packet capture and analysis
Wireshark	Packet-level inspection
Git	Version control
GitHub	Project repository and evidence storage
23. Repository Structure

The project is organized so that source code, documentation and evidence are easy to find.

CN-Project/
│
├── backend-a/
│   └── server.py
│
├── backend-b/
│   └── server.py
│
├── docs/
│   ├── module-1/
│   ├── module-2/
│   ├── module-3/
│   └── module-4/
│
├── evidence/
│   ├── module-3/
│   │   ├── cache-verification.txt
│   │   └── tls-verification.txt
│   │
│   └── module-4/
│       ├── backend-a-failure.txt
│       ├── both-backends-failure.txt
│       ├── dns-capture.pcapng
│       ├── https-flow-capture.pcapng
│       ├── wrong-destination-port.txt
│       ├── wrong-dns-record.txt
│       └── wrong-dns-server.txt
│
└── README.md

The structure is intentionally simple so that an evaluator can find the required evidence quickly.

24. Important Evidence Files

The most important evidence collected during Phase 1 is:

DNS
evidence/module-4/dns-capture.pcapng

Shows:

DNS Query
    ↓
DNS Response
    ↓
app.cnproject.test → 10.7.29.220
HTTPS / TCP / TLS
evidence/module-4/https-flow-capture.pcapng

Shows:

TCP SYN
TCP SYN/ACK
TCP ACK
     ↓
TLS Client Hello
     ↓
TLS Server Hello
     ↓
TLS Application Data
     ↓
TCP FIN/ACK
Cache
evidence/module-3/cache-verification.txt

Shows cache behavior including:

X-Cache-Status
Cache-Control
HIT / EXPIRED
TLS Verification
evidence/module-3/tls-verification.txt

Contains HTTPS/certificate verification evidence.

Failure Evidence
evidence/module-4/wrong-dns-server.txt
evidence/module-4/wrong-dns-record.txt
evidence/module-4/backend-a-failure.txt
evidence/module-4/both-backends-failure.txt
evidence/module-4/wrong-destination-port.txt
25. Useful Commands
Check Private DNS
dig @10.7.29.220 app.cnproject.test +noall +answer
Test Backend A Directly
curl -i http://127.0.0.1:3001/
Test Backend B Directly
curl -i http://127.0.0.1:3002/
Test Backend Status Through nginx
curl -i https://app.cnproject.test/api/status
Test HTTPS
curl -i https://app.cnproject.test/
Test nginx Configuration
nginx -t
Check Listening Ports
sudo lsof -nP -iTCP:53 -iTCP:3001 -iTCP:3002 -iTCP:443 -sTCP:LISTEN
Read DNS Packet Capture
tshark -r evidence/module-4/dns-capture.pcapng
Read HTTPS Packet Capture
tshark -r evidence/module-4/https-flow-capture.pcapng
26. Phase 1 Task Mapping

The implementation maps to the required Phase 1 tasks as follows:

Task	Implementation in this project	Evidence
Task A — Establish Private LAN	Network interface, IP, subnet, gateway and connectivity verification	Module 1 documentation
Task B — Private DNS	dnsmasq and .test DNS records	DNS commands + DNS packet capture
Task C — Backend Services	Backend A on 3001, Backend B on 3002	Backend responses and source code
Task D — Reverse Proxy / Load Balancer	nginx with two upstream backends	X-Backend: A/B
Task E — HTTPS / TLS	nginx TLS termination on 443	Certificate verification + HTTPS capture
Task F — HTTP Caching	nginx cache + Cache-Control	Cache verification
Task G — Complete Protocol Flow	DNS, TCP, TLS and HTTPS packet evidence	Saved .pcapng captures
27. Phase 1 Completion Status
Network Foundation
 Private network baseline
 IPv4 address identified
 Subnet identified
 Gateway identified
 Active interface identified
 Connectivity checked
Private DNS
 dnsmasq configured
 .test namespace used
 app.cnproject.test configured
 api.cnproject.test configured
 DNS resolution verified
 DNS packet capture saved
Backend Services
 Backend A created
 Backend B created
 Port 3001 used for Backend A
 Port 3002 used for Backend B
 / endpoint implemented
 /api/status implemented
 X-Backend header added
nginx
 Reverse proxy configured
 Upstream backends configured
 Load balancing verified
 HTTPS entry point configured
 HTTP caching configured
HTTPS / TLS
 TLS certificate generated
 SAN configured
 nginx TLS termination configured
 Certificate trusted on macOS
 HTTPS tested without -k
 TLS traffic captured
HTTP Caching
 Cache-Control header
 max-age=60
 nginx cache
 Cache status observed
 Cache evidence saved
Packet Analysis
 DNS query captured
 DNS response captured
 TCP SYN captured
 TCP SYN/ACK captured
 TCP ACK captured
 TLS Client Hello captured
 TLS Server Hello captured
 TLS encrypted application data captured
 TCP termination captured
 DNS .pcapng saved
 HTTPS .pcapng saved
Failure Demonstrations
 Wrong DNS server
 Wrong DNS record
 Backend A failure
 Both backends failure
 Wrong destination port
28. GitHub Repository

The complete project, documentation and packet evidence are maintained in Git.

Repository:

Ritik-62/CN-Project

The repository contains:

Backend source code
Module documentation
Configuration-related documentation
Failure evidence
DNS packet capture
HTTPS/TLS packet capture
Cache evidence
This README

The working tree was kept clean after the evidence commits, and the packet captures were pushed to the repository so that the evidence is not limited to the local machine.

29. What I Learned From This Project

The most useful part of this project was understanding that a web request is actually a chain of networking events.

Before this project, it is easy to think of a request as:

curl → server → response

After observing the packets and configuring the services, the same request can be understood as:

DNS
 ↓
IP address
 ↓
TCP connection
 ↓
TLS handshake
 ↓
HTTPS
 ↓
nginx
 ↓
Load balancing
 ↓
Backend
 ↓
Response
 ↓
Caching

The packet captures made this especially clear.

For example, the HTTPS capture shows the TCP handshake before TLS starts. Then the TLS Client Hello appears, followed by the TLS Server Hello and encrypted application data.

The failure demonstrations were also important.

A wrong DNS server produces an NXDOMAIN.

A wrong destination port produces a connection failure.

Stopping one backend still allows nginx to serve through the other backend.

Stopping both backends results in a 502 Bad Gateway.

These are different symptoms because they happen at different parts of the system.

This helped me understand why network troubleshooting should be systematic rather than based on guessing.

30. Current Scope

This repository currently represents the Phase 1 — Build and Observe part of the course project.

The completed Phase 1 work covers:

Private Network
     ↓
Private DNS
     ↓
Backend Services
     ↓
nginx Reverse Proxy
     ↓
Load Balancing
     ↓
HTTPS / TLS
     ↓
HTTP Caching
     ↓
Packet Analysis
     ↓
Failure Demonstrations

The course specification defines Phase 2 as a separate extension focused on resilience and recovery.

Possible Phase 2 extensions include:

Backup DNS
DNS TTL behavior
Service isolation
Backend firewall rules
High-availability nginx failover
DNS-based edge migration
Faculty-injected troubleshooting challenge

These are future extensions of the current Phase 1 infrastructure and are not claimed as completed here.

31. Final Project Summary

At the end of Phase 1, the complete local service can be represented as:

                         CLIENT
                           |
                           |
                    app.cnproject.test
                           |
                           v
                  +-------------------+
                  |   Private DNS     |
                  |     dnsmasq       |
                  |      :53          |
                  +---------+---------+
                            |
                            |
                            v
                  +-------------------+
                  |      nginx        |
                  |      :443         |
                  |                   |
                  | TLS Termination   |
                  | Reverse Proxy     |
                  | Load Balancer     |
                  | HTTP Cache        |
                  +---------+---------+
                            |
                   +--------+--------+
                   |                 |
                   v                 v
            +-------------+   +-------------+
            |  Backend A  |   |  Backend B  |
            |    :3001    |   |    :3002    |
            +-------------+   +-------------+
                   |                 |
                   +--------+--------+
                            |
                            v
                         Response
                            |
                            v
                          CLIENT

The main outcome of the project is not simply a working webpage.

It is the ability to explain the complete journey of a request and support that explanation with actual configuration, command output, HTTP headers, failure tests and packet captures.

32. Final Takeaway

A user may only see:

https://app.cnproject.test/

But the network sees much more:

DNS Query
    ↓
DNS Response
    ↓
TCP SYN
    ↓
TCP SYN/ACK
    ↓
TCP ACK
    ↓
TLS Client Hello
    ↓
TLS Server Hello
    ↓
Encrypted Application Data
    ↓
nginx
    ↓
Backend A / Backend B
    ↓
HTTP Response
    ↓
Cache
    ↓
TCP Connection Termination

That complete journey is what this project was built to understand.

The application is simple by design. The network is the actual project.

Author

Ritik Raj

Computer Networks Course Project

Repository: Ritik-62/CN-Project