---
id: "{{ID}}"
stage: review
status: draft          # draft | approved (human only)
pr: ""
---

# Review: {{TITLE}}

## Findings
| Severity | File:line | Finding | Why it matters | Suggested fix | Status |
|----------|-----------|---------|----------------|---------------|--------|

<!-- Severity: blocker | important | nit (max nits per REVIEW.md) -->

## Comment log
<!-- Reviewer comment -> agent response -> commit -->

## Release
- Environment tier: dev | staging | production
- Feature flag: none | <name>, default OFF, owner, removal date; release = turning it on
- Rollback steps (code):
- Rollback steps (database and data - migrations, backfills; "n/a" only if nothing changes):
- Rollback rehearsed: yes | no
- Production release approved by: <person - not the person who directed the agent, for client code>
- Deployment record: <link to the merge/deploy run, what it contained, who approved>
