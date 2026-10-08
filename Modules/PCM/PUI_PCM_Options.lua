local _, ns = ...

local Options = { entryFilters = {} }
ns.PCMOptions = Options

local SECTIONS = {
  { "tracking", "Tracking" },
  { "layout", "Layout" },
  { "timer", "Timer" },
  { "appearance", "Appearance" },
  { "text", "Text" },
  { "visibility", "Visibility" },
  { "advanced", "Advanced" },
}

local GROUP_SECTIONS = {
  general = "tracking", tracking = "tracking", placement = "tracking",
  layout = "layout", barLayout = "layout", icons = "layout",
  swipe = "timer", timer = "timer", duration = "timer",
  appearance = "appearance", design = "appearance", barDesign = "appearance",
  border = "appearance", glow = "appearance", stackColors = "appearance",
  slotColors = "appearance", ready = "appearance", cooldown = "appearance",
  active = "appearance", whenReady = "appearance", whenCooldown = "appearance",
  whenActive = "appearance", aura = "appearance",
  text = "text", textsFonts = "text", fonts = "text", fontSettings = "text",
  visibility = "visibility", behavior = "visibility", advanced = "advanced",
}

local FIELD_SECTIONS = {}
local function AssignFields(section, fields)
  for field in fields:gmatch("%S+") do
    FIELD_SECTIONS[field] = section
  end
end

AssignFields("tracking", "enabled name group auraTrackMode maxStacks powerInfusion bloodlust customBuffSpellIDs onlyOnUseTrinkets")
AssignFields("layout", "size iconSize width height fixedWidth widthMode iconSpacing spacing columns iconsPerRow growUp growth rowGrowth growthDirection orientation rowSpacing wrap showIcon showSpellIconNextToBar iconPlacement iconAnchor durationHideIconFrame durationAnchor durationGap durationHeight durationIconSize")
AssignFields("timer", "forceCooldown timerDisplay swipeSource swipeShow durationSwipe durationText swipeGCD swipeCooldown swipeDuration countCooldown countDuration cooldownShow showSwipe showDuration showCooldownText showDurationSwipe showDurationText rechargeCountdown showText barMode drainDirection fillDirection activeAuraSource activeAuraCDM activeAuraCustom source cdmBuff customBuff showActive hideDurationWhenMissing inheritedTimer")
AssignFields("appearance", "borderThickness borderColor borderSize viewerBorderSize viewerBorderColor texture barTexture useClassColor buffBarColor buffBarBgColor backgroundColor glowDuringDurationSwipe desaturateCooldown desaturateReady activeAuraDesaturate customTextureOverride")
AssignFields("text", "showName countCharge countBuff countVisibility showItemQuality keybindToggle showKeybinds chargeShow keybindShow showCount showPips showStackStrip font fontSize fontColor fontOutline outline countFontSize cooldownFontSize keybindFontSize durationFont durationOutline durationCountFontSize countTextColor durationTextColor")
AssignFields("visibility", "showTooltips showTooltip hideWhenInactive visibility combatOnly hideOutOfCombat outOfCombatAlpha missingAlpha readyAlpha readyAlphaOverride cooldownAlpha cooldownAlphaOverride onCooldownAlpha activeAlpha activeAuraAlpha auraAlpha auraAlphaOverride alpha opacity showOnlyWhenActive hideViewerIcon activeAuraHideViewerIcon")
AssignFields("advanced", "delete deleteBar resetIcon resetGroups customTexture swipeEdge swipeReverse swipeColorOverride swipeColor cooldownSwipeColor cooldownSwipeEdge durationSwipeColor durationSwipeEdge gcdSwipeColor gcdSwipeEdge rechargeEdge rotateTexture dynamicTextOnSlot")

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
        local nextCategory = GROUP_SECTIONS[key] or category
        if key == "specializationSpells" then
          option.name = "Spell assignments"
          option.order = 20
          sections.tracking.args[optionKey] = option
        else
          Collect(option.args or {}, nextCategory, optionKey, option.name, CombineHidden(hidden, option.hidden))
        end
      elseif option.type ~= "header" then
        local destination = FIELD_SECTIONS[key] or category
        local bucketPrefix, bucketLabel = prefix, label
        if FIELD_SECTIONS[key] ~= "layout" and (key:match("Anchor$") or key:match("Offset[XY]$")
          or key:match("PositionOverride$") or key:match("Text[XY]$")
          or key:match("TextScale$") or key:match("fontOffset[XY]$"))
        then
          destination = "advanced"
        elseif key:match("^cooldown") or key:match("^charge") or key:match("^keybind")
          or key:match("^Duration") or key:match("^Stack")
        then
          destination = FIELD_SECTIONS[key] or "text"
        end
        if prefix == "" and (destination == "text" or destination == "advanced") then
          local role = key:match("^(cooldown)") or key:match("^(charge)") or key:match("^(keybind)")
          if role then
            bucketPrefix = role
            bucketLabel = role == "cooldown" and "Countdown" or role == "charge" and "Charges / stacks" or "Keybinds"
          end
        end
        option.hidden = CombineHidden(hidden, option.hidden)
        local sectionArgs = sections[destination].args
        if bucketPrefix ~= "" and bucketLabel ~= sections[destination].name and bucketLabel ~= "General"
          and bucketLabel ~= "Icon settings" and bucketLabel ~= "Group settings"
        then
          local bucket = sectionArgs[bucketPrefix]
          if not bucket then
            bucket = { type = "group", name = bucketLabel, inline = true, order = option.order, args = {} }
            sectionArgs[bucketPrefix] = bucket
          elseif (tonumber(option.order) or 50) < (tonumber(bucket.order) or 50) then
            bucket.order = option.order
          end
          bucket.args[key] = option
        else
          sectionArgs[optionKey] = option
        end
      end
    end
  end

  Collect(source, "tracking", "", "", nil)
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
  if path[2] == "groups" and path[4] == "entries" and path[5] then
    local record = ns.PCMGroupManager:GetActiveRecord(path[5])
    if record and not Options:MatchesEntry(path[3], record.entry) then
      Options.entryFilters[path[3]] = nil
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

function Options:MatchesEntry(groupID, entry)
  local query = self.entryFilters[groupID]
  if not query or query == "" then return true end
  local text = string.lower(tostring(entry.name) .. " " .. tostring(entry.spellID or "") .. " " .. tostring(entry.catalogKey))
  for token in query:gmatch("%S+") do
    if not text:find(token, 1, true) then return false end
  end
  return true
end

function Options.GetSearchEntries()
  local results = {}
  local function Add(label, path, keywords)
    results[#results + 1] = { label = label, path = path, keywords = keywords or "" }
  end
  local settingKeywords = {
    tracking = "tracking enabled tooltip spell specialization assignment",
    layout = "layout size width height spacing rows columns orientation growth icon position",
    timer = "timer display duration active aura buff cooldown gcd swipe countdown recharge fill drain",
    appearance = "appearance border color saturation desaturate texture glow",
    text = "text font size outline countdown charges stacks keybinds name",
    visibility = "visibility opacity alpha hide combat inactive ready tooltip",
    advanced = "advanced font anchor offset swipe color edge direction reset delete",
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
        available = groupID ~= "buff-bars" or section[1] ~= "advanced"
      else
        available = section[1] == "tracking" or section[1] == "layout" or section[1] == "advanced"
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
