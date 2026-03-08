---
name: releasing-zig-with-goreleaser
description: Releases Zig CLI applications using GoReleaser v2.5+. Use when setting up automated releases for Zig projects, configuring .goreleaser.yaml for Zig builds, creating GitHub Actions CI/CD for Zig releases, or publishing Zig binaries via Homebrew, Docker, or Linux packages.
---

# Releasing Zig with GoReleaser

Set up automated cross-platform releases for Zig CLI applications using GoReleaser v2.5+. Covers build configuration, GitHub Actions, packaging (Homebrew, Docker, deb/rpm), signing, and SBOMs.

**Use this skill when** configuring GoReleaser for a Zig project, setting up release automation CI/CD, or publishing Zig binaries to multiple platforms.

**Supporting files:** [GORELEASER-CONFIG.md](references/GORELEASER-CONFIG.md) for full configuration reference, [GITHUB-ACTIONS.md](references/GITHUB-ACTIONS.md) for CI/CD workflow setup, [PACKAGING.md](references/PACKAGING.md) for Homebrew, Docker, and Linux package distribution.

## Quick Start

### Prerequisites

- GoReleaser v2.5+ (`go install github.com/goreleaser/goreleaser/v2@latest`)
- Zig compiler installed
- A Zig project that builds with `zig build`

### Initialize

```bash
goreleaser init
```

This generates `.goreleaser.yaml` with Zig-aware defaults if a `build.zig` is detected.

### Minimal .goreleaser.yaml

```yaml
version: 2

builds:
  - builder: zig
    targets:
      - x86_64-linux
      - x86_64-macos
      - x86_64-windows
      - aarch64-linux
      - aarch64-macos

archives:
  - formats: [tar.gz]
    format_overrides:
      - goos: windows
        formats: [zip]

changelog:
  sort: asc
  filters:
    exclude:
      - "^docs:"
      - "^test:"
```

### build.zig Requirements

GoReleaser invokes `zig build` with target flags. Your `build.zig` must accept standard target options:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);
}
```

### Test Locally

```bash
# Validate config
goreleaser check

# Build without publishing
goreleaser release --clean --snapshot
```

## Build Configuration

### Builder Options

```yaml
builds:
  - id: my-app
    builder: zig
    binary: my-app          # Output binary name
    dir: .                  # Working directory
    tool: zig               # Zig binary path (default: "zig")
    command: build           # Build command (default: "build")
    flags:
      - --release            # Zig build flags
    env:
      - CGO_ENABLED=0
    hooks:
      pre: ./scripts/pre-build.sh
      post: ./scripts/post-build.sh {{ .Path }}
```

### Default Targets

When `targets` is omitted, GoReleaser builds for:
- `x86_64-linux`
- `x86_64-macos`
- `x86_64-windows`
- `aarch64-linux`
- `aarch64-macos`

### Template Variables

GoReleaser translates Zig target pairs to GOOS/GOARCH for template compatibility:

| Template | Description |
|----------|-------------|
| `{{ .Os }}` | GOOS equivalent (linux, darwin, windows) |
| `{{ .Arch }}` | GOARCH equivalent (amd64, arm64) |
| `{{ .Target }}` | Original Zig target (e.g., `x86_64-linux`) |
| `{{ .Abi }}` | ABI part of target (e.g., `gnu`, `musl`) |

### Universal Binaries (macOS)

Create fat binaries combining x86_64 and aarch64:

```yaml
universal_binaries:
  - replace: true
```

## GitHub Actions Workflow

Minimal workflow for automated releases on tag push:

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  goreleaser:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: mlugg/setup-zig@v1

      - uses: goreleaser/goreleaser-action@v6
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

See [GITHUB-ACTIONS.md](references/GITHUB-ACTIONS.md) for advanced workflows with signing, Docker, and Homebrew.

## Release Workflow

```bash
# 1. Tag the release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 2. GitHub Actions runs goreleaser automatically
# Or manually:
goreleaser release --clean
```

## Key Points

1. **GoReleaser does not install Zig** - ensure Zig is available in CI via `mlugg/setup-zig`
2. **Config validation** - always run `goreleaser check` before pushing
3. **Snapshot mode** - use `--snapshot` for local testing without publishing
4. **Flags template support** - `flags`, `env`, `tool`, and hooks all support Go templates

See [GORELEASER-CONFIG.md](references/GORELEASER-CONFIG.md) for the full configuration reference including signing, SBOMs, and advanced archive options.
