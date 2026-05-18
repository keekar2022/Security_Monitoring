package main

import (
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/mkesharw/integration-api-dev/lib"
)

// ContainerVulnerability represents a single vulnerability
type ContainerVulnerability struct {
	ID            string                   `json:"id"`
	Name          string                   `json:"name"`
	CVE           string                   `json:"cve"`
	CVSSRecords   []map[string]interface{} `json:"cvssRecords"`
	RiskLevel     string                   `json:"riskLevel"`
	Severity      string                   `json:"severity"`
	ClusterID     string                   `json:"clusterId"`
	Registry      string                   `json:"registry"`
	FirstDetected string                   `json:"firstDetectedDateTime"`
}

// ClusterInfo represents Kubernetes cluster information
type ClusterInfo struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Group struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"group"`
}

// VulnerabilityStats holds statistics for vulnerabilities
type VulnerabilityStats struct {
	Total        int
	Critical     int
	High         int
	Medium       int
	Low          int
	Unknown      int
	UniqueCVEs   int
	RiskScore    int
	ClusterStats map[string]*ClusterStats
	Registries   map[string]int
}

// ClusterStats holds per-cluster statistics
type ClusterStats struct {
	Total     int
	Critical  int
	High      int
	Medium    int
	Low       int
	Unknown   int
	RiskScore int
}

func main() {
	// Command-line flags
	environment := flag.String("environment", "", "Environment to scan (quality_test, production, production_au)")
	groupID := flag.String("group-id", "", "Group ID to filter (optional)")
	groupName := flag.String("group-name", "", "Group name to filter (optional)")
	output := flag.String("output", "container_vulnerability_report.txt", "TXT report output file path")
	quiet := flag.Bool("quiet", false, "Suppress progress messages")
	csvOutput := flag.String("csv-output", "container_vulnerability_summary.csv", "CSV output file")
	otelOutput := flag.String("otel-output", "container_vulnerability_metrics.jsonl", "OTel/JSONL output file")
	outputDir := flag.String("output-dir", "data", "Directory for all output files (paths are relative to this)")
	noOtel := flag.Bool("no-otel", false, "Disable OpenTelemetry/JSONL generation")
	noCSV := flag.Bool("no-csv", false, "Disable CSV generation")
	noTxt := flag.Bool("no-txt", false, "Disable TXT report generation")
	overwrite := flag.Bool("overwrite", false, "Overwrite output files instead of appending (default: append)")
	top := flag.Int("top", 50, "Max results per API page (default: 50; API cap is 50)")
	lookbackDays := flag.Int("lookback-days", 0, "Only include vulnerabilities from the last N days (0 = no date filter)")

	flag.Parse()

	// OpenTelemetry-compliant structured logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	logger.Info("Starting container vulnerability scan",
		slog.String("service.name", "trend-micro-container-security"),
		slog.String("service.version", "1.0.0"),
		slog.String("operation", "scan_vulnerabilities"),
	)

	// Initialize configuration
	config, err := lib.NewTrendMicroConfig("", nil)
	if err != nil {
		logger.Error("Failed to initialize configuration",
			slog.String("error", err.Error()),
			slog.String("service.name", "trend-micro-container-security"),
		)
		os.Exit(1)
	}

	// Determine environments to scan
	var environments []string
	if *environment != "" {
		environments = []string{*environment}
	} else {
		// Get all available environments
		availableEnvs, err := config.ListAvailableEnvironments()
		if err != nil {
			logger.Error("Failed to list environments",
				slog.String("error", err.Error()),
			)
			os.Exit(1)
		}

		for env, info := range availableEnvs {
			if hasCreds, ok := info["has_credentials"].(bool); ok && hasCreds {
				environments = append(environments, env)
			}
		}
		// Deterministic order matching report: quality_test, production, production_au
		envOrder := map[string]int{"quality_test": 0, "production": 1, "production_au": 2}
		sort.Slice(environments, func(i, j int) bool {
			oi, oj := envOrder[environments[i]], envOrder[environments[j]]
			if oi != oj {
				return oi < oj
			}
			return environments[i] < environments[j]
		})
	}

	if len(environments) == 0 {
		fmt.Println("❌ No environments configured with credentials.")
		os.Exit(1)
	}

	if !*quiet {
		fmt.Printf("🌍 Scanning environments: %s\n\n", strings.Join(environments, ", "))
	}

	// Scan each environment
	allResults := make(map[string]*EnvironmentResults)

	for _, env := range environments {
		if !*quiet {
			fmt.Printf("\n╔%s╗\n", strings.Repeat("═", 76))
			fmt.Printf("║  ENVIRONMENT: %-61s  ║\n", strings.ToUpper(env))
			fmt.Printf("╚%s╝\n\n", strings.Repeat("═", 76))
		}

		// Get deployment info
		deployment, err := config.GetDeploymentInfo(env)
		if err != nil {
			logger.Error("Failed to get deployment info",
				slog.String("environment", env),
				slog.String("error", err.Error()),
			)
			continue
		}

		// Fetch all clusters
		clusters, err := fetchAllClusters(config, env, !*quiet)
		if err != nil {
			logger.Error("Failed to fetch clusters",
				slog.String("environment", env),
				slog.String("error", err.Error()),
			)
			continue
		}

		if len(clusters) == 0 {
			if !*quiet {
				fmt.Println("⚠️  No Kubernetes clusters found")
			}
			continue
		}

		// Filter by group if specified
		var clustersToProcess []*ClusterInfo
		if *groupID != "" || *groupName != "" {
			for _, cluster := range clusters {
				if (*groupID != "" && cluster.Group.ID == *groupID) ||
					(*groupName != "" && cluster.Group.Name == *groupName) {
					clustersToProcess = append(clustersToProcess, cluster)
				}
			}
		} else {
			clustersToProcess = clusters
		}

		// Fetch vulnerabilities for each cluster
		groupResults := make(map[string]*GroupResult)

		for _, cluster := range clustersToProcess {
			groupKey := cluster.Group.ID
			if _, exists := groupResults[groupKey]; !exists {
				groupResults[groupKey] = &GroupResult{
					GroupID:   cluster.Group.ID,
					GroupName: cluster.Group.Name,
					Clusters:  []*ClusterInfo{},
					Vulns:     []*ContainerVulnerability{},
				}
			}

			groupResults[groupKey].Clusters = append(groupResults[groupKey].Clusters, cluster)

			// Fetch vulnerabilities for this cluster
			vulns, err := fetchVulnerabilitiesForCluster(config, env, cluster, !*quiet, *top, *lookbackDays)
			if err != nil {
				logger.Error("Failed to fetch vulnerabilities",
					slog.String("cluster_id", cluster.ID),
					slog.String("cluster_name", cluster.Name),
					slog.String("error", err.Error()),
				)
				continue
			}

			groupResults[groupKey].Vulns = append(groupResults[groupKey].Vulns, vulns...)
		}

		envLabel, _ := config.GetEnvironmentLabel(env)

		allResults[env] = &EnvironmentResults{
			Deployment:      deployment,
			EnvironmentName: env,
			EnvLabel:        envLabel,
			GroupResults:    groupResults,
		}
	}

	// Resolve output paths (all three formats)
	csvPath := resolveOutputPath(*outputDir, *csvOutput)
	txtPath := resolveOutputPath(*outputDir, *output)
	otelPath := resolveOutputPath(*outputDir, *otelOutput)

	// Generate all three formats: CSV, JSONL (OTel), TXT
	if !*noCSV {
		if err := generateCSVSummary(allResults, csvPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate CSV",
				slog.String("error", err.Error()),
				slog.String("path", csvPath),
			)
		} else if !*quiet {
			fmt.Printf("✅ CSV: %s\n", csvPath)
		}
	}

	if !*noOtel {
		if err := generateOTelLogs(allResults, otelPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate OTel/JSONL",
				slog.String("error", err.Error()),
				slog.String("path", otelPath),
			)
		} else if !*quiet {
			fmt.Printf("✅ JSONL (OTel): %s\n", otelPath)
		}
	}

	if !*noTxt {
		if err := generateTextReport(allResults, txtPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate TXT report",
				slog.String("error", err.Error()),
				slog.String("path", txtPath),
			)
		} else if !*quiet {
			fmt.Printf("✅ TXT report: %s\n", txtPath)
		}
	}

	logger.Info("Container vulnerability scan completed",
		slog.String("service.name", "trend-micro-container-security"),
		slog.Int("environments_scanned", len(allResults)),
	)
}

// EnvironmentResults holds results for an environment
type EnvironmentResults struct {
	Deployment      *lib.DeploymentConfig
	EnvironmentName string
	EnvLabel        string
	GroupResults    map[string]*GroupResult
}

// GroupResult holds results for a group
type GroupResult struct {
	GroupID   string
	GroupName string
	Clusters  []*ClusterInfo
	Vulns     []*ContainerVulnerability
}

func fetchAllClusters(config *lib.TrendMicroConfig, env string, verbose bool) ([]*ClusterInfo, error) {
	baseURL, err := config.GetAPIBaseURL(env)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("%s/v3.0/containerSecurity/kubernetesClusters", baseURL)
	headers, err := config.GetCommonHeaders(env, true)
	if err != nil {
		return nil, err
	}

	if verbose {
		fmt.Println("Fetching Kubernetes clusters...")
	}

	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}

	for key, value := range headers {
		req.Header.Set(key, value)
	}

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var response struct {
		Items []*ClusterInfo `json:"items"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, err
	}

	if verbose {
		fmt.Printf("✓ Found %d clusters\n\n", len(response.Items))
	}

	return response.Items, nil
}

func fetchVulnerabilitiesForCluster(config *lib.TrendMicroConfig, env string, cluster *ClusterInfo, verbose bool, top int, lookbackDays int) ([]*ContainerVulnerability, error) {
	baseURL, err := config.GetAPIBaseURL(env)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("%s/v3.0/containerSecurity/vulnerabilities", baseURL)
	headers, err := config.GetCommonHeaders(env, true)
	if err != nil {
		return nil, err
	}

	// Container Security API rejects TMV1-Filter with firstDetectedDateTime; use only clusterId.
	headers["TMV1-Filter"] = fmt.Sprintf("clusterId eq '%s'", cluster.ID)
	var since time.Time
	if lookbackDays > 0 {
		since = time.Now().UTC().AddDate(0, 0, -lookbackDays)
	}

	if verbose {
		fmt.Printf("  • %s: ", cluster.Name)
	}

	req, err := http.NewRequest("GET", endpoint, nil)
	if err != nil {
		return nil, err
	}

	if top <= 0 {
		top = 50
	}
	if top > 50 {
		top = 50
	}
	q := req.URL.Query()
	q.Add("top", fmt.Sprintf("%d", top))
	q.Add("orderBy", "firstDetectedDateTime desc")
	req.URL.RawQuery = q.Encode()

	for key, value := range headers {
		req.Header.Set(key, value)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		if verbose {
			fmt.Printf("API request failed: %v\n", err)
		}
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		if verbose {
			fmt.Printf("Failed to read response body: %v\n", err)
		}
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		// Try to parse error details from response body
		errorMsg := fmt.Sprintf("API returned status %d", resp.StatusCode)
		if len(body) > 0 {
			// Try to extract error message from JSON response
			var errorResponse map[string]interface{}
			if err := json.Unmarshal(body, &errorResponse); err == nil {
				if msg, ok := errorResponse["error"].(map[string]interface{}); ok {
					if message, ok := msg["message"].(string); ok {
						errorMsg = fmt.Sprintf("API returned status %d: %s", resp.StatusCode, message)
					}
				} else if msg, ok := errorResponse["message"].(string); ok {
					errorMsg = fmt.Sprintf("API returned status %d: %s", resp.StatusCode, msg)
				}
			}

			if verbose {
				fmt.Printf("%s\n", errorMsg)
				if len(body) < 500 {
					fmt.Printf("Response body: %s\n", string(body))
				} else {
					fmt.Printf("Response body (first 500 chars): %s...\n", string(body[:500]))
				}
			}
		} else {
			if verbose {
				fmt.Printf("%s (no response body)\n", errorMsg)
			}
		}
		return nil, fmt.Errorf("%s", errorMsg)
	}

	var response struct {
		Items    []*ContainerVulnerability `json:"items"`
		NextLink string                    `json:"nextLink"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		if verbose {
			fmt.Printf("Failed to parse JSON: %v (first 200 chars: %s)\n", err, string(body[:min(200, len(body))]))
		}
		return nil, err
	}

	vulns := response.Items

	// Show initial count
	if verbose {
		fmt.Printf("%d vulns (page 1)", len(vulns))
	}

	// Handle pagination with progress indicator
	nextLink := response.NextLink
	pageCount := 1
	maxPages := 200 // Safety limit to prevent infinite loops

	for nextLink != "" && pageCount < maxPages {
		pageCount++
		req, _ := http.NewRequest("GET", nextLink, nil)
		for key, value := range headers {
			req.Header.Set(key, value)
		}

		resp, err := client.Do(req)
		if err != nil {
			if verbose {
				fmt.Printf(" [page %d failed: %v]", pageCount, err)
			}
			break
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			if verbose {
				fmt.Printf(" [page %d returned status %d]", pageCount, resp.StatusCode)
			}
			break
		}

		if err := json.Unmarshal(body, &response); err != nil {
			if verbose {
				fmt.Printf(" [page %d parse error]", pageCount)
			}
			break
		}

		vulns = append(vulns, response.Items...)
		nextLink = response.NextLink

		// Show progress every 5 pages
		if verbose && pageCount%5 == 0 {
			fmt.Printf("...%d", len(vulns))
		}
	}

	if verbose {
		pagesInfo := ""
		if pageCount > 1 {
			pagesInfo = fmt.Sprintf(" across %d pages", pageCount)
		}
		if pageCount >= maxPages {
			pagesInfo += " (limit reached)"
		}
		fmt.Printf(" - Total: %d vulnerabilities%s\n", len(vulns), pagesInfo)
	}

	// Filter by lookback-days client-side (API does not support firstDetectedDateTime in filter)
	if lookbackDays > 0 && !since.IsZero() {
		origLen := len(vulns)
		filtered := vulns[:0]
		for _, v := range vulns {
			if v.FirstDetected == "" {
				filtered = append(filtered, v)
				continue
			}
			t, err := time.Parse(time.RFC3339, v.FirstDetected)
			if err != nil && len(v.FirstDetected) >= 10 {
				t, err = time.Parse("2006-01-02", v.FirstDetected[:10])
			}
			if err != nil {
				filtered = append(filtered, v)
				continue
			}
			if !t.Before(since) {
				filtered = append(filtered, v)
			}
		}
		vulns = filtered
		if verbose && len(vulns) != origLen {
			fmt.Printf("  (filtered to last %d days: %d)\n", lookbackDays, len(vulns))
		}
	}

	return vulns, nil
}

func analyzeVulnerabilities(vulns []*ContainerVulnerability) *VulnerabilityStats {
	stats := &VulnerabilityStats{
		ClusterStats: make(map[string]*ClusterStats),
		Registries:   make(map[string]int),
	}

	cveSet := make(map[string]bool)

	for _, vuln := range vulns {
		stats.Total++

		// Determine severity
		severity := strings.ToLower(vuln.Severity)
		if severity == "" && len(vuln.CVSSRecords) > 0 {
			if sev, ok := vuln.CVSSRecords[0]["severity"].(string); ok {
				severity = strings.ToLower(sev)
			}
		}
		if severity == "" && vuln.RiskLevel != "" {
			severity = strings.ToLower(vuln.RiskLevel)
		}

		switch severity {
		case "critical":
			stats.Critical++
		case "high":
			stats.High++
		case "medium":
			stats.Medium++
		case "low":
			stats.Low++
		default:
			stats.Unknown++
		}

		// Track unique CVEs
		if vuln.CVE != "" {
			cveSet[vuln.CVE] = true
		} else if vuln.Name != "" {
			cveSet[vuln.Name] = true
		}

		// Track registries
		if vuln.Registry != "" {
			stats.Registries[vuln.Registry]++
		}
	}

	stats.UniqueCVEs = len(cveSet)
	stats.RiskScore = stats.Critical*10 + stats.High*5 + stats.Medium*2 + stats.Low*1

	return stats
}

func generateCSVSummary(results map[string]*EnvironmentResults, outputFile string, overwrite bool, verbose bool) error {
	if verbose {
		fmt.Printf("\n%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING CSV SUMMARY")
		fmt.Printf("%s\n\n", strings.Repeat("=", 70))
	}

	// Ensure parent directory exists
	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("create output dir: %w", err)
		}
	}

	mode := os.O_CREATE | os.O_WRONLY
	if overwrite {
		mode |= os.O_TRUNC
	} else {
		mode |= os.O_APPEND
	}

	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return fmt.Errorf("open CSV file: %w", err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// Write header if new or empty file
	fileInfo, err := file.Stat()
	if err != nil {
		return fmt.Errorf("stat output file: %w", err)
	}
	if fileInfo.Size() == 0 {
		header := []string{"Timestamp", "Environment", "Business Name", "Region",
			"Cluster ID", "Cluster Name", "Total", "Unique CVEs", "Critical", "High", "Medium", "Low", "Risk Score"}
		if err := writer.Write(header); err != nil {
			return fmt.Errorf("write CSV header: %w", err)
		}
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Collect all clusters with their vulnerabilities
	type ClusterWithStats struct {
		EnvResults *EnvironmentResults
		Cluster    *ClusterInfo
		Vulns      []*ContainerVulnerability
	}
	var allClusters []ClusterWithStats

	for _, envResults := range results {
		for _, groupResult := range envResults.GroupResults {
			for _, cluster := range groupResult.Clusters {
				var clusterVulns []*ContainerVulnerability
				for _, vuln := range groupResult.Vulns {
					if vuln.ClusterID == cluster.ID {
						clusterVulns = append(clusterVulns, vuln)
					}
				}
				allClusters = append(allClusters, ClusterWithStats{
					EnvResults: envResults,
					Cluster:    cluster,
					Vulns:      clusterVulns,
				})
			}
		}
	}

	// Sort by environment label then cluster name for deterministic output
	sort.Slice(allClusters, func(i, j int) bool {
		if allClusters[i].EnvResults.EnvLabel != allClusters[j].EnvResults.EnvLabel {
			return allClusters[i].EnvResults.EnvLabel < allClusters[j].EnvResults.EnvLabel
		}
		return allClusters[i].Cluster.Name < allClusters[j].Cluster.Name
	})

	for _, clusterData := range allClusters {
		stats := analyzeVulnerabilities(clusterData.Vulns)
		row := []string{
			timestamp,
			clusterData.EnvResults.EnvLabel,
			clusterData.EnvResults.Deployment.BusinessName,
			clusterData.EnvResults.Deployment.Region,
			clusterData.Cluster.ID,
			clusterData.Cluster.Name,
			fmt.Sprintf("%d", stats.Total),
			fmt.Sprintf("%d", stats.UniqueCVEs),
			fmt.Sprintf("%d", stats.Critical),
			fmt.Sprintf("%d", stats.High),
			fmt.Sprintf("%d", stats.Medium),
			fmt.Sprintf("%d", stats.Low),
			fmt.Sprintf("%d", stats.RiskScore),
		}
		if err := writer.Write(row); err != nil {
			return fmt.Errorf("write CSV row: %w", err)
		}
	}

	return nil
}

func generateOTelLogs(results map[string]*EnvironmentResults, outputFile string, overwrite bool, verbose bool) error {
	if verbose {
		fmt.Printf("\n%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING OPENTELEMETRY / JSONL")
		fmt.Printf("%s\n\n", strings.Repeat("=", 70))
	}

	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("create output dir: %w", err)
		}
	}

	mode := os.O_CREATE | os.O_WRONLY
	if overwrite {
		mode |= os.O_TRUNC
	} else {
		mode |= os.O_APPEND
	}
	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return fmt.Errorf("open JSONL file: %w", err)
	}
	defer file.Close()

	timestamp := time.Now().UTC().Format(time.RFC3339)
	hostname, _ := os.Hostname()

	for _, envResults := range results {
		for _, groupResult := range envResults.GroupResults {
			// Write cluster-level entries (one per cluster)
			for _, cluster := range groupResult.Clusters {
				// Filter vulnerabilities for this cluster
				var clusterVulns []*ContainerVulnerability
				for _, vuln := range groupResult.Vulns {
					if vuln.ClusterID == cluster.ID {
						clusterVulns = append(clusterVulns, vuln)
					}
				}

				stats := analyzeVulnerabilities(clusterVulns)

				// Cluster-level entry
				clusterEntry := map[string]interface{}{
					"Timestamp":         timestamp,
					"ObservedTimestamp": timestamp,
					"SeverityNumber":    9,
					"SeverityText":      "INFO",
					"Body":              fmt.Sprintf("Container Security vulnerability scan for cluster '%s'", cluster.Name),
					"Resource": map[string]interface{}{
						"service.name":           "trend-micro-container-security",
						"service.version":        "1.0.0",
						"deployment.environment": envResults.EnvLabel,
						"cloud.provider":         "trend-micro",
						"cloud.region":           envResults.Deployment.Region,
						"cloud.account.id":       envResults.Deployment.BusinessID,
						"cloud.account.name":     envResults.Deployment.BusinessName,
						"host.name":              hostname,
					},
					"Attributes": map[string]interface{}{
						"cluster.id":                      cluster.ID,
						"cluster.name":                    cluster.Name,
						"group.id":                        groupResult.GroupID,
						"group.name":                      groupResult.GroupName,
						"vulnerability.total":             stats.Total,
						"vulnerability.unique_cves":       stats.UniqueCVEs,
						"vulnerability.severity.critical": stats.Critical,
						"vulnerability.severity.high":     stats.High,
						"vulnerability.severity.medium":   stats.Medium,
						"vulnerability.severity.low":      stats.Low,
						"vulnerability.severity.unknown":  stats.Unknown,
						"vulnerability.risk_score":        stats.RiskScore,
						"event.kind":                      "metric",
						"event.category":                  "vulnerability",
						"event.type":                      "info",
						"event.dataset":                   "container.vulnerability.cluster",
						"event.module":                    "container_security",
						"api.endpoint":                    envResults.Deployment.APIBaseURL,
						"portal.url":                      envResults.Deployment.PortalURL,
						"aggregation.level":               "cluster",
					},
					"TraceId":    "",
					"SpanId":     "",
					"TraceFlags": 0,
				}

				data, _ := json.Marshal(clusterEntry)
				file.Write(data)
				file.WriteString("\n")
			}
		}
	}

	return nil
}

func generateTextReport(results map[string]*EnvironmentResults, outputFile string, overwrite bool, verbose bool) error {
	if verbose {
		fmt.Printf("\n%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING TEXT REPORT")
		fmt.Printf("%s\n\n", strings.Repeat("=", 70))
	}

	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("create output dir: %w", err)
		}
	}

	mode := os.O_CREATE | os.O_WRONLY
	if overwrite {
		mode |= os.O_TRUNC
	} else {
		mode |= os.O_APPEND
	}

	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return fmt.Errorf("open report file: %w", err)
	}
	defer file.Close()

	timestamp := time.Now().UTC().Format("2006-01-02 15:04:05")

	// Collect environment names for header
	var envNames []string
	for envName := range results {
		envNames = append(envNames, envName)
	}

	// Header
	fmt.Fprintf(file, "\n%s\n", strings.Repeat("=", 140))
	fmt.Fprintf(file, "TREND MICRO VISION ONE - CONTAINER SECURITY VULNERABILITY REPORT (DETAILED)\n")
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 140))
	fmt.Fprintf(file, "Generated: %s UTC\n", timestamp)
	fmt.Fprintf(file, "Environments Scanned: %s\n", strings.Join(envNames, ", "))
	fmt.Fprintf(file, "\n")
	fmt.Fprintf(file, "This report contains the same data as container_vulnerability_summary.csv\n")
	fmt.Fprintf(file, "Format: One row per cluster with all vulnerability metrics\n")
	fmt.Fprintf(file, "\n")

	// Table header (wider columns without Group Name)
	fmt.Fprintf(file, "%s\n", strings.Repeat("─", 140))
	fmt.Fprintf(file, "%-24s %-30s %-10s %-35s %-7s %-7s %-5s %-5s %-5s %-5s %-6s\n",
		"Environment", "Business Name", "Region", "Cluster Name", "Total", "Unique", "Crit", "High", "Med", "Low", "Risk")
	fmt.Fprintf(file, "%s\n", strings.Repeat("─", 140))

	// Calculate totals
	grandTotalVulns := 0
	grandUniqueCVEs := 0
	grandTotalCrit := 0
	grandTotalHigh := 0
	grandTotalMed := 0
	grandTotalLow := 0
	totalClusters := 0

	// Collect all clusters with their vulnerabilities
	type ClusterWithStats struct {
		EnvResults *EnvironmentResults
		Cluster    *ClusterInfo
		Vulns      []*ContainerVulnerability
	}
	var allClusters []ClusterWithStats

	for _, envResults := range results {
		for _, groupResult := range envResults.GroupResults {
			for _, cluster := range groupResult.Clusters {
				// Filter vulnerabilities for this cluster
				var clusterVulns []*ContainerVulnerability
				for _, vuln := range groupResult.Vulns {
					if vuln.ClusterID == cluster.ID {
						clusterVulns = append(clusterVulns, vuln)
					}
				}

				allClusters = append(allClusters, ClusterWithStats{
					EnvResults: envResults,
					Cluster:    cluster,
					Vulns:      clusterVulns,
				})
			}
		}
	}

	// Display results sorted by cluster name
	lastEnv := ""
	for _, clusterData := range allClusters {
		stats := analyzeVulnerabilities(clusterData.Vulns)

		// Add blank line between environments
		if lastEnv != "" && lastEnv != clusterData.EnvResults.EnvLabel {
			fmt.Fprintf(file, "\n")
		}
		lastEnv = clusterData.EnvResults.EnvLabel

		// Print row
		fmt.Fprintf(file, "%-24s %-30s %-10s %-35s %-7d %-7d %-5d %-5d %-5d %-5d %-6d\n",
			truncateString(clusterData.EnvResults.EnvLabel, 24),
			truncateString(clusterData.EnvResults.Deployment.BusinessName, 30),
			truncateString(clusterData.EnvResults.Deployment.Region, 10),
			truncateString(clusterData.Cluster.Name, 35),
			stats.Total,
			stats.UniqueCVEs,
			stats.Critical,
			stats.High,
			stats.Medium,
			stats.Low,
			stats.RiskScore,
		)

		// Update totals
		grandTotalVulns += stats.Total
		grandUniqueCVEs += stats.UniqueCVEs
		grandTotalCrit += stats.Critical
		grandTotalHigh += stats.High
		grandTotalMed += stats.Medium
		grandTotalLow += stats.Low
		totalClusters++
	}
	fmt.Fprintf(file, "\n")

	// Summary
	fmt.Fprintf(file, "%s\n", strings.Repeat("─", 140))
	fmt.Fprintf(file, "Total Clusters: %d\n", totalClusters)
	fmt.Fprintf(file, "Total Vulnerabilities: %d (Unique CVEs, sum per cluster: %d | Critical: %d, High: %d, Medium: %d, Low: %d)\n",
		grandTotalVulns, grandUniqueCVEs, grandTotalCrit, grandTotalHigh, grandTotalMed, grandTotalLow)
	fmt.Fprintf(file, "%s\n", strings.Repeat("─", 140))
	fmt.Fprintf(file, "\n")

	// Additional Details Section
	fmt.Fprintf(file, "ADDITIONAL DETAILS:\n\n")
	for _, envResults := range results {
		fmt.Fprintf(file, "Environment: %s\n", envResults.EnvLabel)
		fmt.Fprintf(file, "  Business Name: %s\n", envResults.Deployment.BusinessName)
		fmt.Fprintf(file, "  Business ID:   %s\n", envResults.Deployment.BusinessID)
		fmt.Fprintf(file, "  Region:        %s (%s)\n", getRegionFullName(envResults.Deployment.Region), envResults.Deployment.Region)
		fmt.Fprintf(file, "  Portal URL:    %s\n", envResults.Deployment.PortalURL)
		fmt.Fprintf(file, "  API Base URL:  %s\n", envResults.Deployment.APIBaseURL)
		fmt.Fprintf(file, "\n")
	}

	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 97))
	fmt.Fprintf(file, "END OF DETAILED REPORT\n")
	fmt.Fprintf(file, "%s\n\n", strings.Repeat("=", 97))

	if verbose {
		fmt.Printf("✅ Report %s to: %s\n\n", map[bool]string{true: "written", false: "appended"}[overwrite], outputFile)
	}

	return nil
}

// resolveOutputPath joins outputDir with path if outputDir is set; otherwise returns path.
func resolveOutputPath(outputDir, path string) string {
	if outputDir == "" {
		return path
	}
	return filepath.Join(outputDir, filepath.Base(path))
}

// truncateString truncates a string to the specified length
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-2] + ".."
}

// getRegionFullName returns the full region name
func getRegionFullName(region string) string {
	regionMap := map[string]string{
		"us": "United States (Global)",
		"au": "Australia",
		"eu": "Europe",
		"in": "India",
		"sg": "Singapore",
		"jp": "Japan",
	}
	if fullName, ok := regionMap[region]; ok {
		return fullName
	}
	return region
}
