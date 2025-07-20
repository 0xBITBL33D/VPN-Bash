#!/bin/bash

# Configuration
WIFI_INTERFACE="wlan0"
SSID="MyVPNHotspot"
PASSWORD="strongpassword"
VPN_INTERFACE="tun0"
HOTSPOT_CONNECTION_NAME="vpn-hotspot"

# Exit on error
set -e

echo "[+] Checking interfaces..."
if ! ip link show "$WIFI_INTERFACE" > /dev/null 2>&1; then
    echo "[-] Wi-Fi interface $WIFI_INTERFACE not found"
    exit 1
fi

if ! ip link show "$VPN_INTERFACE" > /dev/null 2>&1; then
    echo "[-] VPN interface $VPN_INTERFACE not found"
    exit 1
fi

echo "[+] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

echo "[+] Creating Wi-Fi hotspot..."
nmcli connection add type wifi ifname "$WIFI_INTERFACE" con-name "$HOTSPOT_CONNECTION_NAME" autoconnect no \
    ssid "$SSID"

nmcli connection modify "$HOTSPOT_CONNECTION_NAME" \
    wifi.mode ap \
    wifi.band bg \
    ipv4.method shared \
    ipv4.addresses 10.42.0.1/24 \
    802-11-wireless-security.key-mgmt wpa-psk \
    802-11-wireless-security.psk "$PASSWORD"

# Ensure it uses the VPN interface as the default route
nmcli connection modify "$HOTSPOT_CONNECTION_NAME" \
    ipv4.gateway 10.42.0.1

echo "[+] Starting hotspot..."
nmcli connection up "$HOTSPOT_CONNECTION_NAME"

sleep 2

echo "[+] Setting up NAT from $WIFI_INTERFACE to $VPN_INTERFACE..."
iptables -t nat -F
iptables -t nat -A POSTROUTING -o "$VPN_INTERFACE" -j MASQUERADE
iptables -A FORWARD -i "$VPN_INTERFACE" -o "$WIFI_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$WIFI_INTERFACE" -o "$VPN_INTERFACE" -j ACCEPT

echo "[✔] Hotspot is running on SSID: $SSID, routing via $VPN_INTERFACE"
