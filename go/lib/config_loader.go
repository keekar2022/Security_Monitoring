package lib

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// DeploymentConfig represents the deployment configuration
type DeploymentConfig struct {
	BusinessName string `json:"business_name"`
	BusinessID   string `json:"business_id"`
	Region       string `json:"region"`
	RegionName   string `json:"region_name"`
	APIBaseURL   string `json:"api_base_url"`
	PortalURL    string `json:"portal_url"`
}

// APICredentials represents API credentials
type APICredentials struct {
	APIToken  string `json:"api_token"`
	ExpiresAt int64  `json:"expires_at"`
}

// EnvironmentConfig represents a single environment configuration
type EnvironmentConfig struct {
	Deployment     DeploymentConfig `json:"deployment"`
	APICredentials APICredentials   `json:"api_credentials"`
}

// DeploymentConfigFile represents the deployment_config.json structure
type DeploymentConfigFile struct {
	CurrentEnvironment string                        `json:"current_environment"`
	Environments       map[string]EnvironmentConfig  `json:"environments"`
}

// EnvironmentInfo represents environment information
type EnvironmentInfo struct {
	Name            string `json:"name"`
	Region          string `json:"region"`
	APIBaseURL      string `json:"api_base_url"`
	PortalURL       string `json:"portal_url"`
	EnvironmentLabel string `json:"environment_label"`
}

// EnvironmentsFile represents the environments.json structure
type EnvironmentsFile struct {
	CurrentEnvironment string                     `json:"current_environment"`
	Environments       map[string]EnvironmentInfo `json:"environments"`
}

// TrendMicroConfig manages configuration loading
type TrendMicroConfig struct {
	configDir   string
	usePass     bool
	credentials *DeploymentConfigFile
	environments *EnvironmentsFile
}

// NewTrendMicroConfig creates a new configuration loader
func NewTrendMicroConfig(configDir string, usePass *bool) (*TrendMicroConfig, error) {
	config := &TrendMicroConfig{}
	
	// Set config directory
	if configDir != "" {
		config.configDir = configDir
	} else {
		// Default to ../config relative to current directory
		cwd, err := os.Getwd()
		if err != nil {
			return nil, fmt.Errorf("failed to get working directory: %w", err)
		}
		config.configDir = filepath.Join(cwd, "config")
	}
	
	// Determine if we should use pass
	if usePass != nil {
		config.usePass = *usePass
	} else {
		envUsePass := strings.ToLower(os.Getenv("USE_PASS"))
		if envUsePass == "true" || envUsePass == "1" || envUsePass == "yes" {
			config.usePass = true
		} else if envUsePass == "false" || envUsePass == "0" || envUsePass == "no" {
			config.usePass = false
		} else {
			// Auto-detect: use pass if available
			config.usePass = isPassAvailable()
		}
	}
	
	slog.Debug("TrendMicroConfig initialized",
		slog.String("service.name", "trend-micro-config"),
		slog.String("config_dir", config.configDir),
		slog.Bool("use_pass", config.usePass),
	)
	
	return config, nil
}

// isPassAvailable checks if pass is installed and initialized
func isPassAvailable() bool {
	cmd := exec.Command("pass")
	if err := cmd.Run(); err != nil {
		return false
	}
	return true
}

// getFromPass retrieves a value from pass
func (c *TrendMicroConfig) getFromPass(path string) (string, error) {
	cmd := exec.Command("pass", path)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to retrieve '%s' from pass: %w", path, err)
	}
	
	// Return first line
	lines := strings.Split(string(output), "\n")
	if len(lines) > 0 {
		return strings.TrimSpace(lines[0]), nil
	}
	
	return "", fmt.Errorf("empty response from pass for '%s'", path)
}

// loadJSON loads a JSON file from the config directory
func (c *TrendMicroConfig) loadJSON(filename string, v interface{}) error {
	filePath := filepath.Join(c.configDir, filename)
	
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", filePath, err)
	}
	
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("failed to parse %s: %w", filePath, err)
	}
	
	return nil
}

// LoadCredentials loads deployment configuration
func (c *TrendMicroConfig) LoadCredentials() (*DeploymentConfigFile, error) {
	if c.credentials == nil {
		creds := &DeploymentConfigFile{}
		if err := c.loadJSON("deployment_config.json", creds); err != nil {
			return nil, err
		}
		c.credentials = creds
	}
	return c.credentials, nil
}

// LoadEnvironments loads environment configurations
func (c *TrendMicroConfig) LoadEnvironments() (*EnvironmentsFile, error) {
	if c.environments == nil {
		envs := &EnvironmentsFile{}
		if err := c.loadJSON("environments.json", envs); err != nil {
			return nil, err
		}
		c.environments = envs
	}
	return c.environments, nil
}

// GetAPIToken retrieves the API token for the specified environment
func (c *TrendMicroConfig) GetAPIToken(environment string) (string, error) {
	// Try pass first if enabled
	if c.usePass {
		token, err := c.getFromPass(fmt.Sprintf("TrendMicro/%s/api_token", environment))
		if err == nil {
			return token, nil
		}
		slog.Warn("Could not retrieve token from pass, falling back to config file",
			slog.String("error", err.Error()),
		)
	}
	
	// Fallback to config file
	creds, err := c.LoadCredentials()
	if err != nil {
		return "", err
	}
	
	envConfig, ok := creds.Environments[environment]
	if !ok {
		return "", fmt.Errorf("environment '%s' not found in configuration", environment)
	}
	
	return envConfig.APICredentials.APIToken, nil
}

// GetAPIBaseURL gets the API base URL for the environment
func (c *TrendMicroConfig) GetAPIBaseURL(environment string) (string, error) {
	// Try pass first if enabled
	if c.usePass {
		url, err := c.getFromPass(fmt.Sprintf("TrendMicro/%s/api_base_url", environment))
		if err == nil {
			return url, nil
		}
	}
	
	// Fallback to environments.json
	envs, err := c.LoadEnvironments()
	if err != nil {
		return "", err
	}
	
	envInfo, ok := envs.Environments[environment]
	if !ok {
		return "", fmt.Errorf("environment '%s' not found", environment)
	}
	
	return envInfo.APIBaseURL, nil
}

// GetDeploymentInfo gets deployment information for the environment
func (c *TrendMicroConfig) GetDeploymentInfo(environment string) (*DeploymentConfig, error) {
	creds, err := c.LoadCredentials()
	if err != nil {
		return nil, err
	}
	
	envConfig, ok := creds.Environments[environment]
	if !ok {
		return nil, fmt.Errorf("environment '%s' not found", environment)
	}
	
	return &envConfig.Deployment, nil
}

// GetCommonHeaders returns common HTTP headers for API requests
func (c *TrendMicroConfig) GetCommonHeaders(environment string, includeToken bool) (map[string]string, error) {
	headers := map[string]string{
		"Content-Type": "application/json",
		"Accept":       "application/json",
	}
	
	if includeToken {
		token, err := c.GetAPIToken(environment)
		if err != nil {
			return nil, err
		}
		headers["Authorization"] = fmt.Sprintf("Bearer %s", token)
	}
	
	return headers, nil
}

// CheckTokenExpiry checks if the API token is expiring soon
func (c *TrendMicroConfig) CheckTokenExpiry(environment string) (map[string]interface{}, error) {
	creds, err := c.LoadCredentials()
	if err != nil {
		return nil, err
	}
	
	envConfig, ok := creds.Environments[environment]
	if !ok {
		return nil, fmt.Errorf("environment '%s' not found", environment)
	}
	
	expiresAt := envConfig.APICredentials.ExpiresAt
	expiryDate := time.Unix(expiresAt, 0)
	now := time.Now()
	daysRemaining := int(expiryDate.Sub(now).Hours() / 24)
	
	return map[string]interface{}{
		"expires_at":        expiresAt,
		"expiry_date":       expiryDate.Format("2006-01-02"),
		"days_remaining":    daysRemaining,
		"is_expiring_soon":  daysRemaining < 30,
		"is_expired":        daysRemaining < 0,
	}, nil
}

// GetEnvironmentLabel gets the human-readable environment label
func (c *TrendMicroConfig) GetEnvironmentLabel(environment string) (string, error) {
	envs, err := c.LoadEnvironments()
	if err != nil {
		return "", err
	}
	
	envInfo, ok := envs.Environments[environment]
	if !ok {
		return strings.Title(environment), nil
	}
	
	if envInfo.EnvironmentLabel != "" {
		return envInfo.EnvironmentLabel, nil
	}
	
	return strings.Title(environment), nil
}

// ListAvailableEnvironments lists all available environments
func (c *TrendMicroConfig) ListAvailableEnvironments() (map[string]map[string]interface{}, error) {
	creds, err := c.LoadCredentials()
	if err != nil {
		return nil, err
	}
	
	envs, err := c.LoadEnvironments()
	if err != nil {
		return nil, err
	}
	
	result := make(map[string]map[string]interface{})
	
	// Get environments from credentials
	for envName, envData := range creds.Environments {
		result[envName] = map[string]interface{}{
			"business_name":    envData.Deployment.BusinessName,
			"region":           envData.Deployment.Region,
			"api_base_url":     envData.Deployment.APIBaseURL,
			"portal_url":       envData.Deployment.PortalURL,
			"has_credentials":  true,
		}
	}
	
	// Add environments from environments.json without credentials
	for envName, envData := range envs.Environments {
		if _, exists := result[envName]; !exists {
			result[envName] = map[string]interface{}{
				"name":            envData.Name,
				"region":          envData.Region,
				"api_base_url":    envData.APIBaseURL,
				"portal_url":      envData.PortalURL,
				"has_credentials": false,
			}
		}
	}
	
	return result, nil
}

// IsUsingPass checks if configuration is using pass
func (c *TrendMicroConfig) IsUsingPass() bool {
	return c.usePass
}

// GetCredentialSource returns the credential source being used
func (c *TrendMicroConfig) GetCredentialSource() string {
	if c.usePass {
		return "pass"
	}
	return "deployment_config.json"
}
