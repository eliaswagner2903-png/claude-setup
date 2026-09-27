# claude-setup

Globale Claude-Code-Umgebung für Cloud-Sitzungen (claude.ai/code):

- `~/.claude/CLAUDE.md` – Arbeitsregeln für jedes Projekt
- 5 Subagents: `researcher`, `frontend`, `backend`, `tester`, `reviewer`
- Hooks: formatieren/linten mit Projektwerkzeugen, Secret-Schutz, Audit bei Dependency-Änderungen,
  Diff vor Commit/Push, Rückfrage bei riskanten Befehlen, optionaler Schnelltest (`.claude/quick-test`)
- MCPs: Playwright, Chrome DevTools (lokal, feste Versionen), Context7 (wenn erreichbar)

Enthält keine Secrets. Das Skript ist idempotent und ersetzt nur seine eigenen Einträge.

## Einrichtung

In den Einstellungen der Cloud-Umgebung (im Browser: Umgebung → Bearbeiten → **Setup script**) genau diese Zeile:

```bash
curl -fsSL https://raw.githubusercontent.com/eliaswagner2903-png/claude-setup/main/claude-global-setup.sh | bash
```

Neue Sitzungen laden damit immer den aktuellen Stand dieses Repositorys. Kontrolle in einer Sitzung: `/agents`, `/mcp`,
Protokoll unter `~/.claude/global-setup.log`.
