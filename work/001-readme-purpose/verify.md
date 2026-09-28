---
id: "001"
stage: verify
status: ready-for-review          # draft | ready-for-review
---

# Verify: readme-purpose

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
| AC1 | `grep -q "sandbox for trying out the AI-native SDLC pack" README.md` | 2026-09-28T17:32:17Z (exit 1, HEAD 6418b8b) | 2026-09-28T17:32:23Z (exit 0, HEAD f3e3377) | Pass |
| AC2 | `git diff --stat main -- . ':!work'` | n/a (diff check) | `README.md \| 4 +++-`, 1 file changed | Pass |

The AC1 check is a command logged via `scripts/sdlc red/green`, not a test file in a suite.

## Refactoring done
None needed.

## Deviations from the plan
None. The README also gained a blank line after the heading and a trailing newline, as the plan
stated.

## Evals added
None (not a bug fix).

## Manual checks for the reviewer
1. Open `README.md` and confirm the sentence under the heading describes the repo accurately.
