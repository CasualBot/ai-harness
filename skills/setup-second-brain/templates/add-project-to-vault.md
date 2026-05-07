# Add Project to Vault

When asked to "add `<repo>` to the vault", "set up `<repo>` in the notes", or "onboard `<repo>`", follow this checklist in order.

---

## Step 0 — Confirm the Project Name

Before doing anything else, ask:

> "What is the name of the project/repo you want to add to the vault?"

Wait for the answer. The repo name must match the folder name in `{{REPO_ROOT}}/` exactly — this is used for all paths, wikilinks, and git commands throughout the process. Do not proceed until confirmed.

Verify the repo exists:
```bash
ls {{REPO_ROOT}}/<repo>/
```

If the directory is not found, tell the user and stop.

---

## Step 1 — Create Folder Structure

```
01 Projects/<repo>/
├── <repo>.md          ← project overview (write in Step 2)
├── 00 Skills/         ← skill files (write in Step 3)
├── 01 Plans/          ← plans (write in Step 4)
└── 02 Memories/
    └── MEMORIES.md    ← empty index to start
```

Create the `MEMORIES.md` index:

```markdown
[[<repo>]]

| File | Summary |
|------|---------|
```

---

## Step 2 — Project Overview (`<repo>.md`)

**First check for `AGENT.md` or `CLAUDE.md` in the repo root** — these are the best source of truth:

```bash
ls {{REPO_ROOT}}/<repo>/AGENT.md 2>/dev/null
ls {{REPO_ROOT}}/<repo>/CLAUDE.md 2>/dev/null
```

If found, read them fully — they contain architecture, conventions, and dev commands. Use that as the foundation for the overview.

If not found, explore the codebase to determine:
- What the repo does and its role in the system
- Tech stack (language, framework, key dependencies from `package.json` / `*.csproj` / `go.mod` / `pyproject.toml` / etc.)
- Entry points, key files or directories
- How it communicates with other repos

**Overview format:**

```markdown
# <repo>

**Code:** {{REPO_ROOT}}/<repo>

## What It Does

[1–2 sentences: purpose + what it produces/exposes]

## Tech Stack

| Layer | Technology |
|-------|-----------|
| ...   | ...       |

## Key Concepts

### [Pattern or subsystem name]
[Concrete explanation — not generic docs. Reference actual files and patterns.]

## Role in System

[How it connects to other repos. Use [[wikilinks]] for every repo named.]

## Dev Commands

```bash
[key run/build/test commands]
```

## Standards & Conventions

[Non-obvious rules — naming, file structure, anything a new developer would get wrong]
```

---

## Step 3 — Skills Extraction

Explore the codebase and write one or more skill files in `00 Skills/`. Start from the AGENT.md/CLAUDE.md if present.

**What to look for:**
- Non-obvious patterns (DI conventions, base classes, naming rules)
- Framework-specific quirks (custom hooks, mixin usage, inherited config)
- Testing setup (how to run, test helpers, what NOT to mock)
- Cross-repo integration points (how it calls other services, event names, shared contracts)
- Gotchas (silent failures, ordering requirements, environment-specific behaviour)

**Do not document:** things obvious from the language/framework docs, or things a developer would find by reading the code naturally.

**Skill file format:**

```markdown
[[<repo>]]

# <Topic> Patterns

[Concrete patterns with actual file references and code examples from this codebase]
```

Name the file descriptively: `patterns.md`, `socketio-rpc.md`, `migration-conventions.md`, etc.

---

## Step 4 — Plans

Check two places for existing plans that should move into the vault:

```bash
# 1. Claude Code plan files
ls ~/.claude/plans/ | grep -i <repo>

# 2. Any .claude/ directory inside the repo
ls {{REPO_ROOT}}/<repo>/.claude/ 2>/dev/null
```

Move any found plans to `01 Projects/<repo>/01 Plans/<plan-name>.md`.

Plans that touch multiple repos go in the primary repo's `01 Plans/` with an `## Also involves` section listing the other repos as wikilinks.

---

## Step 5 — Cross-Project Links

Search the vault for any plain-text mentions of the repo name that should be wikilinks:

```bash
grep -rl "<repo>" "$VAULT" --include="*.md" | while read f; do
  grep -n "<repo>" "$f" | grep -v "\[\[<repo>\]\]"
done
```

Convert plain mentions in other project overviews and any cross-cutting docs to `[[<repo>]]`. Use `[[wikilinks]]` for all vault-internal references. Never use plain paths or markdown links between vault documents.

---

## Checklist

- [ ] `01 Projects/<repo>/` folder created with `00 Skills/`, `01 Plans/`, `02 Memories/MEMORIES.md`
- [ ] `<repo>.md` overview written (AGENT.md/CLAUDE.md used if present)
- [ ] At least one skill file in `00 Skills/`
- [ ] Plans moved from `~/.claude/plans/` or repo `.claude/` if found
- [ ] Vault searched for plain-text repo mentions; converted to wikilinks
