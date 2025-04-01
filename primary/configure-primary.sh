#!/bin/bash
# ########################################################################### #
# https://railway.com
# ########################################################################### #
set -e

# ANSI colors
GREEN_R='\033[0;32m'
GREEN_B='\033[1;92m'
RED_R='\033[0;31m'
RED_B='\033[1;91m'
YELLOW_R='\033[0;33m'
YELLOW_B='\033[1;93m'
PURPLE_R='\033[0;35m'
PURPLE_B='\033[1;95m'
WHITE_R='\033[0;37m'
WHITE_B='\033[1;97m'
NC='\033[0m'

# is_dry_run() checks if the --dry-run flag is present in the arguments.
# Returns true if the flag is present, false otherwise.
#
# Usage:
#
#   DRY_RUN=$(is_dry_run "$@")
#   if [ "$DRY_RUN" = "true" ]; then
#       echo "dryrun"
#   else
#       echo "normal"
#   fi
is_dry_run() {
    local dry_run=false
    for arg in "$@"; do
        case $arg in
            --dry-run)
                dry_run=true
                break
                ;;
        esac
    done
    echo "$dry_run"
}

# confirm() shows a prompt to the user and returns true if the user types
# 'y' or 'Y'. Returns false otherwise.
#
# Usage:
#
#   if confirm "Continue?"; then
#     # yes
#   else
#    # no
#    exit 1
#   fi
confirm() {
   local prompt="$1"
   local default="$2"
   default=${default:-"N"}
   if [ "$default" = "Y" ]; then
       echo ""
       prompt="$prompt [Y/n]: "
       echo ""
   else
       echo ""
       prompt="$prompt [y/N]: "
       echo ""
   fi
   read -r -p "$prompt" response
   if [ -z "$response" ]; then
       response=$default
   fi
   if [[ "$response" =~ ^[Yy]$ ]]; then
       return 0
   else
       return 1
   fi
}

ts() {
    date +'%d-%m-%Y %H:%M:%S'
}

log() {
  echo -e "[$(ts)][ ${WHITE_R}ℹ️ INFO${NC} ] ${WHITE_B}$1${NC}"
}

log_hl() {
  echo -e "[$(ts)][ ${PURPLE_R}ℹ️ INFO${NC} ] ${PURPLE_B}$1${NC}"
}

log_ok() {
  echo -e "[$(ts)][ ${GREEN_R}✅ OK${NC}   ] ${GREEN_B}$1${NC}"
}

log_warn() {
  echo -e "[$(ts)][ ${YELLOW_R}⚠️ WARN${NC} ] ${YELLOW_B}$1${NC}"
}

log_err() {
  echo -e "[$(ts)][ ${RED_R}⛔ ERR${NC}  ] ${RED_B}$1${NC}" >&2
}

log_dry_run() {
  echo -e "[$(ts)][ ${YELLOW_R}ℹ️ DRY${NC}  ] ${YELLOW_B}$1${NC}"
}

REQUIRED_ENV_VARS=(\
    "RAILWAY_VOLUME_NAME" \
    "RAILWAY_VOLUME_MOUNT_PATH" \
    "RAILWAY_PROJECT_NAME" \
    "RAILWAY_SERVICE_NAME" \
    "RAILWAY_ENVIRONMENT" \
    "RAILWAY_PROJECT_ID" \
    "RAILWAY_SERVICE_ID" \
    "RAILWAY_ENVIRONMENT_ID" \
    "PGHOST" \
    "PGPORT" \
    "REPMGR_USER_PASSWORD" \
)
for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_err "Missing required environment variable: $var"
        exit 1
    fi
done

DRY_RUN=$(is_dry_run "$@")

RAILWAY_SERVICE_URL="https://railway.app/project/${RAILWAY_PROJECT_ID}/service/${RAILWAY_SERVICE_ID}?environmentId=${RAILWAY_ENVIRONMENT_ID}"

log "--------------------------------------------------------------------"
log_hl "|        Railway PostgreSQL Replication Configuration Script        |"
log "--------------------------------------------------------------------"
log ""
log_hl "Before proceeding, please ensure you have read the documentation:"
log ""
log "  https://docs.railway.com/tutorials/set-up-postgres-replication"
log ""
log_hl "You are running this script the following Railway database:"
log ""
log "  - Project       : ${RAILWAY_PROJECT_NAME}"
log "  - Service       : ${RAILWAY_SERVICE_NAME}"
log "  - Environment   : ${RAILWAY_ENVIRONMENT}"
log "  - URL           : ${RAILWAY_SERVICE_URL}"
log "  - PGHOST/PGPORT : ${PGHOST} / ${PGPORT}"
log ""
log_hl "THIS SCRIPT SHOULD ONLY BE EXECUTED ON THE DATABASE YOU WISH TO "
log_hl "DESIGNATE AS THE PRIMARY NODE."
log ""
log_hl "  - This script will make changes to your current PostgreSQL "
log_hl "    configuration and set up repmgr"
log_hl ""
log_hl "  - A re-deploy of your database is required for changes to take "
log_hl "    effect after configuration is finished"
log_hl ""
log_hl "  - Please ensure you have a backup of your data before proceeding"
log_hl "    Refer to https://docs.railway.com/reference/backups for more"
log_hl "    information on how to create backups"
log ""
if [ "$DRY_RUN" = true ]; then
    log_warn "--dry-run enabled. You will see a list of changes that will "
    log_warn "be applied, but no changes will be made. To apply changes, "
    log_warn "run without the --dry-run flag."
fi
confirm "Continue?" || {
    log "Exiting..."
    exit 0
}
log ""

REQUIRED_COMMANDS=(\
    "pg_config" \
    "repmgr" \
    "psql" \
    "sed" \
    "grep" \
    "cat" \
)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_err "Required cmd '$cmd' not found in PATH"
        log_err "Please ensure you have completed the dependencies"
        log_err "installation step before running this script."
        log_err ""
        log_err "https://docs.railway.com/tutorials/set-up-postgres-replication"
        exit 1
    fi
done

# Ensure PostgreSQL data directory exists
if [ ! -d "$PGDATA" ]; then
    log_err "PostgreSQL data directory '$PGDATA' not found"
    exit 1
fi
log_ok "Found PostgreSQL data directory at '$PGDATA'"

# Ensure PostgreSQL configuration file exists
POSTGRESQL_CONF="$PGDATA/postgresql.conf"
if [ ! -f "$POSTGRESQL_CONF" ]; then
    log_err "PostgreSQL configuration file '$POSTGRESQL_CONF' not found"
    exit 1
fi
log_ok "Found PostgreSQL configuration file at '$POSTGRESQL_CONF'"

# Create Railway runtime dir
REPMGR_DIR="${RAILWAY_VOLUME_MOUNT_PATH}/repmgr"
REPMGR_CONF="$REPMGR_DIR/repmgr.conf"
if [ $DRY_RUN = true ]; then
    log_dry_run "create directory '$REPMGR_DIR'"
else
    mkdir -p "$REPMGR_DIR"
fi

# Create replication configuration. If there's an existing replication conf,
# do nothing
if grep -q \
    "include 'postgresql.replication.conf'" "$POSTGRESQL_CONF" 2>/dev/null; then
        log_err "Include directive already exists in '$POSTGRESQL_CONF'. This"
        log_err "script should only be ran once."
    exit 1
fi

POSTGRESQL_CONF_BAK="$PGDATA/postgresql.bak.conf"
REPLICATION_CONF="$PGDATA/postgresql.replication.conf"

if [ "$DRY_RUN" = true ]; then
    # 1. Create the replication configuration file
    log_dry_run "create file '$REPLICATION_CONF' with content:"
    log_dry_run ""
    log_dry_run "  max_wal_senders = 10"
    log_dry_run "  max_replication_slots = 10"
    log_dry_run "  wal_level = replica"
    log_dry_run "  wal_log_hints = on"
    log_dry_run "  hot_standby = on"
    log_dry_run "  archive_mode = on"
    log_dry_run "  archive_command = '/bin/true'"
    log_dry_run ""

    # 2. Backup the original postgresql.conf file
    log_dry_run "back up '$POSTGRESQL_CONF' to '$POSTGRESQL_CONF_BAK'"
    log_dry_run ""

    # 3. Add the include directive to postgresql.conf
    log_dry_run "append to '$POSTGRESQL_CONF' this line:"
    log_dry_run ""
    log_dry_run "  # Added by Railway on $(date +'%Y-%m-%d %H:%M:%S')"
    log_dry_run "  include 'postgresql.replication.conf'"
    log_dry_run ""

    # 4. Create repmgr user and database
    log_dry_run "execute the following psql commands:"
    log_dry_run ""
    log_dry_run "  CREATE USER repmgr WITH SUPERUSER PASSWORD '${REPMGR_USER_PASSWORD}';"
    log_dry_run "  CREATE DATABASE repmgr;"
    log_dry_run "  GRANT ALL PRIVILEGES ON DATABASE repmgr TO repmgr;"
    log_dry_run "  ALTER USER repmgr SET search_path TO repmgr, railway, public;"
    log_dry_run ""

    # 5. Create repmgr directory
    log_dry_run "create directory '$REPMGR_DIR'"
    log_dry_run ""

    # 6. Create repmgr configuration file
    log_dry_run "create '$REPMGR_CONF' with content:"
    log_dry_run ""
    log_dry_run "  node_id=1"
    log_dry_run "  node_name='node1'"
    log_dry_run "  conninfo='host=${PGHOST} port=${PGPORT} user=repmgr dbname=repmgr connect_timeout=10'"
    log_dry_run "  data_directory='${PGDATA}'"
    log_dry_run "  use_replication_slots=yes"
    log_dry_run "  monitoring_history=yes"
    log_dry_run ""

    # 7. Register primary node
    log_dry_run "register primary node with:"
    log_dry_run ""
    log_dry_run "  su -m postgres -c \"repmgr -f $REPMGR_CONF primary register\""

    # 8. Modify pg_hba.conf
    PG_HBA_CONF="$PGDATA/pg_hba.conf"
    PG_HBA_CONF_BAK="$PGDATA/pg_hba.conf.bak"
    log_dry_run "verify last line of '$PG_HBA_CONF' is 'host all all all scram-sha-256'"
    log_dry_run "back up '$PG_HBA_CONF' to '$PG_HBA_CONF_BAK'"
    log_dry_run "add the following line before the last line of '$PG_HBA_CONF':"
    log_dry_run "# Added by Railway on $(date +'%Y-%m-%d %H:%M:%S')"
    log_dry_run "host replication repmgr ::0/0 trust"
else

    # 1. Create the replication configuration file
    log "Creating replication configuration file at '$REPLICATION_CONF'"
    cat > "$REPLICATION_CONF" << EOF
max_wal_senders = 10
max_replication_slots = 10
wal_level = replica
wal_log_hints = on
hot_standby = on
archive_mode = on
archive_command = '/bin/true'
EOF

    # 2. Backup the original postgresql.conf file
    log "Backing up '$POSTGRESQL_CONF' to '$POSTGRESQL_CONF_BAK'"
    cp "$POSTGRESQL_CONF" "$POSTGRESQL_CONF_BAK"
    log_ok "Created backup of PostgreSQL configuration at '$POSTGRESQL_CONF_BAK'"

    # 3. Add the include directive to postgresql.conf
    echo "" >> "$POSTGRESQL_CONF"
    echo "# Added by Railway on $(date +'%Y-%m-%d %H:%M:%S')" >> "$POSTGRESQL_CONF"
    echo "include 'postgresql.replication.conf'" >> "$POSTGRESQL_CONF"
    log_ok "Added include directive to '$POSTGRESQL_CONF'"

    # 4. Create repmgr user and database
    log "Creating repmgr user and database..."
    if ! psql -c "SELECT 1 FROM pg_roles WHERE rolname='repmgr'" | grep -q 1; then
        psql -c "CREATE USER repmgr WITH SUPERUSER PASSWORD '${REPMGR_USER_PASSWORD}';"
        log_ok "Created repmgr user"
    else
        log "User repmgr already exists"
    fi

    if ! psql -c "SELECT 1 FROM pg_database WHERE datname='repmgr'" | grep -q 1; then
        psql -c "CREATE DATABASE repmgr;"
        log_ok "Created repmgr database"
    else
        log "Database repmgr already exists"
    fi

    psql -c "GRANT ALL PRIVILEGES ON DATABASE repmgr TO repmgr;"
    psql -c "ALTER USER repmgr SET search_path TO repmgr, railway, public;"
    log_ok "Configured repmgr user and database permissions"

    # 5. Create repmgr directory and copy binary
    log "Setting up repmgr configuration and binary..."
    if [ ! -d "$REPMGR_DIR" ]; then
        mkdir -p "$REPMGR_DIR"
    fi
    REPMGR_SRC_PATH=$(command -v repmgr)
    if [ -z "$REPMGR_SRC_PATH" ]; then
        log_err "Cannot find repmgr binary"
        exit 1
    fi

    # 6. Create repmgr configuration file
    cat > "$REPMGR_CONF" << EOF
node_id=1
node_name='node1'
conninfo='host=${PGHOST} port=${PGPORT} user=repmgr dbname=repmgr connect_timeout=10'
data_directory='${PGDATA}'
use_replication_slots=yes
monitoring_history=yes
EOF
    chown postgres:postgres "$REPMGR_CONF"
    chmod 600 "$REPMGR_CONF"
    log_ok "Created repmgr configuration at '$REPMGR_CONF'"

    # 7. Register primary node
    log "Registering primary node with repmgr..."
    export PGPASSWORD="$REPMGR_USER_PASSWORD"
    if su -m postgres -c "repmgr -f $REPMGR_CONF primary register"; then
        log_ok "Successfully registered primary node"
    else
        log_err "Failed to register primary node with repmgr"
        exit 1
    fi

    # 8. Modify pg_hba.conf
    PG_HBA_CONF="$PGDATA/pg_hba.conf"
    PG_HBA_CONF_BAK="$PGDATA/pg_hba.conf.bak"

    log "Verifying and modifying pg_hba.conf..."

    # Verify the last line
    LAST_LINE=$(tail -n 1 "$PG_HBA_CONF")
    if [ "$LAST_LINE" != "host all all all scram-sha-256" ]; then
        log_err "The last line of pg_hba.conf is not 'host all all all scram-sha-256'"
        log_err "Current last line: '$LAST_LINE'"
        log_err "Skipping pg_hba.conf modification"
    else
        # Create backup of pg_hba.conf
        cp "$PG_HBA_CONF" "$PG_HBA_CONF_BAK"
        log_ok "Created backup of pg_hba.conf at '$PG_HBA_CONF_BAK'"

        # Create temporary file with the desired content
        TEMP_FILE=$(mktemp)
        # Get all lines except the last one
        head -n -1 "$PG_HBA_CONF" > "$TEMP_FILE"
        # Add our new line
        echo "# Added by Railway on $(date +'%Y-%m-%d %H:%M:%S')" >> "$TEMP_FILE"
        echo "host replication repmgr ::0/0 trust" >> "$TEMP_FILE"
        # Add the last line back
        echo "host all all all scram-sha-256" >> "$TEMP_FILE"

        # Replace the original file
        mv "$TEMP_FILE" "$PG_HBA_CONF"
        chmod 600 "$PG_HBA_CONF"
        chown postgres:postgres "$PG_HBA_CONF"

        log_ok "Successfully updated pg_hba.conf with replication access"
    fi
fi

if [ "$DRY_RUN" = true ]; then
    log_warn ""
    log_warn "✅ Configuration complete in --dry-run mode. No changes were made"
    log_warn "📢 To apply changes, run without the --dry-run flag"
    log_warn ""
else
    log_ok ""
    log_ok "✅ Configuration complete"
    log_ok "🚀 For changes to take effect, please re-deploy your Postgres service:"
    log_ok ""
    log_ok "  ${RAILWAY_SERVICE_URL} "
    log_ok ""
    log_ok "After re-deploying, you can proceed with setting up the replica"
    log_ok "by following the instructions in the documentation:"
    log_ok ""
    log_ok "  https://docs.railway.com/tutorials/set-up-postgres-replication#2-configure-the-replica"
    log_ok ""
fi
