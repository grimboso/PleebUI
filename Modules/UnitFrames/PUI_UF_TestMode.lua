local _, ns = ...

local TestMode = ns.TestMode
local Presentation = ns.Presentation
local UFStyle = ns.UFStyle
local UFHealPrediction = ns.UFHealPrediction
local UF = ns.Modules.UnitFrames
local PartyFrames = ns.Modules.PartyFrames
local RaidFrames = ns.Modules.RaidFrames
local CastBar = ns.Modules.CastBar
local AuraLayout = ns.UFAuraLayout
local Theme = ns.Theme
local Inspector = ns.UFTestInspector

local AuraUtil = _G.AuraUtil
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UIParent = _G.UIParent
local ipairs = _G.ipairs
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local math_sin = _G.math.sin
local next = _G.next
local pairs = _G.pairs
local sort = _G.table.sort
local tonumber = _G.tonumber
local type = _G.type
local wipe = _G.wipe

local PARTICIPANT_KEY = "unitframes"
local UPDATE_INTERVAL = 0.1

local PERCENT_TEXT = {}
for value = 0, 100 do
  PERCENT_TEXT[value] = value .. "%"
end

local TEST_CLASS_TOKENS = {
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

local TEST_ACTIVITY_VALUES = {
  { value = "MIXED", label = "Mixed" },
  { value = "DAMAGE", label = "Damage" },
  { value = "HEALING", label = "Healing" },
  { value = "AURAS", label = "Auras" },
  { value = "CASTING", label = "Casting" },
}

local TEST_ROLE_ATLASES = {
  "UI-LFG-RoleIcon-Tank-Micro-Raid",
  "UI-LFG-RoleIcon-Healer-Micro-Raid",
  "UI-LFG-RoleIcon-DPS-Micro-Raid",
}

local TEST_STATUS_ATLASES = {
  "UI-LFG-ReadyMark-Raid",
  "RaidFrame-Icon-SummonPending",
  "RaidFrame-Icon-Rez",
}

local TEST_HELPFUL_TEXTURES = {
  "Interface\\Icons\\Spell_Holy_PowerWordShield",
  "Interface\\Icons\\Spell_Nature_Rejuvenation",
  "Interface\\Icons\\Spell_Holy_Renew",
  "Interface\\Icons\\Spell_Nature_Riptide",
}

local TEST_HARMFUL_TEXTURES = {
  "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
  "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
  "Interface\\Icons\\Spell_Nature_NullifyPoison",
  "Interface\\Icons\\Spell_DeathKnight_FrostFever",
}


local TEST_PARTY_DISPEL_TYPES = {
  "Curse",
  "Poison",
}

local TEST_RAID_DISPEL_TYPES = {
  "Magic",
  "Curse",
  "Disease",
  "Poison",
  "Bleed",
  "Magic",
}

local TEST_THREAT_COLORS = {
  { 1.00, 0.82, 0.00, 0.95 },
  { 1.00, 0.48, 0.00, 0.95 },
  { 1.00, 0.08, 0.08, 0.95 },
}


local SINGLE_FAMILIES = {
  {
    control = "uf.player",
    units = { "player", "pet" },
    names = { "Player", "Pet" },
  },
  {
    control = "uf.target",
    units = { "target", "targettarget" },
    names = { "Target", "Target's target" },
  },
  {
    control = "uf.focus",
    units = { "focus", "focustarget" },
    names = { "Focus", "Focus target" },
  },
  {
    control = "uf.boss",
    units = { "boss1", "boss2", "boss3", "boss4", "boss5" },
    names = { "Boss 1", "Boss 2", "Boss 3", "Boss 4", "Boss 5" },
  },
}

local UnitFrameTest = {
  activeFrames = {},
  presentationFrames = {
    single = {},
    party = {},
    partyPets = {},
    raid = {},
    raidGroups = {},
  },
  partyLayoutActive = false,
  raidLayoutActive = false,
  castbarUnits = {},
  auraDisplayCache = {},
  activity = "MIXED",
  elapsed = 0,
  animationTime = 0,
}
ns.UnitFrameTest = UnitFrameTest

function UnitFrameTest:GetQuickSettingsFrame(moverKey)
  local requestedUnit = type(moverKey) == "string" and moverKey:match("^UF_(.+)$") or nil
  local fallback

  for frame, sample in pairs(self.activeFrames) do
    if frame:IsShown() then
      local matchesMover = moverKey == "PartyFrames" and sample.groupKind == "party" and not sample.isPet
        or moverKey == "RaidFrames" and sample.groupKind == "raid"
        or requestedUnit and sample.unit == requestedUnit

      if matchesMover then
        if frame:IsMouseOver() then
          return frame
        end
        fallback = fallback or frame
      end
    end
  end

  return fallback
end

function UnitFrameTest:OpenQuickSettings(moverKey)
  local frame = self:GetQuickSettingsFrame(moverKey)
  if frame then
    return Inspector:BuildFrameSpec(frame)
  end
end

local function SetColor(target, source, fallback)
  source = source or fallback
  fallback = fallback or { 1, 1, 1, 1 }

  target[1] = source and (source[1] or source.r) or fallback[1]
  target[2] = source and (source[2] or source.g) or fallback[2]
  target[3] = source and (source[3] or source.b) or fallback[3]
  target[4] = source and (source[4] or source.a) or fallback[4] or 1
end

local function CreateTestBorder(parent)
  local border = CreateFrame("Frame", nil, parent)
  border:SetAllPoints(parent)
  border:EnableMouse(false)
  border:Hide()

  border.top = border:CreateTexture(nil, "OVERLAY")
  border.bottom = border:CreateTexture(nil, "OVERLAY")
  border.left = border:CreateTexture(nil, "OVERLAY")
  border.right = border:CreateTexture(nil, "OVERLAY")

  return border
end

local function SetTestBorder(border, color, edge)
  edge = math_max(1, math_floor((tonumber(edge) or 1) + 0.5))
  local r = color[1] or color.r or 1
  local g = color[2] or color.g or 1
  local b = color[3] or color.b or 1
  local a = color[4] or color.a or 1

  border.top:ClearAllPoints()
  border.top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
  border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
  border.top:SetHeight(edge)

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
  border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
  border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
  border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
  border.right:SetWidth(edge)

  for _, texture in ipairs({
    border.top,
    border.bottom,
    border.left,
    border.right,
  }) do
    texture:SetColorTexture(r, g, b, a)
  end

  border:Show()
end

local function CreateTestAuraIcon(parent)
  local icon = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Theme.SetSquareBackdrop(icon, {
    bg = { 0.04, 0.04, 0.04, 0.95 },
    border = { 0, 0, 0, 1 },
  }, 1)

  local texture = icon:CreateTexture(nil, "ARTWORK")
  texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
  texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon.texture = texture

  local duration = icon:CreateFontString(nil, "OVERLAY")
  duration:SetPoint("CENTER", icon, "CENTER", 0, 0)
  Theme.ApplyFont(duration, "tiny", 9, "OUTLINE")
  icon.duration = duration

  local count = icon:CreateFontString(nil, "OVERLAY")
  count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  Theme.ApplyFont(count, "tiny", 8, "OUTLINE")
  icon.count = count

  icon:Hide()
  return icon
end

local function CreateTestHealthSegment(parent, frameLevel)
  local segment = CreateFrame("StatusBar", nil, parent)
  segment:SetMinMaxValues(0, 1)
  segment:SetValue(1)
  segment:SetFrameLevel(frameLevel)
  segment:Hide()
  return segment
end

local function EnsureTestVisuals(frame)
  local visuals = frame.__puiTestScenarioVisuals
  if visuals then
    visuals.root:SetFrameLevel(frame:GetFrameLevel() + 80)
    return visuals
  end

  local root = CreateFrame("Frame", nil, frame)
  root:SetAllPoints(frame)
  root:SetFrameLevel(frame:GetFrameLevel() + 80)
  root:EnableMouse(false)

  local role = root:CreateTexture(nil, "OVERLAY")
  role:Hide()

  local status = root:CreateTexture(nil, "OVERLAY")
  status:Hide()

  local dispelFill = frame.Health:CreateTexture(nil, "ARTWORK", nil, 1)
  dispelFill:SetAllPoints(frame.Health:GetStatusBarTexture())
  dispelFill:SetBlendMode("BLEND")
  dispelFill:Hide()

  local dispelBorder = CreateTestBorder(root)
  dispelBorder:SetFrameLevel(root:GetFrameLevel() + 3)

  local dispelBlizzard = root:CreateTexture(nil, "OVERLAY", nil, 4)
  dispelBlizzard:Hide()

  local threat = CreateTestBorder(root)
  threat:SetFrameLevel(root:GetFrameLevel() + 1)

  local target = CreateTestBorder(root)
  target:SetFrameLevel(root:GetFrameLevel() + 2)

  local healthLevel = frame.Health:GetFrameLevel()
  local prediction = CreateTestHealthSegment(frame.Health, healthLevel + 1)
  local healingOther = CreateTestHealthSegment(frame.Health, healthLevel + 2)
  local absorb = CreateTestHealthSegment(frame.Health, healthLevel + 3)
  local healAbsorb = CreateTestHealthSegment(frame.Health, healthLevel + 4)

  visuals = {
    root = root,
    role = role,
    status = status,
    dispelFill = dispelFill,
    dispelBorder = dispelBorder,
    dispelBlizzard = dispelBlizzard,
    threat = threat,
    target = target,
    prediction = prediction,
    healingOther = healingOther,
    absorb = absorb,
    healAbsorb = healAbsorb,
    auraHolders = {},
    auraIcons = {},
  }

  frame.__puiTestScenarioVisuals = visuals
  return visuals
end

local function HideTestVisuals(frame)
  local visuals = frame and frame.__puiTestScenarioVisuals
  if not visuals then
    return
  end

  visuals.root:Hide()
  visuals.role:Hide()
  visuals.status:Hide()
  visuals.dispelFill:Hide()
  visuals.dispelBorder:Hide()
  visuals.dispelBlizzard:Hide()
  visuals.threat:Hide()
  visuals.target:Hide()
  visuals.prediction:Hide()
  visuals.healingOther:Hide()
  visuals.absorb:Hide()
  visuals.healAbsorb:Hide()

  for _, holder in pairs(visuals.auraHolders) do
    holder:Hide()
  end

  for _, icon in ipairs(visuals.auraIcons) do
    icon:Hide()
  end
end

local function AcquireTestAuraHolder(visuals, displayID)
  local holder = visuals.auraHolders[displayID]
  if holder then
    return holder
  end

  holder = CreateFrame("Frame", nil, visuals.root)
  holder:SetSize(1, 1)
  holder:EnableMouse(false)
  holder:Hide()
  visuals.auraHolders[displayID] = holder
  return holder
end

local function AcquireTestAuraIcon(visuals, index, parent)
  local icon = visuals.auraIcons[index]

  if not icon then
    icon = CreateTestAuraIcon(parent or visuals.root)
    visuals.auraIcons[index] = icon
  end

  icon:SetParent(parent or visuals.root)
  icon:Show()
  return icon
end

local function GetTestAuraDB(frame, sample)
  local cfg = frame.config
  local filters = ns.UFAuraFilters

  if type(cfg) ~= "table" then
    return nil
  end

  if sample.groupKind then
    return filters.BuildGroupedAuraDB(
      sample.groupKind,
      sample.db or cfg,
      sample.unit or frame.unit
    )
  end

  return filters.BuildFrameAuraDB(frame, sample.unit or frame.unit)
end

local function GetSortedTestDisplays(auraDB)
  if type(auraDB) ~= "table" then
    return nil
  end

  local normalized = ns.UFAuraFilters.NormalizeDisplays(auraDB)
  local displays = {}

  for _, display in pairs(normalized or {}) do
    displays[#displays + 1] = display
  end

  sort(displays, function(left, right)
    local leftOrder = tonumber(left.order) or 0
    local rightOrder = tonumber(right.order) or 0

    if leftOrder == rightOrder then
      return (tonumber(left.id) or 0) < (tonumber(right.id) or 0)
    end

    return leftOrder < rightOrder
  end)

  return displays
end

local function GetTestAuraCount(activity, display, sampleIndex, maximum)
  if activity == "CASTING" then
    return 0
  elseif activity == "DAMAGE" and display.auraType ~= "HARMFUL" then
    return 0
  elseif activity == "HEALING" and display.auraType ~= "HELPFUL" then
    return 0
  end

  maximum = AuraLayout.GetSyntheticDisplayIconCount(display, maximum)
  if maximum == 0 then
    return 0
  end

  if activity == "AURAS" then
    return math_min(maximum, display.displayType == "slot" and 1 or 8)
  elseif activity == "DAMAGE" or activity == "HEALING" then
    return math_min(maximum, display.displayType == "slot" and 1 or 2)
  end

  return math_min(maximum, display.displayType == "slot" and 1 or 1 + (sampleIndex % 2))
end

local function ApplyTestAuras(frame, sample, activity, visuals, auraDisplayCache)
  for _, icon in ipairs(visuals.auraIcons) do
    icon:Hide()
  end

  for _, holder in pairs(visuals.auraHolders) do
    holder:Hide()
  end

  local cacheKey
  if sample.groupKind then
    cacheKey = sample.groupKind .. (sample.isPet and ":pet" or ":main")
  else
    cacheKey = sample.unit or frame.unit
  end

  local displays = auraDisplayCache[cacheKey]
  if displays == nil then
    local auraDB = GetTestAuraDB(frame, sample)
    displays = auraDB and auraDB.enabled ~= false
      and GetSortedTestDisplays(auraDB)
      or false
    auraDisplayCache[cacheKey] = displays
  end

  if displays == false then
    displays = nil
  end

  local iconIndex = 0

  for displayIndex, display in ipairs(displays or {}) do
    if display.enabled ~= false then
      local metrics = AuraLayout.ResolveDisplayMetrics(
        frame:GetWidth(),
        frame.Health:GetHeight(),
        1,
        sample.groupKind == "party" or sample.groupKind == "raid",
        display
      )
      local shown = GetTestAuraCount(
        activity,
        display,
        sample.index + displayIndex,
        metrics.maxIcons
      )
      local centeredX, centeredY = AuraLayout.GetSyntheticDisplayAnchorOffset(
        metrics,
        display,
        display.anchorPoint,
        shown
      )
      local baseX = (tonumber(display.xOffset) or 0) + centeredX
      local baseY = (tonumber(display.yOffset) or 0) + centeredY
      local target = AuraLayout.ResolveAttachTarget(frame, display.attachTo) or frame
      local anchorPoint = display.anchorPoint or "TOPLEFT"
      local relativePoint = display.relativePoint or anchorPoint
      local holder = AcquireTestAuraHolder(visuals, display.id)

      holder:ClearAllPoints()
      holder:SetPoint(anchorPoint, target, relativePoint, baseX, baseY)
      holder:Show()

      for auraIndex = 1, shown do
        iconIndex = iconIndex + 1
        local icon = AcquireTestAuraIcon(visuals, iconIndex, holder)
        local iconX, iconY = AuraLayout.GetIconOffset(metrics, auraIndex)
        local textures = display.auraType == "HARMFUL"
          and TEST_HARMFUL_TEXTURES
          or TEST_HELPFUL_TEXTURES

        icon:ClearAllPoints()
        icon:SetPoint(anchorPoint, holder, anchorPoint, iconX, iconY)
        icon:SetSize(metrics.size, metrics.size)
        icon.texture:SetTexture(
          textures[((sample.index + displayIndex + auraIndex - 2) % #textures) + 1]
        )
        icon.duration:SetText(tostring(5 + ((sample.index + auraIndex) % 13)))
        icon.count:SetText((sample.index + auraIndex) % 4 == 0 and "2" or "")
        Inspector:AttachAura(icon, frame, {
          displayID = display.id,
          display = display,
          name = display.name,
        })
      end
    end
  end


end

local function GetTestVisualConfig(frame, sample)
  if sample.groupKind and type(sample.db) == "table" then
    return sample.db
  end

  return frame.config or {}
end

local function GetTestDispelType(sample)
  if sample.isPet or not sample.groupMemberIndex then
    return nil
  end

  if sample.groupKind == "party" then
    return TEST_PARTY_DISPEL_TYPES[sample.groupMemberIndex]
  elseif sample.groupKind == "raid" then
    return TEST_RAID_DISPEL_TYPES[sample.groupMemberIndex]
  end
end

local function GetTestDispelHighlightConfig(frame, sample)
  local cfg = GetTestVisualConfig(frame, sample)
  local highlight = cfg.debuffHighlight
  local mode = cfg.debuffHighlighting or "NONE"
  local dispelType = GetTestDispelType(sample)

  if not dispelType
    or type(highlight) ~= "table"
    or (mode == "NONE" and highlight.blizzardIndicator ~= true)
  then
    return nil
  end

  return dispelType, highlight, mode, cfg
end

local function ApplyTestDispelHighlight(frame, sample, visuals)
  local dispelType, highlight, mode, cfg = GetTestDispelHighlightConfig(frame, sample)

  visuals.dispelFill:Hide()
  visuals.dispelBorder:Hide()
  visuals.dispelBlizzard:Hide()

  if not dispelType then
    return
  end

  local color = AuraUtil.GetAuraBorderColor(dispelType)

  if cfg.hideHealth ~= true and (mode == "FILL" or mode == "BOTH") then
    local healthTexture = frame.Health:GetStatusBarTexture()
    visuals.dispelFill:SetTexture(healthTexture:GetTexture())
    visuals.dispelFill:SetVertexColor(color:GetRGBA())
    visuals.dispelFill:Show()
  end

  local borderSize = tonumber(highlight.borderSize) or 3
  if (mode == "GLOW" or mode == "BOTH") and borderSize > 0 then
    SetTestBorder(visuals.dispelBorder, color, borderSize)
  end

  if highlight.blizzardIndicator == true then
    local size = math_max(8, tonumber(highlight.blizzardIndicatorSize) or 18)
    local position = highlight.blizzardIndicatorPosition or "TOPRIGHT"
    local xOffset = tonumber(highlight.blizzardIndicatorXOffset) or 0
    local yOffset = tonumber(highlight.blizzardIndicatorYOffset) or 0
    visuals.dispelBlizzard:ClearAllPoints()
    visuals.dispelBlizzard:SetPoint(position, frame, position, xOffset, yOffset)
    visuals.dispelBlizzard:SetSize(size, size)
    visuals.dispelBlizzard:SetAtlas(
      ns.UFAuraHighlight.GetPreviewDispelIconAtlas(dispelType),
      false
    )
    visuals.dispelBlizzard:Show()
  end
end

local function ApplyTestRoleAndStatus(frame, sample, activity, visuals)
  local cfg = GetTestVisualConfig(frame, sample)
  local grouped = sample.groupKind == "party" or sample.groupKind == "raid"
  local isPet = sample.isPet == true

  visuals.role:Hide()
  visuals.status:Hide()

  if not grouped or isPet then
    return
  end

  if cfg.showRoleIcon ~= false then
    local roleSize = math_max(8, tonumber(cfg.roleIconSize) or 17)
    local rolePoint = cfg.roleIconPosition or "TOPLEFT"

    visuals.role:ClearAllPoints()
    visuals.role:SetPoint(
      rolePoint,
      frame,
      rolePoint,
      tonumber(cfg.roleIconXOffset) or 0,
      tonumber(cfg.roleIconYOffset) or 0
    )
    visuals.role:SetSize(roleSize, roleSize)
    visuals.role:SetAtlas(
      TEST_ROLE_ATLASES[((sample.index - 1) % #TEST_ROLE_ATLASES) + 1],
      false
    )
    visuals.role:Show()
  end

  if activity == "CASTING" then
    return
  end

  local statusIndex = ((sample.index - 1) % #TEST_STATUS_ATLASES) + 1
  local statusAllowed = statusIndex == 1 and cfg.showReadyCheck ~= false
    or statusIndex == 2 and cfg.showSummon ~= false
    or statusIndex == 3 and cfg.showCombatRes ~= false

  if statusAllowed then
    local statusSize = math_max(8, tonumber(cfg.statusIconSize) or 18)

    visuals.status:ClearAllPoints()
    visuals.status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    visuals.status:SetSize(statusSize, statusSize)
    visuals.status:SetAtlas(TEST_STATUS_ATLASES[statusIndex], false)
    visuals.status:Show()
  end
end

local function ApplyTestBorders(frame, sample, activity, visuals)
  local cfg = GetTestVisualConfig(frame, sample)
  local threatConfig = type(cfg.threatIndicator) == "table"
    and cfg.threatIndicator
    or nil
  local grouped = sample.groupKind == "party" or sample.groupKind == "raid"
  local threatLevel = 0

  visuals.threat:Hide()
  visuals.target:Hide()

  if grouped
    and threatConfig
    and threatConfig.enabled ~= false
    and (activity == "MIXED" or activity == "DAMAGE")
  then
    threatLevel = ((sample.index - 1) % 4)
  end

  if threatLevel > 0 then
    SetTestBorder(
      visuals.threat,
      TEST_THREAT_COLORS[math_min(#TEST_THREAT_COLORS, threatLevel)],
      tonumber(threatConfig.borderSize) or 3
    )
  end

  local profile = UF.db and UF.db.profile
  local targetEdge = tonumber(profile and profile.targetHighlightBorderSize) or 3
  local targetShown = activity == "CASTING"
    or activity == "DAMAGE" and sample.index % 3 == 0
    or activity == "MIXED" and sample.index % 5 == 0

  if targetShown and targetEdge > 0 then
    SetTestBorder(visuals.target, { 1, 1, 1, 0.95 }, targetEdge)
  end
end

local function AnchorTestHealthSegment(texture, health, statusTexture, fraction, afterFill)
  local horizontal = health:GetOrientation() ~= "VERTICAL"
  local reverseFill = health:GetReverseFill()

  texture:ClearAllPoints()

  if horizontal then
    texture:SetPoint("TOP", health, "TOP", 0, 0)
    texture:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    texture:SetWidth(math_max(1, health:GetWidth() * fraction))

    if afterFill then
      texture:SetPoint(
        reverseFill and "RIGHT" or "LEFT",
        statusTexture,
        reverseFill and "LEFT" or "RIGHT",
        0,
        0
      )
    else
      texture:SetPoint(
        reverseFill and "LEFT" or "RIGHT",
        statusTexture,
        reverseFill and "LEFT" or "RIGHT",
        0,
        0
      )
    end
  else
    texture:SetPoint("LEFT", health, "LEFT", 0, 0)
    texture:SetPoint("RIGHT", health, "RIGHT", 0, 0)
    texture:SetHeight(math_max(1, health:GetHeight() * fraction))

    if afterFill then
      texture:SetPoint(
        reverseFill and "TOP" or "BOTTOM",
        statusTexture,
        reverseFill and "BOTTOM" or "TOP",
        0,
        0
      )
    else
      texture:SetPoint(
        reverseFill and "BOTTOM" or "TOP",
        statusTexture,
        reverseFill and "BOTTOM" or "TOP",
        0,
        0
      )
    end
  end
end

local function ConfigureTestHealthSegment(
  segment,
  health,
  texture,
  color,
  reverseFill,
  frameLevel
)
  segment:SetFrameStrata(health:GetFrameStrata())
  segment:SetFrameLevel(frameLevel)
  segment:SetOrientation(health:GetOrientation())
  segment:SetReverseFill(reverseFill)
  UFHealPrediction.ConfigurePredictionTexture(segment, texture)
  segment:SetStatusBarColor(color[1], color[2], color[3], color[4])
end


local function ApplyTestHealthOverlay(frame, sample, activity, visuals)
  local health = frame.Health
  local healthTexture = health and health:GetStatusBarTexture()

  visuals.prediction:Hide()
  visuals.healingOther:Hide()
  visuals.absorb:Hide()
  visuals.healAbsorb:Hide()

  if not health or not healthTexture then
    return
  end

  local config = GetTestVisualConfig(frame, sample)
  local unit = sample.unit or frame.unit
  local predictionTexture = UFStyle.ResolveStatusbarTexture("absorb", unit, config)
  local profile = UF.db.profile
  local settings = profile.healthPrediction
  local colors = profile.colors
  local reverseFill = health:GetReverseFill()
  local baseLevel = health:GetFrameLevel()

  if settings.incomingHeals ~= false then
    ConfigureTestHealthSegment(
      visuals.prediction,
      health,
      predictionTexture,
      colors.healthIncomingPlayer,
      reverseFill,
      baseLevel + 1
    )
    ConfigureTestHealthSegment(
      visuals.healingOther,
      health,
      predictionTexture,
      colors.healthIncomingOther,
      reverseFill,
      baseLevel + 2
    )
  end
  if settings.damageAbsorbs ~= false then
    ConfigureTestHealthSegment(
      visuals.absorb,
      health,
      predictionTexture,
      colors.healthAbsorb,
      not reverseFill,
      baseLevel + 3
    )
  end
  if settings.healAbsorbs ~= false then
    ConfigureTestHealthSegment(
      visuals.healAbsorb,
      health,
      predictionTexture,
      colors.healthHealAbsorb,
      not reverseFill,
      baseLevel + 4
    )
  end

  if (activity == "HEALING" or activity == "MIXED")
    and settings.incomingHeals ~= false
  then
    AnchorTestHealthSegment(visuals.prediction, health, healthTexture, 0.09, true)
    visuals.prediction:Show()

    AnchorTestHealthSegment(
      visuals.healingOther,
      health,
      visuals.prediction:GetStatusBarTexture(),
      0.07,
      true
    )
    visuals.healingOther:Show()
  end
  if (activity == "HEALING" or activity == "MIXED")
    and settings.damageAbsorbs ~= false
  then
    AnchorTestHealthSegment(
      visuals.absorb,
      health,
      healthTexture,
      0.35,
      false
    )
    visuals.absorb:Show()
  end

  if (activity == "DAMAGE" or activity == "MIXED")
    and settings.healAbsorbs ~= false
  then
    AnchorTestHealthSegment(
      visuals.healAbsorb,
      health,
      healthTexture,
      0.10,
      false
    )
    visuals.healAbsorb:Show()
  end
end

local function ApplyTestScenario(frame, sample, activity, auraDisplayCache)
  local visuals = EnsureTestVisuals(frame)

  visuals.root:SetFrameLevel(frame:GetFrameLevel() + 80)
  visuals.root:Show()

  ApplyTestRoleAndStatus(frame, sample, activity, visuals)
  ApplyTestDispelHighlight(frame, sample, visuals)
  ApplyTestBorders(frame, sample, activity, visuals)
  ApplyTestHealthOverlay(frame, sample, activity, visuals)
  ApplyTestAuras(frame, sample, activity, visuals, auraDisplayCache)
end

local function ApplyActivityToFrames(context)
  local activity = context:GetValue("uf.activity") or "MIXED"
  local auraDisplayCache = UnitFrameTest.auraDisplayCache

  UnitFrameTest.activity = activity
  wipe(auraDisplayCache)

  for frame, sample in pairs(UnitFrameTest.activeFrames) do
    ApplyTestScenario(frame, sample, activity, auraDisplayCache)
  end
end

local function SetSyntheticValues(frame, sample)
  local phase = UnitFrameTest.animationTime + (sample.index * 0.67)
  local cycle = ((UnitFrameTest.animationTime * 0.16) + (sample.index * 0.13)) % 1
  local activity = UnitFrameTest.activity
  local health
  local power

  if activity == "DAMAGE" then
    health = math_floor(94 - cycle * 69 + 0.5)
    power = math_floor(74 - cycle * 38 + 0.5)
  elseif activity == "HEALING" then
    health = math_floor(24 + cycle * 54 + 0.5)
    power = math_floor(88 - cycle * 48 + 0.5)
  elseif activity == "AURAS" then
    health = 58 + ((sample.index * 9) % 35)
    power = 42 + ((sample.index * 11) % 49)
  elseif activity == "CASTING" then
    health = 88
    power = math_floor(66 + math_sin(phase * 0.38) * 22 + 0.5)
  else
    health = math_floor(62 + (math_sin(phase * 0.72) * 22) + 0.5)
    power = math_floor(50 + (math_sin((phase * 0.43) + 1.4) * 36) + 0.5)
  end

  frame.__puiPreviewHealth = health
  frame.__puiPreviewHealthMax = 100
  frame.__puiPreviewPower = power
  frame.__puiPreviewPowerMin = 0
  frame.__puiPreviewPowerMax = 100

  if frame.Health then
    frame.Health:SetMinMaxValues(0, 100)
    frame.Health:SetValue(health)
  end

  if frame.Power then
    frame.Power:SetMinMaxValues(0, 100)
    frame.Power:SetValue(power)
  end

  if frame.NameText then
    frame.NameText:SetText(sample.name)
  end

  if frame.HealthText then
    frame.HealthText:SetText(PERCENT_TEXT[health])
  end

  if frame.PowerText then
    frame.PowerText:SetText(PERCENT_TEXT[power])
  end
end

local function UpdateAnimatedFrames(elapsed)
  UnitFrameTest.elapsed = UnitFrameTest.elapsed + elapsed
  if UnitFrameTest.elapsed < UPDATE_INTERVAL then
    return
  end

  UnitFrameTest.animationTime = UnitFrameTest.animationTime + UnitFrameTest.elapsed
  UnitFrameTest.elapsed = 0

  for frame, sample in pairs(UnitFrameTest.activeFrames) do
    SetSyntheticValues(frame, sample)
  end
end

local animationDriver = CreateFrame("Frame")
animationDriver:Hide()
animationDriver:SetScript("OnUpdate", function(_, elapsed)
  UpdateAnimatedFrames(elapsed)
end)

local function StartAnimation(reset)
  UnitFrameTest.elapsed = 0

  if reset == true then
    UnitFrameTest.animationTime = 0
  end

  for frame, sample in pairs(UnitFrameTest.activeFrames) do
    SetSyntheticValues(frame, sample)
  end

  if next(UnitFrameTest.activeFrames) and UnitFrameTest.activity ~= "AURAS" then
    animationDriver:Show()
  else
    animationDriver:Hide()
  end
end

local function StopAnimation()
  animationDriver:Hide()
  UnitFrameTest.elapsed = 0
end

local function HidePresentationFrame(frame)
  if not frame then
    return
  end

  UnitFrameTest.activeFrames[frame] = nil
  Inspector:OnFrameHidden(frame)
  HideTestVisuals(frame)

  if frame.__puiPresentationKey then
    Presentation.Release(frame)
  else
    frame:Hide()
    frame:ClearAllPoints()
  end
end

local function AcquirePresentationFrame(bucket, index, unit, cfg, useClassColor)
  local frame = bucket[index]
  if frame then
    return frame
  end

  frame = Presentation.Create("UnitFrame", UIParent, {
    unit = unit,
    config = cfg,
    useConfigText = true,
    useClassColor = useClassColor,
  })

  frame:SetFrameStrata("HIGH")
  frame:SetFrameLevel(200)
  frame:EnableMouse(true)
  frame.__puiIsTestFrame = true
  frame.__puiTestProvider = {
    health = 72,
    healthMax = 100,
    power = 62,
    powerMin = 0,
    powerMax = 100,
    nameColor = {},
    healthColor = {},
    healthMissingColor = {},
    powerColor = {},
  }

  bucket[index] = frame
  return frame
end

local function AcquireLayoutFrame(bucket, index)
  local frame = bucket[index]
  if frame then
    return frame
  end

  frame = CreateFrame("Frame", nil, UIParent)
  frame:EnableMouse(false)
  frame:Hide()
  bucket[index] = frame
  return frame
end

local function ApplyPresentationFrame(
  frame,
  unit,
  cfg,
  db,
  groupKind,
  forceNoPower,
  name,
  index,
  useClassColor,
  groupMemberIndex
)
  useClassColor = useClassColor == true

  local themeColors = UFStyle.GetUFThemeColors()
  local colors = cfg.colors or themeColors
  local layout = UFStyle.CalculateFrameLayout(cfg, db, {
    forceNoPower = forceNoPower == true,
  })
  local provider = frame.__puiTestProvider
  local classToken = TEST_CLASS_TOKENS[((index - 1) % #TEST_CLASS_TOKENS) + 1]
  local classColor = useClassColor and RAID_CLASS_COLORS[classToken] or nil
  local classNameColor = db.colors and db.colors.useClassForNames == true and RAID_CLASS_COLORS[classToken] or nil
  local healthColor = classColor or colors.healthBar or themeColors.healthBar
  local nameColor = classNameColor or (db.colors and db.colors.nameText) or colors.nameText or themeColors.nameText
  local missingColor = colors.healthMissing or themeColors.healthMissing
  local powerColor = ns.Theme.GetColors().accent

  provider.name = name
  provider.healthText = "72%"
  provider.powerText = "62%"
  SetColor(provider.nameColor, nameColor, { 1, 1, 1, 1 })
  SetColor(provider.healthColor, healthColor, { 0.35, 0.35, 0.35, 1 })
  SetColor(provider.healthMissingColor, missingColor, { 0.1, 0.1, 0.1, 0.9 })
  SetColor(provider.powerColor, powerColor, { 0.2, 0.65, 1, 1 })

  Presentation.Apply("UnitFrame", frame, {
    unit = unit,
    config = cfg,
    layout = layout,
    colors = themeColors,
    textColors = db.colors or themeColors,
    fontRevision = UF._fontRev or 0,
    useClassColor = useClassColor,
    forceShown = true,
    options = {
      forceNoPower = forceNoPower == true,
      groupKind = groupKind,
      useConfigText = true,
    },
  }, provider)

  if frame.NameText then
    frame.NameText:SetTextColor(
      provider.nameColor[1],
      provider.nameColor[2],
      provider.nameColor[3],
      provider.nameColor[4]
    )
  end

  local sample = {
    index = index,
    name = name,
    unit = unit,
    db = db,
    groupKind = groupKind,
    groupMemberIndex = groupMemberIndex,
    isPet = type(unit) == "string" and unit:find("pet", 1, true) ~= nil,
  }

  UnitFrameTest.activeFrames[frame] = sample
  frame.__puiTestSample = sample
end

local function HidePresentationBucket(bucket)
  for _, frame in pairs(bucket or {}) do
    HidePresentationFrame(frame)
  end
end

local function HidePresentationFrames(family)
  if family == "party" then
    HidePresentationBucket(UnitFrameTest.presentationFrames.party)
    HidePresentationBucket(UnitFrameTest.presentationFrames.partyPets)
    return
  elseif family == "raid" then
    HidePresentationBucket(UnitFrameTest.presentationFrames.raid)
    HidePresentationBucket(UnitFrameTest.presentationFrames.raidGroups)
    return
  end

  for _, bucket in pairs(UnitFrameTest.presentationFrames) do
    HidePresentationBucket(bucket)
  end
end

local function RefreshSingleFrames(context)
  local frames = UnitFrameTest.presentationFrames.single
  local sampleIndex = 0

  for _, family in ipairs(SINGLE_FAMILIES) do
    local enabled = context:GetValue(family.control) == true

    for index, unit in ipairs(family.units) do
      local frame = frames[unit]

      if enabled then
        local cfg, db, forceNoPower = UF:GetTestFrameConfig(unit)
        if not cfg then
          return false
        end

        sampleIndex = sampleIndex + 1
        local useClassColor = unit == "player" and cfg.useClassColor ~= false
        frame = AcquirePresentationFrame(frames, unit, unit, cfg, useClassColor)

        ApplyPresentationFrame(
          frame,
          unit,
          cfg,
          db,
          nil,
          forceNoPower,
          family.names[index],
          sampleIndex,
          useClassColor
        )

        if UF:LayoutTestFrame(frame, unit) == false then
          return false
        end
      else
        HidePresentationFrame(frame)
      end
    end
  end

  return true
end

local function RefreshPartyFrames(context)
  if context:GetValue("uf.party") ~= true then
    if UnitFrameTest.partyLayoutActive then
      UnitFrameTest.partyLayoutActive = false
      PartyFrames:Refresh()
    end
    return true
  end

  local memberCount = math_min(
    5,
    math_max(1, tonumber(context:GetValue("uf.partyMembers")) or 1)
  )
  local memberConfig, db = PartyFrames:GetTestFrameConfig(false)
  local petConfig, _, forcePetNoPower = PartyFrames:GetTestFrameConfig(true)
  local memberFrames = UnitFrameTest.presentationFrames.party
  local petFrames = UnitFrameTest.presentationFrames.partyPets

  for index = 1, memberCount do
    local unit = "party" .. index
    local frame = AcquirePresentationFrame(memberFrames, index, unit, memberConfig, db.useClassColor ~= false)

    ApplyPresentationFrame(
      frame,
      unit,
      memberConfig,
      db,
      "party",
      false,
      "Party member " .. index,
      20 + index,
      db.useClassColor ~= false,
      index
    )
  end

  local petCount = petConfig.enabled ~= false and math_min(4, memberCount) or 0

  for index = 1, petCount do
    local unit = "partypet" .. index
    local frame = AcquirePresentationFrame(petFrames, index, unit, petConfig, db.useClassColor ~= false)

    ApplyPresentationFrame(
      frame,
      unit,
      petConfig,
      db,
      "party",
      forcePetNoPower,
      "Party pet " .. index,
      25 + index,
      db.useClassColor ~= false,
      index
    )
  end

  if PartyFrames:LayoutTestFrames(memberFrames, petFrames, memberCount) == false then
    return false
  end

  UnitFrameTest.partyLayoutActive = true
  return true
end

local function RefreshRaidFrames(context)
  if context:GetValue("uf.raid") ~= true then
    if UnitFrameTest.raidLayoutActive then
      UnitFrameTest.raidLayoutActive = false
      RaidFrames:Refresh()
    end
    return true
  end

  local groupCount = context:GetValue("uf.raidGroups")
  local membersPerGroup = context:GetValue("uf.raidMembersPerGroup")
  local visibleCount = groupCount * membersPerGroup
  local cfg, db, forceNoPower = RaidFrames:GetTestFrameConfig()
  local frames = UnitFrameTest.presentationFrames.raid
  local groupFrames = UnitFrameTest.presentationFrames.raidGroups

  for index = 1, groupCount do
    AcquireLayoutFrame(groupFrames, index)
  end

  for index = 1, visibleCount do
    local groupIndex = math_floor((index - 1) / membersPerGroup) + 1
    local memberIndex = ((index - 1) % membersPerGroup) + 1
    local unit = "raid" .. index
    local frame = AcquirePresentationFrame(frames, index, unit, cfg, db.useClassColor ~= false)

    ApplyPresentationFrame(
      frame,
      unit,
      cfg,
      db,
      "raid",
      forceNoPower,
      "G" .. groupIndex .. " Member " .. memberIndex,
      40 + index,
      db.useClassColor ~= false,
      memberIndex
    )
  end

  if RaidFrames:LayoutTestFrames(frames, groupFrames, groupCount, membersPerGroup) == false then
    return false
  end

  UnitFrameTest.raidLayoutActive = true
  return true
end

local function RefreshCastBars(context)
  local activity = context:GetValue("uf.activity") or "MIXED"
  local enabled = context:GetValue("uf.castbars") == true
    and (activity == "MIXED" or activity == "CASTING")
  local units = UnitFrameTest.castbarUnits
  local playerShown = context:GetValue("uf.player") == true
  local bossShown = context:GetValue("uf.boss") == true

  units.player = playerShown
  units.pet = playerShown
  units.target = context:GetValue("uf.target") == true
  units.focus = context:GetValue("uf.focus") == true

  for index = 1, 5 do
    units["boss" .. index] = bossShown
  end

  return CastBar:SetTestMode(enabled, units) ~= false
end

function UnitFrameTest:Refresh(context)
  if InCombatLockdown() then
    return false
  end

  local changedKey = context.changedKey

  if changedKey == "uf.castbars" then
    return RefreshCastBars(context)
  elseif changedKey == "uf.activity" then
    ApplyActivityToFrames(context)
    local ready = RefreshCastBars(context)
    StartAnimation()
    return ready ~= false
  elseif changedKey == "uf.auraSettings" then
    ApplyActivityToFrames(context)
    StartAnimation()
    return true
  elseif changedKey == "uf.party" or changedKey == "uf.partyMembers" then
    HidePresentationFrames("party")
    local ready = RefreshPartyFrames(context)
    ApplyActivityToFrames(context)
    StartAnimation()
    return ready ~= false
  elseif changedKey == "uf.partySettings" then
    local ready = RefreshPartyFrames(context)
    ApplyActivityToFrames(context)
    StartAnimation()
    return ready ~= false
  elseif changedKey == "uf.raid"
    or changedKey == "uf.raidGroups"
    or changedKey == "uf.raidMembersPerGroup"
  then
    HidePresentationFrames("raid")
    local ready = RefreshRaidFrames(context)
    ApplyActivityToFrames(context)
    StartAnimation()
    return ready ~= false
  elseif changedKey == "uf.raidSettings" then
    local ready = RefreshRaidFrames(context)
    ApplyActivityToFrames(context)
    StartAnimation()
    return ready ~= false
  elseif changedKey == "uf.player"
    or changedKey == "uf.target"
    or changedKey == "uf.focus"
    or changedKey == "uf.boss"
    or changedKey == "uf.singleSettings"
  then
    local ready = RefreshSingleFrames(context)
    ApplyActivityToFrames(context)
    local castbarsReady = RefreshCastBars(context)
    StartAnimation()
    return ready ~= false and castbarsReady ~= false
  end

  HidePresentationFrames()
  self.activeFrames = {}
  local singleReady = RefreshSingleFrames(context)

  local partyReady = RefreshPartyFrames(context)
  local raidReady = RefreshRaidFrames(context)

  ApplyActivityToFrames(context)
  local castbarsReady = RefreshCastBars(context)

  StartAnimation(context.reason == "start" or context.reason == "enable")
  return singleReady ~= false
    and partyReady ~= false
    and raidReady ~= false
    and castbarsReady ~= false
end

function UnitFrameTest:Start(context)
  if InCombatLockdown() then
    return false
  end

  local _, _, _, raidGroupCount = RaidFrames:GetTestFrameConfig()

  context.values["uf.partyMembers"] = PartyFrames.db.profile.showPlayer == true and 5 or 4
  context.values["uf.raidGroups"] = raidGroupCount
  context.values["uf.raidMembersPerGroup"] = 5
  Inspector:SetActive(true)
  self.animationTime = 0

  if self:Refresh(context) == false then
    self:Stop()
    return false
  end

  return true
end

function UnitFrameTest:Stop()
  StopAnimation()
  Inspector:SetActive(false)
  HidePresentationFrames()
  CastBar:SuspendTestMode()

  if InCombatLockdown() then
    return false
  end

  CastBar:SetTestMode(false)

  if self.partyLayoutActive then
    self.partyLayoutActive = false
    PartyFrames:Refresh()
  end

  if self.raidLayoutActive then
    self.raidLayoutActive = false
    RaidFrames:Refresh()
  end

  self.activeFrames = {}
  return true
end

function UnitFrameTest:IsAvailable()
  return Presentation ~= nil
    and Presentation.Get("UnitFrame") ~= nil
    and UFStyle ~= nil
    and UF ~= nil
    and PartyFrames ~= nil
    and RaidFrames ~= nil
    and CastBar ~= nil
end

local function RegisterToggle(key, label, order, default)
  TestMode:RegisterControl(key, {
    participant = PARTICIPANT_KEY,
    type = "toggle",
    label = label,
    order = order,
    default = default,
  })
end

RegisterToggle("uf.player", "Player", 10, true)
RegisterToggle("uf.target", "Target", 20, true)
RegisterToggle("uf.focus", "Focus", 30, true)
RegisterToggle("uf.boss", "Boss", 40, true)
RegisterToggle("uf.party", "Party", 50, true)
RegisterToggle("uf.raid", "Raid", 60, true)
RegisterToggle("uf.castbars", "Castbars", 70, true)

TestMode:RegisterControl("uf.activity", {
  participant = PARTICIPANT_KEY,
  type = "choice",
  label = "Activity",
  order = 75,
  default = "MIXED",
  values = TEST_ACTIVITY_VALUES,
})

TestMode:RegisterControl("uf.partyMembers", {
  participant = PARTICIPANT_KEY,
  type = "range",
  label = "Party members",
  order = 80,
  min = 1,
  max = 5,
  step = 1,
  default = 4,
  Visible = function(_, context)
    return context:GetValue("uf.party") == true
  end,
})

TestMode:RegisterControl("uf.raidGroups", {
  participant = PARTICIPANT_KEY,
  type = "range",
  label = "Raid groups",
  order = 90,
  min = 1,
  max = 8,
  step = 1,
  default = 4,
  Visible = function(_, context)
    return context:GetValue("uf.raid") == true
  end,
})

TestMode:RegisterControl("uf.raidMembersPerGroup", {
  participant = PARTICIPANT_KEY,
  type = "range",
  label = "Members per group",
  order = 100,
  min = 1,
  max = 5,
  step = 1,
  default = 5,
  Visible = function(_, context)
    return context:GetValue("uf.raid") == true
  end,
})

local P = select(1, ns.Pleebug:DropIn(UnitFrameTest, { name = "UnitFrames.TestMode" }))
AnchorTestHealthSegment = P:Def("AnchorTestHealthSegment", AnchorTestHealthSegment)
ApplyTestScenario = P:Def("ApplyTestScenario", ApplyTestScenario)
ApplyActivityToFrames = P:Def("ApplyActivityToFrames", ApplyActivityToFrames)
UnitFrameTest.Refresh = P:Def("UnitFrameTest:Refresh", UnitFrameTest.Refresh)
UnitFrameTest.GetQuickSettingsFrame = P:Def("UnitFrameTest:GetQuickSettingsFrame", UnitFrameTest.GetQuickSettingsFrame)
UnitFrameTest.OpenQuickSettings = P:Def("UnitFrameTest:OpenQuickSettings", UnitFrameTest.OpenQuickSettings)
UnitFrameTest.Start = P:Def("UnitFrameTest:Start", UnitFrameTest.Start)
UnitFrameTest.Stop = P:Def("UnitFrameTest:Stop", UnitFrameTest.Stop)
UnitFrameTest.IsAvailable = P:Def("UnitFrameTest:IsAvailable", UnitFrameTest.IsAvailable)

UnitFrameTest.label = "Unit Frames"
UnitFrameTest.order = 10
UnitFrameTest.defaultEnabled = true
TestMode:RegisterParticipant(PARTICIPANT_KEY, UnitFrameTest)
