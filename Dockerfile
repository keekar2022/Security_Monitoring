# Multi-stage build: Trend Micro Integration API Server
# Before first build: run ./export-pass-for-docker.sh (or --empty for an empty store).
# That creates pass-export/ so the image has its own pass store (no host mount needed).
# Stage 1: Build Go API server
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy Go module and source (go.sum optional)
COPY go/ .
RUN go mod download

# Build API server and CLI tools (for one-off fetch runs)
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o api-server cmd/api-server/main.go && \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o get_endpoint_vulnerabilities src/get_endpoint_vulnerabilities.go && \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o get_endpoint_stats src/get_endpoint_stats.go && \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o get_container_vulnerabilities src/get_container_vulnerabilities.go

# Stage 2: Minimal runtime (pass + gnupg for credential vault)
FROM alpine:3.19

RUN apk --no-cache add ca-certificates pass gnupg && \
    adduser -D -g "" -u 1000 appuser

WORKDIR /app

# Copy binaries from builder
COPY --from=builder /build/api-server /app/api-server
COPY --from=builder /build/get_endpoint_vulnerabilities /app/get_endpoint_vulnerabilities
COPY --from=builder /build/get_endpoint_stats /app/get_endpoint_stats
COPY --from=builder /build/get_container_vulnerabilities /app/get_container_vulnerabilities

# Image-owned pass store: use pass-export/ if present (from export-pass-for-docker.sh), else create empty store at build time
RUN mkdir -p /app/config /app/data /app/.password-store /app/.gnupg
COPY . /tmp/ctx/
RUN set -e; \
    if [ -f /tmp/ctx/pass-export/.gpg-id ]; then \
      cp /tmp/ctx/pass-export/.gpg-id /app/.password-store/; \
      cp -a /tmp/ctx/pass-export/.gnupg/. /app/.gnupg/; \
      find /tmp/ctx/pass-export -mindepth 1 -maxdepth 1 ! -name .gnupg -exec cp -a {} /app/.password-store/ \; ; \
    else \
      export PASSWORD_STORE_DIR=/app/.password-store GNUPGHOME=/app/.gnupg && \
      (gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key "Docker API <noreply@local>" default default 0 || true) && \
      key=$$(gpg --list-keys --with-colons "Docker API" 2>/dev/null | awk -F: '$$1=="pub"{print $$5}' | head -1) && \
      if [ -n "$$key" ]; then pass init "$$key"; fi; \
    fi; \
    chown -R appuser:appuser /app
# Pass is already initialized; do not run "pass init". Use "pass ls" / "pass insert path".
RUN echo 'Pass is already initialized. Use: pass ls (list), pass insert TrendMicro/ENV/api_token (add). Do not run pass init.' > /app/README-pass.txt && chown appuser:appuser /app/README-pass.txt

USER appuser

EXPOSE 8080

ENTRYPOINT ["/app/api-server"]
CMD ["--port", "8080", "--data-dir", "/app/data"]
