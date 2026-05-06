#!/usr/bin/env bash
set -euo pipefail

CONN="system/${ORACLE_PASSWORD}@//localhost:1521/XEPDB1"

echo "[seed] loading TARIFFS"
sqlldr userid="${CONN}" \
       control=/db/ctl/tariffs.ctl \
       data=/db/csv/TARIFFS.csv \
       log=/tmp/tariffs.log bad=/tmp/tariffs.bad \
       skip=1 direct=true

echo "[seed] loading CUSTOMERS"
sqlldr userid="${CONN}" \
       control=/db/ctl/customers.ctl \
       data=/db/csv/CUSTOMERS.csv \
       log=/tmp/customers.log bad=/tmp/customers.bad \
       skip=1 direct=true

echo "[seed] loading MONTHLY_STATS"
sqlldr userid="${CONN}" \
       control=/db/ctl/monthly_stats.ctl \
       data=/db/csv/MONTHLY_STATS.csv \
       log=/tmp/monthly_stats.log bad=/tmp/monthly_stats.bad \
       direct=true

echo "[seed] applying post_load.sql"
sqlplus -S -L "${CONN}" @/db/post_load.sql

echo "[seed] done"
