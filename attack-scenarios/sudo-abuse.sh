#!/bin/bash
# Sudo Abuse Attack Simulation
# Target: Ubuntu Agent (10.10.10.20)
# Requires: Test user with passwordless sudo (setup on target first)
# Expected Wazuh Rules: 100002 (custom), 5402 (built-in)
# MITRE: T1548.003 (Sudo and Sudo Caching)

set -e

TARGET="10.10.10.20"
USER="socadmin"
COMMAND="whoami"
ITERATIONS=5
DELAY=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Sudo Abuse Attack Simulation${NC}"
echo -e "${YELLOW}[*] Target: $TARGET${NC}"
echo -e "${YELLOW}[*] User: $USER${NC}"
echo -e "${YELLOW}[*] Command: $COMMAND${NC}"
echo -e "${YELLOW}[*] Iterations: $ITERATIONS${NC}"
echo ""

# Check if target is reachable
if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
    echo -e "${RED}[!] Target $TARGET is not reachable${NC}"
    exit 1
fi

# Check SSH connectivity
echo -e "${GREEN}[*] Testing SSH connection...${NC}"
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$USER@$TARGET" "echo 'SSH OK'" 2>/dev/null; then
    echo -e "${RED}[!] SSH key authentication not configured for $USER@$TARGET${NC}"
    echo -e "${YELLOW}[*] Run: ssh-copy-id $USER@$TARGET${NC}"
    exit 1
fi

# Check sudo configuration on target
echo -e "${GREEN}[*] Checking sudo configuration on target...${NC}"
SUDO_CHECK=$(ssh "$USER@$TARGET" "sudo -n true 2>&1; echo \$?")
if [[ "$SUDO_CHECK" != "0" ]]; then
    echo -e "${RED}[!] Passwordless sudo not configured for $USER on $TARGET${NC}"
    echo -e "${YELLOW}[*] On Ubuntu Agent, run:${NC}"
    echo -e "    echo \"$USER ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/test_sudo"
    echo -e "${YELLOW}[*] After test, cleanup with:${NC}"
    echo -e "    sudo rm /etc/sudoers.d/test_sudo"
    exit 1
fi

echo -e "${GREEN}[*] Sudo is configured for passwordless execution${NC}"
echo -e "${YELLOW}[*] This will trigger Wazuh rules: 100002, 5402${NC}"
echo ""

# Run sudo multiple times
for i in $(seq 1 $ITERATIONS); do
    echo -e "${GREEN}[*] Iteration $i/$ITERATIONS${NC}"
    ssh "$USER@$TARGET" "sudo $COMMAND"
    sleep "$DELAY"
done

echo ""
echo -e "${GREEN}[*] Attack simulation completed${NC}"
echo -e "${YELLOW}[*] Cleanup on target:${NC}"
echo -e "    ssh $USER@$TARGET \"sudo rm /etc/sudoers.d/test_sudo\""
echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100002 OR 5402"
echo -e "    MITRE: T1548.003"