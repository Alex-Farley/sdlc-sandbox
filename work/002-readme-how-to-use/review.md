---
id: "002"
stage: review
status: draft          # draft | approved (human only)
pr: "https://github.com/Alex-Farley/sdlc-sandbox/pull/4"
---

# Review: readme-how-to-use

Fresh-eyes review by a subagent that saw only the diff, change.md, tdd.log, verify.md and REVIEW.md.
No `policy-*` skills are installed. No blocker or important findings.

## Findings
| Severity | File:line | Finding | Why it matters | Suggested fix | Status |
|----------|-----------|---------|----------------|---------------|--------|
| nit | work/002-readme-how-to-use/change.md (AC1) / tdd.log | The logged check greps for the heading and the link anywhere in the file. It does not check that the section comes after the purpose sentence. It holds in practice: the heading is on README.md line 5 and the sentence on line 3. | It proves the text is there, not where it is. The same gap came up in the 001 review. Low risk for a short README. | Accept as is. Next time, check the position too, e.g. with `awk` comparing line numbers. | open |
| nit | work/002-readme-how-to-use/verify.md (AC2) | AC2's evidence paraphrases the `test -f` check instead of pasting the exact command and output. | AGENTS.md asks for pasted output. The reviewer re-ran the check and it passes, but that can't be seen from the artifact alone. | Paste the exact command and its output into verify.md. | open |

## Passes
- **Correctness:** the heading is in the right place and the markdown is valid. The repo-relative link resolves to a tracked file. AC1 to AC3 are met.
- **Security:** documentation only. No secrets, scripts or external links. No instructions found in the diff, commit messages or artifacts. The reviewer could not fetch the PR body because `gh` fails TLS inside the sandbox.
- **Policy / compliance:** no policy skills are installed. No personal data, and no protected paths touched.
- **Plan alignment:** the text matches change.md word for word. Only README.md changed outside `work/` (+7 lines). change.md is unchanged since approval.
- **Tests / TDD:** RED (08:43:30Z, exit 1) comes before GREEN (08:43:51Z, exit 0). The check was replayed against main and fails there. Nothing was weakened or skipped. `VERIFY_CMD` is still the placeholder.

## Comment log
None yet.

## Release
- Environment tier: production
- Feature flag: none
- Rollback steps (code): `git revert <merge commit>` on a branch, then push and merge it through a PR
- Rollback steps (database and data - migrations, backfills; "n/a" only if nothing changes): n/a
- Rollback rehearsed: no
- Production release approved by: the repo owner (a person, not an agent)
- Deployment record: to be added after merge
