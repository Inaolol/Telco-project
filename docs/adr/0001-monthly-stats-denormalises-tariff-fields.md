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
