#!/bin/bash
# ########################################################################### #
# https://railway.com
# ########################################################################### #
set -e
source ./_include.sh

log "Detecting PostgreSQL version..."
PG_VERSION_OUTPUT=$(pg_config --version)
POSTGRES_MAJOR_VERSION=$(\
    echo "$PG_VERSION_OUTPUT" | sed -E 's/^PostgreSQL ([0-9]+)\..*$/\1/'\
)
if [ -z "$POSTGRES_MAJOR_VERSION" ]; then
    log_error "Failed to detect PostgreSQL major version"
    exit 1
fi
log_ok "  - PostgreSQL version string : $PG_VERSION_OUTPUT"
log_ok "  - PostgreSQL major version  : $POSTGRES_MAJOR_VERSION"

# Install repmgr for the detected PostgreSQL version
REPMGR_PACKAGE="postgresql-${POSTGRES_MAJOR_VERSION}-repmgr"

apt-get update
if ! apt-get install -y "$REPMGR_PACKAGE"; then
    log_error "Failed to install $REPMGR_PACKAGE"
    exit 1
fi
if ! command -v repmgr >/dev/null 2>&1; then
    log_error "Failed to install $REPMGR_PACKAGE"
    exit 1
fi
log_ok "Installed $(repmgr --version)"

utilities=(vim)
utilities_str=$(printf '%s ' "${utilities[@]}")
apt-get install -y "${utilities[@]}"
log_ok "Installed utilities: $utilities_str"
