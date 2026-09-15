
local ADDON_NAME, ns = ...

ns.UFPreview = ns.UFPreview or {}
local Preview = ns.UFPreview

local P = select(1, ns.Pleebug:DropIn(Preview))

local _G = _G
local AuraUtil = _G.AuraUtil
local CreateFrame = _G.CreateFrame
local C_Spell = _G.C_Spell
local C_Timer = _G.C_Timer
local GameTooltip = _G.GameTooltip
local GetCursorPosition = _G.GetCursorPosition
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UnitClass = _G.UnitClass
local UIParent = _G.UIParent
local ipairs = _G.ipairs
local math_ceil = _G.math.ceil
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local pairs = _G.pairs
local sort = _G.table.sort
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local Theme = ns.Theme
local Presentation = ns.Presentation
local AuraButtons = ns.UFAuraButtons
local AuraLayout = ns.UFAuraLayout

local AURA_MANAGER_UNITS = {
  player = true,
  target = true,
  focus = true,
  boss = true,
  party = true,
  raid = true,
}

local DISPEL_PREVIEW_INTERVAL = 2
local DISPEL_PREVIEW_TYPES = {
  "Magic",
  "Curse",
  "Disease",
  "Bleed",
  "Poison",
}

local NESTED_UNIT_FRAME_PREVIEW_UNITS = {
  pet = true,
  targettarget = true,
  focustarget = true,
}

local PREVIEW_DISPEL_COLORS = {
  MAGIC = { 0.20, 0.60, 1.00, 1 },
  CURSE = { 0.60, 0.00, 1.00, 1 },
  DISEASE = { 0.60, 0.40, 0.00, 1 },
  POISON = { 0.00, 0.60, 0.00, 1 },
}

local PREVIEW_BUFF_SPELL_IDS = {
  21562,
  139,
  774,
  1459,
  1126,
  6673,
}

local PREVIEW_DEFENSIVE_SPELL_IDS = {
  6940,
  102342,
  116849,
  33206,
  47788,
  1022,
}

local PREVIEW_DEBUFF_SAMPLES = {
  { spellID = 118, dispelColor = PREVIEW_DISPEL_COLORS.MAGIC },
  { spellID = 51514, dispelColor = PREVIEW_DISPEL_COLORS.CURSE },
  { spellID = 55078, dispelColor = PREVIEW_DISPEL_COLORS.DISEASE },
  { spellID = 2818, dispelColor = PREVIEW_DISPEL_COLORS.POISON },
  { spellID = 589 },
}


local UNIT_FRAME_PREVIEW_CLASS_TOKENS = {
  "WARRIOR",
  "PALADIN",
  "HUNTER",
  "ROGUE",
  "PRIEST",
  "DEATHKNIGHT",
  "SHAMAN",
  "MAGE",
  "WARLOCK",
  "MONK",
  "DRUID",
  "DEMONHUNTER",
  "EVOKER",
}
local INLINE_PARTY_PREVIEW_DEFAULT_MEMBERS = 3
local INLINE_RAID_PREVIEW_DEFAULT_GROUPS = 2
local INLINE_RAID_PREVIEW_DEFAULT_MEMBERS_PER_GROUP = 3
local INLINE_DENSITY_CONTROL_WIDTH = 188
local INLINE_DENSITY_CONTROL_HEIGHT = 16
local INLINE_DENSITY_CONTROL_GAP = 6
local UNIT_FRAME_OVERVIEW_CARD_GAP = 8
local UNIT_FRAME_OVERVIEW_CARD_INSET = 8
local UNIT_FRAME_OVERVIEW_TITLE_HEIGHT = 24
local UNIT_FRAME_OVERVIEW_FRAME_GAP = 5
local UNIT_FRAME_OVERVIEW_FAMILIES = {
  {
    key = "player",
    label = "Player",
    columns = 1,
    rows = 1,
    names = { "Player" },
  },
  {
    key = "target",
    label = "Target",
    columns = 1,
    rows = 1,
    names = { "Target" },
  },
  {
    key = "focus",
    label = "Focus",
    columns = 1,
    rows = 1,
    names = { "Focus" },
  },
  {
    key = "party",
    label = "Party",
    columns = 1,
    rows = 2,
    names = { "Party 1", "Party 2" },
  },
  {
    key = "raid",
    label = "Raid",
    columns = 2,
    rows = 2,
    names = { "Raid 1", "Raid 2", "Raid 3", "Raid 4" },
  },
  {
    key = "boss",
    label = "Boss",
    columns = 1,
    rows = 2,
    names = { "Boss 1", "Boss 2" },
  },
}
local AURA_PREVIEW_SNAP_RADIUS_PX = 4

local AURA_PREVIEW_ANCHOR_POINTS = {
  "TOPLEFT",
  "TOP",
  "TOPRIGHT",
  "LEFT",
  "CENTER",
  "RIGHT",
  "BOTTOMLEFT",
  "BOTTOM",
  "BOTTOMRIGHT",
}

local StartAuraPreviewDrag
local StopAuraPreviewDrag
local BuildAuraManagerDisplayPath
local FocusAuraManagerOption
local NavigateAuraPreviewElement
local UpdateAuraPreviewSelectionUI
local UpdateAuraPreviewHint
local SyncAuraPreviewControls
local RenderAuraManagerPreview
local BuildAuraPreviewDisplay
local CenterGroupedAuraPreviewPositions
local BuildPartyAuraPreviewPositions
local BuildRaidAuraPreviewPositions

local function CopyPreviewPath(path)
  local output = {}

  for index = 1, #(path or {}) do
    output[index] = path[index]
  end

  return output
end

local function CopyPreviewColor(value, fallback)
  value = type(value) == "table" and value or fallback
  fallback = fallback or { 1, 1, 1, 1 }

  return {
    tonumber(value and (value.r or value[1])) or fallback[1] or 1,
    tonumber(value and (value.g or value[2])) or fallback[2] or 1,
    tonumber(value and (value.b or value[3])) or fallback[3] or 1,
    tonumber(value and (value.a or value[4])) or fallback[4] or 1,
  }
end

local function ResolveAuraPreviewHealthColor(context, frameColors, themeColors)
  local useClassColor

  if context.grouped then
    useClassColor = context.frameDB.useClassColor ~= false
  elseif context.unitKey == "player" then
    useClassColor = context.frameDB.useClassColor ~= false
  else
    useClassColor = true
  end

  if useClassColor then
    local classToken = context.previewClassToken

    if not classToken then
      local _, playerClassToken = UnitClass("player")
      classToken = playerClassToken
    end

    local classColor = classToken and RAID_CLASS_COLORS[classToken]

    if classColor then
      return CopyPreviewColor(classColor, { 1, 1, 1, 1 })
    end
  end

  return CopyPreviewColor(frameColors.healthBar, themeColors.healthBar)
end

local function ResolveAuraPreviewNameColor(context, frameColors, themeColors)
  local colors = frameColors

  if not context.grouped then
    local profile = ns.UnitFrames and ns.UnitFrames.db and ns.UnitFrames.db.profile
    colors = profile and profile.colors or colors
  end

  if colors and colors.useClassForNames == true then
    local classToken = context.previewClassToken

    if not classToken then
      local _, playerClassToken = UnitClass("player")
      classToken = playerClassToken
    end

    local classColor = classToken and RAID_CLASS_COLORS[classToken]

    if classColor then
      return CopyPreviewColor(classColor, { 1, 1, 1, 1 })
    end
  end

  return CopyPreviewColor(colors and colors.nameText, themeColors.nameText)
end

local function CreatePreviewBorder(frame)
  if frame.__puiPreviewBorder then
    return
  end

  local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

  local bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

  local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  frame.__puiPreviewBorder = {
    top,
    bottom,
    left,
    right,
  }
end

local function SetPreviewBorder(frame, color, thickness)
  local border = frame.__puiPreviewBorder
  thickness = math_max(0, ns.Pixel.Round((tonumber(thickness) or 0) * ns.Pixel.GetOnePixel()))

  border[1]:SetHeight(thickness)
  border[2]:SetHeight(thickness)
  border[3]:SetWidth(thickness)
  border[4]:SetWidth(thickness)

  for index = 1, 4 do
    border[index]:SetColorTexture(color[1], color[2], color[3], color[4])
    border[index]:SetShown(thickness > 0)
  end
end

local function EnsureDispelPreviewVisuals(frame)
  local visuals = frame.__puiDispelPreviewVisuals
  if visuals then
    return visuals
  end

  local fill = frame.Health:CreateTexture(nil, "OVERLAY", nil, 5)
  fill:SetBlendMode("BLEND")
  fill:Hide()

  local borderHost = CreateFrame("Frame", nil, frame)
  borderHost:EnableMouse(false)
  borderHost:SetFrameLevel(frame:GetFrameLevel() + 5)

  local border = {
    top = borderHost:CreateTexture(nil, "OVERLAY", nil, 5),
    bottom = borderHost:CreateTexture(nil, "OVERLAY", nil, 5),
    left = borderHost:CreateTexture(nil, "OVERLAY", nil, 5),
    right = borderHost:CreateTexture(nil, "OVERLAY", nil, 5),
  }

  local icon = frame:CreateTexture(nil, "OVERLAY", nil, 6)
  icon:Hide()

  visuals = {
    fill = fill,
    borderHost = borderHost,
    border = border,
    icon = icon,
  }
  frame.__puiDispelPreviewVisuals = visuals
  return visuals
end

local function HideDispelPreviewVisuals(frame)
  local visuals = frame and frame.__puiDispelPreviewVisuals
  if not visuals then
    return
  end

  visuals.fill:Hide()
  visuals.borderHost:Hide()
  visuals.icon:Hide()
end

local function ConfigureDispelPreviewBorder(visuals, health, bottom, thickness, color)
  local border = visuals.border
  local edge = math_max(0, ns.Pixel.Round(tonumber(thickness) or 3))

  border.top:ClearAllPoints()
  border.top:SetPoint("BOTTOMLEFT", health, "TOPLEFT", -edge, 0)
  border.top:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", edge, 0)
  border.top:SetHeight(edge)

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", -edge, 0)
  border.bottom:SetPoint("TOPRIGHT", bottom, "BOTTOMRIGHT", edge, 0)
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPRIGHT", health, "TOPLEFT", 0, edge)
  border.left:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMLEFT", 0, -edge)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, edge)
  border.right:SetPoint("BOTTOMLEFT", bottom, "BOTTOMRIGHT", 0, -edge)
  border.right:SetWidth(edge)

  for _, texture in pairs(border) do
    texture:SetColorTexture(color:GetRGBA())
  end

  visuals.borderHost:SetShown(edge > 0)
end

local function ApplyDispelPreviewVisuals(frame, context, dispelType)
  local profile = context.styleDB
  local highlight = profile and profile.debuffHighlight or nil
  local mode = profile and profile.debuffHighlighting or "NONE"
  local visuals = EnsureDispelPreviewVisuals(frame)

  HideDispelPreviewVisuals(frame)

  if not highlight then
    return
  end

  local color = AuraUtil.GetAuraBorderColor(dispelType)
  local health = frame.Health
  local healthTexture = health:GetStatusBarTexture()
  local power = frame.Power
  local bottom = power and power:IsShown() and power or health

  visuals.borderHost:SetFrameStrata(frame:GetFrameStrata())
  visuals.borderHost:SetFrameLevel(frame:GetFrameLevel() + 5)

  if profile.hideHealth ~= true and (mode == "FILL" or mode == "BOTH") then
    visuals.fill:ClearAllPoints()
    visuals.fill:SetAllPoints(healthTexture)
    visuals.fill:SetTexture(healthTexture:GetTexture())
    visuals.fill:SetVertexColor(color:GetRGBA())
    visuals.fill:Show()
  end

  if mode == "GLOW" or mode == "BOTH" then
    ConfigureDispelPreviewBorder(visuals, health, bottom, highlight.borderSize, color)
  end

  if highlight.blizzardIndicator == true then
    local size = math_max(8, ns.Pixel.Round(tonumber(highlight.blizzardIndicatorSize) or 18))
    local position = highlight.blizzardIndicatorPosition or "TOPRIGHT"
    local xOffset = ns.Pixel.Round(tonumber(highlight.blizzardIndicatorXOffset) or 0)
    local yOffset = ns.Pixel.Round(tonumber(highlight.blizzardIndicatorYOffset) or 0)

    visuals.icon:ClearAllPoints()
    visuals.icon:SetPoint(position, frame, position, xOffset, yOffset)
    visuals.icon:SetSize(size, size)
    visuals.icon:SetAtlas(
      ns.UFAuraHighlight.GetPreviewDispelIconAtlas(dispelType),
      false
    )
    visuals.icon:Show()
  end
end

local function EnsureAuraPreviewSelection(frame)
  local selection = frame.__puiAuraPreviewSelection
  if selection then
    return selection
  end

  selection = CreateFrame("Frame", nil, frame)
  selection:SetAllPoints(frame)
  selection:SetFrameLevel(frame:GetFrameLevel() + 20)
  selection:EnableMouse(false)
  CreatePreviewBorder(selection)
  selection:Hide()

  frame.__puiAuraPreviewSelection = selection
  return selection
end

local function SetAuraPreviewSelected(frame, selected)
  local selection = EnsureAuraPreviewSelection(frame)

  if selected then
    local color = Theme.GetColors().accent
    SetPreviewBorder(selection, color, 2)
    selection:Show()
  else
    selection:Hide()
  end
end

local function ResetAuraPreviewIcon(icon)
  icon:Hide()
  icon:ClearAllPoints()
  icon:SetScript("OnClick", nil)
  icon:EnableMouse(false)
  icon:SetAlpha(1)
  icon.__puiAuraDisplayID = nil
  icon.__puiAuraPreviewDurationValue = nil
  icon.__puiAuraPreviewExpiration = nil
  icon.__puiAuraPreviewShowDurationText = nil
  icon.Icon:SetTexture(nil)
  icon.Cooldown:SetCooldown(0, 0)
  icon.Cooldown:Hide()
  icon.Duration:SetText("")
  icon.Count:SetText("")
  icon.__puiAuraPreviewOverflow:SetText("")
  icon.__puiAuraPreviewOverflow:Hide()

  local navigation = icon.__puiAuraPreviewElementNavigation
  if navigation then
    navigation.previewDisplay = nil

    for _, button in ipairs(navigation.buttons) do
      button:Hide()
    end
  end

  SetPreviewBorder(icon, { 1, 1, 1, 1 }, 0)
  SetAuraPreviewSelected(icon, false)
end

local function BeginAuraPreviewIconPool(box)
  box.__puiAuraPreviewIconPoolIndex = 0

  if box.__puiAuraPreviewDurationDriver then
    box.__puiAuraPreviewDurationDriver:Hide()
  end

  for _, icon in ipairs(box.__puiAuraPreviewIconPool or {}) do
    ResetAuraPreviewIcon(icon)
  end
end

local function AcquireAuraPreviewIcon(box, parent)
  local pool = box.__puiAuraPreviewIconPool
  if not pool then
    pool = {}
    box.__puiAuraPreviewIconPool = pool
  end

  local index = (box.__puiAuraPreviewIconPoolIndex or 0) + 1
  box.__puiAuraPreviewIconPoolIndex = index

  local icon = pool[index]
  if not icon then
    icon = CreateFrame("Button", nil, parent)
    icon:EnableMouse(false)

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(icon)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetReverse(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.65)

    local textParent = CreateFrame("Frame", nil, icon)
    textParent:SetAllPoints(icon)
    textParent:SetFrameLevel(cooldown:GetFrameLevel() + 1)

    local duration = textParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local applications = textParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local overflow = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    icon.Icon = texture
    icon.Cooldown = cooldown
    icon.Duration = duration
    icon.Count = applications
    icon.__puiAuraPreviewOverflow = overflow

    CreatePreviewBorder(icon)
    pool[index] = icon
  end

  icon:SetParent(parent)
  icon:SetFrameLevel(parent:GetFrameLevel() + 20)
  icon:Show()
  return icon
end

local function UpdateAuraPreviewDurations(box, elapsed)
  local driver = box.__puiAuraPreviewDurationDriver
  driver.elapsed = driver.elapsed + elapsed

  if driver.elapsed < 0.2 then
    return
  end

  driver.elapsed = 0

  if not box:IsVisible() then
    driver:Hide()
    return
  end

  local now = GetTime()

  for index = 1, box.__puiAuraPreviewIconPoolIndex do
    local icon = box.__puiAuraPreviewIconPool[index]
    local duration = icon.__puiAuraPreviewDurationValue

    if duration then
      local remaining = icon.__puiAuraPreviewExpiration - now

      if remaining <= 0 then
        remaining = duration
        icon.__puiAuraPreviewExpiration = now + duration
        icon.Cooldown:SetCooldown(now, duration)
      end

      if icon.__puiAuraPreviewShowDurationText ~= false then
        icon.Duration:SetText(AuraButtons.DurationFormatter:FormatNumber(remaining))
      end
    end
  end
end

local function EnableAuraPreviewDurationUpdates(box)
  local driver = box.__puiAuraPreviewDurationDriver

  if not driver then
    driver = CreateFrame("Frame", nil, box)
    driver.elapsed = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
      UpdateAuraPreviewDurations(box, elapsed)
    end)
    box.__puiAuraPreviewDurationDriver = driver
  end

  driver.elapsed = 0
  driver:Show()
end

local function IsUnitFrameOverviewPath(path)
  return type(path) == "table"
    and path[1] == "unitframes"
    and path[2] == "general"
end

local function GetAuraManagerUnitKey(path)
  local nestedUnitKey = type(path) == "table" and path[3] or nil
  if NESTED_UNIT_FRAME_PREVIEW_UNITS[nestedUnitKey] then
    return nestedUnitKey
  end

  local unitKey = type(path) == "table" and path[2] or nil
  return AURA_MANAGER_UNITS[unitKey] and unitKey or "player"
end

function Preview.IsUnitFramesOptionsPath(path)
  return type(path) == "table" and path[1] == "unitframes"
end

local function IsDispelPreviewOptionsPath(path)
  return type(path) == "table"
    and path[1] == "unitframes"
    and (path[2] == "party" or path[2] == "raid")
    and path[3] == "dispels"
end

function Preview.IsAuraManagerOptionsPath(path)
  return type(path) == "table"
    and path[1] == "unitframes"
    and AURA_MANAGER_UNITS[path[2]] == true
    and path[3] == "auras"
    and path[4] == "customDisplays"
end

local function GetAuraManagerPathSelection(path)
  local leafKey = type(path) == "table" and path[#path] or nil
  local selectedID = type(leafKey) == "string" and tonumber(leafKey:match("^display_(%d+)$")) or nil
  local categoryKey = type(path) == "table" and path[5] or nil
  local auraType
  local builtInIDs = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS

  if categoryKey == "buffs" then
    auraType = "HELPFUL"
    selectedID = builtInIDs.DEFAULT_BUFF
  elseif categoryKey == "defensives" then
    auraType = "HELPFUL"
    selectedID = builtInIDs.DEFENSIVES_EXTERNALS
  elseif categoryKey == "important" then
    auraType = "HELPFUL"
    selectedID = builtInIDs.IMPORTANT_BUFFS
  elseif categoryKey == "debuffs" then
    auraType = "HARMFUL"
    selectedID = builtInIDs.DEFAULT_DEBUFF
  end

  return selectedID, auraType
end

local function GetAuraManagerPreviewContext(path)
  local unitKey = GetAuraManagerUnitKey(path)
  local grouped = unitKey == "party" or unitKey == "raid"
  local dispelPreview = IsDispelPreviewOptionsPath(path)
  local partyPetPreview = grouped
    and unitKey == "party"
    and type(path) == "table"
    and path[3] == "partypets"
  local frameDB
  local styleDB
  local forceNoPower
  local auraDB
  local selectionDB

  if grouped then
    local module = ns.Modules[unitKey == "raid" and "RaidFrames" or "PartyFrames"]
    local profile = module.db.profile

    profile.auras = profile.auras or {}
    selectionDB = profile.auras
    frameDB, styleDB, forceNoPower = module:GetTestFrameConfig(partyPetPreview)

    if partyPetPreview then
      auraDB = ns.UFAuraFilters.BuildGroupedAuraDB("party", profile, "partypet1")
    else
      auraDB = ns.UFAuraFilters.BuildGroupedAuraDB(
        unitKey,
        profile,
        unitKey == "raid" and "raid1" or "party1"
      )
    end
  else
    frameDB, styleDB, forceNoPower = ns.UnitFrames:GetTestFrameConfig(unitKey)
    frameDB.auras = frameDB.auras or {}
    auraDB = frameDB.auras
    selectionDB = auraDB
  end

  local displays = dispelPreview and {} or ns.UFAuraFilters.NormalizeDisplays(auraDB)
  local selectedID

  if not dispelPreview then
    local selectedAuraType
    selectedID, selectedAuraType = GetAuraManagerPathSelection(path)

    if not (selectedID and displays[selectedID]) then
      selectedID = nil

      if not selectedAuraType then
        selectedID = tonumber(selectionDB.selectedCustomDisplayID)
      end
    end
  end

  return {
    unitKey = unitKey,
    grouped = grouped,
    dispelPreview = dispelPreview,
    frameDB = frameDB,
    styleDB = styleDB,
    forceNoPower = forceNoPower == true,
    auraDB = auraDB,
    selectionDB = selectionDB,
    displays = displays,
    selectedID = selectedID,
    previewZoom = math_min(2, math_max(0.25, tonumber(selectionDB.auraPreviewZoom) or 1)),
    previewHintSeen = selectionDB.auraPreviewHintSeen == true,
    previewName = partyPetPreview and "Party pet" or nil,
    optionsPath = CopyPreviewPath(path),
    partyPetPreview = partyPetPreview == true,
    nestedPreview = NESTED_UNIT_FRAME_PREVIEW_UNITS[
      type(path) == "table" and path[3] or nil
    ] == true,
    managerPath = {
      "unitframes",
      unitKey,
      "auras",
      "customDisplays",
    },
  }
end

local function GetOrderedAuraDisplays(displays)
  local output = {}

  for _, display in pairs(displays) do
    output[#output + 1] = display
  end

  sort(output, function(left, right)
    local leftOrder = tonumber(left.order) or 0
    local rightOrder = tonumber(right.order) or 0

    if leftOrder == rightOrder then
      return left.id < right.id
    end

    return leftOrder < rightOrder
  end)

  return output
end

local function GetPreviewAuraSample(display, index)
  local spellIDs = {}

  for spellID in pairs(display.includeSpellIDs or {}) do
    spellID = tonumber(spellID)
    if spellID then
      spellIDs[#spellIDs + 1] = spellID
    end
  end

  if #spellIDs > 0 then
    sort(spellIDs)

    return {
      spellID = spellIDs[((index - 1) % #spellIDs) + 1],
      dispelColor = display.auraType == "HARMFUL"
        and PREVIEW_DEBUFF_SAMPLES[((index - 1) % #PREVIEW_DEBUFF_SAMPLES) + 1].dispelColor
        or nil,
    }
  end

  if display.specialType == "DEFENSIVES_EXTERNALS" then
    return {
      spellID = PREVIEW_DEFENSIVE_SPELL_IDS[((index - 1) % #PREVIEW_DEFENSIVE_SPELL_IDS) + 1],
    }
  end

  if display.auraType == "HARMFUL" then
    return PREVIEW_DEBUFF_SAMPLES[((index - 1) % #PREVIEW_DEBUFF_SAMPLES) + 1]
  end

  return {
    spellID = PREVIEW_BUFF_SPELL_IDS[((index - 1) % #PREVIEW_BUFF_SPELL_IDS) + 1],
  }
end

local function BeginAuraPreviewFramePool(box)
  box.__puiAuraPreviewFramePoolIndex = 0

  for _, frame in ipairs(box.__puiAuraPreviewFramePool or {}) do
    HideDispelPreviewVisuals(frame)
    frame:Hide()
  end
end

local function BuildUnitFramePreviewOptionsPath(context, leafKey)
  local path

  if context.partyPetPreview then
    path = {
      "unitframes",
      "party",
      "partypets",
    }
  elseif context.nestedPreview then
    path = {
      "unitframes",
      context.optionsPath[2],
      context.optionsPath[3],
    }
  else
    path = {
      "unitframes",
      context.unitKey,
    }

    if leafKey then
      path[#path + 1] = leafKey
    end
  end

  return path
end

local function NavigateUnitFramePreviewElement(
  context,
  leafKey,
  sectionKey,
  optionKey
)
  ns.PreviewBox.NavigateToOption(
    context.addon or ns.Addon,
    BuildUnitFramePreviewOptionsPath(context, leafKey),
    sectionKey,
    optionKey
  )
end

local function CreateUnitFramePreviewTextInteraction(
  frame,
  fontString,
  frameLevel
)
  local interaction = ns.PreviewBox.CreateInteraction(frame, frame, {
    frameLevel = frameLevel,
  })

  interaction:ClearAllPoints()
  interaction:SetPoint("TOPLEFT", fontString, "TOPLEFT", -3, 3)
  interaction:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 3, -3)
  interaction:Hide()

  return interaction
end

local function CreateUnitFramePreviewInteractions(frame)
  local health = frame.__puiAuraPreviewHealth
  local power = frame.__puiAuraPreviewPower
  local name = frame.__puiAuraPreviewName
  local healthText = frame.__puiAuraPreviewHealthText
  local powerText = frame.__puiAuraPreviewPowerText
  local roleIndicator = frame.__puiAuraPreviewRoleIndicator
  local statusIndicator = frame.__puiAuraPreviewStatusIndicator
  local baseLevel = frame:GetFrameLevel()

  local interactions = {
    health = ns.PreviewBox.CreateInteraction(frame, health, {
      frameLevel = baseLevel + 40,
    }),
    power = ns.PreviewBox.CreateInteraction(frame, power, {
      frameLevel = baseLevel + 41,
    }),
    name = CreateUnitFramePreviewTextInteraction(
      frame,
      name,
      baseLevel + 50
    ),
    healthText = CreateUnitFramePreviewTextInteraction(
      frame,
      healthText,
      baseLevel + 51
    ),
    powerText = CreateUnitFramePreviewTextInteraction(
      frame,
      powerText,
      baseLevel + 52
    ),
    roleIndicator = ns.PreviewBox.CreateInteraction(
      frame,
      roleIndicator,
      {
        frameLevel = baseLevel + 60,
      }
    ),
    statusIndicator = ns.PreviewBox.CreateInteraction(
      frame,
      statusIndicator,
      {
        frameLevel = baseLevel + 61,
      }
    ),
  }

  interactions.roleIndicator:Hide()
  interactions.statusIndicator:Hide()

  return interactions
end

local function ClearUnitFramePreviewInteractionAnchors(frame)
  local interactions = frame.__puiAuraPreviewInteractions
  if not interactions then
    return
  end

  for _, interaction in pairs(interactions) do
    interaction:Hide()
    interaction:ClearAllPoints()
  end
end

local function LayoutUnitFramePreviewInteractions(frame)
  local interactions = frame.__puiAuraPreviewInteractions
  if not interactions then
    interactions = CreateUnitFramePreviewInteractions(frame)
    frame.__puiAuraPreviewInteractions = interactions
  end

  interactions.health:ClearAllPoints()
  interactions.health:SetAllPoints(frame.__puiAuraPreviewHealth)

  interactions.power:ClearAllPoints()
  interactions.power:SetAllPoints(frame.__puiAuraPreviewPower)

  interactions.name:ClearAllPoints()
  interactions.name:SetPoint("TOPLEFT", frame.__puiAuraPreviewName, "TOPLEFT", -3, 3)
  interactions.name:SetPoint("BOTTOMRIGHT", frame.__puiAuraPreviewName, "BOTTOMRIGHT", 3, -3)

  interactions.healthText:ClearAllPoints()
  interactions.healthText:SetPoint("TOPLEFT", frame.__puiAuraPreviewHealthText, "TOPLEFT", -3, 3)
  interactions.healthText:SetPoint("BOTTOMRIGHT", frame.__puiAuraPreviewHealthText, "BOTTOMRIGHT", 3, -3)

  interactions.powerText:ClearAllPoints()
  interactions.powerText:SetPoint("TOPLEFT", frame.__puiAuraPreviewPowerText, "TOPLEFT", -3, 3)
  interactions.powerText:SetPoint("BOTTOMRIGHT", frame.__puiAuraPreviewPowerText, "BOTTOMRIGHT", 3, -3)

  interactions.roleIndicator:ClearAllPoints()
  interactions.roleIndicator:SetAllPoints(frame.__puiAuraPreviewRoleIndicator)

  interactions.statusIndicator:ClearAllPoints()
  interactions.statusIndicator:SetAllPoints(frame.__puiAuraPreviewStatusIndicator)

  local baseLevel = frame:GetFrameLevel()
  interactions.health:SetFrameLevel(baseLevel + 40)
  interactions.power:SetFrameLevel(baseLevel + 41)
  interactions.name:SetFrameLevel(baseLevel + 50)
  interactions.healthText:SetFrameLevel(baseLevel + 51)
  interactions.powerText:SetFrameLevel(baseLevel + 52)
  interactions.roleIndicator:SetFrameLevel(baseLevel + 60)
  interactions.statusIndicator:SetFrameLevel(baseLevel + 61)
end

local function SetUnitFramePreviewInteraction(
  interaction,
  shown,
  title,
  description,
  onClick
)
  interaction:SetPreviewInteractionOptions({
    title = title,
    description = description,
    onClick = onClick,
  })
  interaction:SetShown(shown == true)
end

local function ConfigureUnitFramePreviewInteractions(context)
  local frame = context.frame
  local interactions = frame.__puiAuraPreviewInteractions
  local grouped = context.grouped == true
  local textNavigation = not context.nestedPreview
    and not context.partyPetPreview

  local healthLeaf = grouped and "health" or "general"
  local powerLeaf = grouped and "power" or "general"
  local healthTextureSection = grouped and "textures" or "general"
  local powerTextureSection = grouped and "textures" or "general"
  local healthTextureOption = "healthTexture"
  local powerTextureOption = "powerTexture"

  if context.nestedPreview then
    healthLeaf = nil
    powerLeaf = nil
    healthTextureSection = context.optionsPath[3]
    powerTextureSection = context.optionsPath[3]
  elseif context.partyPetPreview then
    healthLeaf = nil
    powerLeaf = nil
    healthTextureSection = "size"
    powerTextureSection = "size"
    healthTextureOption = "height"
    powerTextureOption = "height"
  end

  SetUnitFramePreviewInteraction(
    interactions.health,
    context.health:IsShown(),
    "Health bar",
    "Click to configure this unit frame's Health settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        healthLeaf,
        healthTextureSection,
        healthTextureOption
      )
    end
  )

  SetUnitFramePreviewInteraction(
    interactions.power,
    context.power:IsShown(),
    "Power bar",
    "Click to configure this unit frame's Power settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        powerLeaf,
        powerTextureSection,
        powerTextureOption
      )
    end
  )

  SetUnitFramePreviewInteraction(
    interactions.name,
    textNavigation and frame.__puiAuraPreviewName:IsShown(),
    "Name text",
    "Click to configure Name settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        "name",
        grouped and "appearance" or "name",
        "fontSize"
      )
    end
  )

  SetUnitFramePreviewInteraction(
    interactions.healthText,
    textNavigation and frame.__puiAuraPreviewHealthText:IsShown(),
    "Health text",
    "Click to configure Health Text settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        "health",
        grouped and "display" or "health",
        "mode"
      )
    end
  )

  SetUnitFramePreviewInteraction(
    interactions.powerText,
    textNavigation and frame.__puiAuraPreviewPowerText:IsShown(),
    "Power text",
    "Click to configure Power Text settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        "power",
        grouped and "display" or "power",
        "mode"
      )
    end
  )

  local indicatorLeaf = context.unitKey == "raid"
    and "indicators"
    or "general"

  SetUnitFramePreviewInteraction(
    interactions.roleIndicator,
    frame.__puiAuraPreviewRoleIndicator:IsShown(),
    "Group role indicator",
    "Click to configure the matching role-indicator settings.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        indicatorLeaf,
        "roleIcon",
        "roleIconSize"
      )
    end
  )

  SetUnitFramePreviewInteraction(
    interactions.statusIndicator,
    frame.__puiAuraPreviewStatusIndicator:IsShown(),
    "Status indicators",
    "Click to configure ready check, summon, combat, resurrection, and phase indicators.",
    function()
      NavigateUnitFramePreviewElement(
        context,
        indicatorLeaf,
        "remainingIndicators",
        "statusIconSize"
      )
    end
  )
end

local function AcquireAuraPreviewFrame(box, canvas)
  local pool = box.__puiAuraPreviewFramePool
  if not pool then
    pool = {}
    box.__puiAuraPreviewFramePool = pool
  end

  local index = (box.__puiAuraPreviewFramePoolIndex or 0) + 1
  box.__puiAuraPreviewFramePoolIndex = index

  local frame = pool[index]
  if not frame then
    frame = Presentation.Create("UnitFrame", canvas, {
      unit = "player",
    })

    local roleIndicator = CreateFrame("Frame", nil, frame)
    local roleBackground = roleIndicator:CreateTexture(nil, "ARTWORK")
    roleBackground:SetAllPoints(roleIndicator)
    roleBackground:SetColorTexture(0.18, 0.56, 1, 0.95)
    local roleText = roleIndicator:CreateFontString(nil, "OVERLAY")
    roleText:SetPoint("CENTER")
    Theme.ApplyFont(roleText, "tiny", 9, "OUTLINE")
    roleText:SetText("R")
    roleIndicator:Hide()

    local statusIndicator = CreateFrame("Frame", nil, frame)
    local statusBackground = statusIndicator:CreateTexture(nil, "ARTWORK")
    statusBackground:SetAllPoints(statusIndicator)
    statusBackground:SetColorTexture(0.20, 0.85, 0.35, 0.95)
    local statusText = statusIndicator:CreateFontString(nil, "OVERLAY")
    statusText:SetPoint("CENTER")
    Theme.ApplyFont(statusText, "tiny", 9, "OUTLINE")
    statusText:SetText("!")
    statusIndicator:Hide()

    frame.__puiAuraPreviewRoleIndicator = roleIndicator
    frame.__puiAuraPreviewRoleText = roleText
    frame.__puiAuraPreviewStatusIndicator = statusIndicator
    frame.__puiAuraPreviewStatusText = statusText
    pool[index] = frame
  end

  frame:SetParent(canvas)
  frame:SetFrameLevel(canvas:GetFrameLevel() + 10)
  frame.__puiAuraPreviewRoleIndicator:SetFrameLevel(frame:GetFrameLevel() + 20)
  frame.__puiAuraPreviewStatusIndicator:SetFrameLevel(frame:GetFrameLevel() + 21)
  frame:Show()
  return frame
end

local function BuildAuraPreviewFrame(box, canvas, context)
  local frameDB = context.frameDB
  local resolvedWidth, resolvedHeight = ns.UFStyle.ResolveFrameSize(frameDB)
  local rawWidth = math_max(40, resolvedWidth)
  local rawHeight = math_max(12, resolvedHeight)
  local scale = tonumber(context.previewZoom) or 1
  local forceNoPower = context.forceNoPower == true
  local themeColors = ns.UFStyle.GetUFThemeColors()
  local frameColors = type(frameDB.colors) == "table" and frameDB.colors or themeColors
  local healthColor = ResolveAuraPreviewHealthColor(context, frameColors, themeColors)
  local nameColor = ResolveAuraPreviewNameColor(context, frameColors, themeColors)
  local missingColor = CopyPreviewColor(frameColors.healthMissing, themeColors.healthMissing)
  local borderColor = CopyPreviewColor(frameColors.borderColor or frameColors.border, themeColors.border)
  local powerColor = CopyPreviewColor(Theme.GetColors().accent, { 0.20, 0.65, 1.00, 1 })
  local layout = ns.UFStyle.CalculateFrameLayout(frameDB, context.styleDB, {
    forceNoPower = forceNoPower,
  })
  local presentationColors = {
    bg = frameColors.bg or themeColors.bg,
    border = borderColor,
    healthBar = frameColors.healthBar or themeColors.healthBar,
    healthMissing = missingColor,
    powerMissing = frameColors.powerMissing or themeColors.powerMissing,
    nameText = nameColor,
    healthText = frameColors.healthText or themeColors.healthText,
    powerText = frameColors.powerText or themeColors.powerText,
  }
  local useClassColor

  if context.grouped or context.unitKey == "player" then
    useClassColor = frameDB.useClassColor ~= false
  end

  local frame = AcquireAuraPreviewFrame(box, canvas)
  ClearUnitFramePreviewInteractionAnchors(frame)
  frame:SetScale(scale)
  frame:SetParent(canvas)
  frame:ClearAllPoints()

  if context.previewX and context.previewY then
    frame:SetPoint(
      "TOPLEFT",
      canvas,
      "TOPLEFT",
      ns.Pixel.Round(context.previewX / scale),
      ns.Pixel.Round(context.previewY / scale)
    )
  else
    frame:SetPoint(
      "CENTER",
      canvas,
      "CENTER",
      0,
      ns.Pixel.Round((tonumber(context.previewCenterYOffset) or -4) / scale)
    )
  end

  Presentation.Apply("UnitFrame", frame, {
    unit = context.unitKey,
    config = frameDB,
    layout = layout,
    colors = presentationColors,
    textColors = presentationColors,
    fontRevision = ns.UnitFrames and ns.UnitFrames._fontRev or 0,
    useClassColor = useClassColor,
    forceShown = context.forceShown == true,
    options = {
      forceNoPower = forceNoPower,
      groupKind = context.grouped and context.unitKey or nil,
      useConfigText = context.grouped == true,
    },
  }, {
    health = tonumber(context.previewHealth) or 73,
    healthMax = 100,
    power = tonumber(context.previewPower) or 62,
    powerMin = 0,
    powerMax = 100,
    name = context.previewName
      or (context.grouped and (context.unitKey == "raid" and "Raid member" or "Party member") or "Preview unit"),
    healthText = tostring(tonumber(context.previewHealth) or 73) .. "%",
    powerText = tostring(tonumber(context.previewPower) or 62) .. "%",
    healthColor = healthColor,
    powerColor = powerColor,
    healthMissingColor = missingColor,
  })

  frame.__puiAuraPreviewBackground = frame.__pui_bg

  local health = frame.Health
  local power = frame.Power
  local roleIndicator = frame.__puiAuraPreviewRoleIndicator
  local statusIndicator = frame.__puiAuraPreviewStatusIndicator

  local showGroupedIndicators = context.grouped
    and not context.partyPetPreview
    and not context.compactOverview
    and not context.dispelPreview

  if showGroupedIndicators and frameDB.showRoleIcon ~= false then
    local roleSize = math_max(
      ns.Pixel.Round(8),
      ns.Pixel.Round((tonumber(frameDB.roleIconSize) or 17))
    )
    local rolePoint = frameDB.roleIconPosition
      or (context.unitKey == "raid" and "TOPLEFT" or "BOTTOM")

    roleIndicator:ClearAllPoints()
    roleIndicator:SetPoint(
      rolePoint,
      frame,
      rolePoint,
      ns.Pixel.Round(
        (tonumber(frameDB.roleIconXOffset) or 0)
      ),
      ns.Pixel.Round(
        (tonumber(frameDB.roleIconYOffset) or 0)
      )
    )
    roleIndicator:SetSize(roleSize, roleSize)
    Theme.ApplyFont(
      frame.__puiAuraPreviewRoleText,
      "tiny",
      math_max(7, roleSize * 0.55),
      "OUTLINE"
    )
    roleIndicator:Show()
  else
    roleIndicator:Hide()
  end

  local showStatusIndicator = showGroupedIndicators
    and (
      frameDB.showReadyCheck ~= false
      or frameDB.showSummon ~= false
      or frameDB.showInCombat ~= false
      or frameDB.showCombatRes ~= false
      or frameDB.showPhase ~= false
    )

  if showStatusIndicator then
    local statusSize = math_max(
      ns.Pixel.Round(8),
      ns.Pixel.Round((tonumber(frameDB.statusIconSize) or 18))
    )

    statusIndicator:ClearAllPoints()
    statusIndicator:SetPoint(
      "TOPRIGHT",
      frame,
      "TOPRIGHT",
      -ns.Pixel.Round(2),
      -ns.Pixel.Round(2)
    )
    statusIndicator:SetSize(statusSize, statusSize)
    Theme.ApplyFont(
      frame.__puiAuraPreviewStatusText,
      "tiny",
      math_max(7, statusSize * 0.55),
      "OUTLINE"
    )
    statusIndicator:Show()
  else
    statusIndicator:Hide()
  end

  context.frame = frame
  context.health = health
  context.power = power
  context.rawWidth = rawWidth
  context.rawHeight = rawHeight
  context.scale = scale
  context.healthRawHeight = layout.healthHeight

  LayoutUnitFramePreviewInteractions(frame)
  ConfigureUnitFramePreviewInteractions(context)
  return frame
end

local function CopyAuraPreviewContext(context)
  local output = {}

  for key, value in pairs(context) do
    output[key] = value
  end

  return output
end

local function GetInlineGroupedPreviewDensity(box)
  local density = box.__puiInlineGroupedPreviewDensity

  if density then
    return density
  end

  density = {
    partyMembers = INLINE_PARTY_PREVIEW_DEFAULT_MEMBERS,
    raidGroups = INLINE_RAID_PREVIEW_DEFAULT_GROUPS,
    raidMembersPerGroup = INLINE_RAID_PREVIEW_DEFAULT_MEMBERS_PER_GROUP,
  }
  box.__puiInlineGroupedPreviewDensity = density
  return density
end

local function GetInlineGroupedPreviewInsets(box, context)
  local topInset = 8

  if context.supportsAuraManager then
    topInset = topInset
      + (tonumber(box.__puiAuraCreateToolbarHeight) or 0)
      + 38
      + (tonumber(box.__puiAuraInteractionHintHeight) or 0)
  end

  local bottomInset = context.unitKey == "raid" and 86 or 64
  return {
    left = 8,
    right = 8,
    top = topInset,
    bottom = bottomInset,
  }
end

local function GetInlineGroupedPreviewScale(box, context)
  return math_max(
    0.25,
    math_min(2, tonumber(context.previewZoom) or 1)
  ), GetInlineGroupedPreviewInsets(box, context)
end

local function RenderInlineGroupedPreview(box, addon, context)
  local density = GetInlineGroupedPreviewDensity(box)
  local positions
  local effectiveScale
  local insets

  if context.unitKey == "raid" then
    effectiveScale, insets = GetInlineGroupedPreviewScale(box, context)
    positions = BuildRaidAuraPreviewPositions(
      box,
      context.frameDB,
      density.raidGroups,
      density.raidMembersPerGroup,
      effectiveScale,
      insets
    )
  else
    effectiveScale, insets = GetInlineGroupedPreviewScale(box, context)
    positions = BuildPartyAuraPreviewPositions(
      box,
      context.frameDB,
      density.partyMembers,
      effectiveScale,
      insets
    )
  end

  local primaryContext

  if context.dispelPreview then
    box.__puiDispelPreviewEntries = {}
  end

  for memberIndex, position in ipairs(positions) do
    local memberContext = CopyAuraPreviewContext(context)
    local classToken = UNIT_FRAME_PREVIEW_CLASS_TOKENS[
      ((memberIndex - 1) % #UNIT_FRAME_PREVIEW_CLASS_TOKENS) + 1
    ]

    memberContext.addon = addon
    memberContext.allowDrag = memberIndex == 1 and context.allowDrag == true
    memberContext.supportsAuraManager = memberIndex == 1
      and context.supportsAuraManager == true
    memberContext.sampleIndex = memberIndex
    memberContext.previewZoom = effectiveScale
    memberContext.previewHealth = 38 + ((memberIndex * 13) % 59)
    memberContext.previewPower = 20 + ((memberIndex * 17) % 73)
    memberContext.previewClassToken = classToken
    memberContext.previewX = position.x
    memberContext.previewY = position.y

    if context.unitKey == "raid" then
      memberContext.previewName = "G"
        .. tostring(position.groupIndex)
        .. " "
        .. classToken
    else
      memberContext.previewName = "Party "
        .. tostring(memberIndex)
        .. " "
        .. classToken
    end

    BuildAuraPreviewFrame(box, box:GetCanvas(), memberContext)

    if context.dispelPreview then
      local entries = box.__puiDispelPreviewEntries
      entries[#entries + 1] = {
        frame = memberContext.frame,
        context = memberContext,
      }
    end

    if memberIndex == 1 then
      primaryContext = memberContext

      if not context.dispelPreview then
        for displayIndex, display in ipairs(GetOrderedAuraDisplays(memberContext.displays)) do
          local previewDisplay = BuildAuraPreviewDisplay(
            box,
            memberContext,
            display,
            displayIndex
          )

          if previewDisplay then
            box.__puiAuraPreviewDisplays[display.id] = previewDisplay
          end
        end
      end
    end
  end

  return primaryContext or context
end

local function BeginUnitFrameOverviewCardPool(box)
  for _, card in ipairs(box.__puiUnitFrameOverviewCardPool or {}) do
    card:Hide()
    card:ClearAllPoints()
    card.__puiUnitFrameOverviewAddon = nil
    card.__puiUnitFrameOverviewFamily = nil
  end
end

local function AcquireUnitFrameOverviewCard(box, canvas)
  local pool = box.__puiUnitFrameOverviewCardPool
  if not pool then
    pool = {}
    box.__puiUnitFrameOverviewCardPool = pool
  end

  local index = (box.__puiUnitFrameOverviewCardPoolIndex or 0) + 1
  box.__puiUnitFrameOverviewCardPoolIndex = index

  local card = pool[index]
  if not card then
    card = CreateFrame("Button", nil, canvas, "BackdropTemplate")
    card:SetFrameLevel(canvas:GetFrameLevel() + 2)
    card:EnableMouse(true)

    local colors = Theme.GetColors()
    Theme.SetSquareBackdrop(card, {
      bg = colors.background,
      border = colors.border,
    }, Theme.GetEdgeSize())

    local hover = card:CreateTexture(nil, "BORDER")
    hover:SetAllPoints(card)
    hover:SetTexture("Interface\\Buttons\\WHITE8x8")
    hover:SetVertexColor(
      colors.accent[1],
      colors.accent[2],
      colors.accent[3],
      0.10
    )
    hover:Hide()
    card.__puiUnitFrameOverviewHover = hover

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
    title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -6)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    Theme.ApplyFont(title, "header", 11)
    card.__puiUnitFrameOverviewTitle = title

    card:SetScript("OnEnter", function(self)
      self.__puiUnitFrameOverviewHover:Show()
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.__puiUnitFrameOverviewTitle:GetText(), 1, 1, 1)
      GameTooltip:AddLine("Open this unit-frame family.", 0.82, 0.82, 0.82, true)
      GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
      self.__puiUnitFrameOverviewHover:Hide()
      GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self)
      local addon = self.__puiUnitFrameOverviewAddon
      local family = self.__puiUnitFrameOverviewFamily

      if addon and family then
        ns.PreviewBox.NavigateToOption(addon, {
          "unitframes",
          family,
        })
      end
    end)

    pool[index] = card
  end

  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(card, {
    bg = colors.background,
    border = colors.border,
  }, Theme.GetEdgeSize())
  card.__puiUnitFrameOverviewHover:SetVertexColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    0.10
  )
  card.__puiUnitFrameOverviewTitle:SetTextColor(
    colors.text[1],
    colors.text[2],
    colors.text[3],
    colors.text[4] or 1
  )
  card:SetParent(canvas)
  card:SetFrameLevel(canvas:GetFrameLevel() + 2)
  card.__puiUnitFrameOverviewHover:Hide()
  card:Show()
  return card
end

local function HideAuraManagerPreviewControls(box)
  box.__puiAuraCreateToolbar:Hide()

  for _, button in ipairs(box.__puiAuraCreateButtons or {}) do
    button:Hide()
  end

  box.__puiAuraSelectionLabel:Hide()
  box.__puiAuraVisibilityButton:Hide()
  box.__puiAuraInteractionHint:Hide()
  box.__puiAuraPreviewZoomControl:Hide()

  for _, control in pairs(box.__puiInlineDensityControls or {}) do
    control:Hide()
  end
end

local function RenderUnitFrameOverviewGallery(box, addon)
  local canvas = box:GetCanvas()
  local canvasWidth = math_floor((tonumber(canvas:GetWidth()) or 0) + 0.5)
  local canvasHeight = math_floor((tonumber(canvas:GetHeight()) or 0) + 0.5)

  if canvasWidth < 1 then
    canvasWidth = 300
  end

  if canvasHeight < 1 then
    canvasHeight = 180
  end

  local horizontalGaps = UNIT_FRAME_OVERVIEW_CARD_GAP * 2
  local verticalGaps = UNIT_FRAME_OVERVIEW_CARD_GAP
  local usableWidth = canvasWidth - UNIT_FRAME_OVERVIEW_CARD_INSET * 2 - horizontalGaps
  local usableHeight = canvasHeight - UNIT_FRAME_OVERVIEW_CARD_INSET * 2 - verticalGaps
  local cardWidth = math_max(84, math_floor(usableWidth / 3))
  local cardHeight = math_max(70, math_floor(usableHeight / 2))

  box.__puiUnitFrameOverviewCardPoolIndex = 0

  for familyIndex, definition in ipairs(UNIT_FRAME_OVERVIEW_FAMILIES) do
    local column = (familyIndex - 1) % 3
    local row = math_floor((familyIndex - 1) / 3)
    local cardX = UNIT_FRAME_OVERVIEW_CARD_INSET
      + column * (cardWidth + UNIT_FRAME_OVERVIEW_CARD_GAP)
    local cardY = -(UNIT_FRAME_OVERVIEW_CARD_INSET
      + row * (cardHeight + UNIT_FRAME_OVERVIEW_CARD_GAP))
    local card = AcquireUnitFrameOverviewCard(box, canvas)

    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", canvas, "TOPLEFT", cardX, cardY)
    card:SetSize(cardWidth, cardHeight)
    card.__puiUnitFrameOverviewTitle:SetText(definition.label)
    card.__puiUnitFrameOverviewAddon = addon
    card.__puiUnitFrameOverviewFamily = definition.key

    local baseContext = GetAuraManagerPreviewContext({
      "unitframes",
      definition.key,
    })
    local resolvedWidth, resolvedHeight = ns.UFStyle.ResolveFrameSize(baseContext.frameDB)
    local rawWidth = math_max(40, resolvedWidth)
    local rawHeight = math_max(12, resolvedHeight)
    local clusterRawWidth = rawWidth * definition.columns
      + UNIT_FRAME_OVERVIEW_FRAME_GAP * (definition.columns - 1)
    local clusterRawHeight = rawHeight * definition.rows
      + UNIT_FRAME_OVERVIEW_FRAME_GAP * (definition.rows - 1)
    local frameAreaWidth = math_max(1, cardWidth - 16)
    local frameAreaHeight = math_max(1, cardHeight - UNIT_FRAME_OVERVIEW_TITLE_HEIGHT - 8)
    local scale = math_min(
      1,
      frameAreaWidth / clusterRawWidth,
      frameAreaHeight / clusterRawHeight
    )
    local clusterWidth = clusterRawWidth * scale
    local clusterHeight = clusterRawHeight * scale
    local clusterX = (cardWidth - clusterWidth) * 0.5
    local clusterY = -UNIT_FRAME_OVERVIEW_TITLE_HEIGHT
      - (frameAreaHeight - clusterHeight) * 0.5

    for frameIndex = 1, #definition.names do
      local frameColumn = (frameIndex - 1) % definition.columns
      local frameRow = math_floor((frameIndex - 1) / definition.columns)
      local context = GetAuraManagerPreviewContext({
        "unitframes",
        definition.key,
      })

      context.box = box
      context.addon = addon
      context.supportsAuraManager = false
      context.allowDrag = false
      context.compactOverview = true
      context.forceShown = true
      context.previewZoom = scale
      context.previewX = clusterX
        + frameColumn * (rawWidth + UNIT_FRAME_OVERVIEW_FRAME_GAP) * scale
      context.previewY = clusterY
        - frameRow * (rawHeight + UNIT_FRAME_OVERVIEW_FRAME_GAP) * scale
      context.previewName = definition.names[frameIndex]
      context.previewHealth = 42 + ((familyIndex * 11 + frameIndex * 9) % 51)
      context.previewPower = 24 + ((familyIndex * 13 + frameIndex * 7) % 65)
      context.previewClassToken = UNIT_FRAME_PREVIEW_CLASS_TOKENS[
        ((familyIndex + frameIndex - 2) % #UNIT_FRAME_PREVIEW_CLASS_TOKENS) + 1
      ]

      BuildAuraPreviewFrame(box, card, context)
    end
  end
end

local function GetAuraPreviewAttachTarget(context)
  return context.frame
end

BuildAuraManagerDisplayPath = function(context, display)
  local path = CopyPreviewPath(context.managerPath)

  if display.builtInKey == "DEFAULT_BUFF" then
    path[#path + 1] = "buffs"
  elseif display.builtInKey == "DEFENSIVES_EXTERNALS" then
    path[#path + 1] = "defensives"
  elseif display.builtInKey == "IMPORTANT_BUFFS" then
    path[#path + 1] = "important"
  elseif display.builtInKey == "DEFAULT_DEBUFF" then
    path[#path + 1] = "debuffs"
  else
    path[#path + 1] = "display_" .. tostring(display.id)
  end

  return path
end



local function ShowAuraPreviewTooltip(owner, title, description)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title, 1, 1, 1)

  if description and description ~= "" then
    GameTooltip:AddLine(description, 0.82, 0.82, 0.82, true)
  end

  GameTooltip:Show()
end

local function HideAuraPreviewTooltip()
  GameTooltip:Hide()
end

local function DismissAuraPreviewHint(context)
  if context.previewHintSeen then
    return
  end

  context.previewHintSeen = true
  context.selectionDB.auraPreviewHintSeen = true

  if context.box then
    UpdateAuraPreviewHint(context.box, context)
  end
end

local function AuraManagerOptionPathMatches(path, sectionKey, optionKey)
  if type(path) ~= "table" then
    return false
  end

  for index = 1, #path - 1 do
    if path[index] == sectionKey and path[index + 1] == optionKey then
      return true
    end
  end

  return false
end

local function FindAuraManagerOptionWidget(root, sectionKey, optionKey)
  local targetWidget
  local targetScroll

  local function Walk(widget, scrollWidget)
    if widget.type == "ScrollFrame" then
      scrollWidget = widget
    end

    if widget.GetUserDataTable then
      local user = widget:GetUserDataTable()

      if AuraManagerOptionPathMatches(user.path, sectionKey, optionKey) then
        targetWidget = widget
        targetScroll = scrollWidget
        return true
      end
    end

    for _, child in ipairs(widget.children or {}) do
      if Walk(child, scrollWidget) then
        return true
      end
    end

    return false
  end

  Walk(root)
  return targetWidget, targetScroll
end

local function ShowAuraManagerOptionGlow(targetFrame)
  local glow = Preview.__puiAuraManagerOptionGlow

  if not glow then
    glow = CreateFrame("Frame", nil, UIParent)

    local function CreateEdge()
      local edge = glow:CreateTexture(nil, "OVERLAY")
      edge:SetColorTexture(1, 1, 1, 1)
      return edge
    end

    glow.top = CreateEdge()
    glow.bottom = CreateEdge()
    glow.left = CreateEdge()
    glow.right = CreateEdge()

    glow.top:SetHeight(2)
    glow.top:SetPoint("TOPLEFT")
    glow.top:SetPoint("TOPRIGHT")
    glow.bottom:SetHeight(2)
    glow.bottom:SetPoint("BOTTOMLEFT")
    glow.bottom:SetPoint("BOTTOMRIGHT")
    glow.left:SetWidth(2)
    glow.left:SetPoint("TOPLEFT", glow.top, "BOTTOMLEFT")
    glow.left:SetPoint("BOTTOMLEFT", glow.bottom, "TOPLEFT")
    glow.right:SetWidth(2)
    glow.right:SetPoint("TOPRIGHT", glow.top, "BOTTOMRIGHT")
    glow.right:SetPoint("BOTTOMRIGHT", glow.bottom, "TOPRIGHT")

    Preview.__puiAuraManagerOptionGlow = glow
  end

  local color = Theme.GetColors().accent

  glow:SetParent(targetFrame)
  glow:ClearAllPoints()
  glow:SetAllPoints(targetFrame)
  glow:SetFrameLevel(targetFrame:GetFrameLevel() + 20)
  glow.top:SetColorTexture(color[1], color[2], color[3], 1)
  glow.bottom:SetColorTexture(color[1], color[2], color[3], 1)
  glow.left:SetColorTexture(color[1], color[2], color[3], 1)
  glow.right:SetColorTexture(color[1], color[2], color[3], 1)
  glow.elapsed = 0
  glow:SetAlpha(1)
  glow:Show()
  glow:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed

    if self.elapsed >= 0.8 then
      self:Hide()
      self:SetScript("OnUpdate", nil)
      return
    end

    self:SetAlpha(1 - self.elapsed / 0.8)
  end)
end

FocusAuraManagerOption = function(sectionKey, optionKey)
  C_Timer.After(0.05, function()
    local optionsFrame = ns.Addon._OptionsWindow
    local shell = optionsFrame and optionsFrame.__puiPageShell
    local root = shell and shell.acdContainer

    if not root then
      return
    end

    local targetWidget, scrollWidget = FindAuraManagerOptionWidget(root, sectionKey, optionKey)
    if not targetWidget then
      return
    end

    local targetFrame = targetWidget.frame

    if scrollWidget then
      local contentTop = scrollWidget.content:GetTop()
      local targetTop = targetFrame:GetTop()
      local scrollRange = math_max(0, scrollWidget.content:GetHeight() - scrollWidget.scrollframe:GetHeight())

      if contentTop and targetTop and scrollRange > 0 then
        local offset = math_min(scrollRange, math_max(0, contentTop - targetTop - 24))
        scrollWidget.scrollbar:SetValue(offset / scrollRange * 1000)
      end
    end

    C_Timer.After(0.1, function()
      ShowAuraManagerOptionGlow(targetFrame)
    end)
  end)
end

NavigateAuraPreviewElement = function(previewDisplay, sectionKey, optionKey)
  local context = previewDisplay.context

  DismissAuraPreviewHint(context)
  context.addon:SelectOptionsPath(BuildAuraManagerDisplayPath(context, previewDisplay.display))
  FocusAuraManagerOption(sectionKey, optionKey)
end

local function GetPreviewAuraState(display, displayIndex, iconIndex, sample)
  local seed = (tonumber(display.id) or 0) * 17 + displayIndex * 11 + iconIndex * 7
  local durations = {
    12,
    18,
    24,
    35,
    45,
    60,
  }
  local duration = durations[((seed - 1) % #durations) + 1]
  local applications = iconIndex % 3 == 1 and 2 or iconIndex % 3 == 0 and 3 or 0

  return {
    duration = duration,
    applications = applications,
    dispelColor = sample and sample.dispelColor or nil,
    elapsedFraction = 0.18 + ((seed % 5) * 0.12),
  }
end

local function CreateAuraPreviewIcon(box, context, display, appearance, spellID, size, state)
  local icon = AcquireAuraPreviewIcon(box, box:GetCanvas())
  icon.__puiAuraDisplayID = display.id

  icon.Icon:SetTexture(C_Spell.GetSpellTexture(spellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
  icon.Count:Show()
  icon.__puiAuraPreviewShowDurationText = appearance.disableCountdownText ~= true
  AuraButtons.ApplyButtonAppearance(icon, appearance, size, context.previewZoom)

  if state.duration > 0 then
    local elapsed = state.duration * state.elapsedFraction
    icon.__puiAuraPreviewDurationValue = state.duration
    icon.__puiAuraPreviewExpiration = GetTime() + state.duration - elapsed
    icon.Cooldown:SetCooldown(GetTime() - elapsed, state.duration)
    icon.Cooldown:Show()
    icon.Duration:SetText(AuraButtons.DurationFormatter:FormatNumber(state.duration - elapsed))
    EnableAuraPreviewDurationUpdates(box)
  else
    icon.Cooldown:SetCooldown(0, 0)
    icon.Cooldown:Hide()
    icon.Duration:SetText("")
  end

  icon.Count:SetText(state.applications > 1 and tostring(state.applications) or "")

  if state.dispelColor then
    AuraButtons.ApplyPreviewDispelBorder(
      icon,
      (tonumber(appearance.dispelBorderSize) or 0) * (tonumber(context.previewZoom) or 1),
      state.dispelColor
    )
  else
    AuraButtons.ApplyPreviewDispelBorder(icon, 0, { 1, 1, 1, 1 })
  end

  return icon
end

local function ResetAuraPreviewDisplayControl(control)
  control:Hide()
  control:ClearAllPoints()
  control.__puiAuraPreviewDisplay = nil
  SetAuraPreviewSelected(control, false)
end

local function BeginAuraPreviewDisplayPool(box)
  box.__puiAuraPreviewDisplayPoolIndex = 0

  for _, control in ipairs(box.__puiAuraPreviewDisplayPool or {}) do
    ResetAuraPreviewDisplayControl(control)
  end
end

local function AcquireAuraPreviewDisplayControl(box, parent)
  local pool = box.__puiAuraPreviewDisplayPool
  if not pool then
    pool = {}
    box.__puiAuraPreviewDisplayPool = pool
  end

  local index = (box.__puiAuraPreviewDisplayPoolIndex or 0) + 1
  box.__puiAuraPreviewDisplayPoolIndex = index

  local control = pool[index]
  if not control then
    control = ns.PreviewBox.CreateInteraction(parent, parent, {
      draggable = true,
      frameLevel = parent:GetFrameLevel() + 70,
      title = function(button)
        local previewDisplay = button.__puiAuraPreviewDisplay
        return previewDisplay
          and (previewDisplay.display.name or "Aura display")
          or "Aura display"
      end,
      description = "Click to configure this exact aura display. Drag to reposition it.",
      onClick = function(button)
        local previewDisplay = button.__puiAuraPreviewDisplay
        local context = previewDisplay and previewDisplay.context

        if not context or context.supportsAuraManager == false then
          return
        end

        DismissAuraPreviewHint(context)
        context.addon:SelectOptionsPath(
          BuildAuraManagerDisplayPath(context, previewDisplay.display)
        )
      end,
      onDragStart = function(button)
        StartAuraPreviewDrag(button)
      end,
      onDragStop = function(button)
        StopAuraPreviewDrag(button, true)
      end,
    })
    pool[index] = control
  end

  control:SetParent(parent)
  control:SetFrameLevel(parent:GetFrameLevel() + 70)
  control:EnableMouse(true)
  control:Show()
  return control
end

local function CreateAuraPreviewElementButton(icon, navigation, title, description, sectionKey, optionKey)
  local button = ns.PreviewBox.CreateInteraction(icon, icon, {
    draggable = true,
    title = title,
    description = description,
    onClick = function(self)
      NavigateAuraPreviewElement(
        self.navigation.previewDisplay,
        self.sectionKey,
        self.optionKey
      )
    end,
    onDragStart = function(self)
      StartAuraPreviewDrag(self.navigation.previewDisplay.control)
    end,
    onDragStop = function(self)
      StopAuraPreviewDrag(self.navigation.previewDisplay.control, true)
    end,
  })

  button.navigation = navigation
  button.sectionKey = sectionKey
  button.optionKey = optionKey

  navigation.buttons[#navigation.buttons + 1] = button
  return button
end

local function ConfigureAuraPreviewElementNavigation(previewDisplay)
  local context = previewDisplay.context
  local icon = previewDisplay.icons[1]

  if context.supportsAuraManager == false then
    return
  end

  local navigation = icon.__puiAuraPreviewElementNavigation

  if not navigation then
    navigation = {
      buttons = {},
      borderButtons = {},
    }

    for _ = 1, 4 do
      navigation.borderButtons[#navigation.borderButtons + 1] = CreateAuraPreviewElementButton(
        icon,
        navigation,
        "Border settings",
        "Open the selected display and highlight its border-size control.",
        "appearance",
        "borderSize"
      )
    end

    navigation.durationButton = CreateAuraPreviewElementButton(
      icon,
      navigation,
      "Duration text settings",
      "Open the selected display and highlight its duration-font control.",
      "appearance",
      "durationTextSize"
    )
    navigation.stackButton = CreateAuraPreviewElementButton(
      icon,
      navigation,
      "Stack text settings",
      "Open the selected display and highlight its stack-font control.",
      "appearance",
      "stackTextSize"
    )

    icon.__puiAuraPreviewElementNavigation = navigation
  end

  navigation.previewDisplay = previewDisplay

  local size = previewDisplay.metrics.size
  local edgeSize = math_max(3, math_floor(size * 0.12 + 0.5))
  local top = navigation.borderButtons[1]
  local bottom = navigation.borderButtons[2]
  local left = navigation.borderButtons[3]
  local right = navigation.borderButtons[4]

  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
  top:SetHeight(edgeSize)

  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(edgeSize)

  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
  left:SetWidth(edgeSize)

  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
  right:SetWidth(edgeSize)

  navigation.durationButton:ClearAllPoints()
  navigation.durationButton:SetPoint("CENTER", icon, "CENTER", 0, 0)
  navigation.durationButton:SetSize(
    math_max(10, math_floor(size * 0.68 + 0.5)),
    math_max(8, math_floor(size * 0.42 + 0.5))
  )

  navigation.stackButton:ClearAllPoints()
  navigation.stackButton:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
  navigation.stackButton:SetSize(
    math_max(8, math_floor(size * 0.42 + 0.5)),
    math_max(8, math_floor(size * 0.42 + 0.5))
  )

  for index, button in ipairs(navigation.buttons) do
    button:SetFrameLevel(icon:GetFrameLevel() + 60 + index)
    button:Show()
  end
end

local function GetAnchorRelativeBounds(point, xOffset, yOffset, width, height)
  local left
  local bottom

  if point == "TOPRIGHT" or point == "RIGHT" or point == "BOTTOMRIGHT" then
    left = xOffset - width
  elseif point == "TOP" or point == "CENTER" or point == "BOTTOM" then
    left = xOffset - width * 0.5
  else
    left = xOffset
  end

  if point == "TOPLEFT" or point == "TOP" or point == "TOPRIGHT" then
    bottom = yOffset - height
  elseif point == "LEFT" or point == "CENTER" or point == "RIGHT" then
    bottom = yOffset - height * 0.5
  else
    bottom = yOffset
  end

  return left, bottom, left + width, bottom + height
end

local function PositionAuraPreviewDisplay(previewDisplay, xOffset, yOffset, anchorPoint, relativePoint)
  local metrics = previewDisplay.metrics
  local display = previewDisplay.display
  local target = previewDisplay.target

  anchorPoint = anchorPoint or display.anchorPoint or "TOPLEFT"
  relativePoint = relativePoint or display.relativePoint or anchorPoint
  previewDisplay.previewXOffset = xOffset
  previewDisplay.previewYOffset = yOffset
  previewDisplay.previewAnchorPoint = anchorPoint
  previewDisplay.previewRelativePoint = relativePoint

  local minX
  local minY
  local maxX
  local maxY
  local centeredX, centeredY = AuraLayout.GetSyntheticDisplayAnchorOffset(
    metrics,
    display,
    anchorPoint,
    #previewDisplay.icons
  )

  for index, icon in ipairs(previewDisplay.icons) do
    local iconX, iconY = AuraLayout.GetIconOffset(metrics, index)
    local currentX = xOffset + centeredX + iconX
    local currentY = yOffset + centeredY + iconY

    icon:ClearAllPoints()
    icon:SetPoint(anchorPoint, target, relativePoint, currentX, currentY)

    local left, bottom, right, top = GetAnchorRelativeBounds(
      anchorPoint,
      currentX,
      currentY,
      metrics.size,
      metrics.size
    )

    minX = minX and math_min(minX, left) or left
    minY = minY and math_min(minY, bottom) or bottom
    maxX = maxX and math_max(maxX, right) or right
    maxY = maxY and math_max(maxY, top) or top
  end

  local control = previewDisplay.control
  control:ClearAllPoints()
  control:SetPoint("BOTTOMLEFT", target, relativePoint, minX, minY)
  control:SetSize(math_max(1, maxX - minX), math_max(1, maxY - minY))
end

local function GetRegionAnchorOffset(region, point)
  local halfWidth = region:GetWidth() * 0.5
  local halfHeight = region:GetHeight() * 0.5

  if point == "TOPLEFT" then
    return -halfWidth, halfHeight
  elseif point == "TOP" then
    return 0, halfHeight
  elseif point == "TOPRIGHT" then
    return halfWidth, halfHeight
  elseif point == "LEFT" then
    return -halfWidth, 0
  elseif point == "RIGHT" then
    return halfWidth, 0
  elseif point == "BOTTOMLEFT" then
    return -halfWidth, -halfHeight
  elseif point == "BOTTOM" then
    return 0, -halfHeight
  elseif point == "BOTTOMRIGHT" then
    return halfWidth, -halfHeight
  end

  return 0, 0
end

local function EnsureAuraPreviewDragAnchors(box, parent)
  if box.__puiAuraPreviewDragAnchors then
    return box.__puiAuraPreviewDragAnchors
  end

  local anchors = {}

  for index, point in ipairs(AURA_PREVIEW_ANCHOR_POINTS) do
    local anchor = CreateFrame("Frame", nil, parent)
    anchor:SetSize(9, 9)
    anchor:SetFrameLevel(parent:GetFrameLevel() + 80)

    local texture = anchor:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(anchor)

    local anchorColor = Theme.GetColors().mutedText
    texture:SetColorTexture(
      anchorColor[1],
      anchorColor[2],
      anchorColor[3],
      anchorColor[4]
    )

    anchor.point = point
    anchor.texture = texture
    anchor:Hide()
    anchors[index] = anchor
  end

  box.__puiAuraPreviewDragAnchors = anchors
  return anchors
end

local function HideAuraPreviewDragAnchors(box)
  for _, anchor in ipairs(box.__puiAuraPreviewDragAnchors or {}) do
    anchor:Hide()
  end
end

local function ShowAuraPreviewDragAnchors(box, target)
  local anchors = EnsureAuraPreviewDragAnchors(box, box:GetCanvas())
  local anchorColor = Theme.GetColors().mutedText

  for _, anchor in ipairs(anchors) do
    anchor:SetParent(box:GetCanvas())
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", target, anchor.point, 0, 0)
    anchor.texture:SetColorTexture(
      anchorColor[1],
      anchorColor[2],
      anchorColor[3],
      anchorColor[4]
    )
    anchor:Show()
  end
end

local function UpdateAuraPreviewDropAnchor(box)
  local cursorX, cursorY = GetCursorPosition()
  local nearest
  local nearestDistance

  for _, anchor in ipairs(box.__puiAuraPreviewDragAnchors) do
    local centerX, centerY = anchor:GetCenter()
    local scale = anchor:GetEffectiveScale()
    local deltaX = cursorX - centerX * scale
    local deltaY = cursorY - centerY * scale
    local distance = deltaX * deltaX + deltaY * deltaY
    local maximumDistance =
      AURA_PREVIEW_SNAP_RADIUS_PX * AURA_PREVIEW_SNAP_RADIUS_PX

    if distance <= maximumDistance
      and (not nearestDistance or distance < nearestDistance)
    then
      nearest = anchor
      nearestDistance = distance
    end
  end

  local colors = Theme.GetColors()
  local hoverColor = colors.accent
  local anchorColor = colors.mutedText

  for _, anchor in ipairs(box.__puiAuraPreviewDragAnchors) do
    if anchor == nearest then
      anchor.texture:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    else
      anchor.texture:SetColorTexture(
        anchorColor[1],
        anchorColor[2],
        anchorColor[3],
        anchorColor[4]
      )
    end
  end

  box.__puiAuraPreviewDragState.dropAnchor = nearest and nearest.point or nil
end

local function UpdateAuraPreviewDrag(box)
  local state = box.__puiAuraPreviewDragState
  local cursorX, cursorY = GetCursorPosition()
  local parentScale = box:GetCanvas():GetEffectiveScale()
  local deltaX = (cursorX - state.startCursorX) / parentScale
  local deltaY = (cursorY - state.startCursorY) / parentScale

  state.currentXOffset = state.startXOffset + deltaX
  state.currentYOffset = state.startYOffset + deltaY

  PositionAuraPreviewDisplay(
    state.previewDisplay,
    state.currentXOffset,
    state.currentYOffset,
    state.previewDisplay.previewAnchorPoint,
    state.previewDisplay.previewRelativePoint
  )
  UpdateAuraPreviewDropAnchor(box)
end

StartAuraPreviewDrag = function(control)
  local previewDisplay = control.__puiAuraPreviewDisplay
  local context = previewDisplay.context

  if context.allowDrag == false or InCombatLockdown() then
    return
  end

  DismissAuraPreviewHint(context)

  local box = previewDisplay.box
  local cursorX, cursorY = GetCursorPosition()
  local driver = box.__puiAuraPreviewDragDriver

  if not driver then
    driver = CreateFrame("Frame", nil, box:GetCanvas())
    driver:SetScript("OnUpdate", function()
      UpdateAuraPreviewDrag(box)
    end)
    driver:Hide()
    box.__puiAuraPreviewDragDriver = driver
  end

  box.__puiAuraPreviewDragState = {
    previewDisplay = previewDisplay,
    startCursorX = cursorX,
    startCursorY = cursorY,
    startXOffset = previewDisplay.previewXOffset,
    startYOffset = previewDisplay.previewYOffset,
    currentXOffset = previewDisplay.previewXOffset,
    currentYOffset = previewDisplay.previewYOffset,
    dropAnchor = previewDisplay.previewRelativePoint,
  }

  ShowAuraPreviewDragAnchors(box, previewDisplay.target)
  UpdateAuraPreviewHint(box, context, previewDisplay.display)
  driver:Show()
end

StopAuraPreviewDrag = function(control, commit)
  local previewDisplay = control and control.__puiAuraPreviewDisplay
  local box = previewDisplay and previewDisplay.box
  local state = box and box.__puiAuraPreviewDragState

  if not state then
    return
  end

  box.__puiAuraPreviewDragState = nil
  box.__puiAuraPreviewDragDriver:Hide()
  HideAuraPreviewDragAnchors(box)
  UpdateAuraPreviewHint(box, state.previewDisplay.context)

  if not commit or InCombatLockdown() then
    Preview.RefreshAuraManagerPreview()
    return
  end

  local display = state.previewDisplay.display
  local anchorPoint = state.previewDisplay.previewAnchorPoint
  local oldRelativePoint = state.previewDisplay.previewRelativePoint
  local newRelativePoint = state.dropAnchor or oldRelativePoint
  local target = state.previewDisplay.target
  local oldAnchorX, oldAnchorY = GetRegionAnchorOffset(target, oldRelativePoint)
  local newAnchorX, newAnchorY = GetRegionAnchorOffset(target, newRelativePoint)
  local xOffset = ns.Pixel.Round(
    (oldAnchorX + state.currentXOffset - newAnchorX) / state.previewDisplay.context.scale
  )
  local yOffset = ns.Pixel.Round(
    (oldAnchorY + state.currentYOffset - newAnchorY) / state.previewDisplay.context.scale
  )

  display.relativePoint = newRelativePoint
  display.xOffset = xOffset
  display.yOffset = yOffset

  PositionAuraPreviewDisplay(
    state.previewDisplay,
    xOffset * state.previewDisplay.context.scale,
    yOffset * state.previewDisplay.context.scale,
    anchorPoint,
    newRelativePoint
  )

  Preview.AuraManagerPositionCommitter(
    state.previewDisplay.context.unitKey,
    display.id,
    anchorPoint,
    newRelativePoint,
    xOffset,
    yOffset
  )
end

BuildAuraPreviewDisplay = function(box, context, display, displayIndex)
  if context.auraDB.enabled == false or display.enabled == false then
    return nil
  end

  local target = GetAuraPreviewAttachTarget(context)
  local metrics = AuraLayout.ResolveDisplayMetrics(
    context.rawWidth,
    context.healthRawHeight,
    context.scale,
    context.grouped,
    display
  )
  local shown = AuraLayout.GetSyntheticDisplayIconCount(display, metrics.maxIcons)
  if shown <= 0 then
    return nil
  end

  local xOffset = math_floor((tonumber(display.xOffset) or 0) * context.scale + 0.5)
  local yOffset = math_floor((tonumber(display.yOffset) or 0) * context.scale + 0.5)
  local anchorPoint = display.anchorPoint or "TOPLEFT"
  local relativePoint = display.relativePoint or anchorPoint
  local appearance = ns.UFAuraFilters.BuildEffectiveAppearance(context.auraDB, display)
  local output = {
    box = box,
    context = context,
    display = display,
    icons = {},
    metrics = metrics,
    target = target,
  }

  for index = 1, shown do
    local iconX, iconY = AuraLayout.GetIconOffset(metrics, index)
    local sample = GetPreviewAuraSample(
      display,
      displayIndex + (tonumber(context.sampleIndex) or 0) * 3 + index - 1
    )
    local icon = CreateAuraPreviewIcon(
      box,
      context,
      display,
      appearance,
      sample.spellID,
      metrics.size,
      GetPreviewAuraState(
        display,
        displayIndex + (tonumber(context.sampleIndex) or 0) * 3,
        index,
        sample
      )
    )

    icon:SetPoint(
      anchorPoint,
      target,
      relativePoint,
      xOffset + iconX,
      yOffset + iconY
    )

    output.icons[#output.icons + 1] = icon
  end

  local control = AcquireAuraPreviewDisplayControl(box, box:GetCanvas())
  output.control = control
  control.__puiAuraPreviewDisplay = output
  PositionAuraPreviewDisplay(output, xOffset, yOffset, anchorPoint)
  ConfigureAuraPreviewElementNavigation(output)

  if metrics.maxIcons > shown then
    local lastIcon = output.icons[#output.icons]
    local overflow = lastIcon.__puiAuraPreviewOverflow
    overflow:ClearAllPoints()
    overflow:SetPoint("CENTER", lastIcon, "CENTER", 0, 0)
    Theme.ApplyFont(overflow, "tiny", math_max(8, math_floor(metrics.size * 0.42)), "OUTLINE")
    overflow:SetText("+" .. tostring(metrics.maxIcons - shown))
    overflow:Show()
    output.overflow = overflow
  end

  return output
end



local function ApplyAuraManagerPreviewSelection(box, selectedID)
  box.__puiAuraPreviewSelectedID = selectedID

  for displayID, previewDisplay in pairs(box.__puiAuraPreviewDisplays or {}) do
    SetAuraPreviewSelected(previewDisplay.control, displayID == selectedID)
  end

  local context = box.__puiAuraPreviewContext
  if context then
    SetAuraPreviewSelected(context.frame, false)
    SetAuraPreviewSelected(context.health, false)
    SetAuraPreviewSelected(context.power, false)

    local selectedDisplay = selectedID and box.__puiAuraPreviewDisplays[selectedID]
    if selectedDisplay then
      SetAuraPreviewSelected(selectedDisplay.target, true)
    end

    UpdateAuraPreviewSelectionUI(box, context)
  end
end

local function UpdateUnitFramePreviewMode(box, path)
  local overview = IsUnitFrameOverviewPath(path)

  if overview then
    box:SetTitle("Unit frame overview")
    box:SetDescription("Global Unit Frame settings update every family below. Click a card to open that family, or click a bar or text element for its exact setting.")
  elseif IsDispelPreviewOptionsPath(path) then
    box:SetTitle("Dispel preview")
    box:SetDescription("Shows only the enabled dispel indicators and cycles Magic, Curse, Disease, Bleed, and Poison every 2 seconds.")
  else
    box:SetTitle("Unit frame preview")
    box:SetDescription("Click frame bars, text, indicators, buffs, or debuffs to open their exact settings. Aura displays remain draggable without triggering navigation.")
  end

  return overview
end

local function ApplyCurrentDispelPreview(box)
  local entries = box.__puiDispelPreviewEntries
  if type(entries) ~= "table" then
    return
  end

  local index = tonumber(box.__puiDispelPreviewTypeIndex) or 1
  local dispelType = DISPEL_PREVIEW_TYPES[index] or DISPEL_PREVIEW_TYPES[1]

  for _, entry in ipairs(entries) do
    ApplyDispelPreviewVisuals(entry.frame, entry.context, dispelType)
  end
end

local function StopDispelPreviewCycle(box)
  local ticker = box.__puiDispelPreviewTicker
  if ticker then
    ticker:Cancel()
    box.__puiDispelPreviewTicker = nil
  end
end

local function StartDispelPreviewCycle(box)
  StopDispelPreviewCycle(box)

  if not box.__puiDispelPreviewHideHooked then
    box:HookScript("OnHide", StopDispelPreviewCycle)
    box.__puiDispelPreviewHideHooked = true
  end

  box.__puiDispelPreviewTypeIndex = tonumber(box.__puiDispelPreviewTypeIndex) or 1
  ApplyCurrentDispelPreview(box)

  box.__puiDispelPreviewTicker = C_Timer.NewTicker(DISPEL_PREVIEW_INTERVAL, function()
    if not box:IsVisible() or not IsDispelPreviewOptionsPath(ns._PUIActiveOptionsPath) then
      StopDispelPreviewCycle(box)
      return
    end

    local index = (tonumber(box.__puiDispelPreviewTypeIndex) or 1) + 1
    if index > #DISPEL_PREVIEW_TYPES then
      index = 1
    end

    box.__puiDispelPreviewTypeIndex = index
    ApplyCurrentDispelPreview(box)
  end)
end

RenderAuraManagerPreview = function(box, addon, path)
  StopDispelPreviewCycle(box)
  box.__puiDispelPreviewEntries = nil

  BeginAuraPreviewFramePool(box)
  BeginAuraPreviewIconPool(box)
  BeginAuraPreviewDisplayPool(box)
  BeginUnitFrameOverviewCardPool(box)

  box.__puiAuraPreviewAddon = addon
  box.__puiAuraPreviewPath = CopyPreviewPath(path)
  box.__puiAuraPreviewDisplays = {}

  if UpdateUnitFramePreviewMode(box, path) then
    box.__puiAuraPreviewContext = nil
    box.__puiAuraPreviewSelectedID = nil
    HideAuraManagerPreviewControls(box)
    RenderUnitFrameOverviewGallery(box, addon)
    return
  end

  local canvas = box:GetCanvas()
  local context = GetAuraManagerPreviewContext(path)

  context.box = box
  context.addon = addon
  context.supportsAuraManager = AURA_MANAGER_UNITS[context.unitKey] == true
    and not context.dispelPreview
  context.allowDrag = context.supportsAuraManager

  box.__puiAuraPreviewContext = context
  box.__puiAuraPreviewSelectedID = context.selectedID

  SyncAuraPreviewControls(box, context)

  local renderContext = context

  if context.grouped and not context.partyPetPreview then
    renderContext = RenderInlineGroupedPreview(box, addon, context)
  else
    context.previewCenterYOffset = 0
    BuildAuraPreviewFrame(box, canvas, context)

    for index, display in ipairs(GetOrderedAuraDisplays(context.displays)) do
      local previewDisplay = BuildAuraPreviewDisplay(box, context, display, index)
      if previewDisplay then
        box.__puiAuraPreviewDisplays[display.id] = previewDisplay
      end
    end
  end

  box.__puiAuraPreviewContext = renderContext

  ApplyAuraManagerPreviewSelection(box, renderContext.selectedID)

  if context.dispelPreview then
    StartDispelPreviewCycle(box)
  end
end

function Preview.HandleUnitFrameOptionsPathChanged(addon, _optionsFrame, shell, path)
  if not Preview.IsUnitFramesOptionsPath(path) then
    return
  end

  local context = GetAuraManagerPreviewContext(path)
  local selectedID = GetAuraManagerPathSelection(path)

  if selectedID and context.displays[selectedID] then
    context.selectionDB.selectedCustomDisplayID = selectedID
  end

  local box = shell and shell.__puiAuraManagerPreviewBox
  if not (box and box:GetParent() == shell.previewHost) then
    return
  end

  RenderAuraManagerPreview(box, addon, path)
end

function Preview.RefreshAuraManagerPreview()
  if Preview.__puiAuraManagerRefreshQueued then
    return
  end

  Preview.__puiAuraManagerRefreshQueued = true

  C_Timer.After(0, function()
    Preview.__puiAuraManagerRefreshQueued = nil

    local optionsFrame = ns.Addon._OptionsWindow
    local shell = optionsFrame and optionsFrame.__puiPageShell
    local box = shell and shell.__puiAuraManagerPreviewBox

    if not (optionsFrame and optionsFrame:IsShown()
      and box
      and box:GetParent() == shell.previewHost
      and shell.previewDock:IsShown())
    then
      return
    end

    local path = ns._PUIActiveOptionsPath
    if not Preview.IsUnitFramesOptionsPath(path) then
      path = box.__puiAuraPreviewPath
    end

    if Preview.IsUnitFramesOptionsPath(path) then
      RenderAuraManagerPreview(box, box.__puiAuraPreviewAddon or ns.Addon, path)
    end
  end)
end

function Preview.RegisterAuraManagerDisplayCreator(callback)
  Preview.AuraManagerDisplayCreator = callback
end

function Preview.RegisterAuraManagerVisibilityCommitter(callback)
  Preview.AuraManagerVisibilityCommitter = callback
end

function Preview.RegisterAuraManagerPositionCommitter(callback)
  Preview.AuraManagerPositionCommitter = callback
end



CenterGroupedAuraPreviewPositions = function(
  host,
  positions,
  frameWidth,
  frameHeight,
  insets
)
  local minLeft
  local maxRight
  local maxTop
  local minBottom

  for _, position in ipairs(positions) do
    local left = position.x
    local right = left + frameWidth
    local top = position.y
    local bottom = top - frameHeight

    minLeft = minLeft and math_min(minLeft, left) or left
    maxRight = maxRight and math_max(maxRight, right) or right
    maxTop = maxTop and math_max(maxTop, top) or top
    minBottom = minBottom and math_min(minBottom, bottom) or bottom
  end

  local canvas = host:GetCanvas()
  local canvasWidth = math_max(1, tonumber(canvas:GetWidth()) or 884)
  local canvasHeight = math_max(1, tonumber(canvas:GetHeight()) or 500)
  local leftInset = tonumber(insets and insets.left) or 0
  local rightInset = tonumber(insets and insets.right) or 0
  local topInset = tonumber(insets and insets.top) or 0
  local bottomInset = tonumber(insets and insets.bottom) or 0
  local availableWidth = math_max(1, canvasWidth - leftInset - rightInset)
  local availableHeight = math_max(1, canvasHeight - topInset - bottomInset)
  local totalWidth = math_max(1, maxRight - minLeft)
  local totalHeight = math_max(1, maxTop - minBottom)
  local desiredLeft = leftInset
    + math_floor((availableWidth - totalWidth) * 0.5 + 0.5)
  local desiredTop = -(
    topInset
      + math_floor((availableHeight - totalHeight) * 0.5 + 0.5)
  )
  local xShift = desiredLeft - minLeft
  local yShift = desiredTop - maxTop

  for _, position in ipairs(positions) do
    position.x = math_floor(position.x + xShift + 0.5)
    position.y = math_floor(position.y + yShift + 0.5)
  end

  return positions, totalWidth, totalHeight
end

BuildPartyAuraPreviewPositions = function(
  host,
  frameDB,
  memberCount,
  zoom,
  insets
)
  zoom = tonumber(zoom) or 1
  memberCount = math_max(1, math_min(5, tonumber(memberCount) or 1))

  local resolvedWidth, resolvedHeight = ns.UFStyle.ResolveFrameSize(frameDB)
  local frameWidth = math_max(
    1,
    math_floor(resolvedWidth * zoom + 0.5)
  )
  local frameHeight = math_max(
    1,
    math_floor(resolvedHeight * zoom + 0.5)
  )
  local spacing = math_max(
    0,
    math_floor((tonumber(frameDB.spacing) or 8) * zoom + 0.5)
  )
  local horizontal = frameDB.orientation == "HORIZONTAL"
  local growsUp = not horizontal and frameDB.growthY == "UP"
  local positions = {}

  for memberIndex = 1, memberCount do
    local offset = memberIndex - 1

    positions[memberIndex] = {
      x = horizontal and offset * (frameWidth + spacing) or 0,
      y = horizontal
        and 0
        or offset * (frameHeight + spacing) * (growsUp and 1 or -1),
    }
  end

  local centered, totalWidth, totalHeight = CenterGroupedAuraPreviewPositions(
    host,
    positions,
    frameWidth,
    frameHeight,
    insets
  )

  return centered, frameWidth, frameHeight, totalWidth, totalHeight
end

BuildRaidAuraPreviewPositions = function(
  host,
  frameDB,
  groupCount,
  membersPerGroup,
  zoom,
  insets
)
  zoom = tonumber(zoom) or 1
  groupCount = math_max(1, math_min(8, tonumber(groupCount) or 1))
  membersPerGroup = math_max(
    1,
    math_min(5, tonumber(membersPerGroup) or 1)
  )

  local frameWidth = math_max(
    1,
    math_floor((tonumber(frameDB.width) or 85) * zoom + 0.5)
  )
  local frameHeight = math_max(
    1,
    math_floor((tonumber(frameDB.height) or 54) * zoom + 0.5)
  )
  local rowSpacing = math_max(
    0,
    math_floor((tonumber(frameDB.rowSpacing) or 3) * zoom + 0.5)
  )
  local columnSpacing = math_max(
    0,
    math_floor((tonumber(frameDB.columnSpacing) or 3) * zoom + 0.5)
  )
  local orientation = ns.UFLayout.GetGroupSortOrientation(frameDB)
  local growthDirection = frameDB.growthDirection or "RIGHT_DOWN"
  local xMultiplier = growthDirection:find("LEFT", 1, true) and -1 or 1
  local yMultiplier = growthDirection:find("UP", 1, true) and 1 or -1
  local lockedGroups = frameDB.lockMembersToGroup ~= false
  local positions = {}

  if lockedGroups then
    local rawGroupSpacing = tonumber(frameDB.groupSpacing)
      or (
        orientation == "VERTICAL"
          and tonumber(frameDB.columnSpacing)
          or tonumber(frameDB.rowSpacing)
      )
      or 3
    local groupSpacing = math_max(
      0,
      math_floor(rawGroupSpacing * zoom + 0.5)
    )
    local groupsPerRowCol = math_max(
      1,
      math_min(groupCount, math_floor(tonumber(frameDB.groupsPerRowCol) or 1))
    )

    for groupIndex = 1, groupCount do
      local groupOffset = groupIndex - 1
      local groupColumn
      local groupRow
      local groupX
      local groupY

      if orientation == "VERTICAL" then
        groupRow = groupOffset % groupsPerRowCol
        groupColumn = math_floor(groupOffset / groupsPerRowCol)
        groupX = groupColumn
          * (frameWidth + columnSpacing + groupSpacing)
          * xMultiplier
        groupY = groupRow
          * (((frameHeight + rowSpacing) * membersPerGroup) + groupSpacing)
          * yMultiplier
      else
        groupColumn = groupOffset % groupsPerRowCol
        groupRow = math_floor(groupOffset / groupsPerRowCol)
        groupX = groupColumn
          * (((frameWidth + columnSpacing) * membersPerGroup) + groupSpacing)
          * xMultiplier
        groupY = groupRow
          * (frameHeight + rowSpacing + groupSpacing)
          * yMultiplier
      end

      for memberIndex = 1, membersPerGroup do
        local memberOffset = memberIndex - 1
        local previewIndex = groupOffset * membersPerGroup + memberIndex

        positions[previewIndex] = {
          x = groupX
            + (orientation == "VERTICAL"
              and 0
              or memberOffset * (frameWidth + columnSpacing) * xMultiplier),
          y = groupY
            + (orientation == "VERTICAL"
              and memberOffset * (frameHeight + rowSpacing) * yMultiplier
              or 0),
          groupIndex = groupIndex,
          groupMemberIndex = memberIndex,
        }
      end
    end
  else
    local outerXMultiplier = xMultiplier
    local outerYMultiplier = yMultiplier

    if frameDB.invertGroupingOrder == true then
      if orientation == "VERTICAL" then
        outerXMultiplier = -outerXMultiplier
      else
        outerYMultiplier = -outerYMultiplier
      end
    end

    for groupIndex = 1, groupCount do
      for memberIndex = 1, membersPerGroup do
        local previewIndex = (groupIndex - 1) * membersPerGroup + memberIndex
        local x
        local y

        if orientation == "VERTICAL" then
          x = (groupIndex - 1)
            * (frameWidth + columnSpacing)
            * outerXMultiplier
          y = (memberIndex - 1)
            * (frameHeight + rowSpacing)
            * yMultiplier
        else
          x = (memberIndex - 1)
            * (frameWidth + columnSpacing)
            * xMultiplier
          y = (groupIndex - 1)
            * (frameHeight + rowSpacing)
            * outerYMultiplier
        end

        positions[previewIndex] = {
          x = x,
          y = y,
          groupIndex = groupIndex,
          groupMemberIndex = memberIndex,
        }
      end
    end
  end

  local centered, totalWidth, totalHeight = CenterGroupedAuraPreviewPositions(
    host,
    positions,
    frameWidth,
    frameHeight,
    insets
  )

  return centered, frameWidth, frameHeight, totalWidth, totalHeight
end



local function StyleAuraPreviewButton(button)
  Theme.WidgetSkins.UIButton(button)
  Theme.ApplyFont(button:GetFontString(), "tiny", 8)
end

local function SetAuraPreviewButtonTooltip(button, title, description)
  button.__puiAuraPreviewTooltipTitle = title
  button.__puiAuraPreviewTooltipDescription = description
  button:SetScript("OnEnter", function(self)
    ShowAuraPreviewTooltip(
      self,
      self.__puiAuraPreviewTooltipTitle,
      self.__puiAuraPreviewTooltipDescription
    )
  end)
  button:SetScript("OnLeave", HideAuraPreviewTooltip)
end

local function LayoutAuraPreviewCreateButtons(box)
  local toolbar = box.__puiAuraCreateToolbar
  local buttons = box.__puiAuraCreateButtons or {}
  local availableWidth = math_max(80, box:GetCanvas():GetWidth() - 16)

  for index, button in ipairs(buttons) do
    local textWidth = math_ceil(button:GetFontString():GetStringWidth())
    local width = math_min(availableWidth, math_max(66, textWidth + 20))

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 0, -((index - 1) * 26))
    button:SetSize(width, 22)
  end

  local buttonCount = #buttons
  local height = buttonCount > 0 and ((buttonCount * 22) + ((buttonCount - 1) * 4)) or 0
  toolbar:SetHeight(height)
  box.__puiAuraCreateToolbarHeight = height
end

local function CreateAuraPreviewEyeLine(button, width, height, xOffset, yOffset, rotation)
  local line = button:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 1)
  line:SetSize(width, height)
  line:SetPoint("CENTER", button, "CENTER", xOffset, yOffset)
  line:SetRotation(rotation)
  return line
end

local function UpdateAuraPreviewVisibilityIcon(button, enabled)
  local color = Theme.GetColors().text

  for _, line in ipairs(button.__puiEyeLines) do
    line:SetColorTexture(color[1], color[2], color[3], enabled and 0.95 or 0.45)
  end

  button.__puiEyePupil:SetColorTexture(color[1], color[2], color[3], enabled and 0.95 or 0.35)
  button.__puiEyeSlash:SetColorTexture(1, 0.25, 0.25, 0.95)
  button.__puiEyeSlash:SetShown(not enabled)
end

local function UpdateAuraPreviewVisibilityButton(box, context, display)
  local button = box.__puiAuraVisibilityButton
  local show = context.supportsAuraManager
    and display
    and display.protected ~= true

  button:SetShown(show == true)

  if not show then
    return
  end

  local enabled = display.enabled ~= false
  button.__puiAuraDisplayID = display.id
  button.__puiAuraDisplayEnabled = enabled
  button.__puiAuraPreviewTooltipTitle = enabled and "Hide aura display" or "Show aura display"
  button.__puiAuraPreviewTooltipDescription = enabled
    and "Disable the selected display without deleting its settings."
    or "Enable the selected display and restore it to the preview."
  UpdateAuraPreviewVisibilityIcon(button, enabled)
end

UpdateAuraPreviewHint = function(box, context, dragDisplay)
  local hint = box.__puiAuraInteractionHint

  if dragDisplay then
    hint:SetText(
      "Dragging "
        .. tostring(dragDisplay.name or "aura display")
        .. ": release near an anchor point to snap."
    )
    hint:SetTextColor(1, 1, 1, 0.85)
    hint:Show()
  elseif context.supportsAuraManager and not context.previewHintSeen then
    hint:SetText("Click an aura to edit it. Click duration, stacks, or a border for exact settings. Drag to reposition.")
    hint:SetTextColor(1, 1, 1, 0.52)
    hint:Show()
  else
    hint:Hide()
  end

  box.__puiAuraInteractionHintHeight = hint:IsShown() and 16 or 0
end

UpdateAuraPreviewSelectionUI = function(box, context)
  local selectedID = box.__puiAuraPreviewSelectedID
  local display = selectedID and context.displays[selectedID]
  local label = box.__puiAuraSelectionLabel

  if display then
    local typeLabel = display.displayType == "slot" and "Aura Slot" or "Aura Group"
    label:SetText("Editing: " .. tostring(display.name or typeLabel) .. "  -  " .. typeLabel)
  elseif context.supportsAuraManager then
    label:SetText("Select an aura display in the preview.")
  else
    label:SetText("Preview follows the selected unit-frame settings.")
  end

  label:SetShown(context.supportsAuraManager)
  UpdateAuraPreviewVisibilityButton(box, context, display)
  UpdateAuraPreviewHint(box, context)
end

local function CreateInlineDensityControl(
  parent,
  labelText,
  minimum,
  maximum,
  onValueChanged,
  onValueCommitted
)
  local colors = Theme.GetColors()
  local control = CreateFrame("Frame", nil, parent)
  local label = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local slider = CreateFrame("Slider", nil, control)
  local valueText = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  control:SetSize(INLINE_DENSITY_CONTROL_WIDTH, INLINE_DENSITY_CONTROL_HEIGHT)
  control:SetFrameLevel(parent:GetFrameLevel() + 105)

  label:SetPoint("LEFT", control, "LEFT", 0, 0)
  label:SetWidth(86)
  label:SetJustifyH("RIGHT")
  label:SetText(labelText)
  Theme.ApplyFont(label, "tiny", 9)

  slider:SetPoint("LEFT", label, "RIGHT", 8, 0)
  slider:SetSize(68, INLINE_DENSITY_CONTROL_HEIGHT)
  slider:SetOrientation("HORIZONTAL")
  slider:SetHitRectInsets(0, 0, -8, -8)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)

  local track = slider:CreateTexture(nil, "ARTWORK")
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(4)
  track:SetColorTexture(
    colors.border[1],
    colors.border[2],
    colors.border[3],
    colors.border[4]
  )

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(10, INLINE_DENSITY_CONTROL_HEIGHT)
  thumb:SetColorTexture(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    colors.accent[4]
  )
  slider:SetThumbTexture(thumb)

  valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  valueText:SetWidth(18)
  valueText:SetJustifyH("LEFT")
  Theme.ApplyFont(valueText, "tiny", 9)

  function control:SetValue(value)
    value = math_max(
      minimum,
      math_min(
        maximum,
        math_floor((tonumber(value) or minimum) + 0.5)
      )
    )
    slider.__puiSyncingValue = true
    slider:SetValue(value)
    slider.__puiSyncingValue = nil
    valueText:SetText(tostring(value))
  end

  slider:SetScript("OnValueChanged", function(self, value)
    value = math_max(minimum, math_min(maximum, math_floor(value + 0.5)))
    valueText:SetText(tostring(value))

    if self.__puiSyncingValue then
      return
    end

    onValueChanged(value)
  end)

  slider:SetScript("OnMouseUp", function(self, mouseButton)
    if mouseButton ~= "LeftButton" or self.__puiSyncingValue then
      return
    end

    onValueCommitted()
  end)

  control.slider = slider
  control.label = label
  control.valueText = valueText
  control:Hide()
  return control
end

local function RefreshInlineGroupedPreview(box)
  if not box.__puiAuraPreviewContext then
    return
  end

  RenderAuraManagerPreview(
    box,
    box.__puiAuraPreviewAddon or ns.Addon,
    box.__puiAuraPreviewPath
  )
end

local function EnsureInlineGroupedPreviewControls(box)
  if box.__puiInlineDensityControls then
    return
  end

  local canvas = box:GetCanvas()
  local density = GetInlineGroupedPreviewDensity(box)
  local controls = {}

  controls.partyMembers = CreateInlineDensityControl(
    canvas,
    "Party members",
    1,
    5,
    function(value)
      density.partyMembers = value
    end,
    function()
      RefreshInlineGroupedPreview(box)
    end
  )

  controls.raidGroups = CreateInlineDensityControl(
    canvas,
    "Raid groups",
    1,
    8,
    function(value)
      density.raidGroups = value
    end,
    function()
      RefreshInlineGroupedPreview(box)
    end
  )

  controls.raidMembers = CreateInlineDensityControl(
    canvas,
    "Members/group",
    1,
    5,
    function(value)
      density.raidMembersPerGroup = value
    end,
    function()
      RefreshInlineGroupedPreview(box)
    end
  )

  box.__puiInlineDensityControls = controls
end

local function SyncInlineGroupedPreviewControls(box, context)
  EnsureInlineGroupedPreviewControls(box)

  local controls = box.__puiInlineDensityControls
  local density = GetInlineGroupedPreviewDensity(box)

  for _, control in pairs(controls) do
    control:Hide()
    control:ClearAllPoints()
  end

  if not context.grouped or context.partyPetPreview then
    return
  end

  if context.unitKey == "raid" then
    controls.raidMembers:SetValue(density.raidMembersPerGroup)
    controls.raidMembers:SetPoint("BOTTOMRIGHT", box:GetCanvas(), "BOTTOMRIGHT", -8, 36)
    controls.raidMembers:Show()

    controls.raidGroups:SetValue(density.raidGroups)
    controls.raidGroups:SetPoint(
      "BOTTOMRIGHT",
      controls.raidMembers,
      "TOPRIGHT",
      0,
      INLINE_DENSITY_CONTROL_GAP
    )
    controls.raidGroups:Show()
  else
    controls.partyMembers:SetValue(density.partyMembers)
    controls.partyMembers:SetPoint("BOTTOMRIGHT", box:GetCanvas(), "BOTTOMRIGHT", -8, 36)
    controls.partyMembers:Show()
  end
end

local function EnsureAuraManagerPreviewControls(box)
  local canvas = box:GetCanvas()

  if not box.__puiAuraCreateToolbar then
    local toolbar = CreateFrame("Frame", nil, canvas)
    toolbar:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -8)
    toolbar:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -8, -8)
    toolbar:SetFrameLevel(canvas:GetFrameLevel() + 100)

    local definitions = {
      {
        label = "Add Buff Slot",
        displayType = "slot",
        auraType = "HELPFUL",
        tooltip = "Create one fixed icon that tracks one Helpful SpellID.",
      },
      {
        label = "Add Buff Group",
        displayType = "group",
        auraType = "HELPFUL",
        tooltip = "Create a flowing row or grid of matching Helpful auras.",
      },
      {
        label = "Add Debuff Slot",
        displayType = "slot",
        auraType = "HARMFUL",
        tooltip = "Create one fixed Harmful icon. Midnight secret aura identity can limit exact live verification.",
      },
      {
        label = "Add Debuff Group",
        displayType = "group",
        auraType = "HARMFUL",
        tooltip = "Create a flowing row or grid of matching Harmful auras.",
      },
    }

    box.__puiAuraCreateToolbar = toolbar
    box.__puiAuraCreateButtons = {}

    for _, definition in ipairs(definitions) do
      local displayType = definition.displayType
      local auraType = definition.auraType
      local button = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")

      button:SetText(definition.label)
      button:SetFrameLevel(toolbar:GetFrameLevel() + 1)
      button:SetScript("OnClick", function()
        local context = box.__puiAuraPreviewContext
        DismissAuraPreviewHint(context)
        Preview.AuraManagerDisplayCreator(context.unitKey, displayType, auraType)
      end)
      StyleAuraPreviewButton(button)
      SetAuraPreviewButtonTooltip(button, definition.label, definition.tooltip)
      box.__puiAuraCreateButtons[#box.__puiAuraCreateButtons + 1] = button
    end

    local selectionLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectionLabel:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
    selectionLabel:SetPoint("RIGHT", canvas, "RIGHT", -38, 0)
    selectionLabel:SetJustifyH("LEFT")
    selectionLabel:SetWordWrap(false)
    Theme.ApplyFont(selectionLabel, "tiny", 9)
    box.__puiAuraSelectionLabel = selectionLabel

    local visibilityButton = CreateFrame("Button", nil, canvas)
    visibilityButton:SetPoint("CENTER", selectionLabel, "RIGHT", 14, 0)
    visibilityButton:SetSize(22, 18)
    visibilityButton:SetFrameLevel(canvas:GetFrameLevel() + 110)
    visibilityButton.__puiEyeLines = {
      CreateAuraPreviewEyeLine(visibilityButton, 8, 1, -3, 2, 0.45),
      CreateAuraPreviewEyeLine(visibilityButton, 8, 1, 3, 2, -0.45),
      CreateAuraPreviewEyeLine(visibilityButton, 8, 1, -3, -2, -0.45),
      CreateAuraPreviewEyeLine(visibilityButton, 8, 1, 3, -2, 0.45),
    }
    visibilityButton.__puiEyePupil = visibilityButton:CreateTexture(nil, "ARTWORK")
    visibilityButton.__puiEyePupil:SetPoint("CENTER")
    visibilityButton.__puiEyePupil:SetSize(3, 3)
    visibilityButton.__puiEyeSlash = CreateAuraPreviewEyeLine(visibilityButton, 18, 2, 0, 0, -0.65)
    visibilityButton:SetScript("OnClick", function(self)
      local context = box.__puiAuraPreviewContext
      DismissAuraPreviewHint(context)
      Preview.AuraManagerVisibilityCommitter(
        context.unitKey,
        self.__puiAuraDisplayID,
        self.__puiAuraDisplayEnabled == false
      )
    end)
    SetAuraPreviewButtonTooltip(visibilityButton, "Aura display visibility", "Show or hide the selected aura display.")
    visibilityButton:Hide()
    box.__puiAuraVisibilityButton = visibilityButton

    local interactionHint = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    interactionHint:SetPoint("TOPLEFT", selectionLabel, "BOTTOMLEFT", 0, -3)
    interactionHint:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -8, 0)
    interactionHint:SetJustifyH("LEFT")
    interactionHint:SetWordWrap(false)
    Theme.ApplyFont(interactionHint, "tiny", 8)
    interactionHint:Hide()
    box.__puiAuraInteractionHint = interactionHint

    canvas:HookScript("OnSizeChanged", function()
      LayoutAuraPreviewCreateButtons(box)
      Preview.RefreshAuraManagerPreview()
    end)
  end

  LayoutAuraPreviewCreateButtons(box)
  EnsureInlineGroupedPreviewControls(box)

  if not box.__puiAuraPreviewZoomControl then
    local zoomControl = ns.PreviewBox.CreateZoomControl(canvas, {
      sliderWidth = 110,
      sliderHeight = 14,
      frameLevel = canvas:GetFrameLevel() + 100,
      onValueChanged = function(_, zoom)
        local context = box.__puiAuraPreviewContext

        context.selectionDB.auraPreviewZoom = zoom
        context.previewZoom = zoom
        box.__puiAuraPreviewZoom = zoom
      end,
      onValueCommitted = function()
        RenderAuraManagerPreview(
          box,
          box.__puiAuraPreviewAddon or ns.Addon,
          box.__puiAuraPreviewPath
        )
      end,
    })

    zoomControl:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 10)
    box.__puiAuraPreviewZoomControl = zoomControl
  end
end

SyncAuraPreviewControls = function(box, context)
  local toolbar = box.__puiAuraCreateToolbar

  toolbar:SetShown(context.supportsAuraManager)

  for _, button in ipairs(box.__puiAuraCreateButtons or {}) do
    button:SetShown(context.supportsAuraManager)
  end

  LayoutAuraPreviewCreateButtons(box)

  box.__puiAuraPreviewZoomControl:Show()
  box.__puiAuraPreviewZoomControl:SetZoom(context.previewZoom)
  box.__puiAuraPreviewZoom = context.previewZoom

  SyncInlineGroupedPreviewControls(box, context)
  UpdateAuraPreviewSelectionUI(box, context)
end

function Preview.BuildUnitFramePreview(addon, optionsFrame, shell, path)
  local previewHost = shell.previewHost
  local box = shell.__puiAuraManagerPreviewBox

  if box then
    if box:GetParent() ~= previewHost then
      box:SetParent(previewHost)
    end
  else
    box = ns.PreviewBox.Create(previewHost)
    shell.__puiAuraManagerPreviewBox = box
  end

  local boxLevel = previewHost:GetFrameLevel() + 1
  local canvas = box:GetCanvas()

  box:SetFrameStrata(previewHost:GetFrameStrata())
  box:SetFrameLevel(boxLevel)

  if box._puiBg then
    box._puiBg:SetFrameStrata(box:GetFrameStrata())
    box._puiBg:SetFrameLevel(math_max(0, boxLevel - 1))
  end

  box:ClearAllPoints()
  box:SetAllPoints(previewHost)
  box:SetTitle("Unit frame preview")
  box:SetDescription("Click frame bars, text, indicators, buffs, or debuffs to open their exact settings. Aura displays remain draggable without triggering navigation.")

  canvas:SetFrameStrata(box:GetFrameStrata())
  canvas:SetFrameLevel(boxLevel + 1)

  if canvas._puiBg then
    canvas._puiBg:SetFrameStrata(canvas:GetFrameStrata())
    canvas._puiBg:SetFrameLevel(boxLevel)
  end

  canvas:SetClipsChildren(true)
  box:Show()

  EnsureAuraManagerPreviewControls(box)

  box.__puiAuraPreviewOptionsFrame = optionsFrame
  RenderAuraManagerPreview(box, addon, path)

  return true
end

function Preview.PLAYER_REGEN_DISABLED()
  local optionsFrame = ns.Addon._OptionsWindow
  local shell = optionsFrame and optionsFrame.__puiPageShell
  local box = shell and shell.__puiAuraManagerPreviewBox

  if box and box.__puiAuraPreviewDragState then
    StopAuraPreviewDrag(box.__puiAuraPreviewDragState.previewDisplay.control, false)
  end
end

CopyPreviewPath = P:Def("CopyPreviewPath", CopyPreviewPath)
CopyPreviewColor = P:Def("CopyPreviewColor", CopyPreviewColor)
ResolveAuraPreviewHealthColor = P:Def("ResolveAuraPreviewHealthColor", ResolveAuraPreviewHealthColor)
ResolveAuraPreviewNameColor = P:Def("ResolveAuraPreviewNameColor", ResolveAuraPreviewNameColor)
CreatePreviewBorder = P:Def("CreatePreviewBorder", CreatePreviewBorder)
SetPreviewBorder = P:Def("SetPreviewBorder", SetPreviewBorder)
EnsureAuraPreviewSelection = P:Def("EnsureAuraPreviewSelection", EnsureAuraPreviewSelection)
SetAuraPreviewSelected = P:Def("SetAuraPreviewSelected", SetAuraPreviewSelected)
ResetAuraPreviewIcon = P:Def("ResetAuraPreviewIcon", ResetAuraPreviewIcon)
BeginAuraPreviewIconPool = P:Def("BeginAuraPreviewIconPool", BeginAuraPreviewIconPool)
AcquireAuraPreviewIcon = P:Def("AcquireAuraPreviewIcon", AcquireAuraPreviewIcon)
UpdateAuraPreviewDurations = P:Def("UpdateAuraPreviewDurations", UpdateAuraPreviewDurations)
EnableAuraPreviewDurationUpdates = P:Def("EnableAuraPreviewDurationUpdates", EnableAuraPreviewDurationUpdates)
IsUnitFrameOverviewPath = P:Def("IsUnitFrameOverviewPath", IsUnitFrameOverviewPath)
GetAuraManagerUnitKey = P:Def("GetAuraManagerUnitKey", GetAuraManagerUnitKey)
Preview.IsUnitFramesOptionsPath = P:Def("Preview:IsUnitFramesOptionsPath", Preview.IsUnitFramesOptionsPath)
Preview.IsAuraManagerOptionsPath = P:Def("Preview:IsAuraManagerOptionsPath", Preview.IsAuraManagerOptionsPath)
GetAuraManagerPathSelection = P:Def("GetAuraManagerPathSelection", GetAuraManagerPathSelection)
GetAuraManagerPreviewContext = P:Def("GetAuraManagerPreviewContext", GetAuraManagerPreviewContext)
GetOrderedAuraDisplays = P:Def("GetOrderedAuraDisplays", GetOrderedAuraDisplays)
GetPreviewAuraSample = P:Def("GetPreviewAuraSample", GetPreviewAuraSample)
BeginAuraPreviewFramePool = P:Def("BeginAuraPreviewFramePool", BeginAuraPreviewFramePool)
BuildUnitFramePreviewOptionsPath = P:Def("BuildUnitFramePreviewOptionsPath", BuildUnitFramePreviewOptionsPath)
NavigateUnitFramePreviewElement = P:Def("NavigateUnitFramePreviewElement", NavigateUnitFramePreviewElement)
CreateUnitFramePreviewTextInteraction = P:Def("CreateUnitFramePreviewTextInteraction", CreateUnitFramePreviewTextInteraction)
CreateUnitFramePreviewInteractions = P:Def("CreateUnitFramePreviewInteractions", CreateUnitFramePreviewInteractions)
ClearUnitFramePreviewInteractionAnchors = P:Def("ClearUnitFramePreviewInteractionAnchors", ClearUnitFramePreviewInteractionAnchors)
LayoutUnitFramePreviewInteractions = P:Def("LayoutUnitFramePreviewInteractions", LayoutUnitFramePreviewInteractions)
SetUnitFramePreviewInteraction = P:Def("SetUnitFramePreviewInteraction", SetUnitFramePreviewInteraction)
ConfigureUnitFramePreviewInteractions = P:Def("ConfigureUnitFramePreviewInteractions", ConfigureUnitFramePreviewInteractions)
AcquireAuraPreviewFrame = P:Def("AcquireAuraPreviewFrame", AcquireAuraPreviewFrame)
BuildAuraPreviewFrame = P:Def("BuildAuraPreviewFrame", BuildAuraPreviewFrame)
BeginUnitFrameOverviewCardPool = P:Def("BeginUnitFrameOverviewCardPool", BeginUnitFrameOverviewCardPool)
AcquireUnitFrameOverviewCard = P:Def("AcquireUnitFrameOverviewCard", AcquireUnitFrameOverviewCard)
HideAuraManagerPreviewControls = P:Def("HideAuraManagerPreviewControls", HideAuraManagerPreviewControls)
RenderUnitFrameOverviewGallery = P:Def("RenderUnitFrameOverviewGallery", RenderUnitFrameOverviewGallery)
GetAuraPreviewAttachTarget = P:Def("GetAuraPreviewAttachTarget", GetAuraPreviewAttachTarget)
BuildAuraManagerDisplayPath = P:Def("BuildAuraManagerDisplayPath", BuildAuraManagerDisplayPath)
ShowAuraPreviewTooltip = P:Def("ShowAuraPreviewTooltip", ShowAuraPreviewTooltip)
HideAuraPreviewTooltip = P:Def("HideAuraPreviewTooltip", HideAuraPreviewTooltip)
DismissAuraPreviewHint = P:Def("DismissAuraPreviewHint", DismissAuraPreviewHint)
AuraManagerOptionPathMatches = P:Def("AuraManagerOptionPathMatches", AuraManagerOptionPathMatches)
FindAuraManagerOptionWidget = P:Def("FindAuraManagerOptionWidget", FindAuraManagerOptionWidget)
ShowAuraManagerOptionGlow = P:Def("ShowAuraManagerOptionGlow", ShowAuraManagerOptionGlow)
FocusAuraManagerOption = P:Def("FocusAuraManagerOption", FocusAuraManagerOption)
NavigateAuraPreviewElement = P:Def("NavigateAuraPreviewElement", NavigateAuraPreviewElement)
GetPreviewAuraState = P:Def("GetPreviewAuraState", GetPreviewAuraState)
CreateAuraPreviewIcon = P:Def("CreateAuraPreviewIcon", CreateAuraPreviewIcon)
ResetAuraPreviewDisplayControl = P:Def("ResetAuraPreviewDisplayControl", ResetAuraPreviewDisplayControl)
BeginAuraPreviewDisplayPool = P:Def("BeginAuraPreviewDisplayPool", BeginAuraPreviewDisplayPool)
AcquireAuraPreviewDisplayControl = P:Def("AcquireAuraPreviewDisplayControl", AcquireAuraPreviewDisplayControl)
CreateAuraPreviewElementButton = P:Def("CreateAuraPreviewElementButton", CreateAuraPreviewElementButton)
ConfigureAuraPreviewElementNavigation = P:Def("ConfigureAuraPreviewElementNavigation", ConfigureAuraPreviewElementNavigation)
GetAnchorRelativeBounds = P:Def("GetAnchorRelativeBounds", GetAnchorRelativeBounds)
PositionAuraPreviewDisplay = P:Def("PositionAuraPreviewDisplay", PositionAuraPreviewDisplay)
GetRegionAnchorOffset = P:Def("GetRegionAnchorOffset", GetRegionAnchorOffset)
EnsureAuraPreviewDragAnchors = P:Def("EnsureAuraPreviewDragAnchors", EnsureAuraPreviewDragAnchors)
HideAuraPreviewDragAnchors = P:Def("HideAuraPreviewDragAnchors", HideAuraPreviewDragAnchors)
ShowAuraPreviewDragAnchors = P:Def("ShowAuraPreviewDragAnchors", ShowAuraPreviewDragAnchors)
UpdateAuraPreviewDropAnchor = P:Def("UpdateAuraPreviewDropAnchor", UpdateAuraPreviewDropAnchor)
UpdateAuraPreviewDrag = P:Def("UpdateAuraPreviewDrag", UpdateAuraPreviewDrag)
StartAuraPreviewDrag = P:Def("StartAuraPreviewDrag", StartAuraPreviewDrag)
StopAuraPreviewDrag = P:Def("StopAuraPreviewDrag", StopAuraPreviewDrag)
BuildAuraPreviewDisplay = P:Def("BuildAuraPreviewDisplay", BuildAuraPreviewDisplay)
ApplyAuraManagerPreviewSelection = P:Def("ApplyAuraManagerPreviewSelection", ApplyAuraManagerPreviewSelection)
UpdateUnitFramePreviewMode = P:Def("UpdateUnitFramePreviewMode", UpdateUnitFramePreviewMode)
RenderAuraManagerPreview = P:Def("RenderAuraManagerPreview", RenderAuraManagerPreview)
Preview.HandleUnitFrameOptionsPathChanged = P:Def("Preview:HandleUnitFrameOptionsPathChanged", Preview.HandleUnitFrameOptionsPathChanged)
Preview.RefreshAuraManagerPreview = P:Def("Preview:RefreshAuraManagerPreview", Preview.RefreshAuraManagerPreview)
Preview.RegisterAuraManagerDisplayCreator = P:Def("Preview:RegisterAuraManagerDisplayCreator", Preview.RegisterAuraManagerDisplayCreator)
Preview.RegisterAuraManagerVisibilityCommitter = P:Def("Preview:RegisterAuraManagerVisibilityCommitter", Preview.RegisterAuraManagerVisibilityCommitter)
Preview.RegisterAuraManagerPositionCommitter = P:Def("Preview:RegisterAuraManagerPositionCommitter", Preview.RegisterAuraManagerPositionCommitter)
CopyAuraPreviewContext = P:Def("CopyAuraPreviewContext", CopyAuraPreviewContext)
GetInlineGroupedPreviewDensity = P:Def("GetInlineGroupedPreviewDensity", GetInlineGroupedPreviewDensity)
GetInlineGroupedPreviewInsets = P:Def("GetInlineGroupedPreviewInsets", GetInlineGroupedPreviewInsets)
GetInlineGroupedPreviewScale = P:Def("GetInlineGroupedPreviewScale", GetInlineGroupedPreviewScale)
RenderInlineGroupedPreview = P:Def("RenderInlineGroupedPreview", RenderInlineGroupedPreview)
CenterGroupedAuraPreviewPositions = P:Def("CenterGroupedAuraPreviewPositions", CenterGroupedAuraPreviewPositions)
BuildPartyAuraPreviewPositions = P:Def("BuildPartyAuraPreviewPositions", BuildPartyAuraPreviewPositions)
BuildRaidAuraPreviewPositions = P:Def("BuildRaidAuraPreviewPositions", BuildRaidAuraPreviewPositions)
StyleAuraPreviewButton = P:Def("StyleAuraPreviewButton", StyleAuraPreviewButton)
SetAuraPreviewButtonTooltip = P:Def("SetAuraPreviewButtonTooltip", SetAuraPreviewButtonTooltip)
LayoutAuraPreviewCreateButtons = P:Def("LayoutAuraPreviewCreateButtons", LayoutAuraPreviewCreateButtons)
CreateAuraPreviewEyeLine = P:Def("CreateAuraPreviewEyeLine", CreateAuraPreviewEyeLine)
UpdateAuraPreviewVisibilityIcon = P:Def("UpdateAuraPreviewVisibilityIcon", UpdateAuraPreviewVisibilityIcon)
UpdateAuraPreviewVisibilityButton = P:Def("UpdateAuraPreviewVisibilityButton", UpdateAuraPreviewVisibilityButton)
UpdateAuraPreviewHint = P:Def("UpdateAuraPreviewHint", UpdateAuraPreviewHint)
UpdateAuraPreviewSelectionUI = P:Def("UpdateAuraPreviewSelectionUI", UpdateAuraPreviewSelectionUI)
CreateInlineDensityControl = P:Def("CreateInlineDensityControl", CreateInlineDensityControl)
RefreshInlineGroupedPreview = P:Def("RefreshInlineGroupedPreview", RefreshInlineGroupedPreview)
EnsureInlineGroupedPreviewControls = P:Def("EnsureInlineGroupedPreviewControls", EnsureInlineGroupedPreviewControls)
SyncInlineGroupedPreviewControls = P:Def("SyncInlineGroupedPreviewControls", SyncInlineGroupedPreviewControls)
EnsureAuraManagerPreviewControls = P:Def("EnsureAuraManagerPreviewControls", EnsureAuraManagerPreviewControls)
SyncAuraPreviewControls = P:Def("SyncAuraPreviewControls", SyncAuraPreviewControls)
Preview.BuildUnitFramePreview = P:Def("Preview:BuildUnitFramePreview", Preview.BuildUnitFramePreview)
Preview.PLAYER_REGEN_DISABLED = P:Def("Preview:PLAYER_REGEN_DISABLED", Preview.PLAYER_REGEN_DISABLED)

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:SetScript("OnEvent", function()
  Preview.PLAYER_REGEN_DISABLED()
end)
