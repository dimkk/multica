#!/bin/sh
set -eu

if [ -z "${SSH_ADMIN_AUTHORIZED_KEY:-}" ]; then
  echo "SSH_ADMIN_AUTHORIZED_KEY is required" >&2
  exit 1
fi

ssh-keygen -A >/dev/null 2>&1

install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
printf '%s\n' "$SSH_ADMIN_AUTHORIZED_KEY" > /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys

exec /usr/sbin/sshd -D -e
