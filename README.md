# Nebula 3rd-Party First-Use

This repository serves as a **Supply Chain Firewall** for third-party tools used across Nebula projects. 

## Purpose

To prevent "Supply Chain Attacks" and "Live Internet Breakages", we **do not** pipe `curl | sh` from upstream URLs directly in our pipelines or dev environments.

Instead, we:
1.  **Cache** the installer scripts here.
2.  **Verify** them against a strict Allow List (`manifests/`).
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

## Testing & Security Verification

Tests verify the firewall by `curl`-ing scripts strictly from **GitHub**, ensuring end-to-end validity.

### Security Gates
Every test run includes automated security compliance checks:
1.  **Static Analysis**: The upstream script is parsed to ensure:
    *   No calls to unauthorized domains (Allowed: `github.com`, `mise.run`, `sh.rustup.rs`).
    *   No usage of `sudo` (User-space installation enforcement).
    *   No suspicious obfuscation patterns (`base64 -d | sh`).
    *   No hardcoded IPs.
2.  **Binary Scanning**: The installed binary is scanned with **ClamAV** to detect known malware signatures before it is accepted as "valid".
3.  **Architecture Verification**: Ensures downloaded artifacts are valid ELF executables, not HTML error pages or scripts.

### Workflow (Push-to-Test)
1.  Work on a feature branch.
2.  **Push** changes to GitHub (tests run against remote code).
3.  Run the suite:

```bash
./tests/run_tests.sh
```

**Note:** Testing is blocked on `main` to prevent testing against production. You must be on a feature branch.
