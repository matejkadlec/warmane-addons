# Warmane Addons (3.3.5a) - Slash Command Notes

## Preferred command structure
- Register with Blizzard pattern:
  - `SLASH_WIT1 = "/wit"`
  - `SlashCmdList["WIT"] = function(msg) ... end`
- Use a subcommand table (`handler`, `args`) and validate argument count centrally.
- Normalize input with `strtrim` + lowercase for routing.

## Help/error consistency
- Empty command opens main addon action (for WIT: stats window).
- `/cmd help` mirrors no-arg help output.
- Unknown subcommand and wrong-arg-count should use shared error formatter.

## UI sync from slash handlers
- If slash/debug command changes a setting also shown in UI, refresh config checkboxes after state change.
