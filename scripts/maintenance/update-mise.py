#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import urllib.request
import hashlib

# Configuration
REPO_ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode("utf-8").strip()
MANIFEST_DIR = os.path.join(REPO_ROOT, "manifests/mise")
UPSTREAM_SCRIPT_PATH = os.path.join(REPO_ROOT, "scripts/mise/upstream-install.sh")
LATEST_FILE = os.path.join(MANIFEST_DIR, "latest")
ALLOWED_PLATFORMS = "linux-x64" # Default for new versions

def get_latest_mise_version():
    url = "https://api.github.com/repos/jdx/mise/releases/latest"
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read().decode())
        return data["tag_name"]

def version_exists(version):
    return os.path.exists(os.path.join(MANIFEST_DIR, f"{version}.conf"))

def calculate_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def update_upstream_script(version):
    # mise.run usually points to the latest. 
    # To get a specific version installation script, we typically use the same script 
    # but the environment variable MISE_VERSION controls what binary it downloads.
    # However, if the INSTALLER SCRIPT itself changes, we need to capture that.
    # For now, we assume https://mise.run is the source of truth for the installer.
    url = "https://mise.run"
    print(f"Downloading installer from {url}...")
    urllib.request.urlretrieve(url, UPSTREAM_SCRIPT_PATH)

def create_manifest(version, sha):
    config_path = os.path.join(MANIFEST_DIR, f"{version}.conf")
    with open(config_path, "w") as f:
        f.write(f"BOOTSTRAPPER_SHA256={sha}\n")
        f.write(f"ALLOWED_PLATFORMS={ALLOWED_PLATFORMS}\n")
    print(f"Created {config_path}")

def update_latest_pointer(version):
    with open(LATEST_FILE, "w") as f:
        f.write(version)
    print(f"Updated latest pointer to {version}")

def run_command(cmd):
    print(f"Running: {' '.join(cmd)}")
    subprocess.check_call(cmd)

def main():
    print("Checking for mise updates...")
    latest_version = get_latest_mise_version()
    print(f"Latest upstream version: {latest_version}")

    if version_exists(latest_version):
        print("Version already exists in manifests. No action needed.")
        sys.exit(0)

    print(f"New version detected: {latest_version}")
    
    # Create Branch
    branch_name = f"chore/update-mise-{latest_version}"
    run_command(["git", "checkout", "-b", branch_name])

    # Update Script
    update_upstream_script(latest_version)
    
    # Calculate SHA
    sha = calculate_sha256(UPSTREAM_SCRIPT_PATH)
    print(f"New Installer SHA: {sha}")

    # Create Manifest
    create_manifest(latest_version, sha)

    # Update Latest
    update_latest_pointer(latest_version)

    print("\nUpdate complete.")
    print("Please run regression tests before pushing:")
    print("./tests/run_tests.sh")

if __name__ == "__main__":
    main()
