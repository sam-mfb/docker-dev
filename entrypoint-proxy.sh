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

# Allow established/related connections
iptables -A OUTPUT -d "$HOST_IP" -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow TCP to port 48272 (OAuth2 forwarder)
iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 48272 -j ACCEPT

# Allow DNS to host (Docker Desktop routes DNS through the host gateway)
iptables -A OUTPUT -d "$HOST_IP" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 53 -j ACCEPT

# Block everything else to the host
iptables -A OUTPUT -d "$HOST_IP" -j REJECT

echo "iptables applied: host access restricted to port 48272 + DNS only"

# --- Start dnsmasq ---
# Forward DNS queries to Docker's embedded DNS (127.0.0.11)
# This allows the exp container to resolve both container names and external domains
dnsmasq \
    --no-daemon \
    --listen-address=0.0.0.0 \
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

# --- Start tinyproxy (foreground, keeps container alive) ---
echo "Starting tinyproxy on port 8888..."
exec tinyproxy -d
