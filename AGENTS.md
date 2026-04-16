# Warmane Addons

## Context

- This project contains multiple WoW addons for **Wrath of the Lich King 3.3.5a**
- Target server: **Warmane**
- This is a **strict 3.3.5a environment** (NOT retail, NOT classic 3.4.x)

---

## Core Rules (VERY IMPORTANT)

- ALWAYS prefer functions from: `3.3.5-interface-files/`
- Treat this folder as the **primary source of truth**

## Communication Rules

- When making code or file changes, summarize the changes you did at the end of the response
  - Only mention core/bigger changes (for smaller changes overall, mention the small change)
  - Do not include a summary when only answering a question and making no changes to any files
    (but if even one change was done to ANY file, then include it)
- After changing any addon files inside `addons/`, run `scripts/sync-addons.sh` before replying to the user
  - The script loads developer-specific paths from `.env.sync-addons`
  - The template file `.env.sync-addons.example` shows the required variables
  - The script syncs each top-level addon folder that contains a `.toc` file, including all nested files and subfolders inside it
- Remind the user to replace the updated AddOn in their WoW folder only after making changes to addon files (below the Summary)
  - Only include this reminder when changing addon files, inside `addons/` folder
  - "Please update your {AddOn Name} with the newest version and {run "/reload"}/{restart the game}
    for this changes to take effect in-game."
    - the "run "/reload"" or "restart the game" text will depends what changes were done and whether
      /reload is enough, or if full restart is needed (added/removed Lua files, changed to TOC file, ...)
    - if `.toc` file was changed, always use **restart the game** (do not use `/reload`)
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
- Keep code simple and compatible with Lua used in 3.3.5a
- Add simple yet descriptive one line comments to the code

---

## WoW Chat Message Rules

- All addon chat messages use a `[SHORTNAME]` prefix
- Prefix `[SHORTNAME]` is **all orange** (`|cFFFF8000`)
  - Format: `|cFFFF8000[PREFIX]`
- Regular message text: **yellow** (`|cFFFFFF00`)
- Important values (instance names, creature types, numbers): **orange** (`|cFFFF8000`)
- Error text: **red** (`|cFFFF0000`) with same orange prefix
- Loading messages use: `FormatMessage("PREFIX", "AddonFullName loaded")`

### Addon Shortnames

| Addon                  | Shortname |
| ---------------------- | --------- |
| WarmaneInstanceTracker | WIT       |
| WarmaneTrackingAid     | WTA       |
| WarmaneWGReminder      | WWR       |
| WarmaneChatCopy        | WCC       |

---

## Slash Command Rules

- Register using Blizzard pattern: `SLASH_NAME1 = "/cmd"` + `SlashCmdList["NAME"]`
- Command name is the addon shortname in lowercase (e.g. `/wwr`, `/wit`)
- Typing `/cmd` with no arguments shows help (list of available subcommands)
- `help` subcommand also shows the same help output
- Help format: one line per subcommand, indented with two spaces:
  - `  |cFFFF8000/cmd subcommand |cFFFFFF00- Description of the subcommand|r`
- Unknown subcommand → error: `"find subcommand 'X'. Use /cmd help to see available commands"`
- Wrong argument count → error: `"execute command. Wrong number of arguments for 'X' (expected N)"`
- Error messages use `FormatErrorMessage` (orange prefix, red body)
- Input is trimmed and lowercased before processing
- Define subcommands in a `SUBCOMMANDS` table with `handler` and `args` fields

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

---

## External Sources

- https://github.com/widxwer/Questie
- https://www.wowhead.com/wotlk
- https://wowpedia.fandom.com/wiki/
- https://us.forums.blizzard.com/en/wow/
