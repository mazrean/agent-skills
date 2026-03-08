# Packaging and Distribution

## Homebrew

### Setup

1. Create a Homebrew tap repository: `your-username/homebrew-tap`
2. Create a `GH_PAT` secret with repo access to the tap repo
3. Add to `.goreleaser.yaml`:

```yaml
brews:
  - repository:
      owner: your-username
      name: homebrew-tap
      token: "{{ .Env.GH_PAT }}"
    homepage: https://github.com/your-username/my-zig-cli
    description: Description of your tool
    license: MIT
    install: |
      bin.install "my-zig-cli"
    test: |
      system "#{bin}/my-zig-cli", "--version"
```

### User Installation

```bash
brew tap your-username/tap
brew install my-zig-cli
```

## Linux Packages (deb/rpm/apk)

### Configuration

```yaml
nfpms:
  - id: packages
    package_name: my-zig-cli
    file_name_template: "{{ .ConventionalFileName }}"
    vendor: Your Name
    homepage: https://github.com/your-username/my-zig-cli
    maintainer: Your Name <you@example.com>
    description: Description of your tool
    license: MIT
    formats:
      - deb
      - rpm
      - apk
    bindir: /usr/bin
    contents:
      - src: ./completions/my-zig-cli.bash
        dst: /usr/share/bash-completion/completions/my-zig-cli
        file_info:
          mode: 0644
      - src: ./completions/my-zig-cli.zsh
        dst: /usr/share/zsh/vendor-completions/_my-zig-cli
        file_info:
          mode: 0644
      - src: ./man/my-zig-cli.1
        dst: /usr/share/man/man1/my-zig-cli.1
        file_info:
          mode: 0644
```

### User Installation

```bash
# Debian/Ubuntu
sudo dpkg -i my-zig-cli_1.0.0_amd64.deb

# RHEL/Fedora
sudo rpm -i my-zig-cli_1.0.0_amd64.rpm

# Alpine
sudo apk add --allow-untrusted my-zig-cli_1.0.0_amd64.apk
```

## Docker

### Dockerfile

For Zig binaries, use a minimal base image. Build with musl target for static linking:

```dockerfile
FROM alpine:latest
COPY my-zig-cli /usr/bin/my-zig-cli
ENTRYPOINT ["/usr/bin/my-zig-cli"]
```

### GoReleaser Config

```yaml
dockers:
  - image_templates:
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-amd64"
    goarch: amd64
    use: buildx
    build_flag_templates:
      - "--platform=linux/amd64"

  - image_templates:
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-arm64"
    goarch: arm64
    use: buildx
    build_flag_templates:
      - "--platform=linux/arm64"

docker_manifests:
  - name_template: "ghcr.io/your-username/my-zig-cli:{{ .Tag }}"
    image_templates:
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-amd64"
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-arm64"

  - name_template: "ghcr.io/your-username/my-zig-cli:latest"
    image_templates:
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-amd64"
      - "ghcr.io/your-username/my-zig-cli:{{ .Tag }}-arm64"
```

### Important: Use musl Targets for Docker

Include musl targets in your build config for static Alpine containers:

```yaml
builds:
  - builder: zig
    targets:
      - x86_64-linux-musl    # For Docker amd64
      - aarch64-linux-musl   # For Docker arm64
      - x86_64-linux-gnu
      - x86_64-macos
      - aarch64-macos
      - x86_64-windows
```

### User Usage

```bash
docker pull ghcr.io/your-username/my-zig-cli:latest
docker run --rm ghcr.io/your-username/my-zig-cli:latest --help
```

## Archives

### Configuration

```yaml
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
      - completions/*
      - man/*
```

## Checksums

```yaml
checksum:
  name_template: "checksums.txt"
  algorithm: sha256
```

Users can verify downloads:

```bash
sha256sum --check checksums.txt
```
