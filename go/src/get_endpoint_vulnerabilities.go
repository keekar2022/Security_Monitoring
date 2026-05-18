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

// Device represents a managed endpoint/device
type Device struct {
	ID         string `json:"id"`
	GUID       string `json:"guid"`
	Name       string `json:"name"`
	Hostname   string `json:"hostname"`
	DeviceName string `json:"deviceName"` // attackSurfaceDevices API returns deviceName
}

// DeviceVulnerability represents a vulnerability on a device
type DeviceVulnerability struct {
	ID       string  `json:"id"`
	CVE      string  `json:"cve"`
	Severity string  `json:"severity"`
	Score    float64 `json:"score"`
}

// vulnerableDevicesResponse is the shape of /v3.0/asrm/vulnerableDevices (Get CVEs detected in a device)
type vulnerableDevicesResponse struct {
	Items    []vulnerableDeviceItem `json:"items"`
	NextLink string                 `json:"nextLink"`
}

type vulnerableDeviceItem struct {
	ID         string      `json:"id"`
	DeviceName string      `json:"deviceName"`
	CVERecords []cveRecord `json:"cveRecords"`
}

type cveRecord struct {
	ID             string  `json:"id"`
	CVSSScore      float64 `json:"cvssScore"`
	EventRiskLevel string  `json:"eventRiskLevel"`
}

// EnvResult holds devices and vulnerability data for one environment (used for CSV/JSONL/TXT after scan).
type EnvResult struct {
	EnvLabel    string
	Deployment  *lib.DeploymentConfig
	Devices     []*Device
	DeviceVulns map[string][]*DeviceVulnerability
}

func main() {
	// Command-line flags
	environment := flag.String("environment", "", "Environment to scan (production, production_au)")
	output := flag.String("output", "endpoint_vulnerability_report.txt", "TXT report output file")
	csvOutput := flag.String("csv-output", "endpoint_vulnerability_summary.csv", "CSV output file")
	otelOutput := flag.String("otel-output", "endpoint_vulnerability_metrics.jsonl", "JSONL/OTel output file")
	outputDir := flag.String("output-dir", "data", "Directory for all output files (paths relative to this)")
	noOtel := flag.Bool("no-otel", false, "Disable JSONL/OTel output")
	noCSV := flag.Bool("no-csv", false, "Disable CSV output")
	noTxt := flag.Bool("no-txt", false, "Disable TXT report output")
	overwrite := flag.Bool("overwrite", false, "Overwrite output files instead of appending (default: append)")
	quiet := flag.Bool("quiet", false, "Suppress progress messages")
	setupHelp := flag.Bool("setup-help", false, "Show setup instructions")
	top := flag.Int("top", 100, "Max results per API page (default: 100)")
	lookbackDays := flag.Int("lookback-days", 0, "Only include vulnerabilities from the last N days (0 = no date filter)")

	flag.Parse()

	if *setupHelp {
		printSetupInstructions()
		return
	}

	// OpenTelemetry-compliant structured logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	logger.Info("Starting endpoint vulnerability scan",
		slog.String("service.name", "trend-vision-one-endpoint-vulnerabilities"),
		slog.String("service.version", "1.0.0"),
		slog.String("operation", "scan_vulnerabilities"),
	)

	// Initialize configuration
	config, err := lib.NewTrendMicroConfig("", nil)
	if err != nil {
		logger.Error("Failed to initialize configuration",
			slog.String("error", err.Error()),
		)
		os.Exit(1)
	}

	// Determine environments to scan
	var environments []string
	if *environment != "" {
		environments = []string{*environment}
	} else {
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
	}

	if len(environments) == 0 {
		fmt.Println("❌ No environments configured with credentials.")
		fmt.Println("\nRun: go run get_endpoint_vulnerabilities.go --setup-help")
		fmt.Println("for setup instructions.")
		os.Exit(1)
	}

	if !*quiet {
		fmt.Printf("🌍 Scanning environments: %s\n\n", strings.Join(environments, ", "))
	}

	// Scan each environment and collect results for CSV/JSONL/TXT
	var allResults []*EnvResult
	anySuccess := false

	for _, env := range environments {
		if !*quiet {
			fmt.Printf("\n╔%s╗\n", strings.Repeat("═", 76))
			fmt.Printf("║  ENVIRONMENT: %-61s  ║\n", strings.ToUpper(env))
			fmt.Printf("╚%s╝\n\n", strings.Repeat("═", 76))
		}

		// Fetch devices
		devices, err := fetchAllDevices(config, env, !*quiet)
		if err != nil {
			logger.Error("Failed to fetch devices",
				slog.String("environment", env),
				slog.String("error", err.Error()),
			)
			continue
		}

		if len(devices) > 0 {
			anySuccess = true

			if !*quiet {
				fmt.Printf("\n  ✅ Found %d devices\n", len(devices))
				fmt.Println("\n  Fetching vulnerabilities for each device...")
			}

			// Fetch vulnerabilities for each device
			deviceVulns := make(map[string][]*DeviceVulnerability)

			for _, device := range devices {
				deviceID := device.ID
				if deviceID == "" {
					deviceID = device.GUID
				}
				deviceName := device.Name
				if deviceName == "" {
					deviceName = device.DeviceName
				}
				if deviceName == "" {
					deviceName = device.Hostname
				}

				if deviceID != "" {
					vulns, err := fetchVulnerabilitiesForDevice(config, env, deviceID, deviceName, !*quiet, *top, *lookbackDays)
					if err == nil {
						deviceVulns[deviceID] = vulns
					}
				}
			}

			deployment, _ := config.GetDeploymentInfo(env)
			envLabel, _ := config.GetEnvironmentLabel(env)
			allResults = append(allResults, &EnvResult{
				EnvLabel:    envLabel,
				Deployment:  deployment,
				Devices:     devices,
				DeviceVulns: deviceVulns,
			})
		} else {
			if !*quiet {
				fmt.Println("\n  ⚠️  No devices found or API access denied")
			}
		}
	}

	if !anySuccess {
		fmt.Printf("\n%s\n", strings.Repeat("=", 80))
		fmt.Println("❌ UNABLE TO FETCH DEVICE DATA")
		fmt.Printf("%s\n\n", strings.Repeat("=", 80))
		fmt.Println("This script requires additional API permissions that are")
		fmt.Println("not currently granted to your API role.")
		fmt.Println()
		fmt.Println("Run with --setup-help flag for detailed setup instructions:")
		fmt.Println("  go run get_endpoint_vulnerabilities.go --setup-help")
		fmt.Println()
		os.Exit(1)
	}

	// Resolve output paths and generate all three formats: CSV, JSONL, TXT
	csvPath := resolveOutputPath(*outputDir, *csvOutput)
	txtPath := resolveOutputPath(*outputDir, *output)
	otelPath := resolveOutputPath(*outputDir, *otelOutput)

	if !*noCSV {
		if err := generateCSVSummary(allResults, csvPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate CSV", slog.String("error", err.Error()), slog.String("path", csvPath))
		} else if !*quiet {
			fmt.Printf("✅ CSV: %s\n", csvPath)
		}
	}
	if !*noOtel {
		if err := writeOTelLogsAll(allResults, otelPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate JSONL/OTel", slog.String("error", err.Error()), slog.String("path", otelPath))
		} else if !*quiet {
			fmt.Printf("✅ JSONL (OTel): %s\n", otelPath)
		}
	}
	if !*noTxt {
		if err := generateTextReportAll(allResults, txtPath, *overwrite, !*quiet); err != nil {
			logger.Error("Failed to generate TXT report", slog.String("error", err.Error()), slog.String("path", txtPath))
		} else if !*quiet {
			fmt.Printf("✅ TXT report: %s\n", txtPath)
		}
	}

	logger.Info("Endpoint vulnerability scan completed",
		slog.String("service.name", "trend-vision-one-endpoint-vulnerabilities"),
	)
}

func fetchAllDevices(config *lib.TrendMicroConfig, env string, verbose bool) ([]*Device, error) {
	baseURL, err := config.GetAPIBaseURL(env)
	if err != nil {
		return nil, err
	}

	// Get discovered devices (per UMA / current API docs)
	// V3.0: /v3.0/asrm/attackSurfaceDevices (Beta equivalent: /beta/xdr/riskInsights/attackSurfaceDevices)
	deviceEndpoints := []string{
		"/v3.0/asrm/attackSurfaceDevices",
	}

	headers, err := config.GetCommonHeaders(env, true)
	if err != nil {
		return nil, err
	}

	if verbose {
		deployment, _ := config.GetDeploymentInfo(env)
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Println("FETCHING MANAGED DEVICES/ENDPOINTS")
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Printf("Business: %s\n", deployment.BusinessName)
		fmt.Printf("Region: %s (%s)\n", deployment.RegionName, deployment.Region)
		fmt.Printf("API Base: %s\n\n", baseURL)
	}

	client := &http.Client{Timeout: 60 * time.Second}

	// Try each endpoint
	for _, endpoint := range deviceEndpoints {
		url := fmt.Sprintf("%s%s", baseURL, endpoint)

		if verbose {
			fmt.Printf("Trying: %s... ", endpoint)
		}

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			continue
		}

		q := req.URL.Query()
		q.Add("top", "100")
		req.URL.RawQuery = q.Encode()

		for key, value := range headers {
			req.Header.Set(key, value)
		}

		resp, err := client.Do(req)
		if err != nil {
			if verbose {
				fmt.Printf("❌ Error: %v\n", err)
			}
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			if verbose {
				fmt.Println("✅ Success!")
			}

			var response struct {
				Items    []*Device `json:"items"`
				NextLink string    `json:"nextLink"`
			}

			if err := json.Unmarshal(body, &response); err != nil {
				continue
			}

			devices := response.Items

			if verbose {
				fmt.Printf("  Found %d devices\n", len(devices))
			}

			// Handle pagination
			nextLink := response.NextLink
			pageCount := 1
			for nextLink != "" {
				pageCount++
				req, _ := http.NewRequest("GET", nextLink, nil)
				for key, value := range headers {
					req.Header.Set(key, value)
				}

				resp, err := client.Do(req)
				if err != nil {
					break
				}

				body, _ := io.ReadAll(resp.Body)
				resp.Body.Close()

				if resp.StatusCode != http.StatusOK {
					break
				}

				if err := json.Unmarshal(body, &response); err != nil {
					break
				}

				devices = append(devices, response.Items...)
				nextLink = response.NextLink

				if verbose {
					fmt.Printf("  Fetched page %d: +%d devices\n", pageCount, len(response.Items))
				}
			}

			return devices, nil
		} else if resp.StatusCode == http.StatusForbidden {
			if verbose {
				fmt.Println("⚠️  Forbidden - Need permissions")
			}
		} else if resp.StatusCode == http.StatusNotFound {
			if verbose {
				fmt.Println("❌ Not Found")
			}
		} else {
			if verbose {
				fmt.Printf("❌ HTTP %d\n", resp.StatusCode)
			}
		}
	}

	// If we get here, no endpoint worked
	if verbose {
		fmt.Println("\n❌ ERROR: Unable to fetch devices from any endpoint.")
		fmt.Println("\nRequired Permissions:")
		fmt.Println("  • Attack Surface Risk Management → View")
		fmt.Println("  • Endpoint Inventory → View")
		fmt.Println()
	}

	return []*Device{}, nil
}

// fetchVulnerabilitiesForDevice uses Get CVEs detected in a device (per UMA / current API docs):
// V3.0: GET /v3.0/asrm/vulnerableDevices with TMV1-Filter: id eq '<deviceID>' in header.
func fetchVulnerabilitiesForDevice(config *lib.TrendMicroConfig, env string, deviceID string, deviceName string, verbose bool, top int, lookbackDays int) ([]*DeviceVulnerability, error) {
	baseURL, err := config.GetAPIBaseURL(env)
	if err != nil {
		return nil, err
	}

	headers, err := config.GetCommonHeaders(env, true)
	if err != nil {
		return nil, err
	}

	endpoint := "/v3.0/asrm/vulnerableDevices"
	url := baseURL + endpoint

	// ASRM vulnerableDevices API does not support firstDetectedDateTime in TMV1-Filter;
	// filtering by date returns empty. Use only device id filter. top and lookbackDays
	// are kept for CLI consistency; lookback-days applies to container scan only.
	if top <= 0 {
		top = 100
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	q := req.URL.Query()
	q.Add("top", fmt.Sprintf("%d", top))
	req.URL.RawQuery = q.Encode()

	for key, value := range headers {
		req.Header.Set(key, value)
	}
	req.Header.Set("TMV1-Filter", fmt.Sprintf("id eq '%s'", deviceID))

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return []*DeviceVulnerability{}, nil
	}

	var apiResp vulnerableDevicesResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return []*DeviceVulnerability{}, nil
	}

	var vulns []*DeviceVulnerability
	for _, item := range apiResp.Items {
		for _, rec := range item.CVERecords {
			severity := rec.EventRiskLevel
			if severity == "" {
				severity = severityFromScore(rec.CVSSScore)
			}
			vulns = append(vulns, &DeviceVulnerability{
				ID:       rec.ID,
				CVE:      rec.ID,
				Severity: severity,
				Score:    rec.CVSSScore,
			})
		}
	}

	// Pagination: follow nextLink if present
	nextLink := apiResp.NextLink
	for nextLink != "" {
		req, _ := http.NewRequest("GET", nextLink, nil)
		for key, value := range headers {
			req.Header.Set(key, value)
		}
		resp, err := client.Do(req)
		if err != nil {
			break
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			break
		}
		if err := json.Unmarshal(body, &apiResp); err != nil {
			break
		}
		for _, item := range apiResp.Items {
			for _, rec := range item.CVERecords {
				severity := rec.EventRiskLevel
				if severity == "" {
					severity = severityFromScore(rec.CVSSScore)
				}
				vulns = append(vulns, &DeviceVulnerability{
					ID:       rec.ID,
					CVE:      rec.ID,
					Severity: severity,
					Score:    rec.CVSSScore,
				})
			}
		}
		nextLink = apiResp.NextLink
	}

	if verbose && len(vulns) > 0 {
		fmt.Printf("    • %s: %d vulnerabilities\n", deviceName, len(vulns))
	}

	return vulns, nil
}

func severityFromScore(score float64) string {
	switch {
	case score >= 9.0:
		return "critical"
	case score >= 7.0:
		return "high"
	case score >= 4.0:
		return "medium"
	case score >= 0.1:
		return "low"
	default:
		return "info"
	}
}

func analyzeVulnerabilities(vulns []*DeviceVulnerability) map[string]int {
	counts := map[string]int{
		"total":    len(vulns),
		"critical": 0,
		"high":     0,
		"medium":   0,
		"low":      0,
		"info":     0,
	}

	for _, vuln := range vulns {
		severity := strings.ToLower(vuln.Severity)
		if _, exists := counts[severity]; exists {
			counts[severity]++
		}
	}

	counts["risk_score"] = counts["critical"]*10 + counts["high"]*5 + counts["medium"]*2 + counts["low"]*1

	return counts
}

func resolveOutputPath(outputDir, path string) string {
	if outputDir == "" {
		return path
	}
	return filepath.Join(outputDir, filepath.Base(path))
}

func generateCSVSummary(results []*EnvResult, outputFile string, overwrite bool, verbose bool) error {
	if verbose {
		fmt.Printf("\n%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING CSV SUMMARY")
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
		return fmt.Errorf("open CSV file: %w", err)
	}
	defer file.Close()
	writer := csv.NewWriter(file)
	defer writer.Flush()
	fileInfo, err := file.Stat()
	if err != nil {
		return fmt.Errorf("stat output file: %w", err)
	}
	if fileInfo.Size() == 0 {
		header := []string{"Timestamp", "Environment", "Business Name", "Region", "Device ID", "Device Name",
			"Total", "Critical", "High", "Medium", "Low", "Risk Score"}
		if err := writer.Write(header); err != nil {
			return fmt.Errorf("write CSV header: %w", err)
		}
	}
	timestamp := time.Now().UTC().Format(time.RFC3339)
	type csvRow struct {
		envLabel   string
		business   string
		region     string
		deviceID   string
		deviceName string
		stats      map[string]int
	}
	var rows []csvRow
	for _, res := range results {
		region := ""
		business := ""
		if res.Deployment != nil {
			region = res.Deployment.Region
			business = res.Deployment.BusinessName
		}
		for _, device := range res.Devices {
			deviceID := device.ID
			if deviceID == "" {
				deviceID = device.GUID
			}
			deviceName := device.Name
			if deviceName == "" {
				deviceName = device.DeviceName
			}
			if deviceName == "" {
				deviceName = device.Hostname
			}
			vulns := res.DeviceVulns[deviceID]
			rows = append(rows, csvRow{
				res.EnvLabel,
				business,
				region,
				deviceID,
				deviceName,
				analyzeVulnerabilities(vulns),
			})
		}
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].envLabel != rows[j].envLabel {
			return rows[i].envLabel < rows[j].envLabel
		}
		return rows[i].deviceName < rows[j].deviceName
	})
	for _, r := range rows {
		row := []string{
			timestamp,
			r.envLabel,
			r.business,
			r.region,
			r.deviceID,
			r.deviceName,
			fmt.Sprintf("%d", r.stats["total"]),
			fmt.Sprintf("%d", r.stats["critical"]),
			fmt.Sprintf("%d", r.stats["high"]),
			fmt.Sprintf("%d", r.stats["medium"]),
			fmt.Sprintf("%d", r.stats["low"]),
			fmt.Sprintf("%d", r.stats["risk_score"]),
		}
		if err := writer.Write(row); err != nil {
			return fmt.Errorf("write CSV row: %w", err)
		}
	}
	return nil
}

func writeOTelLogsAll(results []*EnvResult, outputFile string, overwrite bool, verbose bool) error {
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
	for _, res := range results {
		for _, device := range res.Devices {
			deviceID := device.ID
			if deviceID == "" {
				deviceID = device.GUID
			}
			deviceName := device.Name
			if deviceName == "" {
				deviceName = device.DeviceName
			}
			if deviceName == "" {
				deviceName = device.Hostname
			}
			vulns := res.DeviceVulns[deviceID]
			stats := analyzeVulnerabilities(vulns)
			businessName, businessID, region := "", "", ""
			if res.Deployment != nil {
				businessName = res.Deployment.BusinessName
				businessID = res.Deployment.BusinessID
				region = res.Deployment.Region
			}
			entry := map[string]interface{}{
				"Timestamp":                timestamp,
				"service.name":             "trend-vision-one-endpoint-vulnerabilities",
				"service.version":          "1.0.0",
				"deployment.environment":   res.EnvLabel,
				"deployment.business":      businessName,
				"deployment.business_id":   businessID,
				"deployment.region":        region,
				"event.dataset":            "endpoint.vulnerabilities",
				"event.module":             "asrm_vulnerable_devices",
				"device.id":                deviceID,
				"device.name":              deviceName,
				"vulnerability.total":      stats["total"],
				"vulnerability.critical":   stats["critical"],
				"vulnerability.high":       stats["high"],
				"vulnerability.medium":     stats["medium"],
				"vulnerability.low":        stats["low"],
				"vulnerability.risk_score": stats["risk_score"],
			}
			data, _ := json.Marshal(entry)
			file.Write(data)
			file.WriteString("\n")
		}
	}
	return nil
}

func generateTextReportAll(results []*EnvResult, outputFile string, overwrite bool, verbose bool) error {
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
	timestamp := time.Now().UTC().Format("2006-01-02 15:04:05 UTC")
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 100))
	fmt.Fprintf(file, "TREND MICRO VISION ONE - ENDPOINT/DEVICE VULNERABILITY REPORT\n")
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 100))
	fmt.Fprintf(file, "Generated: %s\n", timestamp)
	fmt.Fprintf(file, "Environments: %d\n\n", len(results))
	for _, res := range results {
		fmt.Fprintf(file, "%s\n", strings.Repeat("-", 100))
		fmt.Fprintf(file, "Environment: %s\n", res.EnvLabel)
		if res.Deployment != nil {
			fmt.Fprintf(file, "Business: %s\n", res.Deployment.BusinessName)
			fmt.Fprintf(file, "Region: %s (%s)\n\n", res.Deployment.RegionName, res.Deployment.Region)
		} else {
			fmt.Fprintf(file, "Business: -\nRegion: -\n\n")
		}
		totalDevices := len(res.Devices)
		totalVulns := 0
		for _, vulns := range res.DeviceVulns {
			totalVulns += len(vulns)
		}
		fmt.Fprintf(file, "Total Devices: %d  |  Total Vulnerabilities: %d\n\n", totalDevices, totalVulns)
		if len(res.Devices) == 0 {
			fmt.Fprintf(file, "⚠️  NO DEVICES FOUND\n\n")
			continue
		}
		fmt.Fprintf(file, "%-40s %8s %6s %6s %6s %6s %8s\n",
			"Device Name", "Total", "Crit", "High", "Med", "Low", "Risk")
		fmt.Fprintf(file, "%s\n", strings.Repeat("-", 100))
		for _, device := range res.Devices {
			deviceID := device.ID
			if deviceID == "" {
				deviceID = device.GUID
			}
			deviceName := device.Name
			if deviceName == "" {
				deviceName = device.DeviceName
			}
			if deviceName == "" {
				deviceName = device.Hostname
			}
			vulns := res.DeviceVulns[deviceID]
			stats := analyzeVulnerabilities(vulns)
			nameShort := deviceName
			if len(nameShort) > 38 {
				nameShort = nameShort[:38]
			}
			fmt.Fprintf(file, "%-40s %8d %6d %6d %6d %6d %8d\n",
				nameShort, stats["total"], stats["critical"], stats["high"], stats["medium"], stats["low"], stats["risk_score"])
		}
		fmt.Fprintf(file, "\n")
	}
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 100))
	if len(results) > 0 && results[0].Deployment != nil && results[0].Deployment.PortalURL != "" {
		fmt.Fprintf(file, "Portal: %s\n", results[0].Deployment.PortalURL)
	}
	fmt.Fprintf(file, "API Documentation: https://automation.trendmicro.com/xdr/api-v3/\n")
	fmt.Fprintf(file, "%s\n\n", strings.Repeat("=", 100))
	return nil
}

func printSetupInstructions() {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Println("SETUP REQUIRED: Device Vulnerabilities API Access")
	fmt.Printf("%s\n\n", strings.Repeat("=", 80))
	fmt.Println("The current API role does not have access to Device Vulnerability data.")
	fmt.Println()
	fmt.Println("STEP 1: Update API Role Permissions")
	fmt.Printf("%s\n", strings.Repeat("-", 80))
	fmt.Println("1. Log into Trend Vision One console:")
	fmt.Println("   • https://portal.xdr.trendmicro.com/ (US/Global)")
	fmt.Println("   • https://portal.au.xdr.trendmicro.com/ (Australia)")
	fmt.Println()
	fmt.Println("2. Navigate to: Administration → User Roles")
	fmt.Println()
	fmt.Println("3. Edit your API custom role")
	fmt.Println()
	fmt.Println("4. Add the following permissions:")
	fmt.Println("   ✅ Attack Surface Risk Management → View")
	fmt.Println("   ✅ Endpoint Inventory → View")
	fmt.Println("   ✅ Risk Insights → View")
	fmt.Println()
	fmt.Println("5. Save the role and wait 5 minutes for changes to propagate")
	fmt.Printf("%s\n\n", strings.Repeat("=", 80))
}
