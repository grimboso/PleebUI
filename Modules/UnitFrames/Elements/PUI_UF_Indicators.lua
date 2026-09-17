
-- File: PUI_UF_Indicators.lua
-- Purpose: Shared UnitFrames indicator construction and oUF-native indicator positioning.


local ADDON_NAME, ns = ...

ns.UFIndicators = ns.UFIndicators or {}

local UFIndicators = ns.UFIndicators
local Theme = ns.Theme
local P = select(1, ns.Pleebug:DropIn(UFIndicators, { name = "UnitFrames.Indicators" }))
local _G = _G
local CreateFrame = _G.CreateFrame
local type = _G.type
local tonumber = _G.tonumber
local pairs = _G.pairs
local math_max = _G.math.max

local Round = ns.Pixel.Round
local SHARED_ICON_ANCHOR_POINTS = {
  LEFT = true,
  RIGHT = true,
  CENTER = true,
  TOP = true,
  BOTTOM = true,
  TOPLEFT = true,
  TOPRIGHT = true,
  BOTTOMLEFT = true,
  BOTTOMRIGHT = true,
}

local function NormalizeSharedIconPoint(point, fallback)
  if type(point) == "string" and SHARED_ICON_ANCHOR_POINTS[point] then
    return point
  end

  return fallback or "TOPLEFT"
end

local function GetSharedRoleIconDefaults(defaults)
  defaults = type(defaults) == "table" and defaults or {}

  return {
    showRaidRoleStrip = defaults.showRaidRoleStrip ~= false,
    raidRoleStripPosition = NormalizeSharedIconPoint(defaults.raidRoleStripPosition, "TOPLEFT"),
    raidRoleStripXOffset = tonumber(defaults.raidRoleStripXOffset) or 0,
    raidRoleStripYOffset = tonumber(defaults.raidRoleStripYOffset) or 0,
    raidRoleStripSize = tonumber(defaults.raidRoleStripSize) or 12,
    roleIconSize = tonumber(defaults.roleIconSize) or 17,
    roleIconPosition = NormalizeSharedIconPoint(defaults.roleIconPosition, "TOPLEFT"),
    roleIconXOffset = tonumber(defaults.roleIconXOffset) or 0,
    roleIconYOffset = tonumber(defaults.roleIconYOffset) or 0,
    raidTargetAnchorPoint = NormalizeSharedIconPoint(defaults.raidTargetAnchorPoint, "TOP"),
    raidTargetXOffset = tonumber(defaults.raidTargetXOffset) or 0,
    raidTargetYOffset = tonumber(defaults.raidTargetYOffset) or 0,
    raidTargetSize = tonumber(defaults.raidTargetSize) or 18,
    statusIconSize = tonumber(defaults.statusIconSize) or 18,
  }
end

local DEFAULT_SHARED_ROLE_ICON_DEFAULTS = GetSharedRoleIconDefaults()

local function BuildSharedRoleIconConfig(config, defaults)
  config = type(config) == "table" and config or {}
  defaults = type(defaults) == "table" and defaults or DEFAULT_SHARED_ROLE_ICON_DEFAULTS

  if config.showRaidRoleStrip == nil then
    config.showRaidRoleStrip = defaults.showRaidRoleStrip
  end

  if config.raidRoleStripPosition == nil then
    config.raidRoleStripPosition = defaults.raidRoleStripPosition
  end

  if config.raidRoleStripXOffset == nil then
    config.raidRoleStripXOffset = defaults.raidRoleStripXOffset
  end

  if config.raidRoleStripYOffset == nil then
    config.raidRoleStripYOffset = defaults.raidRoleStripYOffset
  end

  if config.raidRoleStripSize == nil then
    config.raidRoleStripSize = defaults.raidRoleStripSize
  end

  if config.roleIconSize == nil then
    config.roleIconSize = defaults.roleIconSize
  end

  if config.roleIconPosition == nil then
    config.roleIconPosition = defaults.roleIconPosition
  end

  if config.roleIconXOffset == nil then
    config.roleIconXOffset = defaults.roleIconXOffset
  end

  if config.roleIconYOffset == nil then
    config.roleIconYOffset = defaults.roleIconYOffset
  end

  if config.raidTargetAnchorPoint == nil then
    config.raidTargetAnchorPoint = defaults.raidTargetAnchorPoint
  end

  if config.raidTargetXOffset == nil then
    config.raidTargetXOffset = defaults.raidTargetXOffset
  end

  if config.raidTargetYOffset == nil then
    config.raidTargetYOffset = defaults.raidTargetYOffset
  end

  if config.raidTargetSize == nil then
    config.raidTargetSize = defaults.raidTargetSize
  end

  if config.statusIconSize == nil then
    config.statusIconSize = defaults.statusIconSize
  end

  return config
end

local function GetFrameIndicatorConfig(frame)
  local config = frame.__puiIndicatorConfig
  if config then
    return config
  end

  local provider = frame.__puiRoleIconConfigProvider
  config = provider and provider() or {}
  config = BuildSharedRoleIconConfig(config, frame.__puiRoleIconDefaults)
  frame.__puiIndicatorConfig = config

  return config
end

local function IsElementEnabled(frame, elementName)
  return frame:IsElementEnabled(elementName) == true
end

local function EnableElement(frame, elementName, unit)
  if not IsElementEnabled(frame, elementName) then
    frame:EnableElement(elementName, unit)
  end
end

local function DisableElement(frame, elementName)
  if IsElementEnabled(frame, elementName) then
    frame:DisableElement(elementName)
  end
end


local function IsPetUnit(unit)
  return type(unit) == "string" and unit:find("pet", 1, true) ~= nil
end

local function IsIndicatorEnabled(config, key)
  if type(config) ~= "table" then
    return true
  end

  return config[key] ~= false
end

local function SetTexturePoint(texture, point, relativeTo, relativePoint, x, y, size)
  if not texture then
    return
  end

  x = Round(x or 0)
  y = Round(y or 0)
  size = math_max(Round(1), Round(size or 1))

  texture:ClearAllPoints()
  texture:SetPoint(point, relativeTo, relativePoint, x, y)
  texture:SetSize(size, size)
end

local function GetRaidRoleVisibilityMask(frame)
  local isLeader = frame and frame.LeaderIndicator and frame.LeaderIndicator:IsShown() == true
  local isAssistant = frame and frame.AssistantIndicator and frame.AssistantIndicator:IsShown() == true
  local isRaidRole = frame and frame.RaidRoleIndicator and frame.RaidRoleIndicator:IsShown() == true
  local mask = (isLeader and 1 or 0) + (isAssistant and 2 or 0) + (isRaidRole and 4 or 0)

  return mask, isLeader, isAssistant, isRaidRole
end

local function LayoutRaidRoleIndicators(frame)
  if not frame then
    return
  end

  local layout = frame.__puiRaidRoleLayout
  if type(layout) ~= "table" then
    return
  end

  local visibilityMask, isLeader, isAssistant, isRaidRole = GetRaidRoleVisibilityMask(frame)
  frame.__puiRaidRoleVisibilityMask = visibilityMask

  if visibilityMask == 0 then
    return
  end

  local leader = frame.LeaderIndicator
  local assistant = frame.AssistantIndicator
  local raidRole = frame.RaidRoleIndicator
  local anchor = frame.PUIRaidRoleAnchor or frame
  local point = layout.point
  local size = math_max(Round(1), Round(layout.size or 1))
  local x = Round(layout.x or 0)
  local y = Round(layout.y or 0)

  if isLeader then
    leader:SetSize(size, size)
    leader:ClearAllPoints()
  end

  if isAssistant then
    assistant:SetSize(size, size)
    assistant:ClearAllPoints()
  end

  if isRaidRole then
    raidRole:SetSize(size, size)
    raidRole:ClearAllPoints()
  end

  local growsLeft = point:find("RIGHT", 1, true) ~= nil
  local pos1 = growsLeft and "RIGHT" or "LEFT"
  local pos2 = growsLeft and "LEFT" or "RIGHT"

  if isLeader then
    leader:SetPoint(point, anchor, point, x, y)
  elseif isAssistant then
    assistant:SetPoint(point, anchor, point, x, y)
  end

  if isRaidRole then
    if isLeader then
      raidRole:SetPoint(pos1, leader, pos2, 0, 0)
    elseif isAssistant then
      raidRole:SetPoint(pos1, assistant, pos2, 0, 0)
    else
      raidRole:SetPoint(point, anchor, point, x, y)
    end
  end
end

local function PostUpdateRaidRoleElement(element, role)
  local owner = element and element.__owner or nil
  local layout = owner and owner.__puiRaidRoleLayout or nil

  if role == "MAINTANK" and layout and layout.showMainTank ~= true then
    element:Hide()
  elseif role == "MAINASSIST" and layout and layout.showMainAssist ~= true then
    element:Hide()
  end

  if not owner or owner.__puiRaidRoleVisibilityMask == GetRaidRoleVisibilityMask(owner) then
    return
  end

  LayoutRaidRoleIndicators(owner)
end

local function PostUpdateGroupRoleIndicator(element, role)
  local frame = element.__owner
  local previousRole = frame.__puiGroupRole
  frame.__puiGroupRole = role
  element:SetAlpha(element.__puiShowRoleIcon == true and 1 or 0)

  if previousRole ~= role then
    ns.UFThreat.Refresh(frame)

    if frame.__puiGroupKind == "party" then
      ns.Modules.PartyFrames:RefreshGroupLayout()
    end
  end
end

local function CreatePhaseIndicator(frame, parent)
  local indicator = CreateFrame("Frame", nil, parent)
  indicator:SetSize(Round(18), Round(18))
  indicator:EnableMouse(true)
  indicator:Hide()

  local icon = indicator:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(indicator)
  indicator.Icon = icon

  return indicator
end

function UFIndicators.ConstructNativeStatusElements(frame, unit, cfg)
  local parent = frame.TextureParent or frame.RaisedElementParent or frame
  local health = frame.Health or frame
  local size = Round(14)
  local isPlayer = unit == "player"
  local isGroupFrame = frame.__puiGroupKind == "party" or frame.__puiGroupKind == "raid"

  if (isPlayer or isGroupFrame) and not frame.CombatIndicator then
    frame.CombatIndicator = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.CombatIndicator:Hide()
  end

  if frame.CombatIndicator then
    frame.CombatIndicator:ClearAllPoints()
    frame.CombatIndicator:SetSize(size, size)
    frame.CombatIndicator:SetPoint(
      "TOPRIGHT",
      health,
      "TOPRIGHT",
      -Round(1),
      -Round(1)
    )
  end

  if isPlayer and (not cfg or cfg.showRestingIndicator ~= false) and not frame.RestingIndicator then
    frame.RestingIndicator = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.RestingIndicator:Hide()
  end

  if frame.RestingIndicator then
    frame.RestingIndicator:ClearAllPoints()
    frame.RestingIndicator:SetSize(size, size)
    frame.RestingIndicator:SetPoint(
      "TOPRIGHT",
      frame.CombatIndicator,
      "TOPLEFT",
      -Round(2),
      0
    )

    if frame.__puiUF_oUFInitialized == true then
      if cfg and cfg.showRestingIndicator == false then
        DisableElement(frame, "RestingIndicator")
        frame.RestingIndicator:Hide()
      else
        local wasEnabled = IsElementEnabled(frame, "RestingIndicator")
        EnableElement(frame, "RestingIndicator", unit)

        if not wasEnabled and frame.RestingIndicator.ForceUpdate then
          frame.RestingIndicator:ForceUpdate()
        end
      end
    end
  end

  if isPlayer then
    if not frame.PvPIndicator then
      frame.PvPIndicator = parent:CreateTexture(nil, "OVERLAY", nil, 6)
      frame.PvPIndicator:Hide()
    end

    frame.PvPIndicator:ClearAllPoints()
    frame.PvPIndicator:SetSize(size, size)
    frame.PvPIndicator:SetPoint("TOPLEFT", health, "TOPLEFT", Round(1), -Round(1))
  end

  if unit == "target" and not frame.QuestIndicator then
    frame.QuestIndicator = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.QuestIndicator:Hide()
  end

  if frame.QuestIndicator then
    frame.QuestIndicator:ClearAllPoints()
    frame.QuestIndicator:SetSize(size, size)
    frame.QuestIndicator:SetPoint(
      "BOTTOMRIGHT",
      health,
      "BOTTOMRIGHT",
      -Round(1),
      Round(1)
    )
  end
end

function UFIndicators.EnsureSharedUnitIndicators(frame, parent, roleConfigProvider, roleDefaults, indicatorParents)
  if not frame then
    return nil, nil, nil, nil
  end

  parent = parent or frame
  indicatorParents = type(indicatorParents) == "table" and indicatorParents or {}

  local roleParent = indicatorParents.role or parent
  local leaderParent = indicatorParents.leader or parent
  local raidTargetParent = indicatorParents.raidTarget or parent
  local statusParent = indicatorParents.status or parent
  local readyCheckParent = indicatorParents.readyCheck or statusParent


  frame.__puiRoleIconConfigProvider = roleConfigProvider
  frame.__puiRoleIconDefaults = GetSharedRoleIconDefaults(roleDefaults)
  frame.__puiIndicatorConfig = nil

  local useRoleIndicators = roleConfigProvider ~= nil

  if useRoleIndicators and not frame.GroupRoleIndicator then
    frame.GroupRoleIndicator = roleParent:CreateTexture(nil, "ARTWORK")
  end
  if frame.GroupRoleIndicator then
    frame.GroupRoleIndicator.PostUpdate = PostUpdateGroupRoleIndicator
  end

  if useRoleIndicators and not frame.PUIRaidRoleAnchor then
    frame.PUIRaidRoleAnchor = CreateFrame("Frame", nil, leaderParent)
    frame.PUIRaidRoleAnchor:SetSize(Round(36), Round(12))
    frame.PUIRaidRoleAnchor:EnableMouse(false)
  end

  if frame.PUIRaidRoleAnchor and frame.RaisedElementParent and frame.RaisedElementParent.RaidRoleLevel then
    frame.PUIRaidRoleAnchor:SetFrameLevel(frame.RaisedElementParent.RaidRoleLevel)
  end

  if useRoleIndicators and not frame.LeaderIndicator then
    frame.LeaderIndicator = frame.PUIRaidRoleAnchor:CreateTexture(nil, "OVERLAY")
  end
  if frame.LeaderIndicator then
    frame.LeaderIndicator.PostUpdate = PostUpdateRaidRoleElement
  end

  if useRoleIndicators and not frame.AssistantIndicator then
    frame.AssistantIndicator = frame.PUIRaidRoleAnchor:CreateTexture(nil, "OVERLAY")
    frame.AssistantIndicator:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
  end
  if frame.AssistantIndicator then
    frame.AssistantIndicator.PostUpdate = PostUpdateRaidRoleElement
  end

  if useRoleIndicators and not frame.RaidRoleIndicator then
    frame.RaidRoleIndicator = frame.PUIRaidRoleAnchor:CreateTexture(nil, "OVERLAY")
  end
  if frame.RaidRoleIndicator then
    frame.RaidRoleIndicator.PostUpdate = PostUpdateRaidRoleElement
  end

  if not frame.RaidTargetIndicator then
    frame.RaidTargetIndicator = raidTargetParent:CreateTexture(nil, "OVERLAY")
  end

  if not frame.ReadyCheckIndicator then
    frame.ReadyCheckIndicator = readyCheckParent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.ReadyCheckIndicator.finishedTime = 10
    frame.ReadyCheckIndicator.fadeTime = 1.5
    frame.ReadyCheckIndicator.useAtlasSize = false
    frame.ReadyCheckIndicator:Hide()
  end

  if not frame.PhaseIndicator then
    frame.PhaseIndicator = CreatePhaseIndicator(frame, statusParent)
  end

  if not frame.ResurrectIndicator then
    frame.ResurrectIndicator = statusParent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.ResurrectIndicator:Hide()
  end

  if not frame.SummonIndicator then
    frame.SummonIndicator = statusParent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.SummonIndicator.useAtlasSize = false
    frame.SummonIndicator:Hide()
  end

  if not frame.OfflineText then
    frame.OfflineText = frame.TextParent:CreateFontString(nil, "OVERLAY")
    frame.OfflineText:SetPoint("CENTER", frame.Health, "CENTER", 0, 0)
    Theme.ApplyFont(frame.OfflineText, "tiny", 10, "OUTLINE")
    frame.OfflineText:SetText(_G.PLAYER_OFFLINE or "OFFLINE")
    frame.OfflineText:Hide()
  end

  return frame.GroupRoleIndicator, frame.LeaderIndicator, frame.RaidTargetIndicator, nil
end



function UFIndicators.UpdateOfflinePresentation(frame, isOffline)
  frame.__puiOfflineState = isOffline

  frame.NameText:SetAlpha(1)
  frame.HealthText:SetAlpha(isOffline and 0 or 1)
  frame.PowerText:SetAlpha(isOffline and 0 or 1)
  frame.OfflineText:SetShown(isOffline)
  frame.healthBG:SetAlpha(isOffline and 0.75 or 1)
  frame.Health:SetAlpha(isOffline and 0.35 or 1)
  frame.Power:SetAlpha(isOffline and 0.20 or 1)
  frame.TextureParent:SetAlpha(isOffline and 0.45 or 1)
end

function UFIndicators.ConfigureSharedUnitIndicators(frame, layout)
  frame.__puiIndicatorLayout = layout

  local config = GetFrameIndicatorConfig(frame)
  local unit = frame.__unit
  local isPet = IsPetUnit(unit)

  if frame.__puiIndicatorConfiguredConfig == config
    and frame.__puiIndicatorConfiguredLayout == layout
    and frame.__puiIndicatorConfiguredPet == isPet
  then
    return
  end

  local role = type(layout.role) == "table" and layout.role or {}
  local leader = type(layout.leader) == "table" and layout.leader or {}
  local raidTarget = type(layout.raidTarget) == "table" and layout.raidTarget or {}
  local status = type(layout.status) == "table" and layout.status or {}
  local readyCheck = type(layout.readyCheck) == "table" and layout.readyCheck or status

  if frame.GroupRoleIndicator then
    local point = NormalizeSharedIconPoint(config.roleIconPosition, "TOPLEFT")
    local x = tonumber(config.roleIconXOffset) or 0
    local y = tonumber(config.roleIconYOffset) or 0
    local size = tonumber(config.roleIconSize) or 17

    SetTexturePoint(frame.GroupRoleIndicator, point, frame, point, x, y, size)

    frame.GroupRoleIndicator.__puiShowRoleIcon = IsIndicatorEnabled(config, "showRoleIcon") and not isPet
    frame.GroupRoleIndicator:SetAlpha(frame.GroupRoleIndicator.__puiShowRoleIcon and 1 or 0)

    if isPet then
      DisableElement(frame, "GroupRoleIndicator")
      frame.GroupRoleIndicator:Hide()
    else
      EnableElement(frame, "GroupRoleIndicator", unit)
    end
  end

  if frame.PUIRaidRoleAnchor then
    local point = NormalizeSharedIconPoint(config.raidRoleStripPosition, "TOPLEFT")
    local x = tonumber(config.raidRoleStripXOffset) or 0
    local y = tonumber(config.raidRoleStripYOffset) or 0
    local size = tonumber(config.raidRoleStripSize) or 12

    local roleLayout = frame.__puiRaidRoleLayout
    if type(roleLayout) ~= "table" then
      roleLayout = {}
      frame.__puiRaidRoleLayout = roleLayout
    end

    roleLayout.point = point
    roleLayout.x = Round(x)
    roleLayout.y = Round(y)
    roleLayout.size = math_max(Round(1), Round(size))
    roleLayout.showMainTank = IsIndicatorEnabled(config, "showMainTank")
    roleLayout.showMainAssist = IsIndicatorEnabled(config, "showMainAssist")

    frame.PUIRaidRoleAnchor:ClearAllPoints()
    frame.PUIRaidRoleAnchor:SetPoint(point, frame, point, 0, 0)
    frame.PUIRaidRoleAnchor:SetSize(Round(size * 3), math_max(Round(1), Round(size)))
  end

  local useRaidRoleStrip = IsIndicatorEnabled(config, "showRaidRoleStrip") and not isPet

  if frame.LeaderIndicator then
    if useRaidRoleStrip and IsIndicatorEnabled(config, "showLeader") then
      EnableElement(frame, "LeaderIndicator", unit)
    else
      DisableElement(frame, "LeaderIndicator")
      frame.LeaderIndicator:Hide()
    end
  end

  if frame.AssistantIndicator then
    if useRaidRoleStrip and IsIndicatorEnabled(config, "showRaidAssistant") then
      EnableElement(frame, "AssistantIndicator", unit)
    else
      DisableElement(frame, "AssistantIndicator")
      frame.AssistantIndicator:Hide()
    end
  end

  if frame.RaidRoleIndicator then
    if useRaidRoleStrip and (IsIndicatorEnabled(config, "showMainTank") or IsIndicatorEnabled(config, "showMainAssist")) then
      EnableElement(frame, "RaidRoleIndicator", unit)
    else
      DisableElement(frame, "RaidRoleIndicator")
      frame.RaidRoleIndicator:Hide()
    end
  end

  LayoutRaidRoleIndicators(frame)

  if frame.RaidTargetIndicator then
    local point = NormalizeSharedIconPoint(config.raidTargetAnchorPoint, "TOP")
    local x = tonumber(config.raidTargetXOffset) or 0
    local y = tonumber(config.raidTargetYOffset) or 0
    local size = tonumber(config.raidTargetSize) or 18

    SetTexturePoint(frame.RaidTargetIndicator, point, frame, point, x, y, size)

    if IsIndicatorEnabled(config, "showRaidTarget") and not isPet then
      EnableElement(frame, "RaidTargetIndicator", unit)
    else
      DisableElement(frame, "RaidTargetIndicator")
      frame.RaidTargetIndicator:Hide()
    end
  end

  local statusPoint = NormalizeSharedIconPoint(status.point, "CENTER")
  local statusRelativeTo = status.relativeTo or frame.Health or frame
  local statusRelativePoint = NormalizeSharedIconPoint(status.relativePoint, statusPoint)
  local statusX = tonumber(status.x) or 0
  local statusY = tonumber(status.y) or 0
  local statusSize = tonumber(status.size or config.statusIconSize) or 18

  if frame.CombatIndicator then
    if IsIndicatorEnabled(config, "showInCombat") and not isPet then
      EnableElement(frame, "CombatIndicator", unit)
    else
      DisableElement(frame, "CombatIndicator")
      frame.CombatIndicator:Hide()
    end
  end

  if frame.PhaseIndicator then
    SetTexturePoint(
      frame.PhaseIndicator,
      statusPoint,
      statusRelativeTo,
      statusRelativePoint,
      statusX,
      statusY,
      statusSize
    )
    if frame.PhaseIndicator.Icon then
      frame.PhaseIndicator.Icon:SetAllPoints(frame.PhaseIndicator)
    end

    if IsIndicatorEnabled(config, "showPhase") and not isPet then
      EnableElement(frame, "PhaseIndicator", unit)
    else
      DisableElement(frame, "PhaseIndicator")
      frame.PhaseIndicator:Hide()
    end
  end

  if frame.ResurrectIndicator then
    SetTexturePoint(frame.ResurrectIndicator, statusPoint, statusRelativeTo, statusRelativePoint, statusX, statusY, statusSize)

    if IsIndicatorEnabled(config, "showCombatRes") and not isPet then
      EnableElement(frame, "ResurrectIndicator", unit)
    else
      DisableElement(frame, "ResurrectIndicator")
      frame.ResurrectIndicator:Hide()
    end
  end

  if frame.SummonIndicator then
    SetTexturePoint(frame.SummonIndicator, statusPoint, statusRelativeTo, statusRelativePoint, statusX, statusY, statusSize)

    if IsIndicatorEnabled(config, "showSummon") and not isPet then
      EnableElement(frame, "SummonIndicator", unit)
    else
      DisableElement(frame, "SummonIndicator")
      frame.SummonIndicator:Hide()
    end
  end

  if frame.ReadyCheckIndicator then
    local point = NormalizeSharedIconPoint(readyCheck.point, "BOTTOM")
    local relativeTo = readyCheck.relativeTo or frame.Health or frame
    local relativePoint = NormalizeSharedIconPoint(readyCheck.relativePoint, "BOTTOM")
    local x = tonumber(readyCheck.x) or 0
    local y = tonumber(readyCheck.y) or 2
    local size = tonumber(readyCheck.size) or 14

    SetTexturePoint(frame.ReadyCheckIndicator, point, relativeTo, relativePoint, x, y, size)

    if not IsIndicatorEnabled(config, "showReadyCheck") or isPet then
      DisableElement(frame, "ReadyCheckIndicator")
      if frame.ReadyCheckIndicator.Animation and frame.ReadyCheckIndicator.Animation:IsPlaying() then
        frame.ReadyCheckIndicator.Animation:Stop()
      end
      frame.ReadyCheckIndicator:SetAlpha(1)
      frame.ReadyCheckIndicator:Hide()
    else
      EnableElement(frame, "ReadyCheckIndicator", unit)
    end
  end

  frame.__puiIndicatorConfiguredConfig = config
  frame.__puiIndicatorConfiguredLayout = layout
  frame.__puiIndicatorConfiguredPet = isPet
end

local REFRESHABLE_INDICATOR_ELEMENTS = {
  "GroupRoleIndicator",
  "LeaderIndicator",
  "AssistantIndicator",
  "RaidRoleIndicator",
  "RaidTargetIndicator",
  "ReadyCheckIndicator",
  "CombatIndicator",
  "PhaseIndicator",
  "ResurrectIndicator",
  "SummonIndicator",
}

local INDICATOR_ELEMENT_GROUPS = {
  indicatorRaidRoleStrip = {
    "LeaderIndicator",
    "AssistantIndicator",
    "RaidRoleIndicator",
  },
  indicatorGroupRole = {
    "GroupRoleIndicator",
  },
  indicatorRaidTarget = {
    "RaidTargetIndicator",
  },
  indicatorStatus = {
    "ReadyCheckIndicator",
    "CombatIndicator",
    "PhaseIndicator",
    "ResurrectIndicator",
    "SummonIndicator",
  },
}

local function ForceUpdateIndicatorElements(frame, elementNames)
  for index = 1, #elementNames do
    local elementName = elementNames[index]
    local element = frame[elementName]
    if element and IsElementEnabled(frame, elementName) then
      element:ForceUpdate()
    end
  end
end

function UFIndicators.RefreshSharedUnitIndicators(frame, flags)
  if not frame then
    return
  end

  frame.__puiIndicatorConfig = nil
  frame.__puiIndicatorConfiguredConfig = nil
  frame.__puiIndicatorConfiguredLayout = nil
  frame.__puiIndicatorConfiguredPet = nil
  UFIndicators.ConfigureSharedUnitIndicators(frame, frame.__puiIndicatorLayout)

  local targeted = false

  if flags then
    for flag, elementNames in pairs(INDICATOR_ELEMENT_GROUPS) do
      if flags[flag] then
        targeted = true
        ForceUpdateIndicatorElements(frame, elementNames)
      end
    end
  end

  if not targeted then
    ForceUpdateIndicatorElements(frame, REFRESHABLE_INDICATOR_ELEMENTS)
  end
end

local RAID_GROUP_LABEL_OFFSET = 4
local RAID_GROUP_SIDE_LABEL_WIDTH = 26
local RAID_GROUP_SIDE_LABEL_OFFSET = 6

local function EnsureRaidGroupLabel(header)
  if not header then
    return nil
  end

  local label = header.__puiGroupLabel
  if label then
    return label
  end

  label = header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyFont(label, "body", 13, "OUTLINE")
  label:SetJustifyH("LEFT")
  label:SetTextColor(1, 1, 1, 0.95)

  header.__puiGroupLabel = label
  return label
end

local raidVisibleMemberOptions
local raidVisibleMemberFound = false

local function CheckRaidHeaderMember(frame)
  if raidVisibleMemberFound or not frame then
    return
  end

  local unit = raidVisibleMemberOptions.getCurrentUnit(frame)
  if unit and frame:IsShown() then
    raidVisibleMemberFound = true
  end
end

local function RaidHeaderHasVisibleMembers(header, opts)
  if not header then
    return false
  end

  raidVisibleMemberOptions = opts
  raidVisibleMemberFound = false
  opts.iterateHeaderChildren(header, CheckRaidHeaderMember)

  local found = raidVisibleMemberFound
  raidVisibleMemberOptions = nil
  raidVisibleMemberFound = false
  return found
end

function UFIndicators.UpdateRaidGroupLabels(owner, opts)
  if not owner then
    return
  end

  local db = opts.getProfile(owner)
  local raidWideSorting = db.lockMembersToGroup == false
  local showGroupNumbers = db.showGroupNumbers ~= false
  local orientation = opts.getGroupSortOrientation(db)
  local xDir = opts.getLayoutDirectionParts(db)

  if owner.header and owner.header.__puiGroupLabel then
    owner.header.__puiGroupLabel:Hide()
  end

  if type(owner.headers) ~= "table" then
    return
  end

  if raidWideSorting or not showGroupNumbers then
    for i = 1, #owner.headers do
      local header = owner.headers[i]
      local label = header and header.__puiGroupLabel or nil
      if label then
        label:Hide()
      end
    end
    return
  end

  local numGroups = opts.getEffectiveNumGroups(db)

  for i = 1, #owner.headers do
    local header = owner.headers[i]
    local label = header and header.__puiGroupLabel or nil

    if header and i <= numGroups and RaidHeaderHasVisibleMembers(header, opts) then
      label = label or EnsureRaidGroupLabel(header)

      local groupNumber = opts.getGroupNumber(owner, i, header)
      label:ClearAllPoints()
      label:SetWidth(0)

      if orientation == "HORIZONTAL" then
        label:SetWidth(Round(RAID_GROUP_SIDE_LABEL_WIDTH))

        if xDir == "LEFT" then
          label:SetJustifyH("LEFT")
          label:SetPoint(
            "LEFT",
            header,
            "RIGHT",
            Round(RAID_GROUP_SIDE_LABEL_OFFSET),
            0
          )
        else
          label:SetJustifyH("RIGHT")
          label:SetPoint(
            "RIGHT",
            header,
            "LEFT",
            -Round(RAID_GROUP_SIDE_LABEL_OFFSET),
            0
          )
        end

        label:SetText("G" .. tostring(groupNumber))
      else
        label:SetJustifyH("LEFT")
        label:SetPoint(
          "BOTTOMLEFT",
          header,
          "TOPLEFT",
          0,
          Round(RAID_GROUP_LABEL_OFFSET)
        )
        label:SetText("Group " .. tostring(groupNumber))
      end

      label:Show()
    elseif label then
      label:Hide()
    end
  end
end




  NormalizeSharedIconPoint = P:Def("NormalizeSharedIconPoint", NormalizeSharedIconPoint)
  GetSharedRoleIconDefaults = P:Def("GetSharedRoleIconDefaults", GetSharedRoleIconDefaults)
  BuildSharedRoleIconConfig = P:Def("BuildSharedRoleIconConfig", BuildSharedRoleIconConfig)
  GetFrameIndicatorConfig = P:Def("GetFrameIndicatorConfig", GetFrameIndicatorConfig)
  IsElementEnabled = P:Def("IsElementEnabled", IsElementEnabled)
  EnableElement = P:Def("EnableElement", EnableElement)
  DisableElement = P:Def("DisableElement", DisableElement)
  SetTexturePoint = P:Def("SetTexturePoint", SetTexturePoint)
  LayoutRaidRoleIndicators = P:Def("LayoutRaidRoleIndicators", LayoutRaidRoleIndicators)
  PostUpdateRaidRoleElement = P:Def("PostUpdateRaidRoleElement", PostUpdateRaidRoleElement)
  PostUpdateGroupRoleIndicator = P:Def("PostUpdateGroupRoleIndicator", PostUpdateGroupRoleIndicator)
  CreatePhaseIndicator = P:Def("CreatePhaseIndicator", CreatePhaseIndicator)
  UFIndicators.ConstructNativeStatusElements = P:Def("UFIndicators.ConstructNativeStatusElements", UFIndicators.ConstructNativeStatusElements)
  UFIndicators.EnsureSharedUnitIndicators = P:Def("UFIndicators.EnsureSharedUnitIndicators", UFIndicators.EnsureSharedUnitIndicators)
  UFIndicators.UpdateOfflinePresentation = P:Def("UFIndicators.UpdateOfflinePresentation", UFIndicators.UpdateOfflinePresentation)
  UFIndicators.ConfigureSharedUnitIndicators = P:Def("UFIndicators.ConfigureSharedUnitIndicators", UFIndicators.ConfigureSharedUnitIndicators)
  ForceUpdateIndicatorElements = P:Def("ForceUpdateIndicatorElements", ForceUpdateIndicatorElements)
  UFIndicators.RefreshSharedUnitIndicators = P:Def("UFIndicators.RefreshSharedUnitIndicators", UFIndicators.RefreshSharedUnitIndicators)
  EnsureRaidGroupLabel = P:Def("EnsureRaidGroupLabel", EnsureRaidGroupLabel)
  RaidHeaderHasVisibleMembers = P:Def("RaidHeaderHasVisibleMembers", RaidHeaderHasVisibleMembers)
  UFIndicators.UpdateRaidGroupLabels = P:Def("UFIndicators.UpdateRaidGroupLabels", UFIndicators.UpdateRaidGroupLabels)
  IsPetUnit = P:Def("IsPetUnit", IsPetUnit)
  IsIndicatorEnabled = P:Def("IsIndicatorEnabled", IsIndicatorEnabled)
  GetRaidRoleVisibilityMask = P:Def("GetRaidRoleVisibilityMask", GetRaidRoleVisibilityMask)
  CheckRaidHeaderMember = P:Def("CheckRaidHeaderMember", CheckRaidHeaderMember)
