# Dashboard Guide

This document covers importing, customizing, and using the pre-built Wazuh dashboards.

---

## Dashboard Files

| File | Description | Visualizations |
|------|-------------|----------------|
| `ssh-brute-force.ndjson` | SSH brute force tracking | Geo-map, timeline, top usernames, source IPs |
| `web-attacks.ndjson` | Web attack summary | Top rules, target URLs, HTTP methods, response codes |
| `mitre-coverage.ndjson` | MITRE ATT&K coverage | Technique matrix heatmap |

---

## Importing Dashboards

### Method 1: Via Wazuh Dashboard UI (Recommended)

1. Open Dashboard: `https://10.10.10.12:5601`
2. Login: `admin` / password from `group_vars/all.yml`
3. Navigate: **Management** → **Saved Objects**
4. Click **Import** (top right)
5. Select `.ndjson` file from `dashboards/` folder
6. Click **Import** → Wait for success
7. Repeat for each dashboard file

### Method 2: Via API (Automated)

```bash
# Import all dashboards
for file in dashboards/*.ndjson; do
  curl -k -X POST "https://10.10.10.12:5601/api/saved_objects/_import" \
    -H "osd-xsrf: true" \
    -H "Content-Type: application/ndjson" \
    -u "admin:ChangeMe_Dashboard_2026!" \
    --data-binary @"$file"
done
```

---

## Dashboard Details

### 1. SSH Brute Force Tracker (`ssh-brute-force.ndjson`)

**Purpose:** Track SSH brute force attacks in real-time

**Visualizations:**

| Visualization | Type | Description |
|---------------|------|-------------|
| `SSH Brute Force - Geo Map` | Map | Attacker locations by source IP (GeoIP) |
| `SSH Brute Force - Timeline` | Line | Alert count over time (1h intervals) |
| `SSH Brute Force - Top Usernames` | Bar | Most targeted usernames |
| `SSH Brute Force - Top Source IPs` | Bar | Most active attacking IPs |
| `SSH Brute Force - Alert Details` | Table | Raw alert data: timestamp, IP, user, rule |

**Index Pattern:** `wazuh-alerts-*`

**Filters Applied:**
- `rule.id: 100001 OR 5716 OR 5712 OR 5710`
- `agent.name: ubuntu-agent OR kali-linux`

**Time Range:** Last 24 hours (default)

---

### 2. Web Attack Summary (`web-attacks.ndjson`)

**Purpose:** Monitor web application attacks (SQLi, XSS, LFI/RFI, shell upload)

**Visualizations:**

| Visualization | Type | Description |
|---------------|------|-------------|
| `Web Attacks - Rule Breakdown` | Pie | Alert count by rule ID |
| `Web Attacks - Target URLs` | Bar | Most attacked URLs |
| `Web Attacks - HTTP Methods` | Pie | GET vs POST vs others |
| `Web Attacks - Response Codes` | Bar | 200, 403, 404, 500 distribution |
| `Web Attacks - Top Attackers` | Bar | Source IPs with most alerts |
| `Web Attacks - Timeline` | Line | Attack volume over time |

**Index Pattern:** `wazuh-alerts-*`

**Filters Applied:**
- `rule.groups: web OR attack OR exploitation`
- `rule.id: 31151 OR 100003 OR 31101 OR 31106 OR 31111 OR 31121 OR 31131`

---

### 3. MITRE ATT&CK Coverage (`mitre-coverage.ndjson`)

**Purpose:** Visualize detection coverage across MITRE ATT&CK matrix

**Visualizations:**

| Visualization | Type | Description |
|---------------|------|-------------|
| `MITRE Coverage - Matrix` | Heatmap | Tactics (columns) × Techniques (rows) — Green=Covered, Yellow=Partial, Red=Gap |
| `MITRE Coverage - By Tactic` | Bar | Coverage % per tactic |
| `MITRE Coverage - Rule Mapping` | Table | Rule ID → Technique mapping |

**Data Source:** Static lookup table (embedded in dashboard)

**Coverage Data (as of v1.0):**

| Tactic | Techniques Covered | Total Techniques | Coverage |
|--------|-------------------|------------------|----------|
| Initial Access | 3/9 | 9 | 33% |
| Execution | 5/12 | 12 | 42% |
| Persistence | 4/19 | 19 | 21% |
| Privilege Escalation | 3/13 | 13 | 23% |
| Defense Evasion | 2/40 | 40 | 5% |
| Credential Access | 4/15 | 15 | 27% |
| Discovery | 6/30 | 30 | 20% |
| Lateral Movement | 2/9 | 9 | 22% |
| Collection | 1/17 | 17 | 6% |
| Command & Control | 3/16 | 16 | 19% |
| Exfiltration | 2/9 | 9 | 22% |
| Impact | 0/13 | 13 | 0% |

---

## Customizing Dashboards

### Edit Visualization

1. Dashboard → Click visualization title → **Edit**
2. Modify: Metrics, Buckets, Filters, Time range
3. Click **Update** → **Save**

### Add New Visualization

1. Dashboard → **Visualize** → **Create new visualization**
2. Select type (Lens, Bar, Line, Pie, Map, Table, etc.)
3. Choose index pattern: `wazuh-alerts-*`
4. Configure metrics & buckets
5. Save → Add to dashboard

### Clone & Modify

1. Dashboard → **Management** → **Saved Objects**
2. Find dashboard → **Clone** (copy icon)
3. Rename → Edit visualizations

---

## Creating New Dashboards

### Step 1: Define Requirements
- What questions does this dashboard answer?
- Who is the audience? (Analyst, Manager, Executive)
- What time range? (Real-time, Last 24h, Last 7d)

### Step 2: Build Visualizations
```bash
# Example: Top 10 alerting rules
# Visualize → Lens → Drag "rule.id" to "Break down by" → Top 10
```

### Step 3: Assemble Dashboard
1. **Dashboard** → **Create new dashboard**
2. **Add** → Select visualizations
3. Arrange layout (drag/resize)
3. Add **Filters** bar (top) for common filters
4. Set **Time picker** default (top right)

### Step 4: Export for Git
1. **Management** → **Saved Objects**
2. Select dashboard + all visualizations
3. **Export** → Save as `dashboards/new-dashboard.ndjson`
4. Commit to git

---

## Index Patterns

| Pattern | Description | Retention |
|---------|-------------|-----------|
| `wazuh-alerts-*` | Security alerts | 90 days (ILM) |
| `wazuh-archives-*` | Archived alerts | 365 days |
| `wazuh-monitoring-*` | Internal metrics | 30 days |
| `wazuh-states-*` | Agent state snapshots | 30 days |

**ILM Policy:** `wazuh-ilm-policy` (managed by Wazuh Indexer)

---

## Performance Tips

| Tip | Impact |
|-----|--------|
| Use **Lens** visualizations (new) | Faster than legacy |
| Limit time range to **Last 24h** default | Reduces query size |
| Add **index pattern filters** in dashboard | Avoids full index scans |
| Use **Dashboard-only mode** for TV displays | No edit overhead |
| Enable **Dashboard caching** | `opensearch_dashboards.yml`: `dashboard.cache.enabled: true` |

---

## Troubleshooting

### Dashboard Shows "No Data"
1. Check index pattern exists: Management → Index Patterns
2. Verify data in index: `GET /wazuh-alerts-*/_count`
3. Check time range matches data timestamps
4. Verify agent sending logs: Agents page → Status: Active

### Visualization Errors
- **"Courier Fetch Error"** → Indexer issue, check cluster health
- **"No Living Connections"** → Dashboard can't reach Indexer, check TLS certs
- **"Index Not Found"** → ILM rolled over, update index pattern

### Slow Loading
- Reduce time range
- Fewer visualizations per dashboard
- Check Indexer heap/CPU: `GET /_nodes/stats`

---

## Export/Backup

```bash
# Export all dashboards
curl -k -X GET "https://10.10.10.12:5601/api/saved_objects/_export" \
  -H "osd-xsrf: true" \
  -u "admin:ChangeMe_Dashboard_2026!" \
  -o dashboards-backup-$(date +%Y%m%d).ndjson
```

---

## Best Practices

1. **One dashboard per use case** — Don't overcrowd
2. **Consistent color scheme** — Red=Critical, Orange=High, Yellow=Medium, Blue=Low
3. **Clear titles** — "SSH Brute Force - Last 24h" not "Chart 1"
4. **Document filters** — Add markdown visualization explaining applied filters
5. **Version control** — Export `.ndjson` after every change
6. **Test on mobile** — Analysts may check on phone

---

## References

- [OpenSearch Dashboards Docs](https://opensearch.org/docs/latest/dashboards/)
- [Wazuh Dashboard Guide](https://documentation.wazuh.com/current/user-manual/dashboard/)
- [Lens Visualization](https://opensearch.org/docs/latest/dashboards/visualize/lens/)

---

*See also: [RULES.md](RULES.md) for rule-to-dashboard mapping, [SETUP.md](SETUP.md) for initial import*