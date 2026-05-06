#!/bin/bash
# ============================================================
# BackupPC - Entrypoint
# ============================================================
set -euo pipefail

WHITE='\033[1;37m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${WHITE}[INFO]${NC} $*"; }
bpclog()  { echo -e "${GREEN}[BackupPC]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Variables ───────────────────────────────────────────────────────
TEMPLATE_DIR="/opt/app/template"
BACKUPPC_CONFIG_DIR="/etc/backuppc"
BACKUPPC_CONFIG="${BACKUPPC_CONFIG_DIR}/config.pl"
BACKUPPC_DATA="/var/lib/backuppc"
HTPASSWD_FILE="${BACKUPPC_CONFIG_DIR}/htpasswd"
SSH_DIR="${BACKUPPC_DATA}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"

# Required
: "${WEBUI_USER:?WEBUI_USER is required (ex: backuppc)}"
: "${WEBUI_PASSWORD:?WEBUI_PASSWORD is required}"



# ── 0. Initializing directories ─────────────────────────────────────
DIRS="/etc/backuppc /var/lib/backuppc /var/log/backuppc"

for dir in $DIRS; do
    template_path="${TEMPLATE_DIR}${dir}"

    # If the directory does not exist OR is empty
    if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        log "Initializing $dir from the template"
        mkdir -p "$dir"
        
        if [ -d "$template_path" ]; then
            cp -a "$template_path/." "$dir/"
        fi

        #chown -R backuppc:backuppc "$dir"
    fi
done



# ── 1. Set web user name and password ───────────────────────────────
WEBUI_USER="${WEBUI_USER:-backuppc}"

bpclog "WebUI — user configuration: ${WEBUI_USER}"

if [ ! -f "${HTPASSWD_FILE}" ]; then
    htpasswd -cbB "${HTPASSWD_FILE}" "${WEBUI_USER}" "${WEBUI_PASSWORD}"
else
    htpasswd -bB "${HTPASSWD_FILE}" "${WEBUI_USER}" "${WEBUI_PASSWORD}"
fi

chown backuppc:backuppc "${HTPASSWD_FILE}"
chmod 640 "${HTPASSWD_FILE}"

if [ ! -f "${BACKUPPC_CONFIG}" ]; then
    err "Configuration file not found: ${BACKUPPC_CONFIG}"
    exit 1
fi

sed -i "s|\$Conf{AdminUsers}.*|\$Conf{AdminUsers} = '${WEBUI_USER}';|" "${BACKUPPC_CONFIG}"



# ── 2. BackupPC user ssh keys ───────────────────────────────────────
mkdir -p "${SSH_DIR}"
chown backuppc:backuppc "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [ ! -f "${SSH_KEY}" ]; then
    bpclog "Generating SSH keys for the backuppc user..."
    su - backuppc -c "ssh-keygen -t ed25519 -f \"${SSH_KEY}\" -N \"\" -C \"backuppc@$(hostname)\""
    
    bpclog "SSH keys generated."
    bpclog "Public key (to be deployed on remote hosts):"
    echo "────────────────────────────────────────────────────"
    cat "${SSH_KEY}.pub"
    echo "────────────────────────────────────────────────────"
else
    bpclog "SSH keys already present."
fi

if [ ! -f "${SSH_DIR}/known_hosts" ]; then
    touch "${SSH_DIR}/known_hosts"
    chown backuppc:backuppc "${SSH_DIR}/known_hosts"
    chmod 600 "${SSH_DIR}/known_hosts"
fi



if [ "${ROOTLESS_RUNTIME}" = "true" ]; then
    bpclog "Rootless runtime mode: allow ping for non-root users"
    chmod u+s /usr/bin/ping
fi


# ── 3. Startup services ─────────────────────────────────────────────
bpclog "Starting Apache..."
apachectl -D FOREGROUND &
APACHE_PID=$!
sleep 1

bpclog "Starting BackupPC..."
service backuppc start || err "BackupPC failed to start — see logs above."

bpclog ""
bpclog "══════════════════════════════════════════════"
bpclog "  BackupPC is ready !"
bpclog "  WebUI    : http://localhost/backuppc"
bpclog "  Login    : ${WEBUI_USER}"
bpclog "══════════════════════════════════════════════"
bpclog ""


# ── 4. Signal handling ──────────────────────────────────────────────
_shutdown() {
    bpclog "Stopping services..."
    service backuppc stop 2>/dev/null || true
    service apache2 stop 2>/dev/null || true
    wait "${APACHE_PID}" 2>/dev/null || true
    bpclog "Service stopped."
    exit 0
}
trap _shutdown SIGTERM SIGINT SIGQUIT

wait "${APACHE_PID}"
_shutdown
