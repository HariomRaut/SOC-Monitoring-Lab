#!/bin/bash
# Agent Enrollment Script
# Usage: ./enroll-agent.sh <agent_ip> <agent_name> [manager_ip]

set -e

AGENT_IP="${1:-}"
AGENT_NAME="${2:-}"
MANAGER_IP="${3:-10.10.10.10}"
AUTH_PORT="${4:-1515}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$AGENT_IP" || -z "$AGENT_NAME" ]]; then
    echo -e "${RED}Usage: $0 <agent_ip> <agent_name> [manager_ip] [auth_port]${NC}"
    echo -e "Example: $0 10.10.10.50 new-agent 10.10.10.10 1515"
    exit 1
fi

echo -e "${YELLOW}[*] Enrolling agent: $AGENT_NAME ($AGENT_IP)${NC}"
echo -e "${YELLOW}[*] Manager: $MANAGER_IP:$AUTH_PORT${NC}"

# Check connectivity
echo -e "${GREEN}[*] Testing connectivity to agent...${NC}"
if ! ping -c 1 -W 2 "$AGENT_IP" > /dev/null 2>&1; then
    echo -e "${RED}[!] Agent $AGENT_IP not reachable${NC}"
    exit 1
fi

# Check if agent-auth is running on manager
echo -e "${GREEN}[*] Checking agent-auth on manager...${NC}"
if ! nc -z -w 5 "$MANAGER_IP" "$AUTH_PORT" 2>/dev/null; then
    echo -e "${RED}[!] agent-auth not running on $MANAGER_IP:$AUTH_PORT${NC}"
    echo -e "${YELLOW}[*] Start it on manager: sudo /var/ossec/bin/agent-auth -m $MANAGER_IP -p $AUTH_PORT -v${NC}"
    exit 1
fi

# Enroll agent
echo -e "${GREEN}[*] Enrolling agent via agent-auth...${NC}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "socadmin@$AGENT_IP" \
    "sudo /var/ossec/bin/agent-auth -m $MANAGER_IP -p $AUTH_PORT -A $AGENT_NAME"

# Restart agent
echo -e "${GREEN}[*] Restarting Wazuh agent...${NC}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "socadmin@$AGENT_IP" \
    "sudo systemctl restart wazuh-agent"

# Verify enrollment
echo -e "${GREEN}[*] Verifying enrollment...${NC}"
sleep 5

AGENT_STATUS=$(curl -k -s -u wazuh-wui:ChangeMe_Wazuh_WUI_2026! "https://$MANAGER_IP:55000/agents?name=$AGENT_NAME" | jq -r '.data.affected_items[0].status // "unknown"')

if [[ "$AGENT_STATUS" == "active" ]]; then
    echo -e "${GREEN}[+] Agent $AGENT_NAME enrolled successfully! Status: $AGENT_STATUS${NC}"
else
    echo -e "${YELLOW}[!] Agent status: $AGENT_STATUS (may need more time)${NC}"
    echo -e "${YELLOW}[*] Check Dashboard: https://10.10.10.12:5601 -> Agents${NC}"
fi