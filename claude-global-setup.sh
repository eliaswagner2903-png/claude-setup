#!/usr/bin/env bash
# Globale Claude-Code-Umgebung: Regeln, 5 Subagents, Hooks, MCPs (Playwright, Chrome DevTools, optional Context7).
# Idempotent: mehrfach ausführbar, ersetzt nur die eigenen Einträge, lässt fremde Einstellungen unberührt.
# Nutzung: als Setup-Skript der Cloud-Umgebung hinterlegen ODER einmal lokal ausführen: bash claude-global-setup.sh
set -u
Z="$HOME/.claude"; LOG="$Z/global-setup.log"
mkdir -p "$Z/agents" "$Z/hooks"
exec > >(tee "$LOG") 2>&1
echo "== Claude-Global-Setup $(date -Iseconds)"

if [ -f "$Z/CLAUDE.md" ] && ! grep -q "Globale Arbeitsregeln (gelten in jedem Projekt)" "$Z/CLAUDE.md"; then
  cp "$Z/CLAUDE.md" "$Z/CLAUDE.md.vorher-$(date +%Y%m%d%H%M%S)"; echo "Vorhandene CLAUDE.md gesichert."
fi

cat > "$Z/CLAUDE.md" <<'CLAUDE_SETUP_ENDE'
# Globale Arbeitsregeln (gelten in jedem Projekt)

Projektregeln (`CLAUDE.md` im Repository) gehen vor, diese Datei ergänzt sie. Der Nutzer schreibt Deutsch – antworte
auf Deutsch, außer das Projekt schreibt etwas anderes vor.

## Arbeitsweise

1. **Erst verstehen, dann ändern.** Relevanten Code, Konventionen und bestehende Tests lesen, bevor du etwas änderst.
2. **Bestehende Architektur respektieren.** Muster, Ordnerstruktur, Benennung und Stil des Projekts übernehmen.
3. **Kleine Änderungen.** Nur das, was die Aufgabe braucht. Kein Aufräumen nebenbei, keine spekulativen Abstraktionen.
4. **Keine unnötigen Dependencies.** Vorhandene Libraries und Plattformfunktionen bevorzugen. Eine neue Dependency nur
   mit echtem Grund – und dann den Grund nennen.
5. **Bei Unsicherheit recherchieren** (Subagent `researcher`) statt aus dem Gedächtnis zu raten – besonders bei
   Versionen, APIs und Konfiguration, die sich schnell ändern.
6. **Größere Aufgaben: zuerst ein kurzer Plan** (Ziel, betroffene Dateien, Schritte, Risiken), dann umsetzen.
7. **Nach Änderungen testen** – die projekteigenen Befehle (Tests, Linter, Typprüfung, Build). Bei UI-Änderungen im
   Browser ansehen. Was nicht testbar war, ausdrücklich sagen.
8. **Nachvollziehbar bleiben:** sinnvolle Commit-Nachrichten, keine versteckten Nebenänderungen.
9. **Am Ende kurz zusammenfassen:** was geändert wurde, was getestet wurde (mit Ergebnis), was offen ist.

## Sicherheit

- **Keine Secrets** (API-Keys, Tokens, Passwörter, private Schlüssel) in Code, Commits, Logs oder Ausgaben. Werte aus
  `.env` o. Ä. nie ausgeben; nur Variablennamen nennen.
- **Keine destruktiven Aktionen ohne Rückfrage:** Löschen von Dateien/Branches, `git reset --hard`, Force-Push,
  `rm -rf`, Datenbank-Drops, Abhängigkeiten entfernen/downgraden, Änderungen an CI/CD oder geteilter Infrastruktur.
- Nur Dateien innerhalb des Projekts ändern, außer der Nutzer bittet ausdrücklich um anderes.
- Eingaben an Systemgrenzen validieren; kein SQL-/Shell-/HTML-Injection-anfälliger Code.

## Subagents – wann sie sich lohnen

Selbst entscheiden. Triviale Aufgaben (eine Datei, klarer Fix, kurze Frage) **ohne** Subagent erledigen.

| Agent | Einsetzen, wenn … |
|---|---|
| `researcher` | aktuelle/unsichere Informationen nötig sind: Library-Versionen, API-Änderungen, Doku, Best Practices |
| `frontend` | die Aufgabe hauptsächlich UI betrifft: Komponenten, Styling, Responsive, Barrierefreiheit |
| `backend` | Server, API, Datenbank, Auth, Serverlogik oder Fehlerbehandlung betroffen sind |
| `tester` | eine Anwendung oder ein Feature systematisch getestet werden soll (Browserflows, Formulare, Responsive) |
| `reviewer` | eine größere Änderung fertig scheint – **vor** „erledigt“ unabhängig prüfen lassen |

Unabhängige Teilaufgaben dürfen parallel an Subagents gehen. Ergebnisse von Subagents prüfen, nicht blind übernehmen.

## Tools

- **Playwright-MCP** (`playwright`) für Browser-Tests und End-to-End-Flows; **Chrome-DevTools-MCP**
  (`chrome-devtools`) für Performance-Traces, Netzwerk und Konsole. Beide laufen lokal mit dem vorinstallierten
  Chromium. Seiten lokal immer über einen HTTP-Server testen, nicht über `file://`.
- **GitHub** über die bereitgestellten `mcp__github__*`-Tools (Issues, PRs, Workflows).
- **Context7** (falls eingerichtet) für aktuelle Library-Dokumentation.

## Hooks (automatisch, nicht umgehen)

Nach Bearbeitungen formatiert und lintet ein Hook die geänderte Datei mit den Werkzeugen **des Projekts**; gemeldete
Lint-Fehler beheben. Bei Änderungen an Dependency-Dateien kommt ein Audit-Hinweis. Vor `git commit`/`git push` wird
der Diff als Kontext angezeigt und auf Secrets geprüft; riskante Git-Befehle erfordern Rückfrage.
Schnelle Tests laufen am Ende einer Antwort nur, wenn das Projekt es per `.claude/quick-test` festlegt.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/backend.md" <<'CLAUDE_SETUP_ENDE'
---
name: backend
description: Backend-Implementierung – APIs, Datenbanken, Authentifizierung, Serverlogik, Fehlerbehandlung, Security, Architektur. Einsetzen, wenn Server-Code, Endpunkte, Datenmodelle, Migrationen oder Auth betroffen sind.
tools: Read, Edit, Write, Grep, Glob, Bash
model: inherit
---

Du bist ein erfahrener Backend-Entwickler.

Grundsätze:
- Architektur und Schichten des Projekts respektieren (Routing → Validierung → Service/Logik → Datenzugriff).
- **Eingaben an der Grenze validieren** (Schema-Validierung mit der Library, die das Projekt schon nutzt).
- **Security:** parametrisierte Queries, keine Secrets im Code (Umgebungsvariablen), Passwörter nur mit etablierten
  Hash-Verfahren, Autorisierung bei **jedem** Zugriff prüfen (nicht nur Authentifizierung), sichere Cookies/Tokens,
  keine sensiblen Daten in Logs oder Fehlermeldungen, Rate-Limits bei Login/teuren Endpunkten bedenken.
- **Fehlerbehandlung:** erwartbare Fehler mit passenden Statuscodes und klaren Meldungen; unerwartete Fehler loggen
  (ohne Secrets) und generisch beantworten. Keine leeren `catch`-Blöcke.
- **Datenbank:** Migrationen statt manueller Schemaänderungen, Transaktionen für zusammengehörige Schreibvorgänge,
  Indizes für häufige Abfragen, N+1-Abfragen vermeiden. **Nie** destruktive Migrationen oder Datenlöschungen ohne
  ausdrückliche Freigabe.
- Keine neuen Dependencies ohne Begründung.

Nach der Umsetzung: vorhandene Tests ausführen, für neue Logik passende Tests ergänzen (im Stil des Projekts),
Endpunkte mit einem realen Aufruf prüfen, falls ein Server lokal startbar ist.

Rückgabe an den Main Agent: geänderte Dateien, API-/Schema-Änderungen, Security-Überlegungen, Testergebnis, offene
Punkte (z. B. benötigte Umgebungsvariablen – nur Namen, nie Werte).
CLAUDE_SETUP_ENDE

cat > "$Z/agents/frontend.md" <<'CLAUDE_SETUP_ENDE'
---
name: frontend
description: Frontend-Implementierung – React, Next.js, HTML/CSS, Tailwind, Responsive Design, Barrierefreiheit, UI/UX. Einsetzen, wenn die Aufgabe hauptsächlich Komponenten, Styling, Layout oder Bedienung im Browser betrifft.
tools: Read, Edit, Write, Grep, Glob, Bash, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_click, mcp__playwright__browser_console_messages
model: inherit
---

Du bist ein erfahrener Frontend-Entwickler.

Grundsätze:
- Bestehendes Framework, Komponentenbibliothek, Design-Tokens und Styling-Ansatz des Projekts verwenden
  (Tailwind **oder** CSS-Module **oder** eigenes CSS – nie mischen, was das Projekt nicht mischt).
- Komponenten klein, klar benannt, typisiert (falls TypeScript), ohne unnötigen State. Server- vs. Client-Komponenten
  bei Next.js bewusst wählen (`"use client"` nur wo nötig).
- **Mobil zuerst:** 320–1920 px ohne horizontales Scrollen, Tippflächen ≥ 44 px, Text ≥ 16 px.
- **Barrierefreiheit:** semantisches HTML, Labels für Formularfelder, sichtbarer Fokus, Tastaturbedienung,
  Alt-Texte, Kontrast WCAG AA, `prefers-reduced-motion` respektieren.
- Leistung: Bilder mit Größenangaben und passenden Formaten, das LCP-Element nie lazy laden, keine Layout-Sprünge,
  Animationen nur mit `transform`/`opacity`.
- Keine neuen UI-Libraries ohne Rückfrage beim Main Agent.

Nach der Umsetzung: Linter/Typprüfung/Build des Projekts ausführen und die Änderung im Browser (Playwright, lokaler
Server) bei Handy- und Desktop-Breite ansehen.

Rückgabe an den Main Agent: geänderte Dateien, kurze Begründung, was geprüft wurde (Breiten, Tastatur, Konsole),
offene Punkte.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/researcher.md" <<'CLAUDE_SETUP_ENDE'
---
name: researcher
description: Technische Recherche mit aktuellen Quellen. Einsetzen, wenn Library-/API-Versionen, aktuelle Dokumentation, Breaking Changes, Best Practices oder Vergleiche von Tools gebraucht werden – oder wenn Wissen veraltet sein könnte. Liefert kompakte, belegte Ergebnisse.
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, mcp__context7__resolve-library-id, mcp__context7__query-docs
model: inherit
---

Du bist ein Recherche-Spezialist. Du änderst keinen Projektcode.

Vorgehen:
1. Frage präzisieren: Was genau muss der Main Agent wissen, um weiterzuarbeiten?
2. Zuerst im Projekt nachsehen, welche Versionen tatsächlich verwendet werden (`package.json`, Lockfiles,
   `requirements*.txt`, `pyproject.toml`, `go.mod` …) – Antworten müssen zu **diesen** Versionen passen.
3. Quellen in dieser Reihenfolge: offizielle Dokumentation (Context7, falls verfügbar), offizielles Repository
   (Changelog, Releases, Migration Guides), Paketregister (`npm view <paket> version`, `pip index versions`),
   dann seriöse Sekundärquellen. Gesperrte Seiten melden, nicht raten.
4. Veraltetes aktiv ausschließen: Veröffentlichungsdatum und Versionsbezug jeder Quelle prüfen.
5. Nichts erfinden. Was nicht belegbar ist, als „unbestätigt“ kennzeichnen.

Antwortformat (kompakt, max. ~300 Wörter, außer mehr ist ausdrücklich gewünscht):
- **Ergebnis:** die direkte Antwort in 1–3 Sätzen
- **Details:** nur das Nötige (Codeschnipsel, Konfiguration, Befehle)
- **Versionen:** worauf sich die Aussage bezieht
- **Quellen:** URL oder Dokumentationsstelle je Aussage (bzw. „lokal: <Datei>“)
- **Unsicher/offen:** falls vorhanden
CLAUDE_SETUP_ENDE

cat > "$Z/agents/reviewer.md" <<'CLAUDE_SETUP_ENDE'
---
name: reviewer
description: Unabhängiges Code-Review – findet Bugs, Security-Probleme, unnötige Komplexität, Performance-Probleme und schlechte Architektur und liefert konkrete Verbesserungen. Einsetzen, bevor größere Änderungen als abgeschlossen gelten, oder auf Wunsch für einen Diff/Branch/PR.
tools: Read, Grep, Glob, Bash
model: inherit
---

Du bist ein erfahrener, unabhängiger Reviewer. Du änderst **keinen Code** – du prüfst und berichtest.
Du kennst die Absicht des Autors nur aus dem Auftrag und dem Code; prüfe, ob der Code wirklich tut, was er soll.

Vorgehen:
1. Umfang bestimmen: `git status`, `git diff` (bzw. `git diff <basis>...HEAD`), betroffene Dateien vollständig lesen,
   Aufrufer der geänderten Funktionen suchen.
2. Prüfen, in dieser Priorität:
   1. **Korrektheit:** Logikfehler, Randfälle (leer, null, sehr groß, gleichzeitig), Fehlerpfade, Off-by-one,
      Race Conditions, falsche Annahmen über Eingaben
   2. **Security:** Injection (SQL/Shell/HTML/XSS), fehlende Autorisierung, Secrets im Code/Log, unsichere
      Deserialisierung, SSRF, Pfad-Traversal, unsichere Defaults, verwundbare Dependencies
   3. **Performance:** unnötige Schleifen/Queries (N+1), fehlende Indizes, große Bundles, blockierende Aufrufe,
      Speicherlecks
   4. **Architektur & Wartbarkeit:** Verstoß gegen bestehende Muster, doppelte Logik, unnötige Abstraktion oder
      Komplexität, unklare Namen, fehlende Tests für neue Logik
3. Jeden Befund **verifizieren** (Code lesen, ggf. kleinen Test/Befehl ausführen). Keine Vermutungen als Fakten.

Bericht an den Main Agent, nach Schwere sortiert:
- `[KRITISCH|HOCH|MITTEL|NIEDRIG] Datei:Zeile – Problem` · **Szenario:** konkrete Eingabe → falsches Ergebnis ·
  **Vorschlag:** konkrete Änderung (kurzer Codeschnipsel, falls hilfreich)
- Am Ende: **Gesamturteil** (bereit / nach Fixes bereit / nicht bereit) und was gut gelöst ist (1–2 Sätze).
Keine Stil-Kleinigkeiten, die ein Formatter/Linter ohnehin erledigt.
CLAUDE_SETUP_ENDE

cat > "$Z/agents/tester.md" <<'CLAUDE_SETUP_ENDE'
---
name: tester
description: Systematisches Testen von Anwendungen und Features – Browserflows, Formulare, Navigation, Responsive-Verhalten, Fehlerfälle, Regressionen; nutzt Playwright. Einsetzen, wenn ein Feature oder eine Anwendung geprüft werden soll, bevor sie als fertig gilt.
tools: Read, Grep, Glob, Bash, Write, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_fill_form, mcp__playwright__browser_select_option, mcp__playwright__browser_press_key, mcp__playwright__browser_hover, mcp__playwright__browser_wait_for, mcp__playwright__browser_evaluate, mcp__playwright__browser_console_messages, mcp__playwright__browser_network_requests, mcp__playwright__browser_navigate_back, mcp__playwright__browser_tabs, mcp__playwright__browser_close, mcp__chrome-devtools__new_page, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__lighthouse_audit, mcp__chrome-devtools__performance_start_trace, mcp__chrome-devtools__performance_analyze_insight, mcp__chrome-devtools__performance_stop_trace, mcp__chrome-devtools__list_console_messages, mcp__chrome-devtools__list_network_requests
model: inherit
---

Du bist ein gründlicher QA-Ingenieur. Du änderst **keinen Anwendungscode** – du findest und belegst Fehler.
Testdateien darfst du anlegen, wenn der Main Agent das möchte.

Vorgehen:
1. Verstehen, was getestet werden soll, und wie die Anwendung lokal startet (README, `package.json`-Skripte).
   Anwendung bzw. statischen Server im Hintergrund starten; nie über `file://` testen.
2. Vorhandene automatische Tests ausführen (Unit/E2E) und Ergebnis notieren.
3. Manuell per Playwright (MCP oder Skript) prüfen:
   - **Hauptflows** Schritt für Schritt (Navigation, Links, Zurück-Knopf, Deep-Links)
   - **Formulare:** gültige Eingaben, leere Pflichtfelder, ungültige Formate, sehr lange Eingaben, Sonderzeichen,
     Doppelklick auf Absenden
   - **Responsive:** 320, 390, 768, 1440 px – kein horizontales Scrollen, nichts überlappt, Menü bedienbar
   - **Tastatur:** Tab-Reihenfolge, sichtbarer Fokus, Escape schließt Dialoge
   - **Fehlerfälle:** 404, Netzwerkfehler/Server-Fehler, leere Zustände
   - **Konsole und Netzwerk:** JavaScript-Fehler, fehlgeschlagene Requests
4. Regressionen: auch angrenzende, nicht direkt geänderte Bereiche kurz prüfen.
5. Gestartete Prozesse am Ende beenden (gezielt per PID, nie `pkill -f` auf allgemeine Muster).

Bericht an den Main Agent:
- **Ergebnis:** bestanden / Fehler gefunden (Anzahl)
- **Fehler:** je Fehler Schritte zum Nachstellen, erwartet vs. tatsächlich, Breite/Browser, Screenshot-Pfad
- **Geprüft ohne Befund:** kurze Liste
- **Nicht testbar:** mit Grund
CLAUDE_SETUP_ENDE

cat > "$Z/hooks/gemeinsam.py" <<'CLAUDE_SETUP_ENDE'
"""Gemeinsame Hilfen für die globalen Claude-Code-Hooks. Keine Abhängigkeiten außer der Standardbibliothek."""
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
    ("GitHub-Token", r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{50,}\b"),
    ("Anthropic-Key", r"\bsk-ant-[A-Za-z0-9_\-]{20,}"),
    ("OpenAI-Key", r"\bsk-(?:proj-)?[A-Za-z0-9]{32,}\b"),
    ("Stripe Live Key", r"\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b"),
    ("Slack-Token", r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    ("Google API Key", r"\bAIza[0-9A-Za-z_\-]{35}\b"),
    ("Privater Schlüssel", r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY-----"),
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
    """Liefert nur die Arten gefundener Secrets – nie die Werte."""
    return sorted({name for name, m in SECRET_MUSTER if re.search(m, text or "")})


def schwaerzen(text):
    for _, m in SECRET_MUSTER:
        text = re.sub(m, "[GESCHWÄRZT]", text)
    return text


def kuerzen(text, zeilen=40):
    z = schwaerzen(text).strip().splitlines()
    return "\n".join(z[:zeilen] + ([f"… ({len(z) - zeilen} weitere Zeilen)"] if len(z) > zeilen else []))


def ausfuehren(befehl, cwd, timeout):
    """Führt einen Befehl ohne Shell aus. Ergebnis: (exitcode, ausgabe) – bei Zeitüberschreitung (None, '')."""
    try:
        r = subprocess.run(befehl, cwd=cwd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return None, ""
    except (OSError, ValueError):
        return 127, ""


def werkzeug(name, paketordner):
    """Projekt-lokales Werkzeug bevorzugen, sonst global installiertes."""
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
"""PostToolUse (Edit|Write|MultiEdit): formatiert und lintet die geänderte Datei mit den Werkzeugen DES PROJEKTS,
meldet Dependency-Änderungen mit einem Audit und merkt sich, dass sich Code geändert hat (für den Schnelltest).

Robust: nur Dateien im Projekt, nur konfigurierte Werkzeuge, kurze Timeouts, Ausgaben gekürzt und geschwärzt,
höchstens 3 Lint-Rückmeldungen hintereinander pro Datei (keine Endlosschleife)."""
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
    """JSON-Ausgabe von ESLint (Kernformat, versionsstabil) in kurze Zeilen umwandeln."""
    start = ausgabe.find("[{\"filePath\"")
    try:
        daten = json.JSONDecoder().raw_decode(ausgabe[start:])[0] if start >= 0 else []
    except ValueError:
        return []
    return [f"{m.get('line', '?')}:{m.get('column', '?')} {'Fehler' if m.get('severity') == 2 else 'Warnung'} "
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

    # ---- Formatter und Linter (nur wenn das Projekt sie konfiguriert hat)
    pkg = paketordner(pfad, wurzel)
    if pkg and endung in PRETTIER and prettier_konfiguriert(pkg):
        p = werkzeug("prettier", pkg)
        if p:
            code, out = ausfuehren([p, "--write", "--log-level", "warn", str(pfad)], pkg, 20)
            if code not in (0, None):
                hinweise.append(f"Prettier konnte {rel} nicht formatieren:\n{kuerzen(out, 10)}")
    if pkg and endung in CODE and eslint_konfiguriert(pkg):
        e = werkzeug("eslint", pkg)
        if e:
            code, out = ausfuehren([e, "--no-warn-ignored", "--format", "json", str(pfad)], pkg, 40)
            meldungen = eslint_meldungen(out)
            if code == 1 and meldungen:
                fehler.append(f"ESLint meldet Probleme in {rel}:\n{kuerzen(chr(10).join(meldungen))}")
            elif code not in (0, 1, None):
                hinweise.append(f"ESLint konnte {rel} nicht prüfen (Konfigurationsfehler?):\n{kuerzen(out, 8)}")
    pypkg = paketordner(pfad, wurzel, ("pyproject.toml", "ruff.toml", ".ruff.toml", "setup.cfg"))
    if pypkg and endung in PY:
        ruff_cfg = (pypkg / "ruff.toml").exists() or (pypkg / ".ruff.toml").exists() or pyproject_hat(pypkg, "ruff")
        ruff = werkzeug("ruff", pypkg) if ruff_cfg else None
        if ruff:
            ausfuehren([ruff, "format", str(pfad)], pypkg, 20)
            code, out = ausfuehren([ruff, "check", "--output-format", "concise", str(pfad)], pypkg, 30)
            if code == 1 and out.strip():
                fehler.append(f"Ruff meldet Probleme in {rel}:\n{kuerzen(out)}")
        elif pyproject_hat(pypkg, "black") and werkzeug("black", pypkg):
            ausfuehren([werkzeug("black", pypkg), "-q", str(pfad)], pypkg, 20)

    # ---- Sicherheit: Dependencies und sensible Konfiguration
    if pfad.name in DEPS:
        sperre = zustand(wurzel, "audit")
        if not sperre.exists() or time.time() - sperre.stat().st_mtime > 600:   # höchstens alle 10 Minuten
            sperre.touch()
            ordner = pfad.parent
            if (ordner / "package-lock.json").exists() and werkzeug("npm", ordner):
                code, out = ausfuehren(["npm", "audit", "--audit-level=high", "--omit=dev", "--json"], ordner, 60)
                try:
                    v = json.loads(out).get("metadata", {}).get("vulnerabilities", {})
                    zahl = {k: v.get(k, 0) for k in ("critical", "high", "moderate")}
                    hinweise.append(f"npm audit nach Änderung an {rel}: kritisch {zahl['critical']}, hoch {zahl['high']}, "
                                    f"mittel {zahl['moderate']}." + (" Bitte prüfen, bevor die Änderung als fertig gilt."
                                                                     if zahl["critical"] or zahl["high"] else ""))
                except Exception:
                    hinweise.append(f"{rel} geändert: npm audit war nicht auswertbar (offline?). Neue Pakete auf Vertrauenswürdigkeit prüfen.")
            elif werkzeug("pip-audit", ordner) and pfad.name.startswith("requirements"):
                code, out = ausfuehren(["pip-audit", "-r", str(pfad), "--progress-spinner", "off"], ordner, 90)
                hinweise.append(f"pip-audit für {rel}:\n{kuerzen(out, 15)}")
            else:
                hinweise.append(f"Dependency-Datei {rel} geändert: neue Pakete auf Herkunft, Pflege und bekannte Lücken prüfen.")
    if SENSIBEL.search(rel):
        hinweise.append(f"Sicherheitsrelevante Datei {rel} geändert: keine Secrets eintragen/ausgeben, "
                        "`.env*` muss in .gitignore stehen, Berechtigungen und Defaults bewusst wählen.")

    # ---- Rückmeldung (Lint-Fehler höchstens 3× hintereinander pro Datei zurückspielen)
    zaehler = zustand(wurzel, "lint-" + hashlib.sha1(rel.encode()).hexdigest()[:10])
    if fehler:
        n = int(zaehler.read_text() or 0) + 1 if zaehler.exists() else 1
        zaehler.write_text(str(n))
        if n <= 3:
            print("\n\n".join(fehler + hinweise), file=sys.stderr)
            return 2
        hinweise.append(f"Lint-Probleme in {rel} bestehen weiter (nach 3 Rückmeldungen nicht mehr blockierend).")
    elif zaehler.exists():
        zaehler.unlink()
    if hinweise:
        kontext("PostToolUse", "\n\n".join(hinweise))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:   # ein Hook-Fehler darf die Arbeit nie blockieren
        print(f"Hook nach_bearbeitung: interner Fehler ({type(e).__name__}) – übersprungen", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/nach_bearbeitung.py"

cat > "$Z/hooks/schnelltest.py" <<'CLAUDE_SETUP_ENDE'
#!/usr/bin/env python3
"""Stop: führt am Ende einer Antwort einen SCHNELLEN Test aus – nur wenn
  1. das Projekt ihn in `.claude/quick-test` festlegt (erste nicht-leere Zeile = Befehl, z. B. `npm run test:quick`),
  2. seit dem letzten Lauf Code geändert wurde (Markierung vom Hook nach_bearbeitung) und
  3. dieser Stop nicht schon durch einen Hook ausgelöst wurde (stop_hook_active → keine Endlosschleife).
Zeitlimit: optional zweite Zeile `timeout=90` (Standard 120 s, höchstens 300 s). Schlägt der Test fehl, bekommt
Claude die gekürzte Ausgabe zurück und arbeitet weiter; beim nächsten Stop wird nicht erneut blockiert."""
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
    markierung.unlink()   # vor dem Lauf entfernen: ein Fehlschlag löst nie mehr als eine Rückmeldung aus
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
        print(f"Schnelltest `{zeilen[0]}` nach {timeout} s abgebrochen – für den Stop-Hook zu langsam; "
              "in .claude/quick-test einen schnelleren Befehl eintragen.", file=sys.stderr)
        return 0
    if code != 0:
        print(f"Schnelltest `{zeilen[0]}` fehlgeschlagen (Exit {code}):\n{kuerzen(out, 50)}\n\n"
              "Bitte Ursache beheben oder dem Nutzer erklären, warum der Test fehlschlägt.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"Hook schnelltest: interner Fehler ({type(e).__name__}) – übersprungen", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/schnelltest.py"

cat > "$Z/hooks/vor_werkzeug.py" <<'CLAUDE_SETUP_ENDE'
#!/usr/bin/env python3
"""PreToolUse:
- Edit|Write|MultiEdit: verhindert, dass Secrets in Projektdateien geschrieben werden (außer in .env-Dateien).
- Bash: riskante Befehle (Force-Push, reset --hard, clean -f, rm -rf auf weite Pfade, DROP …) → Rückfrage;
        vor git commit / git push den Diff als Kontext zeigen und gestagte Änderungen auf Secrets prüfen.
Gibt nie Secret-Werte aus. Blockiert bei internen Fehlern nie."""
import json
import re
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemeinsam import ausfuehren, eingabe, kuerzen, projekt, secrets_finden  # noqa: E402

# git mit globalen Optionen davor (git -C ordner …, git -c key=val …, git --no-pager …)
GIT = r"\bgit(?:\s+-[Cc]\s+\S+|\s+--[a-z-]+(?:=\S+)?)*\s+"

RISKANT = [
    (GIT + r"push\b[^|;&]*\s(--force(?!-with-lease)\b|-f\b|--force-with-lease\b|\+\S+)", "Force-Push überschreibt Remote-Historie"),
    (GIT + r"reset\s+[^|;&]*--hard\b", "git reset --hard verwirft lokale Änderungen"),
    (GIT + r"clean\s+[^|;&]*-[a-zA-Z]*f", "git clean löscht unversionierte Dateien"),
    (GIT + r"branch\s+[^|;&]*-D\b", "Branch wird ohne Merge-Prüfung gelöscht"),
    (GIT + r"(checkout|restore)\s+(--\s+)?\.(\s|$)", "verwirft alle lokalen Änderungen"),
    (GIT + r"stash\s+(drop|clear)\b", "löscht gesicherte Änderungen"),
    (r"\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR])[a-zA-Z]*\s+(/|~|\$HOME|\.\.|\*|\.)(\s|/?$|/\*)", "rm -rf auf einen weiten Pfad"),
    (r"\b(DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE)\b", "löscht Datenbankinhalte"),
    (r"\b(prisma\s+migrate\s+reset|rails\s+db:drop|dropdb)\b", "setzt die Datenbank zurück"),
    (r"\bnpm\s+(uninstall|remove|rm)\b|\bpip\s+uninstall\b", "entfernt Abhängigkeiten"),
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
        entscheidung("deny", f"Blockiert: Der neue Inhalt für {Path(pfad).name} enthält vermutlich ein Secret "
                             f"({', '.join(arten)}). Secrets gehören in Umgebungsvariablen bzw. eine .env-Datei, die in "
                             ".gitignore steht – im Code nur den Variablennamen verwenden.")


def befehl(daten):
    cmd = (daten.get("tool_input") or {}).get("command") or ""
    for muster, grund in RISKANT:
        if re.search(muster, cmd, re.IGNORECASE):
            entscheidung("ask", f"Riskanter Befehl: {grund}. Bitte bestätigen.")
            return
    wurzel = projekt(daten)
    if not re.search(GIT + r"(commit|push)\b", cmd):
        return
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
            entscheidung("deny", f"Commit blockiert: Die Änderungen enthalten vermutlich ein Secret ({', '.join(arten)}). "
                                 "Datei(en) mit `git diff --cached` prüfen, Secret entfernen und in eine Umgebungsvariable "
                                 "verschieben. Werte nicht ausgeben.")
            return
        teile.append("Vor dem Commit – Umfang der Änderungen:\n" + (kuerzen(stat, 30) or "(nichts gestaged)"))
    else:
        _, stat = ausfuehren(["git", "diff", "--stat", "@{upstream}...HEAD"], wurzel, 10)
        _, log = ausfuehren(["git", "log", "--oneline", "@{upstream}..HEAD"], wurzel, 10)
        if "fatal" in log or "fatal" in stat:
            _, log = ausfuehren(["git", "log", "--oneline", "-5"], wurzel, 10)
            stat = "(kein Upstream – neuer Branch; letzte Commits siehe oben)"
        teile.append("Vor dem Push – Commits:\n" + kuerzen(log, 15) + "\n\nGeänderte Dateien:\n" + kuerzen(stat, 30))
    teile.append("Prüfen, ob nur beabsichtigte Dateien enthalten sind (keine .env, Build-Artefakte, großen Binärdateien).")
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
        print(f"Hook vor_werkzeug: interner Fehler ({type(e).__name__}) – übersprungen", file=sys.stderr)
        sys.exit(0)
CLAUDE_SETUP_ENDE
chmod +x "$Z/hooks/vor_werkzeug.py"

# ---- settings.json zusammenführen (nur eigene Hook-Einträge ersetzen)
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
print("settings.json: Hooks eingetragen")
CLAUDE_SETUP_ENDE

# ---- MCP-Server (Nutzer-Ebene). Nur lokal laufende, vertrauenswürdige Server; Versionen fest.
CHROME=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux*/chrome 2>/dev/null | head -1)
[ -z "$CHROME" ] && CHROME=$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)
mcp() {  # name json
  if command -v claude >/dev/null 2>&1; then
    claude mcp remove -s user "$1" >/dev/null 2>&1 || true
    claude mcp add-json -s user "$1" "$2" >/dev/null && echo "MCP $1: eingerichtet" || echo "MCP $1: FEHLER beim Eintragen"
  else
    python3 - "$1" "$2" <<'CLAUDE_SETUP_ENDE'
import json, sys, os
p = os.path.expanduser("~/.claude.json")
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("mcpServers", {})[sys.argv[1]] = json.loads(sys.argv[2])
json.dump(d, open(p, "w"), indent=2)
print(f"MCP {sys.argv[1]}: eingerichtet (ohne claude-CLI)")
CLAUDE_SETUP_ENDE
  fi
}
# Chromium startet als root nur ohne Sandbox (Cloud-Container laufen als root); als normaler Nutzer bleibt sie an.
PW_SB=""; CD_SB=""
if [ "$(id -u)" = "0" ]; then PW_SB=',"--no-sandbox"'; CD_SB=',"--chrome-arg=--no-sandbox"'; fi
if [ -n "$CHROME" ]; then
  mcp playwright "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@playwright/mcp@0.0.82\",\"--headless\",\"--isolated\",\"--executable-path\",\"$CHROME\",\"--output-dir\",\"/tmp/playwright-mcp\"$PW_SB]}"
  mcp chrome-devtools "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"chrome-devtools-mcp@1.10.1\",\"--headless\",\"--isolated\",\"--no-usage-statistics\",\"--executablePath\",\"$CHROME\"$CD_SB]}"
else
  echo "MCP playwright/chrome-devtools: kein Chromium gefunden – übersprungen"
fi
# Context7 nur, wenn der Dienst im Netz erreichbar ist (sonst würde jede Sitzung mit einem Fehler starten)
code=$(curl -s -m 8 -o /dev/null -w "%{http_code}" https://mcp.context7.com/mcp 2>/dev/null); code=${code:-000}
if [ "${code:0:3}" != "000" ]; then
  mcp context7 '{"type":"http","url":"https://mcp.context7.com/mcp"}'
else
  command -v claude >/dev/null 2>&1 && claude mcp remove -s user context7 >/dev/null 2>&1
  echo "MCP context7: mcp.context7.com nicht erreichbar (Netzwerkfreigabe fehlt) – übersprungen"
fi
# npm-Pakete vorwärmen, damit der erste Start schnell ist (Fehler egal)
(cd /tmp && timeout 180 npx -y @playwright/mcp@0.0.82 --help >/dev/null 2>&1; timeout 180 npx -y chrome-devtools-mcp@1.10.1 --help >/dev/null 2>&1) || true
python3 -m py_compile "$Z"/hooks/*.py && echo "Hooks: Syntax ok"
echo "== fertig. Agents: $(ls "$Z/agents" | tr '\n' ' ')"
exit 0
