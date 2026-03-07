# Templ CLI Commands

Reference for templ command-line interface.

## Installation

```bash
go install github.com/a-h/templ/cmd/templ@latest
```

## templ generate

Generate Go code from `.templ` files.

### Basic Usage

```bash
# Generate all .templ files in current directory (recursive)
templ generate

# Generate from specific directory
templ generate -path ./views

# Generate single file
templ generate -f ./views/home.templ

# Print to stdout (single file only)
templ generate -f ./views/home.templ -stdout
```

### Watch Mode

```bash
# Watch and regenerate on changes
templ generate --watch

# Watch with custom pattern
templ generate --watch -watch-pattern "(.+\.go$)|(.+\.templ$)"
```

### Development Server

```bash
# Watch with proxy (live reload)
templ generate --watch --proxy="http://localhost:8080" --proxyport=7331

# Run command after generation
templ generate --watch --cmd="go run ."
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-path` | Directory to generate from | `.` |
| `-f` | Generate single file | - |
| `-stdout` | Print to stdout (with -f) | `false` |
| `--watch` | Watch for changes | `false` |
| `-watch-pattern` | Regex for files to watch | `(.+\.go$)\|(.+\.templ$)` |
| `--proxy` | URL to proxy after generation | - |
| `--proxyport` | Proxy listen port | `7331` |
| `--proxybind` | Proxy listen address | `127.0.0.1` |
| `--cmd` | Command to run after generation | - |
| `-w` | Number of workers | CPU count |
| `-lazy` | Only generate if source is newer | `false` |
| `-include-version` | Include templ version in output | `true` |
| `-include-timestamp` | Include timestamp in output | `false` |
| `-keep-orphaned-files` | Keep generated files without source | `false` |
| `-v` | Debug logging | `false` |
| `-log-level` | Log level (debug/info/warn/error) | `info` |

## templ fmt

Format `.templ` files.

### Basic Usage

```bash
# Format all .templ files in current directory
templ fmt .

# Format specific file
templ fmt ./views/home.templ

# Print formatted output to stdout
templ fmt -stdout ./views/home.templ

# Format from stdin
cat file.templ | templ fmt -stdout -stdin-filepath=file.templ
```

### CI Mode

```bash
# Exit with code 1 if files would change
templ fmt -fail .
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-stdout` | Print to stdout | `false` |
| `-stdin-filepath` | Filepath context for stdin | - |
| `-fail` | Exit 1 if files changed (CI) | `false` |
| `-w` | Number of workers | CPU count |
| `-v` | Debug logging | `false` |
| `-log-level` | Log level | `info` |

## templ lsp

Start Language Server Protocol server for IDE integration.

### Basic Usage

```bash
# Start LSP server
templ lsp

# With logging
templ lsp -log=/tmp/templ-lsp.log

# With gopls logging
templ lsp -goplsLog=/tmp/gopls.log
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-log` | File path for templ LSP logs | - |
| `-goplsLog` | File path for gopls logs | - |
| `-goplsRPCTrace` | Log gopls I/O | `false` |
| `-gopls-remote` | Remote gopls address | - |
| `-http` | HTTP debug server address | - |
| `-pprof` | Enable pprof server | `false` |
| `-no-preload` | Disable preloading (large repos) | `false` |

## templ version

Print version information.

```bash
templ version
```

## templ info

Display environment information.

```bash
templ info
```

## Common Workflows

### Development

```bash
# Terminal 1: Watch and rebuild
templ generate --watch --cmd="go run ." --proxy="http://localhost:8080"

# Browser opens http://localhost:7331 for live reload
```

### Production Build

```bash
# Generate all templates
templ generate

# Build application
go build -o app .
```

### CI/CD

```bash
# Check formatting
templ fmt -fail .

# Generate and verify no changes
templ generate
git diff --exit-code
```

### IDE Setup

Most IDEs use the LSP server automatically. For manual setup:

```bash
# VS Code: Install templ extension
# It will start templ lsp automatically

# Neovim: Configure LSP client to use
templ lsp
```
