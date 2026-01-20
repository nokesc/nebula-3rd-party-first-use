#!/bin/bash
set -e

# Determine Branch
BRANCH="${NEBULA_REPO_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

if [ "$BRANCH" = "master" ]; then
    echo "Error: Testing on main/master branch is restricted. Please create a feature branch."
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "WARNING: You have uncommitted changes. The test will run against the REMOTE code on $BRANCH."
    echo "If your changes are not pushed, the test will verify the OLD code."
    
    if [ "$CI" = "true" ]; then
        echo "CI detected: Proceeding automatically (assuming changes were pushed if needed)."
    else
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Build the test image
echo "Building test image..."
docker build -t nebula-upsteam-tests -f tests/Dockerfile .

# Run the tests
echo "Running tests on branch: $BRANCH..."
# Mount only the tests/workspace directory to /workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/workspace"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Discovery: specific version or latest?
if [ -z "$MISE_VERSION" ]; then
    echo "No specific version requested. Running regression on ALL versions found in manifests..."
    # Find all .conf files and extract the version base name
    VERSIONS=$(find "$REPO_ROOT/manifests/mise" -name "*.conf" -exec basename {} .conf \;)
else
    VERSIONS="$MISE_VERSION"
fi

for VER in $VERSIONS; do
    echo "=========================================================="
    echo " TESTING VERSION: $VER"
    echo "=========================================================="
    
    docker run --rm \
        -v "$WORKSPACE_DIR:/workspace" \
        -e NEBULA_REPO_BRANCH="$BRANCH" \
        -e MISE_VERSION="$VER" \
        nebula-upsteam-tests \
        pytest -v
        
    if [ $? -ne 0 ]; then
        echo "FAILED testing version $VER"
        exit 1
    fi
done
