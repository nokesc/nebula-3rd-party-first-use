import os
import re
import pytest
import subprocess

# We download the upstream script from the remote branch to analyze it
BRANCH = os.environ.get("NEBULA_REPO_BRANCH", "master")
RAW_BASE = f"https://raw.githubusercontent.com/nokesc/nebula-3rd-party-first-use/{BRANCH}"
UPSTREAM_SCRIPT_URL = f"{RAW_BASE}/scripts/mise/upstream-install.sh"

@pytest.fixture(scope="module")
def upstream_script_content():
    """Fetches the upstream script content once for analysis."""
    cmd = f"curl -sSfL {UPSTREAM_SCRIPT_URL}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    assert result.returncode == 0, f"Failed to download upstream script from {UPSTREAM_SCRIPT_URL}"
    return result.stdout

def test_allowed_domains(upstream_script_content):
    """Verify that network calls only go to allowed domains."""
    # Regex to capture URLs
    # Matches http:// or https:// followed by non-whitespace/quote characters
    url_pattern = re.compile(r'https?://[^\s"\')>]+')
    
    found_urls = url_pattern.findall(upstream_script_content)
    
    # Whitelist of trusted domains for mise
    ALLOWED_DOMAINS = [
        "github.com",
        "raw.githubusercontent.com",
        "mise.run",
        "mise.jdx.dev",
        "sh.rustup.rs", # mise might install rust?
        "rtx.pub" # legacy domain for mise/rtx
    ]
    
    violations = []
    for url in found_urls:
        domain_match = re.search(r'https?://([^/]+)', url)
        if domain_match:
            domain = domain_match.group(1)
            # Check if domain ends with any allowed domain (to handle subdomains)
            if not any(domain.endswith(d) for d in ALLOWED_DOMAINS):
                violations.append(url)
                
    assert not violations, f"Found URLs pointing to unauthorized domains: {violations}"

def test_no_sudo_usage(upstream_script_content):
    """Verify sudo is not used (we expect user-space install)."""
    # Simply looking for 'sudo ' might be too aggressive if it's in a comment, but good for alerting.
    # We strip comments first? simplified check for now.
    
    lines = upstream_script_content.splitlines()
    violations = []
    for i, line in enumerate(lines, 1):
        # Ignore comments
        if line.strip().startswith("#"):
            continue
            
        if "sudo " in line:
            violations.append(f"Line {i}: {line.strip()}")
            
    assert not violations, f"Found potential 'sudo' usage. Mise should be installed in user space:\n{violations}"

def test_no_obfuscated_eval(upstream_script_content):
    """Check for base64 decoding piped to bash/sh (typical obfuscation)."""
    if "base64 -d" in upstream_script_content and "| bash" in upstream_script_content:
        pytest.fail("Script appears to use 'base64 -d | bash' pattern, which is highly suspicious.")
        
    if "base64 -d" in upstream_script_content and "| sh" in upstream_script_content:
        pytest.fail("Script appears to use 'base64 -d | sh' pattern, which is highly suspicious.")

def test_no_hardcoded_ips(upstream_script_content):
    """Check for hardcoded IPv4 addresses."""
    # Pattern for 4 octets. Exclude version numbers looking like IPs slightly.
    # Simple regex for x.x.x.x
    ip_pattern = re.compile(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b')
    
    # Common FPs: Version numbers (1.2.3.4), Localhost (127.0.0.1 - usually ok?)
    IGNORED_IPS = ["127.0.0.1", "0.0.0.0"]
    
    found_ips = ip_pattern.findall(upstream_script_content)
    violations = [ip for ip in found_ips if ip not in IGNORED_IPS]
    
    # Heuristic: If it looks like a version number (often near 'v'), ignore it?
    # For now, strict.
    assert not violations, f"Found hardcoded IP addresses: {violations}"
