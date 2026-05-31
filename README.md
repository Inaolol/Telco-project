# Telco Analytics — Oracle XE

A self-contained Oracle XE challenge for analysing telecom customers, tariff subscriptions, monthly usage, and payment status. The project turns three raw CSV files into a constrained relational model, loads them automatically in Docker, and answers eleven business questions in `SOLUTIONS.sql`.

The focus is reproducible data engineering: one command starts the database, creates the schema, imports the data, and leaves a reviewer ready to inspect the analytics queries. Domain context lives in [`CONTEXT.md`](./CONTEXT.md);

---

## What's in here

| File / dir | Purpose |
| --- | --- |
| `docker-compose.yml` | Oracle XE 21c service, port 1521, auto-seeded |
| `TABLE_CREATION_SCRIPTS.sql` | Canonical schema (TARIFFS, CUSTOMERS, MONTHLY_STATS) with FK / CHECK / indexes |
| `SOLUTIONS.sql` | Eleven analytics queries with explanatory comments |
| `RESULTS.md` | Verified result counts and representative query outputs |
| `CUSTOMERS.csv`, `TARIFFS.csv`, `MONTHLY_STATS.csv` | Source data — 10 000 customers, 4 plans, 9 950 monthly rows |
| `db/init/02_seed.sh` | Runs on first container boot: schema → SQL*Loader → tariff-snapshot |
| `db/ctl/*.ctl` | SQL*Loader control files (handle DD/MM/YYYY dates, UTF-8, and CRLF status values) |
| `db/post_load.sql` | Snapshots tariff limits/fee onto `MONTHLY_STATS` per ADR-0001 |
| `CONTEXT.md` | Domain vocabulary, schema rationale, business rules |

---

## Prerequisites

You only need two things on your machine:

| Tool | Why | Install |
| --- | --- | --- |
| **Docker** (≥ 24) with Compose v2 | Runs Oracle XE in a container so you don't install Oracle locally | <https://docs.docker.com/get-docker/> |
| **A SQL client** | To run the queries | **DBeaver Community** (recommended, free, GUI): <https://dbeaver.io/download/> — or anything that speaks Oracle (SQL Developer, DataGrip, `sqlplus` inside the container) |

Tested on Linux with Docker 29.x. Works on macOS and Windows (use WSL2 for best Docker performance on Windows). The image (`gvenzl/oracle-xe:21-slim-faststart`) is ~1.6 GB; allow a few minutes for the first pull. Oracle XE needs about 2 GB of RAM available to Docker.

---

## Quickstart

```bash
git clone <this-repo-url> telco-project
cd telco-project

# 1. Create your local env file and pick a strong DB password
cp .env.example .env
$EDITOR .env          # change ORACLE_PASSWORD

# 2. Bring up Oracle XE (first run pulls the image, then initialises the DB)
docker compose up -d

# 3. Wait until the container reports healthy (1–3 minutes on first boot)
docker inspect -f '{{.State.Health.Status}}' telco-oracle
# repeat until it prints: healthy
```

On the very first `docker compose up`, the container:

1. Initialises an Oracle XE instance with two databases — the CDB root `XE` and the pluggable `XEPDB1`.
2. Runs `db/init/02_seed.sh`, which connects to `XEPDB1` as the `system` user and:
   - applies `TABLE_CREATION_SCRIPTS.sql`,
   - SQL*Loader's the three CSVs into the new tables,
   - runs `db/post_load.sql` to snapshot each customer's tariff limits and monthly fee onto their `MONTHLY_STATS` row.

Subsequent `docker compose up` calls reuse the seeded volume and skip the init step.

### Verify the seed

```bash
docker exec -e P="$(grep ORACLE_PASSWORD .env | cut -d= -f2)" telco-oracle \
  bash -lc 'echo "SELECT
              (SELECT COUNT(*) FROM CUSTOMERS)     AS customers,
              (SELECT COUNT(*) FROM TARIFFS)       AS tariffs,
              (SELECT COUNT(*) FROM MONTHLY_STATS) AS monthly_stats
            FROM dual;" | sqlplus -S system/$P@//localhost:1521/XEPDB1'
```

Expected: `10000 / 4 / 9950`. The 50-row gap in `MONTHLY_STATS` is intentional (the "missing monthly record" insertion-error scenario — see `CONTEXT.md`).

---

## Connect with DBeaver

1. **Database → New Database Connection → Oracle**.
2. Connection settings:
   - **Host:** `localhost`
   - **Port:** `1521`
   - **Database:** `XEPDB1`  (this is the *Service name*, not the SID)
   - **Username:** `system`
   - **Password:** the `ORACLE_PASSWORD` you put in `.env`
3. **Test Connection** → DBeaver will offer to download the Oracle JDBC driver, accept.
4. Open `SOLUTIONS.sql` in DBeaver and run any query (Ctrl+Enter).

If you don't want a GUI, you can run any query directly in the container:

```bash
docker exec -i telco-oracle bash -lc \
  "sqlplus -S system/\$ORACLE_PASSWORD@//localhost:1521/XEPDB1" < SOLUTIONS.sql
```

---

## Common operations

| You want to… | Command |
| --- | --- |
| Stop the DB (keep data) | `docker compose stop` |
| Start the DB again | `docker compose start` |
| View Oracle logs | `docker logs -f telco-oracle` |
| Open a `sqlplus` session inside the container | `docker exec -it telco-oracle sqlplus system/$ORACLE_PASSWORD@//localhost:1521/XEPDB1` |
| **Wipe everything and re-seed from scratch** | `docker compose down -v && docker compose up -d` |
| Tear down completely | `docker compose down -v` |

The `-v` flag deletes the `oracle-data` volume — without it, your seeded data persists and the seed script will *not* re-run.

---

## Troubleshooting

**Container exits right after start, logs say `ORA-04043: object TARIFFS does not exist`.**
You're on an old version of this repo where the schema was auto-run as `SYS` against the CDB root instead of in `XEPDB1`. Pull the latest commit (the schema is now applied inside the seed script). Then `docker compose down -v && docker compose up -d`.

**`docker compose up` fails with "port 1521 already in use".**
Another Oracle (or another `telco-oracle`) is bound to the host port. Either stop it, or change the host port in `docker-compose.yml` (`"1521:1521"` → e.g. `"1522:1521"`).

**Health stays `starting` forever.**
Oracle XE needs ~2 GB of RAM. On Docker Desktop, raise the memory limit (Settings → Resources). Logs (`docker logs telco-oracle`) usually show the actual problem.

**Turkish characters render as `?` in DBeaver.**
The schema and JDBC driver speak UTF-8, so this is almost always a font/console issue in your client, not a data problem. The container itself runs with `NLS_LANG=AMERICAN_AMERICA.AL32UTF8`.

---

## The eleven analytics queries

Each is in `SOLUTIONS.sql`, prefixed with a comment block explaining the approach. Verified counts and representative outputs are captured in [`RESULTS.md`](./RESULTS.md).

| # | Question |
| --- | --- |
| 1.1 | Customers subscribed to the `Kobiye Destek` tariff |
| 1.2 | Newest customer on `Kobiye Destek` |
| 2.1 | Distribution of tariffs among customers |
| 3.1 | Earliest signup customers (by `SIGNUP_DATE`, not by ID) |
| 3.2 | City distribution of the earliest signup cohort |
| 4.1 | Customers with a missing `MONTHLY_STATS` row |
| 4.2 | City distribution of missing-record customers |
| 5.1 | Customers who used ≥ 75 % of their data limit |
| 5.2 | Customers who exhausted all positive package limits (data + minutes + SMS) |
| 6.1 | Customers with unpaid fees (`UNPAID` or `LATE`) |
| 6.2 | Payment-status distribution per tariff |

---

## Original assignment brief

This repo started as a take-home for i2i Systems. The original brief is preserved below for context — it's what the queries above are answering.

### Operational requirements

1. **Oracle XE setup** — Run Oracle XE in Docker, accessible locally. ✓ (see `docker-compose.yml`)
2. **DBeaver** — Connect to the local instance. ✓ (instructions above)
3. **Data import** — Design tables and import the three CSVs. ✓ (`TABLE_CREATION_SCRIPTS.sql`, `db/init/02_seed.sh`)
4. **Bonus — Compose & auto-seed** — Provide `docker-compose.yml` and run the schema automatically on first boot. ✓

### Functional requirements

Each of the eleven questions in the table above carries a >=3-sentence explanation in `SOLUTIONS.sql`, per the original brief. Verified outputs are documented in `RESULTS.md`.


