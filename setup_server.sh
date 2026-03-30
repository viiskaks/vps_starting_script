#!/usr/bin/env bash

set -euo pipefail

echo "=== Server Initial Setup ==="

# === INPUT ===
while true; do
    read -rp "Enter new username: " NEW_USER
    [[ -n "$NEW_USER" ]] && break
    echo "Username cannot be empty."
done

# Password (hidden input)
while true; do
    read -rsp "Enter password for $NEW_USER: " USER_PASS
    echo ""
    read -rsp "Confirm password: " USER_PASS_CONFIRM
    echo ""

    if [[ "$USER_PASS" == "$USER_PASS_CONFIRM" && -n "$USER_PASS" ]]; then
        break
    else
        echo "Passwords do not match or empty. Try again."
    fi
done

# Port input with validation
while true; do
    read -rp "Enter SSH port (default 51532): " SSH_PORT
    SSH_PORT=${SSH_PORT:-51532}

    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && ((SSH_PORT >= 1 && SSH_PORT <= 65535)); then
        break
    else
        echo "Invalid port. Must be 1-65535."
    fi
done

echo "Paste your PUBLIC SSH key (single line):"
read -r PUB_KEY

if [[ -z "$PUB_KEY" ]]; then
    echo "Public key cannot be empty."
    exit 1
fi

echo ""
echo "===== SUMMARY ====="
echo "User: $NEW_USER"
echo "SSH Port: $SSH_PORT"
echo "==================="
echo ""

read -rp "Continue? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "Aborted." && exit 1

# === CREATE USER ===
if ! id "$NEW_USER" &>/dev/null; then
    echo "[+] Creating user $NEW_USER"
    adduser --disabled-password --gecos "" --shell /bin/bash --home "/home/$NEW_USER" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
else
    echo "[=] User already exists"
fi

# === SET PASSWORD ===
echo "[+] Setting user password"
echo "$NEW_USER:$USER_PASS" | chpasswd

# === SSH SETUP ===
USER_HOME="/home/$NEW_USER"
SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

echo "[+] Setting up SSH keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

grep -qxF "$PUB_KEY" "$AUTH_KEYS" || echo "$PUB_KEY" >> "$AUTH_KEYS"

chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"

# === SSH CONFIG ===
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "[+] Updating sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

sed -i \
    -e "s/^#\?Port .*/Port $SSH_PORT/" \
    -e "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" \
    -e "s/^#\?PermitRootLogin .*/PermitRootLogin no/" \
    -e "s/^#\?TCPKeepAlive .*/TCPKeepAlive yes/" \
    -e "s/^#\?ClientAliveInterval .*/ClientAliveInterval 60/" \
    -e "s/^#\?ClientAliveCountMax .*/ClientAliveCountMax 360/" \
    "$SSHD_CONFIG"

# === RESTART SSH ===
echo "[+] Restarting SSH"
systemctl restart ssh || systemctl restart sshd

# === FIREWALL ===
echo "[+] Applying firewall rules"

iptables -F
iptables -X

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 80  -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

apt install iptables-persistent
netfilter-persistent save

# === FINAL WARNING ===
echo ""
echo "⚠️  IMPORTANT:"
echo "Test access in NEW terminal BEFORE reboot:"
echo "ssh -p $SSH_PORT $NEW_USER@your_server_ip"
echo ""

read -rp "Press ENTER to reboot or Ctrl+C to cancel..."

reboot
