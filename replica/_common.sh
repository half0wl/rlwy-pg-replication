#!/bin/bash
# ########################################################################### #
# https://railway.com
# ########################################################################### #
set -e
source _include.sh

RAILWAY_VOLUME_NAME=${RAILWAY_VOLUME_NAME}
if [ -z "$RAILWAY_VOLUME_NAME" ]; then
    log_err "RAILWAY_VOLUME_NAME is unset"
    exit 1
fi

RAILWAY_VOLUME_MOUNT_PATH=${RAILWAY_VOLUME_MOUNT_PATH}
if [ -z "$RAILWAY_VOLUME_MOUNT_PATH" ]; then
    log_err "RAILWAY_VOLUME_MOUNT_PATH is unset"
    exit 1
fi

PRIMARY_PGHOST=${PRIMARY_PGHOST}
if [ -z "$PRIMARY_PGHOST" ]; then
    log_err "PRIMARY_PGHOST is unset"
    exit 1
fi

PRIMARY_PGPORT=${PRIMARY_PGPORT}
if [ -z "$PRIMARY_PGPORT" ]; then
    log_err "PRIMARY_PGPORT is unset"
    exit 1
fi

PRIMARY_REPMGR_PWD=${PRIMARY_REPMGR_PWD}
if [ -z "$PRIMARY_REPMGR_PWD" ]; then
    log_err "PRIMARY_REPMGR_PWD is unset"
    exit 1
fi

OUR_NODE_ID=${OUR_NODE_ID}
if [ -z "$OUR_NODE_ID" ]; then
    log_err "OUR_NODE_ID is unset"
    exit 1
fi


PG_DATA_DIR="${RAILWAY_VOLUME_MOUNT_PATH}/pgdata"
PG_CONF_FILE="${PG_DATA_DIR}/postgresql.conf"
mkdir -p "$PG_DATA_DIR"

SSL_CERTS_DIR="${RAILWAY_VOLUME_MOUNT_PATH}/certs"
mkdir -p "$SSL_CERTS_DIR"

REPMGR_DIR="${RAILWAY_VOLUME_MOUNT_PATH}/repmgr"
REPMGR_CONF_FILE="$REPMGR_DIR/repmgr.conf"
mkdir -p "$REPMGR_DIR"

MUTEX="${REPMGR_DIR}/mutex"
