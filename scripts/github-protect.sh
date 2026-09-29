#!/usr/bin/env bash
# Set up the GitHub branch rules that make the gates real. Needs the GitHub CLI (gh), logged in as you.
#
#   scripts/github-protect.sh            show what would be applied (dry run)
#   scripts/github-protect.sh --apply    create the ruleset on the default branch
#   scripts/github-protect.sh --apply --approvals 1   also require 1 approving review (team repos)
#   scripts/github-protect.sh --apply --require-ai-review   also require the ai-review check (turn on
#                                        the sdlc-ai-review workflow first; see its header)
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
# Tested live: the ruleset (4.0.1, on a public personal repo). NOT yet tested live: the Actions
# policy (new in 4.1, written from GitHub's REST docs for /repos/{owner}/{repo}/actions/policies).
# Run the dry run first, then check Settings > Rules and Settings > Actions > Policies afterwards.
# Safe to re-run: anything that already exists is left alone.
set -euo pipefail
APPLY=0; APPROVALS=0; AIREV=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --require-ai-review) AIREV=1; shift;;
    --approvals) [ $# -ge 2 ] || { echo "--approvals needs a number"; exit 1; }; APPROVALS="$2"; shift 2;;
    *) echo "unknown option $1"; exit 1;;
  esac
done
[[ "$APPROVALS" =~ ^[0-9]$ ]] || { echo "--approvals must be a number from 0 to 9"; exit 1; }
command -v gh >/dev/null || { echo "Install the GitHub CLI first: https://cli.github.com"; exit 1; }
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
VIS="$(gh repo view --json visibility -q .visibility)"

AI_CHECK=""; [ "$AIREV" = 1 ] && AI_CHECK=',
          { "context": "ai-review", "integration_id": 15368 }'
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
          { "context": "verify", "integration_id": 15368 }$AI_CHECK ] } }
  ]
}
JSON
)
POLICY=$(cat <<'JSON'
{
  "name": "sdlc-allow-pull-request-target",
  "enforcement": "active",
  "conditions": { "workflow_path": { "include": [".github/workflows/sdlc-guardrails.yml", ".github/workflows/sdlc-ai-review.yml"], "exclude": [] } },
  "rules": [ { "type": "restrict_action_events", "parameters": { "allowed_events": ["pull_request_target"] } } ]
}
JSON
)

echo "Repository: $REPO ($VIS)"
echo
echo "1. Branch ruleset 'sdlc-gates':"
echo "$BODY"
echo
echo "2. Actions policy allowing pull_request_target for the two sdlc workflows only."
echo "   From 2 November 2026 GitHub turns that trigger off by default on public repos; without this"
echo "   the guardrails check never runs and every merge needs your bypass."
echo "$POLICY"
[ "$APPLY" = 1 ] || { echo; echo "Dry run. Re-run with --apply to create both."; exit 0; }

RID="$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name=="sdlc-gates") | .id' 2>/dev/null || true)"
if [ -n "$RID" ] && [ "$AIREV" = 1 ]; then
  # Add the ai-review check to the existing ruleset, keeping everything else as it is.
  cur="$(gh api "repos/$REPO/rulesets/$RID")"
  new="$(printf '%s' "$cur" | python3 -c '
import json, sys
r = json.load(sys.stdin)
keep = {k: r[k] for k in ("name", "target", "enforcement", "bypass_actors", "conditions", "rules") if k in r}
for rule in keep["rules"]:
    if rule["type"] == "required_status_checks":
        checks = rule["parameters"]["required_status_checks"]
        if not any(c["context"] == "ai-review" for c in checks):
            checks.append({"context": "ai-review", "integration_id": 15368})
print(json.dumps(keep))')"
  if printf '%s' "$new" | gh api -X PUT "repos/$REPO/rulesets/$RID" --input - >/dev/null; then
    echo "Ruleset 'sdlc-gates' now also requires the ai-review check."
  else
    echo "GitHub refused the ruleset update. Add 'ai-review' as a required check under Settings > Rules > Rulesets."; exit 1
  fi
elif [ -n "$RID" ]; then
  echo "Ruleset 'sdlc-gates' already exists - left as it is (edit it under Settings > Rules > Rulesets)."
elif ! out="$(printf '%s' "$BODY" | gh api -X POST "repos/$REPO/rulesets" --input - 2>&1)"; then
  echo
  echo "GitHub refused the ruleset:"
  echo "$out"
  if [ "$VIS" = "PRIVATE" ]; then
    echo "This is a private repo: on a free personal account rulesets need GitHub Pro (or make it public)."
  fi
  echo "Until rules are in place, CI still runs, but nothing stops a direct push to main."
  exit 1
else
  echo "Ruleset 'sdlc-gates' created. Check it under Settings > Rules > Rulesets."
fi

if [ "$VIS" != "PUBLIC" ]; then
  echo "Private repo: GitHub's default pull_request_target block applies to public repos only, so no Actions policy is needed."
  exit 0
fi
if gh api "repos/$REPO/actions/policies" --jq '.policies[]?.name' 2>/dev/null | grep -qx 'sdlc-allow-pull-request-target'; then
  echo "Actions policy 'sdlc-allow-pull-request-target' already exists."
elif ! out="$(printf '%s' "$POLICY" | gh api -X POST "repos/$REPO/actions/policies" --input - 2>&1)"; then
  echo
  echo "GitHub refused the Actions policy:"
  echo "$out"
  echo "Set it by hand: Settings > Actions > Policies > New policy, restrict events, allow"
  echo "pull_request_target, and target .github/workflows/sdlc-guardrails.yml and sdlc-ai-review.yml."
  echo "Then open a test PR and check the 'guardrails' check runs."
  exit 1
else
  echo "Actions policy created. Check it under Settings > Actions > Policies, then open a test PR and"
  echo "confirm the 'guardrails' check still runs."
fi
