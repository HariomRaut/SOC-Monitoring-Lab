#!/bin/bash
# Health Check Script for SOC Monitoring Lab
# Checks all components: Manager, Indexer, Dashboard, Agents

set -e

MANAGER_IP="${MANAGER_IP:-10.10.10.10}"
INDEXER_IP="${INDEXER_IP:-10.10.10.11}"
DASHBOARD_IP="${DASHBOARD_IP:-10.10.10.12}"
WUI_PASS="${WUI_PASS:-ChangeMe_Wazuh_WUI_2026!}"
ADMIN_PASS="${ADMIN_PASS:-ChangeMe_Indexer_Admin_2026!}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HEALTH_OK=0
HEALTH_WARN=0
HEALTH_CRIT=0

check() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    echo -ne "${YELLOW}[*] Checking $name... ${NC}"
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        ((HEALTH_OK++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        ((HEALTH_CRIT++))
        return 1
    fi
}

check_warn() {
    local name="$1"
    local cmd="$2"
    
    echo -ne "${YELLOW}[*] Checking $name... ${NC}"
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        ((HEALTH_OK++))
        return 0
    else
        echo -e "${YELLOW}WARNING${NC}"
        ((HEALTH_WARN++))
        return 1
    fi
}

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  SOC Monitoring Lab - Health Check${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# 1. Network connectivity
check "Manager ping" "ping -c 1 -W 2 $MANAGER_IP"
check "Indexer ping" "ping -c 1 -W 2 $INDEXER_IP"
check "Dashboard ping" "ping -c 1 -W 2 $DASHBOARD_IP"

echo ""

# 2. Service status (via SSH)
check "Manager service" "ssh -o ConnectTimeout=5 socadmin@$MANAGER_IP 'systemctl is-active wazuh-manager | grep -q active'"
check "Indexer service" "ssh -o ConnectTimeout=5 socadmin@$INDEXER_IP 'systemctl is-active wazuh-indexer | grep -q active'"
check "Dashboard service" "ssh -o ConnectTimeout=5 socadmin@$DASHBOARD_IP 'systemctl is-active wazuh-dashboard | grep -q active'"

echo ""

# 3. API endpoints
check "Manager API" "curl -k -s -u wazuh-wui:$WUI_PASS https://$MANAGER_IP:55000 | grep -q 'Wazuh'"
check "Indexer API" "curl -k -s -u admin:$ADMIN_PASS https://$INDEXER_IP:9200/_cluster/health | grep -q 'green\\|yellow'"
check "Dashboard UI" "curl -k -s https://$DASHBOARD_IP:5601/api/status | grep -q 'available'"

echo ""

# 4. Indexer cluster health
echo -ne "${YELLOW}[*] Checking Indexer cluster health... ${NC}"
CLUSTER_HEALTH=$(curl -k -s -u "admin:$ADMIN_PASS" "https://$INDEXER_IP:9200/_cluster/health" | jq -r '.status')
if [[ "$CLUSTER_HEALTH" == "green" ]]; then
    echo -e "${GREEN}GREEN${NC}"
    ((HEALTH_OK++))
elif [[ "$CLUSTER_HEALTH" == "yellow" ]]; then
    echo -e "${YELLOW}YELLOW (some replicas unassigned)${NC}"
    ((HEALTH_WARN++))
else
    echo -e "${RED}RED ($CLUSTER_HEALTH)${NC}"
    ((HEALTH_CRIT++))
fi

# 5. Agent status
echo -ne "${YELLOW}[*] Checking agent status... ${NC}"
AGENTS=$(curl -k -s -u "wazuh-wui:$WUI_PASS" "https://$MANAGER_IP:55000/agents" | jq -r '.data.affected_items[] | "\(.name):\(.status)"')
ACTIVE_COUNT=$(echo "$AGENTS" | grep -c ":active" || true)
TOTAL_COUNT=$(echo "$AGENTS" | wc -l)
if [[ $ACTIVE_COUNT -eq $TOTAL_COUNT && $TOTAL_COUNT -gt 0 ]]; then
    echo -e "${GREEN}$ACTIVE_COUNT/$TOTAL_COUNT active${NC}"
    ((HEALTH_OK++))
elif [[ $ACTIVE_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}$ACTIVE_COUNT/$TOTAL_COUNT active${NC}"
    ((HEALTH_WARN++))
else
    echo -e "${RED}No active agents${NC}"
    ((HEALTH_CRIT++))
fi

echo "$AGENTS" | while IFS= read -r line; do
    echo -e "    $line"
done

echo ""

# 6. Indexer disk usage
echo -ne "${YELLOW}[*] Checking Indexer disk usage... ${NC}"
DISK_USAGE=$(ssh -o ConnectTimeout=5 "socadmin@$INDEXER_IP" "df -h /var/lib/wazuh-indexer | tail -1 | awk '{print \$5}' | sed 's/%//'")
if [[ $DISK_USAGE -lt 70 ]]; then
    echo -e "${GREEN}${DISK_USAGE}%${NC}"
    ((HEALTH_OK++))
elif [[ $DISK_USAGE -lt 85 ]]; then
    echo -e "${YELLOW}${DISK_USAGE}% (warning)${NC}"
    ((HEALTH_WARN++))
else
    echo -e "${RED}${DISK_USAGE}% (critical)${NC}"
    ((HEALTH_CRIT++))
fi

# 7. Manager queue
echo -ne "${YELLOW}[*] Checking Manager event queue... ${NC}"
QUEUE_SIZE=$(curl -k -s -u "wazuh-wui:$WUI_PASS" "https://$MANAGER_IP:55000/manager/stats/hourly" | jq -r '.data.affected_items[0].event_count // 0')
if [[ $QUEUE_SIZE -lt 1000 ]]; then
    echo -e "${GREEN}$QUEUE_SIZE events/hour${NC}"
    ((HEALTH_OK++))
elif [[ $QUEUE_SIZE -lt 10000 ]]; then
    echo -e "${YELLOW}$QUEUE_SIZE events/hour (high)${NC}"
    ((HEALTH_WARN++))
else
    echo -e "${RED}$QUEUE_SIZE events/hour (very high)${NC}"
    ((HEALTH_CRIT++))
fi

# 8. Alert volume (last 24h)
echo -ne "${YELLOW}[*] Checking alert volume (24h)... ${NC}"
ALERT_COUNT=$(curl -k -s -u "admin:$ADMIN_PASS" "https://$INDEXER_IP:9200/wazuh-alerts-*/_count?q=@timestamp:[now-24h TO now]" | jq -r '.count // 0')
echo -e "${GREEN}$ALERT_COUNT alerts${NC}"
((HEALTH_OK++))

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}OK: $HEALTH_OK${NC}"
echo -e "${YELLOW}Warnings: $HEALTH_WARN${NC}"
echo -e "${RED}Critical: $HEALTH_CRIT${NC}"

if [[ $HEALTH_CRIT -gt 0 ]]; then
    echo -e "${RED}[!] CRITICAL issues detected!${NC}"
    exit 1
elif [[ $HEALTH_WARN -gt 0 ]]; then
    echo -e "${YELLOW}[!] Some warnings - review recommended${NC}"
    exit 0
else
    echo -e "${GREEN}[+] All systems healthy!${NC}"
    exit 0
fi