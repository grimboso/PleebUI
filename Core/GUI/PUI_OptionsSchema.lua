local _, ns = ...

local Schema = {}
ns.OptionsSchema = Schema

local RULES = {}
local GROUPS = {}

local function DefineGroup(key, name, order)
  GROUPS[key] = { name = name, order = order }
end

DefineGroup("text", "Text", 40)
DefineGroup("name", "Name", 10)
DefineGroup("healthText", "Health", 20)
DefineGroup("powerText", "Power", 30)
DefineGroup("castTime", "Cast time", 40)
DefineGroup("countdown", "Countdown", 50)
DefineGroup("charges", "Charges", 60)
DefineGroup("stacks", "Stacks", 70)
DefineGroup("counts", "Counts", 80)
DefineGroup("keybinds", "Keybinds", 90)
DefineGroup("macroName", "Macro name", 100)
DefineGroup("warning", "Warning", 10)
DefineGroup("missingPet", "Missing pet", 20)
DefineGroup("deadPet", "Dead pet", 30)
DefineGroup("idleWarning", "Idle warning", 40)
DefineGroup("clock", "Clock", 10)
DefineGroup("coordinates", "Coordinates", 20)
DefineGroup("zoneText", "Zone text", 30)
DefineGroup("border", "Border", 40)
DefineGroup("iconBorder", "Icon border", 41)
DefineGroup("backdropBorder", "Backdrop border", 42)
DefineGroup("outerBorder", "Outer border", 43)
DefineGroup("mouseoverBorder", "Mouseover border", 44)
DefineGroup("targetBorder", "Target border", 45)
DefineGroup("aggroBorder", "Aggro border", 46)
DefineGroup("chatBorder", "Chat border", 47)
DefineGroup("slotBorder", "Slot border", 48)
DefineGroup("ready", "Ready", 10)
DefineGroup("inactive", "Inactive", 20)
DefineGroup("cooldown", "On cooldown", 30)
DefineGroup("recharging", "Recharging", 40)
DefineGroup("auraActive", "Aura active", 50)
DefineGroup("outOfRange", "Out of range", 60)
DefineGroup("instantCast", "Instant cast bar", 20)
DefineGroup("instantOverlay", "Instant cast overlay", 30)
DefineGroup("fadeIn", "Fade in", 70)
DefineGroup("fadeOut", "Fade out", 80)
DefineGroup("size", "Size", 10)
DefineGroup("arrangement", "Arrangement", 20)
DefineGroup("icon", "Icon", 30)
DefineGroup("buffIcons", "Buff icons", 31)
DefineGroup("debuffIcons", "Debuff icons", 32)
DefineGroup("buttons", "Buttons", 30)
DefineGroup("bar", "Bar", 35)
DefineGroup("background", "Background", 36)
DefineGroup("swipe", "Swipe", 30)
DefineGroup("visibility", "Visibility", 30)
DefineGroup("general", "General", 10)
DefineGroup("resourceBars", "Resource bars", 20)
DefineGroup("stackedBars", "Stacked bars", 21)
DefineGroup("unitTooltips", "Unit tooltips", 10)
DefineGroup("auraTooltips", "Aura tooltips", 20)
DefineGroup("castTarget", "Cast target", 45)
DefineGroup("panel", "Panel", 25)
DefineGroup("minimap", "Minimap", 30)
DefineGroup("barOpacity", "Bar", 10)
DefineGroup("message", "Message", 10)
DefineGroup("timerText", "Timer", 20)
DefineGroup("hidden", "Hidden", 65)
DefineGroup("unavailable", "Unavailable", 66)
DefineGroup("outOfCombat", "Out of combat", 67)

local function DefineControl(group, label, order, names)
  for index = 1, #names do
    RULES[names[index]] = { group = group, label = label, order = order }
  end
end

DefineControl("text", "Font", 40, { "Font", "Font type" })
DefineControl("text", "Font size", 50, { "Font size", "Text size" })
DefineControl("text", "Use global font", 30, { "Use global font", "Use shared font" })
DefineControl("text", "Use custom font", 35, { "Custom font", "Use custom font" })
DefineControl("text", "Outline", 60, { "Outline", "Font outline", "Text outline" })
DefineControl("text", "Text color", 70, { "Text color", "Font color" })
DefineControl("text", "Center text", 25, { "Show centered", "Center text" })
DefineControl("text", "Format", 20, { "Text format", "Timestamp format" })
DefineControl("text", "Show text", 10, { "Show text" })
DefineControl("message", "Font size", 50, { "Message font size" })
DefineControl("timerText", "Font size", 50, { "Timer font size" })
DefineControl("warning", "Text color", 70, { "Warning color" })
DefineControl("name", "Hide name", 10, { "Hide name" })
DefineControl("countdown", "Override font size", 35, { "Override duration font size" })
DefineControl("stacks", "Override font size", 35, { "Override stack font size" })
DefineControl("border", "Override thickness", 5, { "Override border size" })
DefineControl("text", "Text color", 70, { "Label color" })
DefineControl("unitTooltips", "Show tooltips", 10, { "Enable unit mouseover tooltips" })
DefineControl("auraTooltips", "Show tooltips", 10, { "Enable aura mouseover tooltips" })
DefineControl("text", "Anchor point", 80, { "Text anchor" })
DefineControl("text", "Horizontal offset", 90, { "Text X offset" })
DefineControl("text", "Vertical offset", 100, { "Text Y offset" })
DefineControl("size", "Width", 10, { "Width", "Frame width" })
DefineControl("size", "Height", 20, { "Height" })
DefineControl("arrangement", "Orientation", 10, { "Orientation", "Group Orientation" })
DefineControl("arrangement", "Growth direction", 20, { "Growth direction" })
DefineControl("arrangement", "Spacing", 30, { "Spacing" })
DefineControl("icon", "Size", 20, { "Icon size" })
DefineControl("icon", "Spacing", 30, { "Icon spacing" })
DefineControl("buffIcons", "Size", 20, { "Buff icon size" })
DefineControl("debuffIcons", "Size", 20, { "Debuff icon size" })
DefineControl("buttons", "Size", 20, { "Button size" })
DefineControl("buttons", "Spacing", 30, { "Button spacing" })
DefineControl("bar", "Width", 10, { "Bar width" })
DefineControl("bar", "Height", 20, { "Bar height" })
DefineControl("bar", "Spacing", 30, { "Bar spacing" })
DefineControl("panel", "Height", 20, { "Panel height" })
DefineControl("minimap", "Size", 20, { "Minimap size" })
DefineControl("bar", "Texture", 40, { "Bar texture", "Cast bar texture" })
DefineControl("bar", "Color", 50, { "Bar color" })
DefineControl("barOpacity", "Opacity", 10, { "Bar opacity" })
DefineControl("background", "Color", 20, { "Background color", "Slot background color" })
DefineControl("swipe", "Color", 20, { "Swipe color" })
DefineControl("visibility", "Opacity", 20, { "Opacity", "Opacity (%)" })
DefineControl("visibility", "Only show in combat", 10, { "Only in combat", "Only show in combat" })
DefineControl("visibility", "Show on mouseover", 15, { "Show on mouseover" })
DefineControl("visibility", "Hide in combat", 11, { "Hide in combat" })
DefineControl("visibility", "Hide out of combat", 12, { "Hide out of combat" })
DefineControl("visibility", "Hide when inactive", 13, { "Hide when inactive" })
DefineControl("hidden", "Opacity", 10, { "Hidden opacity" })
DefineControl("unavailable", "Opacity", 10, { "Unavailable opacity" })
DefineControl("outOfCombat", "Opacity", 10, { "Out-of-combat opacity" })
DefineControl("resourceBars", "Spacing", 30, { "Gap between resource bars" })
DefineControl("stackedBars", "Spacing", 30, { "Gap between stacked bars" })

local TEXT_ROLES = {
  { "name", "Name", { "Name text size", "Name Font Size" }, { "Name text color" } },
  { "healthText", "Health", { "Health text size" }, { "Health text color" } },
  { "powerText", "Power", { "Power text size" }, { "Power text color" } },
  { "castTime", "Cast time", { "Time font size" }, {} },
  { "countdown", "Countdown", { "Cooldown font size", "Duration font size", "Countdown font size" }, { "Cooldown font color", "Countdown color" } },
  { "charges", "Charges", { "Charge font size" }, { "Charge font color" } },
  { "stacks", "Stacks", { "Stack font size" }, {} },
  { "counts", "Counts", { "Charges / stacks font size", "Count font size" }, { "Count color" } },
  { "keybinds", "Keybinds", { "Keybind font size" }, { "Keybind font color" } },
  { "macroName", "Macro name", { "Macro font size" }, {} },
  { "warning", "Warning", { "Warning size" }, {} },
  { "missingPet", "Missing pet", { "Missing pet size" }, { "Missing pet color" } },
  { "deadPet", "Dead pet", { "Dead pet size" }, { "Dead pet color" } },
  { "idleWarning", "Idle warning", { "Idle warning size" }, { "Idle warning color" } },
  { "clock", "Clock", { "Clock text size" }, {} },
  { "coordinates", "Coordinates", { "Coordinate text size" }, {} },
  { "zoneText", "Zone text", { "Zone text size" }, {} },
}
for index = 1, #TEXT_ROLES do
  local role = TEXT_ROLES[index]
  role[3][#role[3] + 1] = role[2] .. " font size"
  DefineControl(role[1], "Font", 40, { role[2] .. " font" })
  DefineControl(role[1], "Outline", 60, { role[2] .. " outline", role[2] .. " font outline" })
  DefineControl(role[1], "Font size", 50, role[3])
  DefineControl(role[1], "Text color", 70, role[4])
end
DefineControl("countdown", "Font", 40, { "Cooldown font", "Timer font" })
DefineControl("castTarget", "Maximum width", 110, { "Max target width" })
DefineControl("castTime", "Show text", 10, { "Show cast time", "Enable Cast Time" })
DefineControl("countdown", "Outline", 60, { "Cooldown font outline" })
DefineControl("charges", "Font", 40, { "Charge font" })
DefineControl("charges", "Outline", 60, { "Charge font outline" })
DefineControl("keybinds", "Font", 40, { "Keybind font" })
DefineControl("keybinds", "Outline", 60, { "Keybind font outline" })
DefineControl("name", "Horizontal offset", 90, { "Name X offset" })
DefineControl("name", "Vertical offset", 100, { "Name Y offset" })
DefineControl("castTime", "Horizontal offset", 90, { "Time X offset" })
DefineControl("castTime", "Vertical offset", 100, { "Time Y offset" })
DefineControl("countdown", "Horizontal offset", 90, { "Cooldown X offset", "Countdown X" })
DefineControl("countdown", "Vertical offset", 100, { "Cooldown Y offset", "Countdown Y" })
DefineControl("counts", "Horizontal offset", 90, { "Count X" })
DefineControl("counts", "Vertical offset", 100, { "Count Y" })
DefineControl("charges", "Horizontal offset", 90, { "Charge X offset", "Charge font offset X" })
DefineControl("charges", "Vertical offset", 100, { "Charge Y offset", "Charge font offset Y" })
DefineControl("keybinds", "Horizontal offset", 90, { "Keybind X offset" })
DefineControl("keybinds", "Vertical offset", 100, { "Keybind Y offset" })
DefineControl("countdown", "Anchor point", 80, { "Countdown anchor" })
DefineControl("counts", "Anchor point", 80, { "Count anchor" })
DefineControl("name", "Anchor point", 80, { "Spell Name Anchor" })
DefineControl("castTime", "Anchor point", 80, { "Cast Time anchor" })
DefineControl("countdown", "Scale", 55, { "Countdown scale" })
DefineControl("counts", "Scale", 55, { "Count scale" })
DefineControl("name", "Maximum width", 110, { "Max spell name width" })
DefineControl("countdown", "Show countdown", 10, { "Show cooldown text", "Show cooldown countdown", "Show duration text", "Show duration countdown" })
DefineControl("recharging", "Show countdown", 10, { "Recharge countdown", "Show recharge time" })
DefineControl("charges", "Show count", 10, { "Show charge count", "Show charges" })
DefineControl("counts", "Show count", 10, { "Show counts" })
DefineControl("stacks", "Show count", 10, { "Show stack count", "Show buff stacks", "Show stacks" })
DefineControl("macroName", "Show text", 10, { "Show macro text", "Show macro name" })
DefineControl("name", "Show text", 10, { "Show spell name", "Enable Spell Name" })

local BORDERS = {
  { "border", { "Border size", "Border thickness" }, { "Border color" } },
  { "iconBorder", { "Icon border size" }, { "Icon border color" } },
  { "backdropBorder", { "Backdrop border size" }, { "Backdrop border color" } },
  { "outerBorder", { "Outer border size" }, { "Outer border color" } },
  { "mouseoverBorder", { "Mouseover border size" }, {} },
  { "targetBorder", { "Target border size" }, {} },
  { "aggroBorder", { "Aggro border size" }, {} },
  { "chatBorder", { "Chat border size" }, { "Chat border" } },
  { "slotBorder", { "Slot border thickness" }, { "Slot border color" } },
}
for index = 1, #BORDERS do
  local border = BORDERS[index]
  DefineControl(border[1], "Thickness", 10, border[2])
  DefineControl(border[1], "Color", 20, border[3])
end
DefineControl("border", "Placement", 30, { "Border placement" })
DefineControl("ready", "Opacity", 10, { "Ready alpha", "Ready opacity" })
DefineControl("inactive", "Opacity", 10, { "Inactive alpha", "Inactive opacity" })
DefineControl("cooldown", "Opacity", 10, { "On cooldown alpha", "On cooldown opacity" })
DefineControl("recharging", "Opacity", 10, { "Recharging alpha" })
DefineControl("auraActive", "Opacity", 10, { "Active alpha", "Active aura alpha", "Aura active opacity" })
DefineControl("outOfRange", "Opacity", 10, { "Out of range alpha" })
DefineControl("instantCast", "Opacity", 20, { "Instant cast bar alpha" })
DefineControl("instantOverlay", "Opacity", 20, { "Instant cast overlay alpha" })
DefineControl("fadeIn", "Duration (seconds)", 20, { "Fade-in duration" })
DefineControl("fadeIn", "Opacity", 30, { "Fade-in opacity" })
DefineControl("fadeOut", "Duration (seconds)", 20, { "Fade-out duration", "Fade-out time", "Fade-out time (seconds)" })
DefineControl("fadeOut", "Delay (seconds)", 10, { "Fade-out delay" })
DefineControl("fadeOut", "Opacity", 30, { "Fade-out opacity", "Fade-out opacity (%)" })

local LABELS = {
  ["X offset"] = "Horizontal offset", ["Y offset"] = "Vertical offset",
  ["Anchor Point"] = "Anchor point", ["Anchor"] = "Anchor point",
  ["Type"] = "Display type", ["Group Orientation"] = "Orientation",
  ["Sort per Group"] = "Sort per group", ["Click Through"] = "Click through",
  ["Max icons per row"] = "Maximum icons per row",
  ["Max icons on first row"] = "Maximum icons on first row",
  ["Max stacks (segments)"] = "Maximum stacks",
  ["Number of buttons"] = "Buttons per bar",
  ["Show tooltip"] = "Show tooltips", ["Show tooltip on hover"] = "Show tooltips",
  ["Enable unit mouseover tooltips"] = "Show unit tooltips",
  ["Enable aura mouseover tooltips"] = "Show aura tooltips",
  ["Show Latency (Ping) overlay"] = "Show latency overlay",
  ["Show Spell Icon"] = "Show spell icon",
  ["Enable Main Tank Frames"] = "Enable main tank frames",
  ["Only in combat"] = "Only show in combat",
  ["Enable free moving"] = "Allow dragging",
  ["Reset to shared"] = "Reset to shared settings",
  ["Reset to default"] = "Reset to defaults",
  ["Enabled"] = "Enable",
  ["Enable auras (buffs/debuffs)"] = "Enable auras",
  ["Reset castbar to defaults"] = "Reset castbar settings",
  ["Delete shift"] = "Delete color shift",
  ["Add stack color shift"] = "Add color shift",
  ["Add stack color threshold"] = "Add color shift",
  ["SpellID filter mode"] = "Spell ID filter mode",
  ["Blacklist SpellIDs"] = "Blacklisted spell IDs",
  ["Custom buff SpellIDs"] = "Custom buff spell IDs",
  ["Show aura SpellIDs outside /pui"] = "Show aura spell IDs outside /pui",
  ["Opacity (%)"] = "Opacity",
  ["Use viewer setting"] = "Use group setting",
  ["Use inherited setting"] = "Use group setting",
}

local SECTION_NAMES = {
  ["General Settings"] = "General", ["General settings"] = "General",
  ["Features"] = "General",
  ["Font Settings"] = "Text",
  ["Bar Design"] = "Appearance", ["Bar Size & Layout"] = "Layout",
  ["Timers & Swipes"] = "Timers and swipes",
  ["Visibility & behavior"] = "Visibility",
  ["Cooldown text"] = "Countdown", ["Duration text"] = "Countdown",
  ["Timer text"] = "Countdown", ["Charge text"] = "Charges",
  ["Stack text"] = "Stacks", ["Button settings"] = "Icon",
  ["When on CD"] = "On cooldown", ["When Active"] = "Aura active",
  ["When active"] = "Aura active", ["When ready"] = "Ready",
  ["When recharging"] = "Recharging", ["When inactive"] = "Inactive",
  ["At full charges"] = "Full charges", ["State opacity"] = "Visibility",
  ["Name text"] = "Name", ["Keybind text"] = "Keybinds",
  ["Text and border"] = "Layout and appearance",
  ["Icon size"] = "Icons",
  ["Player buffs"] = "General",
  ["Top panel appearance"] = "Layout and appearance",
  ["Typography"] = "Text", ["Fade"] = "Visibility",
  ["Text and fonts"] = "Text", ["Font settings"] = "Text",
  ["Position and layout"] = "Layout",
  ["Button appearance"] = "Border", ["Box border"] = "Outer border",
  ["Swipes and timers"] = "Timers and swipes",
}
local SECTION_ORDER = {
  General = 10, Layout = 20, Appearance = 25,
  ["Layout and appearance"] = 20, Visibility = 30, Text = 40,
  ["Timers and swipes"] = 50, Glow = 60, Advanced = 90,
}
local TEXT_CONTEXTS = {
  Text = true, Font = true, Fonts = true, Typography = true, Message = true, Timer = true,
  Name = true, Health = true, Power = true, Warning = true,
  ["Missing pet"] = true, ["Dead pet"] = true, ["Idle warning"] = true,
  Clock = true, Coordinates = true, ["Zone text"] = true,
  ["Chat text"] = true, Tabs = true, Input = true,
  ["Top panel text"] = true, ["Emergency Salve"] = true,
  ["Bar font"] = true, ["Spell name"] = true, ["Cast time"] = true,
  Countdown = true, ["Duration countdown"] = true, Charges = true,
  Stacks = true, Counts = true, ["Charges / stacks"] = true, Keybinds = true,
  ["Keybind text"] = true, ["Macro text"] = true, ["Macro name"] = true,
}

local function HasContext(context, name)
  return context[name] == true
    or name == "Name" and context["Spell name"] == true
    or name == "Charges" and context["Charges / stacks"] == true
    or name == "Stacks" and context["Charges / stacks"] == true
    or name == "Counts" and context["Charges / stacks"] == true
    or name == "Countdown" and context["Duration countdown"] == true
    or name == "Keybinds" and context["Keybind text"] == true
end

local INLINE_NAMES = {
  core = "General", frameLayout = "Size and layout", indicators = "Indicators",
  textures = "Textures", sorting = "Sorting", groupLayout = "Raid groups",
  layout = "Layout", visibility = "Visibility", dispelIndicator = "Dispel indicator",
  roleSetup = "Role order", topLine = "General", pages = "Settings",
}

local PROPERTY_SECTIONS = {
  text = "Text", name = "Text", healthText = "Text", powerText = "Text",
  castTime = "Text", castTarget = "Text", countdown = "Text", charges = "Text",
  stacks = "Text", counts = "Text", keybinds = "Text", macroName = "Text",
  warning = "Text", missingPet = "Text", deadPet = "Text", idleWarning = "Text",
  clock = "Text", coordinates = "Text", zoneText = "Text", message = "Text", timerText = "Text",
  unitTooltips = "General", auraTooltips = "General",
  ready = "Visibility", inactive = "Visibility", cooldown = "Visibility",
  recharging = "Visibility", auraActive = "Visibility", outOfRange = "Visibility",
  fadeIn = "Visibility", fadeOut = "Visibility", visibility = "Visibility", barOpacity = "Visibility",
  hidden = "Visibility", unavailable = "Visibility", outOfCombat = "Visibility",
}

local PRESENTATION_SECTIONS = {
  Layout = true, Appearance = true, ["Layout and appearance"] = true,
  ["Frame style"] = true, ["Size and layout"] = true, Icons = true,
}

local INHERITED_FIELDS = { "get", "set", "func", "handler", "disabled", "hidden", "confirm", "validate", "arg" }

local function ArrangePageSections(group)
  local args = group.args
  local hasPages = false
  for _, child in pairs(args) do
    if child.type == "group" and not child.inline then hasPages = true end
  end
  if hasPages or TEXT_CONTEXTS[group.name] or PRESENTATION_SECTIONS[group.name]
    or group.name == "Visibility" then return end

  local lifted = {}
  for parentKey, parent in pairs(args) do
    if parent.type == "group" and parent.inline and PRESENTATION_SECTIONS[parent.name]
      and type(parent.args) == "table" then
      local remove = {}
      for key, child in pairs(parent.args) do
        local role = key:match("^puiStyle_(.+)$")
        local section = role and PROPERTY_SECTIONS[role]
        if child.type == "group" and (section == "Text" or section == "Visibility") then
          -- Moving a group must retain its original callbacks and conditions.
          for index = 1, #INHERITED_FIELDS do
            local field = INHERITED_FIELDS[index]
            if child[field] == nil then child[field] = parent[field] end
          end
          lifted["puiLift_" .. parentKey .. "_" .. key] = { role = role, option = child }
          remove[#remove + 1] = key
        end
      end
      for index = 1, #remove do parent.args[remove[index]] = nil end
    end
  end
  for key, item in pairs(lifted) do args[key] = item.option end

  local collected, counts = {}, {}
  local function Collect(section, key, option)
    collected[section] = collected[section] or {}
    collected[section][key] = option
    counts[section] = (counts[section] or 0) + 1
  end
  for key, child in pairs(args) do
    if child.type == "group" and child.inline then
      local role = key:match("^puiStyle_(.+)$") or lifted[key] and lifted[key].role
      if role then
        Collect(PROPERTY_SECTIONS[role] or "Layout and appearance", key, child)
      elseif TEXT_CONTEXTS[child.name] then
        Collect("Text", key, child)
      elseif PRESENTATION_SECTIONS[child.name] then
        Collect("Layout and appearance", key, child)
      end
    end
  end
  for section, children in pairs(collected) do
    local singleSection
    if counts[section] == 1 then
      for _, child in pairs(children) do singleSection = child.name == section end
    end
    if not singleSection then
      local key = section == "Text" and "puiText" or section == "Visibility" and "puiVisibility"
        or section == "General" and "puiGeneral" or "puiLayoutAppearance"
      local container = { type = "group", name = section == "General" and "Tooltips" or section,
        order = SECTION_ORDER[section], inline = true, args = children }
      for childKey, child in pairs(children) do
        args[childKey] = nil
        if section == "Layout and appearance" then
          if child.name == "Layout" then child.name = "Size and arrangement"
          elseif child.name == "Appearance" or child.name == section then child.name = "Style" end
        elseif section == "Text" and child.name == "Text" then
          child.name = "Typography"
        elseif section == "Visibility" and child.name == "Visibility" then
          child.name = "Conditions and opacity"
        end
      end
      args[key] = container
    end
  end
  for _, child in pairs(args) do
    if child.type == "group" and child.inline then
      child.order = SECTION_ORDER[child.name] or (60 + (tonumber(child.order) or 0) / 100)
    end
  end
end

local COMMON_CONTROLS = {
  { "Buttons", "Size" }, { "Buttons", "Spacing" },
  { "Icon", "Size" }, { "Icon", "Spacing" },
  { "Size", "Width" }, { "Size", "Height" },
  { "Visibility", "Only show in combat" }, { "Visibility", "Show on mouseover" },
  { "Keybinds", "Show keybinds" }, { "Countdown", "Show countdown" },
}

local function AddCommonSettings(group)
  local general, pages = nil, {}
  for _, child in pairs(group.args) do
    if child.type == "group" and not child.inline then
      if child.name == "General" then general = child
      elseif SECTION_ORDER[child.name] then pages[#pages + 1] = child end
    end
  end
  if not general or type(general.args) ~= "table" or #pages == 0
    or general.args.puiCommonSettings or general.args.quickLayout or general.args.quickText or general.args.quickTimers then return end

  local candidates = {}
  local function Visit(node, inherited)
    local effective = {}
    for key, value in pairs(inherited) do effective[key] = value end
    for index = 1, #INHERITED_FIELDS do
      local field = INHERITED_FIELDS[index]
      if node[field] ~= nil then effective[field] = node[field] end
    end
    if type(node.args) ~= "table" then return end
    for key, option in pairs(node.args) do
      if option.type == "group" then
        Visit(option, effective)
      else
        for index = 1, #COMMON_CONTROLS do
          local definition = COMMON_CONTROLS[index]
          if node.name == definition[1] and option.name == definition[2] then
            if candidates[index] == nil then
              candidates[index] = { key = key, option = option, inherited = effective, group = node.name }
            else
              candidates[index] = false
            end
          end
        end
      end
    end
  end
  for index = 1, #pages do Visit(pages[index], {}) end

  local common = { type = "group", name = "Common settings", order = 80, inline = true, args = {} }
  local count = 0
  for index = 1, #COMMON_CONTROLS do
    local candidate = candidates[index]
    if candidate and count < 6 then
      local key = "group" .. candidate.group
      local bucket = common.args[key]
      if not bucket then
        bucket = { type = "group", name = candidate.group, order = index, inline = true, args = {} }
        common.args[key] = bucket
      end
      local shortcut = {}
      for field, value in pairs(candidate.option) do shortcut[field] = value end
      for field, value in pairs(candidate.inherited) do
        if shortcut[field] == nil then shortcut[field] = value end
      end
      bucket.args[candidate.key] = shortcut
      count = count + 1
    end
  end
  if count > 0 then general.args.puiCommonSettings = common end
end

-- Providers can return the same table after their GUI cache is invalidated.
local APPLIED_GROUPS = setmetatable({}, { __mode = "k" })

local function FormatValues(values, isOutline)
  for key, label in pairs(values) do
    if label == "Use viewer setting" or label == "Use inherited setting" then
      values[key] = "Use group setting"
    elseif isOutline and label == "Use theme default" then
      values[key] = "Use global outline"
    end
  end
  return values
end

local function ArrangeGroup(group, context, groupKey)
  if APPLIED_GROUPS[group] then return end
  APPLIED_GROUPS[group] = true
  local name = group.name
  local inheritedText = context.text
  local nextContext = {}
  for key, value in pairs(context) do nextContext[key] = value end
  if type(name) == "string" then
    if name == "" or name == " " then
      name = INLINE_NAMES[groupKey] or "General"
    else
      name = SECTION_NAMES[name] or name
      if name == "Behavior" and not group.inline then name = "General" end
    end
    group.name = name
    nextContext[name] = true
    nextContext.text = inheritedText or TEXT_CONTEXTS[name] == true
  end

  local args = group.args
  if type(args) ~= "table" then return end
  local additions, removals = {}, {}
  local iconBorderOnly = false
  for _, option in pairs(args) do
    if option.name == "Icon border size" then iconBorderOnly = true end
    if option.name == "Border size" or option.name == "Border thickness" then
      iconBorderOnly = false
      break
    end
  end
  for key, option in pairs(args) do
    if option.type == "group" then
      ArrangeGroup(option, nextContext, key)
    elseif option.type ~= "description" and option.type ~= "header" and type(option.name) == "string" then
      local oldName = option.name
      local rule = RULES[oldName]
      if rule and rule.group == "buttons" and nextContext.moduleKey == "CooldownManager" then
        rule = { group = "icon", label = rule.label, order = rule.order }
      end
      if rule and oldName == "Border color" and iconBorderOnly then
        rule = { group = "iconBorder", label = "Color", order = 20 }
      elseif rule and oldName == "Icon border size" and nextContext.Border then
        rule = { group = "border", label = "Thickness", order = 10 }
      elseif rule and oldName == "Border color" and nextContext.Border then
        rule = { group = "border", label = "Color", order = 20 }
      end
      if rule then
        local definition = GROUPS[rule.group]
        local inContext = HasContext(nextContext, definition.name)
          or rule.group == "text" and nextContext.text
          or rule.group == "size" and (nextContext.Bar or nextContext.Buttons or nextContext.Icon)
        option.name = rule.label
        option.order = rule.order
        if not inContext then
          local groupKey = "puiStyle_" .. rule.group
          local bucket = additions[groupKey] or args[groupKey]
          if not bucket then
            bucket = { type = "group", name = definition.name, order = definition.order, inline = true, args = {} }
            additions[groupKey] = bucket
          end
          bucket.args[key] = option
          removals[#removals + 1] = key
          APPLIED_GROUPS[bucket] = true
        end
      else
        option.name = LABELS[oldName] or oldName
        if oldName == "Reset to default" and type(option.desc) == "string" then
          if option.desc:find("General settings", 1, true) then option.name = "Reset General settings"
          elseif option.desc:find("built-in aura display", 1, true) then option.name = "Reset aura display" end
        end
        if oldName == "Delete" and type(name) == "string" and name:match("^Window %d+$") then
          option.name = "Delete window"
        end
        if option.name == "Horizontal offset" then option.order = 90
        elseif option.name == "Vertical offset" then option.order = 100
        elseif option.name == "Anchor point" then option.order = 80
        elseif option.type == "toggle" and option.name:match("^Enable") then
          option.order = 5 + (tonumber(option.order) or 0) / 100
        elseif option.type == "toggle" and option.name:match("^Show") then
          option.order = 1 + (tonumber(option.order) or 0) / 100
        elseif option.type == "execute" and (tonumber(option.order) or 0) < 900 then
          option.order = 900 + (tonumber(option.order) or 0)
        end
      end
      if type(option.values) == "table" then
        FormatValues(option.values, option.name == "Outline")
      elseif type(option.values) == "function" then
        local valueProvider = option.values
        local isOutline = option.name == "Outline"
        option.values = function(...)
          return FormatValues(valueProvider(...), isOutline)
        end
      end
    end
  end
  for index = 1, #removals do args[removals[index]] = nil end
  for key, bucket in pairs(additions) do args[key] = bucket end

  ArrangePageSections(group)
  AddCommonSettings(group)

  local sectionCount = 0
  for _, option in pairs(args) do
    if option.type == "group" and not option.inline and SECTION_ORDER[option.name] then
      sectionCount = sectionCount + 1
    end
  end
  if sectionCount > 1 then
    for _, option in pairs(args) do
      if option.type == "group" and not option.inline and SECTION_ORDER[option.name] then
        option.order = SECTION_ORDER[option.name]
      end
    end
  end
end

function Schema.Apply(options, moduleKey)
  ArrangeGroup(options, { moduleKey = moduleKey })
end

function Schema.GetCompactLabel(label)
  if label == "Border size" then return "Border thickness" end
  if label == "Text size" then return "Font size" end
  if label == "Cooldown font size" then return "Countdown font size" end
  if label == "Show macro text" then return "Show macro name" end
  if label == "Active alpha" then return "Active aura opacity" end
  if label == "Inactive alpha" then return "Inactive opacity" end
  if label == "Ready alpha" then return "Ready opacity" end
  if label == "On cooldown alpha" then return "On cooldown opacity" end
  if label == "Recharging alpha" then return "Recharging opacity" end
  if label == "Fade-out time" then return "Fade-out time (seconds)" end
  if label == "Font outline" or label == "Text outline" then return "Outline" end
  if label == "Font color" then return "Text color" end
  return LABELS[label] or label
end
