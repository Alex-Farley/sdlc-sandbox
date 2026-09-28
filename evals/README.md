# Evals

A small suite of **real past tasks** with a check command that proves the agent did them right.
Run it whenever `AGENTS.md`, a skill or a hook changes, and on a schedule, so instruction changes
are regression-tested like code.

- Aim for 20-50 cases over time. Start with 3-5.
- Every bug fix and every incident adds one (the verify and maintain skills prompt for this).
- `evals/run.sh` with no `AGENT_CMD` is a free dry run. With `AGENT_CMD` set it costs roughly one
  agent task per case, so run it on changes to agent config and weekly, not on every commit.
