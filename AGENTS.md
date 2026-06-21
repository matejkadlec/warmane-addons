# Warmane Addons

## Context

- This project contains multiple WoW addons for **Wrath of the Lich King 3.3.5a**
- Target server: **Warmane**
- This is a **strict 3.3.5a environment** (NOT retail, NOT classic 3.4.x)
- First-party AddOns live in `addons/`; third-party backported AddOns live in `backports/`

---

## Core Rules (VERY IMPORTANT)

- ALWAYS prefer functions from: `3.3.5-interface-files/`
- Treat this folder as the **primary source of truth**
- IMPORTANT: Keep this file and `README.md` updated when AddOns are added, removed, renamed, backported, or when user-facing behavior, slash commands, installation/sync behavior, screenshots, or documentation-relevant details change

## Communication Rules

- When making code or file changes, summarize the changes you did at the end of the response
  - Only mention core/bigger changes (for smaller changes overall, mention the small change)
  - Do not include a summary when only answering a question and making no changes to any files
    (but if even one change was done to ANY file, then include it)
- After changing any AddOn files inside `addons/` or `backports/`, run `scripts/sync-addons.sh` before replying to the user
  - The script loads developer-specific paths from `.env.sync-addons`
  - The template file `.env.sync-addons.example` shows the required variables
  - The script syncs each top-level AddOn folder in `addons/` and `backports/` that contains a `.toc` file, including all nested files and subfolders inside it
- After syncing changed addon files, tell the user what was updated and whether `/reload` or a full restart is needed
  - If sync succeeds: "I updated {AddOn Name} for you. Please {run "/reload"}/{restart the game} for these changes to take effect in-game."
  - If sync fails or is unavailable: explain that the sync did not complete and tell the user to update the AddOn manually
  - Use **restart the game** when a `.toc` file changed or Lua files were added/removed
  - Use **run "/reload"** only for changes where a UI reload is enough
  - Whole message bold

### Interpretation Rules

- If a function is present there → it **exists and is valid**
- If a function is NOT present there → assume:
  - it does NOT exist in 3.3.5a
  - OR is implemented differently

- Do NOT use modern (retail / classic 3.4+) API unless explicitly confirmed compatible
  - You are allowed to break this rule if you run out of all other options

---

## Allowed Sources (priority order)

1. `3.3.5-interface-files/` (PRIMARY, most reliable)
2. Existing 3.3.5a addons (pattern reference)
3. Trusted WotLK-era documentation
4. https://www.wowhead.com/wotlk (LOW priority, may differ - 3.4.3)

---

## Coding Rules

- Prefer **existing patterns** from FrameXML over inventing new solutions
- Reuse Blizzard-style structures (frames, events, handlers)
- Avoid unnecessary abstractions
- Split large addon main files into folders/modules when adding a substantial subsystem, but avoid tiny one-off files
- Keep code simple and compatible with Lua used in 3.3.5a
- Add simple yet descriptive one line comments to the code

---

## Current AddOn Inventory

### First-Party AddOns (`addons/`)

| AddOn | Shortname | Slash command | Notes |
| ----- | --------- | ------------- | ----- |
| WarmaneInstanceTracker | WIT | `/wit` | Instance run tracking, stats table, config, manual tracking, debug tools |
| WarmaneWGReminder | WWR | `/wwr` | Wintergrasp timing reminders; level 80 only |
| WarmaneChatCopy | WCC | `/wcc` | Click chat messages/channel names to copy text |
| WarmaneTrackingAid | WTA | `/wta` | Hunter tracking switcher; Hunters only |
| WarmaneHealerMana | WHM | `/whm` | Healer low-mana party warning |
| WarmaneHealerProtection | WHP | `/whp` | Healer aggro party warning |
| WarmaneNotAway | WNA | `/wna` | Automatically re-enables/uses Blizzard AFK auto-clear |

### Backported AddOns (`backports/`)

| AddOn | Slash command | Notes |
| ----- | ------------- | ----- |
| MBB (MinimapButtonBag) | `/mmbb`, `/minimapbuttonbag` | Third-party minimap button bag, backported for Warmane/3.3.5a |

---

## Backported AddOn Rules

- Treat `backports/` as separate from first-party `addons/`
- Backported AddOns are third-party AddOns being fixed for Warmane/3.3.5a compatibility
- Keep fixes conservative and focused on compatibility, bug fixes, and robustness
- Preserve the original AddOn name, folder name, slash commands, chat style, and user-facing behavior unless a bug requires changing them
- Do not apply first-party Warmane AddOn naming, shortname, slash command, or chat formatting rules to `backports/` unless the backported AddOn already follows them
- Do not move backported AddOns into `addons/` or make first-party AddOns depend on them
- When adding or updating a backported AddOn `.toc`, keep original attribution and mark the backport:
  - `## Author: Original Author (backported by Matej Kadlec)`
  - `## X-Repository: https://github.com/matejkadlec/warmane-addons`
- Document each maintained backported AddOn in the README under `Backported AddOns`

---

## WoW Chat Message Rules

- These rules apply to first-party Warmane AddOns in `addons/`
- Backported AddOns in `backports/` keep their original chat/message style unless intentionally fixed
- All addon chat messages use a `[SHORTNAME]` prefix
- Prefix `[SHORTNAME]` is **all orange** (`|cFFFF8000`)
  - Format: `|cFFFF8000[PREFIX]`
- Regular message text: **yellow** (`|cFFFFFF00`)
- Important values (instance names, creature types, numbers): **orange** (`|cFFFF8000`)
- Error text: **red** (`|cFFFF0000`) with same orange prefix
- Loading messages use: `FormatMessage("PREFIX", "AddonFullName loaded")`

---

## Slash Command Rules

- These rules apply to first-party Warmane AddOns in `addons/` that expose slash commands
- Backported AddOns in `backports/` keep their original slash commands and parser behavior unless the user asks to normalize them
- Register using Blizzard pattern: `SLASH_NAME1 = "/cmd"` + `SlashCmdList["NAME"]`
- Command name is the AddOn shortname in lowercase (e.g. `/wwr`, `/wit`, `/whm`)
- Typing `/cmd` with no arguments shows help (list of available subcommands)
  - Exception: `/wit` with no arguments opens or closes the stats table; `/wit help` shows help
  - Exception: `/wwr` with no arguments behaves like `/wwr when`
- `help` subcommand also shows the same help output
- All first-party slash commands include `on` and `off` subcommands that enable/disable the AddOn without requiring a UI reload
- In help output, `on` and `off` are listed immediately after the bare `/cmd` entry when that entry is shown, otherwise before other subcommands
- Help format: one line per subcommand, indented with two spaces:
  - `  |cFFFF8000/cmd subcommand |cFFFFFF00- Description of the subcommand|r`
- Unknown subcommand → error: `"find subcommand 'X'. Use /cmd help to see available commands"`
- Wrong argument count → error: `"execute command. Wrong number of arguments for 'X' (expected N)"`
- Error messages use `FormatErrorMessage` (orange prefix, red body)
- Input is trimmed and lowercased before command lookup; preserve raw argument text where case or spacing matters, such as quoted instance names
- Define subcommands in a `SUBCOMMANDS` table with `handler` and `args` fields
- Current first-party slash commands:
  - `/wit`: bare command opens/closes stats table; `on`, `off`, `config`, `status`, `update`, `start`, `-s`, `end`, `end -s`, `-e`, `reset`, `pause`, `-p`, `continue`, `-c`, `debug`, `help`, `-h`
  - `/wwr`: bare command behaves like `when`; `on`, `off`, `when`, `help`, `-h`
  - `/wcc`: bare command behaves like `help`; `on`, `off`, `help`
  - `/wta`: bare command behaves like `help`; `on`, `off`, `help`
  - `/whm`: `on`, `off`, `help`, `delay`, `delay <seconds>`, `threshold`, `threshold <integer>`
  - `/whp`: `on`, `off`, `help`, `delay`, `delay <seconds>`
  - `/wna`: bare command behaves like `help`; `on`, `off`, `help`

---

## API Safety Rules

- NEVER hallucinate API functions
- NEVER assume retail API exists
- If unsure:
  - search in `3.3.5-interface-files/`
  - search in https://github.com/widxwer/Questie
  - if not found → say it's unsupported

---

## Development Workflow

When implementing features:

1. Search for similar implementation in `3.3.5-interface-files/`
2. Reuse structure/pattern
3. Adapt minimally
4. Keep compatibility over elegance
5. Update `AGENTS.md` and `README.md` in the same change when the work changes AddOn inventory, commands, setup/sync behavior, or documented user-facing behavior

---

## External Sources

- https://github.com/widxwer/Questie
- https://www.wowhead.com/wotlk
- https://wowpedia.fandom.com/wiki/
- https://us.forums.blizzard.com/en/wow/
