#!/bin/bash
set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=0

# Helper for logging to stderr
log() {
    echo "$@" >&2
}

# Parse args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --force) FORCE=1 ;;
        *) log "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

log "Checking development environment..."

# 1. Create Virtual Env
if [ ! -d "$PROJECT_ROOT/.venv" ]; then
    log "Creating .venv..."
    python3 -m venv "$PROJECT_ROOT/.venv"
    # New venv implies force install
    FORCE=1
else
    log ".venv already exists."
fi

# 2. Activate
source "$PROJECT_ROOT/.venv/bin/activate"

# 3. Check Dependencies
REQ_FILE="$PROJECT_ROOT/tests/requirements.txt"

MARKER_FILE="$PROJECT_ROOT/.venv/.last_install_success"

SHOULD_INSTALL=0
if [ "$FORCE" -eq 1 ]; then
    SHOULD_INSTALL=1
elif [ ! -f "$MARKER_FILE" ]; then
    SHOULD_INSTALL=1
elif [ -n "$(find "$REQ_FILE" -newer "$MARKER_FILE" 2>/dev/null)" ]; then
    # If requirements file is newer than the marker
    SHOULD_INSTALL=1
fi

if [ "$SHOULD_INSTALL" -eq 1 ]; then
    log "Installing/Updating dependencies..."
    pip install --upgrade pip
    
    if [ -f "$REQ_FILE" ]; then
        pip install -r "$REQ_FILE"
    fi
    
    # Touch marker file
    touch "$MARKER_FILE"
    log "Dependencies updated."
else
    log "Skipping install (dependencies up to date). Run with --force to override."
fi

log "Environment ready."
