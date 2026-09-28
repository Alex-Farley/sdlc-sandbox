#!/usr/bin/env bash
# Shared helpers for scripts/sdlc and the git hooks. Sourced, never executed directly.
# Config is parsed as DATA (KEY="value" lines, fixed allowlist), never sourced, so a config file
# cannot run code or set bypass flags. Bypass flags come from the environment only.
# Works with bash 3.2 (macOS default) and later.

SDLC_KEYS="VERIFY_CMD PROTECTED_PATHS VERIFY_ON_COMMIT DEFAULT_BRANCH CLIENT_CODE AI_USE_APPROVAL REQUIRE_SIGNED_APPROVALS SECRETS_IGNORE_PATHS"

# Paths that are always protected, whatever the config says. People change these, deliberately.
SDLC_ALWAYS_PROTECTED=".sdlc/ .claude/ .codex/ .gemini/ .agents/ .github/ scripts/sdlc scripts/github-protect.sh CLAUDE.md REVIEW.md maintain/runbooks/"

# git diff that cannot be fooled by .gitattributes (-diff, textconv, external diff drivers).
sdlc_diff() { git -c core.quotePath=false diff --text --no-textconv --no-ext-diff "$@"; }

# sdlc_config_text: print the config to trust.
#   SDLC_CONFIG_FILE set (CI passes the base-branch copy) -> that file
#   otherwise the committed copy (HEAD), falling back to the working tree before the first commit.
# Reading HEAD means editing .sdlc/config in the working tree cannot switch off the checks.
sdlc_config_text() {
  if [ -n "${SDLC_CONFIG_FILE:-}" ]; then cat "$SDLC_CONFIG_FILE" 2>/dev/null; return; fi
  git show HEAD:.sdlc/config 2>/dev/null || cat .sdlc/config 2>/dev/null || true
}

# Locked tests: union of the trusted list and the list being committed, so a test locked earlier
# in the same PR is still protected. Lines are "path" or "path<TAB>blob-sha".
sdlc_locked_text() {
  {
    if [ -n "${SDLC_LOCKED_FILE:-}" ]; then cat "$SDLC_LOCKED_FILE" 2>/dev/null
    else git show HEAD:.sdlc/locked-tests 2>/dev/null || true; fi
    git show :.sdlc/locked-tests 2>/dev/null || true
  } | tr -d '\r' | awk 'NF' | sort -u
}

# shellcheck disable=SC2034  # variables are used by the scripts that source this file
sdlc_load_config() {
  VERIFY_CMD=""; PROTECTED_PATHS=""; VERIFY_ON_COMMIT="0"; DEFAULT_BRANCH="main"
  CLIENT_CODE="0"; AI_USE_APPROVAL=""; REQUIRE_SIGNED_APPROVALS="0"; SECRETS_IGNORE_PATHS=""
  local line key val
  local tail='[[:space:]]*(#.*)?$'
  local re_dq="^([A-Z_]+)=\"(.*)\"$tail" re_sq="^([A-Z_]+)='(.*)'$tail" re_bare="^([A-Z_]+)=([^[:space:]\"'#]*)$tail"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ $re_dq ]] || [[ "$line" =~ $re_sq ]] || [[ "$line" =~ $re_bare ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
      case " $SDLC_KEYS " in *" $key "*) printf -v "$key" '%s' "$val";; *) echo "sdlc: ignoring unknown config key $key" >&2;; esac
    else
      echo "sdlc: ignoring unparseable config line: $line" >&2
    fi
  done <<< "$(sdlc_config_text)"
}

# Is a path protected? (always-protected list, config list, and any .gitattributes at any depth)
sdlc_is_protected() {
  local path="$1" p
  case "$path" in .gitattributes|*/.gitattributes) return 0;; esac
  set -f
  for p in $SDLC_ALWAYS_PROTECTED $PROTECTED_PATHS; do
    case "$path" in "$p"|"$p"*) set +f; return 0;; esac
  done
  set +f
  return 1
}

sdlc_sha256() { if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

# Hash of everything after the front matter, line endings normalised.
sdlc_body_hash() { tr -d '\r' | awk 'NR==1&&/^---[[:space:]]*$/{f=1;next} f==1&&/^---[[:space:]]*$/{f=2;next} f==2{print}' | sdlc_sha256; }

# Read one front matter field. Handles quoted values and trailing comments; strips CR.
sdlc_fm_get() {
  tr -d '\r' < "$1" | awk -v k="$2" '
    NR==1&&/^---/{f=1;next} f&&/^---/{exit}
    f&&index($0,k":")==1 {
      v=substr($0,length(k)+2); sub(/^[ \t]+/,"",v)
      if (v ~ /^"/) { v=substr(v,2); sub(/".*$/,"",v) }
      else if (v ~ /^'"'"'/) { v=substr(v,2); sub(/'"'"'.*$/,"",v) }
      else { sub(/[ \t]+#.*$/,"",v); sub(/[ \t]+$/,"",v) }
      print v; exit }'
}

# Upstream artifact for each gate (the approval of X also pins the hash of its upstream).
sdlc_upstream_of() {
  case "$1" in spec) echo intent;; plan) echo spec;; review) echo plan;; *) echo "";; esac
}
