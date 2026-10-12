local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local math_max = _G.math.max

local CURRENT_RELEASE_VERSION = _G.C_AddOns.GetAddOnMetadata(ns.Name, "Version")
if CURRENT_RELEASE_VERSION == "@project-version@" then
  CURRENT_RELEASE_VERSION = "1.5.1"
end

local RELEASE_1_4 = {
  version = "1.4.4",
  intro = "This release brings together the current feature set with additional usability improvements, fixes, cleanup, and Midnight 12.1 stability work.",
  items = {
    {
      title = "Consumable Tracker",
      description = "Added a movable combat tracker for health potions, combat resurrection items, Healthstones, equipped trinkets, racial abilities, and other supported consumables. It includes counts, item quality, keybinds, tooltips, on-use trinket filtering, duration swipes and glows, and combat-only visibility.",
      location = "PleebUI > Combat frames > Cooldown Manager > Consumable Tracker",
    },
    {
      title = "Vertical and configurable Buff Bars",
      description = "Cooldown Manager Buff Bars can now be horizontal or vertical, place their icon on either side or end of the bar or hide it completely, choose the drain direction, and grow in the direction that fits your layout.",
      location = "PleebUI > Combat frames > Cooldown Manager > Buff Bars",
    },
    {
      title = "Per-icon Cooldown Manager settings",
      description = "Essential, Utility, and Buff Icon viewers now support dedicated per-icon override pages. Their previews also represent the selected viewer directly, and clicking a preview icon can take you to that icon's settings.",
      location = "PleebUI > Combat frames > Cooldown Manager > Essential / Utility / Buff Icons > Icon overrides",
    },
    {
      title = "Flexible cooldown groups",
      description = "Cooldowns and tracked buffs now start in four familiar groups but can be reordered, moved between groups, or dropped into empty space as standalone groups while PleebUI Edit Mode is open.",
      location = "PleebUI Edit Mode (/pe) / PleebUI > Pleeb Cooldown Manager",
    },
    {
      title = "Smarter Cooldown Manager keybinds",
      description = "Cooldown Manager keybind text now resolves live Action Bar bindings for spells, items, equipped trinkets, and supported macros, with compact key labels and event-driven updates when bindings or Action Bar assignments change.",
      location = "PleebUI > Combat frames > Cooldown Manager > Texts and Fonts / Consumable Tracker > Show keybinds",
    },
    {
      title = "Dedicated Party and Raid dispel controls",
      description = "Party and Raid frames now have their own Dispels page with independent health-bar coloring, border highlighting, and a high-resolution Blizzard-style dispel icon. The icon has its own size, anchor, and X/Y positioning controls with a dedicated preview.",
      location = "PleebUI > Combat frames > Unit Frames > Party / Raid > Dispels",
    },
    {
      title = "Shortened Unit Frame values",
      description = "Added a Shorten values option for health and resource text using compact values such as 12.3k and 1.2m while leaving percent-only displays unchanged.",
      location = "PleebUI > Combat frames > Unit Frames > General settings",
    },
    {
      title = "Character Sheet stat inspection",
      description = "The Character Sheet can now show Max Health and highlight equipped items that contribute to the stat you are inspecting, including Crit, Haste, Mastery, Versatility, Leech, Avoidance, Speed, and matching permanent enchant contributions.",
      location = "Character panel > settings button in the lower-right corner",
    },
    {
      title = "Hunter Emergency Salve warning",
      description = "Added a movable FEIGN warning for Hunters using Emergency Salve when a supported Poison or Disease is present, with configurable warning size and color plus an Edit Mode preview.",
      location = "PleebUI > Quality of Life > Combat > Emergency Salve / PleebUI Edit Mode (/pe)",
    },
    {
      title = "Native Action Bar keybindings",
      description = "PleebUI Action Bars 1-8 now use Blizzard's native Action Bar binding actions, so their bindings stay part of the normal WoW keybinding system. PleebUI's additional Action Bars 9-12 keep their own dedicated bindings.",
      location = "Blizzard Key Bindings / PleebUI Action Bars binding mode",
    },
    {
      title = "Up to 10 Damage Meter windows",
      description = "Damage Meters can now create and manage up to 10 independent windows, with New window, Hide window, and Delete window controls while each window keeps its own meter and segment selection.",
      location = "PleebUI Damage Meters > window menu",
    },
    {
      title = "Back and forward settings navigation",
      description = "PleebUI options now keep navigation history so you can move back and forward between pages, including using the standard mouse Back and Forward buttons. Major sections also remember their last opened page.",
      location = "PleebUI options",
    },
    {
      title = "Faster settings search",
      description = "Settings search now looks deeper into option names and descriptions from two characters, and pressing Enter opens the first matching result for faster keyboard navigation.",
      location = "PleebUI options > Search",
    },
    {
      title = "Improved What's New controls",
      description = "What's New now separates closing the window from dismissing a release. Close or the X keeps the release available next login, Hide until next release dismisses only the current release, and Don't show again disables automatic release notes.",
      location = "PleebUI What's New",
    },
    {
      title = "Release fixes and polish",
      description = "This release also includes fixes and cleanup across Action Bars, Unit Frames, the Character Sheet, the Consumable Tracker, Cooldown Manager, settings navigation, and other Midnight-sensitive lifecycle and restricted-execution paths.",
      location = "Applies automatically",
    },
  },
}

local RELEASE_1_5 = {
  version = "1.5",
  intro = "Version 1.5 adds a rebuilt Edit Mode workflow, keyboard navigation, accessibility controls, expanded previews, and more combat display options.",
  items = {
    {
      title = "Reorganized settings and quick settings",
      description = "Related controls now share clearer sections, with consistent layout, appearance, visibility, and text settings. Mover quick settings include useful shortcuts, explanations for unavailable controls, and direct links to full module options. Chat and Damage Meter pages also use tree navigation.",
      location = "PleebUI Edit Mode (/pe) / PleebUI options",
    },
    {
      title = "Searchable Edit Mode mover list",
      description = "Find movers in a searchable tree grouped by module. Saved visibility presets and group-context filters help you focus on the frames you want to arrange, including supported external addon movers. Hidden samples pause their preview updates.",
      location = "PleebUI Edit Mode (/pe) > mover list",
    },
    {
      title = "Resizable Edit Mode controls",
      description = "Edit Mode now uses a resizable panel with collapsible sections. Quick settings retain their scroll position, and width, height, and position controls let you arrange the panel without dragging it.",
      location = "PleebUI Edit Mode (/pe) > toolbar",
    },
    {
      title = "Edit Mode Undo and Redo",
      description = "Undo and redo mover positions, supported quick-setting changes, and linked group moves during your editing session. Buttons and Ctrl+Z / Ctrl+Y include descriptions of the change. History clears when you leave Edit Mode or switch profiles.",
      location = "PleebUI Edit Mode (/pe) > Undo / Redo",
    },
    {
      title = "Easier mover selection and alignment",
      description = "Snap guides show nearby frame edges, and Compact movers can soften idle labels and borders. Small and selected movers are easier to reach when frames overlap, with an Overlaps selector for choosing the intended frame.",
      location = "PleebUI Edit Mode (/pe) > mover controls / Overlaps",
    },
    {
      title = "Keyboard navigation and movement",
      description = "Navigate options, dialogs, dropdowns, colors, and supported previews with Tab, arrow keys, Enter, and Space. F1 opens contextual help. Save a mouse or keyboard Edit Mode preference, use /pek for one keyboard session, and press F6 to switch between movers and toolbar controls. Mouse interaction clears keyboard focus.",
      location = "PleebUI > Accessibility > Controls and motion / PleebUI Edit Mode (/pek)",
    },
    {
      title = "Action Bar previews and simpler setup",
      description = "Shared settings and individual bars are easier to navigate, with previews that show actual icons, cooldowns, counts, keybinds, and macro names. Dedicated pages cover Bars 1-12, Pet, and Stance. Inherited sizes and backdrop spacing now match the live bars more closely.",
      location = "PleebUI > Action Bars",
    },
    {
      title = "Unit Frame positions by group context",
      description = "Keep separate positions for supported Unit Frames in Solo, Party, and Raid layouts, or use Shared positions. Choose how group-context changes select a layout, and configure each context without replacing the rest of your frame settings.",
      location = "PleebUI Edit Mode (/pe) > Unit Frame quick settings > More: group positions",
    },
    {
      title = "Unit Frame options and previews",
      description = "Unit Frame settings are organized by purpose, with clearer layout, text, aura, and indicator controls. Improved castbar and aura previews make it easier to see changes, and section resets help without resetting the whole profile.",
      location = "PleebUI > Combat frames > Unit Frames",
    },
    {
      title = "More Cast Bar text control",
      description = "Place cast target text independently, limit spell-name width, choose cast-time display modes, and set a separate border color. Spell names stay on one line, and instant casts clear stale target text. Instant Cast and Evoker Empower controls have dedicated pages with castbar previews.",
      location = "PleebUI > Combat frames > Unit Frames > select a frame > Cast Bar / Instant / Empower",
    },
    {
      title = "Clearer Resource Display setup",
      description = "The Resource Display opens on Health and uses compact pages named for your class resources and tracked effects. Individual bar previews and direct preview navigation make setup easier. Turning off a glow cue preserves its selected buff.",
      location = "PleebUI > Combat frames > Personal Resource Display",
    },
    {
      title = "Soul Fragment display choices",
      description = "Choose whether Vengeance Soul Fragments appear on the Soul Cleave and Spirit Bomb cooldown icons, the Personal Resource Display bar, both, or neither. Both settings pages share the same choice, and previews follow it.",
      location = "PleebUI > Combat frames > Personal Resource Display > Soul Fragments / Cooldown Manager > icon settings",
    },
    {
      title = "Spell use counts on cooldown icons",
      description = "Cooldown icons can show Blizzard's spell use counts as well as supported charge counts, with per-icon appearance settings.",
      location = "PleebUI > Combat frames > Cooldown Manager > Essential / Utility > count settings",
    },
    {
      title = "Growing or fixed Buff Bar groups",
      description = "Cooldown Manager Buff Bars can keep fixed slots or pack active bars together, growing in your chosen direction instead of leaving gaps when buffs disappear.",
      location = "PleebUI > Combat frames > Cooldown Manager > Buff Bars",
    },
    {
      title = "Cooldown tracking after loading screens",
      description = "Cooldown viewers and custom trackers refresh after zoning and loading transitions. Charge notifications, aura widgets, and totem bar durations reconnect to the current Blizzard state instead of retaining stale widgets or durations.",
      location = "Applies automatically",
    },
    {
      title = "Quality of Life settings, organized",
      description = "Find tools under Combat, Position indicators, Group tools, and Convenience. Missing or dead pet, idle pet, and low-health warnings have independent appearance controls. Combat samples and movement reminders can be previewed together, and Emergency Salve is grouped with Hunter tools.",
      location = "PleebUI > Quality of Life",
    },
    {
      title = "Independent movement reminders",
      description = "Configure supported movement reminders separately, including their selected spell, display type, size, colors, and visibility. The options preview shows reminders side by side and follows the selected display settings.",
      location = "PleebUI > Movement Reminder",
    },
    {
      title = "Auto loot setting",
      description = "Enable Blizzard auto loot from PleebUI's Convenience page, alongside Faster looting and the existing everyday conveniences.",
      location = "PleebUI > Quality of Life > Convenience > Everyday conveniences",
    },
    {
      title = "Separate buff and debuff appearance",
      description = "Player buffs and debuffs have independent icon sizes, border thickness, fonts, outlines, and text colors. Debuff borders use Blizzard's debuff-type colors, while text can follow the UI theme or use a custom color.",
      location = "PleebUI > Player Buffs",
    },
    {
      title = "Character Sheet sockets and icon search",
      description = "An optional socket strip shows equipped gems and empty sockets, with paging, tooltips, and clicks to open socketing outside combat. The icon selector supports searches by name or ID. More compact stat rows leave room for tank defenses above the settings button.",
      location = "Character panel > settings button > Show socket strip / icon selector",
    },
    {
      title = "Minimap controls in one place",
      description = "Minimap settings now expose Blizzard border, tracking, calendar, clock, top-panel, and launcher visibility controls together. Hiding the PleebUI launcher is respected when addon buttons are arranged.",
      location = "PleebUI > Minimap",
    },
    {
      title = "Damage Meter setup and refresh controls",
      description = "Damage Meter settings use consistent sections and tree navigation, with combat refresh rates up to 20 Hz. Deleting a saved meter window asks for confirmation, and unavailable history controls explain their dependencies.",
      location = "PleebUI > Damage Meters",
    },
    {
      title = "Accessibility presets with Undo",
      description = "A dedicated Accessibility category brings together color presets, an interactive palette preview, and combat readability settings. Combat readability includes a session Undo that restores values you have not subsequently edited. Larger pointer targets make controls easier to reach.",
      location = "PleebUI > Accessibility",
    },
    {
      title = "Responsive settings and preview polish",
      description = "Options columns adapt to available space, and controls, headings, tabs, and navigation rows scale with their fonts. Unit Frame, aura, and bar previews scale more consistently, with keyboard access to supported preview controls and zoom.",
      location = "PleebUI options",
    },
    {
      title = "Saved options window size and position",
      description = "The options window remembers its geometry across sessions. Width, height, horizontal position, vertical position, and Center window controls provide another way to arrange it, with sizing kept inside the scaled screen.",
      location = "PleebUI > General > UI Theme > Layout and appearance",
    },
    {
      title = "More options text and font controls",
      description = "Set fonts, sizes, outlines, shadows, and SLUG rendering separately for options text categories, with curated defaults and resets. Font selectors preview the font itself. Separate SLUG settings apply to options text and supported runtime text.",
      location = "PleebUI > General > UI Theme > Text",
    },
    {
      title = "Color tools and clearer controls",
      description = "Color controls now include numeric editing, opacity, copy and paste, recent colors, favorites, and saved palettes. Thin control borders, clearer hover and focus states, larger navigation targets, and opaque tooltips improve readability. Disabled controls retain explanations.",
      location = "PleebUI options > color controls / PleebUI > General > UI Theme",
    },
    {
      title = "More precise slider editing",
      description = "Slider step buttons and validated numeric inputs make precise changes easier. Wheel adjustment is deliberate, and invalid values remain visible until corrected or cancelled. Reset and delete prompts describe the affected settings.",
      location = "PleebUI options",
    },
    {
      title = "Optional settings animations",
      description = "Options pages and navigation highlights use smoother transitions. Turn Animate options off from Accessibility if you prefer immediate changes. Page construction, font choices, dropdown layouts, and window resizing also avoid repeated layout work.",
      location = "PleebUI > Accessibility > Controls and motion",
    },
  },
}

local CURRENT_RELEASE = {
  version = CURRENT_RELEASE_VERSION,
  intro = "Version 1.5.1 adds an interactive Edit Mode guide, rune recharge improvements, queue countdowns, and optional group conveniences.",
  items = {
    {
      title = "Interactive Edit Mode guide",
      description = "Choose Mouse, Keyboard, or Both and practice settings navigation, mover selection, group movement, and Undo / Redo with sample controls. The practice area keeps its own layout and history, so your real settings stay untouched. Replay the guide whenever you need it.",
      location = "PleebUI > Edit Mode > Getting started > Edit Mode guide / Accessibility > Controls and motion",
    },
    {
      title = "Dedicated Edit Mode settings page",
      description = "Set your preferred input, keyboard nudge step, frame snapping, Smart Snap, snap distance, grid, compact movers, and screen dimming from the main options. These controls share the toolbar's saved settings.",
      location = "PleebUI > Edit Mode > Settings",
    },
    {
      title = "Accessibility text and size shortcuts",
      description = "Accessibility now includes options text size, window scale, and global text controls. Changes use the same profile settings as UI Theme, so either page updates the same appearance.",
      location = "PleebUI > Accessibility > Text and size",
    },
    {
      title = "Death Knight rune recharge",
      description = "Rune segments now animate their recharge with selectable direction, optional recharge time, ready glow, and completion effects. Ready runes return to full opacity, countdowns appear only after recharge starts, and recharging runes do not retain ready glows. Rune artwork and resource colors follow Blood, Frost, or Unholy in both live frames and previews.",
      location = "PleebUI > Combat frames > Personal Resource Display > Runes",
    },
    {
      title = "Dungeon and PvP entry countdowns",
      description = "Show the remaining acceptance time on supported dungeon and PvP queue prompts. The dungeon countdown uses a 40-second estimate.",
      location = "PleebUI > Quality of Life > Convenience > Everyday conveniences > Show entry countdown",
    },
    {
      title = "Optional summon and resurrection acceptance",
      description = "Opt in to accept ordinary summons and resurrection outside combat. Special summon warnings, resurrection sickness, and recovery timers still require confirmation.",
      location = "PleebUI > Quality of Life > Convenience > Summons and resurrection",
    },
    {
      title = "Whisper keyword invites",
      description = "Invite trusted friends, Battle.net friends, or guild members when they whisper one of your chosen keywords. Enter multiple keywords separated by commas, such as invite, inv, +. Matching ignores case and surrounding spaces; invites require permission to invite and stop during combat or restricted chat.",
      location = "PleebUI > Quality of Life > Convenience > Whisper invites",
    },
    {
      title = "Screen effects and weather controls",
      description = "Disable screen glow, disable supported death and special screen effects, or choose weather density for regular and raid graphics. Turning these controls off restores their previous settings.",
      location = "PleebUI > Quality of Life > Convenience > Accessibility",
    },
    {
      title = "Larger combat timer and Edit Mode preview",
      description = "The combat timer supports font sizes up to 72 and has an Edit Mode sample. Its mover resizes to fit the displayed text.",
      location = "PleebUI > Quality of Life > Combat > Combat timer / PleebUI Edit Mode (/pe)",
    },
    {
      title = "Repair summaries and profile refresh fixes",
      description = "Repair summaries print through the normal chat window after repairs complete, with guild-first repair and personal-funds fallback. Movement reminder settings and castbar configuration refresh when profiles change, and missing reminder color components are restored.",
      location = "PleebUI > Quality of Life > Convenience > Items and merchants / applies automatically",
    },
    {
      title = "Cooldown count layering",
      description = "Cooldown counts remain above active-aura duration icons, keeping the count readable when both displays are present.",
      location = "PleebUI > Combat frames > Cooldown Manager",
    },
  },
}

local RELEASE_1_3 = {
  version = "1.3",
  intro = "This release rebuilds PleebUI's combat layout and tracking workflow, with major Resource Display, custom tracker, Damage Meter, usability, performance, and Midnight 12.1 improvements.",
  items = {
    {
      title = "Smart Snap and synced movers",
      description = "Compatible movers can now snap into persistent groups, move together, keep edge alignment, and optionally sync width or size and visuals. Shift-drag detaches a mover and disables snapping for that drag.",
      location = "PleebUI Edit Mode (/pe) > select a compatible mover > Quick settings > Smart Snap",
    },
    {
      title = "Cooldown and Resource HUD",
      description = "Cooldown Manager elements, the Resource Display, Player Cast Bar, Player Unit Frame, custom bars, and other compatible combat frames can now be arranged as one flexible HUD instead of relying on a fixed stack.",
      location = "PleebUI Edit Mode (/pe) > move compatible combat frames",
    },
    {
      title = "Personal Resource Display rebuild",
      description = "The Resource Display and Secondary resources were rebuilt around specialization-relevant class resources and tracked effects, with shared or per-resource appearance, visibility, spacing, text, width, detach, and positioning controls.",
      location = "PleebUI > Combat frames > Personal Resource Display > Secondary",
    },
    {
      title = "Player Unit Frame in the Resource Display",
      description = "The Player Unit Frame can now replace the Resource Display health bar and join the same HUD layout while keeping its normal Unit Frame appearance and settings.",
      location = "PleebUI Edit Mode (/pe) > Player / Personal Resource Display > Quick settings",
    },
    {
      title = "Stack color shifts",
      description = "PRD tracked effects and PCM stack trackers can now change the full bar color at any number of configured stack thresholds instead of being limited to a fixed set of colors.",
      location = "PleebUI > Combat frames > Personal Resource Display / Cooldown Manager > Stack color shifts",
    },
    {
      title = "Guided custom tracker creation",
      description = "Added a guided custom tracker setup with a live preview for creating custom buttons and bars without building every setting manually first.",
      location = "PleebUI > Combat frames > Cooldown Manager > Custom trackers > Create custom tracker",
    },
    {
      title = "Expanded PCM custom trackers",
      description = "Custom trackers now have a more unified editor and runtime, Smart Snap alignment, richer state visibility and opacity controls, active-aura behavior, glow controls, bar direction and total-width settings, and cleaner per-tracker layout handling.",
      location = "PleebUI > Combat frames > Cooldown Manager > Custom trackers",
    },
    {
      title = "Unit Frame aura system rework",
      description = "Unit Frame aura displays were reworked around Midnight 12.1 AuraContainers, with separate default buffs, defensives and externals, important buffs, and debuffs while keeping custom Aura Groups and Aura Slots in the Aura Manager.",
      location = "PleebUI > Combat frames > Unit Frames > select a frame > Auras > Aura Manager",
    },
    {
      title = "Action Bar controls",
      description = "Added Hide unused action buttons and expanded Pet, Stance, and Possess bar controls with their own layout, backdrop, alpha, and mouseover fade settings.",
      location = "PleebUI > Action bars",
    },
    {
      title = "Damage Meter history",
      description = "Damage Meters now keep configurable boss kills and completed Mythic+ Overall runs alongside Blizzard's live and recent sessions.",
      location = "PleebUI Damage Meters > Bosses / Completed keystones / Recent segments",
    },
    {
      title = "Historical Damage Meter breakdowns",
      description = "Saved encounters now retain the player spell and target breakdown data needed for historical analysis, with a dedicated segment browser and an Always show me option for keeping your own row visible.",
      location = "PleebUI Damage Meters > segment picker / PleebUI > Damage Meters > Window settings",
    },
    {
      title = "Character Sheet display menu",
      description = "Added a Character Sheet settings button for toggling enchant icons, socket icons, bag item level, and stat values directly from the character panel.",
      location = "Character panel > settings button in the lower-right corner",
    },
    {
      title = "Faster settings workflow and accessibility",
      description = "Added settings search, a direct All settings path from mover Quick Settings, a Combat readability preset, and an optional stripe pattern so dispel highlights do not rely on color alone.",
      location = "PleebUI options / PleebUI > General > UI Theme > Combat readability / PleebUI Edit Mode (/pe)",
    },
    {
      title = "Chat compatibility and skinning rework",
      description = "PleebUI Chat now leaves Blizzard in control of message routing, whispers, temporary windows, and tab behavior while keeping PleebUI visuals, history, URL, and copy tools with safer combat-lockdown handling.",
      location = "PleebUI > Chat",
    },
    {
      title = "Performance and Midnight 12.1 stability",
      description = "Moved more combat updates to targeted, event-driven paths and removed duplicate or delayed refresh work across PCM, Unit Frames, Action Bars, Damage Meters, movers, and aura handling, with additional secret-value and combat-lockdown fixes.",
      location = "Applies automatically",
    },
  },
}

local RELEASE_1_2 = {
  version = "1.2",
  intro = "This release adds new Unit Frame, Action Bar, PCM, and quality-of-life features, plus broad performance and stability improvements.",
  items = {
    {
      title = "PCM buff glow",
      description = "Added buff-triggered custom glows for PCM custom bars, with selectable buff sources, glow thickness, and color.",
      location = "PleebUI > Combat frames > Cooldown Manager > Custom bars > Select a bar > Buff glow",
    },
    {
      title = "2D and 3D portraits",
      description = "Added configurable portraits to Player, Target, Focus, Boss, and Party frames, with 2D or 3D styles plus side, width, and zoom controls.",
      location = "PleebUI > Combat frames > Unit Frames > Player / Target / Focus / Boss Frames / Party > Portrait",
    },
    {
      title = "Extra Action Bars",
      description = "Added optional Action Bars 9-12, each with 12 buttons, individual settings, movers, and keybindings.",
      location = "PleebUI > Action bars > General > Enabled bars",
    },
    {
      title = "Class colored names",
      description = "Added an option to class-color Unit Frame names independently of the health bar color.",
      location = "PleebUI > Combat frames > Unit Frames > General settings > Unit Frame Appearance > Class colored names",
    },
    {
      title = "PleebUI minimap button",
      description = "Added an option to anchor the PleebUI launcher directly to the minimap instead of keeping it in the addon button bucket.",
      location = "PleebUI > Minimap > General > Anchor PleebUI button to minimap",
    },
    {
      title = "Game Menu shortcuts",
      description = "Added PleebUI and PleebUI Test Mode buttons to the Game Menu for faster access.",
      location = "Esc > PleebUI / PleebUI Test Mode",
    },
    {
      title = "Options UI scaling",
      description = "Expanded Options UI scaling to 75-200% in 1% steps and improved slider resizing for smoother adjustments.",
      location = "PleebUI > General > UI Theme > Options layout > Options UI scale",
    },
    {
      title = "Clearer options tooltips",
      description = "PleebUI options tooltips now use a solid background so text stays readable over the options window.",
      location = "PleebUI options",
    },
    {
      title = "Performance and stability",
      description = "Improved Unit Frame and Action Bar lifecycle, layout, and update handling, including more reliable Party roster assignment and Midnight 12.1 compatibility fixes.",
      location = "Applies automatically",
    },
  },
}

local RELEASES = {
  CURRENT_RELEASE,
  RELEASE_1_5,
  RELEASE_1_4,
  RELEASE_1_3,
  RELEASE_1_2,
}

local whatsNewFrame

local function GetWhatsNewDB()
  return Addon.db.global.whatsNew
end

local function ApplyTextColor(fontString)
  local color = Theme.GetColors().text
  fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function CreateText(parent, role, size, justify)
  local text = parent:CreateFontString(nil, "OVERLAY")
  Theme.ApplyFont(text, role, size)
  ApplyTextColor(text)
  text:SetJustifyH(justify or "LEFT")
  text:SetJustifyV("TOP")
  return text
end

local function CreateButton(parent, label, width)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, 32)
  button:RegisterForClicks("LeftButtonUp")

  local text = CreateText(button, "body", 12, "CENTER")
  text:SetPoint("CENTER")
  text:SetText(label)
  button.Text = text
  button:SetFontString(text)

  Theme.WidgetSkins.UIButton(button)
  return button
end

local function AddReleaseItems(lines, release)
  for index = 1, #release.items do
    local item = release.items[index]
    lines[#lines + 1] = index .. ". " .. item.title
    lines[#lines + 1] = item.description
    lines[#lines + 1] = "Where: " .. item.location

    if index < #release.items then
      lines[#lines + 1] = ""
    end
  end
end

local function BuildReleaseText()
  local lines = {}

  AddReleaseItems(lines, CURRENT_RELEASE)

  for releaseIndex = 2, #RELEASES do
    local release = RELEASES[releaseIndex]
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Release " .. release.version
    lines[#lines + 1] = release.intro
    lines[#lines + 1] = ""
    AddReleaseItems(lines, release)
  end

  return table.concat(lines, "\n")
end

local function RefreshWhatsNewTheme(frame)
  local colors = Theme.GetColors()

  Theme.SetSquareBackdrop(frame, {
    bg = colors.background,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  Theme.SetSquareBackdrop(frame.scrollBorder, {
    bg = colors.control,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  ApplyTextColor(frame.title)
  ApplyTextColor(frame.version)
  ApplyTextColor(frame.intro)
  ApplyTextColor(frame.body)
  ApplyTextColor(frame.footer)

  Theme.WidgetSkins.UIButton(frame.close)
  Theme.WidgetSkins.UIButton(frame.disable)
  Theme.WidgetSkins.UIButton(frame.closeNow)
  Theme.WidgetSkins.UIButton(frame.untilNext)
  Theme.WidgetSkins.Scrollbar(frame.scroll.ScrollBar)
end

local function PopulateWhatsNew(frame)
  frame.version:SetText("Release " .. CURRENT_RELEASE.version)
  frame.intro:SetText(CURRENT_RELEASE.intro)
  frame.body:SetText(BuildReleaseText())

  local bodyHeight = frame.body:GetStringHeight()
  frame.content:SetHeight(math_max(frame.scroll:GetHeight(), bodyHeight + 16))
  frame.scroll:SetVerticalScroll(0)
  frame.scroll:UpdateScrollChildRect()
end

local function EnsureWhatsNewFrame()
  if whatsNewFrame then
    return whatsNewFrame
  end

  local frame = CreateFrame("Frame", "PleebUIWhatsNewFrame", UIParent, "BackdropTemplate")
  frame:SetSize(720, 560)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetTexture([[Interface\AddOns\PleebUI\Media\logo.tga]])
  logo:SetSize(42, 42)
  logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
  frame.logo = logo

  local title = CreateText(frame, "title", 24, "LEFT")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
  title:SetText("What's New in PleebUI")
  frame.title = title

  local version = CreateText(frame, "body", 12, "LEFT")
  version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  frame.version = version

  local close = CreateButton(frame, "X", 30)
  close:SetSize(30, 30)
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
  close:SetScript("OnClick", function()
    Addon:HideWhatsNew()
  end)
  frame.close = close

  local intro = CreateText(frame, "body", 13, "LEFT")
  intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)
  intro:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -76)
  intro:SetHeight(36)
  intro:SetWordWrap(true)
  frame.intro = intro

  local scrollBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  scrollBorder:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
  scrollBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 92)
  frame.scrollBorder = scrollBorder

  local scroll = CreateFrame("ScrollFrame", nil, scrollBorder, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", scrollBorder, "TOPLEFT", 10, -10)
  scroll:SetPoint("BOTTOMRIGHT", scrollBorder, "BOTTOMRIGHT", -30, 10)
  frame.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(632)
  content:SetHeight(1)
  scroll:SetScrollChild(content)
  frame.content = content

  local body = CreateText(content, "body", 13, "LEFT")
  body:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
  body:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2)
  body:SetWordWrap(true)
  body:SetNonSpaceWrap(false)
  frame.body = body

  local disable = CreateButton(frame, "Don't show again", 180)
  disable:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
  disable:SetScript("OnClick", function()
    Addon:SetWhatsNewEnabled(false)
    Addon:HideWhatsNewUntilNextRelease()
  end)
  frame.disable = disable

  local closeNow = CreateButton(frame, "Close", 140)
  closeNow:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)
  closeNow:SetScript("OnClick", function()
    Addon:HideWhatsNew()
  end)
  frame.closeNow = closeNow

  local untilNext = CreateButton(frame, "Hide until next release", 190)
  untilNext:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
  untilNext:SetScript("OnClick", function()
    Addon:HideWhatsNewUntilNextRelease()
  end)
  frame.untilNext = untilNext

  local footer = CreateText(frame, "body", 11, "CENTER")
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 58)
  footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 58)
  footer:SetText("Open release notes anytime from What's new in the PleebUI footer.")
  footer:SetWordWrap(true)
  frame.footer = footer

  frame:Hide()
  whatsNewFrame = frame
  return frame
end

function Addon:SetWhatsNewEnabled(enabled)
  GetWhatsNewDB().disabled = enabled ~= true
end

function Addon:IsWhatsNewPending()
  local db = GetWhatsNewDB()
  return db.disabled ~= true and db.lastSeenRelease ~= CURRENT_RELEASE.version
end

function Addon:HideWhatsNew()
  if whatsNewFrame then
    whatsNewFrame:Hide()
  end
end

function Addon:HideWhatsNewUntilNextRelease()
  GetWhatsNewDB().lastSeenRelease = CURRENT_RELEASE.version
  self:HideWhatsNew()
end

function Addon:ShowWhatsNew(force)
  if not force and (self:IsInstallWizardPending() or not self:IsWhatsNewPending()) then
    return false
  end

  local frame = EnsureWhatsNewFrame()
  PopulateWhatsNew(frame)
  RefreshWhatsNewTheme(frame)
  frame:Show()
  frame:Raise()
  return true
end


local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")

  local db = GetWhatsNewDB()

  if Addon.db.global.installed ~= true then
    db.lastSeenRelease = CURRENT_RELEASE.version
    return
  end

  if Addon:IsInstallWizardPending() then
    return
  end

  Addon:ShowWhatsNew(false)
end)
