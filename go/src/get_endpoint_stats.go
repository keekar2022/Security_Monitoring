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

// OATDetection represents an Observed Attack Technique detection
type OATDetection struct {
	DetectedDateTime string                 `json:"detectedDateTime"`
	Endpoint         map[string]interface{} `json:"endpoint"`
	Detail           map[string]interface{} `json:"detail"`
	Filters          []map[string]interface{} `json:"filters"`
	EntityType       string                 `json:"entityType"`
	Source           string                 `json:"source"`
}

// EndpointInfo holds endpoint inventory and statistics
type EndpointInfo struct {
	GUID                  string
	Name                  string
	IPs                   []string
	MACAddresses          []string
	OSName                string
	OSVersion             string
	OSDescription         string
	ProductName           string
	ProductVersion        string
	DetectionCount        int
	DetectionCritical     int
	DetectionHigh         int
	DetectionMedium       int
	DetectionLow          int
	DetectionInfo         int
	EntityTypes           []string
	Sources               []string
	MITRETactics          []string
	MITRETechniques       []string
	FirstSeen             string
	LastSeen              string
	RiskScore             int
}

func main() {
	// Command-line flags
	environment := flag.String("environment", "", "Environment to scan (production, production_au)")
	output := flag.String("output", "endpoint_inventory_report.txt", "Output text file")
	csvOutput := flag.String("csv-output", "endpoint_inventory_summary.csv", "Output CSV file")
	otelOutput := flag.String("otel-output", "endpoint_inventory_metrics.jsonl", "Output JSONL file")
	outputDir := flag.String("output-dir", "data", "Directory for all output files (paths relative to this)")
	quiet := flag.Bool("quiet", false, "Suppress progress messages")
	summaryOnly := flag.Bool("summary-only", false, "Display summary to console only (no files)")
	
	flag.Parse()

	// OpenTelemetry-compliant structured logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	logger.Info("Starting endpoint inventory scan",
		slog.String("service.name", "trend-vision-one-endpoint-inventory"),
		slog.String("service.version", "2.0.0"),
		slog.String("operation", "extract_inventory"),
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
		os.Exit(1)
	}

	if !*quiet {
		fmt.Printf("🌍 Scanning environments: %s\n\n", strings.Join(environments, ", "))
	}

	// Scan each environment
	allEndpoints := make(map[string]map[string]*EndpointInfo)
	
	for _, env := range environments {
		if !*quiet {
			fmt.Printf("\n╔%s╗\n", strings.Repeat("═", 76))
			fmt.Printf("║  ENVIRONMENT: %-61s  ║\n", strings.ToUpper(env))
			fmt.Printf("╚%s╝\n\n", strings.Repeat("═", 76))
		}

		// Fetch OAT detections
		detections, err := fetchOATDetections(config, env, !*quiet)
		if err != nil {
			logger.Error("Failed to fetch OAT detections",
				slog.String("environment", env),
				slog.String("error", err.Error()),
			)
			continue
		}

		if len(detections) == 0 {
			if !*quiet {
				fmt.Println("⚠️  No detections found")
			}
			continue
		}

		// Extract endpoint inventory
		endpoints := extractEndpointInventory(detections, !*quiet)
		allEndpoints[env] = endpoints

		if !*summaryOnly {
			// Resolve output paths under output-dir
			csvPath := resolveOutputPath(*outputDir, *csvOutput)
			txtPath := resolveOutputPath(*outputDir, *output)
			otelPath := resolveOutputPath(*outputDir, *otelOutput)

			// Generate outputs
			if err := writeCSVSummary(config, env, endpoints, csvPath, !*quiet); err != nil {
				logger.Error("Failed to write CSV",
					slog.String("error", err.Error()),
				)
			}

			if err := writeTextReport(config, env, endpoints, txtPath, !*quiet); err != nil {
				logger.Error("Failed to write text report",
					slog.String("error", err.Error()),
				)
			}

			if err := writeOTelLogs(config, env, endpoints, otelPath, !*quiet); err != nil {
				logger.Error("Failed to write OTel logs",
					slog.String("error", err.Error()),
				)
			}
		}
	}

	// Print overall summary
	if !*quiet {
		printOverallSummary(config, allEndpoints)
	}

	logger.Info("Endpoint inventory scan completed",
		slog.String("service.name", "trend-vision-one-endpoint-inventory"),
		slog.Int("environments_scanned", len(allEndpoints)),
	)
}

func fetchOATDetections(config *lib.TrendMicroConfig, env string, verbose bool) ([]*OATDetection, error) {
	baseURL, err := config.GetAPIBaseURL(env)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("%s/v3.0/oat/detections", baseURL)
	headers, err := config.GetCommonHeaders(env, true)
	if err != nil {
		return nil, err
	}

	if verbose {
		deployment, _ := config.GetDeploymentInfo(env)
		envLabel, _ := config.GetEnvironmentLabel(env)
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Println("FETCHING ENDPOINT DATA FROM OAT DETECTIONS")
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Printf("Environment: %s\n", envLabel)
		fmt.Printf("Business: %s\n", deployment.BusinessName)
		fmt.Printf("Region: %s (%s)\n", deployment.RegionName, deployment.Region)
		fmt.Printf("API: %s\n\n", endpoint)
	}

	var allDetections []*OATDetection
	nextURL := endpoint
	pageNum := 0

	client := &http.Client{Timeout: 60 * time.Second}

	for nextURL != "" {
		pageNum++
		
		if verbose {
			fmt.Printf("  Fetching page %d... ", pageNum)
		}

		req, err := http.NewRequest("GET", nextURL, nil)
		if err != nil {
			return nil, err
		}

		for key, value := range headers {
			req.Header.Set(key, value)
		}

		resp, err := client.Do(req)
		if err != nil {
			if verbose {
				fmt.Printf("❌ %v\n", err)
			}
			return nil, err
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			if verbose {
				fmt.Printf("❌ HTTP %d\n", resp.StatusCode)
			}
			return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
		}

		var response struct {
			Items    []*OATDetection `json:"items"`
			NextLink string          `json:"nextLink"`
		}

		if err := json.Unmarshal(body, &response); err != nil {
			if verbose {
				fmt.Printf("❌ JSON parse error\n")
			}
			return nil, err
		}

		allDetections = append(allDetections, response.Items...)
		
		if verbose {
			fmt.Printf("✅ %d detections\n", len(response.Items))
		}

		nextURL = response.NextLink
	}

	if verbose {
		fmt.Printf("\n✅ Collected %d detections from %d page(s)\n\n", len(allDetections), pageNum)
	}

	return allDetections, nil
}

func extractEndpointInventory(detections []*OATDetection, verbose bool) map[string]*EndpointInfo {
	if verbose {
		fmt.Println("Analyzing detections to extract endpoint inventory...")
	}

	endpoints := make(map[string]*EndpointInfo)

	for _, detection := range detections {
		endpointData := detection.Endpoint
		detailData := detection.Detail

		// Get unique identifier
		var agentGUID string
		if val, ok := endpointData["agentGuid"].(string); ok {
			agentGUID = val
		} else if val, ok := detailData["endpointGuid"].(string); ok {
			agentGUID = val
		}

		if agentGUID == "" {
			continue
		}

		// Initialize endpoint record if new
		if _, exists := endpoints[agentGUID]; !exists {
			endpointName := "Unknown"
			if val, ok := endpointData["endpointName"].(string); ok {
				endpointName = val
			} else if val, ok := detailData["endpointHostName"].(string); ok {
				endpointName = val
			}

			endpoints[agentGUID] = &EndpointInfo{
				GUID:            agentGUID,
				Name:            endpointName,
				IPs:             []string{},
				MACAddresses:    []string{},
				EntityTypes:     []string{},
				Sources:         []string{},
				MITRETactics:    []string{},
				MITRETechniques: []string{},
				FirstSeen:       detection.DetectedDateTime,
				LastSeen:        detection.DetectedDateTime,
			}

			if val, ok := detailData["osName"].(string); ok {
				endpoints[agentGUID].OSName = val
			}
			if val, ok := detailData["osVer"].(string); ok {
				endpoints[agentGUID].OSVersion = val
			}
			if val, ok := detailData["pname"].(string); ok {
				endpoints[agentGUID].ProductName = val
			}
			if val, ok := detailData["pver"].(string); ok {
				endpoints[agentGUID].ProductVersion = val
			}
		}

		endpoint := endpoints[agentGUID]

		// Update detection count
		endpoint.DetectionCount++

		// Count by risk level
		for _, filter := range detection.Filters {
			if riskLevel, ok := filter["riskLevel"].(string); ok {
				switch strings.ToLower(riskLevel) {
				case "critical":
					endpoint.DetectionCritical++
				case "high":
					endpoint.DetectionHigh++
				case "medium":
					endpoint.DetectionMedium++
				case "low":
					endpoint.DetectionLow++
				case "info":
					endpoint.DetectionInfo++
				}
			}
		}

		// Update timestamps
		if detection.DetectedDateTime < endpoint.FirstSeen {
			endpoint.FirstSeen = detection.DetectedDateTime
		}
		if detection.DetectedDateTime > endpoint.LastSeen {
			endpoint.LastSeen = detection.DetectedDateTime
		}

		// Calculate risk score
		endpoint.RiskScore = endpoint.DetectionCritical*10 +
			endpoint.DetectionHigh*5 +
			endpoint.DetectionMedium*2 +
			endpoint.DetectionLow*1
	}

	if verbose {
		fmt.Printf("✅ Extracted %d unique endpoints\n\n", len(endpoints))
	}

	return endpoints
}

// resolveOutputPath joins outputDir with path if outputDir is set; otherwise returns path.
func resolveOutputPath(outputDir, path string) string {
	if outputDir == "" {
		return path
	}
	return filepath.Join(outputDir, filepath.Base(path))
}

func writeCSVSummary(config *lib.TrendMicroConfig, env string, endpoints map[string]*EndpointInfo, outputFile string, verbose bool) error {
	if verbose {
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING CSV SUMMARY")
		fmt.Printf("%s\n", strings.Repeat("=", 70))
	}

	// Ensure parent directory exists
	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}

	deployment, err := config.GetDeploymentInfo(env)
	if err != nil {
		return err
	}
	
	envLabel, _ := config.GetEnvironmentLabel(env)

	fileExists := false
	if _, err := os.Stat(outputFile); err == nil {
		fileExists = true
	}

	mode := os.O_CREATE | os.O_WRONLY | os.O_APPEND
	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// Write header if new file
	if !fileExists {
		header := []string{"timestamp", "environment", "business_name", "region", "endpoint_guid", "endpoint_name",
			"ip_addresses", "os_name", "os_version", "product", "total_detections", "critical_detections",
			"high_detections", "medium_detections", "low_detections", "risk_score", "first_seen", "last_seen"}
		writer.Write(header)
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Sort endpoints by name
	var sortedEndpoints []*EndpointInfo
	for _, ep := range endpoints {
		sortedEndpoints = append(sortedEndpoints, ep)
	}
	sort.Slice(sortedEndpoints, func(i, j int) bool {
		return sortedEndpoints[i].Name < sortedEndpoints[j].Name
	})

	for _, ep := range sortedEndpoints {
		ips := strings.Join(ep.IPs, ", ")
		if len(ep.IPs) > 3 {
			ips = strings.Join(ep.IPs[:3], ", ")
		}
		
		product := fmt.Sprintf("%s v%s", ep.ProductName, ep.ProductVersion)

		row := []string{
			timestamp,
			envLabel,
			deployment.BusinessName,
			deployment.Region,
			ep.GUID,
			ep.Name,
			ips,
			ep.OSName,
			ep.OSVersion,
			product,
			fmt.Sprintf("%d", ep.DetectionCount),
			fmt.Sprintf("%d", ep.DetectionCritical),
			fmt.Sprintf("%d", ep.DetectionHigh),
			fmt.Sprintf("%d", ep.DetectionMedium),
			fmt.Sprintf("%d", ep.DetectionLow),
			fmt.Sprintf("%d", ep.RiskScore),
			ep.FirstSeen,
			ep.LastSeen,
		}
		writer.Write(row)
	}

	if verbose {
		fmt.Printf("✅ CSV summary appended to: %s\n", outputFile)
		fmt.Printf("   Rows written: %d\n", len(sortedEndpoints))
		fmt.Printf("   Timestamp: %s\n\n", timestamp)
	}

	return nil
}

func writeTextReport(config *lib.TrendMicroConfig, env string, endpoints map[string]*EndpointInfo, outputFile string, verbose bool) error {
	if verbose {
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING TEXT REPORT")
		fmt.Printf("%s\n", strings.Repeat("=", 70))
	}

	// Ensure parent directory exists
	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}

	deployment, err := config.GetDeploymentInfo(env)
	if err != nil {
		return err
	}

	mode := os.O_CREATE | os.O_WRONLY | os.O_APPEND
	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	timestamp := time.Now().UTC().Format("2006-01-02 15:04:05 UTC")

	fmt.Fprintf(file, "\n\n%s\n", strings.Repeat("=", 100))
	fmt.Fprintf(file, "TREND MICRO VISION ONE - ENDPOINT INVENTORY & STATISTICS REPORT\n")
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 100))
	envLabel, _ := config.GetEnvironmentLabel(env)
	
	fmt.Fprintf(file, "Generated: %s\n", timestamp)
	fmt.Fprintf(file, "Environment: %s\n", envLabel)
	fmt.Fprintf(file, "Business: %s\n", deployment.BusinessName)
	fmt.Fprintf(file, "Region: %s (%s)\n", deployment.RegionName, deployment.Region)
	fmt.Fprintf(file, "Data Source: OAT (Observed Attack Techniques) Detections\n\n")

	// Summary statistics
	totalEndpoints := len(endpoints)
	var totalDetections, totalCritical, totalHigh, totalMedium, totalLow int
	for _, ep := range endpoints {
		totalDetections += ep.DetectionCount
		totalCritical += ep.DetectionCritical
		totalHigh += ep.DetectionHigh
		totalMedium += ep.DetectionMedium
		totalLow += ep.DetectionLow
	}

	fmt.Fprintf(file, "SUMMARY\n")
	fmt.Fprintf(file, "%s\n", strings.Repeat("-", 100))
	fmt.Fprintf(file, "Total Endpoints:           %d\n", totalEndpoints)
	fmt.Fprintf(file, "Total Detections:          %d\n", totalDetections)
	fmt.Fprintf(file, "  Critical Risk:           %d\n", totalCritical)
	fmt.Fprintf(file, "  High Risk:               %d\n", totalHigh)
	fmt.Fprintf(file, "  Medium Risk:             %d\n", totalMedium)
	fmt.Fprintf(file, "  Low Risk:                %d\n\n", totalLow)

	// Sort endpoints by risk score
	var sortedEndpoints []*EndpointInfo
	for _, ep := range endpoints {
		sortedEndpoints = append(sortedEndpoints, ep)
	}
	sort.Slice(sortedEndpoints, func(i, j int) bool {
		if sortedEndpoints[i].RiskScore == sortedEndpoints[j].RiskScore {
			return sortedEndpoints[i].DetectionCount > sortedEndpoints[j].DetectionCount
		}
		return sortedEndpoints[i].RiskScore > sortedEndpoints[j].RiskScore
	})

	fmt.Fprintf(file, "ENDPOINT DETAILS\n")
	fmt.Fprintf(file, "%s\n", strings.Repeat("-", 100))
	fmt.Fprintf(file, "%-45s %-25s %12s %8s\n", "Endpoint Name", "OS", "Detections", "Risk")
	fmt.Fprintf(file, "%s\n", strings.Repeat("-", 100))

	for _, ep := range sortedEndpoints {
		name := ep.Name
		if len(name) > 43 {
			name = name[:43]
		}
		osInfo := fmt.Sprintf("%s %s", ep.OSName, ep.OSVersion)
		if len(osInfo) > 23 {
			osInfo = osInfo[:23]
		}

		detStr := fmt.Sprintf("%d", ep.DetectionCount)
		if ep.DetectionCritical > 0 || ep.DetectionHigh > 0 {
			detStr += fmt.Sprintf(" (%dC/%dH)", ep.DetectionCritical, ep.DetectionHigh)
		}

		fmt.Fprintf(file, "%-45s %-25s %12s %8d\n", name, osInfo, detStr, ep.RiskScore)
	}

	fmt.Fprintf(file, "%s\n\n", strings.Repeat("-", 100))
	fmt.Fprintf(file, "%s\n", strings.Repeat("=", 100))

	if verbose {
		fmt.Printf("✅ Report appended to: %s\n\n", outputFile)
	}

	return nil
}

func writeOTelLogs(config *lib.TrendMicroConfig, env string, endpoints map[string]*EndpointInfo, outputFile string, verbose bool) error {
	if verbose {
		fmt.Printf("%s\n", strings.Repeat("=", 70))
		fmt.Println("GENERATING OPENTELEMETRY LOGS")
		fmt.Printf("%s\n", strings.Repeat("=", 70))
	}

	// Ensure parent directory exists
	if dir := filepath.Dir(outputFile); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}

	deployment, err := config.GetDeploymentInfo(env)
	if err != nil {
		return err
	}

	mode := os.O_CREATE | os.O_WRONLY | os.O_APPEND
	file, err := os.OpenFile(outputFile, mode, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	timestamp := time.Now().UTC().Format(time.RFC3339)
	envLabel, _ := config.GetEnvironmentLabel(env)

	for _, ep := range endpoints {
		entry := map[string]interface{}{
			"Timestamp":                       timestamp,
			"service.name":                    "trend-vision-one-endpoint-inventory",
			"service.version":                 "2.0.0",
			"deployment.environment":          envLabel,
			"deployment.business":             deployment.BusinessName,
			"deployment.business_id":          deployment.BusinessID,
			"deployment.region":               deployment.Region,
			"event.dataset":                   "endpoint.inventory",
			"event.module":                    "oat_detections",
			"endpoint.guid":                   ep.GUID,
			"endpoint.name":                   ep.Name,
			"endpoint.ips":                    ep.IPs,
			"endpoint.os.name":                ep.OSName,
			"endpoint.os.version":             ep.OSVersion,
			"endpoint.product.name":           ep.ProductName,
			"endpoint.product.version":        ep.ProductVersion,
			"detections.total":                ep.DetectionCount,
			"detections.critical":             ep.DetectionCritical,
			"detections.high":                 ep.DetectionHigh,
			"detections.medium":               ep.DetectionMedium,
			"detections.low":                  ep.DetectionLow,
			"detections.risk_score":           ep.RiskScore,
			"endpoint.first_seen":             ep.FirstSeen,
			"endpoint.last_seen":              ep.LastSeen,
		}

		data, _ := json.Marshal(entry)
		file.Write(data)
		file.WriteString("\n")
	}

	if verbose {
		fmt.Printf("✅ OTel logs appended to: %s\n", outputFile)
		fmt.Printf("   Entries written: %d\n", len(endpoints))
		fmt.Printf("   Timestamp: %s\n\n", timestamp)
	}

	return nil
}

func printOverallSummary(config *lib.TrendMicroConfig, allEndpoints map[string]map[string]*EndpointInfo) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 70))
	fmt.Println("OVERALL SUMMARY")
	fmt.Printf("%s\n", strings.Repeat("=", 70))

	totalEndpoints := 0
	totalDetections := 0

	for _, endpoints := range allEndpoints {
		totalEndpoints += len(endpoints)
		for _, ep := range endpoints {
			totalDetections += ep.DetectionCount
		}
	}

	fmt.Printf("Total Endpoints Across All Environments: %d\n", totalEndpoints)
	fmt.Printf("Total Detections: %d\n\n", totalDetections)

	for env, endpoints := range allEndpoints {
		envLabel := ""
		if label, err := config.GetEnvironmentLabel(env); err == nil {
			envLabel = label
		} else {
			envLabel = env
		}
		detections := 0
		for _, ep := range endpoints {
			detections += ep.DetectionCount
		}
		fmt.Printf("  %-30s %5d endpoints, %6d detections\n", envLabel, len(endpoints), detections)
	}

	fmt.Printf("%s\n", strings.Repeat("=", 70))
}
