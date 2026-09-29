---
id: "002"
title: "readme-how-to-use"
stage: change
route: small
status: approved
risk: routine
branch: "sdlc/002-readme-how-to-use"
created: "2026-09-29"
approved_by: "alex farley <37551336+Alex-Farley@users.noreply.github.com>"
approved_on: "2026-09-29T08:42:35Z"
approved_sha256: d0bce1169e42a95a2c02f17603bcb0bfb7b7cc9b58f771094903ddaed0e48185
---

# Small change: readme-how-to-use

<!-- Small-change route: intent, spec and plan in one short file with one approval.
     Only for changes that are ALL of: routine risk, about a day's work or less, no new or changed
     personal data, no auth/payments/infrastructure/migrations, no protected paths, and no
     policy-* flag. If any of these is not true, use the full route (scripts/sdlc new <slug>). -->

## Why (problem and evidence)
`README.md` says what the repo is for but not how to start using the loop. A newcomer has to find
`AGENTS.md` or dig through the skills folder to learn that work starts with the `sdlc-loop` skill.
Evidence: `cat README.md` on `main` at 465ae7d shows only the heading and one purpose sentence.

## What changes (and what does not)
Changes: `README.md` gets a `## How to use` section after the purpose sentence:

> ## How to use
>
> All work follows the `sdlc-loop` skill
> ([`.agents/skills/sdlc-loop/SKILL.md`](.agents/skills/sdlc-loop/SKILL.md)). Ask your AI agent to
> "start the loop" for new work, or say "small change" for a routine fix. The agent stops at each
> gate for a person to approve.

Does not change: the heading, the purpose sentence, AGENTS.md, skills, scripts or any protected path.

## Acceptance criteria (Given / When / Then)
| ID | Given | When | Then |
|----|-------|------|------|
| AC1 | the repo at this branch | a reader opens `README.md` | there is a `## How to use` section after the purpose sentence |
| AC2 | the repo at this branch | a reader follows the link in that section | it resolves to the `sdlc-loop` SKILL.md, which exists |
| AC3 | the repo at this branch | `git diff main -- . ':!work'` is run | only `README.md` has changed |

## Plan (test first: red, green, refactor)
| Step | Test first (name, file) | Code change |
|------|-------------------------|-------------|
| 1    | `grep -q '^## How to use$' README.md && grep -q 'sdlc-loop/SKILL.md)' README.md` - fails (red) on current README | Add the section to `README.md`; re-run the greps (green) and check the link target exists |

## Checks that this qualifies as small
- [x] Routine risk, about a day or less
- [x] No new or changed personal data
- [x] No auth, payments, infrastructure, migrations or protected paths
- [x] No policy concerns
