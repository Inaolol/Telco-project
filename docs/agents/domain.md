# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — primary domain source: dataset descriptions, domain vocabulary, schema decisions, business rules, and project direction.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. This directory will be created as architectural decisions get recorded.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront.

## File structure

Single-context repo:

```
/
├── CONTEXT.md                        ← primary domain source (read this first)
├── docs/
│   ├── agents/                       ← skill configuration
│   └── adr/                          ← architectural decisions (created on demand)
├── TABLE_CREATION_SCRIPTS.sql
└── SOLUTIONS.sql
```

## Use the domain's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the terms as defined in `CONTEXT.md`. Key terms: `CUSTOMERS`, `TARIFFS`, `MONTHLY_STATS`, `TARIFF_ID`, `CUSTOMER_ID`, `PAYMENT_STATUS`, `SIGNUP_DATE`, `missing monthly record`, `exhausted limits`, `unpaid fee`.

Don't drift to synonyms — e.g. prefer `MONTHLY_STATS` over "usage table", prefer `missing monthly record` over "absent record" or "null entry".

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0001 — but worth reopening because…_
