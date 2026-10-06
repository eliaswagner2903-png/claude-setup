#!/usr/bin/env bash
# Global Claude Code environment: rules, 5 subagents, hooks, MCPs (Playwright, Chrome DevTools, optional Context7).
# Idempotent: can be run repeatedly, replaces only its own entries, leaves other settings untouched.
# Usage: store as the setup script of the cloud environment OR run once locally: bash claude-global-setup.sh
set -u
Z="$HOME/.claude"; LOG="$Z/global-setup.log"
mkdir -p "$Z/agents" "$Z/hooks"
exec > >(tee "$LOG") 2>&1
echo "== Claude global setup $(date -Iseconds)"

# Back up a foreign CLAUDE.md (one that carries neither our current nor our former German heading)
if [ -f "$Z/CLAUDE.md" ] && ! grep -q -e "Global working rules (apply in every project)" -e "Globale Arbeitsregeln (gelten in jedem Projekt)" "$Z/CLAUDE.md"; then
  cp "$Z/CLAUDE.md" "$Z/CLAUDE.md.vorher-$(date +%Y%m%d%H%M%S)"; echo "Existing CLAUDE.md backed up."
fi

cat > "$Z/CLAUDE.md" <<'CLAUDE_SETUP_ENDE'
# Global working rules (apply in every project)

Project rules (`CLAUDE.md` in the repository) take precedence; this file complements them. The user writes German –
answer in German, unless the project specifies otherwise.

## Way of working

1. **Understand first, then change.** Read the relevant code, conventions and existing tests before changing anything.
2. **Respect the existing architecture.** Adopt the project's patterns, folder structure, naming and style.
3. **Small changes.** Only what the task needs. No drive-by cleanups, no speculative abstractions.
4. **No unnecessary dependencies.** Prefer existing libraries and platform features. Add a new dependency only with a
   real reason – and state that reason.
5. **When unsure, research** (subagent `researcher`) instead of guessing from memory – especially for versions, APIs
   and configuration that change quickly.
6. **Larger tasks: a short plan first** (goal, affected files, steps, risks), then implement.
7. **Test after changes** – using the project's own commands (tests, linter, type check, build). For UI changes, look
   at the result in the browser. Explicitly say what could not be tested.
8. **Stay traceable:** meaningful commit messages, no hidden side changes.
9. **Summarize briefly at the end:** what was changed, what was tested (with result), what is still open.

## Security

- **No secrets** (API keys, tokens, passwords, private keys) in code, commits, logs or output. Never print values
  from `.env` or similar; name only the variable names.
- **No destructive actions without asking first:** deleting files/branches, `git reset --hard`, force-push,
  `rm -rf`, database drops, removing/downgrading dependencies, changes to CI/CD or shared infrastructure.
- Only change files inside the project, unless the user explicitly asks for something else.
- Validate input at system boundaries; no code that is vulnerable to SQL/shell/HTML injection.

## Subagents – when they are worth it

Decide for yourself. Handle trivial tasks (one file, clear fix, short question) **without** a subagent.

| Agent | Use when … |
|---|---|
| `researcher` | current/uncertain information is needed: library versions, API changes, docs, best practices |
| `frontend` | the task is mainly UI: components, styling, responsive design, accessibility |
| `backend` | server, API, database, auth, server logic or error handling is involved |
| `tester` | an application or feature should be tested systematically (browser flows, forms, responsive) |
| `reviewer` | a larger change seems finished – have it checked independently **before** calling it "done" |
| `videograf` | a website should be shown as a short video for a customer (scroll-through of all features, computer + phone) |

Independent subtasks may go to subagents in parallel. Check subagent results, don't adopt them blindly.

## Tools

- **Playwright MCP** (`playwright`) for browser tests and end-to-end flows; **Chrome DevTools MCP**
  (`chrome-devtools`) for performance traces, network and console. Both run locally with the preinstalled
  Chromium. Always test pages locally through an HTTP server, not via `file://`.
- **GitHub** via the provided `mcp__github__*` tools (issues, PRs, workflows).
- **Context7** (if set up) for current library documentation.

## Hooks (automatic, do not bypass)

After edits, a hook formats and lints the changed file using the **project's** tools; fix any reported lint errors.
Changes to dependency files trigger an audit notice. Before `git commit`/`git push` the diff is shown as context and
checked for secrets; risky git commands require confirmation.
Quick tests run at the end of a response only if the project defines them via `.claude/quick-test`.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/backend.md" <<'CLAUDE_SETUP_ENDE'
---
name: backend
description: Backend implementation – APIs, databases, authentication, server logic, error handling, security, architecture. Use when server code, endpoints, data models, migrations or auth are involved.
tools: Read, Edit, Write, Grep, Glob, Bash
model: sonnet
---

You are an experienced backend developer.

Principles:
- Respect the project's architecture and layers (routing → validation → service/logic → data access).
- **Validate input at the boundary** (schema validation with the library the project already uses).
- **Security:** parameterized queries, no secrets in code (environment variables), passwords only with established
  hashing schemes, check authorization on **every** access (not just authentication), secure cookies/tokens,
  no sensitive data in logs or error messages, consider rate limits for login/expensive endpoints.
- **Error handling:** expected errors with fitting status codes and clear messages; log unexpected errors
  (without secrets) and answer generically. No empty `catch` blocks.
- **Database:** migrations instead of manual schema changes, transactions for related writes,
  indexes for frequent queries, avoid N+1 queries. **Never** run destructive migrations or delete data without
  explicit approval.
- No new dependencies without justification.

After implementing: run existing tests, add suitable tests for new logic (in the project's style),
verify endpoints with a real call if a server can be started locally.

Report back to the main agent: changed files, API/schema changes, security considerations, test result, open
points (e.g. required environment variables – names only, never values).
CLAUDE_SETUP_ENDE

cat > "$Z/agents/frontend.md" <<'CLAUDE_SETUP_ENDE'
---
name: frontend
description: Frontend implementation – React, Next.js, HTML/CSS, Tailwind, responsive design, accessibility, UI/UX. Use when the task is mainly about components, styling, layout or interaction in the browser.
tools: Read, Edit, Write, Grep, Glob, Bash, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_click, mcp__playwright__browser_console_messages
model: sonnet
---

You are an experienced frontend developer.

Principles:
- Use the project's existing framework, component library, design tokens and styling approach
  (Tailwind **or** CSS modules **or** custom CSS – never mix what the project does not mix).
- Keep components small, clearly named, typed (if TypeScript), without unnecessary state. In Next.js, choose
  server vs. client components deliberately (`"use client"` only where needed).
- **Mobile first:** 320–1920 px without horizontal scrolling, tap targets ≥ 44 px, text ≥ 16 px.
- **Accessibility:** semantic HTML, labels for form fields, visible focus, keyboard operation,
  alt texts, WCAG AA contrast, respect `prefers-reduced-motion`.
- Performance: images with dimensions and suitable formats, never lazy-load the LCP element, no layout shifts,
  animate only with `transform`/`opacity`.
- No new UI libraries without checking with the main agent first.

After implementing: run the project's linter/type check/build and look at the change in the browser (Playwright, local
server) at phone and desktop width.

Report back to the main agent: changed files, brief rationale, what was checked (widths, keyboard, console),
open points.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/researcher.md" <<'CLAUDE_SETUP_ENDE'
---
name: researcher
description: Technical research with current sources. Use when library/API versions, current documentation, breaking changes, best practices or tool comparisons are needed – or when knowledge may be outdated. Delivers compact, sourced results.
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, mcp__context7__resolve-library-id, mcp__context7__query-docs
model: sonnet
---

You are a research specialist. You do not change any project code.

Approach:
1. Sharpen the question: what exactly does the main agent need to know to continue?
2. First check the project for the versions actually in use (`package.json`, lockfiles,
   `requirements*.txt`, `pyproject.toml`, `go.mod` …) – answers must fit **those** versions.
3. Sources in this order: official documentation (Context7, if available), official repository
   (changelog, releases, migration guides), package registry (`npm view <package> version`, `pip index versions`),
   then reputable secondary sources. Report blocked sites, don't guess.
4. Actively rule out outdated information: check the publication date and version relevance of every source.
5. Invent nothing. Mark anything that cannot be substantiated as "unconfirmed".

Answer format (compact, max. ~300 words unless more is explicitly requested):
- **Result:** the direct answer in 1–3 sentences
- **Details:** only what is necessary (code snippets, configuration, commands)
- **Versions:** what the statement refers to
- **Sources:** URL or documentation location for each statement (or "local: <file>")
- **Uncertain/open:** if applicable
CLAUDE_SETUP_ENDE

cat > "$Z/agents/reviewer.md" <<'CLAUDE_SETUP_ENDE'
---
name: reviewer
description: Independent code review – finds bugs, security problems, unnecessary complexity, performance problems and poor architecture, and delivers concrete improvements. Use before larger changes count as complete, or on request for a diff/branch/PR.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are an experienced, independent reviewer. You change **no code** – you review and report.
You know the author's intent only from the assignment and the code; check whether the code really does what it should.

Approach:
1. Determine the scope: `git status`, `git diff` (or `git diff <base>...HEAD`), read the affected files completely,
   find callers of the changed functions.
2. Check, in this priority:
   1. **Correctness:** logic errors, edge cases (empty, null, very large, concurrent), error paths, off-by-one,
      race conditions, wrong assumptions about input
   2. **Security:** injection (SQL/shell/HTML/XSS), missing authorization, secrets in code/logs, unsafe
      deserialization, SSRF, path traversal, unsafe defaults, vulnerable dependencies
   3. **Performance:** unnecessary loops/queries (N+1), missing indexes, large bundles, blocking calls,
      memory leaks
   4. **Architecture & maintainability:** violation of existing patterns, duplicated logic, unnecessary abstraction or
      complexity, unclear names, missing tests for new logic
3. **Verify** every finding (read the code, run a small test/command if needed). No guesses presented as facts.

Report to the main agent, sorted by severity:
- `[CRITICAL|HIGH|MEDIUM|LOW] file:line – problem` · **Scenario:** concrete input → wrong result ·
  **Suggestion:** concrete change (short code snippet if helpful)
- At the end: **Overall verdict** (ready / ready after fixes / not ready) and what is well solved (1–2 sentences).
No style nitpicks that a formatter/linter handles anyway.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/tester.md" <<'CLAUDE_SETUP_ENDE'
---
name: tester
description: Systematic testing of applications and features – browser flows, forms, navigation, responsive behavior, error cases, regressions; uses Playwright. Use when a feature or application should be checked before it counts as done.
tools: Read, Grep, Glob, Bash, Write, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_fill_form, mcp__playwright__browser_select_option, mcp__playwright__browser_press_key, mcp__playwright__browser_hover, mcp__playwright__browser_wait_for, mcp__playwright__browser_evaluate, mcp__playwright__browser_console_messages, mcp__playwright__browser_network_requests, mcp__playwright__browser_navigate_back, mcp__playwright__browser_tabs, mcp__playwright__browser_close, mcp__chrome-devtools__new_page, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__lighthouse_audit, mcp__chrome-devtools__performance_start_trace, mcp__chrome-devtools__performance_analyze_insight, mcp__chrome-devtools__performance_stop_trace, mcp__chrome-devtools__list_console_messages, mcp__chrome-devtools__list_network_requests
model: sonnet
---

You are a thorough QA engineer. You change **no application code** – you find and document defects.
You may create test files if the main agent wants that.

Approach:
1. Understand what is to be tested and how the application starts locally (README, `package.json` scripts).
   Start the application or a static server in the background; never test via `file://`.
2. Run existing automated tests (unit/E2E) and note the result.
3. Check manually with Playwright (MCP or script):
   - **Main flows** step by step (navigation, links, back button, deep links)
   - **Forms:** valid input, empty required fields, invalid formats, very long input, special characters,
     double-click on submit
   - **Responsive:** 320, 390, 768, 1440 px – no horizontal scrolling, nothing overlaps, menu usable
   - **Keyboard:** tab order, visible focus, Escape closes dialogs
   - **Error cases:** 404, network errors/server errors, empty states
   - **Console and network:** JavaScript errors, failed requests
4. Regressions: also briefly check adjacent areas that were not directly changed.
5. Stop started processes at the end (specifically by PID, never `pkill -f` on general patterns).

Report to the main agent:
- **Result:** passed / defects found (count)
- **Defects:** for each defect steps to reproduce, expected vs. actual, width/browser, screenshot path
- **Checked without findings:** short list
- **Not testable:** with reason
CLAUDE_SETUP_ENDE

cat > "$Z/agents/videograf.md" <<'CLAUDE_SETUP_ENDE'
---
name: videograf
description: Records a short customer walkthrough video of a website (scroll-through showing every feature), for computer and phone, with intro/outro cards. Use whenever a video, screen recording or film of a site or a feature is wanted.
tools: Read, Grep, Glob, Bash, Write
model: sonnet
---

You record website walkthrough videos for **customers**, not for internal checking. The video must look as if a
person thought about what to show and for how long. You change no website code.

## Rules

1. **About 1 minute per video** (page part ~45 s plus intro and outro card). Never two minutes.
2. **Every section is seen and every unique feature is shown.** Before recording, list the sections and unique
   features from the HTML/JS (menu, tabs, gallery, lightbox, selectors, forms, quick bar, opening hours …) and tick
   each one off afterwards on the contact sheet. Nothing may be scrolled past without a short stop.
3. **Repeated features are shown 2-3 times, never all of them** (3 of 7 tabs, 3 of 8 team members).
4. **Never make the site look worse than it is.** Wait for animations that are the feature; do not cut them off.
5. **Order:** hero with its load animation (~2.5 s), then the menu briefly, then scroll quickly, then the
   signature interaction early, then the remaining features top to bottom, then back to the top.
6. **Pace:** scroll moves 0.9-1.1 s with ease-in-out, 1-1.5 s dwell per feature, ~1.2 s after an interaction.
7. **Two videos:** computer (record 1440x900 with mouse, export 1280x800) and phone (record 390x844 with
   `isMobile`, `hasTouch`, `tap()`, export 586x1268). Mouse-only effects only in the computer video.
8. **Visible pointer:** inject a mouse pointer (computer) or a touch ring (phone) via `addInitScript` so clicks
   read as human actions. Before a key action, let the pointer rest ~1.2 s on its target.
9. **Controls and their effect stay in frame together** (tabs plus the list they change).
10. **Mark it as a draft:** intro card, a slim band under the video, outro card, with the customer's name.
    File names `<Name> Website - Computer.mp4` and `<Name> Website - Handy.mp4`.
11. Customer-facing text is German. Reduced motion stays off.

## Technique

- Serve the site over HTTP (`python3 -m http.server 8765` in the site folder), never `file://`.
- Playwright from Node: `require('/opt/node22/lib/node_modules/playwright')`,
  `executablePath: '/opt/pw-browsers/chromium'`, `recordVideo: {dir, size}` = viewport, `deviceScaleFactor: 1`.
- Desktop clicks: `mouse.move(x, y, {steps})` then `mouse.click(x, y)`. `element.click()` scrolls the element into
  view itself and makes the page jump.
- `addInitScript` sets `scroll-behavior: auto` for the recording, so scripted scrolls land exactly.
- Every click/tap gets `{noWaitAfter: true, timeout: 2500}` inside try/catch.
- Cut the first ~0.8 s of each recording (white frame while the page loads).
- Export: H.264 `-profile:v main -level 4.0 -pix_fmt yuv420p`, even sizes, `-movflags +faststart`, 30 fps, no
  audio, about 4-5 MB.
- Hover effects that follow the pointer (a light in a menu bar) look wrong on film; leave such sweeps out.
- Never `pkill -f` a pattern that also matches your own command line.

## Checking before delivery

Build a timestamped contact sheet every 1.5 s
(`ffmpeg -i v.mp4 -vf "fps=1/1.5,scale=300:-1,drawtext=text='%{pts\:hms}':fontcolor=red:box=1,tile=6x8" -frames:v 1 s.png`),
look at it, and tick off every section and feature. Check that the first frame is not white.

## Report to the main agent

Paths of both videos, length, the list of features shown, anything that could not be recorded and why.
In this project the toolkit and the full notes live in `/mnt/project-files/werkzeuge/video/README.md`
(scripts `record-example-hairstyle.js`, `cards.js`, `cut.sh`) - read it first and reuse the scripts.
CLAUDE_SETUP_ENDE

cat > "$Z/hooks/gemeinsam.py" <<'CLAUDE_SETUP_ENDE'
"""Shared helpers for the global Claude Code hooks. No dependencies beyond the standard library."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ZUSTAND = Path(tempfile.gettempdir()) / "claude-hooks"
IGNORIERT = {"node_modules", ".git", "dist", "build", ".next", "out", "coverage", "vendor", ".venv", "venv", "__pycache__", ".turbo", ".cache"}

SECRET_MUSTER = [
    ("AWS Access Key", r"\bAKIA[0-9A-Z]{16}\b"),
    ("GitHub token", r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{50,}\b"),
    ("Anthropic key", r"\bsk-ant-[A-Za-z0-9_\-]{20,}"),
    ("OpenAI key", r"\bsk-(?:proj-)?[A-Za-z0-9]{32,}\b"),
    ("Stripe Live Key", r"\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b"),
    ("Slack token", r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    ("Google API Key", r"\bAIza[0-9A-Za-z_\-]{35}\b"),
    ("Private key", r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY-----"),
]


def eingabe():
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def projekt(daten):
    p = os.environ.get("CLAUDE_PROJECT_DIR") or daten.get("cwd") or os.getcwd()
    return Path(p).resolve()


def im_projekt(datei, wurzel):
    try:
        Path(datei).resolve().relative_to(wurzel)
        return True
    except (ValueError, OSError):
        return False


def ignoriert(datei, wurzel):
    try:
        teile = Path(datei).resolve().relative_to(wurzel).parts
    except ValueError:
        return True
    return any(t in IGNORIERT for t in teile)


def secrets_finden(text):
    """Returns only the kinds of secrets found – never the values."""
    return sorted({name for name, m in SECRET_MUSTER if re.search(m, text or "")})


def schwaerzen(text):
    for _, m in SECRET_MUSTER:
        text = re.sub(m, "[REDACTED]", text)
    return text


def kuerzen(text, zeilen=40):
    z = schwaerzen(text).strip().splitlines()
    return "\n".join(z[:zeilen] + ([f"… ({len(z) - zeilen} more lines)"] if len(z) > zeilen else []))


def ausfuehren(befehl, cwd, timeout):
    """Runs a command without a shell. Result: (exit code, output) – (None, '') on timeout."""
    try:
        r = subprocess.run(befehl, cwd=cwd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return None, ""
    except (OSError, ValueError):
        return 127, ""


def werkzeug(name, paketordner):
    """Prefer the project-local tool, otherwise the globally installed one."""
    lokal = paketordner / "node_modules" / ".bin" / name
    if lokal.exists():
        return str(lokal)
    return shutil.which(name)


def paketordner(datei, wurzel, marker=("package.json",)):
    d = Path(datei).resolve().parent
    while True:
        if any((d / m).exists() for m in marker):
            return d
        if d == wurzel or d == d.parent:
            return None
        d = d.parent


def schluessel(wurzel):
    return hashlib.sha1(str(wurzel).encode()).hexdigest()[:12]


def zustand(wurzel, name):
    ZUSTAND.mkdir(parents=True, exist_ok=True)
    return ZUSTAND / f"{schluessel(wurzel)}.{name}"


def kontext(ereignis, text):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": ereignis, "additionalContext": text}}, ensure_ascii=False))
CLAUDE_SETUP_ENDE

cat > "$Z/hooks/nach_bearbeitung.py" <<'CLAUDE_SETUP_ENDE'
#!/usr/bin/env python3
"""PostToolUse (Edit|Write|MultiEdit): formats and lints the changed file with the PROJECT'S tools,
reports dependency changes with an audit and records that code has changed (for the quick test).

Robust: only files in the project, only configured tools, short timeouts, output truncated and redacted,
at most 3 consecutive lint reports per file (no endless loop)."""
import hashlib
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemeinsam import (ausfuehren, eingabe, ignoriert, im_projekt, kontext, kuerzen, paketordner, projekt,  # noqa: E402
                       werkzeug, zustand)

CODE = {".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts", ".vue", ".svelte", ".astro"}
PRETTIER = CODE | {".css", ".scss", ".less", ".html", ".htm", ".json", ".md", ".mdx", ".yaml", ".yml", ".graphql"}
PY = {".py"}
DEPS = {"package.json", "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb",
        "requirements.txt", "requirements-dev.txt", "pyproject.toml", "poetry.lock", "Pipfile", "Pipfile.lock",
        "uv.lock", "go.mod", "go.sum", "Cargo.toml", "Cargo.lock", "Gemfile", "Gemfile.lock", "composer.json"}
SENSIBEL = re.compile(r"(^|/)(\.env(\..+)?|.*\.pem|.*\.key|docker-compose.*\.ya?ml|Dockerfile|\.github/workflows/.+|"
                      r"next\.config\.[cm]?[jt]s|vite\.config\.[cm]?[jt]s|\.npmrc|nginx.*\.conf|firebase\.json|vercel\.json)$")


def prettier_konfiguriert(pkg):
    if any(pkg.glob(".prettierrc*")) or any(pkg.glob("prettier.config.*")):
        return True
    try:
        d = json.loads((pkg / "package.json").read_text(encoding="utf-8"))
    except Exception:
        return False
    return "prettier" in d or "prettier" in {**d.get("dependencies", {}), **d.get("devDependencies", {})}


def eslint_konfiguriert(pkg):
    if any(pkg.glob("eslint.config.*")) or any(pkg.glob(".eslintrc*")):
        return True
    pj = pkg / "package.json"
    return pj.exists() and '"eslintConfig"' in pj.read_text(encoding="utf-8", errors="ignore")


def eslint_meldungen(ausgabe):
    """Convert ESLint's JSON output (core format, stable across versions) into short lines."""
    start = ausgabe.find("[{\"filePath\"")
    try:
        daten = json.JSONDecoder().raw_decode(ausgabe[start:])[0] if start >= 0 else []
    except ValueError:
        return []
    return [f"{m.get('line', '?')}:{m.get('column', '?')} {'Error' if m.get('severity') == 2 else 'Warning'} "
            f"{m.get('message', '')} ({m.get('ruleId') or 'parser'})"
            for d in daten for m in d.get("messages", [])]


def pyproject_hat(pkg, abschnitt):
    p = pkg / "pyproject.toml"
    return p.exists() and f"[tool.{abschnitt}" in p.read_text(encoding="utf-8", errors="ignore")


def main():
    daten = eingabe()
    wurzel = projekt(daten)
    datei = (daten.get("tool_input") or {}).get("file_path") or ""
    if not datei or not Path(datei).is_file() or not im_projekt(datei, wurzel) or ignoriert(datei, wurzel):
        return 0
    pfad = Path(datei).resolve()
    rel = pfad.relative_to(wurzel).as_posix()
    endung = pfad.suffix.lower()
    hinweise, fehler = [], []

    if endung in PRETTIER | PY:
        zustand(wurzel, "geaendert").touch()

    # ---- Formatters and linters (only if the project has configured them)
    pkg = paketordner(pfad, wurzel)
    if pkg and endung in PRETTIER and prettier_konfiguriert(pkg):
        p = werkzeug("prettier", pkg)
        if p:
            code, out = ausfuehren([p, "--write", "--log-level", "warn", str(pfad)], pkg, 20)
            if code not in (0, None):
                hinweise.append(f"Prettier could not format {rel}:\n{kuerzen(out, 10)}")
    if pkg and endung in CODE and eslint_konfiguriert(pkg):
        e = werkzeug("eslint", pkg)
        if e:
            code, out = ausfuehren([e, "--no-warn-ignored", "--format", "json", str(pfad)], pkg, 40)
            meldungen = eslint_meldungen(out)
            if code == 1 and meldungen:
                fehler.append(f"ESLint reports problems in {rel}:\n{kuerzen(chr(10).join(meldungen))}")
            elif code not in (0, 1, None):
                hinweise.append(f"ESLint could not check {rel} (configuration error?):\n{kuerzen(out, 8)}")
    pypkg = paketordner(pfad, wurzel, ("pyproject.toml", "ruff.toml", ".ruff.toml", "setup.cfg"))
    if pypkg and endung in PY:
        ruff_cfg = (pypkg / "ruff.toml").exists() or (pypkg / ".ruff.toml").exists() or pyproject_hat(pypkg, "ruff")
        ruff = werkzeug("ruff", pypkg) if ruff_cfg else None
        if ruff:
            ausfuehren([ruff, "format", str(pfad)], pypkg, 20)
            code, out = ausfuehren([ruff, "check", "--output-format", "concise", str(pfad)], pypkg, 30)
            if code == 1 and out.strip():
                fehler.append(f"Ruff reports problems in {rel}:\n{kuerzen(out)}")
        elif pyproject_hat(pypkg, "black") and werkzeug("black", pypkg):
            ausfuehren([werkzeug("black", pypkg), "-q", str(pfad)], pypkg, 20)

    # ---- Security: dependencies and sensitive configuration
    if pfad.name in DEPS:
        sperre = zustand(wurzel, "audit")
        if not sperre.exists() or time.time() - sperre.stat().st_mtime > 600:   # at most every 10 minutes
            sperre.touch()
            ordner = pfad.parent
            if (ordner / "package-lock.json").exists() and werkzeug("npm", ordner):
                code, out = ausfuehren(["npm", "audit", "--audit-level=high", "--omit=dev", "--json"], ordner, 60)
                try:
                    v = json.loads(out).get("metadata", {}).get("vulnerabilities", {})
                    zahl = {k: v.get(k, 0) for k in ("critical", "high", "moderate")}
                    hinweise.append(f"npm audit after change to {rel}: critical {zahl['critical']}, high {zahl['high']}, "
                                    f"moderate {zahl['moderate']}." + (" Please review before the change counts as done."
                                                                       if zahl["critical"] or zahl["high"] else ""))
                except Exception:
                    hinweise.append(f"{rel} changed: npm audit could not be evaluated (offline?). Check new packages for trustworthiness.")
            elif werkzeug("pip-audit", ordner) and pfad.name.startswith("requirements"):
                code, out = ausfuehren(["pip-audit", "-r", str(pfad), "--progress-spinner", "off"], ordner, 90)
                hinweise.append(f"pip-audit for {rel}:\n{kuerzen(out, 15)}")
            else:
                hinweise.append(f"Dependency file {rel} changed: check new packages for origin, maintenance and known vulnerabilities.")
    if SENSIBEL.search(rel):
        hinweise.append(f"Security-relevant file {rel} changed: do not enter/print secrets, "
                        "`.env*` must be listed in .gitignore, choose permissions and defaults deliberately.")

    # ---- Feedback (report lint errors back at most 3 times in a row per file)
    zaehler = zustand(wurzel, "lint-" + hashlib.sha1(rel.encode()).hexdigest()[:10])
    if fehler:
        n = int(zaehler.read_text() or 0) + 1 if zaehler.exists() else 1
        zaehler.write_text(str(n))
        if n <= 3:
            print("\n\n".join(fehler + hinweise), file=sys.stderr)
            return 2
        hinweise.append(f"Lint problems in {rel} persist (no longer blocking after 3 reports).")
    elif zaehler.exists():
        zaehler.unlink()
    if hinweise:
        kontext("PostToolUse", "\n\n".join(hinweise))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:   # a hook error must never block the work
        print(f"Hook nach_bearbeitung: internal error ({type(e).__name__}) – skipped", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/nach_bearbeitung.py"

cat > "$Z/hooks/schnelltest.py" <<'CLAUDE_SETUP_ENDE'
#!/usr/bin/env python3
"""Stop: runs a QUICK test at the end of a response – only if
  1. the project defines it in `.claude/quick-test` (first non-empty line = command, e.g. `npm run test:quick`),
  2. code has changed since the last run (marker from the nach_bearbeitung hook) and
  3. this stop was not already triggered by a hook (stop_hook_active → no endless loop).
Time limit: optional second line `timeout=90` (default 120 s, at most 300 s). If the test fails, Claude gets the
truncated output back and keeps working; the next stop does not block again."""
import re
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemeinsam import ausfuehren, eingabe, kuerzen, projekt, zustand  # noqa: E402


def main():
    daten = eingabe()
    if daten.get("stop_hook_active"):
        return 0
    wurzel = projekt(daten)
    datei = wurzel / ".claude" / "quick-test"
    markierung = zustand(wurzel, "geaendert")
    if not datei.is_file() or not markierung.exists():
        return 0
    markierung.unlink()   # remove before the run: a failure never triggers more than one report
    zeilen = [z.strip() for z in datei.read_text(encoding="utf-8").splitlines() if z.strip() and not z.startswith("#")]
    if not zeilen:
        return 0
    timeout = 120
    for z in zeilen[1:]:
        m = re.match(r"timeout\s*=\s*(\d+)", z)
        if m:
            timeout = min(int(m.group(1)), 300)
    code, out = ausfuehren(shlex.split(zeilen[0]), wurzel, timeout)
    if code is None:
        print(f"Quick test `{zeilen[0]}` aborted after {timeout} s – too slow for the Stop hook; "
              "enter a faster command in .claude/quick-test.", file=sys.stderr)
        return 0
    if code != 0:
        print(f"Quick test `{zeilen[0]}` failed (exit {code}):\n{kuerzen(out, 50)}\n\n"
              "Please fix the cause or explain to the user why the test fails.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Hook schnelltest: internal error ({type(e).__name__}) – skipped", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/schnelltest.py"

cat > "$Z/hooks/vor_werkzeug.py" <<'CLAUDE_SETUP_ENDE'
#!/usr/bin/env python3
"""PreToolUse:
- Edit|Write|MultiEdit: prevents secrets from being written into project files (except .env files).
- Bash: risky commands (force-push, reset --hard, clean -f, rm -rf on broad paths, DROP …) → confirmation prompt;
        before git commit / git push, shows the diff as context and checks staged changes for secrets.
Never prints secret values. Never blocks on internal errors."""
import json
import os
import re
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemeinsam import ausfuehren, eingabe, kuerzen, projekt, secrets_finden  # noqa: E402

# git with global options in front (git -C dir …, git -c key=val …, git --no-pager …)
GIT = r"\bgit(?:\s+-[Cc]\s+\S+|\s+--[a-z-]+(?:=\S+)?)*\s+"

RISKANT = [
    (GIT + r"push\b[^|;&]*\s(--force(?!-with-lease)\b|-f\b|--force-with-lease\b|\+\S+)", "force-push overwrites remote history"),
    (GIT + r"reset\s+[^|;&]*--hard\b", "git reset --hard discards local changes"),
    (GIT + r"clean\s+[^|;&]*-[a-zA-Z]*f", "git clean deletes untracked files"),
    (GIT + r"branch\s+[^|;&]*-D\b", "branch is deleted without a merge check"),
    (GIT + r"(checkout|restore)\s+(--\s+)?\.(\s|$)", "discards all local changes"),
    (GIT + r"stash\s+(drop|clear)\b", "deletes stashed changes"),
    (r"\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR])[a-zA-Z]*\s+(/|~|\$HOME|\.\.|\*|\.)(\s|/?$|/\*)", "rm -rf on a broad path"),
    (r"\b(DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE)\b", "deletes database contents"),
    (r"\b(prisma\s+migrate\s+reset|rails\s+db:drop|dropdb)\b", "resets the database"),
    (r"\bnpm\s+(uninstall|remove|rm)\b|\bpip\s+uninstall\b", "removes dependencies"),
]


def entscheidung(art, grund, kontext=None):
    aus = {"hookEventName": "PreToolUse"}
    if art:
        aus["permissionDecision"] = art
        aus["permissionDecisionReason"] = grund
    if kontext:
        aus["additionalContext"] = kontext
    print(json.dumps({"hookSpecificOutput": aus}, ensure_ascii=False))


def ist_env_datei(pfad):
    n = Path(pfad).name
    return n.startswith(".env") and not n.endswith((".example", ".sample", ".template", ".dist"))


def bearbeitung(daten):
    ti = daten.get("tool_input") or {}
    pfad = ti.get("file_path") or ""
    if ist_env_datei(pfad):
        return
    text = "\n".join(filter(None, [ti.get("content"), ti.get("new_string")] +
                            [e.get("new_string") for e in ti.get("edits") or [] if isinstance(e, dict)]))
    arten = secrets_finden(text)
    if arten:
        entscheidung("deny", f"Blocked: the new content for {Path(pfad).name} probably contains a secret "
                             f"({', '.join(arten)}). Secrets belong in environment variables or an .env file that is listed in "
                             ".gitignore – use only the variable name in code.")


def git_ordner(cmd, standard):
    """Repo of the command: `git -C X …` or a leading `cd X &&`, otherwise the project; None if not a git repo."""
    m = re.search(r"\bgit\s+-C\s+(\"[^\"]+\"|'[^']+'|\S+)", cmd) or re.match(r"\s*cd\s+(\"[^\"]+\"|'[^']+'|[^\s;&|]+)", cmd)
    ordner = Path(os.path.expanduser(m.group(1).strip("\"'"))) if m else standard
    if not ordner.is_absolute():
        ordner = standard / ordner
    code, _ = ausfuehren(["git", "rev-parse", "--show-toplevel"], ordner, 5)
    return ordner if code == 0 else None


def befehl(daten):
    cmd = (daten.get("tool_input") or {}).get("command") or ""
    for muster, grund in RISKANT:
        if re.search(muster, cmd, re.IGNORECASE):
            entscheidung("ask", f"Risky command: {grund}. Please confirm.")
            return
    if not re.search(GIT + r"(commit|push)\b", cmd):
        return
    wurzel = git_ordner(cmd, projekt(daten))
    if wurzel is None:
        return  # no git repo recognizable: better to stay silent than to dump git help text into the context
    ist_commit = re.search(GIT + r"commit\b", cmd)
    teile = []
    if ist_commit:
        alle = bool(re.search(r"\s-[a-zA-Z]*a[a-zA-Z]*\b|--all\b", cmd))
        diff_cmd = ["git", "diff", "HEAD" if alle else "--cached"]
        _, stat = ausfuehren(diff_cmd + ["--stat"], wurzel, 10)
        _, voll = ausfuehren(diff_cmd + ["--unified=0"], wurzel, 15)
        neu = "\n".join(z[1:] for z in voll.splitlines() if z.startswith("+") and not z.startswith("+++"))
        arten = secrets_finden(neu)
        if arten:
            entscheidung("deny", f"Commit blocked: the changes probably contain a secret ({', '.join(arten)}). "
                                 "Check the file(s) with `git diff --cached`, remove the secret and move it into an environment "
                                 "variable. Do not print values.")
            return
        teile.append("Before the commit – scope of the changes:\n" + (kuerzen(stat, 30) or "(nothing staged)"))
    else:
        _, stat = ausfuehren(["git", "diff", "--stat", "@{upstream}...HEAD"], wurzel, 10)
        _, log = ausfuehren(["git", "log", "--oneline", "@{upstream}..HEAD"], wurzel, 10)
        if "fatal" in log or "fatal" in stat:
            _, log = ausfuehren(["git", "log", "--oneline", "-5"], wurzel, 10)
            stat = "(no upstream – new branch; see latest commits above)"
        teile.append("Before the push – commits:\n" + kuerzen(log, 15) + "\n\nChanged files:\n" + kuerzen(stat, 30))
    teile.append("Check that only intended files are included (no .env, build artifacts, large binary files).")
    entscheidung(None, None, "\n".join(teile))


def main():
    daten = eingabe()
    werkzeug = daten.get("tool_name", "")
    if werkzeug in ("Edit", "Write", "MultiEdit"):
        bearbeitung(daten)
    elif werkzeug == "Bash":
        befehl(daten)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Hook vor_werkzeug: internal error ({type(e).__name__}) – skipped", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/vor_werkzeug.py"

# ---- Merge settings.json (replace only our own hook entries)
python3 - "$Z/settings.json" <<'CLAUDE_SETUP_ENDE'
import json, sys, os
pfad = sys.argv[1]
eigene = json.loads(r'''{
  "PreToolUse": [
    { "matcher": "Edit|Write|MultiEdit|Bash",
      "hooks": [ { "type": "command", "command": "python3 ~/.claude/hooks/vor_werkzeug.py", "timeout": 25 } ] }
  ],
  "PostToolUse": [
    { "matcher": "Edit|Write|MultiEdit",
      "hooks": [ { "type": "command", "command": "python3 ~/.claude/hooks/nach_bearbeitung.py", "timeout": 100 } ] }
  ],
  "Stop": [
    { "hooks": [ { "type": "command", "command": "python3 ~/.claude/hooks/schnelltest.py", "timeout": 310 } ] }
  ]
}
''')
try:
    s = json.load(open(pfad))
except Exception:
    s = {}
s.setdefault("$schema", "https://json.schemastore.org/claude-code-settings.json")
h = s.setdefault("hooks", {})
for ereignis, eintraege in eigene.items():
    alt = [e for e in h.get(ereignis, []) if not any("/.claude/hooks/" in x.get("command", "") for x in e.get("hooks", []))]
    h[ereignis] = alt + eintraege
json.dump(s, open(pfad, "w"), indent=2, ensure_ascii=False)
print("settings.json: hooks registered")
CLAUDE_SETUP_ENDE

# ---- MCP servers (user level). Only locally running, trusted servers; pinned versions.
CHROME=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux*/chrome 2>/dev/null | head -1)
[ -z "$CHROME" ] && CHROME=$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)
mcp() {  # name json
  if command -v claude >/dev/null 2>&1; then
    claude mcp remove -s user "$1" >/dev/null 2>&1 || true
    claude mcp add-json -s user "$1" "$2" >/dev/null && echo "MCP $1: set up" || echo "MCP $1: ERROR while registering"
  else
    python3 - "$1" "$2" <<'CLAUDE_SETUP_ENDE'
import json, sys, os
p = os.path.expanduser("~/.claude.json")
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("mcpServers", {})[sys.argv[1]] = json.loads(sys.argv[2])
json.dump(d, open(p, "w"), indent=2)
print(f"MCP {sys.argv[1]}: set up (without claude CLI)")
CLAUDE_SETUP_ENDE
  fi
}
# As root, Chromium starts only without a sandbox (cloud containers run as root); as a normal user the sandbox stays on.
PW_SB=""; CD_SB=""
if [ "$(id -u)" = "0" ]; then PW_SB=',"--no-sandbox"'; CD_SB=',"--chrome-arg=--no-sandbox"'; fi
if [ -n "$CHROME" ]; then
  mcp playwright "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@playwright/mcp@0.0.82\",\"--headless\",\"--isolated\",\"--executable-path\",\"$CHROME\",\"--output-dir\",\"/tmp/playwright-mcp\"$PW_SB]}"
  mcp chrome-devtools "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"chrome-devtools-mcp@1.10.1\",\"--headless\",\"--isolated\",\"--no-usage-statistics\",\"--executablePath\",\"$CHROME\"$CD_SB]}"
else
  echo "MCP playwright/chrome-devtools: no Chromium found – skipped"
fi
# Context7 only if the service is reachable on the network (otherwise every session would start with an error)
code=$(curl -s -m 8 -o /dev/null -w "%{http_code}" https://mcp.context7.com/mcp 2>/dev/null); code=${code:-000}
if [ "${code:0:3}" != "000" ]; then
  mcp context7 '{"type":"http","url":"https://mcp.context7.com/mcp"}'
else
  command -v claude >/dev/null 2>&1 && claude mcp remove -s user context7 >/dev/null 2>&1
  echo "MCP context7: mcp.context7.com not reachable (network access not allowed) – skipped"
fi
# Pre-warm the npm packages so the first start is fast (errors ignored)
(cd /tmp && timeout 180 npx -y @playwright/mcp@0.0.82 --help >/dev/null 2>&1; timeout 180 npx -y chrome-devtools-mcp@1.10.1 --help >/dev/null 2>&1) || true
python3 -m py_compile "$Z"/hooks/*.py && echo "Hooks: syntax ok"
echo "== done. Agents: $(ls "$Z/agents" | tr '\n' ' ')"
exit 0
