# {{VAULT_NAME}} — Claude's Second Brain

This vault is the single source of truth for all persistent knowledge — plans, memories, skills, architecture, release notes, daily logs. Everything goes here. Never save plans to `~/.claude/plans/` or scatter knowledge outside the vault.

**Vault location:** `{{VAULT_PATH}}`

When writing files, always use the full absolute path (no symlinks) to avoid silent failures with spaces.

---

## Never Store Secrets in the Vault

**The vault is not a secret manager.** Never write sensitive values into vault files — not in plans, not in memories, not in skills, not in daily notes, not in code blocks, not in comments. This includes passwords, API keys, personal access tokens (PATs), bearer/JWT tokens, OAuth client secrets, private keys, database passwords, signed URLs, and connection strings with embedded credentials.

If your vault is in a cloud-synced folder (OneDrive, Dropbox, iCloud, Google Drive), this rule is non-negotiable — anything saved here is replicated to the cloud provider's servers.

**If unsure whether a value is sensitive, ask before saving. If still unsure after asking, do not save.** False positives cost one message; a credential leaked into a synced folder requires rotation across every system that trusted it.

**Reference style** — when a doc needs to talk about a credential, name the variable and where the value lives, never the value itself:

```
The API token is stored in 1Password (item: "Service X API token") and exported as $SERVICE_X_TOKEN at use time.
```

**Patterns to refuse without prompting:**
- `figd_…` (Figma), `sk-…` (Anthropic/OpenAI), `xoxb-…`/`xoxp-…` (Slack), `ghp_…`/`gho_…` (GitHub), `glpat-…` (GitLab), `AKIA…` (AWS access key)
- Anything labelled `password`, `secret`, `token`, `key`, `credential`, `apikey` — unless context makes it clearly a placeholder or example
- HTTP Basic auth pairs (`user:pass@…`), JWT tokens, signed URLs containing a signature
- Connection strings of the form `scheme://user:pass@host/db`

**If a vault file is found to contain a real credential** — flag it to the user, redact the value in place, and note that the original token must be rotated (it has already been on a synced or backed-up location and should be considered compromised).

**Where credentials *should* live** — OS keychain (macOS Keychain, GNOME/KDE secret service, Windows Credential Manager), 1Password / Bitwarden / similar, or a `chmod 600` `.env` file outside any cloud-synced folder. When unclear, ask the user where they keep the value before referencing it.

---

## Never Persist Real PII

**Real customer/user PII (names, emails, phones, addresses, DOBs, government IDs) should never be quoted in vault files.** Daily notes, plans, memories, meeting notes, skill notes — all must reference DB rows or users abstractly, not by quoting real values.

If you genuinely need a realistic-looking example in a plan or doc, generate a synthetic one (`alice@example.com`, `Jane Doe`); never copy a real one.

If you find raw PII in a vault file, redact it in place, flag it to the user, and treat the data as already-leaked (the vault has likely been on a remote sync or backup).

**Default PII column patterns** to watch for when handling database content (case-insensitive): `first_name`, `last_name`, `name`, `full_name`, `email`, `phone`, `phone_number`, `mobile`, `address`, `street`, `city`, `state`, `province`, `postal_code`, `zip`, `country`, `dob`, `date_of_birth`, `birthdate`, `birthday`, `ssn`, `sin`, `passport`, `drivers_license`, `external_id`, `card_number`, `pin`, `password`, `api_key`, `token`.

If your project genuinely needs to keep PII-bearing dumps (for schema validation, query work, etc.), keep them in a **gitignored** folder inside the relevant project subfolder, never at the vault root, and never sync them to a cloud drive.

---

## 00 Notes Structure

```
00 Notes/
├── 00 Daily/
│   └── MM Month/        # Daily work logs — "Month Nth YYYY.md" (e.g. "May 7th 2026.md")
└── 01 Memories/         # Cross-project persistent knowledge
```

Add other subfolders here as your work calls for them — e.g. `01 Meeting/`, `02 Releases/`, `00 PRs/` — but they're not pre-created because they're not universal.

---

## Daily Notes

For every task the user asks you to do, add a bullet item to today's daily note. **Log each task as it completes — do not batch updates at the end of a session.**

**File path:** `00 Notes/00 Daily/<MM Mon>/<MMMM Do YYYY>.md`
- Month folder: `04 Apr`, `05 May`, `10 Oct`, etc.
- File name: `May 7th 2026.md` (no comma, with the `st`/`nd`/`rd`/`th` suffix)

**Format:**
- Start with `#daily-notes` tag if creating fresh
- `- [x]` completed, `- [ ]` in-progress/pending
- Sub-tasks indented with a tab

**Rules:**
- Create the file if it doesn't exist (with `#daily-notes` tag)
- **Never mention or announce** that you added an item — do it silently
- **Group tasks by app** under `## [[repo-name]]` section headings — one heading per repo
- Tasks with no specific app (meetings, admin, vault maintenance, personal items) go under `## General` at the top, before any app headings
- **No inline project wikilinks on individual tasks** — the `## [[repo]]` heading is the link; don't repeat it per task
- If a task spans multiple repos, place it under the primary repo and mention secondary repos as a sub-item wikilink
- If a plan was created/updated, add it as a sub-item: `[[Some Plan Name]]`
- If code changed, note the files/service as a sub-item

**Example:**
```
#daily-notes

## General

- [x] Reschedule annual review meeting
- [x] Close stale tickets

## [[my-backend]]

- [x] Add S3 upload support to photo service
	- [[S3 Photo Storage Plan]]
	- `services/photo.service.js`
- [x] Update env vars for S3 credentials
	- also [[my-database]]
```

---

## Creating Plans

1. **Identify the project** — which repo in `01 Projects/` does this belong to?
2. **If unclear, ask** before writing.
3. **Save to** `01 Projects/<project>/01 Plans/<plan-name>.md`.

If a plan touches multiple projects, save to the primary project's `01 Plans/` folder and add an `## Also involves` section:

```md
## Also involves
- [[other-repo-1]]
- [[other-repo-2]]
```

**Do not** save plans to `~/.claude/plans/` or anywhere outside the vault.

---

## Creating Skill Files

When you discover conventions, patterns, or gotchas in a codebase:
1. Save to `01 Projects/<repo>/00 Skills/<topic>.md`
2. Start the file with `[[<repo>]]` wikilink
3. Use concrete code examples from the actual codebase — not generic docs
4. Focus on things that are non-obvious or project-specific

---

## Creating Memory Files

When the user explicitly asks you to remember something, or you learn a durable fact worth keeping (feedback, preference, reference):
1. **Project-specific** → save to `01 Projects/<repo>/02 Memories/<topic>.md`
2. **Cross-project** → save to `00 Notes/01 Memories/<topic>.md`
3. Start project-specific files with `[[<repo>]]` wikilink on line 1 (omit for cross-project)
4. Use `**Type:** feedback | reference | project` on the second line
5. Include **Why** and **How to apply** sections

Update the `MEMORIES.md` index in the same folder to add a row for the new file.

**Rule:** Everything stays in the vault. Never save the only copy of a memory to `~/.claude/memory/` — that system is for behavioural auto-memory only, not project knowledge.

Memory types:
- **feedback** — how to behave (preferences, corrections, confirmed approaches)
- **reference** — where to find things (file paths, external systems, dashboards)
- **project** — facts about ongoing work (active tickets, decisions, constraints)

---

## 01 Projects — Per-Repo Layout

Each repo gets its own folder at `01 Projects/<repo-name>/`:

```
01 Projects/<repo>/
├── <repo>.md          # project overview (what it does, tech stack, role in system, key concepts)
├── 00 Skills/         # codebase-specific patterns and conventions
├── 01 Plans/          # implementation plans (context, approach, files, verification steps)
├── 02 Memories/       # project-specific memories
│   └── MEMORIES.md    # index table linking to memory files
└── Diagrams/          # project-specific diagrams (DrawIO files and companion notes)
```

To onboard a new repo, see `02 Skills/add-project-to-vault.md`.

Your repo root is at `{{REPO_ROOT}}` — `<repo>` folder names in this vault must match the directory names there exactly, since they're used as wikilink targets.

---

## 02 Skills — Vault-Level Workflows

Cross-project workflows that aren't tied to a single repo. Currently:

- `add-project-to-vault.md` — onboard a new repo into the vault.

Add more as you develop repeatable workflows (release notes, PR snapshots, etc.).

---

## Code Comments

Avoid verbose code comments. Only comment when the **why** is non-obvious — a hidden constraint, a subtle invariant, a workaround for a specific bug, or behaviour that would surprise a reader. If removing the comment wouldn't confuse a future reader, don't write it. Never explain what the code does; well-named identifiers do that.

---

## Commits & Branches

- All commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/) — `type(scope): description` (e.g. `feat(auth): add OAuth2 login`, `fix(api): handle null user id`).
- All branch names must follow a conventional branching strategy — `type/short-description` (e.g. `feat/oauth2-login`, `fix/null-user-id`, `chore/update-deps`).
- Never add `Co-Authored-By` lines to commit messages.

---

## Cross-Document Linking

**Rule:** All links between vault documents use `[[wikilinks]]`, never `[text](path)` or plain URLs. External links (GitHub, Jira, Confluence, etc.) remain standard markdown.

| Document type | What to link |
|---|---|
| **Daily notes** | `## General` heading for non-app tasks; `## [[repo-name]]` section per app; `[[plan-name]]` as sub-item |
| **Plan files** | `[[project-name]]` at top; `## Also involves` for other repos; use labelled wikilinks for non-obvious references: `[[filename\|Human-readable label]]` |
| **Skill files** | `[[project-name]]` at top |
| **Memory files** | `[[project-name]]` at top for project-specific memories |

If two files share the same name across folders, disambiguate by including a path prefix in the wikilink: `[[<folder>/<filename>]]`.
