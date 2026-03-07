# Go Tool Command Reference

Complete reference for `go tool` and related commands in Go 1.24+.

## go get -tool

Adds a tool dependency to go.mod.

### Syntax

```bash
go get -tool <import_path>[@<version>]
```

### Options

| Option | Description |
|--------|-------------|
| `@latest` | Fetch latest release version |
| `@v1.2.3` | Fetch specific version |
| `@none` | Remove tool from go.mod |
| `-modfile=<path>` | Use alternate go.mod file |

### Examples

```bash
# Add latest version
go get -tool golang.org/x/tools/cmd/stringer

# Add specific version
go get -tool honnef.co/go/tools/cmd/staticcheck@v0.5.1

# Remove tool
go get -tool golang.org/x/tools/cmd/stringer@none

# Add to separate modfile
go get -tool -modfile=tools/go.mod github.com/golangci/golangci-lint/cmd/golangci-lint
```

## go tool

Runs a tool or lists available tools.

### Syntax

```bash
go tool [options] [<name>] [tool-args...]
```

### Options

| Option | Description |
|--------|-------------|
| `-n` | Print binary path without executing |
| `-modfile=<path>` | Use alternate go.mod file |

### Examples

```bash
# List all tools (including built-ins)
go tool

# Run tool by short name
go tool stringer -type=MyType

# Run tool by full path
go tool golang.org/x/tools/cmd/stringer -type=MyType

# Get binary path
go tool -n stringer
# Output: /home/user/go/pkg/mod/cache/go-build/.../stringer

# Run from separate modfile
go tool -modfile=tools/go.mod golangci-lint run
```

## go list tool

Lists tools declared in go.mod.

### Syntax

```bash
go list tool
```

### Example

```bash
$ go list tool
golang.org/x/tools/cmd/stringer
honnef.co/go/tools/cmd/staticcheck
github.com/golangci/golangci-lint/cmd/golangci-lint
```

## go get tool

Updates all tools to their latest versions.

### Syntax

```bash
go get tool
```

### With flags

```bash
# Update all tools
go get tool

# Update all tools with -u
go get -u tool
```

## go mod verify

Verifies dependencies (including tools) match go.sum.

### Syntax

```bash
go mod verify
```

### Example

```bash
$ go mod verify
all modules verified
```

## go mod vendor

Vendors all dependencies including tools.

### Syntax

```bash
go mod vendor
```

Tools are vendored alongside regular dependencies. Running `go tool` automatically uses vendored code when present.

## tool Directive Syntax

### go.mod format

```
tool <import_path>
```

### Block format

```
tool (
    <import_path>
    <import_path>
    ...
)
```

### Example go.mod

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

## Tool Meta-Pattern

The special `tool` pattern resolves to all declared tools.

### Usage

```bash
# Update all tools
go get tool

# Install all tools to $GOBIN
go install tool
```

### Workspace Mode

In workspace mode, `tool` resolves to the union of all tools from all modules in the workspace.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GOCACHE` | Build cache location (tools cache here) |
| `GOMODCACHE` | Module cache location |
| `GOBIN` | Binary installation directory for `go install` |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Tool execution failed |
| 2 | Go command error (tool not found, invalid args) |
