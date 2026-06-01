# Security Checklist

Use this checklist before publishing, deploying, or sharing generated files.

## Before Publishing This Repository

- Confirm there are no generated `.conf`, `.ovpn`, `.key`, `.crt`, `.pem`, or
  `.zip` files in Git.
- Run `scripts/check-no-secrets.sh`.
- Keep `config.env` private. Publish only `config.example.env`.
- Do not commit real hostnames, VPS IP addresses, usernames, private keys, or
  client profiles.

## Before Running on a VPS

- Start from a fresh Ubuntu host when possible.
- Patch packages before exposing the server.
- Confirm the cloud firewall allows only the ports you need.
- Keep SSH key-based login enabled and disable password login if your provider
  supports it.
- Back up any existing firewall rules before running this on a shared host.

## After Setup

- Store generated client profiles in a password manager or another secure
  location.
- Delete local copies from insecure devices after importing.
- Create one profile per device so you can revoke only the lost device.
- Rotate client profiles after a device loss or suspected leak.
- Review `sudo wg show`, OpenVPN logs, and cloud bandwidth usage periodically.

## Revoking a WireGuard Client

Remove the matching `[Peer]` block from `/etc/wireguard/wg0.conf`, then run:

```bash
sudo systemctl restart wg-quick@wg0
```

Confirm the client public key is gone:

```bash
sudo wg show wg0 peers
```

If you created one profile per device, only the lost device needs to be removed.

## Revoking an OpenVPN Client

The OpenVPN setup uses Easy-RSA certificates. To revoke a client, generate a
certificate revocation list and make the server enforce it.

From the Easy-RSA directory:

```bash
cd /etc/openvpn/easy-rsa-fallback
sudo ./easyrsa --batch revoke phone
sudo ./easyrsa gen-crl
sudo install -m 0644 pki/crl.pem /etc/openvpn/server/crl.pem
```

Then add this line to `/etc/openvpn/server/fallback.conf` if it is not already
present:

```text
crl-verify crl.pem
```

Restart OpenVPN:

```bash
sudo systemctl restart openvpn-server@fallback
```

Verify the service is still healthy:

```bash
sudo systemctl status openvpn-server@fallback
sudo journalctl -u openvpn-server@fallback -n 100 --no-pager
```

Replace `phone` with the `CLIENT_NAME` used when the profile was generated. Keep
the CRL file readable by OpenVPN but do not commit it to Git.
