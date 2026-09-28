#!/usr/bin/env bash
# Set up the GitHub branch rules that make the gates real. Needs the GitHub CLI (gh), logged in as you.
#
#   scripts/github-protect.sh            show what would be applied (dry run)
#   scripts/github-protect.sh --apply    create the ruleset on the default branch
#   scripts/github-protect.sh --apply --approvals 1   also require 1 approving review (team repos)
#
# Rules: changes reach main only by PR; the guardrails and verify checks must pass and must come from
# GitHub Actions (so nobody can fake them with a status API call); no force pushes or deletion.
# Admins (you) can bypass on a PR, which is the deliberate route for changing the loop's own rules
# and for Dependabot bumps you have reviewed. Bypasses are recorded by GitHub.
# Solo account note: GitHub does not let you approve your own PR, so leave --approvals at 0 when you
# work alone. Your merge is the approval. Keep the agent from merging by not giving it merge rights
# (the Claude deny rules block 'gh pr merge'), or give it its own GitHub identity.
# Private repos on a free personal account cannot use rulesets or branch protection (needs GitHub
# Pro). Public repos can. This script tells you if GitHub refuses.
# NOTE: written against GitHub's REST rulesets API; not tested against a live account. Run the dry
# run first and check the ruleset in Settings > Rules afterwards.
set -euo pipefail
APPLY=0; APPROVALS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --approvals) [ $# -ge 2 ] || { echo "--approvals needs a number"; exit 1; }; APPROVALS="$2"; shift 2;;
    *) echo "unknown option $1"; exit 1;;
  esac
done
[[ "$APPROVALS" =~ ^[0-9]$ ]] || { echo "--approvals must be a number from 0 to 9"; exit 1; }
command -v gh >/dev/null || { echo "Install the GitHub CLI first: https://cli.github.com"; exit 1; }
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
VIS="$(gh repo view --json visibility -q .visibility)"

BODY=$(cat <<JSON
{
  "name": "sdlc-gates",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request" } ],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": $APPROVALS,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": $( [ "$APPROVALS" -gt 0 ] && echo true || echo false ),
        "require_last_push_approval": $( [ "$APPROVALS" -gt 0 ] && echo true || echo false ),
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["merge", "squash", "rebase"] } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "guardrails", "integration_id": 15368 },
          { "context": "verify", "integration_id": 15368 } ] } }
  ]
}
JSON
)
echo "Repository: $REPO ($VIS)"
echo "$BODY"
[ "$APPLY" = 1 ] || { echo; echo "Dry run. Re-run with --apply to create this ruleset."; exit 0; }
if ! out="$(printf '%s' "$BODY" | gh api -X POST "repos/$REPO/rulesets" --input - 2>&1)"; then
  echo
  echo "GitHub refused:"
  echo "$out"
  if [ "$VIS" = "PRIVATE" ]; then
    echo "This is a private repo: on a free personal account rulesets need GitHub Pro (or make it public)."
  fi
  echo "Until rules are in place, CI still runs, but nothing stops a direct push to main."
  exit 1
fi
echo "Ruleset 'sdlc-gates' created. Check it under Settings > Rules > Rulesets."
