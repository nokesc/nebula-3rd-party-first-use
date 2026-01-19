#!/bin/bash
set -e

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
MANIFEST_FILE="$REPO_ROOT/manifests/mise.json"
UPSTREAM_SCRIPT="$SCRIPT_DIR/upstream-install.sh"

# Helper to look up JSON values with simple grep/cut (avoids jq dependency)
get_manifest_value() {
    local key=$1
    grep "\"$key\":" "$MANIFEST_FILE" | head -n1 | cut -d '"' -f 4
}

# 1. Determine Version
LATEST_VERSION=$(get_manifest_value "latest_validated")
REQUESTED_VERSION="${MISE_VERSION:-$LATEST_VERSION}"

echo "Nebula: Requesting install for mise version: $REQUESTED_VERSION"

# 2. Validate Bootstrapper Integrity
# Extract the specific SHA for this version from the manifest block
# This finds the version key, looks at the next 10 lines (context), finds the sha line, and extracts value.
EXPECTED_SHA=$(grep -A 10 "\"$REQUESTED_VERSION\"" "$MANIFEST_FILE" | grep '"bootstrapper_sha256":' | head -n1 | cut -d '"' -f 4)

if [ -z "$EXPECTED_SHA" ]; then
  echo "Error: Version '$REQUESTED_VERSION' is not allowed/validated in $MANIFEST_FILE"
  exit 1
fi

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

# 3. Validate Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
# Normalize arch to match mise conventions
if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

PLATFORM="${OS}-${ARCH}"

# Check if this platform is allowed for this version
# This scans the version block for the platform string
if ! grep -A 10 "\"$REQUESTED_VERSION\"" "$MANIFEST_FILE" | grep -q "\"$PLATFORM\""; then
   echo "Error: Platform '$PLATFORM' is not in the validated allowed list for version $REQUESTED_VERSION."
   exit 1
fi

echo "Nebula: Validation Passed (Script SHA & Platform $PLATFORM verified)."
echo "Nebula: Executing upstream installer..."

# 4. Execute Protected Installer
export MISE_VERSION="$REQUESTED_VERSION"
# We run the cached script
bash "$UPSTREAM_SCRIPT"
