# Warmane AddOns Collection

![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)

Collection of custom World of Warcraft addons specifically developed for Warmane's WotLK (3.3.5a) servers.

A big thanks goes to the owner of [`3.3.5-interface-files`](https://github.com/wowgaming/3.3.5-interface-files) GitHub repository, which I'm using a lot during the development.

## 📋 Table of Contents

- [Available AddOns](#-available-addons)
  - [WarmaneInstanceTracker](#warmaneinstancetracker-wip)
  - [WarmaneTrackingAid](#warmanetrackingaid)
  - [WarmaneChatCopy](#warmanechatcopy)
  - [WarmaneWGReminder](#warmanewgreminder)
- [Screenshots](#-screenshots)
- [Installation](#️-installation)
- [Feedback & Development](#-feedback--development)
- [Contributing](#-contributing)
- [Support](#-support)

## 📦 Available AddOns

### WarmaneInstanceTracker

- This addon is heavily inspired by [Nova Instance Tracker](https://www.curseforge.com/wow/addons/nova-instance-tracker).
- Tracks completed dungeon runs and stores both run history and aggregated per-character/per-instance stats.
- Main table UI (`/wit`) shows: `Character | Instance | Total Runs | Average XP | Average Time | Fastest Time`.
- Instance names in the table include level ranges (i.e. `Wailing Caverns (15-25)`)
- Settings window (`/wit config`) includes persistent checkboxes:
  - User settings: instance tracking, party completion message
  - Developer settings: debug printing, debug logging
- Debug commands (`/wit debug ...`) include `on|off`, `state`, `target`, `simulate "Instance Name" duration xp`, and `log on|off|status|clear`.
- On completion, can post one summary line to party chat:
  - `[WIT] <instance> finished in <hh:mm:ss> | XP gained: <xp> | Runs till next level: <value>`
- SavedVariables are split for clarity:
  - `InstancesData` (runs + aggregated stats)
  - `SettingsData` (user/developer toggles)
  - `DebugData` (debug death log)

### WarmaneTrackingAid

🎯 Automatically switches Hunter tracking based on target type.

- Smart tracking switching for Hunters
- Triggers only for neutral/hostile targets
- GCD-aware to prevent false switching
- Implemented to work with manual tracking switching as well

### WarmaneChatCopy

📋 Makes chat messages easily copyable.

- Click on the channel name or, if the message has no channel, into the message directly to copy messages into a new window
- You can copy messages from the copy window with `CTRL-C`
- Works with all message types (channels, system, say, ...)
- Supports multiple messages in the copy window
- Clear button to reset the copy window content

### WarmaneWGReminder

⏰ Reminds players about upcoming Wintergrasp battle.

- Uses the in-game `GetWintergraspWaitTime()` API for accurate battle timing
- Shows notifications at 30, 15, and 5 minutes before battle
- Also shows notification right after the battle begins and ends
- Addon logic is active only on level 80 characters
- Slash command `/wwr when` to check time until next battle
- Type `/wwr` or `/wwr help` for a list of available commands

## 📸 Screenshots

### WarmaneInstanceTracker

![Instance Tracker Demo](screenshots/instance-tracker-demo.png)

_A clean in-game table tracking your dungeon runs with relevant data, turning every run into visible progress._

### WarmaneTrackingAid

![Tracking Aid Demo](screenshots/tracking-aid-demo.png)

_Reactive tracking system adapting to enemy types in PvP combat._

### WarmaneChatCopy

![Chat Copy Demo](screenshots/chat-copy-demo.png)

_Separate window to copy any message from the chat, created by clicking on the channel name or into the message directly._

### WarmaneWGReminder

![WG Reminder Demo](screenshots/wg-reminder-demo.png)

_Timely reminder for Wintergrasp battles to ensure you never miss one again._

## ⚙️ Installation

1. Download the latest release
2. Extract the addon folders from the `addons/` directory to your `World of Warcraft 3.3.5a/Interface/AddOns` directory
3. Ensure addon names match exactly (case-sensitive)
4. Restart WoW if it was running

All addons are standalone, install only the ones you want to use.

## 💡 Feedback & Development

- This project is actively being developed.
- Feel free to open issues or submit PRs, contributions are welcome.
- You can link this repo if you use it in your project, but it's not required.

## 🤝 Contributing

- As stated in section above, contributors are welcome.
- Some general rules for any PR, as we don't want any spaghetti code:
  - Follow Lua language conventions and WoW addon development best practices
  - Use PascalCase for function names and camelCase for variable names
  - Comment your code
  - Update this file so the description and screenshot correspond to the latest AddOn version
- Additional rules for for <b>completely new</b> AddOns for this repo:

1. Addon Naming Requirements:
   - Follow the format `Warmane[Addon][Name]` for consistency
   - Exactly three words, first always being "Warmane"

2. Each addon must be fully standalone with no cross-addon dependencies

- Otherwise, there are no rules for branch names etc., just make it that the commit messages make sense.

---

Made with ❤️ for the Warmane community
