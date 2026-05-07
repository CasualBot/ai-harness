# ai-harness

A portable Claude Code harness. Currently ships a single skill — **`setup-second-brain`** — that bootstraps an [Obsidian](https://obsidian.md) vault, wires it into Claude Code's global `CLAUDE.md`, and installs a statusline.

The skill asks a handful of questions (OS, where to put the vault, where you keep your code, whether to install the statusline, etc.), then creates a folder skeleton, generic `CLAUDE.md` conventions, an `add-project-to-vault` workflow doc, statusline scripts, and a starter daily note. After it runs you have a working "second brain" you can start logging into immediately.

## What it creates

- A vault folder (path you choose) with `00 Notes/`, `01 Projects/` (developer mode), `02 Skills/`, `03 Scripts/` skeletons
- A generic `CLAUDE.md` at the vault root capturing the conventions (daily notes, plans, memories, linking, secrets/PII)
- `~/.claude/CLAUDE.md` with a vault pointer and `@` import (idempotent — safe to re-run)
- The bundled statusline scripts copied into `<vault>/03 Scripts/` (bash + PowerShell). Wiring them as your active statusline is **opt-in**: the skill asks, and if you say yes it invokes Claude Code's built-in `/statusline-setup` agent — it never edits `~/.claude/settings.json` directly.
- Today's daily note as a starting point
- Optional: on WSL, mirrors the `CLAUDE.md` pointer to your Windows-side Claude Code (`C:\Users\<you>\.claude\`). The Windows-side statusline is *not* auto-wired — you run `/statusline-setup` from Windows-native Claude Code yourself when ready.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated (`claude` command works in your terminal)
- [Obsidian](https://obsidian.md) installed (the skill creates the vault folder; you open it in Obsidian afterwards)
- Git

## Quick start

1. Clone this repo somewhere permanent (e.g. `~/tools/ai-harness`).
2. Run the install commands for your platform (see below) to wire the skill into Claude Code.
3. In any Claude Code session, type `/setup-second-brain` and answer the prompts.

## Install

Pick a location to clone the repo. Replace `<clone>` with your chosen path (e.g. `~/tools/ai-harness`).

### Unix (macOS / Linux / WSL)

```bash
git clone git@github.com:CasualBot/ai-harness.git <clone>
mkdir -p ~/.claude/skills
ln -s "<clone>/skills/setup-second-brain" ~/.claude/skills/setup-second-brain
ln -s "<clone>/skills/setup-second-brain" ~/.claude/skills/setup-brain
ln -s "<clone>/skills/setup-second-brain" ~/.claude/skills/setup-harness
chmod +x "<clone>/skills/setup-second-brain/scripts/statusline-command.sh"
```

### Windows native (PowerShell)

Symlinks on Windows require [Developer Mode](https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development) or running PowerShell as admin.

```powershell
git clone git@github.com:CasualBot/ai-harness.git <clone>
New-Item -ItemType Directory -Force -Path "$HOME\.claude\skills" | Out-Null
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\setup-second-brain" -Target "<clone>\skills\setup-second-brain"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\setup-brain"        -Target "<clone>\skills\setup-second-brain"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\setup-harness"      -Target "<clone>\skills\setup-second-brain"
```

If symlinks aren't available, fall back to `Copy-Item -Recurse` for each alias.

## Run

In Claude Code, type any of:

- `/setup-second-brain`
- `/setup-brain`
- `/setup-harness`

All three are aliases for the same skill. Answer the prompts and the skill takes care of the rest. Re-running is safe — the vault pointer block is marker-wrapped and the statusline merge preserves any other settings you have.

## No secrets, ever

This repo must never contain credentials, API keys, or PII. The skill it installs enforces the same rule on the vault it creates: secrets live in your OS keychain, a password manager, or a `chmod 600` `.env` outside any cloud-synced folder — never in the vault.

## Forking

Fork the repo, edit the templates under `skills/setup-second-brain/templates/`, and your customised vault skeleton ships with the next clone. The skill itself reads from those templates at runtime, so changes are immediate.

## Recommended Obsidian community plugins

The skill creates the vault skeleton but does not touch Obsidian itself. These plugins pair well with the conventions the generated `CLAUDE.md` describes — install them from Obsidian's Community Plugins browser (Settings → Community plugins → Browse):

- **[Calendar](https://github.com/liamcain/obsidian-calendar-plugin)** — sidebar calendar; click a date to open or create that daily note. Pairs directly with the daily-note format the skill seeds (`<Month Nth YYYY>.md`).
- **[Diagrams (drawio)](https://github.com/zapthedingbat/drawio-obsidian)** — renders `.drawio` files inline. Useful once you start adding architecture or flow diagrams to the vault.
- **[Excalidraw](https://github.com/zsviczian/obsidian-excalidraw-plugin)** — hand-drawn-style sketches embedded in notes. Good for whiteboard-style thinking and quick visuals.
- **[Iconize](https://github.com/FlorianWoelki/obsidian-icon-folder)** *(folder name `obsidian-icon-folder`)* — custom icons per folder in the file tree. Helps the eye distinguish `01 Projects/` from `00 Notes/` at a glance.
- **[Code View](https://github.com/zorazrr/obsidian-code-view)** — code-aware viewing of source files stored in the vault.

None of these are required — the skill works without any plugins installed. They're suggestions based on what pairs well with the generated structure.

## Layout

```
ai-harness/
├── README.md
├── .gitignore
└── skills/
    └── setup-second-brain/
        ├── SKILL.md                         # the skill body Claude reads
        ├── templates/
        │   ├── vault-CLAUDE.md              # the generic CLAUDE.md placed at the vault root
        │   ├── global-CLAUDE-snippet.md     # marker-wrapped pointer appended to ~/.claude/CLAUDE.md
        │   ├── add-project-to-vault.md      # the bundled workflow doc copied into <vault>/02 Skills/
        │   ├── memories-index.md            # MEMORIES.md table template
        │   └── starter-daily-note.md        # the first daily note — your "jump off point"
        └── scripts/
            ├── statusline-command.sh        # bash (Linux/macOS/WSL)
            └── statusline-command.ps1       # PowerShell (Windows)
```
