---
name: sdlc-setup
description: Prepares a repository for the AI-native delivery loop - asks whether it is client code (AI-use gate), which policies apply, fills in AGENTS.md and the verify command, and checks GitHub protection. Use once per repo after installing the pack, or when someone says "set up the loop", "write our AGENTS.md" or "the agent keeps making the same mistake".
---

# SDLC setup

The first thing to do in a repo. Everything else depends on it. You draft; the person commits.

## 1. Ask three questions first
1. **Is this client code, or will it hold client data?** If yes:
   - install `policy-ai-use` if it is not present (`install.sh <repo> --policies ai-use`)
   - the person sets `CLIENT_CODE="1"` and fills `AI_USE_APPROVAL` in `.sdlc/config` (who agreed,
     the contract or DPA reference, which tool and account). Until then `scripts/sdlc new` refuses.
   - Do not read further into the repo until they confirm AI use is permitted.
   - At dxw, also install `policy-dxw` (from `private-policies/`). It requires client code to be
     in a dxw- or client-owned, private repository (not a personal account), the AI tool to be
     approved through How to purchase, the client's AI policy checked, and a second person to
     approve production changes (`github-protect.sh --apply --approvals 1`).
2. **Which policies apply?** Offer the list (`install.sh --list-policies`): ai-use, uk-gov-security,
   uk-data-protection, accessibility, gov-service-standard, nhs, financial-services, isms-template.
   All are optional. Suggest based on the client (e.g. an NHS trust: nhs, uk-gov-security,
   uk-data-protection, accessibility). The person installs them.
3. **Is it on GitHub, and is it public or private?** Branch rules are free on public repos but need
   GitHub Pro for private repos on a personal account. Point them at `scripts/github-protect.sh`.

## 2. Read the repo, read-only
README, build files (`package.json`, `Makefile`, `pyproject.toml`, `Gemfile`, `pom.xml`,
`composer.json`, `Dockerfile`), CI config, top-level folders. Change nothing yet.

## 3. Find the verify commands
Build, test, lint. Run each once and note what a pass looks like. If one is missing, say so.

## 4. Draft AGENTS.md (one page)
From `.sdlc/templates/AGENTS.md`: verify commands, conventions that matter, a five-line
architecture overview, and an empty "Common mistakes" list. `AGENTS.md` is protected (it is the
agents' instructions, so an agent must not be able to rewrite its own rules). Write your draft to
`AGENTS.draft.md` and tell the person to review it, then run:
`mv AGENTS.draft.md AGENTS.md && git add AGENTS.md && SDLC_ALLOW_PROTECTED=1 git commit -m "Fill in AGENTS.md"`

## 5. Draft the .sdlc/config changes for the person
You cannot edit `.sdlc/` (it is protected). Show the person the lines to set:
- `VERIFY_CMD` (build, test and lint chained with `&&`)
- extra `PROTECTED_PATHS`: generated code, vendored code, migrations that have run
- `DEFAULT_BRANCH`, `CLIENT_CODE`, `AI_USE_APPROVAL`
They edit and commit it with `SDLC_ALLOW_PROTECTED=1 git commit`.

## 6. Check the safety net and report
Tell the person plainly which of these are in place and which are not (read `.git/config` rather
than running `git config`, which the guard blocks):
- git hooks active (`hooksPath` in `.git/config` ends in `sdlc-hooks`; if not, the person runs
  `scripts/sdlc install-hooks`, once per clone)
- the install committed straight to main **before** branch rules are switched on
- for Claude: `.claude/settings.json` has the guard hook, deny rules and sandbox. The sandbox needs
  macOS, or Linux/WSL2 with `bubblewrap` and `socat` (Ubuntu 24.04+ also needs its AppArmor rule
  relaxed for bubblewrap). Without them Claude warns and runs unsandboxed.
- for Codex: the project is trusted in `~/.codex/config.toml` and the hook approved with `/hooks`
  (otherwise `.codex/` is ignored). Codex will ask before commits, because it keeps `.git` read-only.
- for Gemini: the folder is trusted (otherwise `.gemini/settings.json` and the hook are ignored)
- signed approvals: optional but recommended once the loop feels normal (see the guide)
- CI workflows `sdlc-guardrails` and `sdlc-verify` present (both required in the ruleset), CODEOWNERS username filled in
- GitHub branch rules applied (only possible on public repos or with GitHub Pro)
- gitleaks installed (much better secret detection than the built-in patterns)

## Keeping it current
When the agent repeats a mistake, or a reviewer says the same thing twice, propose one line for
"Common mistakes" in `AGENTS.md`; the person adds it (the file is protected). If it goes over a
page, suggest lines to merge or remove.

## Portability
`AGENTS.md` is read by Codex, Cursor, Copilot and others. Gemini CLI reads it when
`.gemini/settings.json` sets `context.fileName` (the installer does this with `--tools gemini`).
Claude Code reads `CLAUDE.md`, which imports `@AGENTS.md`. Keep real content in `AGENTS.md`.
