#!/bin/bash
set -e

# Determine Branch
BRANCH="${NEBULA_REPO_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo "Error: Testing on main/master branch is restricted. Please create a feature branch."
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "WARNING: You have uncommitted changes. The test will run against the REMOTE code on $BRANCH."
    echo "If your changes are not pushed, the test will verify the OLD code."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
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

docker run --rm \
    -v "$WORKSPACE_DIR:/workspace" \
    -e NEBULA_REPO_BRANCH="$BRANCH" \
    nebula-upsteam-tests \
    pytest test_install.py -v
