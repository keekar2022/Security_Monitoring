// Concept: Mukesh Kesharwani
// Contact: mukesh.kesharwani@adobe.com
//
// Unified Trend Micro collector for EC2 cron — runs all credentialed environments.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/mkesharw/integration-api-dev/lib/s3publish"
)

func main() {
	os.Exit(run())
}

func run() int {
	runAll := flag.Bool("run-all", false, "Run all environments from deployment_config.json")
	environment := flag.String("environment", "", "Single environment name")
	publishS3 := flag.Bool("publish-s3", false, "Upload DATA_DIR to METRICS_S3_BUCKET after collection")
	nonFatal := flag.Bool("non-fatal", false, "Endpoint vuln collector exits 0 on permission errors")
	binDir := flag.String("bin-dir", "", "Directory containing collector binaries (default: ../bin relative to repo)")
	dataDir := flag.String("output-dir", "", "DATA_DIR for JSONL output")
	quiet := flag.Bool("quiet", true, "Quiet collector output")
	flag.Parse()

	root := repoRoot()
	if *binDir == "" {
		*binDir = filepath.Join(root, "go", "bin")
	}
	if *dataDir == "" {
		*dataDir = envOr("DATA_DIR", filepath.Join(root, "data"))
	}
	_ = os.Setenv("DATA_DIR", *dataDir)

	envs, err := resolveEnvironments(root, *runAll, *environment)
	if err != nil {
		slog.Error("resolve environments", "error", err)
		return 1
	}
	if len(envs) == 0 {
		slog.Error("no environments to collect")
		return 1
	}

	if *nonFatal || strings.EqualFold(os.Getenv("COLLECTOR_NON_FATAL"), "true") {
		os.Setenv("COLLECTOR_NON_FATAL", "true")
	}

	start := time.Now()
	var succeeded, partial, failed []string

	for _, env := range envs {
		cOK, sOK, vOK := runEnv(*binDir, *dataDir, env, *quiet, *nonFatal)
		switch {
		case cOK && sOK && vOK:
			succeeded = append(succeeded, env)
		case cOK:
			partial = append(partial, env)
		default:
			failed = append(failed, env)
		}
	}

	duration := time.Since(start).Seconds()
	slog.Info("Collection summary",
		"service.name", "secmon-collector",
		"operation", "run_all",
		"succeeded", len(succeeded),
		"partial", len(partial),
		"failed", len(failed),
		"duration_seconds", duration,
	)

	if len(succeeded) == 0 && len(partial) == 0 {
		return 1
	}

	if *publishS3 {
		bucket := strings.TrimSpace(os.Getenv("METRICS_S3_BUCKET"))
		if bucket == "" {
			slog.Error("METRICS_S3_BUCKET not set")
			return 1
		}
		prefix := strings.Trim(os.Getenv("METRICS_S3_PREFIX"), "/")
		if prefix == "" {
			prefix = "data"
		}
		if err := s3publish.Publish(context.Background(), *dataDir, bucket, prefix); err != nil {
			slog.Error("s3 publish", "error", err)
			return 1
		}
	}

	if len(failed) > 0 {
		return 1
	}
	return 0
}

func runEnv(binDir, dataDir, env string, quiet, nonFatal bool) (containerOK, statsOK, vulnOK bool) {
	run := func(name string, extra ...string) bool {
		bin := filepath.Join(binDir, name)
		args := []string{"--environment", env, "--output-dir", dataDir}
		if quiet {
			args = append(args, "--quiet")
		}
		args = append(args, extra...)
		cmd := exec.Command(bin, args...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Env = os.Environ()
		return cmd.Run() == nil
	}

	containerOK = run("get_container_vulnerabilities")
	statsOK = run("get_endpoint_stats")
	vulnExtra := []string{}
	if nonFatal {
		vulnExtra = append(vulnExtra, "--non-fatal")
	}
	vulnOK = run("get_endpoint_vulnerabilities", vulnExtra...)
	return containerOK, statsOK, vulnOK
}

func repoRoot() string {
	if r := os.Getenv("SECMON_APP_ROOT"); r != "" {
		return r
	}
	wd, _ := os.Getwd()
	for dir := wd; ; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "app.py")); err == nil {
			return dir
		}
		if dir == filepath.Dir(dir) {
			break
		}
	}
	return wd
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func resolveEnvironments(root string, runAll bool, single string) ([]string, error) {
	if single != "" {
		return []string{single}, nil
	}
	if !runAll {
		return nil, fmt.Errorf("specify --run-all or --environment")
	}
	cfgPath := filepath.Join(root, "config", "deployment_config.json")
	raw, err := os.ReadFile(cfgPath)
	if err != nil {
		return nil, err
	}
	var cfg struct {
		Environments []struct {
			Name       string `json:"name"`
			Credential string `json:"credential"`
		} `json:"environments"`
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return nil, err
	}
	var out []string
	for _, e := range cfg.Environments {
		if strings.TrimSpace(e.Credential) != "" {
			out = append(out, e.Name)
		}
	}
	return out, nil
}
