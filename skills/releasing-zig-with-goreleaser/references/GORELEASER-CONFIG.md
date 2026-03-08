# GoReleaser Configuration Reference for Zig

Complete configuration options for `.goreleaser.yaml` when building Zig projects.

## Full Configuration Example

```yaml
version: 2

project_name: my-zig-cli

builds:
  - id: my-zig-cli
    builder: zig
    binary: my-zig-cli
    dir: .
    tool: zig
    command: build
    flags:
      - --release
    targets:
      - x86_64-linux-gnu
      - x86_64-linux-musl
      - x86_64-macos
      - x86_64-windows
      - aarch64-linux-gnu
      - aarch64-linux-musl
      - aarch64-macos
    env:
      - FOO=bar
    hooks:
      pre: echo "building {{ .Target }}"
      post: echo "built {{ .Path }}"

universal_binaries:
  - replace: true

archives:
  - id: default
    formats: [tar.gz]
    format_overrides:
      - goos: windows
        formats: [zip]
    name_template: "{{ .ProjectName }}_{{ .Version }}_{{ .Os }}_{{ .Arch }}"
    files:
      - LICENSE*
      - README*
      - CHANGELOG*

checksum:
  name_template: "checksums.txt"

changelog:
  sort: asc
  filters:
    exclude:
      - "^docs:"
      - "^test:"
      - "^chore:"

release:
  github:
    owner: your-username
    name: your-repo
  draft: false
  prerelease: auto
  footer: |
    ## Installation

    ### Homebrew
    ```bash
    brew install your-username/tap/my-zig-cli
    ```

    ### Binary
    Download the appropriate archive for your platform from the assets below.

source:
  enabled: true
```

## Build Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | string | project name | Unique build identifier |
| `builder` | string | - | Must be `zig` for Zig projects |
| `binary` | string | project dir name | Output binary name |
| `dir` | string | `.` | Working directory for build |
| `tool` | string | `zig` | Path to Zig binary |
| `command` | string | `build` | Build command to run |
| `flags` | list | `[-Doptimize=ReleaseSafe]` | Build flags passed to `zig build` |
| `targets` | list | 5 default targets | Zig target triples |
| `env` | list | inherited | Environment variables |
| `hooks.pre` | string | - | Command to run before build |
| `hooks.post` | string | - | Command to run after build |
| `skip` | bool | `false` | Skip this build |

## Zig Target Format

Targets follow Zig's `<arch>-<os>-<abi>` format:

**Architectures:** `x86_64`, `aarch64`, `x86`, `arm`, `riscv64`

**OS:** `linux`, `macos`, `windows`, `freebsd`

**ABI (optional):** `gnu`, `musl`, `none`

Examples:
- `x86_64-linux-gnu` - x86_64 Linux with glibc
- `x86_64-linux-musl` - x86_64 Linux with musl (static)
- `aarch64-macos` - ARM64 macOS (ABI not needed)
- `x86_64-windows` - x86_64 Windows

## Signing with Cosign

```yaml
signs:
  - cmd: cosign
    artifacts: checksum
    args:
      - sign-blob
      - "--output-signature=${signature}"
      - "${artifact}"
      - "--yes"
```

Requires `sigstore/cosign-installer` in CI.

## SBOM Generation

```yaml
sboms:
  - artifacts: archive
```

Requires `anchore/sbom-action/download-syft` in CI.

## Linux Packages (nFPM)

```yaml
nfpms:
  - id: packages
    package_name: my-zig-cli
    file_name_template: "{{ .ConventionalFileName }}"
    vendor: Your Name
    homepage: https://github.com/your-username/my-zig-cli
    maintainer: Your Name <you@example.com>
    description: A CLI tool built with Zig
    license: MIT
    formats:
      - deb
      - rpm
      - apk
    bindir: /usr/bin
```

## Homebrew Tap

```yaml
brews:
  - repository:
      owner: your-username
      name: homebrew-tap
      token: "{{ .Env.GH_PAT }}"
    homepage: https://github.com/your-username/my-zig-cli
    description: A CLI tool built with Zig
    license: MIT
    install: |
      bin.install "my-zig-cli"
    test: |
      system "#{bin}/my-zig-cli", "--version"
```

Requires a `GH_PAT` secret with repo scope for cross-repo access.

## Docker Images

```yaml
dockers:
  - image_templates:
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-amd64"
    goarch: amd64
    use: buildx
    build_flag_templates:
      - "--platform=linux/amd64"
      - "--label=org.opencontainers.image.title={{ .ProjectName }}"
      - "--label=org.opencontainers.image.version={{ .Version }}"

  - image_templates:
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-arm64"
    goarch: arm64
    use: buildx
    build_flag_templates:
      - "--platform=linux/arm64"
      - "--label=org.opencontainers.image.title={{ .ProjectName }}"
      - "--label=org.opencontainers.image.version={{ .Version }}"

docker_manifests:
  - name_template: "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}"
    image_templates:
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-amd64"
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-arm64"

  - name_template: "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:latest"
    image_templates:
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-amd64"
      - "ghcr.io/{{ .Env.GITHUB_REPOSITORY }}:{{ .Tag }}-arm64"

docker_signs:
  - cmd: cosign
    artifacts: manifests
    args:
      - sign
      - "${artifact}"
      - "--yes"
```

Requires Docker Buildx, QEMU, and GHCR login in CI.

## Dockerfile for Zig Binary

```dockerfile
FROM alpine:latest
COPY my-zig-cli /usr/bin/my-zig-cli
ENTRYPOINT ["/usr/bin/my-zig-cli"]
```

Build with musl target (`x86_64-linux-musl`) for static binaries in Alpine containers.

## Verification Commands

```bash
# Validate config
goreleaser check

# Check toolchain availability
goreleaser healthcheck

# Dry run (no publish)
goreleaser release --clean --snapshot

# Skip specific publishers
goreleaser release --clean --snapshot --skip=docker,signs
```
