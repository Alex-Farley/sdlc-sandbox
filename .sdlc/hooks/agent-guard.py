#!/usr/bin/env python3
"""Pre-tool guard for AI coding agents: Claude Code (PreToolUse), OpenAI Codex (PreToolUse) and
Gemini CLI (BeforeTool). All three send JSON on stdin with tool_name and tool_input, and all three
block the action when a hook exits with code 2 (the reason goes on stderr).

It FAILS CLOSED: any error blocks the action. The hook command in each tool's settings also turns
any other failure (python missing, a crash) into exit 2.

What it is: pattern matching, so a determined agent can still word its way round the command
checks (for example by writing a script and running it). The stronger controls are each tool's
sandbox and deny rules, the git hooks (which run the committed copy from HEAD), the CI guardrails
that run from the base branch, you reviewing the PR, and signed approvals (see the guide), which
are the only thing that proves an approval was yours.
"""
import json, os, re, subprocess, sys

# Always off-limits to the agent. People change these, via PR. Compared case-insensitively,
# because on macOS and Windows ".Claude/x" is ".claude/x".
HARD_PROTECTED = (".sdlc/", ".claude/", ".codex/", ".gemini/", ".agents/", ".github/", ".git/",
                  "scripts/sdlc", "scripts/github-protect.sh", "CLAUDE.md", "AGENTS.md", "REVIEW.md",
                  "maintain/runbooks/", "evals/run.sh")

SHELL_TOOLS = {"Bash", "PowerShell", "Monitor", "run_shell_command", "shell", "exec_command"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit", "write_file", "replace", "edit", "apply_patch"}

# Where git's subcommand sits: "git", then any global options (-C <dir>, --no-pager ...).
GIT = r"\bgit\s+(?:(?:-C|--git-dir|--work-tree|--namespace)\s+\S+\s+|-(?!c\b)\S+\s+)*"

BASH_BLOCK = [  # matched case-sensitively unless the pattern says (?i)
    (r"(?i)sdlc\s+(approve|unlock-test)\b", "Approving and unlocking are for a person, not the agent."),
    (r"(?i)SDLC_(ALLOW|APPROVING|SKIP|IN_RUNNER)", "That environment variable bypasses a human gate."),
    (r"\bGIT_(CONFIG|DIR|INDEX_FILE|WORK_TREE|EXEC_PATH|OBJECT_DIRECTORY|NAMESPACE)\w*", "Changing git's configuration or storage through the environment is not allowed."),
    (r"(?i)--no-v(?!erbose\b)|\bcommit\b[^|;&]*\s-[a-zA-Z]*n", "Skipping git hooks is not allowed."),
    (GIT + r"(-c|--config-env)[\s=]|(?i:core\.hookspath)\s*=|" + GIT + r"config\s+(?!(--get|--get-all|--get-regexp|--list|-l|--show-origin)\b)\S+\s+\S",
     "Changing git configuration is not allowed."),
    (GIT + r"(commit-tree|update-ref|update-index|hash-object|read-tree|write-tree|mktree|replace|filter-branch|filter-repo|fast-import|symbolic-ref)\b",
     "Low-level git commands that can bypass the hooks are not allowed."),
    (r"\bgh\b[^|;&]*\bpr\b[^|;&]*\s(merge|review)\b", "The agent never approves or merges PRs."),
    (r"\bgh\s+(?:-\S+\s+\S+\s+)*(api|alias|extension|ext|auth|secret|variable|ruleset|workflow|run\s+(rerun|cancel)|repo\s+(edit|delete|rename))\b",
     "That GitHub command is for a person (the agent may create, view, check and comment on PRs only)."),
    (r"\bgh\b[^|;&]*(\$\(|`|<\(|--body-file[\s=]+[~/]|\s-F\s+[~/]|@[~/])", "gh runs outside the sandbox, so it may not read files or run commands outside the repo."),
    (GIT + r"push\b[^|;&]*(\s--force(-with-lease)?\b|\s-f\b|\s\+\S)", "Force pushing is not allowed."),
    (GIT + r"push\b[^|;&]*(\s|:)(refs/heads/)?(main|master)\b", "Pushing to the main branch is not allowed. Push your sdlc/ branch and open a PR."),
    (GIT + r"push\b[^|;&]*[$`]", "Name the branch you push; no variables."),
    (r"(^|[;&|(]\s*)(script\s+-|unbuffer\b|expect\b|socat\b)|\bpty\b", "Faking a terminal is not allowed."),
    (r"(^|[;&|(]\s*|\s)((sed|perl)\b[^|;&]*\s-i|(python\d*|node|ruby)\b)[^|;&]*\bapproved\b", "Approvals are for a person, not the agent."),
]

# Shell commands may only READ protected files. A command segment that mentions a protected path
# must start with one of these.
READ_ONLY = re.compile(r"^(cat|less|more|head|tail|grep|egrep|fgrep|rg|ls|wc|diff|cmp|stat|file|"
                       r"sha256sum|shasum|md5sum|cd|pwd|echo\s+[^>]*$|test|\[|"
                       r"git\s+(log|show|diff|status|blame|ls-files|ls-tree|cat-file|rev-parse|grep)|"
                       r"sed\s+-n\s|awk\s+(?!.*-i\s)|"
                       r"gh\s+pr\s+(create|view|checks|diff|list|status|comment)\b|"
                       r"(\./)?scripts/sdlc\s|bash\s+(\./)?scripts/sdlc\s|find\s(?!.*(-delete|-exec|-ok)))")

APPROVAL_TEXT = re.compile(r"status:\s*[\"']?approved|approved_(by|on|sha256)\s*:|upstream_sha256\s*:|reviewed_commit\s*:", re.I)


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
        return {l.split("\t")[0].strip().lower()
                for l in open(os.path.join(root, ".sdlc/locked-tests"), encoding="utf-8") if l.strip()}
    except FileNotFoundError:
        return set()


def all_protected(root):
    return [p.lower() for p in HARD_PROTECTED + tuple(config_protected(root))]


def protected(rel, root):
    rel = rel.lower()
    if rel == ".gitattributes" or rel.endswith("/.gitattributes"):
        return True
    for p in all_protected(root):
        if p.endswith("/"):
            if rel.startswith(p) or rel == p.rstrip("/"):
                return True
        elif rel == p or rel.startswith(p + "/"):
            return True
    return False


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


def normalise(cmd):
    """Remove quoting and escapes so 'scripts/sdl""c' or "SDLC_"ALLOW cannot hide a word."""
    return re.sub(r"[\"'`\\]", "", cmd)


def root_forms(root):
    """The repo root as it may appear in a command: resolved, and as the tool reported it (on macOS
    /var/... and /private/var/... are the same folder)."""
    forms = {root.rstrip("/")}
    for v in (os.environ.get("CLAUDE_PROJECT_DIR"), os.environ.get("GEMINI_PROJECT_DIR"), os.getcwd()):
        if v and os.path.realpath(v) == root:
            forms.add(v.rstrip("/"))
    if root.startswith("/private/"):
        forms.add(root[len("/private"):])
    return sorted(forms, key=len, reverse=True)


def strip_root(text, root, repl):
    for f in root_forms(root):
        text = text.replace(f + "/", repl)
    return text


def mentions(segment, root):
    """A protected path named in a command: relative to the repo root (or absolute inside it)."""
    s = strip_root(segment, root, " ").lower()
    words = [p.rstrip("/") for p in all_protected(root)] + [".gitattributes"]
    for w in words:
        if not w:
            continue
        # at the start of a word (not after a /, so docs/review.md is not REVIEW.md)
        if re.search(r"(^|[\s=(<>:])(\./)?" + re.escape(w) + r"(/|\s|$|[)'\";&|>])", s):
            return w
    if re.search(r"(^|[\s=(<>:/])\.gitattributes(\s|$)", s):
        return ".gitattributes"
    return None


def copy_into_safe_place(seg, root):
    """cp/install from a protected folder (e.g. .sdlc/templates) into an ordinary one is fine."""
    parts = seg.split()
    if len(parts) >= 3 and parts[0] in ("cp", "install") and not mentions(" " + parts[-1], root):
        return True
    return False


MESSAGE_ARG = re.compile(r"(\s(?:-m|--message|--title|--body|-t|-b)[\s=]*)(\"[^\"$`\\]*\"|'[^']*')")  # no $( or ` inside


HEREDOC = re.compile(r"(?P<head>[^\n]*)<<-?\s*(?P<q>['\"]?)(?P<tag>\w+)(?P=q)[^\n]*\n(?P<body>.*?)\n\s*(?P=tag)\s*(?=\n|$)", re.S)
INTERPRETER = re.compile(r"(^|[;&|(\s])(bash|sh|zsh|dash|ksh|python\d*|node|ruby|perl|php|eval|source|\.)\b[^\n]*$")


def drop_text_heredocs(cmd):
    """A heredoc written to a file (cat > work/x.md <<EOF ... EOF) is text, so drop its body. One fed to
    a shell or interpreter (bash <<EOF) is code, so keep it and check it like any other command."""
    def repl(m):
        return m.group(0) if INTERPRETER.search(m.group("head")) else m.group("head") + "<<HEREDOC"
    return HEREDOC.sub(repl, cmd)


def check_shell(cmd, root):
    cmd = drop_text_heredocs(str(cmd))
    norm = normalise(cmd)
    # Commit messages and PR titles are text, not commands or paths. Absolute paths inside the
    # repo are treated as the repo-relative paths they are.
    norm = strip_root(normalise(MESSAGE_ARG.sub(r"\1MSG", cmd)), root, "")
    for pattern, why in BASH_BLOCK:
        if re.search(pattern, norm):
            block(why)
    # Split into simple commands and check each one that mentions a protected file.
    for seg in re.split(r"&&|\|\||[;|\n]|\$\(|`", norm):
        seg = seg.strip().lstrip("(").strip()
        seg = re.sub(r"^(sudo|env|command|builtin|nohup|time|exec)\s+", "", seg)
        seg = re.sub(r"^([A-Za-z_][A-Za-z0-9_]*=\S*\s+)+", "", seg)
        hit = mentions(seg, root)
        if not hit:
            continue
        if not READ_ONLY.match(seg) and not copy_into_safe_place(seg, root):
            block(f"That command could change a protected file ({hit}). Agents may only read these; ask a person.")
        for m in re.finditer(r">>?\s*([^\s&][^\s]*)", seg):
            if mentions(" " + m.group(1), root):
                block(f"Writing to a protected file ({hit}) is not allowed.")


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
            if rel.lower() in locked(root):
                block(f"{rel} is a locked test. Fix the code, not the test.")
            if rel.lower().startswith("work/") and APPROVAL_TEXT.search(new_text(inp)):
                block("Agents never approve gates. Leave status: draft and ask the approver to run scripts/sdlc approve.")

    if tool in SHELL_TOOLS:
        cmd = inp.get("command", "")
        if isinstance(cmd, list):
            cmd = " ".join(map(str, cmd))
        check_shell(cmd, root)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # fail closed
        block(f"guard error ({e.__class__.__name__}); blocking to be safe")
    sys.exit(0)
