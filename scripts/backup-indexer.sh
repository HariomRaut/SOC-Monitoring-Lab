#!/bin/bash
# Indexer Backup Script
# Creates OpenSearch snapshot of Wazuh indices

set -e

INDEXER_IP="${1:-10.10.10.11}"
ADMIN_PASS="${2:-ChangeMe_Indexer_Admin_2026!}"
REPO_NAME="wazuh-backup"
SNAPSHOT_NAME="wazuh-snapshot-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="/mnt/backups/wazuh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Wazuh Indexer Backup${NC}"
echo -e "${YELLOW}[*] Indexer: $INDEXER_IP${NC}"
echo -e "${YELLOW}[*] Snapshot: $SNAPSHOT_NAME${NC}"

# Check connectivity
if ! nc -z -w 5 "$INDEXER_IP" 9200 2>/dev/null; then
    echo -e "${RED}[!] Indexer not reachable on port 9200${NC}"
    exit 1
fi

# Check if repository exists
REPO_EXISTS=$(curl -k -s -u "admin:$ADMIN_PASS" "https://$INDEXER_IP:9200/_snapshot/$REPO_NAME" | jq -r '.error // "none"')
if [[ "$REPO_EXISTS" != "none" ]]; then
    echo -e "${YELLOW}[*] Creating snapshot repository...${NC}"
    curl -k -s -X PUT "https://$INDEXER_IP:9200/_snapshot/$REPO_NAME" \
        -H "Content-Type: application/json" \
        -u "admin:$ADMIN_PASS" \
        -d "{
            \"type\": \"fs\",
            \"settings\": {
                \"location\": \"$BACKUP_PATH\",
                \"compress\": true
            }
        }" | jq .
fi

# Create snapshot
echo -e "${GREEN}[*] Creating snapshot...${NC}"
SNAPSHOT_RESPONSE=$(curl -k -s -X PUT "https://$INDEXER_IP:9200/_snapshot/$REPO_NAME/$SNAPSHOT_NAME?wait_for_completion=true" \
    -H "Content-Type: application/json" \
    -u "admin:$ADMIN_PASS" \
    -d '{
        "indices": "wazuh-alerts-*,wazuh-archives-*,wazuh-monitoring-*,wazuh-states-*",
        "ignore_unavailable": true,
        "include_global_state": false
    }')

echo "$SNAPSHOT_RESPONSE" | jq .

# Check result
SUCCESS=$(echo "$SNAPSHOT_RESPONSE" | jq -r '.snapshot.state // "FAILED"')
if [[ "$SUCCESS" == "SUCCESS" ]]; then
    echo -e "${GREEN}[+] Snapshot completed successfully!${NC}"
    echo -e "${GREEN}[*] Snapshot: $SNAPSHOT_NAME${NC}"
    echo -e "${GREEN}[*] Repository: $REPO_NAME${NC}"
else
    echo -e "${RED}[!] Snapshot failed or partial${NC}"
    exit 1
fi

# Clean old snapshots (keep last 30)
echo -e "${GREEN}[*] Cleaning old snapshots (keeping last 30)...${NC}"
SNAPSHOTS=$(curl -k -s -u "admin:$ADMIN_PASS" "https://$INDEXER_IP:9200/_snapshot/$REPO_NAME/_all" | jq -r '.snapshots | sort_by(.start_time) | .[].snapshot' | head -n -30)

for snap in $SNAPSHOTS; do
    echo -e "${YELLOW}[*] Deleting old snapshot: $snap${NC}"
    curl -k -s -X DELETE "https://$INDEXER_IP:9200/_snapshot/$REPO_NAME/$snap" -u "admin:$ADMIN_PASS" | jq .
done

echo -e "${GREEN}[+] Backup completed!${NC}"