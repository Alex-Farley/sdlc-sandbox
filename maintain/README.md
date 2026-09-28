# Maintain loop

`detect.py` watches a metric and decides, with no AI, whether anything is wrong. At tier 2+ it
creates the work item itself and (only if you set `AGENT_CMD_READONLY`) asks an agent for a
read-only diagnosis. The agent never gets write access from this script.

## Try it (free)
    python3 maintain/detect.py --metric error_rate --file maintain/sample/error_rate.csv

## Add a read-only diagnosis (costs tokens only when a new breach happens)
    AGENT_CMD_READONLY='claude -p --permission-mode plan --max-turns 15' python3 maintain/detect.py ...
    AGENT_CMD_READONLY='codex exec --sandbox read-only'                  python3 maintain/detect.py ...

## Before feeding it real data
- Export only numbers (`timestamp,value`). Do not pass raw logs that may contain personal data.
- The breach file and any diagnosis are untrusted: a person triages every new intent.md.

## Schedule it (off by default)
- Your own machine: cron, e.g. hourly `cd /path/to/repo && python3 maintain/detect.py ...`
- GitHub Actions: `on: schedule`, export metrics to CSV, run detect.py, open a PR with the new work item
- Claude: a scheduled task that runs the sdlc-maintain skill (e.g. a monthly security scan)

## Tier 3 actions
Tier 3 is reported, not acted on, by this script. If you later want an agent to run a runbook at
tier 3, put the runbook in `maintain/runbooks/` (protected), rehearse it, and wire it up deliberately.
