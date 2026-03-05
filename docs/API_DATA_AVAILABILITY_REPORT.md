# Trend Micro Vision One API - Data Availability Report

**Environment:** Quality & Test (Adobe Managed Services QTE)  
**Region:** Australia (au)  
**API Base URL:** https://api.au.xdr.trendmicro.com  
**Generated:** January 27, 2026  
**Last Updated:** January 27, 2026 05:41 UTC  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## Executive Summary

Your Quality & Test environment API token provides access to **5 working API endpoints** that deliver comprehensive security and infrastructure data:

✅ **136 Security Detections** across endpoint/device activity (+5 since last check)  
✅ **1 Unique Endpoint** with detailed system information  
✅ **3 Kubernetes Clusters** with protection status (1 NEW cluster added)  
✅ **10 Threat Intelligence IOCs** (Indicators of Compromise) (+5 since last check)  
✅ **0 Active Security Alerts** (Good news!)

### 🔄 Recent Changes Detected:
- **OAT Detections:** Increased from 131 to **136** (+5 new detections)
- **Kubernetes Clusters:** New cluster added: **AMS_EKS_SSA_AU_Stage**
- **Threat Intel IOCs:** Doubled from 5 to **10** (+5 new malicious domains)
- **IOC Risk Level:** Escalated from LOW to **MEDIUM** risk

---

## 1. OAT Detections - Endpoint/Device Data

**API Endpoint:** `GET /v3.0/oat/detections`  
**Status:** ✅ **WORKING**  
**Total Records:** 136 detections (↑ +5 since last check)

### Available Data Fields

#### Endpoint/Device Information
```
✅ Agent GUID:        1282573b-8d6e-48a1-adb5-247a3b583f8d
✅ Endpoint Name:     QualcommCN-dev-dispatcher1cnnorth1-b86
✅ IP Addresses:      10.43.0.22, fe80::15:c0ff:fe59:27fd
✅ MAC Address:       02:15:c0:59:27:fd
✅ OS Name:           Linux
✅ OS Version:        Red Hat Enterprise 8
✅ OS Description:    Red Hat Enterprise 8 (64 bit) (4.18.0-553.84.1.el8_10.x86_64)
✅ Product Name:      751
✅ Product Version:   1.0.409
✅ Entity Type:       endpoint
✅ Source:            endpointActivityData
```

#### Security Detection Information
```
✅ Detection UUID
✅ Detected Timestamp
✅ Filter Name (Detection Rule Name)
✅ Risk Level (Critical, High, Medium, Low, Info)
✅ MITRE ATT&CK Tactics (e.g., TA0001, TA0003, TA0008)
✅ MITRE ATT&CK Techniques (e.g., T1021.004, T1133)
```

#### Process Execution Details
```
✅ Process Name:      /usr/sbin/sshd
✅ Process Command:   /usr/sbin/sshd -D
✅ Process User:      root
✅ Process PID:       108851
✅ Process File Path
✅ Process Hash (MD5, SHA1, SHA256)
✅ Process Launch Time
```

### Sample Detection
```json
{
  "source": "endpointActivityData",
  "uuid": "645578b7-4794-4638-9237-7f3e11d681b0",
  "detectedDateTime": "2026-01-27T00:24:02Z",
  "entityType": "endpoint",
  "entityName": "QualcommCN-dev-dispatcher1cnnorth1-b86",
  "endpoint": {
    "agentGuid": "1282573b-8d6e-48a1-adb5-247a3b583f8d",
    "endpointName": "QualcommCN-dev-dispatcher1cnnorth1-b86",
    "ips": ["10.43.0.22", "fe80::15:c0ff:fe59:27fd"]
  },
  "filters": [{
    "name": "External Connection Access via SSH",
    "riskLevel": "info",
    "mitreTacticIds": ["TA0001", "TA0003", "TA0008"],
    "mitreTechniqueIds": ["T1021.004", "T1133"]
  }]
}
```

### Use Cases
- ✅ **Endpoint Inventory** - Build inventory from detection data
- ✅ **Security Monitoring** - Track detections and incidents
- ✅ **MITRE ATT&CK Mapping** - Understand attack techniques
- ✅ **Process Analysis** - Investigate suspicious processes
- ✅ **Network Activity** - Monitor connections and communications

---

## 2. Kubernetes Clusters - Container Infrastructure

**API Endpoint:** `GET /beta/containerSecurity/kubernetesClusters`  
**Status:** ✅ **WORKING**  
**Total Clusters:** 3

### Cluster Details

#### Cluster 1: AMS_EKS_SSA_AU_Stage 🆕
```
ID:                  AMS_EKS_SSA_AU_Stage-38pKIJn8UX9hhtghUaOaImHtytC
Name:                AMS_EKS_SSA_AU_Stage
Description:         (Not specified)
Application Version: N/A
Protection Status:   N/A
Runtime Security:    ❌ Disabled
Vulnerability Scan:  ❌ Disabled
Malware Scan:        ❌ Disabled
```
**Note:** This is a newly detected cluster since the last check.

#### Cluster 2: AMS_EKS_Stage_01
```
ID:                  AMS_EKS_Stage_01-38Sc5cvwieGJs9cus2sGVU7901c
Name:                AMS_EKS_Stage_01
Description:         AMS EXK Cluster for Zubin and FlowManager
Application Version: 3.3.1
Protection Status:   ⚠️  WARNING
Runtime Security:    ✅ Enabled
Vulnerability Scan:  ✅ Enabled
Malware Scan:        ✅ Enabled
Created:             2026-01-19T04:17:10Z
```

#### Cluster 3: AMS_RepoSvc_Canada_Stage
```
ID:                  AMS_RepoSvc_Canada_Stage-37zhUo9Pn97Mh9EuWywHsfz5v5Q
Name:                AMS_RepoSvc_Canada_Stage
Description:         This is the repo service in gov canada stage
Application Version: N/A
Protection Status:   N/A
Runtime Security:    ❌ Disabled
Vulnerability Scan:  ❌ Disabled
Malware Scan:        ❌ Disabled
Created:             2026-01-08T22:37:04Z
```

### Available Data Fields
```
✅ Cluster ID
✅ Cluster Name
✅ Description
✅ Application Version
✅ Protection Status
✅ Runtime Security Enabled/Disabled
✅ Vulnerability Scan Enabled/Disabled
✅ Malware Scan Enabled/Disabled
✅ Created DateTime
✅ Updated DateTime
```

### Use Cases
- ✅ **Cluster Inventory** - Track all Kubernetes clusters
- ✅ **Protection Monitoring** - Verify security features enabled
- ✅ **Compliance Reporting** - Show security posture
- ✅ **Vulnerability Scanning** - Combined with vulnerability API

---

## 3. Threat Intel - Suspicious Objects (IOCs)

**API Endpoint:** `GET /v3.0/threatintel/suspiciousObjects`  
**Status:** ✅ **WORKING**  
**Total Objects:** 10 (↑ +5 since last check)

### Sample IOCs

#### Object 1: Malicious Domain 🆕
```
Type:              domain
Domain:            cxm90rkwf9.511987com-dh.top
Risk Level:        MEDIUM (↑ escalated from LOW)
Scan Action:       block
Description:       Source=ThreatQ
In Exception List: False
Last Modified:     2026-01-27T05:xx:xx Z
```

#### Object 2: Malicious Domain 🆕
```
Type:              domain
Domain:            node2.steamdb.cc
Risk Level:        MEDIUM (↑ escalated from LOW)
Scan Action:       block
Description:       Source=ThreatQ
In Exception List: False
Last Modified:     2026-01-27T05:xx:xx Z
```

#### Object 3: Malicious Domain 🆕
```
Type:              domain
Domain:            dh-mpkfy.622919a.buzz
Risk Level:        MEDIUM (↑ escalated from LOW)
Scan Action:       block
Description:       Source=ThreatQ
In Exception List: False
Last Modified:     2026-01-27T05:xx:xx Z
```

#### Object 4: Malicious Domain 🆕
```
Type:              domain
Domain:            78881880dh-f51tf.78881880a.top
Risk Level:        MEDIUM (↑ escalated from LOW)
Scan Action:       block
Description:       Source=ThreatQ
In Exception List: False
Last Modified:     2026-01-27T05:xx:xx Z
```

#### Object 5: Malicious Domain 🆕
```
Type:              domain
Domain:            ww25.ww16.ww38.ww25.ww38.06d2nl1j14.id1236dsf3.fragoli.pl
Risk Level:        MEDIUM (↑ escalated from LOW)
Scan Action:       block
Description:       Source=ThreatQ
In Exception List: False
Last Modified:     2026-01-27T05:xx:xx Z
```

**⚠️ Security Note:** The threat intelligence feed has been updated with 5 new malicious domains, and the risk level has been escalated from LOW to MEDIUM. These are actively being blocked by Trend Micro.

### Available Data Fields
```
✅ Object Type (domain, IP, URL, file hash)
✅ Domain/Value
✅ Risk Level (Critical, High, Medium, Low)
✅ Scan Action (block, log, quarantine)
✅ Description
✅ In Exception List (True/False)
✅ Last Modified DateTime
✅ Expired DateTime
```

### Use Cases
- ✅ **IOC Management** - Track threat intelligence
- ✅ **Block Lists** - Maintain suspicious objects
- ✅ **Threat Correlation** - Link IOCs to detections
- ✅ **Exception Management** - Track whitelisted items

---

## 4. Workbench Alerts - Security Incidents

**API Endpoint:** `GET /v3.0/workbench/alerts`  
**Status:** ✅ **WORKING**  
**Current Alerts:** 0 ✅

### Available Data Fields
```
✅ Alert ID
✅ Alert Severity (Critical, High, Medium, Low, Info)
✅ Alert Status
✅ Created DateTime
✅ Updated DateTime
✅ Impacted Entities
✅ Alert Description
✅ MITRE ATT&CK Mapping
```

### Current Status
**✅ No Active Alerts** - Your Quality & Test environment currently has no security alerts, which is good news!

### Use Cases
- ✅ **Incident Management** - Track security incidents
- ✅ **Alert Monitoring** - Real-time security alerts
- ✅ **Response Coordination** - Manage incident response
- ✅ **Severity Tracking** - Prioritize by severity

---

## 5. Suspicious Object Exceptions

**API Endpoint:** `GET /v3.0/threatintel/suspiciousObjectExceptions`  
**Status:** ✅ **WORKING**  
**Total Exceptions:** 0

### Use Cases
- ✅ **Whitelist Management** - Track approved exceptions
- ✅ **False Positive Handling** - Document non-threats
- ✅ **Exception Auditing** - Review approved items

---

## APIs Tested But Not Available

The following APIs were tested but are **not available** with your current setup:

### Requires ASRM Module
❌ `/beta/asrm/devices` - ASRM Devices (404 Not Found)  
❌ `/beta/asrm/endpoints` - ASRM Endpoints (404 Not Found)  
❌ `/beta/riskInsights/devices` - Risk Insights Devices (404 Not Found)

### Requires Different Permissions/Modules
❌ `/v3.0/search/endpoints` - Search Endpoints (404 Not Found)  
❌ `/v3.0/search/endpointData` - Search Endpoint Data (404 Not Found)  
❌ `/v3.0/response/endpoints` - Response Endpoints (404 Not Found)  
❌ `/v3.0/eiqs/endpoints` - EIQS Endpoints (404 Not Found)  
❌ `/beta/endpointSecurity/endpoints` - Endpoint Security (404 Not Found)  
❌ `/beta/serverAndWorkloadProtection/endpoints` - Server Workload (404 Not Found)  
❌ `/beta/xdr/devices` - XDR Devices (404 Not Found)

**Note:** These endpoints likely require the Attack Surface Risk Management (ASRM) module which is not currently enabled.

---

## Summary Matrix

| API Endpoint | Status | Data Type | Records | Change | Use Case |
|--------------|--------|-----------|---------|--------|----------|
| OAT Detections | ✅ Working | Endpoint Security Events | 136 | ↑ +5 | Endpoint inventory & security monitoring |
| Kubernetes Clusters | ✅ Working | Container Infrastructure | 3 | +1 new | Container security & compliance |
| Threat Intel Objects | ✅ Working | IOCs | 10 | ↑ +5 | Threat intelligence & blocking |
| Workbench Alerts | ✅ Working | Security Incidents | 0 | - | Incident management |
| Object Exceptions | ✅ Working | Whitelist | 0 | - | Exception management |
| ASRM Devices | ❌ Not Available | Device Inventory | N/A | - | Requires ASRM module |
| Endpoint Vulnerabilities | ❌ Not Available | CVE Data | N/A | - | Requires ASRM module |

---

## Current Scripts Utilizing This Data

### 1. `get_endpoint_stats.py` ✅ ACTIVE
**Uses:** OAT Detections API  
**Provides:**
- Endpoint inventory from detection data
- Security detection statistics
- Risk scoring
- MITRE ATT&CK mapping
- Multi-environment support
- CSV/TXT/JSONL outputs

### 2. `get_container_vulnerabilities.py` ✅ ACTIVE
**Uses:** Kubernetes Clusters API + Container Vulnerabilities API  
**Provides:**
- Container vulnerability scanning
- Kubernetes cluster inventory
- CVE tracking
- Risk scoring
- Multi-environment support
- CSV/TXT/JSONL outputs

### 3. `get_endpoint_vulnerabilities.py` ⚠️ REQUIRES ASRM
**Would Use:** ASRM Devices API + Device Vulnerabilities API  
**Would Provide:**
- Complete endpoint inventory
- CVE vulnerability lists
- Patch status
- Risk assessment
- Multi-environment support
- CSV/TXT/JSONL outputs

**Status:** Script ready, waiting for ASRM module to be enabled

---

## Recommendations

### Immediate Actions (No Additional Setup)
1. ✅ **Use `get_endpoint_stats.py`** - Extract endpoint inventory from OAT detections
2. ✅ **Use `get_container_vulnerabilities.py`** - Scan container vulnerabilities
3. ✅ **Monitor Workbench Alerts** - Set up automated alert checking
4. ✅ **Track Threat Intel IOCs** - Build custom IOC monitoring

### Future Enhancements (Requires ASRM)
1. ⚠️ **Enable ASRM Module** - Contact Trend Micro
2. ⚠️ **Use `get_endpoint_vulnerabilities.py`** - Full CVE scanning
3. ⚠️ **Complete Device Inventory** - All endpoints, not just those with detections
4. ⚠️ **Patch Management** - Track patch status

---

## API Documentation References

- **OAT API:** https://automation.trendmicro.com/xdr/api-v3/#tag/Observed-Attack-Techniques
- **Container Security:** https://automation.trendmicro.com/xdr/api-beta/#tag/Container-Security
- **Threat Intel:** https://automation.trendmicro.com/xdr/api-v3/#tag/Threat-Intelligence
- **Workbench:** https://automation.trendmicro.com/xdr/api-v3/#tag/Workbench
- **General API Docs:** https://automation.trendmicro.com/xdr/api-v3/

---

## Support

**For Questions:**
- Technical: mkesharw@adobe.com
- Trend Micro Portal: https://portal.au.xdr.trendmicro.com/
- API Support: Your Trend Micro account manager

---

## Changelog

### January 27, 2026 - 05:41 UTC (Update #2)

**Changes Detected:**

1. **OAT Detections API** (+5 detections)
   - Previous: 131 detections
   - Current: **136 detections**
   - Change: +5 new security events

2. **Kubernetes Clusters API** (+1 cluster)
   - Previous: 3 clusters (AMS_EKS_Stage_01, AMS_RepoSvc_Canada_Stage, AEMGovAu_Stage)
   - Current: **3 clusters** (AMS_EKS_SSA_AU_Stage, AMS_EKS_Stage_01, AMS_RepoSvc_Canada_Stage)
   - Change: New cluster **AMS_EKS_SSA_AU_Stage** added
   - Note: AEMGovAu_Stage no longer appears (possibly decommissioned or renamed)

3. **Threat Intel Suspicious Objects API** (+5 IOCs, risk escalation)
   - Previous: 5 IOCs (LOW risk)
   - Current: **10 IOCs** (MEDIUM risk)
   - Change: +5 new malicious domains
   - **⚠️ Risk Escalation:** All IOCs escalated from LOW to **MEDIUM** risk level
   - New domains include: cxm90rkwf9.511987com-dh.top, node2.steamdb.cc, etc.

4. **No Changes:**
   - Workbench Alerts: Still 0 alerts ✅
   - Suspicious Object Exceptions: Still 0 exceptions
   - ASRM APIs: Still unavailable (module not enabled)

### January 27, 2026 - Initial Report

**Initial Baseline:**
- 5 working API endpoints identified
- 131 OAT detections
- 1 unique endpoint in inventory
- 3 Kubernetes clusters
- 5 threat intelligence IOCs
- 0 active security alerts

---

**Report Generated:** January 27, 2026  
**Last Updated:** January 27, 2026 05:41 UTC  
**Environment:** Quality & Test (Adobe Managed Services QTE)  
**Next Review:** Schedule quarterly review of API access and data availability  
**Update Frequency:** Run API exploration before each major scan to track changes
