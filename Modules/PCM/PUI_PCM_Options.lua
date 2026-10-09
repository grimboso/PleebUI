local _, ns = ...

local Options = {}
ns.PCMOptions = Options

local SECTIONS = {
  { "general", "General" },
  { "layout", "Layout and appearance" },
  { "visibility", "Visibility" },
  { "text", "Text" },
  { "timer", "Timers and swipes" },
  { "glow", "Glow" },
  { "advanced", "Advanced" },
}

local GROUP_SECTIONS = {
  general = "general", tracking = "general", placement = "general",
  layout = "layout", barLayout = "layout", icons = "layout",
  swipe = "timer", timer = "timer", duration = "timer",
  appearance = "layout", design = "layout", barDesign = "layout",
  border = "layout", glow = "glow", stackColors = "layout",
  slotColors = "layout", ready = "layout", cooldown = "layout",
  active = "layout", whenReady = "layout", whenCooldown = "layout",
  whenActive = "layout", aura = "layout",
  text = "text", textsFonts = "text", fonts = "text", fontSettings = "text",
  visibility = "visibility", behavior = "general", advanced = "advanced",
}

local FIELD_SECTIONS = {}
local function AssignFields(section, fields)
  for field in fields:gmatch("%S+") do
    FIELD_SECTIONS[field] = section
  end
end

AssignFields("general", "enabled name group auraTrackMode maxStacks powerInfusion bloodlust customBuffSpellIDs onlyOnUseTrinkets nativeTracking showSwipe swipeShow showTooltips showTooltip")
AssignFields("layout", "size iconSize width height fixedWidth widthMode iconSpacing spacing columns iconsPerRow growUp growth rowGrowth growthDirection orientation rowSpacing wrap showIcon showSpellIconNextToBar iconPlacement iconAnchor durationHideIconFrame durationHideSpellIcon durationAnchor durationGap durationHeight durationIconSize borderThickness borderColor borderSize viewerBorderSize viewerBorderColor durationIconBorderSize durationIconBorderColor showSlotBorder slotBorderThickness slotBorderColor")
AssignFields("timer", "forceCooldown cooldownTimerEnabled timerDisplay swipeSource durationSwipe durationText swipeGCD swipeCooldown swipeDuration countCooldown countDuration showCooldownText showDurationSwipe showDurationText rechargeCountdown barMode durationBarFillMode drainDirection fillDirection activeAuraSource activeAuraCDM activeAuraCustom source cdmBuff customBuff showActive hideDurationWhenMissing inheritedTimer swipeEdge swipeReverse swipeColorOverride swipeColor cooldownSwipeColor cooldownSwipeEdge cooldownSwipeEdgeColor durationSwipeColor durationSwipeEdge durationSwipeEdgeColor gcdSwipeColor gcdSwipeEdge gcdSwipeEdgeColor rechargeEdge")
AssignFields("visibility", "visibility combatOnly hideOutOfCombat outOfCombatAlpha missingAlpha readyAlpha readyAlphaOverride cooldownAlpha cooldownAlphaOverride onCooldownAlpha activeAlpha activeAuraAlpha auraAlpha auraAlphaOverride alpha opacity showOnlyWhenActive hideWhenInactive hideViewerIcon activeAuraHideViewerIcon")
AssignFields("layout", "desaturateCooldown")
AssignFields("layout", "texture barTexture stackTexture durationTexture useClassColor buffBarColor buffBarBgColor backgroundColor durationBarColor desaturateReady activeAuraDesaturate customTextureOverride chromeStyle readySaturationOverride readySaturation cooldownSaturationOverride cooldownSaturation auraSaturationOverride auraSaturation")
AssignFields("text", "cooldownShow showText showDuration showName countCharge countBuff countVisibility showItemQuality keybindToggle showKeybinds chargeShow keybindShow showCount showPips showStackStrip font fontSize fontColor fontOutline outline countFontSize cooldownFontSize keybindFontSize durationFont durationOutline durationCountFontSize countTextColor durationTextColor showCountdown durationTextScale durationTextAnchor durationTextX durationTextY countTextScale countTextAnchor countTextX countTextY")
AssignFields("glow", "glowDuringDurationSwipe readyGlowStyle readyGlowColor cooldownGlowStyle cooldownGlowColor auraGlowStyle auraGlowColor activeAuraGlowStyle activeAuraGlowColor glow glowColor activeGlowStyle")
AssignFields("advanced", "delete deleteBar resetIcon resetGroups customTexture rotateTexture dynamicTextOnSlot")

local QUICK_SETTINGS = {
  forceCooldown = { 1, "Enable duration timer" },
  cooldownTimerEnabled = { 2, "Enable cooldown timer" },
  timerDisplay = { 1, "Enable duration timer" },
  swipeSource = { 1, "Enable duration timer" },
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
  enabled = { 40, "Enable custom glow" },
  desaturateCooldown = { 21, "Desaturation" },
  size = { 50, "Icon size" },
  iconSize = { 50, "Icon size" },
  fixedWidth = { 51, "Width" },
  width = { 51 },
  height = { 52 },
  spacing = { 53 },
  iconSpacing = { 53, "Icon spacing" },
  columns = { 54, "Icons per row" },
}

local INLINE_GROUPS = {
  groupSettings = { "Group", 5 },
  tracking = { "Tracking", 10 },
  behavior = { "Behaviour", 20 },
  quickTimers = { "Timers & swipes", 30 },
  quickText = { "Text", 40 },
  quickLayout = { "Size & spacing", 50 },
  quickGlow = { "Glow", 60 },
  size = { "Size", 10 },
  arrangement = { "Arrangement", 20 },
  iconPlacement = { "Behaviour", 30 },
  borders = { "Borders", 40 },
  styling = { "Bar style", 35 },
  saturation = { "Saturation", 45 },
  glowStyle = { "Glow style", 10 },
  glowShape = { "Animation & shape", 20 },
  readyGlow = { "Ready", 30 },
  cooldownGlow = { "On cooldown / recharging", 40 },
  auraGlow = { "While active", 50 },
}

local GENERAL_GROUPS, LAYOUT_GROUPS = {}, {}
local function AssignInlineGroup(groups, group, fields)
  for field in fields:gmatch("%S+") do groups[field] = group end
end
AssignInlineGroup(GENERAL_GROUPS, "groupSettings", "enabled name group")
AssignInlineGroup(GENERAL_GROUPS, "tracking", "nativeTracking auraTrackMode maxStacks powerInfusion bloodlust customBuffSpellIDs onlyOnUseTrinkets")
AssignInlineGroup(GENERAL_GROUPS, "quickTimers", "showSwipe swipeShow")
AssignInlineGroup(LAYOUT_GROUPS, "size", "size iconSize width height fixedWidth widthMode durationHeight durationIconSize")
AssignInlineGroup(LAYOUT_GROUPS, "arrangement", "iconSpacing spacing columns iconsPerRow growUp growth rowGrowth growthDirection orientation rowSpacing wrap")
AssignInlineGroup(LAYOUT_GROUPS, "iconPlacement", "showIcon showSpellIconNextToBar iconPlacement iconAnchor durationHideIconFrame durationHideSpellIcon durationAnchor durationGap")
AssignInlineGroup(LAYOUT_GROUPS, "borders", "borderThickness borderColor borderSize viewerBorderSize viewerBorderColor durationIconBorderSize durationIconBorderColor showSlotBorder slotBorderThickness slotBorderColor")

AssignInlineGroup(LAYOUT_GROUPS, "styling", "texture barTexture stackTexture durationTexture useClassColor buffBarColor buffBarBgColor backgroundColor durationBarColor customTextureOverride chromeStyle")
AssignInlineGroup(LAYOUT_GROUPS, "saturation", "desaturateCooldown desaturateReady activeAuraDesaturate readySaturationOverride readySaturation cooldownSaturationOverride cooldownSaturation auraSaturationOverride auraSaturation")

local TIMER_ROWS = {
  forceCooldown = { 1, 0.5, "Enable duration timer" },
  cooldownTimerEnabled = { 1, 0.5, "Enable cooldown timer" },
  countDuration = { 2, 0.5, "Show countdown" },
  countCooldown = { 2, 0.5, "Show countdown" },
  swipeDuration = { 3, 0.25, "Show swipe" },
  swipeCooldown = { 3, 0.25, "Show swipe" },
  swipeGCD = { 3, 0.25, "Show swipe" },
  durationSwipe = { 3, 0.25, "Show swipe" },
  showDurationSwipe = { 3, 0.25, "Show swipe" },
  durationSwipeColor = { 4, 0.25, "Swipe color" },
  cooldownSwipeColor = { 4, 0.25, "Swipe color" },
  durationSwipeEdge = { 5, 0.25, "Swipe edge" },
  cooldownSwipeEdge = { 5, 0.25, "Swipe edge" },
  durationSwipeEdgeColor = { 6, 0.25, "Swipe edge color" },
  cooldownSwipeEdgeColor = { 6, 0.25, "Swipe edge color" },
  gcdSwipeColor = { 4, 0.25, "Swipe color" },
  gcdSwipeEdge = { 5, 0.25, "Swipe edge" },
  gcdSwipeEdgeColor = { 6, 0.25, "Swipe edge color" },
}

local function CombineCondition(parent, child)
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

function Options:BuildSections(source, context)
  context = context or {}
  local sections = {}
  local hasStackStyle, hasCharges, hasStacks = false, false, false
  local function InspectTextRoles(args)
    for key, option in pairs(args) do
      if option.type == "group" and option.hidden ~= true then
        InspectTextRoles(option.args or {})
      elseif option.hidden ~= true then
        if key:match("^Stack") then hasStackStyle = true end
        if key == "countCharge" then hasCharges = true end
        if key == "countBuff" then hasStacks = true end
      end
    end
  end
  InspectTextRoles(source)
  for index = 1, #SECTIONS do
    local definition = SECTIONS[index]
    sections[definition[1]] = {
      type = "group", name = definition[2], order = index * 10, arg = { puiExplicit = true }, args = {},
    }
  end

  local function Collect(args, category, prefix, label, hidden, disabled)
    for key, option in pairs(args) do
      local optionKey = prefix == "" and key or prefix .. "_" .. key
      if option.type == "group" then
        local nextCategory = GROUP_SECTIONS[key] or (key:lower():find("glow", 1, true) and "glow") or category
        if key == "specializationSpells" then
          option.name = "Spell assignments"
          option.order = 20
          sections.general.args[optionKey] = option
        else
          Collect(option.args or {}, nextCategory, optionKey, option.name, CombineCondition(hidden, option.hidden), CombineCondition(disabled, option.disabled))
        end
      elseif option.type ~= "header" and option.hidden ~= true and hidden ~= true then
        local destination = FIELD_SECTIONS[key] or category
        local bucketPrefix, bucketLabel = prefix, label
        local role = key:match("^(cooldown)") or key:match("^(charge)") or key:match("^(keybind)")
          or key:match("^Duration") and "cooldown" or key:match("^Stack") and "stacks"
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
        local state
        if prefix:match("whenReady$") or prefix:match("ready$") or key:match("^ready") or key == "desaturateReady" then
          state = "readyState"
        elseif prefix:match("whenCooldown$") or prefix:match("cooldown$") or key:match("^onCooldown")
          or key:match("^cooldownAlpha") or key:match("^cooldownGlow") or key == "desaturateCooldown" then
          state = "cooldownState"
        elseif prefix:match("whenActive$") or prefix:match("active$") or key:match("^active")
          or key:match("^auraGlow") or key == "desaturateActive" or key == "glowDuringDurationSwipe" then
          state = "activeState"
        end
        if context.customTracker and state and destination ~= "text" then destination = "visibility" end
        if context.items and (destination == "glow" or state) then destination = "visibility" end
        if key == "deleteBar" and context.customTracker then destination = "general" end
        if key == "showSwipe" or key == "swipeShow" then destination = "timer" end
        if context.buffBars then
          if key == "hideWhenInactive" or key == "showName" then destination = "general" end
          if key == "drainDirection" then destination = "layout" end
        end
        if destination == "text" then
          if key == "showCountdown" or key == "showDuration" or key:match("^durationText")
            or key == "durationFont" or key == "durationOutline"
            or key == "fontSize" and prefix == "icon_fonts" then
            role = "cooldown"
          elseif key == "countBuff" and hasStackStyle then
            role = "stacks"
          elseif key == "countCharge" or key == "countBuff" or key == "showCount" or key == "countVisibility"
            or key == "countFontSize" or key:match("^countText") then
            role = "charge"
          elseif key == "keybindToggle" or key == "showKeybinds" then
            role = "keybind"
          elseif key == "font" or key == "fontSize" or key == "fontColor" or key == "outline" or key == "fontOutline" then
            bucketPrefix, bucketLabel = "sharedTypography", "Shared typography"
          end
          if role then
            bucketPrefix = role
            bucketLabel = role == "cooldown" and "Countdown" or role == "stacks" and "Stacks"
              or role == "charge" and (hasCharges and hasStacks and "Charges and stacks"
                or hasCharges and "Charges" or hasStacks and "Stacks" or "Counts") or "Keybinds"
          end
        elseif destination == "timer" then
          if key:lower():find("gcd", 1, true) then
            bucketPrefix, bucketLabel = "gcdTimer", "GCD"
          elseif key:lower():find("duration", 1, true) or key:match("^activeAura")
            or key == "forceCooldown" or key == "timerDisplay" or key == "swipeSource"
            or key == "showActive" or key == "source" or key == "cdmBuff" or key == "customBuff"
          then
            bucketPrefix, bucketLabel = "durationTimer", "Duration"
          elseif key:lower():find("cooldown", 1, true) or key:match("^recharge") then
            bucketPrefix, bucketLabel = "cooldownTimer", "Cooldown"
          else
            bucketPrefix, bucketLabel = "swipeSettings", "Swipe settings"
          end
        end
        if destination == "visibility" then
          if state then
            bucketPrefix = state
            bucketLabel = state == "readyState" and "Ready" or state == "activeState" and "Active" or "On cooldown"
            if state == "readyState" and context.auraTracker then bucketLabel = "Inactive" end
          elseif key == "opacity" then
            bucketPrefix, bucketLabel = "barOpacity", "Bar content"
          elseif key == "outOfCombatAlpha" then
            bucketPrefix, bucketLabel = "combat", "Combat"
          elseif key == "missingAlpha" then
            bucketPrefix, bucketLabel = "unavailable", "Unavailable"
          else
            bucketPrefix, bucketLabel = "conditions", "Conditions"
          end
        elseif destination == "general" and option.type ~= "description" then
          bucketPrefix = GENERAL_GROUPS[key] or "behavior"
          if (context.customTracker or context.items) and key == "enabled" then bucketPrefix = "behavior" end
          if context.customTracker and key == "deleteBar" then bucketPrefix, bucketLabel = "actions", "Actions" end
        elseif destination == "layout" then
          bucketPrefix = LAYOUT_GROUPS[key] or "arrangement"
          if context.buffBars and (key == "orientation" or key == "drainDirection") then bucketPrefix = "iconPlacement" end
        elseif destination == "glow" then
          if key:match("^ready") or prefix:match("whenReady$") then
            bucketPrefix = "readyGlow"
          elseif key:match("^cooldown") or prefix:match("whenCooldown$") then
            bucketPrefix = "cooldownGlow"
          elseif key:match("^aura") or key:match("^active") or prefix:match("whenActive$") then
            bucketPrefix = "auraGlow"
          elseif key == "speed" or key == "scale" or key == "lines" or key == "thickness" then
            bucketPrefix = "glowShape"
          else
            bucketPrefix = "glowStyle"
          end
        end
        if destination == "text" then
          local property = key:match("^[Cc]ooldown(.+)$") or key:match("^charge(.+)$")
            or key:match("^keybind(.+)$") or key:match("^[Dd]uration(.+)$") or key:match("^Stack(.+)$")
            or key:match("^count(.+)$")
          local properties = {
            Font = { "Font", 40 }, FontSize = { "Font size", 50 }, Size = { "Font size", 50 },
            Outline = { "Outline", 60 }, Color = { "Text color", 70 },
            Anchor = { "Anchor point", 80 }, OffsetX = { "Horizontal offset", 90 },
            OffsetY = { "Vertical offset", 100 },
            TextScale = { "Scale", 55 }, TextAnchor = { "Anchor point", 80 },
            TextX = { "Horizontal offset", 90 }, TextY = { "Vertical offset", 100 },
            TextColor = { "Text color", 70 },
          }
          local definition = property and properties[property]
          if definition then option.name, option.order = definition[1], definition[2] end
          if key == "countFontSize" or key == "durationCountFontSize" then option.name, option.order = "Font size", 50 end
          if key == "countTextColor" or key == "durationTextColor" then option.name, option.order = "Text color", 70 end
          if key == "font" then option.name, option.order = "Font", 40 end
          if key == "fontSize" then option.name, option.order = "Font size", 50 end
          if key == "fontColor" then option.name, option.order = "Text color", 70 end
          if key == "outline" or key == "fontOutline" then option.name, option.order = "Outline", 60 end
          if key == "keybindToggle" or key == "showKeybinds" or key == "keybindShow" then option.name, option.order = "Show text", 10 end
          if key == "countCharge" then option.name, option.order = hasStacks and "Show charges" or "Show count", 10 end
          if key == "countBuff" then option.name, option.order = hasCharges and not hasStackStyle and "Show stacks" or "Show count", 10 end
          if key == "showCount" or key == "chargeShow" then option.name, option.order = "Show count", 10 end
          if key == "showCountdown" or key == "cooldownShow" then option.name, option.order = "Show countdown", 10 end
        end
        if destination == "visibility" then
          if option.type == "toggle" then option.order = 10 + (tonumber(option.order) or 0) / 100
          elseif option.type == "select" then option.order = 30 + (tonumber(option.order) or 0) / 100
          elseif option.type == "range" then
            option.order = 40 + (tonumber(option.order) or 0) / 100
            if key:lower():find("alpha", 1, true) or key == "opacity" then option.name = "Opacity" end
          end
        end
        if destination == "general" and (key == "showTooltips" or key == "showTooltip") then option.order = 20 end
        if context.customTracker and key == "enabled" and destination == "general" then
          option.name, option.order = "Enable tracker", 0
        elseif context.items and key == "enabled" and destination == "general" then
          option.order = 0
        elseif context.customTracker and key == "deleteBar" then
          option.name, option.order = "Delete tracker", 1000
          option.confirm = option.confirmText or "Delete this tracker?"
          option.confirmText = nil
        end
        option.name = ns.OptionsSchema.GetCompactLabel(option.name)
        local inlineDefinition = INLINE_GROUPS[bucketPrefix]
        if inlineDefinition then bucketLabel = inlineDefinition[1] end
        option.hidden = CombineCondition(hidden, option.hidden)
        option.disabled = CombineCondition(disabled, option.disabled)
        local quickSetting = QUICK_SETTINGS[key]
        if context.customTracker and state == "cooldownState" and key == "desaturate" then quickSetting = { 21, "Desaturation" } end
        if quickSetting and destination ~= "general" and (destination ~= "visibility" or key == "desaturateCooldown" or key == "desaturate") and option.hidden ~= true
          and (key ~= "enabled" or destination == "glow")
          and (key ~= "showDuration" or destination == "text")
        then
          local quickGroup = (key == "desaturateCooldown" or key == "desaturate" or key == "enabled" and destination == "glow")
            and "behavior" or destination == "timer" and "quickTimers"
            or destination == "text" and "quickText"
            or destination == "layout" and "quickLayout" or "quickGlow"
          local definition = INLINE_GROUPS[quickGroup]
          local quickSettings = sections.general.args[quickGroup]
          if not quickSettings then
            quickSettings = { type = "group", name = definition[1], inline = true, order = definition[2], args = {} }
            sections.general.args[quickGroup] = quickSettings
          end
          local shortcut = {}
          for field, value in pairs(option) do
            shortcut[field] = value
          end
          shortcut.name = quickSetting[2] or option.name
          shortcut.order = quickSetting[1]
          quickSettings.args[optionKey] = shortcut
        end
        local timerRow = destination == "timer" and TIMER_ROWS[key]
        if timerRow then
          option.order, option.relWidth, option.name = timerRow[1], timerRow[2], timerRow[3]
          option.width = "relative"
        end
        local sectionArgs = sections[destination].args
        if bucketPrefix ~= "" and bucketLabel ~= sections[destination].name and bucketLabel ~= "General"
          and bucketLabel ~= "Icon settings" and bucketLabel ~= "Group settings"
        then
          local bucket = sectionArgs[bucketPrefix]
          if not bucket then
            local order = inlineDefinition and inlineDefinition[2] or destination == "timer" and (bucketPrefix == "durationTimer" and 10
              or bucketPrefix == "cooldownTimer" and 20 or bucketPrefix == "gcdTimer" and 30 or 40)
              or destination == "text" and (bucketPrefix == "cooldown" and 10
                or (bucketPrefix == "charge" or bucketPrefix == "stacks") and 20 or bucketPrefix == "keybind" and 30 or 40)
              or option.order
            if bucketPrefix == "actions" then order = 1000 end
            if context.customTracker and bucketPrefix == "behavior" then order = 0 end
            if bucketPrefix == "conditions" then order = 10 end
            if bucketPrefix == "combat" then order = 20 end
            if bucketPrefix == "readyState" then order = 30 end
            if bucketPrefix == "activeState" then order = 40 end
            if bucketPrefix == "cooldownState" then order = 50 end
            bucket = { type = "group", name = bucketLabel, inline = true, order = order, args = {} }
            bucket.hidden = function(info)
              for _, control in pairs(bucket.args) do
                local hidden = control.hidden
                if type(hidden) == "function" then hidden = hidden(info) end
                if not hidden then return false end
              end
              return true
            end
            sectionArgs[bucketPrefix] = bucket
          elseif not inlineDefinition and destination ~= "timer" and destination ~= "text"
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
  if (context.customTracker or context.items) and sections.general.args.behavior then
    sections.general.args.behavior.order = 0
  end
  if context.customTracker or context.items then
    if next(sections.glow.args) then
      sections.visibility.args.glow = {
        type = "group", name = "Glow", inline = true, order = 80, args = sections.glow.args,
      }
    end
    sections.glow.args = {}
    sections.visibility.name = "Visibility and glow"
  end
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
  local sectionIndex
  if path[2] == "groups" then
    sectionIndex = path[4] == "entries" and 6 or 4
  elseif path[2] == "customTrackers" then
    sectionIndex = path[3] == "__disabledNotLoaded" and 5 or 4
  elseif path[2] == "consumables" then
    sectionIndex = 3
  end
  if sectionIndex and path[sectionIndex] == "appearance" then
    path[sectionIndex] = "layout"
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
    general = "general quick settings enabled visibility opacity tooltip spell specialization assignment timer swipe countdown charges stacks keybind font size glow desaturate saturation behavior",
    layout = "layout appearance size width height spacing rows columns orientation growth icon position color saturation desaturate texture border",
    timer = "timer display duration active aura buff cooldown gcd swipe countdown recharge fill drain",
    visibility = "visibility combat mouseover opacity fade active inactive ready cooldown",
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
