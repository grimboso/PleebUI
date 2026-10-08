local _, ns = ...

local Options = {}
ns.PCMOptions = Options

local SECTIONS = {
  { "general", "General Settings" },
  { "layout", "Layout" },
  { "timer", "Timers & Swipes" },
  { "appearance", "Appearance" },
  { "text", "Text" },
  { "glow", "Glow" },
  { "advanced", "Advanced" },
}

local GROUP_SECTIONS = {
  general = "general", tracking = "general", placement = "general",
  layout = "layout", barLayout = "layout", icons = "layout",
  swipe = "timer", timer = "timer", duration = "timer",
  appearance = "appearance", design = "appearance", barDesign = "appearance",
  border = "layout", glow = "glow", stackColors = "appearance",
  slotColors = "appearance", ready = "appearance", cooldown = "appearance",
  active = "appearance", whenReady = "appearance", whenCooldown = "appearance",
  whenActive = "appearance", aura = "appearance",
  text = "text", textsFonts = "text", fonts = "text", fontSettings = "text",
  visibility = "general", behavior = "general", advanced = "advanced",
}

local FIELD_SECTIONS = {}
local function AssignFields(section, fields)
  for field in fields:gmatch("%S+") do
    FIELD_SECTIONS[field] = section
  end
end

AssignFields("general", "enabled name group auraTrackMode maxStacks powerInfusion bloodlust customBuffSpellIDs onlyOnUseTrinkets nativeTracking showSwipe swipeShow showTooltips showTooltip hideWhenInactive visibility combatOnly hideOutOfCombat outOfCombatAlpha missingAlpha readyAlpha readyAlphaOverride cooldownAlpha cooldownAlphaOverride onCooldownAlpha activeAlpha activeAuraAlpha auraAlpha auraAlphaOverride alpha opacity showOnlyWhenActive hideViewerIcon activeAuraHideViewerIcon")
AssignFields("layout", "size iconSize width height fixedWidth widthMode iconSpacing spacing columns iconsPerRow growUp growth rowGrowth growthDirection orientation rowSpacing wrap showIcon showSpellIconNextToBar iconPlacement iconAnchor durationHideIconFrame durationHideSpellIcon durationAnchor durationGap durationHeight durationIconSize borderThickness borderColor borderSize viewerBorderSize viewerBorderColor durationIconBorderSize durationIconBorderColor showSlotBorder slotBorderThickness slotBorderColor")
AssignFields("timer", "forceCooldown timerDisplay swipeSource durationSwipe durationText swipeGCD swipeCooldown swipeDuration countCooldown countDuration showCooldownText showDurationSwipe showDurationText rechargeCountdown barMode durationBarFillMode drainDirection fillDirection activeAuraSource activeAuraCDM activeAuraCustom source cdmBuff customBuff showActive hideDurationWhenMissing inheritedTimer swipeEdge swipeReverse swipeColorOverride swipeColor cooldownSwipeColor cooldownSwipeEdge durationSwipeColor durationSwipeEdge gcdSwipeColor gcdSwipeEdge rechargeEdge")
AssignFields("appearance", "texture barTexture stackTexture durationTexture useClassColor buffBarColor buffBarBgColor backgroundColor durationBarColor desaturateCooldown desaturateReady activeAuraDesaturate customTextureOverride chromeStyle readySaturationOverride readySaturation cooldownSaturationOverride cooldownSaturation auraSaturationOverride auraSaturation")
AssignFields("text", "cooldownShow showText showDuration showName countCharge countBuff countVisibility showItemQuality keybindToggle showKeybinds chargeShow keybindShow showCount showPips showStackStrip font fontSize fontColor fontOutline outline countFontSize cooldownFontSize keybindFontSize durationFont durationOutline durationCountFontSize countTextColor durationTextColor showCountdown durationTextScale durationTextAnchor durationTextX durationTextY countTextScale countTextAnchor countTextX countTextY")
AssignFields("glow", "glowDuringDurationSwipe readyGlowStyle readyGlowColor cooldownGlowStyle cooldownGlowColor auraGlowStyle auraGlowColor activeAuraGlowStyle activeAuraGlowColor glow glowColor activeGlowStyle")
AssignFields("advanced", "delete deleteBar resetIcon resetGroups customTexture rotateTexture dynamicTextOnSlot")

local QUICK_SETTINGS = {
  forceCooldown = { 1, "Enable duration timer" },
  timerDisplay = { 1, "Enable duration timer" },
  swipeSource = { 1, "Duration timer" },
  swipeCooldown = { 10, "Show cooldown swipe" },
  swipeDuration = { 11, "Show duration swipe" },
  showDurationSwipe = { 11, "Show duration swipe" },
  durationSwipe = { 11, "Duration swipe" },
  swipeGCD = { 12, "GCD swipe" },
  showCountdown = { 20, "Show countdown" },
  cooldownShow = { 20, "Show countdown" },
  showDuration = { 20, "Show countdown" },
  countCharge = { 21, "Show charges" },
  countBuff = { 21, "Show stacks" },
  chargeShow = { 21 },
  showCount = { 21 },
  keybindToggle = { 22, "Show keybinds" },
  keybindShow = { 22, "Show keybinds" },
  showKeybinds = { 22, "Show keybinds" },
  cooldownFontSize = { 30, "Countdown font size" },
  DurationSize = { 30, "Countdown font size" },
  fontSize = { 30 },
  chargeFontSize = { 31, "Charges / stacks font size" },
  StackSize = { 31, "Stacks font size" },
  countFontSize = { 31, "Charges / stacks font size" },
  keybindFontSize = { 32, "Keybind font size" },
  enabled = { 40, "Enable custom glow" },
  size = { 50, "Icon size" },
  iconSize = { 50, "Icon size" },
  fixedWidth = { 51, "Width" },
  width = { 51 },
  height = { 52 },
  spacing = { 53 },
  iconSpacing = { 53, "Icon spacing" },
  columns = { 54, "Icons per row" },
}

local LABELS = {
  ["Use viewer setting"] = "Use inherited setting",
  ["Button size"] = "Icon size",
  ["Button settings"] = "Icon settings",
  ["Show cooldown text"] = "Show cooldown countdown",
  ["Show duration text"] = "Show duration countdown",
  ["Cooldown text"] = "Countdown",
  ["Duration text"] = "Duration countdown",
  ["Timer text"] = "Countdown",
  ["Charge text"] = "Charges",
  ["Stack text"] = "Stacks",
  ["Font Settings"] = "Text",
  ["Bar Size & Layout"] = "Layout",
  ["Bar Design"] = "Appearance",
  ["When on CD"] = "On cooldown",
  ["When Active"] = "Aura active",
  ["When active"] = "Aura active",
  ["When ready"] = "Ready",
  ["When recharging"] = "Recharging",
  ["At full charges"] = "Full charges",
  ["When inactive"] = "Inactive",
  ["Ready alpha"] = "Ready opacity",
  ["Inactive alpha"] = "Inactive opacity",
  ["On cooldown alpha"] = "On cooldown opacity",
  ["Active aura alpha"] = "Aura active opacity",
  ["Active alpha"] = "Aura active opacity",
  ["Border size"] = "Border thickness",
  ["Show stack count"] = "Show stacks",
}

local function CombineHidden(parent, child)
  if parent == nil then return child end
  if child == nil then return parent end
  if parent == true or child == true then return true end
  return function(info)
    local parentHidden = parent
    if type(parent) == "function" then parentHidden = parent(info) end
    if parentHidden then return true end
    if type(child) == "function" then return child(info) end
    return child
  end
end

function Options:BuildSections(source)
  local sections = {}
  for index = 1, #SECTIONS do
    local definition = SECTIONS[index]
    sections[definition[1]] = {
      type = "group", name = definition[2], order = index * 10, args = {},
    }
  end

  local function Collect(args, category, prefix, label, hidden)
    for key, option in pairs(args) do
      local optionKey = prefix == "" and key or prefix .. "_" .. key
      option.name = LABELS[option.name] or option.name
      if type(option.values) == "table" then
        for value, name in pairs(option.values) do
          option.values[value] = LABELS[name] or name
        end
      end
      if option.type == "group" then
        local nextCategory = GROUP_SECTIONS[key] or (key:lower():find("glow", 1, true) and "glow") or category
        if key == "specializationSpells" then
          option.name = "Spell assignments"
          option.order = 20
          sections.general.args[optionKey] = option
        else
          Collect(option.args or {}, nextCategory, optionKey, option.name, CombineHidden(hidden, option.hidden))
        end
      elseif option.type ~= "header" then
        local destination = FIELD_SECTIONS[key] or category
        local bucketPrefix, bucketLabel = prefix, label
        local role = key:match("^(cooldown)") or key:match("^(charge)") or key:match("^(keybind)")
          or key:match("^Duration") and "cooldown" or key:match("^Stack") and "charge"
        if category == "glow" or prefix:match("whenActive$") and (key == "thickness" or key == "color") then
          destination = "glow"
        elseif key == "showDuration" and prefix == "duration" then
          destination = "timer"
        elseif not FIELD_SECTIONS[key] and role then
          destination = "text"
        elseif not FIELD_SECTIONS[key] and (key:match("Anchor$") or key:match("Offset[XY]$")
          or key:match("PositionOverride$") or key:match("Text[XY]$")
          or key:match("TextScale$") or key:match("fontOffset[XY]$"))
        then
          destination = "text"
        end
        if destination == "text" then
          if key == "showCountdown" or key == "showDuration" or key:match("^durationText")
            or key == "fontSize" and prefix == "icon_fonts" then
            role = "cooldown"
          elseif key == "countCharge" or key == "countBuff" or key == "showCount" or key == "countFontSize" or key:match("^countText") then
            role = "charge"
          elseif key == "keybindToggle" or key == "showKeybinds" then
            role = "keybind"
          end
          if role then
            bucketPrefix = role
            bucketLabel = role == "cooldown" and "Countdown" or role == "charge" and "Charges / stacks" or "Keybinds"
          end
        elseif destination == "timer" then
          if key:lower():find("gcd", 1, true) then
            bucketPrefix, bucketLabel = "gcdTimer", "Global cooldown"
          elseif key:lower():find("duration", 1, true) or key:match("^activeAura")
            or key == "forceCooldown" or key == "timerDisplay" or key == "swipeSource"
            or key == "showActive" or key == "source" or key == "cdmBuff" or key == "customBuff"
          then
            bucketPrefix, bucketLabel = "durationTimer", "Duration timer"
          elseif key:lower():find("cooldown", 1, true) or key:match("^recharge") then
            bucketPrefix, bucketLabel = "cooldownTimer", "Cooldown timer"
          else
            bucketPrefix, bucketLabel = "swipeSettings", "Swipe settings"
          end
        end
        if destination == "timer" then
          option.name = option.name:gsub("[Gg]lobal cooldown swipe", "Swipe"):gsub("GCD swipe", "Swipe")
            :gsub("[Cc]ooldown swipe", "Swipe"):gsub("[Dd]uration swipe", "Swipe")
            :gsub("Show Swipe", "Show swipe"):gsub("^Show cooldown countdown$", "Show countdown")
            :gsub("^Show duration countdown$", "Show countdown")
        end
        option.hidden = CombineHidden(hidden, option.hidden)
        local quickSetting = QUICK_SETTINGS[key]
        if quickSetting and destination ~= "general" and option.hidden ~= true
          and (key ~= "enabled" or destination == "glow")
          and (key ~= "showDuration" or destination == "text")
        then
          local quickSettings = sections.general.args.quickSettings
          if not quickSettings then
            quickSettings = { type = "group", name = "Quick settings", inline = true, order = 2, args = {} }
            sections.general.args.quickSettings = quickSettings
          end
          local shortcut = {}
          for field, value in pairs(option) do
            shortcut[field] = value
          end
          shortcut.name = quickSetting[2] or option.name
          shortcut.order = quickSetting[1]
          quickSettings.args[optionKey] = shortcut
        end
        local sectionArgs = sections[destination].args
        if bucketPrefix ~= "" and bucketLabel ~= sections[destination].name and bucketLabel ~= "General"
          and bucketLabel ~= "Icon settings" and bucketLabel ~= "Group settings"
        then
          local bucket = sectionArgs[bucketPrefix]
          if not bucket then
            local order = destination == "timer" and (bucketPrefix == "durationTimer" and 10
              or bucketPrefix == "cooldownTimer" and 20 or bucketPrefix == "gcdTimer" and 30 or 40)
              or destination == "text" and (bucketPrefix == "cooldown" and 10
                or bucketPrefix == "charge" and 20 or bucketPrefix == "keybind" and 30)
              or option.order
            bucket = { type = "group", name = bucketLabel, inline = true, order = order, args = {} }
            sectionArgs[bucketPrefix] = bucket
          elseif destination ~= "timer" and destination ~= "text"
            and (tonumber(option.order) or 50) < (tonumber(bucket.order) or 50) then
            bucket.order = option.order
          end
          bucket.args[optionKey] = option
        else
          sectionArgs[optionKey] = option
        end
      end
    end
  end

  Collect(source, "general", "", "", nil)
  for key, section in pairs(sections) do
    if next(section.args) == nil then sections[key] = nil end
  end
  return sections
end

function Options.ResolvePath(path)
  local groups = ns.PCMGroupManager:GetGroups()
  if not path[2] then path[2] = "overview" end
  -- Mover shortcuts identify a group by ID; its editor owns the route.
  if groups.byID[path[2]] then
    local groupID = path[2]
    local entryKey = path[3]
    path = { "CooldownManager", "groups", groupID }
    if entryKey and entryKey ~= "settings" then
      path[4] = "entries"
      path[5] = entryKey
    end
  elseif path[2] == "developer" then
    path = { "CooldownManager", "advanced" }
  end
  if path[2] == "groups" and not path[3] then
    path[3] = groups.order[1]
  elseif path[2] == "customTrackers" and not path[3] then
    local candidates = {}
    local owner = ns.Modules.CooldownManager
    for _, source in ipairs({
      { "spell", owner:GetSpellBarsDB(), owner.IsSpellBarLoaded },
      { "chargeSpell", owner:GetCooldownStackBarsDB(), owner.IsChargeCooldownBarLoaded },
      { "bb", ns.Modules.PCM_BB.GetStackBarsDB(), owner.IsBuffBarLoaded },
    }) do
      for id, config in pairs(source[2]) do
        candidates[#candidates + 1] = {
          key = source[1] .. ":" .. tostring(id),
          name = owner:GetCustomBarDisplayName(config), loaded = source[3](config),
        }
      end
    end
    table.sort(candidates, function(a, b)
      if a.loaded ~= b.loaded then return a.loaded end
      if a.name ~= b.name then return a.name < b.name end
      return a.key < b.key
    end)
    local first = candidates[1]
    if first then
      if first.loaded then path[3] = first.key
      else path[3], path[4] = "__disabledNotLoaded", first.key end
    end
  end
  return path
end

function Options.CacheKey(path)
  path = path or {}
  if path[2] == "groups" then
    local entries = path[4] == "entries"
    return table.concat({ "groups", path[3] or "", entries and "entries" or "settings", entries and path[5] or "" }, "\031")
  end
  if path[2] == "customTrackers" then
    local key = path[3] == "__disabledNotLoaded" and path[4] or path[3]
    return table.concat({ "customTrackers", path[3] or "", key or "" }, "\031")
  end
  return path[2] or "overview"
end

function Options.GetSearchEntries()
  local results = {}
  local function Add(label, path, keywords)
    results[#results + 1] = { label = label, path = path, keywords = keywords or "" }
  end
  local settingKeywords = {
    general = "general quick settings enabled visibility opacity tooltip spell specialization assignment timer swipe countdown charges stacks keybind font size glow",
    layout = "layout size width height spacing rows columns orientation growth icon position",
    timer = "timer display duration active aura buff cooldown gcd swipe countdown recharge fill drain",
    appearance = "appearance color saturation desaturate texture",
    text = "text font size outline anchor offset countdown charges stacks keybinds name",
    glow = "glow style color speed scale lines thickness aura ready cooldown",
    advanced = "advanced reset delete custom texture",
  }
  local groups = ns.PCMGroupManager:GetGroups()
  for index = 1, #groups.order do
    local groupID = groups.order[index]
    local group = groups.byID[groupID]
    local path = { "CooldownManager", "groups", groupID }
    Add("Groups / " .. group.name, path, groupID)
    for sectionIndex = 1, #SECTIONS do
      local section = SECTIONS[sectionIndex]
      local available
      if group.isDefault then
        if group.defaultViewerKey == "BuffIconCooldownViewer" then
          available = section[1] == "general" or section[1] == "layout" or section[1] == "timer" or section[1] == "text"
        elseif group.defaultViewerKey == "BuffBarCooldownViewer" then
          available = section[1] ~= "glow" and section[1] ~= "advanced"
        else
          available = section[1] ~= "advanced"
        end
      else
        available = section[1] == "general" or section[1] == "layout" or section[1] == "advanced"
      end
      if available then
        Add("Groups / " .. group.name .. " / " .. section[2],
          { "CooldownManager", "groups", groupID, section[1] }, settingKeywords[section[1]])
      end
    end
    local activeGroup = ns.PCMGroupManager:GetActiveGroup(groupID)
    for recordIndex = 1, #(activeGroup and activeGroup.records or {}) do
      local entry = activeGroup.records[recordIndex].entry
      Add("Groups / " .. group.name .. " / " .. tostring(entry.name),
        { "CooldownManager", "groups", groupID, "entries", entry.catalogKey },
        tostring(entry.spellID or "") .. " " .. entry.catalogKey)
    end
  end
  local owner = ns.Modules.CooldownManager
  for _, source in ipairs({
    { "spell", owner:GetSpellBarsDB() }, { "chargeSpell", owner:GetCooldownStackBarsDB() },
    { "bb", ns.Modules.PCM_BB.GetStackBarsDB() },
  }) do
    for id, config in pairs(source[2]) do
      local key = source[1] .. ":" .. tostring(id)
      local path = { "CooldownManager", "customTrackers", key }
      local loaded = source[1] == "spell" and owner.IsSpellBarLoaded(config)
        or source[1] == "chargeSpell" and owner.IsChargeCooldownBarLoaded(config)
        or source[1] == "bb" and owner.IsBuffBarLoaded(config)
      if not loaded then path = { "CooldownManager", "customTrackers", "__disabledNotLoaded", key } end
      local keywords = "custom tracker " .. tostring(config.label or "") .. " " .. tostring(config.kind or source[1])
      for _, assignment in pairs(config.specAssignments or {}) do
        keywords = keywords .. " " .. tostring(assignment.spellName or "") .. " " .. tostring(assignment.spellID or "")
      end
      for _, words in pairs(settingKeywords) do keywords = keywords .. " " .. words end
      Add("Custom trackers / " .. owner:GetCustomBarDisplayName(config), path, keywords)
      for sectionIndex = 1, #SECTIONS do
        local section = SECTIONS[sectionIndex]
        local sectionPath = {}
        for index = 1, #path do sectionPath[index] = path[index] end
        sectionPath[#sectionPath + 1] = section[1]
        Add("Custom trackers / " .. owner:GetCustomBarDisplayName(config) .. " / " .. section[2],
          sectionPath, tostring(config.label or "") .. " " .. settingKeywords[section[1]])
      end
    end
  end
  local definitions = owner:GetConsumableTrackerDefinitions()
  for index = 1, #definitions do
    local definition = definitions[index]
    Add("Items & racials / " .. definition.label,
      { "CooldownManager", "consumables", "slots", definition.key }, definition.key)
  end
  for sectionIndex = 1, #SECTIONS do
    local section = SECTIONS[sectionIndex]
    if section[1] ~= "advanced" then
      Add("Items & racials / " .. section[2],
        { "CooldownManager", "consumables", section[1] }, settingKeywords[section[1]])
    end
  end
  Add("Overview", { "CooldownManager", "overview" }, "enable create group add tracker layout summary")
  Add("Advanced", { "CooldownManager", "advanced" }, "developer diagnostics native opacity reset groups")
  return results
end
