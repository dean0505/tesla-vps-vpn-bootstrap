# Tesla Fleet Telemetry Layout

This project does not install Tesla Fleet Telemetry. It provides the private
network layer that is useful around a telemetry VPS.

One common layout:

```text
Internet
  |
  | 443/tcp
  v
Tesla Fleet Telemetry HTTPS endpoint

Admin device
  |
  | 443/udp, preferred
  v
WireGuard on wg0

Admin device
  |
  | 8443/tcp, fallback
  v
OpenVPN on tun0
```

Why this split works:

- TCP 443 can stay dedicated to the public telemetry HTTPS endpoint.
- UDP 443 can be used by WireGuard at the same time.
- TCP 8443 gives you a fallback when UDP never reaches the VPS.
- Private admin dashboards can bind to the VPN subnet instead of the public
  interface.

## Suggested Firewall Shape

Provider firewall:

- allow `22/tcp` from your admin IPs when possible
- allow `443/tcp` for Tesla Fleet Telemetry HTTPS
- allow the configured WireGuard UDP port
- allow the configured OpenVPN TCP fallback port

Host firewall:

- keep UFW enabled
- allow only the ports above
- route VPN traffic out through the public interface with NAT

## What To Keep Out Of Git

- Tesla vehicle identifiers
- OAuth client secrets
- Fleet Telemetry private keys
- VPN client profiles
- real production hostnames and IP addresses unless your project intentionally
  documents a public deployment
