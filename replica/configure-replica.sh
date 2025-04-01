#!/bin/bash
# ########################################################################### #
# https://railway.com
# ########################################################################### #
set -e
source _common.sh

if [ -f "$MUTEX" ]; then
    log_ok "Replication setup already completed"
    exit 0
fi

log "🚀 Starting replication setup..."

cat > "$REPMGR_CONF_FILE" << EOF
node_id=${OUR_NODE_ID}
node_name='node${OUR_NODE_ID}'
conninfo='host=${PGHOST} port=${PGPORT} user=repmgr dbname=repmgr connect_timeout=10 sslmode=disable'
data_directory='${PG_DATA_DIR}'
EOF
log "Created repmgr configuration at '$REPMGR_CONF_FILE'"

sudo chown -R postgres:postgres "$PG_DATA_DIR"
sudo chown -R postgres:postgres "$REPMGR_DIR"
sudo chmod 700 "$PG_DATA_DIR"
sudo chmod 700 "$REPMGR_DIR"

export PGPASSWORD="$PRIMARY_REPMGR_PWD"
su -m postgres -c \
   "repmgr -h $PRIMARY_PGHOST -p $PRIMARY_PGPORT \
   -d repmgr -U repmgr -f $REPMGR_CONF_FILE \
   standby clone --force 2>&1" &
repmgr_pid=$!

log "Performing clone of primary node. This may take awhile! ⏳"
while kill -0 $repmgr_pid 2>/dev/null; do
    echo -n "."
    sleep 5
done

wait $repmgr_pid
repmgr_status=$?

if [ $repmgr_status -eq 0 ]; then
  log_ok "Successfully cloned primary node"

  log "Performing post-replication setup ⏳"
  source ssl.sh
  su -m postgres -c "pg_ctl -D ${PG_DATA_DIR} start"
  if su -m postgres -c \
      "repmgr standby register --force -f $REPMGR_CONF_FILE 2>&1"
  then
      log_ok "Successfully registered replica node."
      su -m postgres -c "pg_ctl -D ${PG_DATA_DIR} stop"
      touch "$MUTEX"
  else
      log_err "Failed to register replica node."
      su -m postgres -c "pg_ctl -D ${PG_DATA_DIR} stop"
      exit 1
  fi
else
  log_err "Failed to clone primary node"
  exit 1
fi
