# SOC Monitoring Lab — Setup Guide

Complete step-by-step guide to deploy the SOC Monitoring Lab on VirtualBox.

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| VirtualBox | 7.0+ | With Extension Pack |
| Host RAM | 16 GB minimum | 14 GB allocated to VMs |
| Host Disk | 200 GB free | 180 GB for VMs |
| Ansible | 2.14+ | On control machine (your host) |
| Git | 2.30+ | For cloning repo |
| SSH Client | Any | OpenSSH, PuTTY, etc. |

---

## Phase 1: Download OS Images

### Ubuntu Server 22.04 LTS
```bash
# Download from https://ubuntu.com/download/server
# File: ubuntu-22.04.4-live-server-amd64.iso (~1.5 GB)
```

### Kali Linux (if not already installed)
```bash
# Download from https://www.kali.org/get-kali/
# File: kali-linux-2026.2-installer-amd64.iso (~4 GB)
```

---

## Phase 2: Create Virtual Machines in VirtualBox

### VM 1: Wazuh Manager
```
Name: wazuh-manager
Type: Linux
Version: Ubuntu (64-bit)
Memory: 4096 MB (4 GB)
CPU: 2 vCPU
Disk: 40 GB (VDI, dynamically allocated)
Network:
  Adapter 1: Bridged Adapter → Your physical NIC
  Adapter 2: Internal Network → Name: intnet
```

### VM 2: Wazuh Indexer
```
Name: wazuh-indexer
Type: Linux
Version: Ubuntu (64-bit)
Memory: 6144 MB (6 GB)
CPU: 2 vCPU
Disk: 60 GB (VDI, dynamically allocated)
Network:
  Adapter 1: Internal Network → Name: intnet
```

### VM 3: Wazuh Dashboard
```
Name: wazuh-dashboard
Type: Linux
Version: Ubuntu (64-bit)
Memory: 2048 MB (2 GB)
CPU: 1 vCPU
Disk: 20 GB (VDI, dynamically allocated)
Network:
  Adapter 1: Internal Network → Name: intnet
```

### VM 4: Ubuntu Agent
```
Name: ubuntu-agent
Type: Linux
Version: Ubuntu (64-bit)
Memory: 2048 MB (2 GB)
CPU: 1 vCPU
Disk: 20 GB (VDI, dynamically allocated)
Network:
  Adapter 1: Internal Network → Name: intnet
```

---

## Phase 3: Install Ubuntu Server on Each VM

### Boot from ISO
1. Select VM → Start → Choose Ubuntu ISO
2. Install with defaults:
   - Language: English
   - Keyboard: US
   - Network: Wait for DHCP on Bridged (Manager) or configure static on intnet
   - User: `socadmin` (or your preferred username)
   - Password: Strong password (save it!)
   - SSH: **Enable OpenSSH Server**
   - No snaps needed

### Post-Install Network Config (on each VM)

**Manager (wazuh-manager):**
```bash
# Edit netplan
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:  # Bridged adapter
      dhcp4: true
    enp0s8:  # intnet adapter
      dhcp4: false
      addresses: [10.10.10.10/24]
      routes:
        - to: default
          via: 10.10.10.1
EOF
sudo netplan apply
```

**Indexer (wazuh-indexer):**
```bash
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:  # intnet adapter
      dhcp4: false
      addresses: [10.10.10.11/24]
EOF
sudo netplan apply
```

**Dashboard (wazuh-dashboard):**
```bash
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:  # intnet adapter
      dhcp4: false
      addresses: [10.10.10.12/24]
EOF
sudo netplan apply
```

**Ubuntu Agent (ubuntu-agent):**
```bash
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:  # intnet adapter
      dhcp4: false
      addresses: [10.10.10.20/24]
EOF
sudo netplan apply
```

### Verify Connectivity
```bash
# From Manager, test all:
ping 10.10.10.11  # Indexer
ping 10.10.10.12  # Dashboard
ping 10.10.10.20  # Ubuntu Agent
ping 10.10.10.30  # Kali (after Phase 4)
```

---

## Phase 4: Kali Linux Integration (Existing VM)

### Add 2nd NIC to Kali
1. Shutdown Kali VM
2. Settings → Network → Adapter 2
3. Enable Network Adapter
4. Attach to: **Internal Network**
5. Name: **intnet**
6. Start Kali

### Configure Static IP on Kali
```bash
# Find interface name (usually eth1 or ens8)
ip link show

# Configure static IP
sudo tee /etc/network/interfaces.d/eth1 > /dev/null <<'EOF'
auto eth1
iface eth1 inet static
    address 10.10.10.30
    netmask 255.255.255.0
EOF

# Restart networking
sudo systemctl restart networking
# OR: sudo ifdown eth1 && sudo ifup eth1

# Verify
ip addr show eth1
ping 10.10.10.10  # Manager
```

---

## Phase 5: Prepare Ansible Control Machine

### On Your Host (Windows/Linux/macOS)

```bash
# Clone the repository
git clone https://github.com/HariomRaut/SOC-Monitoring-Lab.git
cd SOC-Monitoring-Lab

# Install Ansible (if not installed)
# Windows (WSL2 recommended):
#   sudo apt update && sudo apt install ansible
# Linux:
#   sudo apt update && sudo apt install ansible
# macOS:
#   brew install ansible

# Verify
ansible --version
```

### Configure SSH Access to All VMs

```bash
# Generate SSH key (if not exists)
ssh-keygen -t ed25519 -C "soc-lab"

# Copy to each VM (use the username you created during install, e.g., socadmin)
ssh-copy-id socadmin@10.10.10.10  # Manager
ssh-copy-id socadmin@10.10.10.11  # Indexer
ssh-copy-id socadmin@10.10.10.12  # Dashboard
ssh-copy-id socadmin@10.10.10.20  # Ubuntu Agent
ssh-copy-id socadmin@10.10.10.30  # Kali

# Test passwordless SSH
ssh socadmin@10.10.10.10 "hostname"
```

### Configure Sudo Without Password (on each VM)
```bash
# Run on EACH VM:
echo "socadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/socadmin
```

---

## Phase 6: Configure Ansible Inventory

### Edit `ansible/inventory.yml`
```yaml
all:
  vars:
    ansible_user: socadmin
    ansible_become: true
    ansible_become_user: root
    ansible_python_interpreter: /usr/bin/python3

  children:
    manager:
      hosts:
        wazuh-manager:
          ansible_host: 10.10.10.10
          node_type: master

    indexer:
      hosts:
        wazuh-indexer:
          ansible_host: 10.10.10.11

    dashboard:
      hosts:
        wazuh-dashboard:
          ansible_host: 10.10.10.12

    agents:
      hosts:
        ubuntu-agent:
          ansible_host: 10.10.10.20
          agent_name: ubuntu-agent
        kali-linux:
          ansible_host: 10.10.10.30
          agent_name: kali-linux
```

### Edit `ansible/group_vars/all.yml`
```yaml
# Wazuh Version
wazuh_version: "4.9.2"

# Network
manager_ip: "10.10.10.10"
indexer_ip: "10.10.10.11"
dashboard_ip: "10.10.10.12"

# Credentials (CHANGE THESE!)
indexer_admin_password: "ChangeMe_Indexer_Admin_2026!"
dashboard_password: "ChangeMe_Dashboard_2026!"
wazuh_api_password: "ChangeMe_Wazuh_API_2026!"
wazuh_wui_password: "ChangeMe_Wazuh_WUI_2026!"

# Email Alerting (optional)
smtp_server: "smtp.gmail.com"
smtp_port: 587
smtp_user: "your-email@gmail.com"
smtp_password: "your-app-password"
alert_email_to: "analyst@yourdomain.com"

# Agent Enrollment
agent_auth_port: 1515
```

**⚠️ IMPORTANT:** Encrypt `group_vars/all.yml` with ansible-vault for production:
```bash
ansible-vault encrypt ansible/group_vars/all.yml
```

---

## Phase 7: Deploy with Ansible

### Run Full Deployment
```bash
cd ansible

# Test connectivity
ansible all -i inventory.yml -m ping

# Deploy everything
ansible-playbook -i inventory.yml site.yml

# Or deploy specific components:
ansible-playbook -i inventory.yml site.yml --tags indexer
ansible-playbook -i inventory.yml site.yml --tags manager
ansible-playbook -i inventory.yml site.yml --tags dashboard
ansible-playbook -i inventory.yml site.yml --tags agents
ansible-playbook -i inventory.yml site.yml --tags suricata
```

### Expected Runtime
| Play | Duration |
|------|----------|
| Indexer | 3-5 min |
| Manager | 2-3 min |
| Dashboard | 2-3 min |
| Agents | 1-2 min |
| Suricata | 2-3 min |
| **Total** | **10-15 min** |

---

## Phase 8: Verify Deployment

### 1. Check Wazuh Manager
```bash
ssh socadmin@10.10.10.10
sudo systemctl status wazuh-manager
sudo /var/ossec/bin/agent_control -l
```

### 2. Check Wazuh Indexer
```bash
ssh socadmin@10.10.10.11
sudo systemctl status wazuh-indexer
curl -k -u admin:ChangeMe_Indexer_Admin_2026! https://10.10.10.11:9200/_cluster/health
```

### 3. Check Wazuh Dashboard
```bash
ssh socadmin@10.10.10.12
sudo systemctl status wazuh-dashboard
```

### 4. Access Web UI
Open browser: `https://10.10.10.12:5601`
- **Username:** `admin`
- **Password:** Value from `group_vars/all.yml` (`dashboard_password`)

### 5. Verify Agents
In Dashboard: **Agents** → Should show:
- `ubuntu-agent` (Active)
- `kali-linux` (Active)

---

## Phase 9: Post-Deployment Configuration

### Import Dashboards
1. Dashboard → Management → Saved Objects → Import
2. Select files from `dashboards/`:
   - `ssh-brute-force.ndjson`
   - `web-attacks.ndjson`
   - `mitre-coverage.ndjson`

### Configure Email Alerts (Optional)
```bash
# On Manager
sudo tee -a /var/ossec/etc/ossec.conf > /dev/null <<'EOF'
<global>
  <email_notification>yes</email_notification>
  <smtp_server>smtp.gmail.com</smtp_server>
  <email_from>wazuh@lab.local</email_from>
  <email_to>analyst@yourdomain.com</email_to>
</global>
EOF
sudo systemctl restart wazuh-manager
```

### Enable Slack Integration (Optional)
Dashboard → Alerting → Integrations → Slack → Add Webhook URL

---

## Phase 10: Run Attack Simulations

```bash
# On Kali (10.10.10.30)
cd /path/to/SOC-Monitoring-Lab/attack-scenarios
chmod +x *.sh

# SSH Brute Force
./ssh-bruteforce.sh

# Web Shell Upload (requires web server on Ubuntu Agent)
./webshell-upload.sh

# Sudo Abuse
./sudo-abuse.sh

# Cron Persistence
./cron-persistence.sh

# DNS Exfiltration
./dns-exfil.sh
```

**Watch alerts in Dashboard:** Security Events → Filter by rule.id

---

## Troubleshooting

### Agent Not Connecting
```bash
# On Agent
sudo /var/ossec/bin/agent-auth -m 10.10.10.10 -A <agent-name>
sudo systemctl restart wazuh-agent
tail -f /var/ossec/logs/ossec.log
```

### Indexer Not Starting
```bash
# Check logs
sudo journalctl -u wazuh-indexer -f

# Common: JVM heap too large for RAM
# Edit /etc/wazuh-indexer/jvm.options:
# -Xms3g
# -Xmx3g
```

### Dashboard Can't Connect to Indexer
```bash
# Check certs
sudo ls -la /etc/wazuh-dashboard/certs/

# Verify Indexer cert
curl -k https://10.10.10.11:9200
```

### Ansible Fails
```bash
# Run with verbosity
ansible-playbook -i inventory.yml site.yml -vvv

# Check specific host
ansible-playbook -i inventory.yml site.yml --limit wazuh-manager -vvv
```

---

## Next Steps

1. **Customize Rules:** Edit `rules/local_rules.xml` → Restart Manager
2. **Add More Agents:** Run `scripts/enroll-agent.sh` on new endpoints
3. **Tune Alerts:** Adjust thresholds in rules, add exceptions
4. **Build More Dashboards:** Export from Dashboard → Save to `dashboards/`
5. **Document Your Lab:** Update `docs/` with your findings

---

*See also: [KALI_INTEGRATION.md](KALI_INTEGRATION.md), [RUNBOOK.md](RUNBOOK.md), [RULES.md](RULES.md)*