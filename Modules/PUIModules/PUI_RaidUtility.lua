local ADDON_NAME, ns = ...
local Module = {}
ns.RaidUtilityModule = Module


local LibStub = _G.LibStub
local LCG = LibStub("LibCustomGlow-1.0")
local LibKeyBound = LibStub("LibKeyBound-1.0")
local P, TrackThis = ns.Pleebug:DropIn(Module, { name = "Modules.RaidUtility" })


local Addon = ns.Addon
local API = ns.QualityAPI
local Round = ns.Pixel.Round

local NormalizeDB = API.NormalizeDB
local Clamp = API.Clamp
local SeedAnchorDefaults = API.SeedAnchorDefaults

local POSITION_DEFAULTS = {
  bresLustWidget = {
    x = -300,
    y = -300,
  },
  raidUtilityButtons = {
    enabled = false,
    x = 300,
    y = -244,
  },
  raidUtilityRaidMarkers = {
    enabled = false,
    x = 300,
    y = -300,
  },
  raidUtilityWorldMarkers = {
    enabled = false,
    x = 300,
    y = -356,
  },
}

function Module.NormalizeDB(q)
  if q.bresWidgetEnable == nil then q.bresWidgetEnable = true end
  if q.lustWidgetEnable == nil then q.lustWidgetEnable = false end
  if q.bresLustWidgetShowOnlyInGroup == nil then q.bresLustWidgetShowOnlyInGroup = true end
  q.bresLustWidgetIconSize = Clamp(q.bresLustWidgetIconSize or 32, 16, 64)
  q.bresLustWidgetAnchor = SeedAnchorDefaults(q.bresLustWidgetAnchor, POSITION_DEFAULTS.bresLustWidget)

  if q.raidUtilityButtonsEnable == nil then
    q.raidUtilityButtonsEnable = POSITION_DEFAULTS.raidUtilityButtons.enabled
  end
  if q.raidUtilityRaidMarkersEnable == nil then
    q.raidUtilityRaidMarkersEnable = POSITION_DEFAULTS.raidUtilityRaidMarkers.enabled
  end
  if q.raidUtilityWorldMarkersEnable == nil then
    q.raidUtilityWorldMarkersEnable = POSITION_DEFAULTS.raidUtilityWorldMarkers.enabled
  end

  if q.raidUtilityShowOnlyInGroup == nil then q.raidUtilityShowOnlyInGroup = true end
  q.raidUtilityPullTimerSeconds = Clamp(q.raidUtilityPullTimerSeconds or 10, 1, 60)
  q.raidUtilityExtraPullTimers = q.raidUtilityExtraPullTimers or {}
  if type(q.raidUtilityExtraPullTimers) ~= "table" then
    q.raidUtilityExtraPullTimers = {}
  end

  do
    local cleaned = {}
    for i, v in ipairs(q.raidUtilityExtraPullTimers) do
      local n = tonumber(v)
      if n then
        cleaned[#cleaned + 1] = Clamp(n, 1, 60)
      end
    end
    q.raidUtilityExtraPullTimers = cleaned
  end

  if q.raidUtilityButtonsHideInCombat == nil then q.raidUtilityButtonsHideInCombat = true end
  if q.raidUtilityButtonsMouseover == nil then q.raidUtilityButtonsMouseover = false end
  if q.raidUtilityButtonsFreeMove == nil then q.raidUtilityButtonsFreeMove = false end
  q.raidUtilityButtonsAlpha = Clamp(q.raidUtilityButtonsAlpha or 1, 0, 1)
  q.raidUtilityButtonsFadeOutAlpha = Clamp(q.raidUtilityButtonsFadeOutAlpha or 0, 0, 1)
  q.raidUtilityButtonsFadeOutDuration = Clamp(q.raidUtilityButtonsFadeOutDuration or 0, 0, 10)

  if q.raidUtilityRaidMarkersHideInCombat == nil then q.raidUtilityRaidMarkersHideInCombat = false end
  if q.raidUtilityRaidMarkersMouseover == nil then q.raidUtilityRaidMarkersMouseover = false end
  if q.raidUtilityRaidMarkersFreeMove == nil then q.raidUtilityRaidMarkersFreeMove = false end
  q.raidUtilityRaidMarkersAlpha = Clamp(q.raidUtilityRaidMarkersAlpha or 1, 0, 1)
  q.raidUtilityRaidMarkersFadeOutAlpha = Clamp(q.raidUtilityRaidMarkersFadeOutAlpha or 0, 0, 1)
  q.raidUtilityRaidMarkersFadeOutDuration = Clamp(q.raidUtilityRaidMarkersFadeOutDuration or 0, 0, 10)
  q.raidUtilityRaidMarkerButtonSize = Clamp(q.raidUtilityRaidMarkerButtonSize or 22, 18, 40)

  if q.raidUtilityWorldMarkersHideInCombat == nil then q.raidUtilityWorldMarkersHideInCombat = false end
  if q.raidUtilityWorldMarkersMouseover == nil then q.raidUtilityWorldMarkersMouseover = false end
  if q.raidUtilityWorldMarkersFreeMove == nil then q.raidUtilityWorldMarkersFreeMove = false end
  q.raidUtilityWorldMarkersAlpha = Clamp(q.raidUtilityWorldMarkersAlpha or 1, 0, 1)
  q.raidUtilityWorldMarkersFadeOutAlpha = Clamp(q.raidUtilityWorldMarkersFadeOutAlpha or 0, 0, 1)
  q.raidUtilityWorldMarkersFadeOutDuration = Clamp(q.raidUtilityWorldMarkersFadeOutDuration or 0, 0, 10)
  q.raidUtilityWorldMarkerButtonSize = Clamp(q.raidUtilityWorldMarkerButtonSize or 22, 18, 40)

  q.raidUtilityButtonsAnchor = SeedAnchorDefaults(q.raidUtilityButtonsAnchor, POSITION_DEFAULTS.raidUtilityButtons)
  q.raidUtilityRaidMarkersAnchor = SeedAnchorDefaults(q.raidUtilityRaidMarkersAnchor, POSITION_DEFAULTS.raidUtilityRaidMarkers)
  q.raidUtilityWorldMarkersAnchor = SeedAnchorDefaults(q.raidUtilityWorldMarkersAnchor, POSITION_DEFAULTS.raidUtilityWorldMarkers)
end

local BRLWidgetFrame
local BRLWidgetGhostMover
local BRLWidgetBres
local BRLWidgetLust
local BRLWidgetEvents
local BRLWidgetConfig
local BRLWidget_UpdateGhostMover
local BresLustWidget_UpdateLustDisplay
local BresLustWidget_Refresh

local BRL_BRES_SPELL_ID = 20484

local BRL_SATED_IDS = { 57723, 57724, 80354, 95809, 160455, 264689, 390435, 428628 }

local BRL_ICON_GAP = 6
local BRL_ICON_BRES = 136080
local BRL_ICON_LUST = 136012
local BRL_LUST_DURATION = 40
local BRL_LUST_GLOW_KEY = "PleebUIBloodlust"
local BRL_LUST_GLOW_COLOR = { 1, 0.82, 0, 1 }
local BRL_LUST_GLOW_LINES = 8
local BRL_LUST_GLOW_FREQUENCY = 0.25
local BRL_LUST_GLOW_THICKNESS = 2

local BRLLustTimer

local BRLState = {
  lustWindowExpiration = 0,
  sated = false,
  satedSpellID = nil,
  satedExpiration = 0,
  satedDuration = 0,
}

local function BRL_StopLustWindow()
  if BRLLustTimer then
    BRLLustTimer:Cancel()
    BRLLustTimer = nil
  end

  BRLState.lustWindowExpiration = 0

  if BRLWidgetLust then
    LCG.PixelGlow_Stop(BRLWidgetLust, BRL_LUST_GLOW_KEY)
  end
end

local function BRL_StartLustWindow()
  BRL_StopLustWindow()

  local now = GetTime()
  BRLState.lustWindowExpiration = now + BRL_LUST_DURATION

  LCG.PixelGlow_Start(
    BRLWidgetLust,
    BRL_LUST_GLOW_COLOR,
    BRL_LUST_GLOW_LINES,
    BRL_LUST_GLOW_FREQUENCY,
    nil,
    BRL_LUST_GLOW_THICKNESS,
    0,
    0,
    true,
    BRL_LUST_GLOW_KEY,
    BRLWidgetLust:GetFrameLevel() + 8
  )

  BRLLustTimer = C_Timer.NewTimer(BRL_LUST_DURATION, function()
    BRLLustTimer = nil
    BRLState.lustWindowExpiration = 0
    LCG.PixelGlow_Stop(BRLWidgetLust, BRL_LUST_GLOW_KEY)
    BresLustWidget_UpdateLustDisplay()
  end)
end




local function BRL_CreateIcon(parent, textureID)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(32, 32)

  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(textureID)
  f.icon = tex

  local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  cd:SetAllPoints()
  f.cooldown = cd

  ns.IconSkin.MakeIconSquare(f, { crop = 0.08 })
  ns.IconSkin.SquareCooldown(cd)
  ns.IconSkin.ApplyBorder(f, {
    enabled = true,
    thickness = 2,
    useThemeColor = true,
  })

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  count:SetJustifyH("RIGHT")
  count:SetText("")
  f.countText = count

  return f
end

local function EnsureBresLustWidget()
  if BRLWidgetFrame then return BRLWidgetFrame end

  local q = NormalizeDB()
  local d = POSITION_DEFAULTS.bresLustWidget
  q.bresLustWidgetAnchor = SeedAnchorDefaults(q.bresLustWidgetAnchor, d)

  local f = CreateFrame("Frame", "PleebUI_BresLustWidget", UIParent)
  BRLWidgetFrame = f
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(20)
  f:SetMovable(false)
  f:EnableMouse(false)

  BRLWidgetBres = BRL_CreateIcon(f, BRL_ICON_BRES)
  BRLWidgetLust = BRL_CreateIcon(f, BRL_ICON_LUST)

  local function ApplyAnchor()
    local qq = NormalizeDB()
    local a = qq.bresLustWidgetAnchor or d
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x or d.x, a.y or d.y)
  end

  local function ApplyLayout()
    local qq = NormalizeDB()
    local size = Round(Clamp(qq.bresLustWidgetIconSize or 32, 16, 64))
    local showBres = not not qq.bresWidgetEnable
    local showLust = not not qq.lustWidgetEnable
    local previous
    local iconCount = 0

    BRLWidgetBres:ClearAllPoints()
    BRLWidgetBres:SetSize(size, size)
    BRLWidgetBres:SetShown(showBres)
    if showBres then
      BRLWidgetBres:SetPoint("LEFT", f, "LEFT", 0, 0)
      previous = BRLWidgetBres
      iconCount = iconCount + 1
    end

    BRLWidgetLust:ClearAllPoints()
    BRLWidgetLust:SetSize(size, size)
    BRLWidgetLust:SetShown(showLust)
    if showLust then
      if previous then
        BRLWidgetLust:SetPoint("LEFT", previous, "RIGHT", BRL_ICON_GAP, 0)
      else
        BRLWidgetLust:SetPoint("LEFT", f, "LEFT", 0, 0)
      end
      iconCount = iconCount + 1
    end

    if iconCount > 0 then
      f:SetSize((size * iconCount) + (BRL_ICON_GAP * (iconCount - 1)), size)
    else
      f:SetSize(size, size)
    end

    ApplyAnchor()
  end

  f.__puiApplyLayout = ApplyLayout
  f.__puiApplyAnchor = ApplyAnchor

  ApplyLayout()
  BRLWidget_UpdateGhostMover()
  return f
end

BRLWidget_UpdateGhostMover = function()
  if not BRLWidgetFrame then
    return
  end

  local q = NormalizeDB()
  local d = POSITION_DEFAULTS.bresLustWidget

  local function SavePosition(frame)
    local qq = NormalizeDB()
    qq.bresLustWidgetAnchor = qq.bresLustWidgetAnchor or {}
    local gx, gy = ns.FrameUtil.GetMoverOffsets(frame)

    qq.bresLustWidgetAnchor.x = math.floor((gx or 0) + 0.5)
    qq.bresLustWidgetAnchor.y = math.floor((gy or 0) + 0.5)

    if BRLWidgetFrame and BRLWidgetFrame.__puiApplyAnchor then
      BRLWidgetFrame.__puiApplyAnchor()
    end
  end

  BRLWidgetGhostMover = ns.FrameUtil:EnsureGhostMover("quality_bres_lust_widget", {
    frameName = "PleebUI_BresLustWidgetGhostMover",
    label = "Battle resurrection and Bloodlust",
    liveFrame = BRLWidgetFrame,
    useOverlayDrag = false,
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        local q = NormalizeDB()
        return q.bresWidgetEnable == true or q.lustWidgetEnable == true
      end,
    },
    fallbackAnchor = {
      point = "CENTER",
      relativeTo = UIParent,
      relativePoint = "CENTER",
      x = q.bresLustWidgetAnchor.x or d.x,
      y = q.bresLustWidgetAnchor.y or d.y,
    },
    shouldShow = function()
      local qq = NormalizeDB()
      if not qq.bresWidgetEnable and not qq.lustWidgetEnable then
        return false
      end

      return ns.Flags.IsEditing and true or false
    end,
    optionsString = "Quality,qualityTab",
    savePosition = SavePosition,
    onDragStop = function()
      BRLWidget_UpdateGhostMover()
    end,
    resetPosition = function()
      local qq = NormalizeDB()
      qq.bresLustWidgetAnchor = SeedAnchorDefaults(nil, d)
      if BRLWidgetFrame and BRLWidgetFrame.__puiApplyAnchor then
        BRLWidgetFrame.__puiApplyAnchor()
      end
      BRLWidget_UpdateGhostMover()
    end,
    quickSettings = function()
      local qq = NormalizeDB()
      return {
        ownerKey = "quality_bres_lust_widget",
        title = "Battle resurrection and Bloodlust",
        description = "Live widget settings.",
        controls = {
          {
            type = "slider",
            label = "Icon size",
            min = 16,
            max = 64,
            step = 1,
            get = function() return qq.bresLustWidgetIconSize end,
            set = function(value)
              qq.bresLustWidgetIconSize = Clamp(value, 16, 64)
              BRLWidgetFrame.__puiApplyLayout()
              BRLWidget_UpdateGhostMover()
            end,
          },
        },
      }
    end,
  })
end

local function BresLustWidget_UpdateBresDisplay()
  BRLWidgetBres.icon:SetDesaturated(false)
  BRLWidgetBres.countText:Show()
  BRLWidgetBres.countText:SetText(C_Spell.GetSpellDisplayCount(BRL_BRES_SPELL_ID))

  local durationObject = C_Spell.GetSpellChargeDuration(BRL_BRES_SPELL_ID)
  if durationObject then
    BRLWidgetBres.cooldown:SetCooldownFromDurationObject(durationObject, true)
  else
    BRLWidgetBres.cooldown:Clear()
  end
end

local function BresLustWidget_FindSatedAura()
  local currentSpellID = BRLState.satedSpellID
  if currentSpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(currentSpellID)
    if aura then
      return aura, currentSpellID
    end
  end

  for i = 1, #BRL_SATED_IDS do
    local spellID = BRL_SATED_IDS[i]
    if spellID ~= currentSpellID then
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
      if aura then
        return aura, spellID
      end
    end
  end
end

BresLustWidget_UpdateLustDisplay = function()
  local now = GetTime()

  if BRLState.lustWindowExpiration > now then
    BRLWidgetLust.icon:SetDesaturated(false)
    BRLWidgetLust.cooldown:SetCooldown(
      BRLState.lustWindowExpiration - BRL_LUST_DURATION,
      BRL_LUST_DURATION
    )
    return
  end

  if BRLState.lustWindowExpiration > 0 then
    BRL_StopLustWindow()
  end

  if BRLState.sated then
    BRLWidgetLust.icon:SetDesaturated(true)

    if BRLState.satedExpiration > 0 and BRLState.satedDuration > 0 then
      BRLWidgetLust.cooldown:SetCooldown(
        BRLState.satedExpiration - BRLState.satedDuration,
        BRLState.satedDuration
      )
    else
      BRLWidgetLust.cooldown:Clear()
    end
    return
  end

  BRLWidgetLust.icon:SetDesaturated(false)
  BRLWidgetLust.cooldown:Clear()
end

local function BresLustWidget_SyncSatedState(startLustOnGain, forceDisplay)
  local aura, spellID = BresLustWidget_FindSatedAura()
  local wasSated = BRLState.sated
  local isSated = aura ~= nil

  if isSated == wasSated and not forceDisplay then
    return false
  end

  BRLState.sated = isSated
  BRLState.satedSpellID = spellID

  if isSated then
    BRLState.satedExpiration = aura.expirationTime or 0
    BRLState.satedDuration = aura.duration or 0
  else
    BRLState.satedExpiration = 0
    BRLState.satedDuration = 0
  end

  if startLustOnGain and isSated and not wasSated then
    BRL_StartLustWindow()
  end

  BresLustWidget_UpdateLustDisplay()
  return isSated ~= wasSated
end

local function BresLustWidget_OnPlayerAuraChanged()
  if not BRLWidgetConfig or not BRLWidgetConfig.lustWidgetEnable then
    return
  end

  if BRLWidgetConfig.bresLustWidgetShowOnlyInGroup and not IsInGroup() then
    return
  end

  BresLustWidget_SyncSatedState(true, false)
end

BresLustWidget_Refresh = function(updateBres, updateLust)
  if updateBres == nil and updateLust == nil then
    updateBres = true
    updateLust = true
  end

  if not BRLWidgetConfig then
    BRLWidgetConfig = NormalizeDB()
  end

  local q = BRLWidgetConfig
  local f = BRLWidgetFrame or EnsureBresLustWidget()

  if not q.bresWidgetEnable and not q.lustWidgetEnable then
    f:Hide()
    return
  end

  if q.bresLustWidgetShowOnlyInGroup and not IsInGroup() then
    f:Hide()
    return
  end

  if q.bresWidgetEnable and updateBres then
    BresLustWidget_UpdateBresDisplay()
  end

  if q.lustWidgetEnable and updateLust then
    BresLustWidget_SyncSatedState(false, true)
  end

  f:Show()
end

local function EnsureBresLustWidgetEvents(enableBres, enableLust)
  if not BRLWidgetEvents then
    BRLWidgetEvents = CreateFrame("Frame", "PleebUI_QualityBresLustEvents")
    BRLWidgetEvents:SetScript("OnEvent", function(_, event)
      if event == "UNIT_AURA" then
        BresLustWidget_OnPlayerAuraChanged()
        return
      end

      if event == "SPELL_UPDATE_CHARGES" then
        BresLustWidget_Refresh(true, false)
        return
      end

      if event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "TRAIT_CONFIG_UPDATED"
      then
        BresLustWidget_Refresh(true, false)
        return
      end

      if event == "PLAYER_DEAD" then
        BRL_StopLustWindow()
        BresLustWidget_Refresh(false, true)
        return
      end

      BresLustWidget_Refresh()
    end)
  end

  enableBres = not not enableBres
  enableLust = not not enableLust

  if BRLWidgetEvents.__puiBresEventsEnabled == enableBres
    and BRLWidgetEvents.__puiLustEventsEnabled == enableLust
  then
    return BRLWidgetEvents
  end

  BRLWidgetEvents:UnregisterAllEvents()
  BRLWidgetEvents.__puiBresEventsEnabled = enableBres
  BRLWidgetEvents.__puiLustEventsEnabled = enableLust

  if not enableLust then
    BRL_StopLustWindow()
    BRLState.sated = false
    BRLState.satedSpellID = nil
    BRLState.satedExpiration = 0
    BRLState.satedDuration = 0
  end

  if not enableBres and not enableLust then
    return BRLWidgetEvents
  end

  BRLWidgetEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
  BRLWidgetEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
  BRLWidgetEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  BRLWidgetEvents:RegisterEvent("ENCOUNTER_START")
  BRLWidgetEvents:RegisterEvent("ENCOUNTER_END")
  BRLWidgetEvents:RegisterEvent("CHALLENGE_MODE_START")
  BRLWidgetEvents:RegisterEvent("CHALLENGE_MODE_COMPLETED")

  if enableBres then
    BRLWidgetEvents:RegisterEvent("SPELL_UPDATE_CHARGES")
    BRLWidgetEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    BRLWidgetEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
    BRLWidgetEvents:RegisterEvent("TRAIT_CONFIG_UPDATED")
  end

  if enableLust then
    BRLWidgetEvents:RegisterUnitEvent("UNIT_AURA", "player")
    BRLWidgetEvents:RegisterEvent("PLAYER_DEAD")
  end

  return BRLWidgetEvents
end

local function ApplyBresLustWidget()
  BRLWidgetConfig = NormalizeDB()
  local f = EnsureBresLustWidget()

  if f.__puiApplyLayout then
    f.__puiApplyLayout()
  end

  BRLWidget_UpdateGhostMover()
  EnsureBresLustWidgetEvents(BRLWidgetConfig.bresWidgetEnable, BRLWidgetConfig.lustWidgetEnable)
  BresLustWidget_Refresh()
end

local RaidUtilityFrames = {}
local RaidUtilityGhostMovers = {}
local RaidUtilityEvents
local RaidUtilityPendingRefresh = false
local RaidUtilityDragState

local function RaidUtility_InRestrictedInstance()
  local _, instanceType = IsInInstance()
  return instanceType == "pvp" or instanceType == "arena"
end

local function RaidUtility_InGroup()
  return IsInGroup() and not RaidUtility_InRestrictedInstance()
end

local function RaidUtility_IsRaidMarkerRole()
  if not IsInRaid() then
    return false
  end

  if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
    return true
  end

  if GetPartyAssignment("MAINTANK", "player", true) or GetPartyAssignment("MAINASSIST", "player", true) then
    return true
  end

  return false
end

local function RaidUtility_HasPermission()
  if not RaidUtility_InGroup() then
    return false
  end

  if not IsInRaid() then
    return true
  end

  return RaidUtility_IsRaidMarkerRole()
end

local function RaidUtility_ShouldShowFrame()
  local q = NormalizeDB()
  if q.raidUtilityShowOnlyInGroup then
    return RaidUtility_HasPermission()
  end

  return not RaidUtility_InRestrictedInstance()
end

local RAID_MARKER_NAMES = {
  [0] = "Clear",
  [1] = "Star",
  [2] = "Circle",
  [3] = "Diamond",
  [4] = "Triangle",
  [5] = "Moon",
  [6] = "Square",
  [7] = "Cross",
  [8] = "Skull",
}

local RAID_UTILITY_WINDOW_ORDER = {
  "buttons",
  "raidMarkers",
  "worldMarkers",
}

local RAID_UTILITY_WINDOW_SPECS = {
  buttons = {
    title = "Pull / ready check buttons",
    moverKey = "quality_raid_utility_buttons",
    frameName = "PleebUI_RaidUtilityButtons",
    ghostFrameName = "PleebUI_RaidUtilityButtonsGhostMover",
    enabledKey = "raidUtilityButtonsEnable",
    anchorKey = "raidUtilityButtonsAnchor",
    hideInCombatKey = "raidUtilityButtonsHideInCombat",
    mouseoverKey = "raidUtilityButtonsMouseover",
    freeMoveKey = "raidUtilityButtonsFreeMove",
    alphaKey = "raidUtilityButtonsAlpha",
    fadeOutAlphaKey = "raidUtilityButtonsFadeOutAlpha",
    fadeOutDurationKey = "raidUtilityButtonsFadeOutDuration",
    defaults = POSITION_DEFAULTS.raidUtilityButtons,
  },
  raidMarkers = {
    title = "Raid Markers",
    moverKey = "quality_raid_utility_raid_markers",
    frameName = "PleebUI_RaidUtilityRaidMarkers",
    ghostFrameName = "PleebUI_RaidUtilityRaidMarkersGhostMover",
    enabledKey = "raidUtilityRaidMarkersEnable",
    anchorKey = "raidUtilityRaidMarkersAnchor",
    hideInCombatKey = "raidUtilityRaidMarkersHideInCombat",
    mouseoverKey = "raidUtilityRaidMarkersMouseover",
    freeMoveKey = "raidUtilityRaidMarkersFreeMove",
    alphaKey = "raidUtilityRaidMarkersAlpha",
    fadeOutAlphaKey = "raidUtilityRaidMarkersFadeOutAlpha",
    fadeOutDurationKey = "raidUtilityRaidMarkersFadeOutDuration",
    buttonSizeKey = "raidUtilityRaidMarkerButtonSize",
    defaults = POSITION_DEFAULTS.raidUtilityRaidMarkers,
  },
  worldMarkers = {
    title = "World Markers",
    moverKey = "quality_raid_utility_world_markers",
    frameName = "PleebUI_RaidUtilityWorldMarkers",
    ghostFrameName = "PleebUI_RaidUtilityWorldMarkersGhostMover",
    enabledKey = "raidUtilityWorldMarkersEnable",
    anchorKey = "raidUtilityWorldMarkersAnchor",
    hideInCombatKey = "raidUtilityWorldMarkersHideInCombat",
    mouseoverKey = "raidUtilityWorldMarkersMouseover",
    freeMoveKey = "raidUtilityWorldMarkersFreeMove",
    alphaKey = "raidUtilityWorldMarkersAlpha",
    fadeOutAlphaKey = "raidUtilityWorldMarkersFadeOutAlpha",
    fadeOutDurationKey = "raidUtilityWorldMarkersFadeOutDuration",
    buttonSizeKey = "raidUtilityWorldMarkerButtonSize",
    defaults = POSITION_DEFAULTS.raidUtilityWorldMarkers,
  },
}

for index = 1, 8 do
  _G["BINDING_NAME_CLICK PUI_WM" .. index .. ":LeftButton"] =
    "Place " .. RAID_MARKER_NAMES[index] .. " world marker"
end
_G["BINDING_NAME_CLICK PUI_CWM:LeftButton"] = "Clear all world markers"


local RaidUtilityPullTimerPopup
local RaidUtilityExtraButtons = {}
local RaidUtilityPopupTargetKind = "main"
local RaidUtilityPopupTargetIndex = nil
local RaidUtility_SetTooltip
local RaidUtility_CreateTextButton
local RaidUtility_EnsureExtraButtons
local RaidUtility_AttachWindowMouseover
local RaidUtility_UpdateLayout
local RaidUtility_UpdateGhostMovers
local RaidUtility_ShowDragGhosts
local RaidUtility_HideDragGhosts
local RaidUtility_CancelWindowDrag
local RaidUtility_Refresh
local ApplyRaidUtility

local function RaidUtility_GetExtraPullTimers()
  local q = NormalizeDB()
  q.raidUtilityExtraPullTimers = q.raidUtilityExtraPullTimers or {}
  return q.raidUtilityExtraPullTimers
end

local function RaidUtility_GetPullTimerSeconds(extraIndex)
  if extraIndex then
    local timers = RaidUtility_GetExtraPullTimers()
    return Clamp(tonumber(timers[extraIndex]) or 10, 1, 60)
  end

  local q = NormalizeDB()
  return Clamp(q.raidUtilityPullTimerSeconds or 10, 1, 60)
end

local function RaidUtility_FormatPullButtonText(seconds)
  return string.format("Pull (%d Sec)", Clamp(tonumber(seconds) or 10, 1, 60))
end

local function RaidUtility_GetMarkerButtonSize(kind)
  local q = NormalizeDB()
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  return Round(Clamp(q[spec.buttonSizeKey] or 22, 18, 40))
end

local function RaidUtility_Scaled(value)
  return math.max(Round(1), Round(tonumber(value) or 0))
end

local function RaidUtility_UpdatePullButtonText()
  local frame = RaidUtilityFrames.buttons
  if frame and frame.buttons and frame.buttons.count then
    frame.buttons.count:SetText(RaidUtility_FormatPullButtonText(RaidUtility_GetPullTimerSeconds()))
  end

  local timers = RaidUtility_GetExtraPullTimers()
  for i, button in ipairs(RaidUtilityExtraButtons) do
    if button and timers[i] then
      button:SetText(RaidUtility_FormatPullButtonText(timers[i]))
    end
  end
end

local function RaidUtility_SetPullTimerSeconds(seconds, extraIndex)
  local value = Clamp(tonumber(seconds) or 10, 1, 60)
  local q = NormalizeDB()

  if extraIndex then
    local timers = RaidUtility_GetExtraPullTimers()
    timers[extraIndex] = value
  else
    q.raidUtilityPullTimerSeconds = value
  end

  RaidUtility_UpdatePullButtonText()

  return value
end

local function RaidUtility_AddExtraPullTimer()
  local q = NormalizeDB()
  local seconds = Clamp(q.raidUtilityPullTimerSeconds or 10, 1, 60)
  local timers = q.raidUtilityExtraPullTimers
  local newIndex = #timers + 1
  timers[newIndex] = seconds

  if InCombatLockdown() then
    RaidUtilityPendingRefresh = true
    local frame = RaidUtilityFrames.buttons
    if frame and frame.buttons and frame.buttons.add then
      frame.buttons.add:SetEnabled(false)
    end
    return
  end

  if not RaidUtilityFrames.buttons then
    ApplyRaidUtility()
    return
  end

  RaidUtility_EnsureExtraButtons()
  RaidUtility_UpdateLayout()
  RaidUtility_UpdatePullButtonText()

  if RaidUtilityExtraButtons[newIndex] then
    RaidUtilityExtraButtons[newIndex]._puiExtraPullIndex = newIndex
    RaidUtilityExtraButtons[newIndex]:Show()
  end

  RaidUtilityFrames.buttons:Show()
  RaidUtility_Refresh()
end

local function RaidUtility_DeleteExtraPullTimer(extraIndex)
  local timers = RaidUtility_GetExtraPullTimers()
  if extraIndex and timers[extraIndex] then
    table.remove(timers, extraIndex)

    if InCombatLockdown() then
      RaidUtilityPendingRefresh = true
      return
    end

    ApplyRaidUtility()
  end
end

local function RaidUtility_RunPullCommand(seconds)
  local slashFn = SlashCmdList and (SlashCmdList.pull or SlashCmdList.PULL or SlashCmdList.BIGWIGSPULL or SlashCmdList.DRT_PULL or SlashCmdList.DEADLYBOSSMODSPULL)
  if type(slashFn) == "function" then
    slashFn(tostring(seconds))
    return true
  end

  return false
end

local function RaidUtility_StartPullTimer(seconds)
  seconds = Clamp(tonumber(seconds) or RaidUtility_GetPullTimerSeconds(), 1, 60)

  if not RaidUtility_InGroup() then
    return
  end

  if RaidUtility_RunPullCommand(seconds) then
    return
  end

  C_PartyInfo.DoCountdown(seconds)
end

local function RaidUtility_CancelPullTimer()
  if not RaidUtility_InGroup() then
    return
  end

  if RaidUtility_RunPullCommand(0) then
    return
  end

  C_PartyInfo.DoCountdown(0)
end

local function RaidUtility_GetPopupSeconds()
  if RaidUtilityPopupTargetKind == "extra" and RaidUtilityPopupTargetIndex then
    return RaidUtility_GetPullTimerSeconds(RaidUtilityPopupTargetIndex)
  end

  return RaidUtility_GetPullTimerSeconds()
end

local function RaidUtility_CommitPopupSeconds(seconds)
  if RaidUtilityPopupTargetKind == "extra" and RaidUtilityPopupTargetIndex then
    return RaidUtility_SetPullTimerSeconds(seconds, RaidUtilityPopupTargetIndex)
  end

  return RaidUtility_SetPullTimerSeconds(seconds)
end

local function RaidUtility_EnsurePullTimerPopup()
  if RaidUtilityPullTimerPopup and RaidUtilityPullTimerPopup.editBox then
    return RaidUtilityPullTimerPopup
  end

  local popup = RaidUtilityPullTimerPopup
  if not popup then
    popup = CreateFrame("Frame", "PleebUI_RaidUtilityPullTimerPopup", UIParent, "BackdropTemplate")
    RaidUtilityPullTimerPopup = popup
  end

  popup:SetFrameStrata("TOOLTIP")
  popup:SetFrameLevel(200)
  popup:SetSize(176, 58)
  popup:SetClampedToScreen(true)
  popup:Hide()

  ns.Theme.WidgetSkins.Frame(popup)

  if not popup.label then
    popup.label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.label:SetText("Pull timer length")
  end
  popup.label:ClearAllPoints()
  popup.label:SetPoint("TOP", popup, "TOP", 0, -8)
  ns.Theme.ApplyFont(popup.label, "body")

  if not popup.editBox then
    popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.editBox:SetAutoFocus(false)
    if popup.editBox.SetNumeric then
      popup.editBox:SetNumeric(true)
    end
    popup.editBox:SetMaxLetters(2)

    popup.editBox:SetScript("OnEnterPressed", function(self)
      local seconds = tonumber(self:GetText() or "")
      if seconds then
        RaidUtility_CommitPopupSeconds(seconds)
      end
      popup:Hide()
      self:ClearFocus()
    end)

    popup.editBox:SetScript("OnEscapePressed", function(self)
      popup:Hide()
      self:ClearFocus()
    end)
  end

  popup.editBox:SetSize(48, 22)
  popup.editBox:SetJustifyH("CENTER")

  ns.Theme.WidgetSkins.UIEditBox(popup.editBox)

  if not popup.okay then
    popup.okay = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.okay:SetScript("OnClick", function()
      local seconds = popup.editBox and tonumber(popup.editBox:GetText() or "")
      if seconds then
        RaidUtility_CommitPopupSeconds(seconds)
      end
      popup:Hide()
    end)
  end
  popup.okay:SetText("Okay")
  popup.okay:SetSize(72, 22)
  ns.Theme.WidgetSkins.Button(popup.okay)

  if not popup.delete then
    popup.delete = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.delete:SetScript("OnClick", function()
      if RaidUtilityPopupTargetKind == "extra" and RaidUtilityPopupTargetIndex then
        RaidUtility_DeleteExtraPullTimer(RaidUtilityPopupTargetIndex)
      end
      popup:Hide()
    end)
  end
  popup.delete:SetText("Delete")
  popup.delete:SetSize(92, 22)
  ns.Theme.WidgetSkins.Button(popup.delete)

  if not popup.cancel then
    popup.cancel = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.cancel:SetScript("OnClick", function()
      popup:Hide()
    end)
  end
  popup.cancel:SetText("Cancel")
  popup.cancel:SetSize(92, 22)
  ns.Theme.WidgetSkins.Button(popup.cancel)

  return popup
end

local function RaidUtility_ShowPullTimerDialog(targetKind, targetIndex, anchorOverride)
  local popup = RaidUtility_EnsurePullTimerPopup()
  local frame = RaidUtilityFrames.buttons
  local anchor = anchorOverride or (frame and frame.buttons and frame.buttons.count)
  local showDelete = targetKind == "extra" and targetIndex and RaidUtility_GetExtraPullTimers()[targetIndex]

  RaidUtilityPopupTargetKind = targetKind or "main"
  RaidUtilityPopupTargetIndex = targetIndex

  popup:SetSize(showDelete and RaidUtility_Scaled(372) or RaidUtility_Scaled(252), RaidUtility_Scaled(58))

  popup:ClearAllPoints()
  if anchor then
    popup:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
  else
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  popup.editBox:ClearAllPoints()
  popup.okay:ClearAllPoints()
  popup.delete:ClearAllPoints()
  popup.cancel:ClearAllPoints()

  if showDelete then
    popup.okay:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 10, 8)
    popup.delete:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -10, 8)
    popup.cancel:SetPoint("RIGHT", popup.delete, "LEFT", -8, 0)
    popup.editBox:SetPoint("LEFT", popup.okay, "RIGHT", 8, 0)
    popup.editBox:SetPoint("RIGHT", popup.cancel, "LEFT", -8, 0)
    popup.delete:Show()
  else
    popup.okay:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 10, 8)
    popup.cancel:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -10, 8)
    popup.editBox:SetPoint("LEFT", popup.okay, "RIGHT", 8, 0)
    popup.editBox:SetPoint("RIGHT", popup.cancel, "LEFT", -8, 0)
    popup.delete:Hide()
  end

  if popup.editBox then
    popup.editBox:SetText(tostring(RaidUtility_GetPopupSeconds()))
    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
  else
    popup:Show()
  end
end

RaidUtility_EnsureExtraButtons = function()
  local frame = RaidUtilityFrames.buttons
  if not frame then return end

  local timers = RaidUtility_GetExtraPullTimers()

  for i = 1, #timers do
    local button = RaidUtilityExtraButtons[i]
    if not button then
      button = RaidUtility_CreateTextButton(frame, RaidUtility_FormatPullButtonText(timers[i]), 120, function(self, mouseButton)
        local extraIndex = self._puiExtraPullIndex
        if mouseButton == "RightButton" then
          RaidUtility_ShowPullTimerDialog("extra", extraIndex, self)
        else
          RaidUtility_StartPullTimer(RaidUtility_GetPullTimerSeconds(extraIndex))
        end
      end)
      RaidUtility_SetTooltip(button, "Extra pull timer", "Left-click to start it.\nRight-click to change or delete it.")
      RaidUtility_AttachWindowMouseover(button, "buttons")
      RaidUtilityExtraButtons[i] = button
    end

    button._puiExtraPullIndex = i
    button:Show()
  end

  for i = #timers + 1, #RaidUtilityExtraButtons do
    local button = RaidUtilityExtraButtons[i]
    if button then
      button:Hide()
    end
  end

  RaidUtility_UpdatePullButtonText()
end

local function RaidUtility_ApplyAnchor(kind)
  local frame = RaidUtilityFrames[kind]
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  if not frame or not spec then return end

  local q = NormalizeDB()
  local anchor = q[spec.anchorKey] or spec.defaults

  frame:ClearAllPoints()
  frame:SetPoint(
    "CENTER",
    UIParent,
    "CENTER",
    anchor.x or spec.defaults.x,
    anchor.y or spec.defaults.y
  )
end

local function RaidUtility_StoreAnchor(kind, sourceFrame)
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  if not spec or not sourceFrame then return end

  local q = NormalizeDB()
  local x, y = ns.FrameUtil.GetMoverOffsets(sourceFrame)
  q[spec.anchorKey] = {
    x = math.floor((x or 0) + 0.5),
    y = math.floor((y or 0) + 0.5),
  }
end

local function RaidUtility_SaveAnchors()
  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    RaidUtility_StoreAnchor(kind, RaidUtilityGhostMovers[kind])
  end

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    RaidUtility_ApplyAnchor(kind)
  end
end

local function RaidUtility_UpdateWindowAlpha(kind, forceShown, useFade)
  local frame = RaidUtilityFrames[kind]
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  if not frame or not spec then return end

  local q = NormalizeDB()
  local shownAlpha = Clamp(q[spec.alphaKey] or 1, 0, 1)
  local hiddenAlpha = Clamp(q[spec.fadeOutAlphaKey] or 0, 0, 1)
  local isHovered = frame:IsMouseOver()
  local shouldFadeOut = q[spec.mouseoverKey]
    and not forceShown
    and not ns.Flags.IsEditing
    and not isHovered

  if q[spec.hideInCombatKey] and InCombatLockdown() then
    hiddenAlpha = 0
  end

  local targetAlpha = shouldFadeOut and hiddenAlpha or shownAlpha
  if ns.Flags.IsEditing then
    targetAlpha = 1
  end

  frame.alphaFadeGroup:Stop()
  if useFade
    and shouldFadeOut
    and q[spec.fadeOutDurationKey] > 0
    and shownAlpha ~= targetAlpha
  then
    frame:SetAlpha(shownAlpha)
    frame.alphaFadeAnimation:SetFromAlpha(shownAlpha)
    frame.alphaFadeAnimation:SetToAlpha(targetAlpha)
    frame.alphaFadeAnimation:SetDuration(q[spec.fadeOutDurationKey])
    frame.alphaFadeGroup:Play()
    return
  end

  frame:SetAlpha(targetAlpha)
end

local function RaidUtility_WindowMouseEnter(kind)
  RaidUtility_UpdateWindowAlpha(kind, true, false)
end

local function RaidUtility_WindowMouseLeave(kind)
  C_Timer.After(0.05, function()
    RaidUtility_UpdateWindowAlpha(kind, false, true)
  end)
end

RaidUtility_AttachWindowMouseover = function(frame, kind)
  frame:HookScript("OnEnter", function()
    RaidUtility_WindowMouseEnter(kind)
  end)
  frame:HookScript("OnLeave", function()
    RaidUtility_WindowMouseLeave(kind)
  end)
end

local function RaidUtility_GetShortBinding(bindingAction)
  local key = bindingAction and GetBindingKey(bindingAction)
  if key then
    return LibKeyBound:ToShortKey(key)
  end
  return key
end

local function RaidUtility_GetBindings(button)
  local output = ""
  for index = 1, select("#", GetBindingKey(button.bindingAction)) do
    local key = select(index, GetBindingKey(button.bindingAction))
    if key and key ~= "" then
      if output ~= "" then output = output .. ", " end
      output = output .. GetBindingText(key, "KEY_")
    end
  end
  return output
end

local function RaidUtility_SetKey(button, key)
  SetBinding(key, button.bindingAction)
end

local function RaidUtility_ClearBindings(button)
  local key = GetBindingKey(button.bindingAction)
  while key do
    SetBinding(key, nil)
    key = GetBindingKey(button.bindingAction)
  end
end

local function RaidUtility_UpdateMarkerHotkey(button)
  local key = RaidUtility_GetShortBinding(button.bindingAction)
  button.HotKey:SetText(key or "")
  button.HotKey:SetShown(key ~= nil and key ~= "")
end

local function RaidUtility_UpdateMarkerHotkeys()
  for _, kind in ipairs({ "raidMarkers", "worldMarkers" }) do
    local frame = RaidUtilityFrames[kind]
    if frame and frame.markers then
      for index = 0, 8 do
        RaidUtility_UpdateMarkerHotkey(frame.markers[index])
      end
    end
  end
end

RaidUtility_SetTooltip = function(frame, title, text)
  if not frame then
    return
  end

  frame:HookScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end

    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if title and title ~= "" then
      GameTooltip:AddLine(title, 1, 0.82, 0)
    end
    if text and text ~= "" then
      GameTooltip:AddLine(text, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)

  frame:HookScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

RaidUtility_CreateTextButton = function(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 22)
  b:EnableMouse(true)

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b:SetScript("OnClick", onClick)

  ns.Theme.WidgetSkins.Frame(b)

  if b.SetNormalTexture then b:SetNormalTexture("") end
  if b.SetPushedTexture then b:SetPushedTexture("") end
  if b.SetHighlightTexture then b:SetHighlightTexture("") end
  if b.SetDisabledTexture then b:SetDisabledTexture("") end

  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetText(label or "")
  b.label = fs

  ns.Theme.ApplyFont(fs, "tiny")

  function b:SetText(text)
    if self.label then
      self.label:SetText(text or "")
    end
  end

  local function UpdateButtonState(self)
    if self:IsEnabled() then
      self:SetAlpha(1)
    else
      self:SetAlpha(0.45)
    end
    if self.label then
      self.label:ClearAllPoints()
      self.label:SetPoint("CENTER", self, "CENTER", 0, 0)
    end
  end

  b:HookScript("OnMouseDown", function(self)
    if not self:IsEnabled() then return end
    self:SetAlpha(0.75)
    if self.label then
      self.label:ClearAllPoints()
      self.label:SetPoint("CENTER", self, "CENTER", 1, -1)
    end
  end)

  b:HookScript("OnMouseUp", UpdateButtonState)
  b:HookScript("OnLeave", UpdateButtonState)
  b:HookScript("OnEnable", UpdateButtonState)
  b:HookScript("OnDisable", UpdateButtonState)
  UpdateButtonState(b)

  return b
end

local function RaidUtility_CreateHeader(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")

  ns.Theme.ApplyFont(fs, "tiny")

  return fs
end

local RAID_TARGET_TCOORDS = {
  [1] = { 0.00, 0.25, 0.00, 0.25 },
  [2] = { 0.25, 0.50, 0.00, 0.25 },
  [3] = { 0.50, 0.75, 0.00, 0.25 },
  [4] = { 0.75, 1.00, 0.00, 0.25 },
  [5] = { 0.00, 0.25, 0.25, 0.50 },
  [6] = { 0.25, 0.50, 0.25, 0.50 },
  [7] = { 0.50, 0.75, 0.25, 0.50 },
  [8] = { 0.75, 1.00, 0.25, 0.50 },
}

local WORLD_MARKER_ICON_ORDER = {
  [1] = 5,
  [2] = 6,
  [3] = 3,
  [4] = 2,
  [5] = 7,
  [6] = 1,
  [7] = 4,
  [8] = 8,
}

local function RaidUtility_SetClearIcon(button)
  local tex = button.icon
  if not tex then
    tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon = tex
  end

  if tex.SetAtlas then
    tex:SetAtlas("talents-button-reset")
  else
    tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    tex:SetTexCoord(0, 1, 0, 1)
  end

  tex:Show()
end

local function RaidUtility_ApplyMarkerIcon(button, iconIndex)
  local tex = button.icon
  if not tex then
    tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon = tex
  end

  tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

  local coords = RAID_TARGET_TCOORDS[iconIndex]
  if coords then
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  else
    tex:SetTexCoord(0, 1, 0, 1)
  end

  tex:Show()
end

local function RaidUtility_CreateMarkerButton(parent, kind, index, size)
  local buttonName
  local bindingAction
  if kind == "raidMarkers" then
    buttonName = "PleebUI_RaidMarker" .. index
    bindingAction = index == 0 and ("CLICK " .. buttonName .. ":LeftButton")
      or ("RAIDTARGET" .. index)
  else
    buttonName = index == 0 and "PUI_CWM" or ("PUI_WM" .. index)
    bindingAction = "CLICK " .. buttonName .. ":LeftButton"
  end

  local b = CreateFrame("Button", buttonName, parent, "SecureActionButtonTemplate,BackdropTemplate")
  b:SetSize(size, size)
  b.kind = kind
  b.index = index
  b.bindingAction = bindingAction

  if b.RegisterForClicks then
    b:RegisterForClicks("AnyUp", "AnyDown")
  end

  ns.Theme.WidgetSkins.Frame(b)

  if b.SetNormalTexture then b:SetNormalTexture("") end
  if b.SetPushedTexture then b:SetPushedTexture("") end
  if b.SetHighlightTexture then b:SetHighlightTexture("") end
  if b.SetDisabledTexture then b:SetDisabledTexture("") end

  if kind == "raidMarkers" then
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", index == 0 and "/tm 0" or ("/tm " .. tostring(index)))
  else
    b:SetAttribute("type", "worldmarker")
    if index == 0 then
      b:SetAttribute("action", "clear-all")
    else
      local markerIndex = WORLD_MARKER_ICON_ORDER[index] or index
      b:SetAttribute("marker", markerIndex)
      b:SetAttribute("action1", "set")
      b:SetAttribute("action2", "clear")
    end
  end

  if index == 0 then
    RaidUtility_SetClearIcon(b)
  else
    RaidUtility_ApplyMarkerIcon(b, index)
  end

  if kind == "raidMarkers" then
    if index == 0 then
      RaidUtility_SetTooltip(b, "Clear Raid Marker", "Removes the current raid marker from your target.")
    else
      RaidUtility_SetTooltip(b, "Raid Marker: " .. (RAID_MARKER_NAMES[index] or tostring(index)), "Sets this raid marker on your current target.")
    end
  else
    if index == 0 then
      RaidUtility_SetTooltip(b, "Clear All World Markers", "Clears all active world markers.")
    else
      RaidUtility_SetTooltip(b, "World Marker: " .. (RAID_MARKER_NAMES[index] or tostring(index)), "Left-click places this world marker.\nRight-click clears this world marker.")
    end
  end

  local hotkey = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
  hotkey:SetJustifyH("RIGHT")
  hotkey:SetWordWrap(false)
  ns.Theme.ApplyFont(hotkey, "tiny")
  b.HotKey = hotkey

  b.GetHotkey = function(self)
    return RaidUtility_GetShortBinding(self.bindingAction)
  end
  b.GetBindings = RaidUtility_GetBindings
  b.SetKey = RaidUtility_SetKey
  b.ClearBindings = RaidUtility_ClearBindings
  b.GetActionName = function(self)
    if self.kind == "raidMarkers" then
      return self.index == 0 and "Clear raid marker"
        or ((RAID_MARKER_NAMES[self.index] or tostring(self.index)) .. " raid marker")
    end
    return self.index == 0 and "Clear all world markers"
      or ((RAID_MARKER_NAMES[self.index] or tostring(self.index)) .. " world marker")
  end

  b:HookScript("OnEnter", function(self)
    LibKeyBound:Set(self)
  end)

  RaidUtility_UpdateMarkerHotkey(b)

  return b
end

RaidUtility_UpdateLayout = function()
  if InCombatLockdown() then return end

  local buttonsFrame = RaidUtilityFrames.buttons
  local raidMarkersFrame = RaidUtilityFrames.raidMarkers
  local worldMarkersFrame = RaidUtilityFrames.worldMarkers
  if not buttonsFrame or not raidMarkersFrame or not worldMarkersFrame then return end

  local layoutSizeChanged = false
  local function SetWindowSize(frame, width, height)
    if frame:GetWidth() ~= width or frame:GetHeight() ~= height then
      layoutSizeChanged = true
    end
    frame:SetSize(width, height)
  end

  local buttonHeight = RaidUtility_Scaled(22)
  local gap = RaidUtility_Scaled(4)
  local sidePad = RaidUtility_Scaled(8)
  local topPad = RaidUtility_Scaled(8)
  local bottomPad = RaidUtility_Scaled(8)
  local headerHeight = RaidUtility_Scaled(14)
  local extraTimers = RaidUtility_GetExtraPullTimers()
  local extraCount = #extraTimers
  local extraColumns = 3
  local buttonWidths = {
    ready = RaidUtility_Scaled(56),
    roles = RaidUtility_Scaled(56),
    cancel = RaidUtility_Scaled(76),
    count = RaidUtility_Scaled(120),
    add = RaidUtility_Scaled(22),
  }

  local actionRowWidth = buttonWidths.ready + gap + buttonWidths.roles + gap + buttonWidths.cancel + gap + buttonWidths.count + gap + buttonWidths.add
  local extraButtonWidth = RaidUtility_Scaled((actionRowWidth - (gap * (extraColumns - 1))) / extraColumns)
  local extraRows = extraCount > 0 and math.ceil(extraCount / extraColumns) or 0
  local extraAreaHeight = extraRows > 0 and (gap + (extraRows * buttonHeight) + ((extraRows - 1) * gap)) or 0
  SetWindowSize(
    buttonsFrame,
    sidePad * 2 + actionRowWidth,
    topPad + headerHeight + gap + buttonHeight + extraAreaHeight + bottomPad
  )

  buttonsFrame.header:ClearAllPoints()
  buttonsFrame.header:SetPoint("TOPLEFT", buttonsFrame, "TOPLEFT", sidePad, -topPad)
  buttonsFrame.dragHandle:ClearAllPoints()
  buttonsFrame.dragHandle:SetPoint("TOPLEFT", buttonsFrame, "TOPLEFT", 0, 0)
  buttonsFrame.dragHandle:SetPoint("TOPRIGHT", buttonsFrame, "TOPRIGHT", 0, 0)
  buttonsFrame.dragHandle:SetHeight(topPad + headerHeight + gap)

  local previous = nil
  for _, key in ipairs({ "ready", "roles", "cancel", "count", "add" }) do
    local button = buttonsFrame.buttons and buttonsFrame.buttons[key]
    if button then
      button:SetSize(buttonWidths[key] or buttonHeight, buttonHeight)
      button:ClearAllPoints()
      if not previous then
        button:SetPoint("TOPLEFT", buttonsFrame, "TOPLEFT", sidePad, -(topPad + headerHeight + gap))
      else
        button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
      end
      previous = button
    end
  end

  if extraCount > 0 then
    for i = 1, extraCount do
      local button = RaidUtilityExtraButtons[i]
      if button then
        local row = math.floor((i - 1) / extraColumns)
        local col = (i - 1) % extraColumns
        button:SetSize(extraButtonWidth, buttonHeight)
        button:ClearAllPoints()
        button:SetPoint(
          "TOPLEFT",
          buttonsFrame,
          "TOPLEFT",
          sidePad + (col * (extraButtonWidth + gap)),
          -(topPad + headerHeight + gap + buttonHeight + gap + (row * (buttonHeight + gap)))
        )
      end
    end
  end

  for _, kind in ipairs({ "raidMarkers", "worldMarkers" }) do
    local frame = RaidUtilityFrames[kind]
    local markerButtonSize = RaidUtility_GetMarkerButtonSize(kind)
    local markerRowWidth = (markerButtonSize * 9) + (gap * 8)
    SetWindowSize(
      frame,
      sidePad * 2 + markerRowWidth,
      topPad + headerHeight + gap + markerButtonSize + bottomPad
    )

    frame.header:ClearAllPoints()
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", sidePad, -topPad)
    frame.dragHandle:ClearAllPoints()
    frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.dragHandle:SetHeight(topPad + headerHeight + gap)

    previous = nil
    for index = 0, 8 do
      local button = frame.markers[index]
      button:SetSize(markerButtonSize, markerButtonSize)
      button:ClearAllPoints()
      if not previous then
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", sidePad, -(topPad + headerHeight + gap))
      else
        button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
      end
      previous = button
    end
  end

  RaidUtility_UpdateGhostMovers()
  if layoutSizeChanged
    and buttonsFrame:GetNumPoints() > 0
    and raidMarkersFrame:GetNumPoints() > 0
    and worldMarkersFrame:GetNumPoints() > 0
    and NormalizeDB().raidUtilitySmartSnapSeeded == true
  then
    RaidUtility_ShowDragGhosts()
    ns.FrameUtil.RelayoutSmartSnapCluster(RAID_UTILITY_WINDOW_SPECS.buttons.moverKey, true)
    RaidUtility_HideDragGhosts()
  end
end

local function RaidUtility_SetWindowShown(kind, shown)
  local frame = RaidUtilityFrames[kind]
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  local q = NormalizeDB()
  if not frame or not spec then return end

  if shown then
    if q[spec.hideInCombatKey] and not q[spec.mouseoverKey] then
      RegisterStateDriver(frame, "visibility", "[combat] hide; show")
    else
      UnregisterStateDriver(frame, "visibility")
      frame:Show()
    end
    RaidUtility_UpdateWindowAlpha(kind, false, false)
  else
    UnregisterStateDriver(frame, "visibility")
    frame.alphaFadeGroup:Stop()
    frame:Hide()
  end
end

RaidUtility_Refresh = function()
  local q = NormalizeDB()
  if not RaidUtilityFrames.buttons then return end

  if InCombatLockdown() then
    RaidUtilityPendingRefresh = true
    RaidUtility_UpdateGhostMovers()
    return
  end

  RaidUtilityPendingRefresh = false

  local shouldShow = RaidUtility_ShouldShowFrame()
    and not RaidUtility_InRestrictedInstance()

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    RaidUtility_ApplyAnchor(kind)
  end
  RaidUtility_EnsureExtraButtons()

  RaidUtility_UpdateLayout()

  local hasPermission = RaidUtility_HasPermission()
  local inGroup = RaidUtility_InGroup()
  local extraTimers = RaidUtility_GetExtraPullTimers()
  local buttonsFrame = RaidUtilityFrames.buttons
  local raidMarkersFrame = RaidUtilityFrames.raidMarkers
  local worldMarkersFrame = RaidUtilityFrames.worldMarkers

  local buttonsEnabled = q.raidUtilityButtonsEnable == true
  local raidMarkersEnabled = q.raidUtilityRaidMarkersEnable == true
  local worldMarkersEnabled = q.raidUtilityWorldMarkersEnable == true

  if not buttonsEnabled and RaidUtilityPullTimerPopup then
    RaidUtilityPullTimerPopup:Hide()
  end

  if buttonsFrame.buttons then
    if buttonsFrame.buttons.ready then
      buttonsFrame.buttons.ready:SetEnabled(buttonsEnabled and hasPermission)
    end
    if buttonsFrame.buttons.roles then
      buttonsFrame.buttons.roles:SetEnabled(buttonsEnabled and hasPermission)
    end
    if buttonsFrame.buttons.cancel then
      buttonsFrame.buttons.cancel:SetEnabled(buttonsEnabled and inGroup)
    end
    if buttonsFrame.buttons.count then
      buttonsFrame.buttons.count:SetEnabled(buttonsEnabled and inGroup)
      RaidUtility_UpdatePullButtonText()
    end
    if buttonsFrame.buttons.add then
      buttonsFrame.buttons.add:SetEnabled(buttonsEnabled and not RaidUtilityPendingRefresh)
    end
  end

  for i, button in ipairs(RaidUtilityExtraButtons) do
    if button then
      button:SetShown(not not extraTimers[i])
      button:SetEnabled(buttonsEnabled and inGroup)
    end
  end

  for index = 0, 8 do
    if raidMarkersFrame.markers[index] then
      raidMarkersFrame.markers[index]:SetEnabled(raidMarkersEnabled and hasPermission)
    end
    if worldMarkersFrame.markers[index] then
      worldMarkersFrame.markers[index]:SetEnabled(worldMarkersEnabled and hasPermission)
    end
  end

  if raidMarkersEnabled or worldMarkersEnabled then
    RaidUtility_UpdateMarkerHotkeys()
  end
  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    local spec = RAID_UTILITY_WINDOW_SPECS[kind]
    RaidUtility_SetWindowShown(kind, shouldShow and q[spec.enabledKey] == true)
  end
  RaidUtility_UpdateGhostMovers()
end

local function RaidUtility_BuildQuickSettings(kind)
  local q = NormalizeDB()
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  local controls = {
    {
      type = "toggle",
      label = "Enable",
      get = function() return q[spec.enabledKey] == true end,
      set = function(value)
        q[spec.enabledKey] = value == true
        ApplyRaidUtility()
      end,
    },
    {
      type = "toggle",
      label = "Hide in combat",
      get = function() return q[spec.hideInCombatKey] end,
      set = function(value)
        q[spec.hideInCombatKey] = value == true
        RaidUtility_Refresh()
      end,
    },
    {
      type = "toggle",
      label = "Show on mouseover",
      get = function() return q[spec.mouseoverKey] end,
      set = function(value)
        q[spec.mouseoverKey] = value == true
        RaidUtility_Refresh()
      end,
    },
    {
      type = "description",
      text = "Hide in combat and Show on mouseover can be combined. The window stays invisible in combat until you move the mouse over it.",
    },
    {
      type = "slider",
      label = "Opacity",
      min = 0,
      max = 1,
      step = 0.05,
      get = function() return q[spec.alphaKey] end,
      set = function(value)
        q[spec.alphaKey] = Clamp(value, 0, 1)
        RaidUtility_UpdateWindowAlpha(kind, false, false)
      end,
    },
    {
      type = "slider",
      label = "Hidden opacity",
      min = 0,
      max = 1,
      step = 0.05,
      disabled = function() return q[spec.mouseoverKey] ~= true end,
      get = function() return q[spec.fadeOutAlphaKey] end,
      set = function(value)
        q[spec.fadeOutAlphaKey] = Clamp(value, 0, 1)
        RaidUtility_UpdateWindowAlpha(kind, false, false)
      end,
    },
    {
      type = "slider",
      label = "Fade-out time",
      min = 0,
      max = 10,
      step = 0.5,
      disabled = function() return q[spec.mouseoverKey] ~= true end,
      get = function() return q[spec.fadeOutDurationKey] end,
      set = function(value)
        q[spec.fadeOutDurationKey] = Clamp(value, 0, 10)
      end,
    },
    {
      type = "toggle",
      label = "Enable free moving",
      get = function() return q[spec.freeMoveKey] end,
      set = function(value)
        q[spec.freeMoveKey] = value == true
      end,
    },
  }

  if spec.buttonSizeKey then
    controls[#controls + 1] = {
      type = "slider",
      label = "Button size",
      min = 18,
      max = 40,
      step = 1,
      get = function() return q[spec.buttonSizeKey] end,
      set = function(value)
        q[spec.buttonSizeKey] = Clamp(value, 18, 40)
        RaidUtility_Refresh()
      end,
    }
  end

  return {
    ownerKey = spec.moverKey,
    title = spec.title,
    description = "Live raid utility settings.",
    controls = controls,
  }
end

RaidUtility_UpdateGhostMovers = function()
  local q = NormalizeDB()

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    local windowKind = kind
    local frame = RaidUtilityFrames[kind]
    local spec = RAID_UTILITY_WINDOW_SPECS[kind]
    if frame then
      local anchor = q[spec.anchorKey] or spec.defaults

      local function SavePosition(mover)
        RaidUtility_StoreAnchor(windowKind, mover)
        RaidUtility_ApplyAnchor(windowKind)
      end

      RaidUtilityGhostMovers[kind] = ns.FrameUtil:EnsureGhostMover(spec.moverKey, {
        frameName = spec.ghostFrameName,
        label = spec.title,
        liveFrame = frame,
        useOverlayDrag = false,
        smartSnap = {
          family = "raidUtility",
          isRuntimeActive = function()
            return NormalizeDB()[spec.enabledKey] == true
          end,
        },
        fallbackAnchor = {
          point = "CENTER",
          relativeTo = UIParent,
          relativePoint = "CENTER",
          x = anchor.x or spec.defaults.x,
          y = anchor.y or spec.defaults.y,
        },
        shouldShow = function()
          local current = NormalizeDB()
          RaidUtility_UpdateWindowAlpha(windowKind, false, false)
          return current[spec.enabledKey] == true and ns.Flags.IsEditing and true or false
        end,
        optionsString = "Quality,qualityTab",
        savePosition = SavePosition,
        resetPosition = function()
          local current = NormalizeDB()
          current[spec.anchorKey] = SeedAnchorDefaults(nil, spec.defaults)
          RaidUtility_ApplyAnchor(windowKind)
          RaidUtility_UpdateGhostMovers()
          ns.FrameUtil.RelayoutSmartSnapCluster(spec.moverKey, true)
        end,
        quickSettings = function()
          return RaidUtility_BuildQuickSettings(windowKind)
        end,
      })
    end
  end
end

RaidUtility_ShowDragGhosts = function()
  RaidUtility_UpdateGhostMovers()
  local q = NormalizeDB()
  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    local mover = RaidUtilityGhostMovers[kind]
    local spec = RAID_UTILITY_WINDOW_SPECS[kind]
    if mover and q[spec.enabledKey] == true then
      mover:Show()
    end
  end
end

RaidUtility_HideDragGhosts = function()
  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    ns.FrameUtil:RefreshGhostMover(RAID_UTILITY_WINDOW_SPECS[kind].moverKey)
  end
end

local function RaidUtility_SeedSmartSnapLinks()
  local q = NormalizeDB()
  if q.raidUtilitySmartSnapSeeded == true then return end

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    RaidUtility_ApplyAnchor(kind)
  end
  RaidUtility_ShowDragGhosts()
  ns.FrameUtil.SeedSmartSnapLink(
    RAID_UTILITY_WINDOW_SPECS.raidMarkers.moverKey,
    RAID_UTILITY_WINDOW_SPECS.buttons.moverKey,
    "BELOW",
    false,
    false
  )
  ns.FrameUtil.SeedSmartSnapLink(
    RAID_UTILITY_WINDOW_SPECS.worldMarkers.moverKey,
    RAID_UTILITY_WINDOW_SPECS.raidMarkers.moverKey,
    "BELOW",
    false,
    false
  )
  ns.FrameUtil.RelayoutSmartSnapCluster(RAID_UTILITY_WINDOW_SPECS.buttons.moverKey, true)
  RaidUtility_HideDragGhosts()
  q.raidUtilitySmartSnapSeeded = true
end

local function RaidUtility_SyncLiveWindowsToGhosts()
  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    local mover = RaidUtilityGhostMovers[kind]
    local frame = RaidUtilityFrames[kind]
    if mover and frame then
      local x, y = ns.FrameUtil.GetMoverOffsets(mover)
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
  end
end

local function RaidUtility_StopWindowDrag(kind)
  local state = RaidUtilityDragState
  if not state or state.kind ~= kind then return end
  if InCombatLockdown() then
    RaidUtility_CancelWindowDrag()
    return
  end

  RaidUtilityDragState = nil
  state.driver:Hide()
  state.window.snapHint:Hide()
  ns.FrameUtil.FinishExternalSmartSnapDrag(state.smartSnap)
  RaidUtility_SyncLiveWindowsToGhosts()
  RaidUtility_SaveAnchors()
  RaidUtility_HideDragGhosts()
end

RaidUtility_CancelWindowDrag = function()
  local state = RaidUtilityDragState
  if not state then return end

  RaidUtilityDragState = nil
  state.driver:Hide()
  state.window.snapHint:Hide()

  if InCombatLockdown() then
    Module.pendingDragRestore = state.smartSnap
    RaidUtility_HideDragGhosts()
    return
  end

  ns.FrameUtil.CancelExternalSmartSnapDrag(state.smartSnap)
  RaidUtility_SyncLiveWindowsToGhosts()
  RaidUtility_HideDragGhosts()
end

local function RaidUtility_UpdateWindowDrag(kind)
  local state = RaidUtilityDragState
  if not state or state.kind ~= kind then return end

  if InCombatLockdown() then
    RaidUtility_CancelWindowDrag()
    return
  end

  local scale = UIParent:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX = cursorX / scale
  cursorY = cursorY / scale

  local deltaX = cursorX - state.cursorX
  local deltaY = cursorY - state.cursorY

  if IsShiftKeyDown() and state.breakSnap ~= true then
    ns.FrameUtil.CancelExternalSmartSnapDrag(state.smartSnap)
    RaidUtility_SyncLiveWindowsToGhosts()

    state.breakSnap = true
    state.smartSnap = ns.FrameUtil.BeginExternalSmartSnapDrag(
      RAID_UTILITY_WINDOW_SPECS[kind].moverKey,
      true
    )
    if not state.smartSnap then
      RaidUtility_CancelWindowDrag()
      return
    end
  end

  ns.FrameUtil.UpdateExternalSmartSnapDrag(
    state.smartSnap,
    deltaX,
    deltaY
  )
  RaidUtility_SyncLiveWindowsToGhosts()
end

local function RaidUtility_StartWindowDrag(kind)
  local q = NormalizeDB()
  local spec = RAID_UTILITY_WINDOW_SPECS[kind]
  local window = RaidUtilityFrames[kind]
  if InCombatLockdown() or ns.Flags.IsEditing or not q[spec.freeMoveKey] then
    return
  end

  RaidUtility_ShowDragGhosts()

  local breakSnap = IsShiftKeyDown() == true
  local smartSnap = ns.FrameUtil.BeginExternalSmartSnapDrag(spec.moverKey, breakSnap)
  if not smartSnap then
    RaidUtility_HideDragGhosts()
    return
  end

  local scale = UIParent:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  RaidUtilityDragState = {
    kind = kind,
    window = window,
    driver = window.dragDriver,
    breakSnap = breakSnap,
    cursorX = cursorX / scale,
    cursorY = cursorY / scale,
    smartSnap = smartSnap,
  }
  window.snapHint:Show()
  window.dragDriver:Show()
end

local function EnsureRaidUtility()
  if RaidUtilityFrames.buttons then return RaidUtilityFrames end

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    local windowKind = kind
    local spec = RAID_UTILITY_WINDOW_SPECS[kind]
    local frame = CreateFrame("Frame", spec.frameName, UIParent, "SecureHandlerStateTemplate,BackdropTemplate")
    RaidUtilityFrames[kind] = frame
    frame.kind = windowKind
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(25)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    local alphaFadeGroup = frame:CreateAnimationGroup()
    alphaFadeGroup:SetToFinalAlpha(true)
    frame.alphaFadeGroup = alphaFadeGroup
    frame.alphaFadeAnimation = alphaFadeGroup:CreateAnimation("Alpha")

    ns.Theme.WidgetSkins.Frame(frame)
    RaidUtility_AttachWindowMouseover(frame, windowKind)
    frame:HookScript("OnShow", function()
      RaidUtility_UpdateWindowAlpha(windowKind, false, false)
    end)
    frame:HookScript("OnHide", function(self)
      self.alphaFadeGroup:Stop()
    end)

    frame.header = RaidUtility_CreateHeader(frame, spec.title)

    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
      RaidUtility_StartWindowDrag(windowKind)
    end)
    dragHandle:SetScript("OnDragStop", function()
      RaidUtility_StopWindowDrag(windowKind)
    end)
    frame.dragHandle = dragHandle
    RaidUtility_AttachWindowMouseover(dragHandle, windowKind)

    local snapHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    snapHint:SetPoint("BOTTOM", frame, "TOP", 0, 6)
    snapHint:SetText("Smart Snap highlights compatible windows. Shift-drag detaches this window.")
    snapHint:Hide()
    frame.snapHint = snapHint

    local dragDriver = CreateFrame("Frame", nil, UIParent)
    dragDriver:SetScript("OnUpdate", function()
      RaidUtility_UpdateWindowDrag(windowKind)
    end)
    dragDriver:Hide()
    frame.dragDriver = dragDriver
  end

  local buttonsFrame = RaidUtilityFrames.buttons
  buttonsFrame.buttons = {}

  buttonsFrame.buttons.ready = RaidUtility_CreateTextButton(buttonsFrame, "Ready", 56, function()
    if RaidUtility_HasPermission() then
      C_PartyInfo.DoReadyCheck()
    end
  end)
  RaidUtility_SetTooltip(buttonsFrame.buttons.ready, "Ready check", "Start a ready check.")

  buttonsFrame.buttons.roles = RaidUtility_CreateTextButton(buttonsFrame, "Roles", 56, function()
    if RaidUtility_HasPermission() then
      InitiateRolePoll()
    end
  end)
  RaidUtility_SetTooltip(buttonsFrame.buttons.roles, "Role poll", "Start a role poll.")

  buttonsFrame.buttons.cancel = RaidUtility_CreateTextButton(buttonsFrame, "Cancel pull", 76, function()
    RaidUtility_CancelPullTimer()
  end)
  RaidUtility_SetTooltip(buttonsFrame.buttons.cancel, "Cancel pull", "Stop the active pull timer.")

  buttonsFrame.buttons.count = RaidUtility_CreateTextButton(buttonsFrame, "Pull (10 Sec)", 120, function(self, mouseButton)
    if mouseButton == "RightButton" then
      RaidUtility_ShowPullTimerDialog("main", nil, self)
    else
      RaidUtility_StartPullTimer(RaidUtility_GetPullTimerSeconds())
    end
  end)
  RaidUtility_SetTooltip(buttonsFrame.buttons.count, "Pull timer", "Left-click to start it.\nRight-click to change its length.")

  buttonsFrame.buttons.add = RaidUtility_CreateTextButton(buttonsFrame, "+", 22, function()
    RaidUtility_AddExtraPullTimer()
  end)
  RaidUtility_SetTooltip(buttonsFrame.buttons.add, "Add pull timer", "Add another pull timer below.")

  for _, button in pairs(buttonsFrame.buttons) do
    RaidUtility_AttachWindowMouseover(button, "buttons")
  end

  for i = 0, 8 do
    for _, kind in ipairs({ "raidMarkers", "worldMarkers" }) do
      local frame = RaidUtilityFrames[kind]
      frame.markers = frame.markers or {}
      frame.markers[i] = RaidUtility_CreateMarkerButton(
        frame,
        kind,
        i,
        RaidUtility_GetMarkerButtonSize(kind)
      )
      RaidUtility_AttachWindowMouseover(frame.markers[i], kind)
    end
  end

  for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
    RaidUtility_ApplyAnchor(kind)
  end
  RaidUtility_UpdateLayout()
  RaidUtility_UpdateGhostMovers()

  RaidUtility_SeedSmartSnapLinks()

  return RaidUtilityFrames
end

local function EnsureRaidUtilityEvents()
  if RaidUtilityEvents then return RaidUtilityEvents end

  local f = CreateFrame("Frame", "PleebUI_QualityRaidUtilityEvents")
  RaidUtilityEvents = f
  f:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_BINDINGS" then
      RaidUtility_UpdateMarkerHotkeys()
      return
    end

    if event == "PLAYER_REGEN_DISABLED" then
      RaidUtility_CancelWindowDrag()
      for _, kind in ipairs(RAID_UTILITY_WINDOW_ORDER) do
        RaidUtility_UpdateWindowAlpha(kind, false, false)
      end
      return
    end

    if event == "PLAYER_REGEN_ENABLED" and RaidUtilityPendingRefresh then
      ApplyRaidUtility()
      return
    end

    RaidUtility_Refresh()
  end)

  return f
end

local function RaidUtility_UpdateEventRegistration()
  local f = EnsureRaidUtilityEvents()
  local q = NormalizeDB()
  local buttonsEnabled = q.raidUtilityButtonsEnable == true
  local raidMarkersEnabled = q.raidUtilityRaidMarkersEnable == true
  local worldMarkersEnabled = q.raidUtilityWorldMarkersEnable == true

  f:UnregisterAllEvents()

  if not buttonsEnabled and not raidMarkersEnabled and not worldMarkersEnabled then
    if RaidUtilityPendingRefresh then
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return
  end

  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("PARTY_LEADER_CHANGED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")

  if raidMarkersEnabled or worldMarkersEnabled then
    f:RegisterEvent("UPDATE_BINDINGS")
  end
end

ApplyRaidUtility = function()
  EnsureRaidUtility()
  RaidUtility_SeedSmartSnapLinks()
  RaidUtility_Refresh()
  RaidUtility_UpdateEventRegistration()
end



function Module.ApplyAll()
  ApplyBresLustWidget()
  ApplyRaidUtility()
end

function Module.BuildBresLustOptions(ctx)
  return {
    type = "group",
    name = "Battle resurrection and Bloodlust",
    order = 40,
    inline = true,
    args = {
      general = {
        type = "group",
        name = "General",
        order = 10,
        inline = true,
        args = {
          bresWidgetEnable = ctx.ToggleOption("Battle resurrection", "bresWidgetEnable", 1),
          lustWidgetEnable = ctx.ToggleOption("Bloodlust", "lustWidgetEnable", 2),
          bresLustWidgetShowOnlyInGroup = ctx.ToggleOption("Show only in group", "bresLustWidgetShowOnlyInGroup", 3),
        },
      },
      layout = {
        type = "group",
        name = "Layout",
        order = 20,
        inline = true,
        args = {
          bresLustWidgetIconSize = ctx.RangeOption("Icon size", "bresLustWidgetIconSize", 16, 64, 1, 1),
        },
      },
    },
  }
end

function Module.BuildRaidUtilityOptions(ctx)
  local function SetRaidUtilityOption(key, value)
    local q = ctx.GetQ()
    q[key] = value
    ctx.RequestApply({ raidUtility = true })
  end

  local function BuildWindowOptions(kind, order)
    local spec = RAID_UTILITY_WINDOW_SPECS[kind]
    local args = {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 0,
        get = function() return ctx.GetQ()[spec.enabledKey] == true end,
        set = function(_, value)
          SetRaidUtilityOption(spec.enabledKey, value == true)
        end,
      },
      hideInCombat = {
        type = "toggle",
        name = "Hide in combat",
        desc = "Hides the window during combat. If Show on mouseover is enabled, moving over its position still reveals it.",
        order = 1,
        get = function() return ctx.GetQ()[spec.hideInCombatKey] == true end,
        set = function(_, value)
          SetRaidUtilityOption(spec.hideInCombatKey, value == true)
        end,
      },
      mouseover = {
        type = "toggle",
        name = "Show on mouseover",
        desc = "Shows the window at its configured opacity while hovered. This can be combined with Hide in combat.",
        order = 2,
        get = function() return ctx.GetQ()[spec.mouseoverKey] == true end,
        set = function(_, value)
          SetRaidUtilityOption(spec.mouseoverKey, value == true)
        end,
      },
      alpha = {
        type = "range",
        name = "Opacity",
        desc = "Opacity while the window is shown or hovered.",
        order = 3,
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
          return ctx.Clamp(tonumber(ctx.GetQ()[spec.alphaKey]) or 1, 0, 1)
        end,
        set = function(_, value)
          SetRaidUtilityOption(spec.alphaKey, ctx.Clamp(value, 0, 1))
        end,
      },
      fadeOutAlpha = {
        type = "range",
        name = "Hidden opacity",
        desc = "Opacity while Show on mouseover is enabled and the window is not hovered.",
        order = 4,
        min = 0,
        max = 1,
        step = 0.05,
        disabled = function() return ctx.GetQ()[spec.mouseoverKey] ~= true end,
        get = function()
          return ctx.Clamp(tonumber(ctx.GetQ()[spec.fadeOutAlphaKey]) or 0, 0, 1)
        end,
        set = function(_, value)
          SetRaidUtilityOption(spec.fadeOutAlphaKey, ctx.Clamp(value, 0, 1))
        end,
      },
      fadeOutDuration = {
        type = "range",
        name = "Fade-out time",
        desc = "How long the window takes to return to its hidden opacity.",
        order = 5,
        min = 0,
        max = 10,
        step = 0.5,
        disabled = function() return ctx.GetQ()[spec.mouseoverKey] ~= true end,
        get = function()
          return ctx.Clamp(tonumber(ctx.GetQ()[spec.fadeOutDurationKey]) or 0, 0, 10)
        end,
        set = function(_, value)
          SetRaidUtilityOption(spec.fadeOutDurationKey, ctx.Clamp(value, 0, 10))
        end,
      },
      freeMove = {
        type = "toggle",
        name = "Enable free moving",
        order = 6,
        get = function() return ctx.GetQ()[spec.freeMoveKey] == true end,
        set = function(_, value)
          SetRaidUtilityOption(spec.freeMoveKey, value == true)
        end,
      },
    }

    if spec.buttonSizeKey then
      args.buttonSize = {
        type = "range",
        name = "Button size",
        order = 7,
        min = 18,
        max = 40,
        step = 1,
        bigStep = 1,
        get = function()
          return ctx.Clamp(tonumber(ctx.GetQ()[spec.buttonSizeKey]) or 22, 18, 40)
        end,
        set = function(_, value)
          SetRaidUtilityOption(spec.buttonSizeKey, ctx.Clamp(value, 18, 40))
        end,
      }
    end

    return {
      type = "group",
      name = spec.title,
      order = order,
      inline = true,
      args = args,
    }
  end

  return {
    type = "group",
    name = "Raid utility",
    order = 50,
    inline = true,
    args = {
      general = {
        type = "group",
        name = "General",
        order = 10,
        inline = true,
        args = {
          raidUtilityShowOnlyInGroup = {
            type = "toggle",
            name = "Show only in group",
            order = 1,
            get = function()
              return ctx.GetQ().raidUtilityShowOnlyInGroup == true
            end,
            set = function(_, value)
              SetRaidUtilityOption("raidUtilityShowOnlyInGroup", value == true)
            end,
          },
        },
      },
      buttons = BuildWindowOptions("buttons", 20),
      raidMarkers = BuildWindowOptions("raidMarkers", 30),
      worldMarkers = BuildWindowOptions("worldMarkers", 40),
    },
  }
end



  Module.NormalizeDB = P:Def("Module.NormalizeDB", Module.NormalizeDB)
  BRL_StopLustWindow = P:Def("BRL_StopLustWindow", BRL_StopLustWindow)
  BRL_StartLustWindow = P:Def("BRL_StartLustWindow", BRL_StartLustWindow)
  BRL_CreateIcon = P:Def("BRL_CreateIcon", BRL_CreateIcon)
  EnsureBresLustWidget = P:Def("EnsureBresLustWidget", EnsureBresLustWidget)
  BRLWidget_UpdateGhostMover = P:Def("BRLWidget_UpdateGhostMover", BRLWidget_UpdateGhostMover)
  BresLustWidget_UpdateBresDisplay = P:Def("BresLustWidget_UpdateBresDisplay", BresLustWidget_UpdateBresDisplay)
  BresLustWidget_FindSatedAura = P:Def("BresLustWidget_FindSatedAura", BresLustWidget_FindSatedAura)
  BresLustWidget_UpdateLustDisplay = P:Def("BresLustWidget_UpdateLustDisplay", BresLustWidget_UpdateLustDisplay)
  BresLustWidget_SyncSatedState = P:Def("BresLustWidget_SyncSatedState", BresLustWidget_SyncSatedState)
  BresLustWidget_OnPlayerAuraChanged = P:Def("BresLustWidget_OnPlayerAuraChanged", BresLustWidget_OnPlayerAuraChanged)
  BresLustWidget_Refresh = P:Def("BresLustWidget_Refresh", BresLustWidget_Refresh)
  EnsureBresLustWidgetEvents = P:Def("EnsureBresLustWidgetEvents", EnsureBresLustWidgetEvents)
  ApplyBresLustWidget = P:Def("ApplyBresLustWidget", ApplyBresLustWidget)
  RaidUtility_InRestrictedInstance = P:Def("RaidUtility_InRestrictedInstance", RaidUtility_InRestrictedInstance)
  RaidUtility_InGroup = P:Def("RaidUtility_InGroup", RaidUtility_InGroup)
  RaidUtility_IsRaidMarkerRole = P:Def("RaidUtility_IsRaidMarkerRole", RaidUtility_IsRaidMarkerRole)
  RaidUtility_HasPermission = P:Def("RaidUtility_HasPermission", RaidUtility_HasPermission)
  RaidUtility_ShouldShowFrame = P:Def("RaidUtility_ShouldShowFrame", RaidUtility_ShouldShowFrame)
  RaidUtility_GetExtraPullTimers = P:Def("RaidUtility_GetExtraPullTimers", RaidUtility_GetExtraPullTimers)
  RaidUtility_GetPullTimerSeconds = P:Def("RaidUtility_GetPullTimerSeconds", RaidUtility_GetPullTimerSeconds)
  RaidUtility_FormatPullButtonText = P:Def("RaidUtility_FormatPullButtonText", RaidUtility_FormatPullButtonText)
  RaidUtility_GetMarkerButtonSize = P:Def("RaidUtility_GetMarkerButtonSize", RaidUtility_GetMarkerButtonSize)
  RaidUtility_Scaled = P:Def("RaidUtility_Scaled", RaidUtility_Scaled)
  RaidUtility_UpdatePullButtonText = P:Def("RaidUtility_UpdatePullButtonText", RaidUtility_UpdatePullButtonText)
  RaidUtility_SetPullTimerSeconds = P:Def("RaidUtility_SetPullTimerSeconds", RaidUtility_SetPullTimerSeconds)
  RaidUtility_AddExtraPullTimer = P:Def("RaidUtility_AddExtraPullTimer", RaidUtility_AddExtraPullTimer)
  RaidUtility_DeleteExtraPullTimer = P:Def("RaidUtility_DeleteExtraPullTimer", RaidUtility_DeleteExtraPullTimer)
  RaidUtility_RunPullCommand = P:Def("RaidUtility_RunPullCommand", RaidUtility_RunPullCommand)
  RaidUtility_StartPullTimer = P:Def("RaidUtility_StartPullTimer", RaidUtility_StartPullTimer)
  RaidUtility_CancelPullTimer = P:Def("RaidUtility_CancelPullTimer", RaidUtility_CancelPullTimer)
  RaidUtility_GetPopupSeconds = P:Def("RaidUtility_GetPopupSeconds", RaidUtility_GetPopupSeconds)
  RaidUtility_CommitPopupSeconds = P:Def("RaidUtility_CommitPopupSeconds", RaidUtility_CommitPopupSeconds)
  RaidUtility_EnsurePullTimerPopup = P:Def("RaidUtility_EnsurePullTimerPopup", RaidUtility_EnsurePullTimerPopup)
  RaidUtility_ShowPullTimerDialog = P:Def("RaidUtility_ShowPullTimerDialog", RaidUtility_ShowPullTimerDialog)
  RaidUtility_EnsureExtraButtons = P:Def("RaidUtility_EnsureExtraButtons", RaidUtility_EnsureExtraButtons)
  RaidUtility_ApplyAnchor = P:Def("RaidUtility_ApplyAnchor", RaidUtility_ApplyAnchor)
  RaidUtility_StoreAnchor = P:Def("RaidUtility_StoreAnchor", RaidUtility_StoreAnchor)
  RaidUtility_SaveAnchors = P:Def("RaidUtility_SaveAnchors", RaidUtility_SaveAnchors)
  RaidUtility_UpdateWindowAlpha = P:Def("RaidUtility_UpdateWindowAlpha", RaidUtility_UpdateWindowAlpha)
  RaidUtility_WindowMouseEnter = P:Def("RaidUtility_WindowMouseEnter", RaidUtility_WindowMouseEnter)
  RaidUtility_WindowMouseLeave = P:Def("RaidUtility_WindowMouseLeave", RaidUtility_WindowMouseLeave)
  RaidUtility_AttachWindowMouseover = P:Def("RaidUtility_AttachWindowMouseover", RaidUtility_AttachWindowMouseover)
  RaidUtility_GetShortBinding = P:Def("RaidUtility_GetShortBinding", RaidUtility_GetShortBinding)
  RaidUtility_GetBindings = P:Def("RaidUtility_GetBindings", RaidUtility_GetBindings)
  RaidUtility_SetKey = P:Def("RaidUtility_SetKey", RaidUtility_SetKey)
  RaidUtility_ClearBindings = P:Def("RaidUtility_ClearBindings", RaidUtility_ClearBindings)
  RaidUtility_UpdateMarkerHotkey = P:Def("RaidUtility_UpdateMarkerHotkey", RaidUtility_UpdateMarkerHotkey)
  RaidUtility_UpdateMarkerHotkeys = P:Def("RaidUtility_UpdateMarkerHotkeys", RaidUtility_UpdateMarkerHotkeys)
  RaidUtility_SetTooltip = P:Def("RaidUtility_SetTooltip", RaidUtility_SetTooltip)
  RaidUtility_CreateTextButton = P:Def("RaidUtility_CreateTextButton", RaidUtility_CreateTextButton)
  RaidUtility_CreateHeader = P:Def("RaidUtility_CreateHeader", RaidUtility_CreateHeader)
  RaidUtility_SetClearIcon = P:Def("RaidUtility_SetClearIcon", RaidUtility_SetClearIcon)
  RaidUtility_ApplyMarkerIcon = P:Def("RaidUtility_ApplyMarkerIcon", RaidUtility_ApplyMarkerIcon)
  RaidUtility_CreateMarkerButton = P:Def("RaidUtility_CreateMarkerButton", RaidUtility_CreateMarkerButton)
  RaidUtility_UpdateLayout = P:Def("RaidUtility_UpdateLayout", RaidUtility_UpdateLayout)
  RaidUtility_SetWindowShown = P:Def("RaidUtility_SetWindowShown", RaidUtility_SetWindowShown)
  RaidUtility_Refresh = P:Def("RaidUtility_Refresh", RaidUtility_Refresh)
  RaidUtility_BuildQuickSettings = P:Def("RaidUtility_BuildQuickSettings", RaidUtility_BuildQuickSettings)
  RaidUtility_UpdateGhostMovers = P:Def("RaidUtility_UpdateGhostMovers", RaidUtility_UpdateGhostMovers)
  RaidUtility_ShowDragGhosts = P:Def("RaidUtility_ShowDragGhosts", RaidUtility_ShowDragGhosts)
  RaidUtility_HideDragGhosts = P:Def("RaidUtility_HideDragGhosts", RaidUtility_HideDragGhosts)
  RaidUtility_SeedSmartSnapLinks = P:Def("RaidUtility_SeedSmartSnapLinks", RaidUtility_SeedSmartSnapLinks)
  RaidUtility_SyncLiveWindowsToGhosts = P:Def("RaidUtility_SyncLiveWindowsToGhosts", RaidUtility_SyncLiveWindowsToGhosts)
  RaidUtility_StopWindowDrag = P:Def("RaidUtility_StopWindowDrag", RaidUtility_StopWindowDrag)
  RaidUtility_CancelWindowDrag = P:Def("RaidUtility_CancelWindowDrag", RaidUtility_CancelWindowDrag)
  RaidUtility_UpdateWindowDrag = P:Def("RaidUtility_UpdateWindowDrag", RaidUtility_UpdateWindowDrag)
  RaidUtility_StartWindowDrag = P:Def("RaidUtility_StartWindowDrag", RaidUtility_StartWindowDrag)
  EnsureRaidUtility = P:Def("EnsureRaidUtility", EnsureRaidUtility)
  EnsureRaidUtilityEvents = P:Def("EnsureRaidUtilityEvents", EnsureRaidUtilityEvents)
  RaidUtility_UpdateEventRegistration = P:Def("RaidUtility_UpdateEventRegistration", RaidUtility_UpdateEventRegistration)
  ApplyRaidUtility = P:Def("ApplyRaidUtility", ApplyRaidUtility)
  Module.ApplyAll = P:Def("Module.ApplyAll", Module.ApplyAll)
  Module.BuildBresLustOptions = P:Def("Module.BuildBresLustOptions", Module.BuildBresLustOptions)
  Module.BuildRaidUtilityOptions = P:Def("Module.BuildRaidUtilityOptions", Module.BuildRaidUtilityOptions)

