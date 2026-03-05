module github.com/mkesharw/integration-api-dev

go 1.21

// Note: All tools use standard library only
// OpenTelemetry-compliant logging via log/slog (Go stdlib)
// No external dependencies needed for production simplicity

replace github.com/mkesharw/integration-api-dev => ./
