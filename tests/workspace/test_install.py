import os
import subprocess
import pytest
import shutil
import time

# We now rely on Real GitHub URLs, so we don't need a local server.
# The branch is injected via NEBULA_REPO_BRANCH env var by the runner.
BRANCH = os.environ.get("NEBULA_REPO_BRANCH", "main")
RAW_BASE = f"https://raw.githubusercontent.com/nokesc/nebula-3rd-party-first-use/{BRANCH}"

@pytest.fixture
def clean_env():
    """Ensures environment is clean and temp paths are removed."""
    # Backup PATH
    old_path = os.environ["PATH"]
    # Provide a clean install location
    install_dir = os.path.expanduser("~/.local/bin")
    if os.path.exists(install_dir):
        shutil.rmtree(install_dir)
    os.makedirs(install_dir, exist_ok=True)
    
    yield
    
    # Restore
    os.environ["PATH"] = old_path
    if os.path.exists(install_dir):
        shutil.rmtree(install_dir)

def test_remote_curl_install(clean_env):
    """Test installing via curl piping from Real GitHub."""
    print(f"Testing against branch: {BRANCH} at {RAW_BASE}")
    
    # We construct the URL just like the README says
    url = f"{RAW_BASE}/scripts/mise/install.sh"
    
    cmd = f"curl -sSfL {url} | bash"
    
    # We pass the NEBULA_REPO_BRANCH to the inner shell so the script knows where to pull manifests from
    # (Since the script defaults to main if not set, and we want to test THIS branch)
    env = os.environ.copy()
    env["NEBULA_REPO_BRANCH"] = BRANCH
    
    result = subprocess.run(
        cmd, 
        shell=True, 
        env=env,
        capture_output=True, 
        text=True
    )
    
    if result.returncode != 0:
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)

    assert result.returncode == 0
    assert "Nebula: Remote execution detected" in result.stdout
    assert "Nebula: Validation Passed" in result.stdout
    assert os.path.exists(os.path.expanduser("~/.local/bin/mise"))

def test_tool_version_switching(clean_env):

def test_tool_version_switching(clean_env):
    """Sanity check: Verify mise can install jq and switch versions between directories."""
    
    # 1. Install mise first (clean check)
    install_res = subprocess.run(
        ["./scripts/mise/install.sh"], 
        capture_output=True, 
        text=True
    )
    assert install_res.returncode == 0
    
    mise_bin = os.path.expanduser("~/.local/bin/mise")
    assert os.path.exists(mise_bin)
    
    # Environment for execution: Add mise to PATH and auto-confirm installs
    env = os.environ.copy()
    env["PATH"] = f"{os.path.dirname(mise_bin)}:{env['PATH']}"
    env["MISE_YES"] = "1"
    
    # 2. Setup directories
    base_dir = os.path.expanduser("~/sanity_test")
    dir1 = os.path.join(base_dir, "dir1")
    dir2 = os.path.join(base_dir, "dir2")
    os.makedirs(dir1, exist_ok=True)
    os.makedirs(dir2, exist_ok=True)
    
    try:
        # 3. Configure jq versions
        # Standard jq versions that are likely to be precompiled and available
        print("Installing jq@1.6 in dir1...")
        subprocess.run([mise_bin, "use", "jq@1.6"], cwd=dir1, check=True, env=env, capture_output=True)
        
        print("Installing jq@1.7.1 in dir2...")
        subprocess.run([mise_bin, "use", "jq@1.7.1"], cwd=dir2, check=True, env=env, capture_output=True)
        
        # 4. Verify selection via 'mise exec' (simulates active path)
        # Check dir1 -> Expect 1.6
        res1 = subprocess.run(
            [mise_bin, "exec", "--", "jq", "--version"], 
            cwd=dir1, 
            check=True, 
            env=env, 
            capture_output=True, 
            text=True
        )
        assert "jq-1.6" in res1.stdout
        
        # Check dir2 -> Expect 1.7.1
        res2 = subprocess.run(
            [mise_bin, "exec", "--", "jq", "--version"], 
            cwd=dir2, 
            check=True, 
            env=env, 
            capture_output=True, 
            text=True
        )
        assert "jq-1.7.1" in res2.stdout
        
    finally:
        # Cleanup sanity directories
        if os.path.exists(base_dir):
            shutil.rmtree(base_dir)

