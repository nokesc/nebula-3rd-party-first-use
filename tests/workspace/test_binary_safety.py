import os
import subprocess
import shutil
import pytest

# We use the same branch logic
BRANCH = os.environ.get("NEBULA_REPO_BRANCH", "master")
RAW_BASE = f"https://raw.githubusercontent.com/nokesc/nebula-3rd-party-first-use/{BRANCH}"
INSTALL_CMD = f"curl -sSfL {RAW_BASE}/scripts/mise/install.sh | bash"

@pytest.fixture(scope="module")
def installed_mise_path():
    """Installs mise and returns the path to the binary."""
    # Run the install
    env = os.environ.copy()
    # Ensure non-interactive
    env["MISE_YES"] = "1" 
    
    subprocess.run(INSTALL_CMD, shell=True, check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Path is usually ~/.local/bin/mise in this container setup
    path = os.path.expanduser("~/.local/bin/mise")
    assert os.path.exists(path), f"Mise binary not found at {path} after install"
    return path

def test_binary_clamscan(installed_mise_path):
    """Scans the installed mise binary for malware using ClamAV."""
    
    # Check if clamscan is available
    if not shutil.which("clamscan"):
        pytest.skip("clamscan not found in environment. Skipping antivirus check.")

    # Run clamscan
    # --no-summary suppresses the big stats block
    cmd = ["clamscan", "--no-summary", installed_mise_path]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    # Exit code 0 means clean
    # Exit code 1 means virus found
    # Exit code 2 means error
    
    if result.returncode == 0:
        print(f"\nClamAV Scan: OK - {installed_mise_path}")
    elif result.returncode == 1:
        pytest.fail(f"ClamAV found malware in {installed_mise_path}:\n{result.stdout}")
    else:
        # If the DB is missing/broken (common in ephemeral builds without freshclam working perfect), we might warn instead of fail?
        # But for 'security policy', failing is safer.
        pytest.fail(f"ClamAV execution failed (exit code {result.returncode}):\n{result.stderr}")

def test_binary_architecture(installed_mise_path):
    """Sanity check that the binary matches the system architecture (simple 'file' check)."""
    # This detects if we somehow downloaded a script or weird blob instead of an ELF
    cmd = ["file", installed_mise_path]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    
    output = result.stdout.lower()
    
    # We are on Linux (container), so we expect ELF
    assert "elf" in output, f"Expected ELF binary, but 'file' command said: {result.stdout}"
    assert "executable" in output, f"Expected executable, but 'file' command said: {result.stdout}"
    
    # We are on x86_64 or arm64 usually
    # Just asserting it's an executable is a decent sanity check against "downloaded HTML error page" scenarios
