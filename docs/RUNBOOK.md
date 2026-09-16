# Runbook — Daily Operations

Standard operating procedures for running the SOC Monitoring Lab.

---

## Daily Checks (Every Morning)

### 1. Cluster Health
```bash
# Run from control machine
cd /path/to/SOC-Monitoring-Lab
./scripts/health-check.sh

# Or manually:
curl -k -u admin:ChangeMe_Indexer_Admin_2026! https://10.10.10.11:9200/_cluster/health?pretty
```
**Expected:** `status: "green"` or `"yellow"` (never red)

### 2. Agent Status
```bash
# Via Dashboard: Agents page
# Or API:
curl -k -u wazuh-wui:ChangeMe_Wazuh_API_2026! https://10.10.10.10:55000/agents?pretty
```
**Expected:** All agents show `status: "active"`

### 3. Indexer Disk Usage
```bash
curl -k -u admin:ChangeMe_Indexer_Admin_2026! https://10.10.10.11:9200/_cat/allocation?v
```
**Alert if:** Any node > 80% disk usage

### 4. Alert Volume Check
```bash
# Last 24h alert count
curl -k -u admin:ChangeMe_Indexer_Admin_2026! "https://10.10.10.11:9200/wazuh-alerts-*/_count?q=@timestamp:[now-24h TO now]"
```
**Baseline:** ~50-200 alerts/day (varies with attack simulations)

### 5. Manager Queue
```bash
curl -k -u wazuh-wui:ChangeMe_Wazuh_API_2026! https://10.10.10.10:55000/manager/stats/hourly?pretty
```
**Alert if:** `event_count` > 10,000/hour sustained

---

## Weekly Tasks

### Monday: Rule Review
- [ ] Check new alerts in Dashboard → Security Events
- [ ] Review false positives → Add exceptions to `rules/local_rules.xml`
- [ ] Deploy rule updates: `ansible-playbook -i inventory.yml site.yml --tags manager`

### Wednesday: Indexer Maintenance
- [ ] Check ILM policy execution: `GET /_ilm/policy/wazuh-ilm-policy`
- [ ] Verify snapshot completed: `GET /_snapshot/wazuh-backup/_all`
- [ ] Force merge old indices (if needed): `POST /wazuh-alerts-*/_forcemerge?max_num_segments=1`

### Friday: Backup Verification
- [ ] Test restore from snapshot (to test index)
- [ ] Verify Ansible configs in git are current
- [ ] Update `docs/` with any changes

---

## Monthly Tasks

### 1. Certificate Rotation (Quarterly)
```bash
# On Indexer
sudo /usr/share/wazuh-indexer/bin/wazuh-indexer-certs-tool -A

# On Manager
sudo /var/ossec/bin/wazuh-manager-certs-tool -A

# On Dashboard
sudo /usr/share/wazuh-dashboard/bin/wazuh-dashboard-certs-tool -A

# Restart all services
ansible-playbook -i inventory.yml site.yml --tags certs
```

### 2. Version Updates
```bash
# Check for updates
apt list --upgradable | grep wazuh

# Update via Ansible (modify group_vars/all.yml version)
# Test in staging first!
```

### 3. Capacity Planning
- Review disk growth trend (last 3 months)
- Plan disk expansion if > 70% at current growth rate
- Review agent count vs Manager capacity

---

## Alert Triage Workflow

### Level 1: Automated (No Human)
- **Info/Low (level 1-4):** Auto-close, log only
- **Examples:** Heartbeat, config changes, successful logins

### Level 2: Analyst Review (Within 1 Hour)
- **Medium (level 5-10):** Single events, known patterns
- **Actions:**
  1. Open alert in Dashboard
  2. Check context: source IP, user, host, MITRE technique
  3. Correlate with other alerts (same IP? same host? same time?)
  4. Decide: Benign / True Positive / Escalate
  5. Add note in Dashboard (Case management)

### Level 3: Immediate Response (Within 15 Min)
- **High/Critical (level 11-15):** Active attacks, privilege escalation, exfiltration
- **Actions:**
  1. **Contain:** Block IP at firewall / isolate host
  2. **Investigate:** Full timeline in Dashboard, check Suricata logs
  3. **Eradicate:** Remove malware, kill processes, reset credentials
  4. **Recover:** Restore from backup, verify integrity
  5. **Document:** Incident report in `incidents/YYYY-MM-DD-incident.md`

---

## Incident Response Playbooks

### Playbook: SSH Brute Force (Rule 100001)
```
1. IDENTIFY: Alert shows source IP, targeted user(s)
2. CONTAIN:
   - Block source IP at firewall: ufw deny from <IP>
   - If internal IP: isolate host (disable switch port)
3. INVESTIGATE:
   - Check if any login succeeded: rule 5715 (SSH success)
   - Check for lateral movement: other hosts from same IP
4. ERADICATE:
   - Reset compromised passwords
   - Check for unauthorized keys in ~/.ssh/authorized_keys
5. RECOVER:
   - Re-enable access after password reset
   - Monitor for 24h
6. LESSONS: Add IP to blocklist, review SSH hardening
```

### Playbook: Web Shell Upload (Rule 100003)
```
1. IDENTIFY: Alert shows target URL, uploaded filename, source IP
2. CONTAIN:
   - Take web app offline (maintenance mode)
   - Block source IP
3. INVESTIGATE:
   - Check uploaded file: cat /var/www/html/uploads/shell.php
   - Search for other webshells: find /var/www -name "*.php" -exec grep -l "system\|exec\|shell" {} \;
   - Check Suricata for C2 traffic
4. ERADICATE:
   - Remove all webshells
   - Restore web files from git/backup
   - Patch vulnerability (file upload validation)
5. RECOVER:
   - Redeploy clean code
   - WAF rule for malicious extensions
6. LESSONS: Secure upload, disable PHP in upload dir
```

### Playbook: DNS Exfiltration (Rule 100005)
```
1. IDENTIFY: High DNS query volume, high entropy subdomains
2. CONTAIN:
   - Block DNS to external (force through internal resolver)
   - Isolate infected host
3. INVESTIGATE:
   - Capture DNS traffic: tcpdump -i eth1 port 53 -w dns.pcap
   - Analyze: zeek -r dns.pcap
   - Identify malware process: lsof -i :53
4. ERADICATE:
   - Kill malware process
   - Remove persistence (cron, systemd, etc.)
   - Full AV scan
5. RECOVER:
   - Rebuild host from golden image
   - Restore data from backup
6. LESSONS: DNS monitoring, egress filtering
```

---

## Escalation Contacts

| Role | Name | Contact | Escalation Time |
|------|------|---------|-----------------|
| SOC Analyst (Primary) | You | Local | Immediate |
| SOC Lead | — | — | 30 min |
| IT Admin | — | — | 1 hour |
| Management | — | — | 2 hours (critical) |

---

## Useful Commands Cheat Sheet

### Wazuh Manager
```bash
# Agent management
/var/ossec/bin/agent_control -l                    # List agents
/var/ossec/bin/agent_control -r <id>               # Restart agent
/var/ossec/bin/agent_control -u <id>               # Remove agent

# Log test
/var/ossec/bin/wazuh-logtest                       # Test rule matching

# Configuration
/var/ossec/bin/wazuh-control restart               # Restart all
systemctl status wazuh-manager                     # Service status
tail -f /var/ossec/logs/ossec.log                  # Live logs
```

### Wazuh Indexer
```bash
# Cluster health
curl -k -u admin:PASS https://10.10.10.11:9200/_cluster/health?pretty

# Indices
curl -k -u admin:PASS https://10.10.10.11:9200/_cat/indices?v

# Shards
curl -k -u admin:PASS https://10.10.10.11:9200/_cat/shards?v

# Snapshots
curl -k -u admin:PASS https://10.10.10.11:9200/_snapshot/wazuh-backup/_all?pretty
```

### Wazuh Dashboard
```bash
# Service
systemctl status wazuh-dashboard
systemctl restart wazuh-dashboard
journalctl -u wazuh-dashboard -f
```

### Suricata (on ubuntu-agent)
```bash
# Status
systemctl status suricata

# Live Eve JSON
tail -f /var/log/suricata/eve.json | jq .

# Test config
suricata -T -c /etc/suricata/suricata.yaml -v

# Rules update
suricata-update
systemctl restart suricata
```

### Ansible
```bash
# Run specific role
ansible-playbook -i inventory.yml site.yml --tags manager

# Run with vault
ansible-playbook -i inventory.yml site.yml --ask-vault-pass

# Check mode (dry run)
ansible-playbook -i inventory.yml site.yml --check

# Limit to one host
ansible-playbook -i inventory.yml site.yml --limit wazuh-manager
```

---

## Emergency Procedures

### Manager Down
1. Check: `systemctl status wazuh-manager`
2. Restart: `systemctl restart wazuh-manager`
3. If persists: Check `/var/ossec/logs/ossec.log` for errors
4. Failover: Not configured in lab (single manager)

### Indexer Down (Red Cluster)
1. Check: `systemctl status wazuh-indexer`
2. Check logs: `journalctl -u wazuh-indexer -f`
3. Common: Heap OOM → Reduce `-Xmx` in `/etc/wazuh-indexer/jvm.options`
4. Restart: `systemctl restart wazuh-indexer`
5. Verify: `GET /_cluster/health` → wait for green/yellow

### Dashboard Down
1. Check: `systemctl status wazuh-dashboard`
2. Check certs: `ls -la /etc/wazuh-dashboard/certs/`
3. Verify Indexer reachable: `curl -k https://10.10.10.11:9200`
4. Restart: `systemctl restart wazuh-dashboard`

### All Agents Disconnected
1. Check Manager: `systemctl status wazuh-manager`
2. Check network: `ping 10.10.10.10` from agent
3. Check firewall: `ufw status` on Manager (port 1514)
4. Re-enroll: `scripts/enroll-agent.sh <agent-ip> <agent-name>`

---

## Documentation Updates

After any incident or change:
1. Update `docs/RUNBOOK.md` if procedure changed
2. Update `rules/local_rules.xml` if new rule/exception added
3. Update `ansible/group_vars/all.yml` if config changed
4. Commit to git with descriptive message:
   ```
   git commit -m "docs: update runbook for DNS exfil response"
   git commit -m "rules: add exception for backup server SSH"
   ```

---

*See also: [SETUP.md](SETUP.md) for deployment, [RULES.md](RULES.md) for rule details, [KALI_INTEGRATION.md](KALI_INTEGRATION.md) for attack testing*