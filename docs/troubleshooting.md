# Troubleshooting

## WireGuard Connects but No Internet

Check forwarding and NAT:

```bash
sudo sysctl net.ipv4.ip_forward
sudo iptables -t nat -S POSTROUTING
sudo wg show
```

If the default interface was detected incorrectly, set `PUBLIC_INTERFACE` in
`config.env` and rerun the bootstrap.

## WireGuard Shows No Handshake

If `wg show` never shows a latest handshake, packets may not be reaching the
server.

On the VPS:

```bash
sudo tcpdump -ni any udp port 443
```

Toggle the client VPN. If packet count stays at zero:

- confirm the client endpoint host and port
- confirm your cloud firewall allows the UDP port
- try a different network
- use the OpenVPN TCP fallback profile

## OpenVPN TCP Does Not Connect

On the VPS:

```bash
sudo systemctl status openvpn-server@fallback
sudo ss -lntp | grep 8443
sudo journalctl -u openvpn-server@fallback -n 100 --no-pager
```

From the client network:

```bash
nc -vz vpn.example.com 8443
```

If TCP cannot connect, check your provider firewall before editing OpenVPN.

## TCP 443 Is Already Used

Do not move OpenVPN to TCP 443 if another service already uses it. TCP 443 and
UDP 443 can coexist, so a common layout is:

- existing HTTPS service: TCP 443
- WireGuard: UDP 443
- OpenVPN fallback: TCP 8443
