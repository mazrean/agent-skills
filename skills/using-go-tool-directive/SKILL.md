---
name: using-go-tool-directive
description: Manages Go development tools using the Go 1.24+ tool directive in go.mod. Use when adding linters, generators, or dev tools to Go projects, running project-specific tools, integrating tools with go:generate, or migrating from tools.go patterns.
---

# Using Go Tool Directive

Manage project-specific development tools in Go 1.24+ using the `tool` directive. Ensures consistent tool versions across team members and CI/CD environments.

**Use this skill when** adding dev tools (linters, generators, formatters) to Go projects, running tools via `go tool`, integrating with `go:generate`, or migrating from legacy `tools.go` patterns.

**Supporting files:** [COMMANDS.md](references/COMMANDS.md) for full command reference, [MIGRATION.md](references/MIGRATION.md) for migration patterns, [ADVANCED.md](references/ADVANCED.md) for dependency isolation and caching.

## Quick Start

Add a tool to your project:

```bash
go get -tool golang.org/x/tools/cmd/stringer@latest
```

This adds to `go.mod`:

```
tool golang.org/x/tools/cmd/stringer
```

Run the tool:

```bash
go tool stringer -type=MyType
```

## Core Workflows

### Adding Tools

```bash
# Add with latest version
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint

# Add with specific version
go get -tool honnef.co/go/tools/cmd/staticcheck@v0.5.1
```

### Running Tools

```bash
# Run by short name
go tool staticcheck ./...

# List all available tools
go tool

# Show binary path
go tool -n stringer
```

### Updating Tools

```bash
# Update specific tool
go get -tool honnef.co/go/tools/cmd/staticcheck@v0.6.0

# Update all tools to latest
go get tool
```

### Removing Tools

```bash
go get -tool golang.org/x/tools/cmd/stringer@none
```

## Integration with go:generate

Use `go tool` in generate directives for reproducible code generation:

```go
//go:generate go tool stringer -type=Level
//go:generate go tool mockgen -source=service.go -destination=mocks/service.go
```

Run with:

```bash
go generate ./...
```

## Makefile Integration

```makefile
.PHONY: lint audit generate

lint:
	go tool golangci-lint run ./...

audit:
	go vet ./...
	go tool staticcheck ./...
	go tool govulncheck ./...

generate:
	go generate ./...
```

## Common Tools

| Tool | Install Command |
|------|-----------------|
| stringer | `go get -tool golang.org/x/tools/cmd/stringer` |
| mockgen | `go get -tool go.uber.org/mock/mockgen` |
| golangci-lint | `go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint` |
| staticcheck | `go get -tool honnef.co/go/tools/cmd/staticcheck` |
| govulncheck | `go get -tool golang.org/x/vuln/cmd/govulncheck` |
| enumer | `go get -tool github.com/dmarkham/enumer` |
| wire | `go get -tool github.com/google/wire/cmd/wire` |

## Best Practices

1. **Pin versions explicitly**: Always specify versions for reproducibility
2. **Use with go:generate**: Replace direct tool calls in generate directives
3. **Document in README**: List required tools and their purposes
4. **Run `go mod verify`**: Validate checksums after adding tools
5. **Consider isolation**: Use `-modfile` for tools with conflicting dependencies

## Limitations

- **Go 1.24+ required**: Earlier versions cannot parse `tool` directive
- **Go tools only**: Non-Go tools (eslint, prettier) need separate management
- **Shared dependencies**: Tool dependencies mix with application dependencies (see [ADVANCED.md](references/ADVANCED.md) for isolation)

## Troubleshooting

**Tool not found after install:**
```bash
# Verify it's in go.mod
go list tool

# Check if go version is 1.24+
go version
```

**Version conflict with application:**
Use separate modfile (see [ADVANCED.md](references/ADVANCED.md)):
```bash
go tool -modfile=tools/go.mod <toolname>
```

**CI/CD caching:**
Cache `$GOPATH/pkg/mod` and `$GOCACHE` for faster tool execution.
