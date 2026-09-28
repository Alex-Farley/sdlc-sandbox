#!/usr/bin/env python3
"""Pre-tool guard for AI coding agents: Claude Code (PreToolUse), OpenAI Codex (PreToolUse) and
Gemini CLI (BeforeTool). All three send JSON on stdin with tool_name and tool_input, and all three
block the action when a hook exits with code 2 (the reason goes on stderr).

It FAILS CLOSED: any error blocks the action.

What it is: pattern matching, so a determined agent can word its way round the command checks.
The stronger controls are each tool's sandbox and deny rules, the CI guardrails that run from the
base branch, and you reviewing the PR. Signed approvals (see the guide) are what prove it was you.
"""
import json, os, re, subprocess, sys

# Always off-limits to the agent. People change these, via PR.
HARD_PROTECTED = (".sdlc/", ".claude/", ".codex/", ".gemini/", ".agents/", ".github/", ".git/",
                  "scripts/sdlc", "scripts/github-protect.sh", "CLAUDE.md", "REVIEW.md",
                  "maintain/runbooks/")

SHELL_TOOLS = {"Bash", "run_shell_command", "shell", "exec_command"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit", "write_file", "replace", "edit", "apply_patch"}

BASH_BLOCK = [
    (r"sdlc['\"]?\s+['\"]?(approve|unlock-test)\b", "Approving and unlocking are for a person, not the agent."),
    (r"SDLC_(ALLOW|APPROVING|SKIP)", "That environment variable bypasses a human gate."),
    (r"--no-verif|\bcommit\b[^|;&]*\s-[a-zA-Z]*n\b", "Skipping git hooks is not allowed."),
    (r"\bgit\b[^|;&]*\s-c\s|core\.hookspath\s*=|\bgit\s+config\s+(?!--get\b|--list\b|-l\b)", "Changing git configuration is not allowed."),
    (r"\bgh\s+pr\s+(merge|review)\b", "The agent never approves or merges PRs."),
    (r"\bgh\s+api\b.*(merge|reviews|statuses|check-runs|rulesets|branches/.*/protection)", "That GitHub API call is for a person."),
    (r"\bgit\b[^|;&]*\bpush\b[^|;&]*(\s--force(-with-lease)?\b|\s-f\b|\s\+\S)", "Force pushing is not allowed."),
    (r"\bscript\s+-|\bpty\b|(^|[;&|(]\s*)(unbuffer|expect)\b", "Faking a terminal is not allowed."),
    (r"(^|[;&|(]\s*|\s)(sed|perl|awk|tee|dd|truncate|mv|cp|rm|chmod|ln)\b[^|;&]*\s['\"]?(\./)?(\.sdlc/|\.claude/|\.codex/|\.gemini/|\.agents/|\.github/|scripts/sdlc|\S*\.gitattributes)",
     "That command changes protected files."),
    (r"(^|[;&|(]\s*|\s)(sed|perl)\b[^|;&]*\bapproved\b", "Approvals are for a person, not the agent."),
    (r"(>|>>)\s*['\"]?(\./)?(\.sdlc/|\.claude/|\.codex/|\.gemini/|scripts/sdlc|\.github/)", "Writing to protected files is not allowed."),
]
APPROVAL_TEXT = re.compile(r"status:\s*[\"']?approved|approved_(by|on|sha256)\s*:|upstream_sha256\s*:", re.I)

def block(msg):
    print(f"Blocked by the sdlc guard: {msg}", file=sys.stderr)
    sys.exit(2)

def repo_root(data):
    for v in (os.environ.get("CLAUDE_PROJECT_DIR"), os.environ.get("GEMINI_PROJECT_DIR")):
        if v:
            return os.path.realpath(v)
    cwd = data.get("cwd") or os.getcwd()
    out = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return os.path.realpath(out.stdout.strip() or cwd)

def protected(rel, root):
    if rel == ".gitattributes" or rel.endswith("/.gitattributes"):
        return True
    for p in HARD_PROTECTED + tuple(config_protected(root)):
        if rel == p.rstrip("/") or rel.startswith(p if p.endswith("/") else p + "/") or rel == p:
            return True
    return False

def config_protected(root):
    try:
        for line in open(os.path.join(root, ".sdlc/config"), encoding="utf-8"):
            m = re.match(r"""\s*PROTECTED_PATHS=["']?(.*?)["']?\s*(#.*)?$""", line)
            if m:
                return m.group(1).split()
    except FileNotFoundError:
        pass
    return []

def locked(root):
    try:
        return {l.split("\t")[0].strip() for l in open(os.path.join(root, ".sdlc/locked-tests"), encoding="utf-8") if l.strip()}
    except FileNotFoundError:
        return set()

def paths_in(inp):
    """Every file path an edit tool is about to touch (Claude, Gemini, Codex apply_patch)."""
    out = [inp.get(k) for k in ("file_path", "notebook_path", "path", "absolute_path") if isinstance(inp.get(k), str)]
    for v in inp.values():  # Codex apply_patch carries the patch text
        if isinstance(v, str):
            out += re.findall(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$", v, re.M)
            out += re.findall(r"^\*\*\* Move to: (.+)$", v, re.M)
    return [p.strip() for p in out if p and p.strip()]

def new_text(inp):
    """Only the text being written, not the text being replaced, so re-drafting is allowed."""
    parts = [inp.get(k) for k in ("content", "new_string", "new_source", "new_str") if isinstance(inp.get(k), str)]
    for e in inp.get("edits") or []:
        if isinstance(e, dict) and isinstance(e.get("new_string"), str):
            parts.append(e["new_string"])
    for v in inp.values():  # added lines in a patch
        if isinstance(v, str) and "*** Begin Patch" in v:
            parts += [l[1:] for l in v.splitlines() if l.startswith("+")]
    return "\n".join(parts)

def main():
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    if not isinstance(inp, dict):
        block("unexpected tool input")
    root = repo_root(data)

    if tool in EDIT_TOOLS:
        paths = paths_in(inp)
        if not paths:
            block("no file path supplied")
        for raw in paths:
            full = os.path.realpath(raw if os.path.isabs(raw) else os.path.join(root, raw))
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if rel.startswith(".."):
                continue  # outside the repo: the tool's sandbox and permission rules decide
            if protected(rel, root):
                block(f"{rel} is protected. Ask a person to make this change.")
            if rel in locked(root):
                block(f"{rel} is a locked test. Fix the code, not the test.")
            if rel.startswith("work/") and APPROVAL_TEXT.search(new_text(inp)):
                block("Agents never approve gates. Leave status: draft and ask the approver to run scripts/sdlc approve.")

    if tool in SHELL_TOOLS:
        cmd = inp.get("command", "")
        if isinstance(cmd, list):
            cmd = " ".join(map(str, cmd))
        for pattern, why in BASH_BLOCK:
            if re.search(pattern, str(cmd), re.IGNORECASE):
                block(why)

if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # fail closed
        block(f"guard error ({e.__class__.__name__}); blocking to be safe")
    sys.exit(0)
