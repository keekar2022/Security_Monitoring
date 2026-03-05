# Grafana Quick Start - 10 Minutes to Dashboard

**Goal:** Get from zero to a working Grafana dashboard showing container vulnerabilities in 10 minutes.

---

## Prerequisites

- Docker and Docker Compose installed
- Container vulnerability data generated (or will generate in step 1)

---

## Step 1: Generate Initial Data (2 minutes)

```bash
cd /path/to/Integration-API-Dev

# Run first scan to generate data
python3 get_container_vulnerabilities.py

# Verify files created
ls -lh container_vulnerability_*.{csv,txt,jsonl}
```

---

## Step 2: Start Grafana Stack (3 minutes)

Create `docker-compose.yml`:

```bash
cat > docker-compose.yml << 'EOF'
version: "3"

services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./loki-data:/loki

  promtail:
    image: grafana/promtail:latest
    volumes:
      - ./config/promtail-config.yaml:/etc/promtail/config.yml:ro
      - ./container_vulnerability_metrics.jsonl:/var/log/vulnerabilities.jsonl:ro
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki

volumes:
  grafana-data:
EOF
```

Update Promtail config with absolute path:

```bash
# Get current directory
CURRENT_DIR=$(pwd)

# Update promtail config with absolute path
sed -i.bak "s|__path__:.*|__path__: ${CURRENT_DIR}/container_vulnerability_metrics.jsonl|" \
  config/promtail-config.yaml

# Verify
grep "__path__" config/promtail-config.yaml
```

Start the stack:

```bash
docker-compose up -d

# Wait for services to start
sleep 10

# Check services are running
docker-compose ps
```

---

## Step 3: Configure Grafana (2 minutes)

```bash
# Open Grafana in browser
open http://localhost:3000

# Or use:
# - Linux: xdg-open http://localhost:3000
# - Windows: start http://localhost:3000
```

**Login:**
- Username: `admin`
- Password: `admin`
- (You'll be prompted to change password - skip for now)

**Add Loki Data Source:**

1. Click **⚙️ Configuration** (gear icon) → **Data Sources**
2. Click **Add data source**
3. Select **Loki**
4. Configure:
   - **Name:** Loki
   - **URL:** `http://loki:3100`
5. Click **Save & Test**
6. Should see: ✅ "Data source connected and labels found"

---

## Step 4: Import Dashboard (2 minutes)

1. Click **➕ Create** → **Import**
2. Click **Upload JSON file**
3. Select: `config/grafana-dashboard-container-security.json`
4. Configure:
   - **Loki:** Select "Loki" from dropdown
5. Click **Import**

**You now have a working dashboard!** 🎉

---

## Step 5: Schedule Regular Scans (1 minute)

For time-series trending, schedule regular scans:

```bash
# Add to crontab
crontab -e

# Add this line (scans every 6 hours):
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet

# Or for hourly scans:
0 * * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

---

## What You Get

### Dashboard Panels

1. **Total Vulnerabilities Over Time**
   - Line graph showing vulnerability trends per cluster
   - Identify which clusters have increasing/decreasing vulnerabilities

2. **Critical Vulnerabilities**
   - Bar chart showing critical vulnerability counts
   - Quickly see which clusters need immediate attention

3. **Risk Score Heatmap**
   - Visual representation of overall risk
   - Color-coded for easy identification

4. **Severity Distribution**
   - Pie chart breaking down vulnerabilities by severity
   - Understand overall security posture

5. **Environment Comparison**
   - Compare Production vs Staging vs Development
   - Track improvements across environments

6. **Cluster Details Table**
   - Detailed breakdown per cluster
   - Sortable and filterable

---

## Testing the Dashboard

### Generate More Data Points

```bash
# Run scan immediately
python3 get_container_vulnerabilities.py

# Wait 5 minutes, run again
sleep 300
python3 get_container_vulnerabilities.py

# Now you have 2+ data points for trending
```

### View in Grafana

1. Refresh dashboard (click 🔄 icon top-right)
2. Adjust time range (top-right dropdown)
   - Select "Last 1 hour" or "Last 6 hours"
3. Hover over graphs to see details
4. Click on cluster names to filter

---

## Queries You Can Run

### In Grafana Explore

1. Go to **Explore** (compass icon)
2. Select **Loki** data source
3. Try these queries:

**All Vulnerability Data:**
```logql
{job="trend-micro-container-security"}
```

**Cluster-Level Only:**
```logql
{job="trend-micro-container-security", aggregation_level="cluster"}
```

**Specific Cluster:**
```logql
{job="trend-micro-container-security", cluster_name="AMS_EKS_Stage_01"}
```

**Critical Vulnerabilities Only:**
```logql
{job="trend-micro-container-security"} 
| json 
| Attributes.vulnerability.severity.critical > 0
```

---

## Troubleshooting

### No Data in Dashboard

**Check 1: JSONL file exists and has data**
```bash
ls -lh container_vulnerability_metrics.jsonl
tail -1 container_vulnerability_metrics.jsonl
```

**Check 2: Promtail is shipping logs**
```bash
docker-compose logs promtail | grep -i "clients/client"
```

**Check 3: Loki is receiving data**
```bash
curl -s "http://localhost:3100/loki/api/v1/label/cluster_name/values" | python3 -m json.tool
```

**Check 4: Restart Promtail**
```bash
docker-compose restart promtail
```

### Grafana Not Loading

```bash
# Check Grafana logs
docker-compose logs grafana

# Restart Grafana
docker-compose restart grafana

# Access Grafana
curl http://localhost:3000/api/health
```

### Wrong Timestamps

```bash
# Check timestamp format (should be RFC3339)
tail -1 container_vulnerability_metrics.jsonl | jq '.Timestamp'

# Should output: "2026-01-21T12:34:56.789012Z"
```

---

## Next Steps

### 1. Set Up Alerts

1. In dashboard, click on panel title → **Edit**
2. Go to **Alert** tab
3. Click **Create Alert**
4. Configure:
   - **Name:** "Critical Vulnerabilities Detected"
   - **Condition:** `WHEN last() OF query(A, 5m, now) IS ABOVE 5`
   - **Frequency:** Evaluate every 5m for 10m
5. Add notification channel (Slack, Email, etc.)
6. Save

### 2. Customize Dashboard

- Add more panels
- Change time ranges
- Add variables for filtering
- Create multiple dashboards for different teams

### 3. Automate Reporting

```bash
# Generate PNG snapshots of dashboards (requires Grafana Image Renderer)
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/render/d/container-security/container-security \
  -o vulnerability-report.png
```

### 4. Integrate with Other Tools

- **Slack:** Send dashboard links to channels
- **Email:** Schedule dashboard snapshots
- **PagerDuty:** Alert on critical vulnerabilities
- **JIRA:** Create tickets from alerts

---

## Common Grafana Commands

```bash
# View all services
docker-compose ps

# View logs
docker-compose logs -f grafana
docker-compose logs -f loki
docker-compose logs -f promtail

# Restart a service
docker-compose restart promtail

# Stop all services
docker-compose down

# Stop and remove volumes (fresh start)
docker-compose down -v

# Start services
docker-compose up -d
```

---

## Performance Tips

### If Dashboard is Slow

1. **Increase Loki query timeout:**
   - Edit `docker-compose.yml`
   - Add to Loki environment:
     ```yaml
     environment:
       - LOKI_QUERY_TIMEOUT=5m
     ```

2. **Limit time range:**
   - Use "Last 6 hours" instead of "Last 7 days"
   - Add time range selector to dashboard

3. **Use query caching:**
   - Grafana → Configuration → Data Sources → Loki
   - Enable "Enable query caching"

4. **Reduce refresh interval:**
   - Dashboard settings → "Auto refresh"
   - Change from "5s" to "1m" or "5m"

---

## Resources

- **Full Guide:** [`docs/OTEL_GRAFANA_GUIDE.md`](OTEL_GRAFANA_GUIDE.md)
- **Container Security:** [`docs/CONTAINER_SECURITY.md`](CONTAINER_SECURITY.md)
- **Grafana Docs:** https://grafana.com/docs/
- **Loki Docs:** https://grafana.com/docs/loki/
- **LogQL:** https://grafana.com/docs/loki/latest/logql/

---

## Success Checklist

- ✅ Generated vulnerability data (CSV, TXT, JSONL)
- ✅ Started Grafana stack (Loki, Promtail, Grafana)
- ✅ Added Loki data source in Grafana
- ✅ Imported pre-built dashboard
- ✅ Scheduled regular scans via cron
- ✅ Dashboard shows data
- ✅ Queries return results
- ✅ Time-series graphs are working

---

**Congratulations! You now have a production-ready vulnerability monitoring dashboard!** 🎉

**Time spent:** ~10 minutes  
**Dashboard:** http://localhost:3000  
**Next:** Set up alerts and customize panels

---

**Last Updated:** January 21, 2026
