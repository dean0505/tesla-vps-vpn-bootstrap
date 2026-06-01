# Tesla VPS VPN Bootstrap

Bootstrap a small Ubuntu VPS as the network support box around Tesla Fleet
Telemetry: a private VPN path for admin access, mobile debugging, and TCP
fallback when WireGuard UDP does not reach the server.

The project installs and configures:

- WireGuard on a configurable UDP port
- OpenVPN on TCP 8443 as a fallback when UDP is blocked
- UFW firewall rules
- IPv4 forwarding and NAT
- systemd services for both VPNs
- generated client profiles under `/root/vpn-clients`

It is intentionally provider-neutral. It works well on lightweight VPS hosts
such as IONOS, Hetzner, DigitalOcean, Lightsail, and similar providers.

## Why This Exists

Tesla Fleet Telemetry deployments often end up on a small VPS with a public
HTTPS endpoint, firewall rules, systemd services, and private admin access.
When you are debugging from a phone, hotel Wi-Fi, airport Wi-Fi, or roaming
network, direct SSH or UDP VPN connectivity may fail for reasons outside the
telemetry service itself.

Some mobile networks, hotels, airports, and cloud firewalls block or mishandle
UDP. WireGuard is fast and simple, but when UDP traffic never reaches the VPS,
a TCP OpenVPN fallback is often the practical escape hatch.

This repository provides a repeatable, auditable setup instead of hand-editing
firewall, sysctl, and VPN configs during an outage.

Typical use cases:

- reach private Tesla telemetry dashboards or admin tools without exposing them
  publicly
- keep Tesla Fleet Telemetry on HTTPS while using WireGuard on UDP 443
- fall back to OpenVPN TCP 8443 when UDP packets never arrive
- verify whether the problem is the VPN client, cloud firewall, or network path

## Requirements

- Ubuntu 22.04 or 24.04
- root shell on a fresh or lightly used VPS
- a DNS name pointing to the VPS, or a public IPv4 address
- inbound firewall access from your cloud provider for:
  - `22/tcp` for SSH
  - `443/udp` or your chosen WireGuard UDP port
  - `8443/tcp` for OpenVPN fallback

## Quick Start

Clone this repo on the VPS, review the config, then run:

```bash
cp config.example.env config.env
$EDITOR config.env
./bootstrap.sh --dry-run --config config.env
sudo ./bootstrap.sh --config config.env
```

Client files are generated on the server:

```text
/root/vpn-clients/
  wireguard-client.conf
  openvpn-client.ovpn
```

Copy those files to your trusted device with `scp` or your password manager's
secure file transfer. Do not commit generated client profiles.

## Project Status

Current validation is tracked in [docs/validation](docs/validation).

The repository includes CI for shell syntax and accidental-secret checks. Full
install validation should be run on a disposable Ubuntu VPS because the
bootstrap modifies host networking, firewall, NAT, VPN services, and generated
client keys.

Use `--dry-run` before install to review package installs, firewall changes,
sysctl changes, NAT rules, generated file paths, and systemd service actions
without modifying the host.

## Example Config

```bash
VPN_HOST=vpn.example.com
WG_PORT=443
OVPN_PORT=8443
CLIENT_NAME=phone
```

`WG_PORT=443` means UDP 443, not TCP 443. It can coexist with a web service on
TCP 443 because TCP and UDP are separate protocols.

## Verification

On the VPS:

```bash
sudo systemctl status wg-quick@wg0
sudo systemctl status openvpn-server@fallback
sudo wg show
sudo ss -lntup | grep -E ':(443|8443)\b'
```

From a client network:

```bash
nc -vz vpn.example.com 8443
```

UDP reachability is harder to test with `nc`; the most reliable check is
`sudo tcpdump -ni any udp port 443` while toggling the WireGuard client.

## Security Notes

- Generated client configs contain private keys. Keep them out of Git.
- Run this on infrastructure you control.
- Review cloud-provider firewall rules as well as UFW.
- Prefer one client profile per device.
- Rotate client profiles if a device is lost.

See [docs/security.md](docs/security.md) for the full checklist.

## Non-Goals

- This is not an anonymity tool.
- This is not a managed VPN service.
- This does not bypass laws, terms of service, or network policies.
- This does not configure Tesla Fleet Telemetry itself, OAuth, vehicle keys, or
  the telemetry ingest service.

## License

MIT
