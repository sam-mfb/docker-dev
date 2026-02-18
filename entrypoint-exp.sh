#!/bin/bash
set -e

# Experimental container entrypoint
# Applies iptables firewall rules to restrict host.docker.internal access
# to only the OAuth2 forwarder port (48272), then hands off to bash.

HOST_IP=$(getent hosts host.docker.internal | awk '{ print $1 }')

if [ -z "$HOST_IP" ]; then
    echo "WARNING: Could not resolve host.docker.internal. Firewall rules not applied."
    exec bash
fi

echo "Applying firewall rules: restricting host.docker.internal ($HOST_IP) to port 48272 only..."

# Allow established/related connections (so responses come back)
sudo iptables -A OUTPUT -d "$HOST_IP" -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow new TCP connections to port 48272 (OAuth2 forwarder)
sudo iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 48272 -j ACCEPT

# Allow DNS (Docker Desktop routes DNS through the host)
sudo iptables -A OUTPUT -d "$HOST_IP" -p udp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 53 -j ACCEPT

# Block everything else to host.docker.internal
sudo iptables -A OUTPUT -d "$HOST_IP" -j REJECT

echo "Firewall rules applied. Only port 48272 (O2F) and DNS are allowed to host."

# Hand off to bash as the main process
exec bash
