# Importing Into OpenVPN Connect

1. Copy `/root/vpn-clients/openvpn-phone.ovpn` from the VPS to your device.
2. Open OpenVPN Connect.
3. Import the `.ovpn` profile without editing the port or hostname.
4. Connect.

If the profile name is not `phone`, use the filename generated from
`CLIENT_NAME` in `config.env`.

When debugging, check the server at the same time:

```bash
sudo journalctl -u openvpn-server@fallback -f
```

If no log lines appear when connecting, the TCP packets are not reaching the
server. Check the cloud-provider firewall first.
