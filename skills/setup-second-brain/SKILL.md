---
name: setup-second-brain
description: "Bootstrap a fresh Obsidian 'second brain' vault with CLAUDE.md conventions, an add-project workflow, statusline scripts, and a starter daily note. Use when setting up a new vault, onboarding a new machine, or sharing the harness with a colleague. Aliases: /setup-brain, /setup-harness."
---

# Setup Second Brain

This skill bootstraps a fresh Obsidian vault that doubles as Claude Code's persistent knowledge store ("second brain"). It asks the user a handful of questions, then creates the folder skeleton, writes a generic `CLAUDE.md`, installs the bundled `add-project-to-vault` workflow, copies statusline scripts, and seeds today's daily note as a jumping-off point. On WSL it can also mirror the wiring to the Windows-side Claude Code so both environments share one vault.

## Bundle layout

The skill bundle lives at the directory containing this `SKILL.md` (call it `<skill-dir>`). When you need to read a template or copy a script, use absolute paths under `<skill-dir>`:

- `<skill-dir>/templates/vault-CLAUDE.md`
- `<skill-dir>/templates/global-CLAUDE-snippet.md`
- `<skill-dir>/templates/add-project-to-vault.md`
- `<skill-dir>/templates/memories-index.md`
- `<skill-dir>/templates/starter-daily-note.md`
- `<skill-dir>/scripts/statusline-command.sh`
- `<skill-dir>/scripts/statusline-command.ps1`

Resolve `<skill-dir>` by reading the path of `SKILL.md` itself (you'll know it from how you were invoked) — typically `~/.claude/skills/setup-second-brain/` (which is a symlink to the cloned repo).

## Step 1 — Detect environment

Run these checks (Bash):

```bash
uname -a
echo "WSL_DISTRO_NAME=${WSL_DISTRO_NAME:-<unset>}"
test -d /mnt/c/Users && echo "mnt-c=present" || echo "mnt-c=absent"
```

Classify the host as one of:
- **macOS** — `uname` reports `Darwin`
- **Linux (no WSL)** — `uname` reports `Linux`, `WSL_DISTRO_NAME` unset, `/mnt/c/Users` absent
- **WSL** — `Linux` *and* (`WSL_DISTRO_NAME` set *or* `/mnt/c/Users` present)
- **Windows native** — running under PowerShell on `Windows_NT` (only relevant if the skill is invoked from a Windows-native Claude Code; on WSL fall through the WSL branch)

If the host is **WSL**, tell the user explicitly:

> Looks like you're on Windows running WSL. After we set up the vault and wire your WSL-side Claude Code, I'll also offer to point your Windows-side (PowerShell) Claude Code at the same vault — so both environments share one brain.

If the host is **not** WSL, never touch `/mnt/c/Users/` paths — that mount won't exist.

## Step 2 — Ask the setup questions

Ask these one at a time, in order. Use plain text — wait for the user's answer before moving to the next. Show defaults the user can accept by replying "yes" or pressing Enter.

### 2.1 — Confirm OS
> "I detected `<os>`. Is that right?" — let the user override if the autodetection is wrong (e.g. they're using a custom distro).

### 2.2 — Vault location *(foundational — ask first)*
> "Where should your Obsidian vault live? Give me an absolute path."

Show platform-aware defaults the user can accept:
- **macOS:** `~/Documents/notes`
- **Linux (no WSL):** `~/notes`
- **WSL:** `/mnt/c/Users/<windows-user>/Documents/notes` *(recommended — makes the vault directly readable by Windows-native tools, including the Windows-side Claude Code without any path translation).* Offer `~/notes` as a Linux-only alternative.
- **Windows native:** `$HOME\Documents\notes`

Validation:
- Must be absolute (not relative, no leading `./`).
- Resolve `~` to the user's home.
- The parent directory must exist or be creatable.
- The user must have write access — `test -w "$(dirname <path>)"`.
- If the path contains spaces, remind the user to **quote it in shells**.

Capture the canonical resolved absolute path. Refer to it as `{{VAULT_PATH}}` from here on.

### 2.3 — Vault name
> "What should I call this vault in prose? Defaults to the folder name (`<basename of vault path>`)."

This is used in `CLAUDE.md` text only — it does not rename the folder.

### 2.4 — Developer mode
> "Are you a developer who wants `01 Projects/` set up for code repos? (yes/no)"

If **no**, skip 2.5.

### 2.5 — Repo root *(developer only)*
> "Where do you keep your code repos locally?"

Defaults: `~/workspace` (Linux/macOS/WSL), `$HOME\workspace` (Windows native). Capture as `{{REPO_ROOT}}`.

### 2.5b — Import existing projects *(developer only — default no)*
> "Do you want to use your existing projects inside the harness? If so, I'll scan `{{REPO_ROOT}}` for project folders, create a `01 Projects/<folder>/` entry for each, and pull any AI/skill files (CLAUDE.md, AGENT.md, AGENTS.md, GEMINI.md, .cursor/rules, .github/copilot-instructions.md, .claude/) into the right vault locations. (yes/no, default no)"

If **no**: skip the import step entirely; the user can run `add-project-to-vault.md` later for any repos they want to bring in.

If **yes**:
- Confirm the scan path. Default is `{{REPO_ROOT}}` (captured in 2.5); allow override if their projects live somewhere else.
- List subdirectories of the scan path. Filter out: hidden folders (starting with `.`), non-directories, anything matching common non-project names (`node_modules`, `.git`, `.vscode`, `.idea`, `dist`, `build`, `target`, `out`, `vendor`, `__pycache__`).
- Show the count and the first ~20 folder names so the user can sanity-check: *"Found 14 project folders: `repo-a`, `repo-b`, …. Import all of them? (yes/no — say no to pick a subset)"*
- If "no, pick a subset", ask the user to list which folder names to include (comma-separated).
- Capture the final list as `{{IMPORT_LIST}}`.

This list flows into Step 4.6b. **Do not import yet** — defer the actual file copies until after the Step 3 confirmation.

### 2.6 — Cloud sync acknowledgement
If `{{VAULT_PATH}}` matches `/OneDrive/`, `/Dropbox/`, `/iCloud/`, `/Google Drive/`, `/pCloud/`, or similar (case-insensitive), warn:

> "Your vault is in a cloud-synced folder. The vault must **never** receive credentials, API keys, or real customer PII — those would be uploaded to the cloud provider. The skill enforces this rule via the `CLAUDE.md` it generates. Do you understand and accept? (yes/no)"

If `no`, offer to pick a different path (re-ask 2.2).

### 2.7 — Configure global CLAUDE.md
> "Add a vault pointer to `~/.claude/CLAUDE.md` so every Claude Code session knows where the vault lives? (yes/no, default yes)"

### 2.8a — Copy statusline scripts into the vault
> "Copy the bundled statusline scripts (bash + PowerShell) into `<vault>/03 Scripts/`? They're inert files until something points at them. (yes/no, default yes)"

### 2.8b — Wire the statusline into settings.json
Only ask if 2.8a was yes (no point wiring a script that wasn't copied).

> "After the scripts are copied, do you want me to run `/statusline-setup` to wire the right one as your statusline in `~/.claude/settings.json`? Saying no leaves your `settings.json` untouched — you can run `/statusline-setup` yourself any time later. (yes/no)"

**Do not** assume yes. Make the user choose explicitly. The skill **must not** edit `~/.claude/settings.json` directly — delegating to the built-in `/statusline-setup` agent (Step 4.8) is the only path the skill takes for this file.

### 2.9 — Install add-project skill
> "Install the `add-project-to-vault` reference doc into your vault's `02 Skills/`? (yes/no, default yes)"

### 2.10 — WSL Windows-side mirror *(WSL only)*
Only ask if Step 1 detected WSL **and** `{{VAULT_PATH}}` is under `/mnt/c/...` (Windows-visible). If the vault is on a Linux-only path (e.g. `~/notes` resolving to `/home/<user>/notes`), tell the user the Windows-side Claude won't be able to read the vault and skip this question.

> "I can also configure your Windows-side Claude Code (`C:\Users\<you>\.claude\`) to point at the same vault and use the PowerShell statusline. Do that? (yes/no, default yes)"

To resolve the Windows username, list `/mnt/c/Users/` and ask the user to confirm which entry is theirs (or run `cmd.exe /c echo %USERPROFILE%` from WSL).

## Step 3 — Show summary and confirm

Print a single bulleted list of every file the skill will create or modify. Group as:

- **Vault folder skeleton** (under `{{VAULT_PATH}}`)
- **Vault files** (CLAUDE.md, MEMORIES.md, today's daily note, optional add-project skill, optional statusline scripts)
- **Imported projects** *(only if user accepted 2.5b)* — show the count and the list of repos that will get a `01 Projects/<repo>/` folder. For each, indicate whether an AI file was detected (and which one). Example: `repo-a (CLAUDE.md found), repo-b (AGENTS.md found), repo-c (no AI file — stub will be created)`
- **Global CLAUDE.md** *(only if user accepted 2.7)* — `~/.claude/CLAUDE.md` appended/updated with the marker-wrapped vault pointer
- **Statusline wiring** *(only if user accepted 2.8b)* — note that `/statusline-setup` will be invoked separately to wire `~/.claude/settings.json`; the skill itself does not edit `settings.json`
- **Windows-side mirror** *(WSL only, only if user accepted 2.10)* — Windows-side `~/.claude/CLAUDE.md` updated; Windows-side `settings.json` is **not** touched (the user runs `/statusline-setup` themselves on Windows if they want the statusline there)

End with:

> "Ready to write these files? (yes/no)"

Do not touch disk until the user confirms.

## Step 4 — Execute

### 4.1 — Folder skeleton
Use Bash with the user-provided path. Quote it (paths may contain spaces):

```bash
VAULT="{{VAULT_PATH}}"
mkdir -p "$VAULT"/{"00 Notes/00 Daily","00 Notes/01 Memories","02 Skills","03 Scripts"}
```

If developer mode (Step 2.4) was **yes**, also create `01 Projects/`:

```bash
mkdir -p "$VAULT/01 Projects"
```

Don't pre-create company/team-specific scaffolding. The generic `00 Notes/` only seeds `00 Daily/` (work logs) and `01 Memories/` (cross-project knowledge). Meeting notes, release notes, PR snapshots, and architecture docs are all business-specific concepts and aren't part of the generic brain — the user can add `01 Meeting/`, `02 Releases/`, etc. themselves if their work calls for it.

Also create the current month's folder under `00 Daily/`:

```bash
MONTH_FOLDER="$(date +'%m %b')"   # e.g. "05 May"
mkdir -p "$VAULT/00 Notes/00 Daily/$MONTH_FOLDER"
```

### 4.2 — Vault CLAUDE.md
Read `<skill-dir>/templates/vault-CLAUDE.md`. Substitute placeholders:
- `{{VAULT_PATH}}` → the user's vault path
- `{{REPO_ROOT}}` → the user's repo root, or omit the developer-mode sections entirely if Step 2.4 was "no"
- `{{VAULT_NAME}}` → the vault name from 2.3

Write the result to `{{VAULT_PATH}}/CLAUDE.md` using the Write tool.

### 4.3 — MEMORIES.md
Copy `<skill-dir>/templates/memories-index.md` to `{{VAULT_PATH}}/00 Notes/01 Memories/MEMORIES.md`. No placeholders.

### 4.4 — Starter daily note ("jump off point")
Read `<skill-dir>/templates/starter-daily-note.md`, substitute `{{TODAY_HUMAN}}` (e.g. `May 7th 2026`) and `{{VAULT_NAME}}`, write to `{{VAULT_PATH}}/00 Notes/00 Daily/<MM Mon>/<Month Nth YYYY>.md`. The filename uses the same `<Month Nth YYYY>` format as the vault CLAUDE.md describes (e.g. `May 7th 2026.md`, with the `st`/`nd`/`rd`/`th` suffix).

### 4.5 — add-project-to-vault doc *(if user accepted 2.9)*
Read `<skill-dir>/templates/add-project-to-vault.md`, substitute `{{REPO_ROOT}}`, write to `{{VAULT_PATH}}/02 Skills/add-project-to-vault.md`.

### 4.5b — Import existing projects *(if user accepted 2.5b)*

For each `<repo>` in `{{IMPORT_LIST}}`:

**4.5b.1 — Folder skeleton**
```bash
mkdir -p "$VAULT/01 Projects/<repo>/00 Skills" \
         "$VAULT/01 Projects/<repo>/01 Plans" \
         "$VAULT/01 Projects/<repo>/02 Memories"
```

Write `02 Memories/MEMORIES.md` with the same template as `<skill-dir>/templates/memories-index.md`, but prefix line 1 with `[[<repo>]]`.

**4.5b.2 — Detect AI/skill files**

Look for these files in `{{REPO_ROOT}}/<repo>/`, in priority order, and stop at the first one found for the overview seed:

1. `CLAUDE.md` (Claude Code project instructions)
2. `AGENTS.md` (newer multi-agent spec)
3. `AGENT.md` (older single-agent spec)
4. `GEMINI.md` (Gemini Code Assist)
5. `.cursorrules` or `.cursor/rules/*.md` (Cursor)
6. `.github/copilot-instructions.md` (GitHub Copilot)
7. `.aider.conf.yml` / `.aiderrules` (Aider)

Track which one was used; track also which others exist (the user might want to know about all of them).

**4.5b.3 — Project overview (`<repo>.md`)**

Write `01 Projects/<repo>/<repo>.md` using this format:

```markdown
# <repo>

**Code:** {{REPO_ROOT}}/<repo>

## What It Does

[If a primary AI file was found, summarise its "purpose" / "what this is" section in 1–2 sentences. Otherwise leave a TODO: `[TODO: describe what <repo> does]`.]

## AI/Skill Files Imported

[List of every AI file found in this repo, with relative paths. Mention which one was used as the source of truth for this overview. If none were found, write "None — this overview is a stub; run `/setup-second-brain` follow-up or use `02 Skills/add-project-to-vault.md` to flesh it out."]

## Tech Stack

[If detectable from package.json / *.csproj / go.mod / pyproject.toml / Cargo.toml / Gemfile / requirements.txt, summarise. Otherwise TODO.]

## Key Concepts

[Pull from the AI file's content if it has architecture/patterns sections. Otherwise TODO.]

## Dev Commands

[Pull from the AI file's "scripts" / "commands" / "how to run" section if present. Otherwise TODO.]
```

**4.5b.4 — Copy skill-style content into `00 Skills/`**

For each of these sources in `{{REPO_ROOT}}/<repo>/`, if it exists, copy its content into `01 Projects/<repo>/00 Skills/`:

- Any `.md` file under `.claude/skills/` → `00 Skills/<original-filename>` (prefix line 1 with `[[<repo>]]` if absent)
- Any `.md` file under `.cursor/rules/` → `00 Skills/cursor-<original-filename>`
- `.cursorrules` (single file) → `00 Skills/cursor-rules.md` (wrap in a code fence if it isn't already markdown)
- `.github/copilot-instructions.md` → `00 Skills/copilot-instructions.md`

Do **not** copy the primary AI file (CLAUDE.md/AGENTS.md/etc.) into `00 Skills/` — its content already feeds the overview. Mention in the overview's "AI/Skill Files Imported" section that the primary file's content is reflected in the overview itself.

**4.5b.5 — Move plans from `.claude/plans/`**

If `{{REPO_ROOT}}/<repo>/.claude/plans/` exists:
- For each `*.md` file in it, copy (don't move — leave the original in place) to `01 Projects/<repo>/01 Plans/<filename>`.
- Prefix line 1 with `[[<repo>]]` if absent.

If `~/.claude/plans/` contains files whose names mention `<repo>`, mention them in the hand-off summary so the user can decide whether to migrate them via the full add-project-to-vault flow.

**4.5b.6 — Track results**

After looping through all imports, capture a short list for the Step 5 hand-off:
- `<repo>` — *imported (used CLAUDE.md as source)*
- `<repo>` — *imported (no AI file found, stub created)*
- etc.

If any single import fails (permissions, missing source, etc.), do not abort the rest of the imports — log it and continue.

### 4.6 — Statusline scripts *(if user accepted 2.8a)*
Copy:
- `<skill-dir>/scripts/statusline-command.sh` → `{{VAULT_PATH}}/03 Scripts/statusline-command.sh`, then `chmod +x` it.
- `<skill-dir>/scripts/statusline-command.ps1` → `{{VAULT_PATH}}/03 Scripts/statusline-command.ps1`.

This step does not modify `~/.claude/settings.json`. The scripts are inert files in the vault until 4.8 (or the user later) wires one of them as the active statusline.

### 4.7 — ~/.claude/CLAUDE.md vault pointer *(if user accepted 2.7)*
Read `<skill-dir>/templates/global-CLAUDE-snippet.md`. Substitute `{{VAULT_PATH}}`.

If `~/.claude/CLAUDE.md` doesn't exist, create it with the substituted snippet as its only content.

If it exists, check whether it already contains `<!-- second-brain-pointer:begin -->`:
- If yes, **replace** the block between `<!-- second-brain-pointer:begin -->` and `<!-- second-brain-pointer:end -->` (inclusive) with the new substituted snippet — this keeps the install idempotent across re-runs.
- If no, **append** the substituted snippet to the end of the file with a leading blank line.

### 4.8 — Wire statusline via `/statusline-setup` *(if user accepted 2.8b)*

Pick the platform-correct command for `<vault>` substituted to the actual path (quote it because of spaces):
- macOS / Linux / WSL: `bash "<vault>/03 Scripts/statusline-command.sh"`
- Windows native: `pwsh -NoProfile -File "<vault>\03 Scripts\statusline-command.ps1"`

Now invoke Claude Code's built-in `/statusline-setup` agent (it's the canonical tool for this — it handles the JSON merge, preserves other keys, and follows the same conventions across versions). Tell it explicitly which command string to set. Do **not** edit `~/.claude/settings.json` from this skill.

Concretely: instruct Claude to use the Skill tool with `skill: statusline-setup` and a brief argument explaining the desired command, e.g.:

> "Set the Claude Code statusline to run `bash \"<vault>/03 Scripts/statusline-command.sh\"`."

If `/statusline-setup` is unavailable on this machine for some reason, tell the user the script path and the exact command string and ask them to wire it themselves — still **do not** modify `settings.json` from here.

### 4.9 — WSL Windows-side mirror *(WSL only, if user accepted 2.10)*

Resolve the Windows username (Step 2.10 captured it; call it `<wuser>`).

Convert `{{VAULT_PATH}}` to its Windows form: replace `/mnt/c/` with `C:\`, then replace `/` with `\`. Capture as `{{VAULT_PATH_WIN}}`.

Repeat 4.7 against `/mnt/c/Users/<wuser>/.claude/CLAUDE.md`, but substitute `{{VAULT_PATH}}` with `{{VAULT_PATH_WIN}}` so the Windows-side import path is correct (Claude Code on Windows can't read `/mnt/c/...`).

For the Windows-side `settings.json`, the WSL-side `/statusline-setup` agent can't reach across to the Windows installation, so we can't delegate it the way Step 4.8 does. Print the exact command string the user needs and ask them to run `/statusline-setup` from inside their Windows-native Claude Code at their convenience:

> "On your Windows-native Claude Code (PowerShell), open Claude Code and run `/statusline-setup`, then paste this command when prompted: `pwsh -NoProfile -File \"{{VAULT_PATH_WIN}}\\03 Scripts\\statusline-command.ps1\"`"

Do **not** edit `/mnt/c/Users/<wuser>/.claude/settings.json` directly — even though it's writable from WSL, this skill has a hard rule against modifying any `settings.json` from inside its own flow.

If `/mnt/c/Users/<wuser>/.claude/` doesn't exist, create it with `mkdir -p` so the CLAUDE.md pointer file from 4.7 has a directory to live in. The settings.json is never touched.

## Step 5 — Hand off

Print a short summary:

> Done. Your vault is at `{{VAULT_PATH}}`.
>
> - **Jumping-off point:** `{{VAULT_PATH}}/00 Notes/00 Daily/<MM Mon>/<today>.md` — open it in Obsidian and start logging tasks.
> - **Conventions:** see `{{VAULT_PATH}}/CLAUDE.md`.
> - **Add a project:** `{{VAULT_PATH}}/02 Skills/add-project-to-vault.md` walks through onboarding a new repo into the vault.
> - **Statusline:** the bundled scripts are at `{{VAULT_PATH}}/03 Scripts/`. If you ran `/statusline-setup`, restart Claude Code to see it. If you skipped that step, run `/statusline-setup` whenever you're ready and point it at the script.
>
> Re-run `/setup-second-brain` (or `/setup-brain` / `/setup-harness`) any time to add components you skipped — it's idempotent.

If projects were imported in Step 4.6b, append:

> **Imported N projects** from `{{REPO_ROOT}}`:
> - `<repo>` — used `CLAUDE.md` as source
> - `<repo>` — used `AGENTS.md` as source
> - `<repo>` — no AI file found, stub created (open `01 Projects/<repo>/<repo>.md` and fill in the TODOs)
>
> For any repo where the overview is a stub or you want richer content (skills extraction, release-notes wiring, cross-project links), run the full workflow at `{{VAULT_PATH}}/02 Skills/add-project-to-vault.md`.

If WSL Windows-side mirror was wired, mention it explicitly so the user knows to test the Windows-side Claude Code separately.

## Idempotency rules

- **Folder skeleton:** `mkdir -p` is safe to repeat.
- **vault CLAUDE.md, MEMORIES.md, add-project-to-vault.md:** write tools overwrite; if the user has hand-edited any of these and re-runs the skill, **ask before overwriting**. Diff first if possible (`diff <existing> <new>`) and let the user choose.
- **Daily note:** if today's daily note already exists, do not overwrite — leave it alone.
- **Statusline scripts:** safe to overwrite (they're verbatim copies from the bundle).
- **~/.claude/CLAUDE.md pointer:** marker-wrapped, replace-or-append pattern (see 4.7).
- **~/.claude/settings.json:** never edited from this skill. All statusline wiring goes through Claude Code's `/statusline-setup` agent, which the skill invokes only when the user explicitly opts in at 2.8b.
- **Imported projects:** if `01 Projects/<repo>/` already exists, **ask before overwriting `<repo>.md`** — the user may have customised it. The folder skeleton (`00 Skills/`, `01 Plans/`, `02 Memories/`) is safe to re-create idempotently. Skill-style files copied into `00 Skills/` should not be overwritten without asking; offer to skip those that already exist.

## Path-format gotchas

- macOS and Linux paths use `/`, Windows native paths use `\`. Quote any path with spaces.
- WSL: vault paths like `/mnt/c/Users/<u>/Documents/notes` are visible from both Linux and Windows. The Linux path goes into the Linux-side Claude Code config; the converted Windows path (`C:\Users\<u>\Documents\notes`) goes into the Windows-side config. Don't swap them.
- Cloud-sync folder paths (OneDrive, iCloud, etc.) frequently contain spaces — always quote.

## What this skill does *not* do

- Install Obsidian itself — assumes the user has it.
- Run `git init` on the vault — some users sync via OneDrive, others via git. Leave the choice to them.
- Push anything anywhere.
- Touch `04 Members/`, `Domain Glossary.md`, or any company-specific scaffolding — those are for the user to add later if they want.
