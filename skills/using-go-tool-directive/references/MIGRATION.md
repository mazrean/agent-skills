# Migration Guide

Migrate from legacy tool management patterns to Go 1.24+ tool directive.

## Prerequisites

Ensure your project uses Go 1.24+:

```bash
go version  # Should be go1.24 or later

# Update go.mod
go mod edit -go=1.24
```

## From tools.go

The `tools.go` pattern used blank imports to track tool dependencies:

### Before (tools.go)

```go
//go:build tools
// +build tools

package tools

import (
    _ "golang.org/x/tools/cmd/stringer"
    _ "honnef.co/go/tools/cmd/staticcheck"
    _ "github.com/golangci/golangci-lint/cmd/golangci-lint"
)
```

### Migration Steps

1. **Add tools with go get -tool:**

```bash
go get -tool golang.org/x/tools/cmd/stringer
go get -tool honnef.co/go/tools/cmd/staticcheck
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint
```

2. **Delete tools.go:**

```bash
rm tools.go
# Or: rm internal/tools/tools.go (wherever it was)
```

3. **Run go mod tidy:**

```bash
go mod tidy
```

4. **Verify tools work:**

```bash
go list tool
go tool stringer -help
```

### Result (go.mod)

```
module example.com/myproject

go 1.24

tool (
    golang.org/x/tools/cmd/stringer
    honnef.co/go/tools/cmd/staticcheck
    github.com/golangci/golangci-lint/cmd/golangci-lint
)

require (
    golang.org/x/tools v0.28.0
    honnef.co/go/tools v0.5.1
    github.com/golangci/golangci-lint v1.63.4
)
```

## From go run

The `go run` pattern executed tools directly:

### Before (go:generate with go run)

```go
//go:generate go run golang.org/x/tools/cmd/stringer -type=Level
//go:generate go run github.com/dmarkham/enumer -type=Status -json
```

### After (go:generate with go tool)

```go
//go:generate go tool stringer -type=Level
//go:generate go tool enumer -type=Status -json
```

### Migration Steps

1. **Add tools:**

```bash
go get -tool golang.org/x/tools/cmd/stringer
go get -tool github.com/dmarkham/enumer
```

2. **Update go:generate directives:**

Find and replace in your codebase:

```bash
# Find all go:generate with go run
grep -r "//go:generate go run" --include="*.go"

# Pattern to replace:
# FROM: //go:generate go run <package> <args>
# TO:   //go:generate go tool <shortname> <args>
```

3. **Test generation:**

```bash
go generate ./...
```

### Benefits

- Faster: No compilation on each `go generate` (cached)
- Explicit: Tool versions visible in go.mod
- Consistent: Same version for all developers

## From Global Installation

### Before

```bash
# In README or setup script
go install golang.org/x/tools/cmd/stringer@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Usage
stringer -type=MyType
golangci-lint run
```

### After

```bash
# One-time setup per project
go get -tool golang.org/x/tools/cmd/stringer
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint

# Usage
go tool stringer -type=MyType
go tool golangci-lint run
```

### Update Documentation

```markdown
## Before (README.md)

### Prerequisites
Install required tools:
\`\`\`bash
go install golang.org/x/tools/cmd/stringer@v0.28.0
\`\`\`

## After (README.md)

### Prerequisites
Tools are managed in go.mod. They're installed automatically when needed.

To explicitly install all tools:
\`\`\`bash
go install tool
\`\`\`
```

## CI/CD Migration

### GitHub Actions

#### Before

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - name: Install tools
        run: |
          go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.63.4
      - name: Lint
        run: golangci-lint run
```

#### After

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
          cache: true  # Caches module and build cache
      - name: Lint
        run: go tool golangci-lint run
```

### Makefile

#### Before

```makefile
.PHONY: tools
tools:
	go install golang.org/x/tools/cmd/stringer@v0.28.0
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.63.4

.PHONY: lint
lint: tools
	golangci-lint run

.PHONY: generate
generate: tools
	go generate ./...
```

#### After

```makefile
.PHONY: lint
lint:
	go tool golangci-lint run

.PHONY: generate
generate:
	go generate ./...

# Optional: explicitly install to $GOBIN
.PHONY: install-tools
install-tools:
	go install tool
```

## Version Pinning Migration

### Ensure Explicit Versions

After migration, verify all tools have explicit versions:

```bash
# List tools and their versions
go list -m -f '{{.Path}} {{.Version}}' all | grep -E 'stringer|staticcheck|golangci'
```

### Lock to Current Versions

If tools were added without version, pin them:

```bash
# Check current resolved version
go list -m golang.org/x/tools

# Pin explicitly
go get -tool golang.org/x/tools/cmd/stringer@v0.28.0
```

## Backward Compatibility

### Supporting Go 1.23 and Earlier

If your project must support Go <1.24:

1. **Keep both patterns temporarily:**

```go
// tools.go (for Go <1.24)
//go:build tools
// +build tools

package tools

import (
    _ "golang.org/x/tools/cmd/stringer"
)
```

```
// go.mod (for Go 1.24+)
tool golang.org/x/tools/cmd/stringer
```

2. **Use conditional go:generate:**

```go
// For Go 1.24+
//go:generate go tool stringer -type=Level

// For Go <1.24 (comment out one or the other)
//go:generate go run golang.org/x/tools/cmd/stringer -type=Level
```

3. **Document requirements:**

```markdown
## Requirements
- Go 1.24+ recommended (uses tool directive)
- Go 1.21-1.23 supported (uses tools.go)
```

## Troubleshooting Migration

### "unknown directive: tool"

Your Go version is <1.24:

```bash
go version
# Update to Go 1.24+
```

### Tool not found after migration

Verify the tool is in go.mod:

```bash
go list tool
```

If missing, add it:

```bash
go get -tool <import_path>
```

### Version mismatch after migration

Clean and re-fetch:

```bash
go clean -cache
go mod download
```
