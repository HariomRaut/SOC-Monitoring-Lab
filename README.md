# SOC Monitoring Lab — Wazuh SIEM on VirtualBox

[![GitHub Stars](https://img.shields.io/github/stars/HariomRaut/SOC-Monitoring-Lab?style=social)](https://github.com/HariomRaut/SOC-Monitoring-Lab/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/HariomRaut/SOC-Monitoring-Lab?style=social)](https://github.com/HariomRaut/SOC-Monitoring-Lab/network/members)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Wazuh Version](https://img.shields.io/badge/Wazuh-4.9.2-blue)](https://wazuh.com/)
[![Platform](https://img.shields.io/badge/Platform-VirtualBox-orange)](https://www.virtualbox.org/)

A complete **SOC Monitoring Lab** built with **Wazuh SIEM** on VirtualBox. Features automated deployment via Ansible, custom detection rules mapped to MITRE ATT&CK, pre-built dashboards, and attack simulation scripts for hands-on blue team practice.

---

## 🎯 Lab Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| **SIEM** | Wazuh 4.9.2 | Log collection, analysis, alerting |
| **Indexer** | OpenSearch 2.11 | Scalable log storage & search |
| **Dashboard** | Wazuh Dashboard (Kibana fork) | Visualization & investigation |
| **IDS** | Suricata 7.0 | Network traffic analysis |
| **Agents** | Wazuh Agent | Endpoint monitoring (Linux/Windows) |
| **Automation** | Ansible | Infrastructure as Code |

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌────────────────┐     ┌────────────────┐
│   Kali Linux    │     │  Wazuh       │     │  Wazuh         │     │  Wazuh         │
│   (Attacker +   │────▶│  Manager     │────▶│  Indexer       │────▶│  Dashboard     │
│    Monitored)   │     │  (Analysis)  │     │  (OpenSearch)  │     │  (Web UI)      │
│   10.10.10.30   │     │  10.10.10.10 │     │  10.10.10.11   │     │  10.10.10.12   │
└─────────────────┘     └──────────────┘     └────────────────┘     └────────────────┘
        │                       │                    │                    │
        │                       │                    │                    │
        ▼                       ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Internal Network: 10.10.10.0/24 (intnet)                │
└─────────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────┐
│  Ubuntu Server  │
│  (Log Source +  │
│   Suricata IDS) │
│  10.10.10.20    │
└─────────────────┘
```

**Full architecture details:** [ARCHITECTURE.md](ARCHITECTURE.md)

---

## 🚀 Quick Start

### Prerequisites
- VirtualBox 7.x
- 16 GB RAM minimum (14 GB allocated to VMs)
- 150 GB free disk space
- Ansible 2.14+ (on control machine)
- Git

### 1. Clone Repository
```bash
git clone https://github.com/HariomRaut/SOC-Monitoring-Lab.git
cd SOC-Monitoring-Lab
```

### 2. Create VMs in VirtualBox
Follow [docs/SETUP.md](docs/SETUP.md) to create 4 new VMs:
- `wazuh-manager` (Ubuntu 22.04, 4GB RAM, 2 vCPU, 40 GB)
- `wazuh-indexer` (Ubuntu 22.04, 6GB RAM, 2 vCPU, 60 GB)
- `wazuh-dashboard` (Ubuntu 22.04, 2GB RAM, 1 vCPU, 20 GB)
- `ubuntu-agent` (Ubuntu 22.04, 2GB RAM, 1 vCPU, 20 GB)

**Add 2nd NIC to each** → Internal Network `intnet`

### 3. Configure Inventory
Edit `ansible/inventory.yml` with your VM IPs:
```yaml
all:
  children:
    manager:
      hosts:
        wazuh-manager:
          ansible_host: 10.10.10.10
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
        kali-linux:
          ansible_host: 10.10.10.30
```

### 4. Deploy with Ansible
```bash
cd ansible
ansible-playbook -i inventory.yml site.yml
```

### 5. Access Dashboard
Open browser: `https://10.10.10.12:5601`
- Username: `admin`
- Password: Check `ansible/group_vars/all.yml` (auto-generated)

### 6. Run Attack Simulations (from Kali)
```bash
cd /path/to/SOC-Monitoring-Lab/attack-scenarios
chmod +x *.sh
./ssh-bruteforce.sh
./webshell-upload.sh
# ... etc
```

Watch alerts appear in Wazuh Dashboard → Security Events!

---

## 📁 Repository Structure

```
SOC-Monitoring-Lab/
├── .github/workflows/     # CI/CD pipelines
├── ansible/               # Ansible playbooks & roles
│   ├── site.yml
│   ├── inventory.yml
│   ├── group_vars/all.yml
│   └── roles/
│       ├── wazuh-manager/
│       ├── wazuh-indexer/
│       ├── wazuh-dashboard/
│       ├── wazuh-agent/
│       └── suricata/
├── rules/
│   └── local_rules.xml    # 5 custom rules + MITRE tags
├── dashboards/
│   ├── ssh-brute-force.ndjson
│   ├── web-attacks.ndjson
│   └── mitre-coverage.ndjson
├── attack-scenarios/
│   ├── ssh-bruteforce.sh
│   ├── webshell-upload.sh
│   ├── sudo-abuse.sh
│   ├── cron-persistence.sh
│   └── dns-exfil.sh
├── scripts/
│   ├── enroll-agent.sh
│   ├── backup-indexer.sh
│   └── health-check.sh
├── docs/
│   ├── SETUP.md
│   ├── RULES.md
│   ├── DASHBOARDS.md
│   ├── RUNBOOK.md
│   └── KALI_INTEGRATION.md
├── ARCHITECTURE.md
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🛡️ Detection Rules

Custom rules in `rules/local_rules.xml` mapped to MITRE ATT&CK:

| Rule ID | Name | MITRE Technique | Description |
|---------|------|-----------------|-------------|
| 100001 | SSH Brute Force | T1110.001 | >5 failed SSH in 1min from same IP |
| 100002 | Sudo Abuse | T1548.003 | `sudo` execution without prior auth |
| 100003 | Web Shell Upload | T1505.003 | PHP/ASP/JSP upload via POST + 200 OK |
| 100004 | Persistence via Cron | T1053.003 | New cron job for root/www-data |
| 100005 | DNS Exfiltration | T1048 | High entropy subdomains, >50 Q/min |

**Built-in rules enabled:** 0010, 0025, 0030, 0040, 0045, 0055, 0060, 0070, 0090

See [docs/RULES.md](docs/RULES.md) for details.

---

## 📊 Dashboards

Import via Dashboard → Management → Saved Objects → Import:

| Dashboard | Focus |
|-----------|-------|
| `ssh-brute-force.ndjson` | Geo-map, timeline, top usernames, source IPs |
| `web-attacks.ndjson` | Top rules, target URLs, HTTP methods, response codes |
| `mitre-coverage.ndjson` | Technique matrix heatmap (covered vs gaps) |

See [docs/DASHBOARDS.md](docs/DASHBOARDS.md) for import instructions.

---

## 🎯 Attack Scenarios

Run from Kali (10.10.10.30) against Ubuntu agent (10.10.10.20):

| Script | Tool | Target | Expected Alert |
|--------|------|--------|----------------|
| `ssh-bruteforce.sh` | hydra | SSH on Ubuntu | Rule 100001 + 5712 |
| `webshell-upload.sh` | curl | Web upload endpoint | Rule 100003 + 31151 |
| `sudo-abuse.sh` | sudo exploit | Local privilege escalation | Rule 100002 + 5402 |
| `cron-persistence.sh` | cron | Persistence mechanism | Rule 100004 + 530 |
| `dns-exfil.sh` | dnscat2/iodine | DNS tunneling | Rule 100005 + 87001 |

See [docs/KALI_INTEGRATION.md](docs/KALI_INTEGRATION.md) for Kali setup.

---

## 🔧 Operational Scripts

| Script | Purpose |
|--------|---------|
| `scripts/enroll-agent.sh` | Auto-enroll new agents to Manager |
| `scripts/backup-indexer.sh` | OpenSearch snapshot to S3/local |
| `scripts/health-check.sh` | Cluster health + agent status check |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | VM creation, network config, Ansible deploy |
| [RULES.md](docs/RULES.md) | Custom rules, MITRE mapping, testing |
| [DASHBOARDS.md](docs/DASHBOARDS.md) | Dashboard import, customization |
| [RUNBOOK.md](docs/RUNBOOK.md) | Daily ops, health checks, alert triage |
| [KALI_INTEGRATION.md](docs/KALI_INTEGRATION.md) | Kali NIC, agent enroll, attack scripts |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Network diagram, data flow, specs |

---

## 🧪 CI/CD Pipeline

GitHub Actions (`.github/workflows/ci.yml`):
- ✅ YAML lint (ansible-lint)
- ✅ XML validation (xmllint for rules)
- ✅ Shell script lint (shellcheck)
- ✅ Markdown lint (markdownlint)

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-rule`
3. Commit changes: `git commit -m "feat: add new detection rule"`
4. Push: `git push origin feature/new-rule`
5. Open Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 👨‍💻 Author

**Hariom Raut**
- GitHub: [@HariomRaut](https://github.com/HariomRaut)
- Project: [SOC-Monitoring-Lab](https://github.com/HariomRaut/SOC-Monitoring-Lab)

---

## 🙏 Acknowledgments

- [Wazuh](https://wazuh.com/) — Open source SIEM/XDR platform
- [OpenSearch](https://opensearch.org/) — Community-driven search & analytics
- [Suricata](https://suricata.io/) — Network IDS/IPS/NSM
- [MITRE ATT&CK](https://attack.mitre.org/) — Adversary tactics & techniques
- [Sigma](https://sigmahq.io/) — Generic signature format for SIEM