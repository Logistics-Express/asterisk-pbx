FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Asterisk 18 (available in Bullseye) and dependencies
RUN apt-get update && apt-get install -y \
    asterisk \
    asterisk-core-sounds-en-wav \
    asterisk-core-sounds-es-wav \
    asterisk-moh-opsound-wav \
    libssl1.1 \
    openssl \
    ca-certificates \
    curl \
    gettext-base \
    festival \
    sox \
    libsox-fmt-all \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate self-signed certificate for TLS transport
RUN mkdir -p /etc/asterisk/certs && \
    openssl req -new -x509 -days 365 -nodes \
        -out /etc/asterisk/certs/asterisk.crt \
        -keyout /etc/asterisk/certs/asterisk.key \
        -subj "/CN=jarvis-asterisk/O=LogisticsExpress/C=ES" && \
    chmod 600 /etc/asterisk/certs/asterisk.key && \
    chown -R asterisk:asterisk /etc/asterisk/certs

# Create Jarvis greeting audio
RUN mkdir -p /usr/share/asterisk/sounds/custom && \
    echo "Hi there, I am Jarvis. How can I help you today?" | text2wave -o /tmp/jarvis.wav && \
    sox /tmp/jarvis.wav -r 8000 -c 1 -t al /usr/share/asterisk/sounds/custom/jarvis-greeting.alaw && \
    sox /tmp/jarvis.wav -r 8000 -c 1 -t ul /usr/share/asterisk/sounds/custom/jarvis-greeting.ulaw && \
    chown -R asterisk:asterisk /usr/share/asterisk/sounds/custom && \
    rm /tmp/jarvis.wav

# Create asterisk user directories
RUN mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk \
    && chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk

# Copy configuration files
COPY asterisk/ /etc/asterisk/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SIP and RTP ports
EXPOSE 5060/udp 5060/tcp 5061/tcp
EXPOSE 10000-20000/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD asterisk -rx "core show channels" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["asterisk", "-fvvv"]
