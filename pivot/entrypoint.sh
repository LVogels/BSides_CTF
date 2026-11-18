#!/bin/sh
set -e
mkdir -p /run/sshd
# Start sshd in the background (maintenance access + SSH -D pivot).
/usr/sbin/sshd
# Run the web console as the unprivileged www-data user so RCE lands there.
exec gunicorn \
  --chdir /opt/castra/app \
  --bind 0.0.0.0:80 \
  --workers 2 \
  --user www-data --group www-data \
  app:app
