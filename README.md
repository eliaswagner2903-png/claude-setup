# claude-setup

Global Claude Code environment for cloud sessions (claude.ai/code):

- `~/.claude/CLAUDE.md` – working rules for every project
- 5 subagents: `researcher`, `frontend`, `backend`, `tester`, `reviewer` (model sonnet, saves credits compared to Opus)
- Hooks: format/lint with the project's own tools, secret protection, audit on dependency changes,
  diff before commit/push, confirmation prompt for risky commands, optional quick test (`.claude/quick-test`)
- MCPs: Playwright, Chrome DevTools (local, pinned versions), Context7 (if reachable)

Contains no secrets. The script is idempotent and only replaces its own entries.

## Setup

In the cloud environment settings (in the browser: Environment → Edit → **Setup script**) enter exactly this line:

```bash
curl -fsSL https://raw.githubusercontent.com/eliaswagner2903-png/claude-setup/main/claude-global-setup.sh | bash
```

New sessions then always load the current state of this repository. To check inside a session: `/agents`, `/mcp`,
log at `~/.claude/global-setup.log`.
