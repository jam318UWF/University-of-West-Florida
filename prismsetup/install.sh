
#!/usr/bin/env bash
# ============================================================
# UWF CPTC - Kali Linux Competition Setup
# Run: bash setup/install.sh
# ============================================================

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[+]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[-]${NC} $*"; }

# Repository location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILED_PACKAGES=()
MISSING_COMMANDS=()

echo "============================================"
echo "       UWF CPTC - Kali Setup Installer"
echo "============================================"
echo

# ------------------------------------------------------------
# 1. Prerequisites
# ------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    fail "Run as a normal user, not root."
    echo "The script uses sudo when required."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    fail "APT not found. This script requires Kali/Debian."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required."
    exit 1
fi

log "Repository: $REPO_ROOT"

sudo -v || exit 1

# ------------------------------------------------------------
# 2. Refresh package lists
# ------------------------------------------------------------

log "Updating APT package indexes..."

if sudo apt-get update; then
    ok "APT updated"
else
    warn "APT update failed."
    warn "Internet connectivity or repository configuration may be unavailable."
    warn "Continuing with available package indexes."
fi

# ------------------------------------------------------------
# 3. Package installation helper
# ------------------------------------------------------------

install_packages() {
    local category="$1"
    shift

    echo
    log "Installing $category..."

    for pkg in "$@"; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null \
           | grep -qx "install ok installed"; then
            ok "$pkg already installed"
            continue
        fi

        if sudo DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "$pkg"; then
            ok "$pkg installed"
        else
            fail "Could not install $pkg"
            FAILED_PACKAGES+=("$pkg")
        fi
    done
}

# ------------------------------------------------------------
# 4. Core dependencies
# ------------------------------------------------------------

install_packages "Core utilities" \
    git curl wget unzip zip \
    jq tree file \
    ca-certificates \
    build-essential \
    python3 python3-pip python3-venv pipx

# ------------------------------------------------------------
# 5. Network enumeration
# ------------------------------------------------------------

install_packages "Network enumeration" \
    nmap \
    netcat-openbsd \
    dnsutils \
    whois \
    traceroute \
    tcpdump \
    tshark

# ------------------------------------------------------------
# 6. Windows / Active Directory
# ------------------------------------------------------------

install_packages "Windows and Active Directory" \
    smbclient \
    smbmap \
    enum4linux-ng \
    ldap-utils \
    krb5-user \
    impacket-scripts \
    netexec \
    certipy-ad

# ------------------------------------------------------------
# 7. Web application assessment
# ------------------------------------------------------------

install_packages "Web application tools" \
    gobuster \
    ffuf \
    feroxbuster \
    nikto \
    whatweb \
    sqlmap \
    dirb \
    seclists

# ------------------------------------------------------------
# 8. Automated reconnaissance
# ------------------------------------------------------------

install_packages "Automated reconnaissance" \
    autorecon \
    dnsrecon

# ------------------------------------------------------------
# 9. Optional utilities
# ------------------------------------------------------------

install_packages "Additional utilities" \
    john \
    hashcat \
    hydra \
    rlwrap \
    proxychains4 \
    responder

# ------------------------------------------------------------
# 10. Prepare workspace
# ------------------------------------------------------------

log "Preparing CPTC workspace..."

mkdir -p \
    "$REPO_ROOT/scans" \
    "$REPO_ROOT/evidence" \
    "$REPO_ROOT/notes"

# Ignore local output and virtual environments
GITIGNORE="$REPO_ROOT/.gitignore"

for entry in \
    "/scans/" \
    "/evidence/" \
    "/notes/" \
    "**/.venv/" \
    "**/__pycache__/"; do

    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
        printf '%s\n' "$entry" >> "$GITIGNORE"
    fi
done

ok "Workspace initialized"

# ------------------------------------------------------------
# 11. Verify installed commands
# ------------------------------------------------------------

echo
log "Verifying tool availability..."

COMMANDS=(
    git
    python3
    nmap
    nxc
    smbclient
    ldapsearch
    impacket-GetUserSPNs
    certipy-ad
    gobuster
    ffuf
    feroxbuster
    nikto
    sqlmap
    autorecon
    dnsrecon
    john
    hashcat
)

for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    else
        warn "$cmd not found"
        MISSING_COMMANDS+=("$cmd")
    fi
done

# ------------------------------------------------------------
# 12. Summary
# ------------------------------------------------------------

echo
echo "============================================"
echo "           Installation Summary"
echo "============================================"

echo "Repository: $REPO_ROOT"
echo "Failed packages: ${#FAILED_PACKAGES[@]}"
echo "Missing commands: ${#MISSING_COMMANDS[@]}"

if (( ${#FAILED_PACKAGES[@]} > 0 )); then
    echo
    warn "Packages requiring attention:"
    printf ' - %s\n' "${FAILED_PACKAGES[@]}"
fi

if (( ${#MISSING_COMMANDS[@]} > 0 )); then
    echo
    warn "Commands requiring verification:"
    printf ' - %s\n' "${MISSING_COMMANDS[@]}"
    echo "Some packages install commands under different names."
fi

echo
if (( ${#FAILED_PACKAGES[@]} == 0 &&
      ${#MISSING_COMMANDS[@]} == 0 )); then
    ok "CPTC environment ready."
else
    warn "Setup completed with warnings."
    warn "Review missing tools before the competition."
fi

echo
echo "Results directory: $REPO_ROOT/scans"
echo "Evidence directory: $REPO_ROOT/evidence"
echo "Notes directory: $REPO_ROOT/notes"

# Nonzero exit status if any package installation failed
if (( ${#FAILED_PACKAGES[@]} > 0 )); then
    exit 1
fi
