# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

This is a single-context repo: use the root `CONTEXT.md` as the shared glossary and `docs/adr/` for architecture decisions. There is no root `CONTEXT-MAP.md` at the moment.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check `src/<context>/docs/adr/` for context-scoped decisions.
- **`docs/domains/ledger/`** — read when touching double-entry accounting, accounts, transactions, postings, ledgers, repositories, balances, or related invariants.
- **`docs/domains/credit/`** — read when touching credit accounts, repayment plans, billing cycles, interest, installment logic, or credit-specific workflows.
- **`docs/domains/budget/`** — read when touching budgets, allocations, periods, budget execution, alerts, or budget-specific workflows.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The producer skill (`/grill-with-docs`) creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo:

```text
/
├── CONTEXT.md
├── docs/adr/
├── docs/domains/
│   ├── budget/
│   ├── credit/
│   └── ledger/
└── docs/
```

Multi-context repo:

```text
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── <context>/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← context-specific decisions
    └── ...
```

## Use the glossary's vocabulary

When output names a domain concept in an issue title, refactor proposal, hypothesis, test name, or implementation note, use the terms from the project docs. Do not drift to synonyms that the docs avoid.

If the concept you need is not in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/grill-with-docs`).

## Flag ADR conflicts

If output contradicts an existing ADR or architecture decision doc, surface it explicitly rather than silently overriding it.
