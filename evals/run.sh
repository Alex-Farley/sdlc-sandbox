#!/usr/bin/env bash
# Continuous evals: re-run real past tasks whenever the agent's instructions change (AGENTS.md,
# skills, hooks) so a "small wording tweak" cannot silently make it worse.
#
#   evals/run.sh                                                                   # dry run, free
#   AGENT_CMD='claude -p --permission-mode acceptEdits --max-turns 25' evals/run.sh
#   AGENT_CMD='codex exec --full-auto'                                 evals/run.sh
#   AGENT_CMD='gemini -y -p'                                           evals/run.sh
#
# Each case runs in a throwaway git worktree at its 'base' commit, with TODAY's agent instructions
# copied in, so you are testing the current instructions against an old task.
#
# SECURITY: eval cases are code. The 'check' line is run as a shell command and the prompt steers an
# agent that can edit files and run commands. Only run cases from your own main branch, never from
# an unreviewed PR, and prefer a container or VM (the agent is not sandboxed by this script).
# COST: roughly one agent task per case.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT" || exit 1
MIN_PASS="${EVAL_MIN_PASS:-100}"
pass=0; total=0; failed=0; results=""
CONFIG_PATHS="AGENTS.md CLAUDE.md REVIEW.md .agents .claude .sdlc .gemini"

if command -v timeout >/dev/null; then TO="timeout ${EVAL_TIMEOUT:-900}"
elif command -v gtimeout >/dev/null; then TO="gtimeout ${EVAL_TIMEOUT:-900}"
else TO=""; echo "note: no 'timeout' command (macOS: brew install coreutils); cases will not be time-limited" >&2; fi

field() { tr -d '\r' < "$1" | awk -v k="$2" 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f&&index($0,k":")==1{v=substr($0,length(k)+2); sub(/^[ \t]+/,"",v); if(v~/^"/){v=substr(v,2); sub(/".*$/,"",v)} else {sub(/[ \t]+#.*$/,"",v)} print v; exit}'; }
section() { tr -d '\r' < "$1" | awk -v h="## $2" '$0==h{f=1;next} f&&/^## /{exit} f&&!/^<!--/{print}'; }

for c in evals/cases/*.md; do
  [ -f "$c" ] || continue
  [ "$(basename "$c")" = "_template.md" ] && continue
  total=$((total+1))
  id="$(field "$c" id)"; base="$(field "$c" base)"; check="$(field "$c" check)"
  prompt="$(section "$c" Prompt)"
  if [ -z "${AGENT_CMD:-}" ]; then results+="DRY  $id  (base=${base:-HEAD}, check=$check)"$'\n'; continue; fi
  if [ -z "$prompt" ] || [ -z "$check" ]; then results+="ERR  $id  missing prompt or check"$'\n'; failed=1; continue; fi

  wt="$(mktemp -d "${TMPDIR:-/tmp}/eval.XXXXXX")/$id"; log="$wt.log"
  if ! git worktree add -q --detach "$wt" "${base:-HEAD}" 2>"$log"; then results+="ERR  $id  bad base ref"$'\n'; continue; fi
  for p in $CONFIG_PATHS; do
    [ -e "$p" ] || continue
    rm -rf "${wt:?}/$p"; cp -R "$p" "$wt/$p"
  done
  ( cd "$wt" && $TO $AGENT_CMD "$prompt" ) >> "$log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    results+="FAIL $id  agent exited $rc (log: $log)"$'\n'
  elif ( cd "$wt" && bash -c "$check" ) >> "$log" 2>&1; then
    pass=$((pass+1)); results+="PASS $id"$'\n'
  else
    results+="FAIL $id  check failed (log: $log)"$'\n'
  fi
  git worktree remove --force "$wt" >/dev/null 2>&1 || true
done

printf '%s' "$results"
if [ -z "${AGENT_CMD:-}" ]; then echo "Dry run: $total case(s). Set AGENT_CMD to run them (costs tokens)."; exit 0; fi
[ "$total" -gt 0 ] || { echo "No eval cases yet."; exit 0; }
pct=$(( pass * 100 / total ))
echo "Evals: $pass/$total passed ($pct%). Gate: $MIN_PASS%."
[ "$pct" -ge "$MIN_PASS" ] && [ "$failed" = 0 ]
