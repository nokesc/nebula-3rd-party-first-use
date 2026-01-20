#!/bin/bash
set -e

# Paths
MANIFEST_DIR_REL="manifests/mise"
UPSTREAM_REL_PATH="scripts/mise/upstream-install.sh"
# Default to main branch, but allow override
BRANCH="${NEBULA_REPO_BRANCH:-master}"
RAW_REPO_BASE="${NEBULA_RAW_REPO_BASE:-https://raw.githubusercontent.com/nokesc/nebula-3rd-party-first-use/$BRANCH}"

# Detect execution mode (Local vs Remote/Curl)
MODE="remote"
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    # Verify we are in the repo structure
    # Check for the latest file as a proxy for the dir existence
    if [ -f "$SCRIPT_DIR/../../$MANIFEST_DIR_REL/latest" ]; then
        MODE="local"
    fi
fi

TEMP_DIR=""
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [ "$MODE" = "local" ]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
    MANIFEST_DIR="$REPO_ROOT/$MANIFEST_DIR_REL"
    UPSTREAM_SCRIPT="$SCRIPT_DIR/upstream-install.sh"
    
    # 1. Determine Version
    if [ -n "$MISE_VERSION" ]; then
        REQUESTED_VERSION="$MISE_VERSION"
    else
        REQUESTED_VERSION=$(cat "$MANIFEST_DIR/latest")
    fi
    
    CONFIG_FILE="$MANIFEST_DIR/${REQUESTED_VERSION}.conf"
    
else
    echo "Nebula: Remote execution detected. Fetching resources from $RAW_REPO_BASE..."
    
    TEMP_DIR="$(mktemp -d)"
    UPSTREAM_SCRIPT="$TEMP_DIR/upstream-install.sh"
    
    CURL_OPTS=(-sfL)
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Nebula: Using GITHUB_TOKEN for authentication."
        CURL_OPTS+=(-H "Authorization: token $GITHUB_TOKEN")
    fi
    
    # 1. Determine Version
    if [ -n "$MISE_VERSION" ]; then
        REQUESTED_VERSION="$MISE_VERSION"
    else
        # Fetch latest
        REQUESTED_VERSION=$(curl "${CURL_OPTS[@]}" "$RAW_REPO_BASE/$MANIFEST_DIR_REL/latest") || { echo "Error: Failed to fetch latest version"; exit 1; }
    fi
    # Trim whitespace just in case
    REQUESTED_VERSION=$(echo "$REQUESTED_VERSION" | xargs)
    
    CONFIG_FILE="$TEMP_DIR/${REQUESTED_VERSION}.conf"
    
    # Fetch Config & Upstream
    curl "${CURL_OPTS[@]}" "$RAW_REPO_BASE/$MANIFEST_DIR_REL/${REQUESTED_VERSION}.conf" -o "$CONFIG_FILE" || { echo "Error: Failed to download config for $REQUESTED_VERSION"; exit 1; }
    curl "${CURL_OPTS[@]}" "$RAW_REPO_BASE/$UPSTREAM_REL_PATH" -o "$UPSTREAM_SCRIPT" || { echo "Error: Failed to download upstream script"; exit 1; }
fi

echo "Nebula: Requesting install for mise version: $REQUESTED_VERSION"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file for version '$REQUESTED_VERSION' not found."
    exit 1
fi

# 2. Parse Config
# We source the values safely by reading the file line by line or using simple grep/cut
# Using grep/cut to avoid arbitrary code execution from sourced files (paranoia)
EXPECTED_SHA=$(grep "^BOOTSTRAPPER_SHA256=" "$CONFIG_FILE" | cut -d= -f2 | xargs)
ALLOWED_PLATFORMS=$(grep "^ALLOWED_PLATFORMS=" "$CONFIG_FILE" | cut -d= -f2 | xargs)

if [ -z "$EXPECTED_SHA" ]; then
    echo "Error: BOOTSTRAPPER_SHA256 not found in $CONFIG_FILE"
    exit 1
fi

# 3. Validate Bootstrapper Integrity
if [ ! -f "$UPSTREAM_SCRIPT" ]; then
    echo "Error: Upstream script not found at $UPSTREAM_SCRIPT"
    exit 1
fi

ACTUAL_SHA=$(sha256sum "$UPSTREAM_SCRIPT" | awk '{print $1}')

if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "SECURITY ALERT: The local bootstrapper script does not match the validated checksum!"
  echo "Expected: $EXPECTED_SHA"
  echo "Actual:   $ACTUAL_SHA"
  echo "This indicates the file has been modified or corrupted."
  exit 1
fi

# 4. Validate Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
PLATFORM="${OS}-${ARCH}"

# Check allowed platforms (comma separated)
if [[ ",$ALLOWED_PLATFORMS," != *",$PLATFORM,"* ]]; then
   echo "Error: Platform '$PLATFORM' is not in the allowed list: $ALLOWED_PLATFORMS"
   exit 1
fi

echo "Nebula: Validation Passed (Script SHA & Platform $PLATFORM verified)."
echo "Nebula: Executing upstream installer..."

# 5. Execute Protected Installer
export MISE_VERSION="$REQUESTED_VERSION"
# We run the cached script
bash "$UPSTREAM_SCRIPT"
