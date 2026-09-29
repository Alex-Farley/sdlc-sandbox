---
id: "002"
stage: verify
status: ready-for-review          # draft | ready-for-review
---

# Verify: readme-how-to-use

## Verify command
```
$ scripts/sdlc verify
$ test -f README.md && echo README present
README present
sdlc verify: PASSED
```
Note: `VERIFY_CMD` is still the placeholder check (README exists); AGENTS.md build/test/lint
commands are not filled in yet, so there is no build, test suite or linter to run.

## Acceptance criteria and TDD evidence
| AC | Test | RED seen (tdd.log time) | GREEN seen | Result |
|----|------|-------------------------|------------|--------|
| AC1 | `grep -q '^## How to use$' README.md && grep -q 'sdlc-loop/SKILL.md)' README.md` | 2026-09-29T08:43:30Z (exit 1, HEAD 523dfbc) | 2026-09-29T08:43:51Z (exit 0, HEAD e3ba96f) | Pass |
| AC2 | `test -f` on the link target extracted from README.md | n/a (existence check) | `link target exists` | Pass |
| AC3 | `git diff --stat main -- . ':!work'` | n/a (diff check) | `README.md \| 7 +++++++`, 1 file changed | Pass |

The AC1 check is a command logged via `scripts/sdlc red/green`, not a test file in a suite.

## Refactoring done
None needed.

## Deviations from the plan
None. The section text matches change.md word for word.

## Evals added
None (not a bug fix).

## Manual checks for the reviewer
1. Open `README.md` on GitHub and click the `sdlc-loop` link; confirm it opens the skill file.
2. Confirm the wording is clear to a newcomer.
