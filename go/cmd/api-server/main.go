package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	ServerVersion = "1.0.0"
	DefaultPort   = 8080
)

// MetricEntry represents a single JSONL metric entry
type MetricEntry map[string]interface{}

// DataCache holds cached JSONL data
type DataCache struct {
	ContainerVulnerabilities []MetricEntry
	EndpointInventory        []MetricEntry
	LastUpdated              time.Time
}

var (
	cache  *DataCache
	logger *slog.Logger
)

func main() {
	// Command-line flags
	port := flag.Int("port", DefaultPort, "Port to listen on")
	dataDir := flag.String("data-dir", "data", "Directory containing JSONL files")
	refreshInterval := flag.Duration("refresh", 5*time.Minute, "Cache refresh interval")
	
	flag.Parse()

	// Initialize OpenTelemetry-compliant logging
	logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Ensure data directory exists (for JSONL files produced by other binaries)
	if *dataDir != "" && *dataDir != "." {
		if err := os.MkdirAll(*dataDir, 0755); err != nil {
			logger.Error("Failed to create data directory",
				slog.String("error", err.Error()),
				slog.String("data_directory", *dataDir),
			)
			os.Exit(1)
		}
	}

	logger.Info("Starting Trend Micro Integration API Server",
		slog.String("service.name", "trend-micro-api-server"),
		slog.String("service.version", ServerVersion),
		slog.Int("port", *port),
		slog.String("data_directory", *dataDir),
	)

	// Initialize cache
	cache = &DataCache{}
	
	// Load initial data
	if err := refreshCache(*dataDir); err != nil {
		logger.Error("Failed to load initial data",
			slog.String("error", err.Error()),
		)
		os.Exit(1)
	}

	// Start background cache refresh
	go func() {
		ticker := time.NewTicker(*refreshInterval)
		defer ticker.Stop()
		
		for range ticker.C {
			if err := refreshCache(*dataDir); err != nil {
				logger.Error("Failed to refresh cache",
					slog.String("error", err.Error()),
				)
			}
		}
	}()

	// Setup HTTP routes
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/api/v1/metrics/container-vulnerabilities", containerVulnerabilitiesHandler)
	http.HandleFunc("/api/v1/metrics/endpoint-inventory", endpointInventoryHandler)
	http.HandleFunc("/api/v1/stats", statsHandler)
	http.HandleFunc("/", indexHandler)

	// Start server
	addr := fmt.Sprintf(":%d", *port)
	logger.Info("API server listening",
		slog.String("address", addr),
		slog.String("service.name", "trend-micro-api-server"),
	)

	if err := http.ListenAndServe(addr, loggingMiddleware(http.DefaultServeMux)); err != nil {
		logger.Error("Server failed",
			slog.String("error", err.Error()),
		)
		os.Exit(1)
	}
}

// refreshCache loads JSONL files into memory
func refreshCache(dataDir string) error {
	startTime := time.Now()
	
	logger.Info("Refreshing data cache",
		slog.String("data_directory", dataDir),
	)

	// Load container vulnerabilities
	containerFile := filepath.Join(dataDir, "container_vulnerability_metrics.jsonl")
	containerVulns, err := loadJSONLFile(containerFile)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to load container vulnerabilities: %w", err)
	}

	// Load endpoint inventory
	endpointFile := filepath.Join(dataDir, "endpoint_inventory_metrics.jsonl")
	endpointInv, err := loadJSONLFile(endpointFile)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to load endpoint inventory: %w", err)
	}

	// Update cache
	cache.ContainerVulnerabilities = containerVulns
	cache.EndpointInventory = endpointInv
	cache.LastUpdated = time.Now()

	duration := time.Since(startTime)
	logger.Info("Cache refreshed successfully",
		slog.Int("container_vulnerabilities_count", len(containerVulns)),
		slog.Int("endpoint_inventory_count", len(endpointInv)),
		slog.Duration("duration_ms", duration),
	)

	return nil
}

// loadJSONLFile reads a JSONL file and returns parsed entries
func loadJSONLFile(filepath string) ([]MetricEntry, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var entries []MetricEntry
	scanner := bufio.NewScanner(file)
	
	// Increase buffer size for large lines
	const maxCapacity = 1024 * 1024 // 1MB
	buf := make([]byte, maxCapacity)
	scanner.Buffer(buf, maxCapacity)

	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())
		
		if line == "" {
			continue
		}

		var entry MetricEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			logger.Warn("Failed to parse JSONL line",
				slog.String("file", filepath),
				slog.Int("line_number", lineNum),
				slog.String("error", err.Error()),
			)
			continue
		}

		entries = append(entries, entry)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return entries, nil
}

// loggingMiddleware logs HTTP requests
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()
		
		// Create custom response writer to capture status code
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(rw, r)
		
		duration := time.Since(startTime)
		
		logger.Info("HTTP request",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.String("remote_addr", r.RemoteAddr),
			slog.String("user_agent", r.UserAgent()),
			slog.Int("status_code", rw.statusCode),
			slog.Duration("duration_ms", duration),
		)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Health check endpoint
func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"status":       "healthy",
		"version":      ServerVersion,
		"timestamp":    time.Now().UTC().Format(time.RFC3339),
		"last_updated": cache.LastUpdated.Format(time.RFC3339),
		"data": map[string]int{
			"container_vulnerabilities": len(cache.ContainerVulnerabilities),
			"endpoint_inventory":        len(cache.EndpointInventory),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Container vulnerabilities endpoint
func containerVulnerabilitiesHandler(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	
	// Filter parameters
	environment := query.Get("environment")
	groupName := query.Get("group_name")
	clusterName := query.Get("cluster_name")
	limitStr := query.Get("limit")
	
	// Apply filters
	filtered := cache.ContainerVulnerabilities
	
	if environment != "" {
		filtered = filterByField(filtered, "Attributes.deployment.environment", environment)
	}
	
	if groupName != "" {
		filtered = filterByField(filtered, "Attributes.group.name", groupName)
	}
	
	if clusterName != "" {
		filtered = filterByField(filtered, "Attributes.cluster.name", clusterName)
	}
	
	// Sort by timestamp (most recent first)
	sort.Slice(filtered, func(i, j int) bool {
		ti := getTimestamp(filtered[i])
		tj := getTimestamp(filtered[j])
		return ti.After(tj)
	})
	
	// Apply limit
	if limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 && limit < len(filtered) {
			filtered = filtered[:limit]
		}
	}

	response := map[string]interface{}{
		"total":   len(filtered),
		"metrics": filtered,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Endpoint inventory endpoint
func endpointInventoryHandler(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	
	// Filter parameters
	environment := query.Get("environment")
	endpointName := query.Get("endpoint_name")
	limitStr := query.Get("limit")
	
	// Apply filters
	filtered := cache.EndpointInventory
	
	if environment != "" {
		filtered = filterByField(filtered, "deployment.environment", environment)
	}
	
	if endpointName != "" {
		filtered = filterByField(filtered, "endpoint.name", endpointName)
	}
	
	// Sort by timestamp (most recent first)
	sort.Slice(filtered, func(i, j int) bool {
		ti := getTimestamp(filtered[i])
		tj := getTimestamp(filtered[j])
		return ti.After(tj)
	})
	
	// Apply limit
	if limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 && limit < len(filtered) {
			filtered = filtered[:limit]
		}
	}

	response := map[string]interface{}{
		"total":   len(filtered),
		"metrics": filtered,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Stats endpoint - aggregated statistics
func statsHandler(w http.ResponseWriter, r *http.Request) {
	// Container vulnerability stats
	var totalVulns, totalCritical, totalHigh int
	environments := make(map[string]bool)
	groups := make(map[string]bool)
	
	for _, entry := range cache.ContainerVulnerabilities {
		if attrs, ok := entry["Attributes"].(map[string]interface{}); ok {
			if total, ok := attrs["vulnerability.total"].(float64); ok {
				totalVulns += int(total)
			}
			if crit, ok := attrs["vulnerability.severity.critical"].(float64); ok {
				totalCritical += int(crit)
			}
			if high, ok := attrs["vulnerability.severity.high"].(float64); ok {
				totalHigh += int(high)
			}
			if env, ok := attrs["deployment.environment"].(string); ok {
				environments[env] = true
			}
			if group, ok := attrs["group.name"].(string); ok {
				groups[group] = true
			}
		}
	}

	// Endpoint inventory stats
	totalEndpoints := len(cache.EndpointInventory)
	var totalDetections int
	endpointEnvs := make(map[string]bool)
	
	for _, entry := range cache.EndpointInventory {
		if total, ok := entry["detections.total"].(float64); ok {
			totalDetections += int(total)
		}
		if env, ok := entry["deployment.environment"].(string); ok {
			endpointEnvs[env] = true
		}
	}

	response := map[string]interface{}{
		"container_security": map[string]interface{}{
			"total_vulnerabilities": totalVulns,
			"critical":              totalCritical,
			"high":                  totalHigh,
			"environments":          len(environments),
			"groups":                len(groups),
		},
		"endpoint_inventory": map[string]interface{}{
			"total_endpoints":  totalEndpoints,
			"total_detections": totalDetections,
			"environments":     len(endpointEnvs),
		},
		"last_updated": cache.LastUpdated.Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Index endpoint - API documentation
func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	html := `<!DOCTYPE html>
<html>
<head>
	<title>Trend Micro Integration API</title>
	<style>
		body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
		h1 { color: #d71920; }
		h2 { color: #333; margin-top: 30px; }
		.endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
		.method { display: inline-block; padding: 3px 8px; background: #4CAF50; color: white; border-radius: 3px; font-weight: bold; }
		.path { font-family: monospace; font-size: 16px; }
		code { background: #eee; padding: 2px 5px; border-radius: 3px; }
		table { border-collapse: collapse; width: 100%; margin: 10px 0; }
		th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
		th { background: #f5f5f5; }
	</style>
</head>
<body>
	<h1>🔒 Trend Micro Integration API Server</h1>
	<p><strong>Version:</strong> ` + ServerVersion + `</p>
	<p><strong>Status:</strong> <span style="color: green;">✓ Running</span></p>
	<p><strong>Last Data Refresh:</strong> ` + cache.LastUpdated.Format("2006-01-02 15:04:05 UTC") + `</p>

	<h2>📊 Available Endpoints</h2>

	<div class="endpoint">
		<span class="method">GET</span> <span class="path">/health</span>
		<p>Health check and system status</p>
	</div>

	<div class="endpoint">
		<span class="method">GET</span> <span class="path">/api/v1/stats</span>
		<p>Aggregated statistics across all data sources</p>
	</div>

	<div class="endpoint">
		<span class="method">GET</span> <span class="path">/api/v1/metrics/container-vulnerabilities</span>
		<p>Container security vulnerability metrics</p>
		<p><strong>Query Parameters:</strong></p>
		<table>
			<tr><th>Parameter</th><th>Description</th><th>Example</th></tr>
			<tr><td><code>environment</code></td><td>Filter by environment</td><td>?environment=production</td></tr>
			<tr><td><code>group_name</code></td><td>Filter by group name</td><td>?group_name=MyGroup</td></tr>
			<tr><td><code>cluster_name</code></td><td>Filter by cluster name</td><td>?cluster_name=prod-cluster</td></tr>
			<tr><td><code>limit</code></td><td>Limit number of results</td><td>?limit=100</td></tr>
		</table>
	</div>

	<div class="endpoint">
		<span class="method">GET</span> <span class="path">/api/v1/metrics/endpoint-inventory</span>
		<p>Endpoint inventory and detection metrics</p>
		<p><strong>Query Parameters:</strong></p>
		<table>
			<tr><th>Parameter</th><th>Description</th><th>Example</th></tr>
			<tr><td><code>environment</code></td><td>Filter by environment</td><td>?environment=production</td></tr>
			<tr><td><code>endpoint_name</code></td><td>Filter by endpoint name</td><td>?endpoint_name=host01</td></tr>
			<tr><td><code>limit</code></td><td>Limit number of results</td><td>?limit=100</td></tr>
		</table>
	</div>

	<h2>💡 Example Usage</h2>
	<pre style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
# Get overall statistics
curl http://localhost:` + fmt.Sprintf("%d", DefaultPort) + `/api/v1/stats

# Get container vulnerabilities for production environment
curl http://localhost:` + fmt.Sprintf("%d", DefaultPort) + `/api/v1/metrics/container-vulnerabilities?environment=production&limit=10

# Get endpoint inventory
curl http://localhost:` + fmt.Sprintf("%d", DefaultPort) + `/api/v1/metrics/endpoint-inventory?limit=50

# Health check
curl http://localhost:` + fmt.Sprintf("%d", DefaultPort) + `/health
	</pre>

	<h2>📈 Current Data</h2>
	<table>
		<tr><th>Data Source</th><th>Records</th></tr>
		<tr><td>Container Vulnerabilities</td><td>` + fmt.Sprintf("%d", len(cache.ContainerVulnerabilities)) + `</td></tr>
		<tr><td>Endpoint Inventory</td><td>` + fmt.Sprintf("%d", len(cache.EndpointInventory)) + `</td></tr>
	</table>

	<footer style="margin-top: 50px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
		<p>Trend Micro Vision One Integration API • Built with Go</p>
	</footer>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

// Helper functions

func filterByField(entries []MetricEntry, fieldPath string, value string) []MetricEntry {
	var filtered []MetricEntry
	
	for _, entry := range entries {
		if getNestedField(entry, fieldPath) == value {
			filtered = append(filtered, entry)
		}
	}
	
	return filtered
}

func getNestedField(entry MetricEntry, fieldPath string) string {
	parts := strings.Split(fieldPath, ".")
	
	var current interface{} = entry
	for _, part := range parts {
		if m, ok := current.(map[string]interface{}); ok {
			current = m[part]
		} else {
			return ""
		}
	}
	
	if str, ok := current.(string); ok {
		return str
	}
	
	return ""
}

func getTimestamp(entry MetricEntry) time.Time {
	if ts, ok := entry["Timestamp"].(string); ok {
		if t, err := time.Parse(time.RFC3339, ts); err == nil {
			return t
		}
	}
	return time.Time{}
}
