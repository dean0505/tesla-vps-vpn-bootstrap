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

## Revoking an OpenVPN Client

This bootstrap keeps the setup simple and does not enable a CRL by default.
For production multi-user use, add Easy-RSA certificate revocation and set
`crl-verify` in the OpenVPN server config.

For one-person emergency fallback use, rebuilding the OpenVPN profile and
removing the old client file is often simpler.
