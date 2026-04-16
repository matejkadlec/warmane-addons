# Warmane AddOns Collection

![Language](https://img.shields.io/badge/language-Lua-2C2D72.svg)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)

Collection of custom World of Warcraft AddOns specifically developed for Warmane's WotLK (3.3.5a) servers.

A big thanks goes to the owner of [`3.3.5-interface-files`](https://github.com/wowgaming/3.3.5-interface-files) GitHub repository, which I'm using a lot during the development.

## 📋 Table of Contents

- [Available AddOns](#-available-addons)
  - [WarmaneInstanceTracker](#warmaneinstancetracker-wip)
  - [WarmaneTrackingAid](#warmanetrackingaid)
  - [WarmaneChatCopy](#warmanechatcopy)
  - [WarmaneWGReminder](#warmanewgreminder)
  - [WarmaneNotAway](#warmanenotaway)
- [Screenshots](#-screenshots)
- [Installation](#️-installation)
- [Feedback & Development](#-feedback--development)
- [Contributing](#-contributing)
- [Support](#-support)

## 📦 Available AddOns

### WarmaneInstanceTracker

📋 Tracks completed dungeon runs and stores both run history and aggregated per-character/per-instance stats.

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

📄 Makes chat messages copyable on mouse click.

- Click on a channel name to copy the message into a new window
  - For messages without a channel, click into the message directly instead
- You can copy messages from the copy window with `CTRL-C`
- Works with all message types (channels, system, say, ...)
- Does not intervene with item or quest links, usernames, etc.
- Copying more messages makes them appear under eachother in the click order
- Clear button to reset the copy window content

### WarmaneWGReminder

⏰ Reminds players about upcoming Wintergrasp battle.

- Uses the in-game `GetWintergraspWaitTime()` API for accurate battle timing
- Shows notifications at 30, 15, and 5 minutes before battle
- Also shows notification right after the battle begins and ends
- Addon logic is active only on level 80 characters
- Slash command `/wwr when` to check time until next battle
- Type `/wwr` or `/wwr help` for a list of available commands

### WarmaneNotAway

🟢 Automatically clears your `<Away>` status when you become active.

- This _should be_ WoW's default behvaior, but I've been having problems with it on Warmane
- Uses Blizzard's built-in `autoClearAFK` option to keep behavior safe and lightweight
- Re-enables AFK auto-clear when the AddOn loads and when entering the world
- No key listener, no polling loop, and no manual `/afk` simulation

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

### WarmaneNotAway

![Not Away Demo](screenshots/not-away-demo.png)

_No more getting stuck with `<Away>` above your name after you are already back in action._

## ⚙️ Installation

1. Download the latest release
2. Extract the AddOn folders from the `addons/` directory to your `World of Warcraft 3.3.5a/Interface/AddOns` directory
3. Ensure AddOn names match exactly (case-sensitive)
4. Restart WoW if it was running

All AddOns are standalone, install only the ones you want to use.

## 💡 Feedback

This project is being under active develompent as of April 2026.

- If you encounter a bug or have a feature request for existing AddOn, open a GitHub issue
- If you have an AddOn idea, you can email me on `info@matejkadlec.cz`
  - If I'll find it interesting, there's a good chance I will create it for you for a voluntary donation
  - If I don't find it interesting, I can still do it for a fixed price (I can provide an invoice)
- Feel free to you use any of my AddOns in your project, in that case a link back to this repository is appreciated

## 🤝 Contributing

- Contributors are welcome, just create a PR and assign it to me for a review
- Some general rules for all PRs, as we don't want any spaghetti code:
  - Follow Lua language conventions and WoW AddOn development best practices
    - If you code in VSCode, I highly recommend [WoW Bundle](https://marketplace.visualstudio.com/items?itemName=Septh.wow-bundle) extension
  - Use PascalCase for function names and camelCase for variable names
  - Comment your code
  - Update this file so the description and screenshot correspond to the latest AddOn version
- Additional rules for for **completely new** AddOns for this repository:
  1. Follow the naming format `Warmane[Addon][Name]` for consistency
  2. Each AddOn must be fully standalone with no cross-AddOn dependencies
  3. Required `.toc` file attributes:
     ```ini
     ## X-Collaboration: Matej Kadlec (https://github.com/matejkadlec)
     ## X-Repository: https://github.com/matejkadlec/warmane-addons
     ```

- Otherwise, there are no rules for branch names etc., just make it that the commit messages make sense

---

Made with ❤️ for the Warmane community
