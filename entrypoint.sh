#!/bin/bash
set -e

# Substitute environment variables in config files
envsubst < /etc/asterisk/pjsip.conf.template > /etc/asterisk/pjsip.conf
envsubst < /etc/asterisk/extensions.conf.template > /etc/asterisk/extensions.conf
envsubst < /etc/asterisk/manager.conf.template > /etc/asterisk/manager.conf

# Set proper permissions on manager.conf (contains credentials)
chmod 600 /etc/asterisk/manager.conf

# Set proper ownership
chown -R asterisk:asterisk /etc/asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk

echo "Starting Asterisk..."
exec "$@"
