# Warmane Addons (3.3.5a) - UI Notes

## Esc-close behavior for custom frames
- WoW uses `UISpecialFrames` for `Esc` closing.
- If multiple custom frames are open, close order is affected by `UISpecialFrames` membership.
- Practical pattern:
  - Remove both custom frame names from `UISpecialFrames`.
  - Re-add only the top-priority frame (e.g., config first, main second).
  - Recompute this on frame `OnShow` and `OnHide`.

## Button styling in custom frames
- `UIPanelButtonTemplate` gives reliable text centering and consistent 3.3.5a behavior.
- For tinted styles (red button + yellow text):
  - Keep panel textures (`UI-Panel-Button-Up/Down/Highlight`)
  - Apply vertex color on normal/pushed/highlight textures.
  - Color button label font string explicitly.

## Frame modularization approach
- Keep event/combat logic in main addon file.
- Move UI builders into `ui/` modules (stats window, config window, special-frame behavior).
- Keep shared constants in `vars/` to avoid repeated hardcoded values.
