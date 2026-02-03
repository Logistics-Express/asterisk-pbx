# Logistics Express Asterisk PBX

SIP gateway with AI voice agents for Logistics Express customer service.

## Architecture

```
Customer Call → Telefacil → Asterisk (Vultr) → OpenAI Realtime SIP
                                 ↓
                          Jarvis Voice API (Railway)
                                 ↓
                    ┌────────────┴────────────┐
                    ↓            ↓            ↓
                Zoho CRM     Holded       Gmail
```

## Phone Numbers (DIDs)

| Number | Department | AI Persona | Voice |
|--------|------------|------------|-------|
| 951 650 500 | Ventas | jarvis-sales | alloy |
| 868 300 587 | Atención al Cliente | jarvis-service | nova |
| 951 319 560 | Administración | jarvis-admin | echo |
| 951 650 501 | Contabilidad | jarvis-accounting | shimmer |
| 951 650 502 | Legal | jarvis-legal | onyx |

## Production Server

**Vultr VPS:** `208.85.18.221`
**SSH Alias:** `jarvis-vultr`
**Location:** `/opt/asterisk-pbx`

### Quick Commands

```bash
# SSH to server
ssh jarvis-vultr

# Container status
docker ps
docker logs logistics-asterisk -f

# Asterisk CLI
docker exec logistics-asterisk asterisk -rx "pjsip show registrations"
docker exec logistics-asterisk asterisk -rx "pjsip show endpoints"
docker exec logistics-asterisk asterisk -rx "core show channels"
```

## Firewall Configuration

Docker bypasses UFW. We use `iptables DOCKER-USER` chain to filter SIP traffic.

### Current Rules

Only Telefacil (130.117.91.38) can reach SIP ports. All scanners are blocked.

```bash
# View rules
sudo iptables -L DOCKER-USER -n -v
```

### Apply Rules (if needed after reboot)

```bash
# 1. Allow established connections (responses to our outbound)
sudo iptables -I DOCKER-USER -m state --state ESTABLISHED,RELATED -j RETURN

# 2. Telefacil SIP signaling (inbound)
sudo iptables -A DOCKER-USER -p udp --dport 5060 -s 130.117.91.38 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --dport 5060 -s 130.117.91.38 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --dport 5061 -s 130.117.91.38 -j ACCEPT

# 3. Telefacil SIP signaling (outbound for registration)
sudo iptables -A DOCKER-USER -p udp --dport 5060 -d 130.117.91.38 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --dport 5060 -d 130.117.91.38 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --dport 5061 -d 130.117.91.38 -j ACCEPT

# 4. Telefacil RTP media (bidirectional)
sudo iptables -A DOCKER-USER -p udp --dport 10000:10100 -s 130.117.91.38 -j ACCEPT
sudo iptables -A DOCKER-USER -p udp --dport 10000:10100 -d 130.117.91.38 -j ACCEPT

# 5. OpenAI SIP (TLS on 5061, Cloudflare 172.65.182.0/24)
sudo iptables -A DOCKER-USER -p tcp --dport 5061 -d 172.65.182.0/24 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --sport 5061 -s 172.65.182.0/24 -j ACCEPT
sudo iptables -A DOCKER-USER -p udp --dport 10000:65535 -d 172.65.182.0/24 -j ACCEPT
sudo iptables -A DOCKER-USER -p udp --sport 10000:65535 -s 172.65.182.0/24 -j ACCEPT

# 6. Drop all other SIP traffic (scanner protection)
sudo iptables -A DOCKER-USER -p udp --dport 5060 -j DROP
sudo iptables -A DOCKER-USER -p tcp --dport 5060 -j DROP
sudo iptables -A DOCKER-USER -p tcp --dport 5061 -j DROP

# 7. Allow other traffic
sudo iptables -A DOCKER-USER -j RETURN

# Persist rules
sudo netfilter-persistent save
```

**Key IPs:**
- Telefacil: `130.117.91.38` (msip.duocom.es)
- OpenAI SIP: `172.65.182.0/24` (sip.api.openai.com via Cloudflare)

Rules are stored in `/etc/iptables/rules.v4`.

## Deployment

### Initial Setup (on Vultr)

```bash
# Clone repo
cd /opt
git clone https://github.com/Logistics-Express/asterisk-pbx.git
cd asterisk-pbx

# Configure environment
cp .env.example .env
nano .env  # Fill in credentials

# Start container
docker-compose up -d --build

# Verify registration
docker exec logistics-asterisk asterisk -rx "pjsip show registrations"
```

### Deploy Updates

```bash
# From local machine
cd ~/Desarrollos/asterisk-pbx
git add . && git commit -m "Update" && git push

# On Vultr
ssh jarvis-vultr
cd /opt/asterisk-pbx
git pull
docker-compose down && docker-compose up -d --build
```

## Configuration Files

| File | Purpose |
|------|---------|
| `asterisk/pjsip.conf.template` | SIP trunk and endpoint config |
| `asterisk/extensions.conf.template` | Dialplan (call routing) |
| `asterisk/rtp.conf` | RTP port range |
| `asterisk/logger.conf` | Logging configuration |
| `asterisk/modules.conf` | Asterisk modules to load |

Templates use environment variable substitution via `entrypoint.sh`.

## SIP Trunk Details

**Provider:** Telefacil (Duocom)
**Server:** msip.duocom.es
**Protocol:** PJSIP (UDP/TCP)
**Auth:** Username/Password

## Troubleshooting

### No Registration

```bash
# Check credentials in .env
docker exec logistics-asterisk cat /etc/asterisk/pjsip.conf | grep -A5 telefacil

# Check network connectivity
docker exec logistics-asterisk ping -c 3 msip.duocom.es

# Check SIP registration attempts
docker logs logistics-asterisk 2>&1 | grep -i "registration"
```

### Calls Not Connecting

```bash
# Check if Telefacil is whitelisted
sudo iptables -L DOCKER-USER -n -v | grep 130.117

# Check active channels
docker exec logistics-asterisk asterisk -rx "core show channels"

# Check SIP endpoint status
docker exec logistics-asterisk asterisk -rx "pjsip show endpoints"
```

### High Log Volume (Scanner Spam)

If logs show thousands of failed auth attempts:

```bash
# Check DROP counters
sudo iptables -L DOCKER-USER -n -v | grep DROP

# If counters are 0, rules aren't working - reapply firewall section above
```

## Related Repositories

| Repo | Purpose |
|------|---------|
| [jarvis-voice-api](https://github.com/abemon-es/jarvis-voice-api) | AI webhook handler (Railway) |

## Contact

**Company:** Logistics Express Aduanas, S.L.U.
**NIF:** B44995355
**Tech Contact:** mj@logisticsexpress.es
