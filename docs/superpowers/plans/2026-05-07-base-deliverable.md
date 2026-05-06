# Telco Base Deliverable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up Oracle XE in Docker Compose with auto-seeded schema and CSV data, then deliver `TABLE_CREATION_SCRIPTS.sql` and `SOLUTIONS.sql` (11 analytics queries) at the repo root.

**Architecture:** Use the `gvenzl/oracle-xe:21-slim-faststart` image because it supports auto-init via files dropped into `/container-entrypoint-initdb.d/`. The schema mirrors `CONTEXT.md` (three tables, `MONTHLY_STATS` denormalises limits/fee from `TARIFFS` at ingest). CSVs are loaded with SQL*Loader (`sqlldr`, bundled in the image) driven by a single seed shell script. Solution queries live in `SOLUTIONS.sql` and are runnable against the seeded DB.

**Tech Stack:** Oracle Database XE 21c, Docker Compose v2, SQL*Loader, SQL*Plus, bash.

---

## File Structure

```
/
├── docker-compose.yml                     ← Oracle XE service (NEW)
├── .env.example                           ← ORACLE_PASSWORD template (NEW)
├── .gitignore                             ← ignore .env, oracle-data/ (NEW)
├── TABLE_CREATION_SCRIPTS.sql             ← canonical schema (NEW, repo root, README requirement)
├── SOLUTIONS.sql                          ← 11 analytics queries (NEW, repo root, README requirement)
├── db/
│   ├── init/                              ← mounted to /container-entrypoint-initdb.d/
│   │   ├── 01_schema.sql                  ← copy of TABLE_CREATION_SCRIPTS.sql (NEW)
│   │   └── 02_seed.sh                     ← runs sqlldr for all three CSVs + post-load join (NEW)
│   ├── ctl/
│   │   ├── tariffs.ctl                    ← SQL*Loader control file (NEW)
│   │   ├── customers.ctl                  ← (NEW)
│   │   └── monthly_stats.ctl              ← (NEW)
│   └── post_load.sql                      ← snapshot TARIFFS → MONTHLY_STATS (NEW)
├── docs/
│   └── adr/
│       └── 0001-monthly-stats-denormalises-tariff-fields.md  (NEW)
└── (existing) CONTEXT.md, README.md, CUSTOMERS.csv, TARIFFS.csv, MONTHLY_STATS.csv
```

Each file has one responsibility: compose orchestrates the container, schema scripts define DDL only, control files describe parsing only, the seed shell script is the single ingest entrypoint, and the post-load SQL handles denormalisation. `TABLE_CREATION_SCRIPTS.sql` and `SOLUTIONS.sql` at the repo root are the deliverables called out in `README.md`; `db/init/01_schema.sql` is a copy used by the container's auto-init.

---

## Task 1: Bootstrap repo skeleton

**Files:**
- Create: `.gitignore`
- Create: `.env.example`
- Create: `db/init/.gitkeep`
- Create: `db/ctl/.gitkeep`

- [ ] **Step 1: Create `.gitignore`**

```
.env
oracle-data/
*.log
```

- [ ] **Step 2: Create `.env.example`**

```
ORACLE_PASSWORD=ChangeMe_StrongPass1
APP_USER=telco
APP_USER_PASSWORD=telco
```

- [ ] **Step 3: Create empty placeholder dirs**

```bash
mkdir -p db/init db/ctl docs/adr
touch db/init/.gitkeep db/ctl/.gitkeep
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore .env.example db/init/.gitkeep db/ctl/.gitkeep
git commit -m "chore: scaffold docker + db directory layout"
```

---

## Task 2: ADR for MONTHLY_STATS denormalisation

**Files:**
- Create: `docs/adr/0001-monthly-stats-denormalises-tariff-fields.md`

- [ ] **Step 1: Write the ADR**

```markdown
# ADR-0001: MONTHLY_STATS denormalises limit/fee fields from TARIFFS

## Status
Accepted — 2026-05-07

## Context
`CONTEXT.md` describes `MONTHLY_STATS` as carrying `DATA_LIMIT`, `MINUTES_LIMIT`,
`SMS_LIMIT`, and `MONTHLY_FEE`. The source `MONTHLY_STATS.csv` does not contain
these columns — only `*_USAGE` and `PAYMENT_STATUS`. Limits and fees live in
`TARIFFS.csv`.

## Decision
Keep the schema as `CONTEXT.md` defines it: `MONTHLY_STATS` carries snapshotted
limit and fee columns. At ingest time, populate them by joining each customer's
row to `TARIFFS` via `CUSTOMERS.TARIFF_ID`. The snapshot models the customer's
plan terms for that month, which would diverge from `TARIFFS` if a tariff is
later edited.

## Consequences
- Ingest is a two-step process: SQL*Loader → post-load `UPDATE` join.
- Queries that need limits read from `MONTHLY_STATS` directly, no join required.
- A tariff change after the month closes does not retroactively affect history.
```

- [ ] **Step 2: Commit**

```bash
git add docs/adr/0001-monthly-stats-denormalises-tariff-fields.md
git commit -m "docs(adr): record monthly_stats denormalisation decision"
```

---

## Task 3: Docker Compose for Oracle XE

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write `docker-compose.yml`**

```yaml
services:
  oracle:
    image: gvenzl/oracle-xe:21-slim-faststart
    container_name: telco-oracle
    environment:
      ORACLE_PASSWORD: ${ORACLE_PASSWORD}
      APP_USER: ${APP_USER}
      APP_USER_PASSWORD: ${APP_USER_PASSWORD}
      NLS_LANG: AMERICAN_AMERICA.AL32UTF8
    ports:
      - "1521:1521"
    volumes:
      - oracle-data:/opt/oracle/oradata
      - ./db/init:/container-entrypoint-initdb.d:ro
      - ./db/ctl:/db/ctl:ro
      - ./CUSTOMERS.csv:/db/csv/CUSTOMERS.csv:ro
      - ./TARIFFS.csv:/db/csv/TARIFFS.csv:ro
      - ./MONTHLY_STATS.csv:/db/csv/MONTHLY_STATS.csv:ro
      - ./db/post_load.sql:/db/post_load.sql:ro
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 30

volumes:
  oracle-data:
```

- [ ] **Step 2: Verify compose file parses**

Run: `docker compose -f docker-compose.yml config --quiet`
Expected: exit 0, no output.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(docker): add oracle xe service with auto-init mount points"
```

---

## Task 4: TARIFFS DDL

**Files:**
- Create: `TABLE_CREATION_SCRIPTS.sql`

- [ ] **Step 1: Write `TARIFFS` table + comments**

Append to `TABLE_CREATION_SCRIPTS.sql`:

```sql
-- Tariff/plan definitions. Master data for what each plan offers.
CREATE TABLE TARIFFS (
  TARIFF_ID      NUMBER(4)        PRIMARY KEY,
  NAME           VARCHAR2(100)    NOT NULL,
  MONTHLY_FEE    NUMBER(10,2)     NOT NULL CHECK (MONTHLY_FEE >= 0),
  DATA_LIMIT     NUMBER(10)       NOT NULL CHECK (DATA_LIMIT >= 0),
  MINUTE_LIMIT   NUMBER(10)       NOT NULL CHECK (MINUTE_LIMIT >= 0),
  SMS_LIMIT      NUMBER(10)       NOT NULL CHECK (SMS_LIMIT >= 0)
);
```

- [ ] **Step 2: Commit**

```bash
git add TABLE_CREATION_SCRIPTS.sql
git commit -m "feat(schema): add TARIFFS table"
```

---

## Task 5: CUSTOMERS DDL with FK + indexes

**Files:**
- Modify: `TABLE_CREATION_SCRIPTS.sql`

- [ ] **Step 1: Append `CUSTOMERS` + indexes**

```sql
-- Customer master. TARIFF_ID FK enforces referential integrity to TARIFFS.
CREATE TABLE CUSTOMERS (
  CUSTOMER_ID    NUMBER(8)        PRIMARY KEY,
  NAME           NVARCHAR2(100)   NOT NULL,
  CITY           NVARCHAR2(100)   NOT NULL,
  SIGNUP_DATE    DATE             NOT NULL,
  TARIFF_ID      NUMBER(4)        NOT NULL,
  CONSTRAINT FK_CUSTOMERS_TARIFF
    FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID)
);

CREATE INDEX IX_CUSTOMERS_TARIFF_ID  ON CUSTOMERS (TARIFF_ID);
CREATE INDEX IX_CUSTOMERS_SIGNUP     ON CUSTOMERS (SIGNUP_DATE);
CREATE INDEX IX_CUSTOMERS_CITY       ON CUSTOMERS (CITY);
```

- [ ] **Step 2: Commit**

```bash
git add TABLE_CREATION_SCRIPTS.sql
git commit -m "feat(schema): add CUSTOMERS table with FK and supporting indexes"
```

---

## Task 6: MONTHLY_STATS DDL with constraints + index

**Files:**
- Modify: `TABLE_CREATION_SCRIPTS.sql`

- [ ] **Step 1: Append `MONTHLY_STATS` + index**

```sql
-- Current-month usage and payment per customer. Limits/fee are snapshotted
-- from TARIFFS at ingest (see ADR-0001). UNIQUE on CUSTOMER_ID enforces the
-- "one row per customer per month" rule.
CREATE TABLE MONTHLY_STATS (
  ID              NUMBER(10)      PRIMARY KEY,
  CUSTOMER_ID     NUMBER(8)       NOT NULL UNIQUE,
  DATA_LIMIT      NUMBER(10)      NOT NULL CHECK (DATA_LIMIT     >= 0),
  DATA_USAGE      NUMBER(12,2)    NOT NULL CHECK (DATA_USAGE     >= 0),
  MINUTES_LIMIT   NUMBER(10)      NOT NULL CHECK (MINUTES_LIMIT  >= 0),
  MINUTES_USAGE   NUMBER(10)      NOT NULL CHECK (MINUTES_USAGE  >= 0),
  SMS_LIMIT       NUMBER(10)      NOT NULL CHECK (SMS_LIMIT      >= 0),
  SMS_USAGE       NUMBER(10)      NOT NULL CHECK (SMS_USAGE      >= 0),
  MONTHLY_FEE     NUMBER(10,2)    NOT NULL CHECK (MONTHLY_FEE    >= 0),
  PAYMENT_STATUS  VARCHAR2(10)    NOT NULL
    CHECK (PAYMENT_STATUS IN ('PAID', 'UNPAID', 'LATE')),
  CONSTRAINT FK_MS_CUSTOMER
    FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID)
);

CREATE INDEX IX_MS_PAYMENT_STATUS ON MONTHLY_STATS (PAYMENT_STATUS);
```

- [ ] **Step 2: Commit**

```bash
git add TABLE_CREATION_SCRIPTS.sql
git commit -m "feat(schema): add MONTHLY_STATS table with check constraints"
```

---

## Task 7: Mirror schema into init dir

**Files:**
- Create: `db/init/01_schema.sql`

- [ ] **Step 1: Copy schema into init location**

```bash
cp TABLE_CREATION_SCRIPTS.sql db/init/01_schema.sql
```

- [ ] **Step 2: Append a final exit so SQL*Plus terminates cleanly**

Append to `db/init/01_schema.sql`:

```sql
EXIT;
```

- [ ] **Step 3: Commit**

```bash
git add db/init/01_schema.sql
git commit -m "feat(db): mirror schema into container init dir"
```

---

## Task 8: SQL*Loader control file for TARIFFS

**Files:**
- Create: `db/ctl/tariffs.ctl`

- [ ] **Step 1: Write control file**

```
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/db/csv/TARIFFS.csv'
INTO TABLE TARIFFS
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  TARIFF_ID    INTEGER EXTERNAL,
  NAME         CHAR(100),
  MONTHLY_FEE  DECIMAL EXTERNAL,
  DATA_LIMIT   INTEGER EXTERNAL,
  MINUTE_LIMIT INTEGER EXTERNAL,
  SMS_LIMIT    INTEGER EXTERNAL
)
```

- [ ] **Step 2: Commit**

```bash
git add db/ctl/tariffs.ctl
git commit -m "feat(ingest): add tariffs sqlldr control file"
```

---

## Task 9: Control file for CUSTOMERS (DD/MM/YYYY)

**Files:**
- Create: `db/ctl/customers.ctl`

- [ ] **Step 1: Write control file**

```
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/db/csv/CUSTOMERS.csv'
INTO TABLE CUSTOMERS
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  CUSTOMER_ID  INTEGER EXTERNAL,
  NAME         CHAR(100),
  CITY         CHAR(100),
  SIGNUP_DATE  DATE "DD/MM/YYYY",
  TARIFF_ID    INTEGER EXTERNAL
)
```

- [ ] **Step 2: Commit**

```bash
git add db/ctl/customers.ctl
git commit -m "feat(ingest): add customers sqlldr control file with DD/MM/YYYY date"
```

---

## Task 10: Control file for MONTHLY_STATS (handle UTF-8 BOM)

**Files:**
- Create: `db/ctl/monthly_stats.ctl`

- [ ] **Step 1: Write control file**

`SKIP=1` skips the BOM-bearing header row. Both `OPTIONS` and `LOAD DATA` blocks below.

```
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/db/csv/MONTHLY_STATS.csv'
INTO TABLE MONTHLY_STATS
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  ID              INTEGER EXTERNAL,
  CUSTOMER_ID     INTEGER EXTERNAL,
  DATA_USAGE      DECIMAL EXTERNAL,
  MINUTES_USAGE   INTEGER EXTERNAL,
  SMS_USAGE       INTEGER EXTERNAL,
  PAYMENT_STATUS  CHAR(10),
  DATA_LIMIT      CONSTANT 0,
  MINUTES_LIMIT   CONSTANT 0,
  SMS_LIMIT       CONSTANT 0,
  MONTHLY_FEE     CONSTANT 0
)
```

> Limits/fee are written as 0 here and overwritten in Task 12's post-load join. Loader expects every NOT NULL column to be supplied; constants satisfy that without extra DDL.

- [ ] **Step 2: Commit**

```bash
git add db/ctl/monthly_stats.ctl
git commit -m "feat(ingest): add monthly_stats sqlldr control file with BOM-skip"
```

---

## Task 11: Post-load denormalisation SQL

**Files:**
- Create: `db/post_load.sql`

- [ ] **Step 1: Write the update**

```sql
-- Snapshot tariff limits/fee onto each MONTHLY_STATS row (see ADR-0001).
MERGE INTO MONTHLY_STATS m
USING (
  SELECT c.CUSTOMER_ID,
         t.DATA_LIMIT,
         t.MINUTE_LIMIT  AS MINUTES_LIMIT,
         t.SMS_LIMIT,
         t.MONTHLY_FEE
    FROM CUSTOMERS c
    JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
) src
ON (m.CUSTOMER_ID = src.CUSTOMER_ID)
WHEN MATCHED THEN UPDATE SET
  m.DATA_LIMIT     = src.DATA_LIMIT,
  m.MINUTES_LIMIT  = src.MINUTES_LIMIT,
  m.SMS_LIMIT      = src.SMS_LIMIT,
  m.MONTHLY_FEE    = src.MONTHLY_FEE;

COMMIT;
EXIT;
```

- [ ] **Step 2: Commit**

```bash
git add db/post_load.sql
git commit -m "feat(ingest): add post-load tariff snapshot into monthly_stats"
```

---

## Task 12: Seed entrypoint shell script

**Files:**
- Create: `db/init/02_seed.sh`

- [ ] **Step 1: Write `db/init/02_seed.sh`**

The gvenzl image runs files in `/container-entrypoint-initdb.d/` after the DB is up. `01_schema.sql` runs first (alphabetic), then this script. The image exposes `$ORACLE_PASSWORD` and a `system` user; we load as `system` to keep things simple for a portfolio project.

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x db/init/02_seed.sh
```

- [ ] **Step 3: Commit**

```bash
git add db/init/02_seed.sh
git commit -m "feat(ingest): add seed script orchestrating sqlldr + post-load"
```

---

## Task 13: First-boot end-to-end verification

**Files:** none (operational task)

- [ ] **Step 1: Copy `.env.example` to `.env`**

```bash
cp .env.example .env
```

- [ ] **Step 2: Bring container up fresh**

```bash
docker compose down -v
docker compose up -d
```

- [ ] **Step 3: Wait for healthy**

Run: `until [ "$(docker inspect -f '{{.State.Health.Status}}' telco-oracle)" = "healthy" ]; do sleep 5; done`
Expected: returns within ~3 minutes.

- [ ] **Step 4: Verify row counts**

```bash
docker exec telco-oracle bash -lc \
  "echo 'SELECT (SELECT COUNT(*) FROM CUSTOMERS) cust, (SELECT COUNT(*) FROM TARIFFS) tar, (SELECT COUNT(*) FROM MONTHLY_STATS) ms FROM dual;' \
   | sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1"
```

Expected output (whitespace approx):
```
      CUST        TAR         MS
---------- ---------- ----------
     10000          4       9950
```

- [ ] **Step 5: Verify denormalisation populated**

```bash
docker exec telco-oracle bash -lc \
  "echo 'SELECT COUNT(*) FROM MONTHLY_STATS WHERE MONTHLY_FEE = 0 AND DATA_LIMIT = 0 AND MINUTES_LIMIT = 0 AND SMS_LIMIT = 0;' \
   | sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1"
```

Expected: `0` (or only rows whose tariff is genuinely free across the board, e.g. `Kurumsal SMS` has `DATA_LIMIT=0` and `MINUTES_LIMIT=0` but `MONTHLY_FEE>0`, so the four-zero count should still be 0).

- [ ] **Step 6: Commit nothing — this task verifies prior work.**

If counts are wrong, stop and fix the failing loader/control file before proceeding.

---

## Task 14: SOLUTIONS.sql — Q1.1 Kobiye Destek subscribers

**Files:**
- Create: `SOLUTIONS.sql`

- [ ] **Step 1: Add Q1.1 with ≥3 sentence comment**

```sql
-- =============================================================================
-- 1.1  Customers subscribed to the 'Kobiye Destek' tariff.
-- We join CUSTOMERS to TARIFFS on TARIFF_ID and filter by the tariff name
-- rather than hard-coding the ID, so the query stays correct if seed order
-- changes. We project the customer-facing fields a service rep would need
-- (id, name, city, signup date) and order by CUSTOMER_ID for stable output.
-- =============================================================================
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 WHERE t.NAME = 'Kobiye Destek'
 ORDER BY c.CUSTOMER_ID;
```

- [ ] **Step 2: Run query inside container**

```bash
docker exec telco-oracle bash -lc \
  "sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1 <<<\
   'SELECT COUNT(*) FROM CUSTOMERS c JOIN TARIFFS t ON t.TARIFF_ID=c.TARIFF_ID WHERE t.NAME=''Kobiye Destek'';'"
```

Expected: a non-zero count (Kobiye Destek is one of the four tariffs).

- [ ] **Step 3: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q1.1 customers on Kobiye Destek"
```

---

## Task 15: Q1.2 Newest Kobiye Destek subscriber

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q1.2**

```sql
-- =============================================================================
-- 1.2  Newest customer on the 'Kobiye Destek' tariff.
-- We sort by SIGNUP_DATE descending and keep only the top row using
-- FETCH FIRST 1 ROWS ONLY, which is clearer than ROWNUM tricks. Ties on
-- SIGNUP_DATE are broken by CUSTOMER_ID descending, giving a deterministic
-- "most recently inserted" winner per the README hint.
-- =============================================================================
SELECT c.CUSTOMER_ID, c.NAME, c.CITY, c.SIGNUP_DATE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 WHERE t.NAME = 'Kobiye Destek'
 ORDER BY c.SIGNUP_DATE DESC, c.CUSTOMER_ID DESC
 FETCH FIRST 1 ROWS ONLY;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q1.2 newest Kobiye Destek subscriber"
```

---

## Task 16: Q2.1 Tariff distribution

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q2.1**

```sql
-- =============================================================================
-- 2.1  Distribution of tariffs among customers.
-- We GROUP BY tariff name and count subscribers, joining via TARIFF_ID so
-- the friendly name is returned. Including the percentage share alongside
-- raw counts makes the distribution easier to read at a glance and is a
-- common ask from product. Ordering by count descending puts the biggest
-- plans on top.
-- =============================================================================
SELECT t.NAME AS TARIFF_NAME,
       COUNT(*) AS CUSTOMER_COUNT,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS PERCENT_SHARE
  FROM CUSTOMERS c
  JOIN TARIFFS   t ON t.TARIFF_ID = c.TARIFF_ID
 GROUP BY t.NAME
 ORDER BY CUSTOMER_COUNT DESC;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q2.1 tariff distribution"
```

---

## Task 17: Q3.1 Earliest signup customers

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q3.1**

```sql
-- =============================================================================
-- 3.1  Earliest customers to sign up.
-- Per the README hint, "earliest" is by SIGNUP_DATE, not by CUSTOMER_ID.
-- We use RANK over SIGNUP_DATE so ties (multiple customers signing up on
-- the very first day) are all returned, not just one of them. Filtering
-- on rank = 1 in the outer query gives the full earliest cohort.
-- =============================================================================
SELECT CUSTOMER_ID, NAME, CITY, SIGNUP_DATE
  FROM (
    SELECT c.CUSTOMER_ID,
           c.NAME,
           c.CITY,
           c.SIGNUP_DATE,
           RANK() OVER (ORDER BY c.SIGNUP_DATE ASC) AS R
      FROM CUSTOMERS c
  )
 WHERE R = 1
 ORDER BY CUSTOMER_ID;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q3.1 earliest signup customers"
```

---

## Task 18: Q3.2 City distribution of earliest signups

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q3.2**

```sql
-- =============================================================================
-- 3.2  City distribution of the earliest signup cohort.
-- We reuse the rank-based earliest-cohort definition from 3.1 inside a
-- subquery, then GROUP BY city. This guarantees we count exactly the
-- customers from 3.1 — no risk of drift between the two answers. Ordering
-- by count descending then city alphabetically gives stable, readable output.
-- =============================================================================
SELECT CITY, COUNT(*) AS CUSTOMER_COUNT
  FROM (
    SELECT c.CUSTOMER_ID, c.CITY,
           RANK() OVER (ORDER BY c.SIGNUP_DATE ASC) AS R
      FROM CUSTOMERS c
  )
 WHERE R = 1
 GROUP BY CITY
 ORDER BY CUSTOMER_COUNT DESC, CITY ASC;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q3.2 city distribution of earliest signups"
```

---

## Task 19: Q4.1 Customers with missing monthly record

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q4.1**

```sql
-- =============================================================================
-- 4.1  Customers with a missing MONTHLY_STATS row.
-- A missing row is meaningful (the insertion-error scenario from CONTEXT.md);
-- it must NOT be treated as zero usage. We use a LEFT JOIN to MONTHLY_STATS
-- and keep only the rows where the joined CUSTOMER_ID is NULL — this is
-- the canonical anti-join in Oracle and makes the absence explicit.
-- =============================================================================
SELECT c.CUSTOMER_ID, c.NAME, c.CITY
  FROM CUSTOMERS c
  LEFT JOIN MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
 WHERE m.CUSTOMER_ID IS NULL
 ORDER BY c.CUSTOMER_ID;
```

- [ ] **Step 2: Verify count is 50 (per CONTEXT.md)**

```bash
docker exec telco-oracle bash -lc \
  "sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1 <<<\
   'SELECT COUNT(*) FROM CUSTOMERS c LEFT JOIN MONTHLY_STATS m ON m.CUSTOMER_ID=c.CUSTOMER_ID WHERE m.CUSTOMER_ID IS NULL;'"
```

Expected: `50`.

- [ ] **Step 3: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q4.1 customers with missing monthly record"
```

---

## Task 20: Q4.2 City distribution of missing-record customers

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q4.2**

```sql
-- =============================================================================
-- 4.2  City distribution of customers whose MONTHLY_STATS row is missing.
-- Same anti-join shape as 4.1, then GROUP BY city. Keeping the anti-join
-- inline (rather than referencing 4.1) means each query in this file is
-- runnable on its own. The total of these counts must equal 50.
-- =============================================================================
SELECT c.CITY, COUNT(*) AS MISSING_COUNT
  FROM CUSTOMERS c
  LEFT JOIN MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
 WHERE m.CUSTOMER_ID IS NULL
 GROUP BY c.CITY
 ORDER BY MISSING_COUNT DESC, c.CITY ASC;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q4.2 city distribution of missing monthly records"
```

---

## Task 21: Q5.1 Customers with ≥75% data usage

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q5.1**

```sql
-- =============================================================================
-- 5.1  Customers who used at least 75% of their data limit.
-- Limits live on MONTHLY_STATS post-snapshot, so no TARIFFS join is needed.
-- We guard against DATA_LIMIT = 0 (e.g. Kurumsal SMS plan) — that plan
-- includes no data, so 75% of zero is undefined and these rows are excluded.
-- The percentage is shown so reviewers can sanity-check the threshold.
-- =============================================================================
SELECT m.CUSTOMER_ID,
       c.NAME,
       m.DATA_USAGE,
       m.DATA_LIMIT,
       ROUND(m.DATA_USAGE * 100 / m.DATA_LIMIT, 2) AS USAGE_PCT
  FROM MONTHLY_STATS m
  JOIN CUSTOMERS     c ON c.CUSTOMER_ID = m.CUSTOMER_ID
 WHERE m.DATA_LIMIT > 0
   AND m.DATA_USAGE >= 0.75 * m.DATA_LIMIT
 ORDER BY USAGE_PCT DESC, m.CUSTOMER_ID ASC;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q5.1 customers >=75% data usage"
```

---

## Task 22: Q5.2 Customers who exhausted all package limits

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q5.2**

```sql
-- =============================================================================
-- 5.2  Customers who exhausted all package limits (data, minutes, SMS).
-- Per CONTEXT.md, "exhausted" only applies to positive limits — a 0 limit
-- means the resource is not part of the plan and is excluded from the
-- exhaustion check. We require all three resources that ARE included in
-- the plan to be at >= 100% consumption.
-- =============================================================================
SELECT m.CUSTOMER_ID, c.NAME, c.CITY
  FROM MONTHLY_STATS m
  JOIN CUSTOMERS     c ON c.CUSTOMER_ID = m.CUSTOMER_ID
 WHERE (m.DATA_LIMIT     = 0 OR m.DATA_USAGE     >= m.DATA_LIMIT)
   AND (m.MINUTES_LIMIT  = 0 OR m.MINUTES_USAGE  >= m.MINUTES_LIMIT)
   AND (m.SMS_LIMIT      = 0 OR m.SMS_USAGE      >= m.SMS_LIMIT)
   AND (m.DATA_LIMIT + m.MINUTES_LIMIT + m.SMS_LIMIT) > 0
 ORDER BY m.CUSTOMER_ID;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q5.2 customers who exhausted package limits"
```

---

## Task 23: Q6.1 Customers with unpaid fees

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q6.1**

```sql
-- =============================================================================
-- 6.1  Customers with unpaid fees.
-- Per CONTEXT.md the only fully-paid status is 'PAID'; both 'UNPAID' and
-- 'LATE' represent outstanding balance. We use IN to make the rule explicit
-- rather than NOT = 'PAID', which would also accidentally include any
-- future status values introduced later (the CHECK constraint blocks that
-- today, but the IN form documents intent).
-- =============================================================================
SELECT m.CUSTOMER_ID, c.NAME, c.CITY, m.PAYMENT_STATUS, m.MONTHLY_FEE
  FROM MONTHLY_STATS m
  JOIN CUSTOMERS     c ON c.CUSTOMER_ID = m.CUSTOMER_ID
 WHERE m.PAYMENT_STATUS IN ('UNPAID', 'LATE')
 ORDER BY m.CUSTOMER_ID;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q6.1 customers with unpaid fees"
```

---

## Task 24: Q6.2 Payment status distribution per tariff

**Files:**
- Modify: `SOLUTIONS.sql`

- [ ] **Step 1: Append Q6.2**

```sql
-- =============================================================================
-- 6.2  Payment status distribution across tariffs.
-- We GROUP BY tariff name and payment status, joining CUSTOMERS to bridge
-- MONTHLY_STATS to TARIFFS. Customers with a missing monthly record are
-- intentionally excluded — they have no payment status to attribute. Output
-- is ordered by tariff then status for predictable side-by-side comparison.
-- =============================================================================
SELECT t.NAME AS TARIFF_NAME,
       m.PAYMENT_STATUS,
       COUNT(*) AS CUSTOMER_COUNT
  FROM MONTHLY_STATS m
  JOIN CUSTOMERS     c ON c.CUSTOMER_ID = m.CUSTOMER_ID
  JOIN TARIFFS       t ON t.TARIFF_ID   = c.TARIFF_ID
 GROUP BY t.NAME, m.PAYMENT_STATUS
 ORDER BY t.NAME, m.PAYMENT_STATUS;
```

- [ ] **Step 2: Commit**

```bash
git add SOLUTIONS.sql
git commit -m "feat(solutions): Q6.2 payment status distribution per tariff"
```

---

## Task 25: Smoke-run all solutions end-to-end

**Files:** none (verification)

- [ ] **Step 1: Execute SOLUTIONS.sql against the live container**

```bash
docker exec -i telco-oracle bash -lc \
  "sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1" < SOLUTIONS.sql > /tmp/solutions.out
echo "exit: $?"
grep -iE 'ORA-|SP2-' /tmp/solutions.out || echo "no errors"
```

Expected: `exit: 0` and `no errors`. If any `ORA-` or `SP2-` lines appear, fix the offending query and re-run.

- [ ] **Step 2: Spot-check Q4.1 returns 50 rows in the output**

```bash
grep -A2 "missing monthly record" /tmp/solutions.out || true
```

(Manual scan: confirm result rows are present and look correct.)

- [ ] **Step 3: No commit — verification only.**

---

## Task 26: README quickstart + reproducibility notes

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append a "Local setup" section**

Append at the end of `README.md`:

```markdown
---

## Local setup (Docker Compose)

1. `cp .env.example .env` and pick a strong `ORACLE_PASSWORD`.
2. `docker compose up -d`
3. Wait for the container to report healthy:
   `docker inspect -f '{{.State.Health.Status}}' telco-oracle`
4. Schema and data are loaded automatically on first boot via
   `db/init/01_schema.sql` and `db/init/02_seed.sh`.
5. Connect from DBeaver: host `localhost`, port `1521`, service `XEPDB1`,
   user `system`, password from your `.env`.
6. Run the analytics queries from `SOLUTIONS.sql`.

To rebuild from scratch: `docker compose down -v && docker compose up -d`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add local setup quickstart"
```

---

## Done criteria

- `docker compose down -v && docker compose up -d` produces a healthy container with `CUSTOMERS=10000`, `TARIFFS=4`, `MONTHLY_STATS=9950` without manual intervention.
- `TABLE_CREATION_SCRIPTS.sql` and `SOLUTIONS.sql` exist at the repo root.
- All 11 solution queries run cleanly against the seeded DB.
- ADR-0001 documents the `MONTHLY_STATS` denormalisation decision.
