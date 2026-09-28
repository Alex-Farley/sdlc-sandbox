---
id: "001"
title: "readme-purpose"
stage: change
route: small
status: approved
risk: routine
branch: "sdlc/001-readme-purpose"
created: "2026-09-28"
approved_by: "alex farley <37551336+Alex-Farley@users.noreply.github.com>"
approved_on: "2026-09-28T17:30:36Z"
approved_sha256: 15ca3d8c0b788745cd71fc84d920754a40a369814b3197230ae3e32c642b850b
---

# Small change: readme-purpose

<!-- Small-change route: intent, spec and plan in one short file with one approval.
     Only for changes that are ALL of: routine risk, about a day's work or less, no new or changed
     personal data, no auth/payments/infrastructure/migrations, no protected paths, and no
     policy-* flag. If any of these is not true, use the full route (scripts/sdlc new <slug>). -->

## Why (problem and evidence)
`README.md` contains only the heading `# sdlc-sandbox` (no trailing newline). Someone landing on the
repo cannot tell what it is for. Evidence: `cat README.md` at commit 1f94e3b.

## What changes (and what does not)
Changes: `README.md` gets one sentence under the heading:

> A sandbox for trying out the AI-native SDLC pack: the delivery loop (intent, spec, plan, build,
> verify, review, maintain) that people and AI agents follow in this repo.

Does not change: any other file, the heading, AGENTS.md, scripts, skills or protected paths.

## Acceptance criteria (Given / When / Then)
| ID | Given | When | Then |
|----|-------|------|------|
| AC1 | the repo at this branch | a reader opens `README.md` | the line after the `# sdlc-sandbox` heading says the repo is a sandbox for trying out the AI-native SDLC pack |
| AC2 | the repo at this branch | `git diff main -- . ':!work'` is run | only `README.md` has changed |

## Plan (test first: red, green, refactor)
| Step | Test first (name, file) | Code change |
|------|-------------------------|-------------|
| 1    | `grep -q "sandbox for trying out the AI-native SDLC pack" README.md` - fails (red) on current README | Add the sentence (and a trailing newline) to `README.md`; re-run the grep (green) |

## Checks that this qualifies as small
- [x] Routine risk, about a day or less
- [x] No new or changed personal data
- [x] No auth, payments, infrastructure, migrations or protected paths
- [x] No policy concerns
