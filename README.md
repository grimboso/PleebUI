![PleebUI](Media/PleebUI.png)

# PleebUI

PleebUI is an integrated interface suite for World of Warcraft Retail, built for Midnight. It brings combat frames, action bars, cooldown tracking, class resources, damage meters, and everyday interface tools into one configurable layout.

PleebUI includes its own setup wizard, options window, profiles, previews, and Edit Mode. Most appearance changes can be applied directly while you configure the UI.

## Main features

- **Unit Frames** for Player, Target, Focus, Boss, Party, and Raid, with cast bars, portraits, health and power text, incoming-heal and absorb displays, dispel indicators, threat indicators, and configurable aura groups.
- **Action Bars** with shared or per-bar layouts, visibility conditions, mouseover fading, backdrops, keybind text, Pet and Stance bars, and four additional bars numbered 9-12.
- **Cooldown Manager styling** for Essential, Utility, Buff Icon, and Buff Bar viewers, including per-icon overrides, keybind text, custom colors, glows, orientation, and bar direction.
- **Custom cooldown and aura trackers** with a guided setup, live previews, buttons, duration bars, charge bars, stack bars, state opacity, glows, and Smart Snap support.
- **Consumable Tracker** for supported potions, Healthstones, combat resurrection items, equipped trinkets, racial abilities, and other combat items.
- **Personal Resource Display** with configurable health, primary power, specialization-relevant class resources, tracked effects, segmented layouts, thresholds, and detachable bars.
- **Damage Meters** with up to ten windows, independent meter and segment selections, player breakdowns, recent encounters, saved boss kills, and completed Mythic+ Overall runs.
- **Chat tools** with PleebUI styling, clickable URLs, a copy window, timestamps, persistent history, font controls, and configurable fading.
- **Minimap and interface styling** including addon-button collection, coordinates, clock and zone text, Player Buffs, bags, Character and Inspect panels, and a configurable Skyriding bar.
- **Quality-of-life tools** including combat and pet warnings, a cursor ring, crosshair, battle resurrection and Bloodlust displays, raid utilities, automatic repair and junk selling, faster looting, trusted invite and role-check handling, and other optional automation.

## Edit Mode and profiles

Use PleebUI Edit Mode to position supported frames and bars. Compatible movers can use Smart Snap to stay aligned and move together. Keyboard movement is available for precise placement.

Profiles can be switched, copied, reset, imported, and exported. Per-specialization profile selection is also supported.

## Commands

| Command | Action |
| --- | --- |
| `/pui` | Open PleebUI settings |
| `/pui install` | Open the setup wizard |
| `/pe` | Toggle PleebUI Edit Mode |
| `/pek` | Enter Edit Mode with keyboard movement |
| `/test` or `/puitest` | Alternate command for PleebUI Edit Mode |
| `/kb` | Toggle Action Bar binding mode |
| `/cd` | Open Blizzard Cooldown Manager settings |
| `/dmg` or `/dps` | Control PleebUI Damage Meters |

## Installation

Install PleebUI through CurseForge or Wago, or download `PleebUI-v*.zip` from [GitHub Releases](https://github.com/grimboso/PleebUI/releases/latest).

For a manual installation:

1. Exit World of Warcraft.
2. Extract the packaged ZIP into `World of Warcraft/_retail_/Interface/AddOns`.
3. Confirm the final path is `Interface/AddOns/PleebUI/PleebUI.toc`.
4. Start the game and follow the PleebUI setup wizard.

Use the packaged `PleebUI-v*.zip` asset, not GitHub's automatically generated source-code archives.

## Addon integration

Addon authors can register PleebUI Edit Mode movers and options pages through the [PleebUI Public API](PublicAPI/README.md).


## Feedback and issues

Report reproducible problems through [GitHub Issues](https://github.com/grimboso/PleebUI/issues). Include what you were doing, the full Lua error, and whether the issue occurred in or out of combat.

## License

PleebUI is available under the [MIT License](LICENSE).
