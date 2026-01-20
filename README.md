# Nebula 3rd-Party First-Use

This repository serves as a **Supply Chain Firewall** for third-party tools used across Nebula projects. 

## Purpose

To prevent "Supply Chain Attacks" and "Live Internet Breakages", we **do not** pipe `curl | sh` from upstream URLs directly in our pipelines or dev environments.

Instead, we:
1.  **Cache** the installer scripts here.
2.  **Verify** them against a strict Allow List (`manifests/*.json`).
3.  **Validate** that the version and architecture being requested are explicitly tested.

## Supported Tools

### mise
- **Wrapper**: `scripts/mise/install.sh`
- **Cached Installer**: `scripts/mise/upstream-install.sh`
- **Manifest**: `manifests/mise/latest` & `manifests/mise/<version>.conf`

## Usage

To install `mise` in a project (CI or Local):

```bash
# Clone or submodule this repo, then run:
./scripts/mise/install.sh

# Or curl directly (no submodule required):
curl -sSfL https://raw.githubusercontent.com/nokesc/nebula-3rd-party-first-use/main/scripts/mise/install.sh | bash

# Or specify a version (must represent a valid config file in manifests/mise/)
MISE_VERSION=v2026.1.5 ./scripts/mise/install.sh
```

## Maintenance

When `mise` releases a new version:
1.  Verify the new version is safe.
2.  Update `manifests/mise/latest` to point to the new version.
3.  Create a new config file `manifests/mise/<version>.conf` with the bootstrapper SHA and allowed platforms.
4.  (If upstream script changed) Update `scripts/mise/upstream-install.sh` and the checksum in the new config.
