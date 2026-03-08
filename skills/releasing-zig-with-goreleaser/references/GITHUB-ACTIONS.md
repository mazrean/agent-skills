# GitHub Actions Workflow for Zig + GoReleaser

## Basic Workflow

Triggers on tag push, builds and releases Zig binaries:

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

## Full-Featured Workflow

Includes signing, SBOM, Docker, and Homebrew:

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  goreleaser:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Zig toolchain
      - uses: mlugg/setup-zig@v1

      # Signing tools
      - uses: sigstore/cosign-installer@v3

      # SBOM tools
      - uses: anchore/sbom-action/download-syft@v0

      # Docker multi-platform support
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      # Container registry login
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Release
      - uses: goreleaser/goreleaser-action@v6
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_PAT: ${{ secrets.GH_PAT }}
```

## CI Build Check (No Release)

Run on PRs to verify the build works:

```yaml
name: build

on:
  pull_request:

jobs:
  build:
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
          args: build --clean --snapshot
```

## Required Secrets

| Secret | Purpose | Required For |
|--------|---------|--------------|
| `GITHUB_TOKEN` | GitHub release creation | Always (auto-provided) |
| `GH_PAT` | Cross-repo Homebrew tap push | Homebrew distribution |

### Creating GH_PAT

1. Go to GitHub Settings > Developer settings > Personal access tokens
2. Create a fine-grained token with `Contents: Read and Write` permission on your Homebrew tap repo
3. Add as repository secret named `GH_PAT`

## Required Permissions

```yaml
permissions:
  contents: write    # Create releases
  packages: write    # Push Docker images to GHCR
  id-token: write    # Cosign keyless signing (sigstore)
```

## Pinning Zig Version

```yaml
- uses: mlugg/setup-zig@v1
  with:
    version: 0.14.0  # Pin specific version
```

## Release Process

```bash
# Create and push a tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# GitHub Actions will automatically run the release workflow
```
