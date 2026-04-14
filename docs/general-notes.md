# Warmane Addons (3.3.5a) - General Notes

## COMBAT_LOG_EVENT_UNFILTERED arguments (3.3.5a)
- For tracker kill handling, this pattern is valid in WotLK 3.3.5a:
  - `local _, subevent, _, _, _, dstGUID, dstName = ...`
- `dstGUID` can be parsed for NPC ID (entry ID) and matched against static boss maps.

## Instance identity is not always stable by raw text
- `GetRealZoneText()` / zone text can differ from saved boss-map strings.
- Better approach for party dungeons:
  - Use `IsInInstance()` + `GetInstanceInfo()` for active instance context.
  - Normalize names before comparison (case, spacing, punctuation, suffixes like `(1)`).

## Tracker state safety
- On zone/world transitions, clear stale tracking if player is no longer in a party instance.
- Re-entry / corpse-run flows should not create a new run if still in the same instance context.

## SetItemRef forwarding
- In 3.3.5a, forward full args when proxying item refs:
  - `SetItemRef(link, text, button, chatFrame)`
- Dropping `chatFrame` can break default hyperlink behavior in some contexts.
