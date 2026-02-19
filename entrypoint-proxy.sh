#!/bin/bash
set -e

echo "=== exp-proxy sidecar starting ==="

# --- Resolve the host gateway IP ---
HOST_IP=$(getent hosts host.docker.internal | awk '{ print $1 }')

if [ -z "$HOST_IP" ]; then
    echo "ERROR: Cannot resolve host.docker.internal. Proxy cannot start."
    exit 1
fi

echo "Host IP: $HOST_IP"

# --- Apply iptables on the proxy to restrict host access ---
# These rules live in the proxy's network namespace. The exp container
# (on the internal network) cannot modify them.

# Use ip6tables for IPv6 addresses, iptables for IPv4
if echo "$HOST_IP" | grep -q ':'; then
    IPTABLES=ip6tables
else
    IPTABLES=iptables
fi

# Allow established/related connections
$IPTABLES -A OUTPUT -d "$HOST_IP" -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow TCP to port 48272 (OAuth2 forwarder)
$IPTABLES -A OUTPUT -d "$HOST_IP" -p tcp --dport 48272 -j ACCEPT

# Allow DNS to host (Docker Desktop routes DNS through the host gateway)
$IPTABLES -A OUTPUT -d "$HOST_IP" -p udp --dport 53 -j ACCEPT
$IPTABLES -A OUTPUT -d "$HOST_IP" -p tcp --dport 53 -j ACCEPT

# Block everything else to the host
$IPTABLES -A OUTPUT -d "$HOST_IP" -j REJECT

echo "iptables applied: host access restricted to port 48272 + DNS only"

# --- Start dnsmasq ---
# Forward DNS queries to Docker's embedded DNS (127.0.0.11)
# This allows the exp container to resolve both container names and external domains
# Only bind to the internal-facing IP so dnsmasq doesn't shadow Docker's
# embedded DNS on 127.0.0.11 (which tinyproxy needs for external resolution)
dnsmasq \
    --no-daemon \
    --listen-address=172.30.0.2 \
    --port=53 \
    --server=127.0.0.11 \
    --log-queries \
    --log-facility=- &

DNSMASQ_PID=$!
echo "dnsmasq started (PID: $DNSMASQ_PID)"

# --- Start socat for OAuth2 forwarder ---
socat TCP-LISTEN:48272,fork,reuseaddr TCP:host.docker.internal:48272 &
SOCAT_PID=$!
echo "socat TCP forwarder started: 48272 -> host.docker.internal:48272 (PID: $SOCAT_PID)"

# --- Start tinyproxy ---
echo "Starting tinyproxy on port 8888..."
touch /var/log/tinyproxy.log
tinyproxy -d &
TINYPROXY_PID=$!

# Tail the log so it appears in docker logs, and wait on tinyproxy
tail -f /var/log/tinyproxy.log &
wait $TINYPROXY_PID
