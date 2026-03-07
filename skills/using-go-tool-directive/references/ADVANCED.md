# Advanced Patterns

Advanced usage patterns for Go tool directive including dependency isolation, performance optimization, and workspace integration.

## Dependency Isolation

### The Problem

Tool dependencies share the same `go.mod` as your application. This can cause:

1. **Version conflicts**: Tool requires newer version of shared dependency
2. **Unexpected upgrades**: Adding tool upgrades application dependencies
3. **Build pollution**: Tool's transitive dependencies appear in your module graph

### Solution: Separate Modfile

Create an isolated go.mod for tools:

```
project/
├── go.mod           # Application dependencies
├── go.sum
├── tools/
│   ├── go.mod       # Tool dependencies only
│   └── go.sum
└── ...
```

#### Setup

```bash
# Create tools directory and module
mkdir tools
cd tools
go mod init example.com/myproject/tools
cd ..

# Add tools to separate modfile
go get -tool -modfile=tools/go.mod github.com/golangci/golangci-lint/cmd/golangci-lint
go get -tool -modfile=tools/go.mod honnef.co/go/tools/cmd/staticcheck
```

#### Usage

```bash
# Run tool from separate modfile
go tool -modfile=tools/go.mod golangci-lint run ./...

# List tools in separate modfile
go list -modfile=tools/go.mod tool
```

#### Makefile Integration

```makefile
TOOLS_MOD := -modfile=tools/go.mod

.PHONY: lint
lint:
	go tool $(TOOLS_MOD) golangci-lint run ./...

.PHONY: audit
audit:
	go vet ./...
	go tool $(TOOLS_MOD) staticcheck ./...
	go tool $(TOOLS_MOD) govulncheck ./...

.PHONY: update-tools
update-tools:
	go get $(TOOLS_MOD) tool
```

#### CI Configuration

```yaml
# .github/workflows/ci.yml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
          cache: true
          cache-dependency-path: |
            go.sum
            tools/go.sum
      - run: go tool -modfile=tools/go.mod golangci-lint run
```

## Performance Optimization

### Understanding Tool Execution Overhead

`go tool` has startup overhead compared to direct binary execution:

| Tool Size | Direct Execution | `go tool` | Overhead |
|-----------|-----------------|-----------|----------|
| Small (~5MB) | ~2ms | ~77ms | ~38x |
| Large (~200MB) | ~56ms | ~471ms | ~8x |

### Caching Strategy

For frequently-run tools, consider installing to `$GOBIN`:

```bash
# Install all tools to $GOBIN for direct execution
go install tool

# Now run directly (faster)
golangci-lint run ./...
```

### When to Use Each Approach

| Scenario | Recommended Approach |
|----------|---------------------|
| CI/CD pipelines | `go tool` (clarity over speed) |
| Pre-commit hooks | `go install tool` + direct (speed matters) |
| `go:generate` | `go tool` (version consistency) |
| Interactive development | Either (preference) |

### Wrapper Script for Hybrid Approach

```bash
#!/bin/bash
# scripts/tool.sh - Run tool, installing if needed

TOOL_NAME="$1"
shift

# Check if installed
if command -v "$TOOL_NAME" &> /dev/null; then
    # Run directly (fast)
    "$TOOL_NAME" "$@"
else
    # Fall back to go tool (always works)
    go tool "$TOOL_NAME" "$@"
fi
```

## Workspace Mode

### Tools in Multi-Module Workspaces

In Go workspaces, tools from all modules are available:

```
workspace/
├── go.work
├── module-a/
│   └── go.mod  # tool stringer
├── module-b/
│   └── go.mod  # tool mockgen
└── shared/
    └── go.mod  # tool enumer
```

```go
// go.work
go 1.24

use (
    ./module-a
    ./module-b
    ./shared
)
```

### Tool Resolution in Workspace

```bash
# From workspace root, all tools available:
go tool stringer   # From module-a
go tool mockgen    # From module-b
go tool enumer     # From shared

# List all tools across workspace
go list tool
```

### Version Conflicts in Workspace

If multiple modules declare the same tool with different versions:

```bash
# Check which version is used
go list -m <module-containing-tool>
```

The workspace uses the highest version satisfying all requirements.

## Vendoring Tools

### Enable Vendoring

```bash
go mod vendor
```

Tools are vendored alongside regular dependencies in `vendor/`.

### Behavior with Vendored Tools

- `go tool` automatically uses vendored code
- No network access required
- Hermetic builds possible

### Limitations

```bash
# go mod verify doesn't support vendored dependencies
go mod verify  # Only checks non-vendored
```

### Workflow

```bash
# Initial setup
go get -tool <tools...>
go mod vendor

# After tool updates
go get -tool <tool>@<version>
go mod vendor  # Re-vendor

# After tool removal
go get -tool <tool>@none
go mod vendor  # Clean vendor
```

## Custom Tool Wrappers

### Creating a Unified Entry Point

```bash
#!/bin/bash
# tools/run.sh

case "$1" in
    lint)
        go tool golangci-lint run ./...
        ;;
    fmt)
        go tool goimports -w .
        go tool gofumpt -w .
        ;;
    generate)
        go generate ./...
        ;;
    audit)
        go vet ./...
        go tool staticcheck ./...
        go tool govulncheck ./...
        ;;
    *)
        echo "Usage: $0 {lint|fmt|generate|audit}"
        exit 1
        ;;
esac
```

### Taskfile Alternative

```yaml
# Taskfile.yml
version: '3'

tasks:
  lint:
    cmds:
      - go tool golangci-lint run ./...

  generate:
    cmds:
      - go generate ./...

  audit:
    cmds:
      - go vet ./...
      - go tool staticcheck ./...
      - go tool govulncheck ./...
```

## Pre-commit Hook Integration

### Basic Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Format
go tool gofumpt -w .

# Lint (staged files only)
FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.go$')
if [ -n "$FILES" ]; then
    go tool golangci-lint run $FILES
fi
```

### With pre-commit Framework

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: golangci-lint
        name: golangci-lint
        entry: go tool golangci-lint run
        language: system
        types: [go]
        pass_filenames: false
```

## Debugging Tool Issues

### Verbose Output

```bash
# See what go tool is doing
go tool -x stringer -type=MyType
```

### Check Tool Binary Location

```bash
go tool -n stringer
# /home/user/go/pkg/mod/cache/go-build/xx/stringer
```

### Verify Tool Version

```bash
# Check resolved version
go list -m golang.org/x/tools

# Check tool binary version (if supported)
go tool stringer -version 2>/dev/null || echo "No -version flag"
```

### Clean Cache If Corrupted

```bash
go clean -cache
go clean -modcache  # Warning: removes all cached modules
```

## Replace Directives with Tools

Replace directives apply to tools:

```
module example.com/myproject

go 1.24

tool golang.org/x/tools/cmd/stringer

// Use local fork for debugging
replace golang.org/x/tools => ../my-tools-fork

require golang.org/x/tools v0.28.0
```

This is useful for:
- Testing tool modifications
- Using patched versions
- Local development
