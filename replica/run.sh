#!/bin/bash
# ########################################################################### #
# https://railway.com
# ########################################################################### #
set -e
source _common.sh

log_hl "RAILWAY_VOLUME_NAME         = $RAILWAY_VOLUME_NAME"
log_hl "RAILWAY_VOLUME_MOUNT_PATH   = $RAILWAY_VOLUME_MOUNT_PATH"
log_hl "PRIMARY_PGHOST              = $PRIMARY_PGHOST"
log_hl "PRIMARY_PGPORT              = $PRIMARY_PGPORT"
log_hl "PRIMARY_REPMGR_PWD          = ***${PRIMARY_REPMGR_PWD: -4}"
log_hl "OUR_NODE_ID                 = $OUR_NODE_ID"
log_hl "RAILWAY_RUNTIME_DIR         = $RAILWAY_RUNTIME_DIR"
log_hl "SSL_CERTS_DIR               = $SSL_CERTS_DIR"
log_hl "PG_DATA_DIR                 = $PG_DATA_DIR"
log_hl "PG_CONF_FILE                = $PG_CONF_FILE"
log_hl "REPMGR_DIR                  = $REPMGR_DIR"
log_hl "REPMGR_CONF_FILE            = $REPMGR_CONF_FILE"

if [ ! -z "$DEBUG_MODE" ]; then
  log "Starting in debug mode! Postgres will not run."
  log "The container will stay alive and be shell-accessible."
  trap "echo Shutting down; exit 0" SIGTERM SIGINT SIGKILL
  sleep infinity & wait
fi

if [ ! -f "$MUTEX" ]; then
  source configure-replica.sh
fi

unset PGHOST
unset PGPORT

log_ok "Replication setup already completed. Starting Postgres."
source ssl.sh
/usr/local/bin/docker-entrypoint.sh "$@"
