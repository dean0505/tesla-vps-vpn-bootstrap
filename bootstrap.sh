#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.env"

usage() {
  cat <<'USAGE'
Usage:
  sudo ./bootstrap.sh [--config config.env]

Creates WireGuard plus OpenVPN TCP fallback on Ubuntu.
Generated client profiles are written to /root/vpn-clients.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./bootstrap.sh" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "Config file not found: ${CONFIG_FILE}" >&2
  echo "Copy config.example.env to config.env first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

: "${VPN_HOST:?Set VPN_HOST in ${CONFIG_FILE}}"
: "${WG_PORT:=443}"
: "${OVPN_PORT:=8443}"
: "${WG_SUBNET:=10.66.0.0/24}"
: "${WG_SERVER_IP:=10.66.0.1/24}"
: "${WG_CLIENT_IP:=10.66.0.2/32}"
: "${OVPN_SUBNET:=10.77.0.0}"
: "${OVPN_NETMASK:=255.255.255.0}"
: "${OVPN_CIDR:=10.77.0.0/24}"
: "${CLIENT_NAME:=phone}"
: "${PUBLIC_INTERFACE:=}"

if [[ -z "${PUBLIC_INTERFACE}" ]]; then
  PUBLIC_INTERFACE="$(ip route show default | awk '{print $5; exit}')"
fi

if [[ -z "${PUBLIC_INTERFACE}" ]]; then
  echo "Could not detect public interface. Set PUBLIC_INTERFACE in ${CONFIG_FILE}." >&2
  exit 1
fi

CLIENT_DIR="/root/vpn-clients"
WG_DIR="/etc/wireguard"
OVPN_DIR="/etc/openvpn/server"
EASYRSA_DIR="/etc/openvpn/easy-rsa-fallback"

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y wireguard openvpn easy-rsa ufw iptables-persistent ca-certificates
}

enable_forwarding() {
  install -m 0644 /dev/null /etc/sysctl.d/99-vpn-forwarding.conf
  cat >/etc/sysctl.d/99-vpn-forwarding.conf <<SYSCTL
net.ipv4.ip_forward=1
SYSCTL
  sysctl --system >/dev/null
}

configure_firewall() {
  ufw allow OpenSSH
  ufw allow "${WG_PORT}/udp"
  ufw allow "${OVPN_PORT}/tcp"
  ufw route allow in on wg0 out on "${PUBLIC_INTERFACE}"
  ufw route allow in on tun0 out on "${PUBLIC_INTERFACE}"
  ufw --force enable
}

configure_nat() {
  local wg_cidr ovpn_cidr
  wg_cidr="${WG_SUBNET}"
  ovpn_cidr="${OVPN_CIDR}"

  iptables -t nat -C POSTROUTING -s "${wg_cidr}" -o "${PUBLIC_INTERFACE}" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "${wg_cidr}" -o "${PUBLIC_INTERFACE}" -j MASQUERADE

  iptables -t nat -C POSTROUTING -s "${ovpn_cidr}" -o "${PUBLIC_INTERFACE}" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "${ovpn_cidr}" -o "${PUBLIC_INTERFACE}" -j MASQUERADE

  netfilter-persistent save >/dev/null
}

configure_wireguard() {
  install -d -m 0700 "${WG_DIR}" "${CLIENT_DIR}"

  local server_private server_public client_private client_public
  server_private="$(wg genkey)"
  server_public="$(printf '%s' "${server_private}" | wg pubkey)"
  client_private="$(wg genkey)"
  client_public="$(printf '%s' "${client_private}" | wg pubkey)"

  cat >"${WG_DIR}/wg0.conf" <<WGCONF
[Interface]
Address = ${WG_SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${server_private}

[Peer]
PublicKey = ${client_public}
AllowedIPs = ${WG_CLIENT_IP}
WGCONF
  chmod 0600 "${WG_DIR}/wg0.conf"

  cat >"${CLIENT_DIR}/wireguard-${CLIENT_NAME}.conf" <<CLIENTCONF
[Interface]
PrivateKey = ${client_private}
Address = ${WG_CLIENT_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${server_public}
Endpoint = ${VPN_HOST}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENTCONF
  chmod 0600 "${CLIENT_DIR}/wireguard-${CLIENT_NAME}.conf"

  systemctl enable --now wg-quick@wg0
}

configure_openvpn() {
  install -d -m 0700 "${CLIENT_DIR}" "${OVPN_DIR}"

  if [[ ! -d "${EASYRSA_DIR}" ]]; then
    make-cadir "${EASYRSA_DIR}"
  fi

  pushd "${EASYRSA_DIR}" >/dev/null
  ./easyrsa --batch init-pki
  ./easyrsa --batch build-ca nopass
  ./easyrsa --batch gen-dh
  ./easyrsa --batch build-server-full server nopass
  ./easyrsa --batch build-client-full "${CLIENT_NAME}" nopass
  openvpn --genkey secret pki/ta.key
  popd >/dev/null

  install -m 0600 "${EASYRSA_DIR}/pki/ca.crt" "${OVPN_DIR}/ca.crt"
  install -m 0600 "${EASYRSA_DIR}/pki/issued/server.crt" "${OVPN_DIR}/server.crt"
  install -m 0600 "${EASYRSA_DIR}/pki/private/server.key" "${OVPN_DIR}/server.key"
  install -m 0600 "${EASYRSA_DIR}/pki/dh.pem" "${OVPN_DIR}/dh.pem"
  install -m 0600 "${EASYRSA_DIR}/pki/ta.key" "${OVPN_DIR}/ta.key"

  cat >"${OVPN_DIR}/fallback.conf" <<OVPNCONF
port ${OVPN_PORT}
proto tcp-server
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server ${OVPN_SUBNET} ${OVPN_NETMASK}
ifconfig-pool-persist /var/log/openvpn/fallback-ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/fallback-status.log
verb 3
OVPNCONF

  {
    echo "client"
    echo "dev tun"
    echo "proto tcp-client"
    echo "remote ${VPN_HOST} ${OVPN_PORT}"
    echo "resolv-retry infinite"
    echo "nobind"
    echo "persist-key"
    echo "persist-tun"
    echo "remote-cert-tls server"
    echo "cipher AES-256-GCM"
    echo "auth SHA256"
    echo "verb 3"
    echo "key-direction 1"
    echo "<ca>"
    cat "${EASYRSA_DIR}/pki/ca.crt"
    echo "</ca>"
    echo "<cert>"
    sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${EASYRSA_DIR}/pki/issued/${CLIENT_NAME}.crt"
    echo "</cert>"
    echo "<key>"
    cat "${EASYRSA_DIR}/pki/private/${CLIENT_NAME}.key"
    echo "</key>"
    echo "<tls-auth>"
    cat "${EASYRSA_DIR}/pki/ta.key"
    echo "</tls-auth>"
  } >"${CLIENT_DIR}/openvpn-${CLIENT_NAME}.ovpn"
  chmod 0600 "${CLIENT_DIR}/openvpn-${CLIENT_NAME}.ovpn"

  systemctl enable --now openvpn-server@fallback
}

main() {
  echo "Installing VPN gateway on ${PUBLIC_INTERFACE} for ${VPN_HOST}"
  install_packages
  enable_forwarding
  configure_firewall
  configure_nat
  configure_wireguard
  configure_openvpn

  cat <<DONE

Done.

Generated client profiles:
  ${CLIENT_DIR}/wireguard-${CLIENT_NAME}.conf
  ${CLIENT_DIR}/openvpn-${CLIENT_NAME}.ovpn

Check services:
  systemctl status wg-quick@wg0
  systemctl status openvpn-server@fallback
  wg show
DONE
}

main
