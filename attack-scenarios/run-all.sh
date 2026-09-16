#!/bin/bash
# Run All Attack Scenarios
# Executes all attack simulations in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Running All Attack Scenarios${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

ATTACKS=(
    "ssh-bruteforce.sh"
    "webshell-upload.sh"
    "sudo-abuse.sh"
    "cron-persistence.sh"
    "dns-exfil.sh"
)

for attack in "${ATTACKS[@]}"; do
    echo -e "${YELLOW}[*] Running $attack...${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    
    if [[ -f "$SCRIPT_DIR/$attack" ]]; then
        chmod +x "$SCRIPT_DIR/$attack"
        "$SCRIPT_DIR/$attack" || echo -e "${RED}[!] $attack failed (continuing...)${NC}"
    else
        echo -e "${RED}[!] $attack not found${NC}"
    fi
    
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${GREEN}[*] Waiting 10 seconds before next attack...${NC}"
    sleep 10
    echo ""
done

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}  All Attack Scenarios Completed${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for all alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100001 OR 100002 OR 100003 OR 100004 OR 100005 OR 5716 OR 5402 OR 31151 OR 530 OR 87001"
echo ""
echo -e "${GREEN}[*] MITRE ATT&CK Techniques Tested:${NC}"
echo -e "    T1110.001 - Password Guessing (SSH Brute Force)"
echo -e "    T1548.003 - Sudo and Sudo Caching"
echo -e "    T1505.003 - Web Shell"
echo -e "    T1053.003 - Cron"
echo -e "    T1048 - Exfiltration Over Alternative Protocol"