#!/bin/bash
# Idempotent Tailscale + mosh bootstrap for RunPod pods.
#
# RunPod pods have no /dev/net/tun and no NET_ADMIN, so tailscaled must run in
# userspace-networking mode. RunPod also can't expose UDP ports, so mosh only
# works over the tailnet IP. State lives on /workspace (persistent volume) so
# the pod keeps the same tailnet identity/IP across restarts.
#
# Auth key (only needed on FIRST join — restarts reuse persisted state):
#   - env var TS_AUTHKEY (set it as a RunPod secret env var), or
#   - /workspace/.secrets/tailscale_authkey
# Never commit the key.
set -euo pipefail

TS_STATE=/workspace/tailscale.state
TS_SOCK=/tmp/tailscaled.sock
TS_HOSTNAME="${TS_HOSTNAME:-runpod-dev}"

# 1) Install tailscale + mosh if missing
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
command -v mosh-server >/dev/null || (apt-get update && apt-get install -y mosh)

# 2) Persist SSH host keys on /workspace so the Tailscale IP's host identity
#    survives pod recreation (avoids known_hosts warnings on the client).
mkdir -p /workspace/.ssh_host_keys
if compgen -G '/workspace/.ssh_host_keys/ssh_host_*' >/dev/null; then
    # /workspace ignores permissions (everything is 0666), so re-restrict after
    # copying or sshd rejects the private keys
    cp /workspace/.ssh_host_keys/ssh_host_* /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub
else
    ssh-keygen -A
    cp -p /etc/ssh/ssh_host_* /workspace/.ssh_host_keys/
fi

# 3) Reap dead SSH sessions server-side (roaming clients drop connections
#    silently, leaving zombie sshd/shell/tmux-attach processes)
if ! grep -q '^ClientAliveInterval' /etc/ssh/sshd_config; then
    printf 'ClientAliveInterval 60\nClientAliveCountMax 3\n' >> /etc/ssh/sshd_config
    service ssh status >/dev/null 2>&1 && service ssh reload
fi

# 4) Start tailscaled in userspace mode if not already running
if ! tailscale --socket="$TS_SOCK" status >/dev/null 2>&1; then
    nohup tailscaled --tun=userspace-networking \
        --state="$TS_STATE" --socket="$TS_SOCK" \
        >>/var/log/tailscaled.log 2>&1 &
fi

# 5) Wait for tailscaled to come up; with persisted state it reconnects on its own
backend_state=""
for _ in $(seq 1 15); do
    backend_state=$(tailscale --socket="$TS_SOCK" status --json 2>/dev/null |
        sed -n 's/.*"BackendState": *"\([^"]*\)".*/\1/p' | head -1)
    [ "$backend_state" = "Running" ] && break
    sleep 1
done

# 6) First join needs an auth key
if [ "$backend_state" != "Running" ]; then
    authkey="${TS_AUTHKEY:-}"
    if [ -z "$authkey" ] && [ -f /workspace/.secrets/tailscale_authkey ]; then
        authkey=$(cat /workspace/.secrets/tailscale_authkey)
    fi
    if [ -z "$authkey" ]; then
        echo "ERROR: tailscale not logged in (state=$backend_state) and no auth key found." >&2
        echo "Set TS_AUTHKEY or write the key to /workspace/.secrets/tailscale_authkey" >&2
        exit 1
    fi
    tailscale --socket="$TS_SOCK" up --authkey="$authkey" --hostname="$TS_HOSTNAME"
fi

echo "Tailscale up: $(tailscale --socket="$TS_SOCK" ip -4)"
