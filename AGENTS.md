# Warmane Addons

## Context

- This project contains multiple WoW addons for **Wrath of the Lich King 3.3.5a**
- Target server: **Warmane**
- This is a **strict 3.3.5a environment** (NOT retail, NOT classic 3.4.x)

---

## Core Rule (VERY IMPORTANT)

- ALWAYS prefer functions from: `3.3.5-interface-files/`
- Treat this folder as the **primary source of truth**

### Interpretation rules:

- If a function is present there → it **exists and is valid**
- If a function is NOT present there → assume:
  - it does NOT exist in 3.3.5a
  - OR is implemented differently

- Do NOT use modern (retail / classic 3.4+) API unless explicitly confirmed compatible

---

## Allowed sources (priority order)

1. `3.3.5-interface-files/` (PRIMARY, most reliable)
2. Existing 3.3.5a addons (pattern reference)
3. Trusted WotLK-era documentation
4. https://www.wowhead.com/wotlk (LOW priority, may differ - 3.4.3)

---

## Coding rules

- Prefer **existing patterns** from FrameXML over inventing new solutions
- Reuse Blizzard-style structures (frames, events, handlers)
- Avoid unnecessary abstractions
- Keep code simple and compatible with Lua used in 3.3.5a
- Add simple yet descriptive one line comments to the code

---

## API safety rules

- NEVER hallucinate API functions
- NEVER assume retail API exists
- If unsure:
  - search in `3.3.5-interface-files/`
  - if not found → say it's unsupported

---

## Development workflow

When implementing features:

1. Search for similar implementation in `3.3.5-interface-files/`
2. Reuse structure/pattern
3. Adapt minimally
4. Keep compatibility over elegance

---

## External sources

- https://www.wowhead.com/wotlk

---

## Notes

- If a high-quality 3.3.5a-compatible source (like a full API dump or addon pack) is found:
  - DO NOT auto-import
  - Suggest it in chat for manual review
