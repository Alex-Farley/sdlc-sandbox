## readme-how-to-use (002)

**Change (small route):** work/002-readme-how-to-use/change.md
**Verify:** work/002-readme-how-to-use/verify.md

### What changed
Adds a `## How to use` section to `README.md` pointing at the `sdlc-loop` skill
(`.agents/skills/sdlc-loop/SKILL.md`), with a one-line note on starting the loop or the small-change route.
No other files outside `work/` changed.

### How it was verified
```
$ scripts/sdlc verify
README present
sdlc verify: PASSED
```
TDD: RED 2026-09-29T08:43:30Z (exit 1), GREEN 2026-09-29T08:43:51Z (exit 0) in tdd.log. Link target checked to exist.

### Manual checks for the reviewer
1. Open `README.md` on GitHub and click the `sdlc-loop` link; confirm it opens the skill file.
2. Confirm the wording is clear to a newcomer.

### Risk
routine

> Agent-assisted: written with Claude Code (Claude Opus 5.5). A person reviews and merges; the agent cannot approve or merge.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
