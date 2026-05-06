# Telco Analytics — Domain Context

A personal portfolio project: a telecom customer analytics database built on Oracle XE, designed to demonstrate SQL schema design, data modelling, and business query skills. The dataset is realistic in shape and scale — 10 000 customers, four tariff plans, and a month of usage records with intentional gaps.

This is a living project. The SQL foundation is the starting point; the intent is to extend it with analytics layers, automation, and tooling over time.

---

## Dataset

Three source CSV files ship with the repo:

| File | Rows | What it contains |
| --- | ---: | --- |
| `CUSTOMERS.csv` | 10 000 | Customer identity, city, signup date, tariff subscription |
| `TARIFFS.csv` | 4 | Tariff/plan definitions and package limits |
| `MONTHLY_STATS.csv` | 9 950 | Current-month usage and payment status per customer |

**Notable data characteristics:**

- Customer IDs run from 1 to 10 000 but the rows in `CUSTOMERS.csv` are not sorted by ID.
- `MONTHLY_STATS.csv` has only 9 950 rows — 50 customers have no monthly record. This gap is intentional and meaningful: it represents a real insertion error scenario.
- `MONTHLY_STATS.csv` carries a UTF-8 BOM in its header row.
- Dates in `CUSTOMERS.csv` use `DD/MM/YYYY` format.
- Turkish characters appear in customer names, city names, and tariff names — the database and client connection must use UTF-8-compatible settings.

---

## Domain Vocabulary

Prefer these exact names when writing queries, issues, ADRs, or documentation. Do not drift to synonyms.

| Term | Meaning |
| --- | --- |
| `CUSTOMERS` | The customer master table |
| `TARIFFS` | The tariff/plan definitions table |
| `MONTHLY_STATS` | Current-month usage and payment records |
| `CUSTOMER_ID` | Primary key for a customer |
| `TARIFF_ID` | Primary key for a tariff, foreign key on `CUSTOMERS` |
| `SIGNUP_DATE` | The date a customer subscribed (`DD/MM/YYYY` in source) |
| `PAYMENT_STATUS` | One of `PAID`, `UNPAID`, `LATE` |
| `DATA_LIMIT` / `DATA_USAGE` | Package data allowance and actual consumption |
| `MINUTES_LIMIT` / `MINUTES_USAGE` | Package voice allowance and actual consumption |
| `SMS_LIMIT` / `SMS_USAGE` | Package SMS allowance and actual consumption |
| missing monthly record | A customer who has no row in `MONTHLY_STATS` — not zero usage, but absent |
| exhausted limits | All three package limits (data, minutes, SMS) fully consumed — only applies when the limit is positive; a `0` limit means the resource is not included in the plan |
| unpaid fee | Payment status is `UNPAID` or `LATE` — `PAID` is the only status that means no outstanding balance |

---

## Database Design

Three tables, mirroring the CSV files:

```
TARIFFS
  TARIFF_ID   PK
  ...

CUSTOMERS
  CUSTOMER_ID  PK
  TARIFF_ID    FK → TARIFFS.TARIFF_ID
  CITY
  SIGNUP_DATE
  ...

MONTHLY_STATS
  ID           PK
  CUSTOMER_ID  FK → CUSTOMERS.CUSTOMER_ID  (unique — one row per customer per month)
  PAYMENT_STATUS  CHECK IN ('PAID', 'UNPAID', 'LATE')
  DATA_LIMIT / DATA_USAGE
  MINUTES_LIMIT / MINUTES_USAGE
  SMS_LIMIT / SMS_USAGE
  MONTHLY_FEE  CHECK >= 0
  ...
```

**Relationship rules:**
- One tariff → many customers.
- One customer → zero or one `MONTHLY_STATS` row. A missing row is meaningful (the insertion-error scenario) and must be detected with a `LEFT JOIN` or anti-join, not treated as zero usage.

**Indexes:**
- `CUSTOMERS.TARIFF_ID` — supports tariff-based filters
- `CUSTOMERS.SIGNUP_DATE` — supports earliest/latest signup queries
- `CUSTOMERS.CITY` — supports city distribution queries
- `MONTHLY_STATS.PAYMENT_STATUS` — supports payment analysis

---

## Core Analytics Queries

These are the baseline SQL use cases the project demonstrates. Each is answered in `SOLUTIONS.sql`.

1. Customers subscribed to a specific tariff (e.g., `Kobiye Destek`)
2. The most recently signed-up customer on that tariff
3. Customer distribution by tariff
4. Earliest signup customers
5. City distribution of earliest signup customers
6. Customers with a missing monthly record
7. City distribution of customers with missing monthly records
8. Customers who used ≥ 75 % of their data limit
9. Customers who exhausted all package limits (data, minutes, and SMS — positive limits only)
10. Customers with unpaid fees (`UNPAID` or `LATE`)
11. Payment status distribution across tariffs

---

## Project Direction

The SQL layer is intentionally designed to be extended. Possible directions:

- **Reporting layer** — views or materialised views that pre-compute common aggregates (churn risk, data overage candidates, city-level summaries)
- **Docker Compose setup** — Oracle XE container with automatic schema seeding on first run
- **Data generation** — scripts to produce larger or refreshed synthetic datasets for load testing
- **ETL pipeline** — automate CSV → Oracle ingestion (Python / shell) so the database can be re-seeded from source files without manual DBeaver steps
- **Analytics dashboard** — a read-only web UI (e.g., Grafana, Metabase, or a custom Next.js app) querying the Oracle views
- **REST API** — a thin service layer exposing the analytics queries as JSON endpoints

Each direction would live in its own ADR under `docs/adr/` once a decision is made.
