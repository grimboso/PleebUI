
local ADDON_NAME, ns = ...



local _G = _G
local UIParent = _G.UIParent
local InCombatLockdown = _G.InCombatLockdown
local CreateFrame = _G.CreateFrame
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local Hooks = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local Addon = ns.Addon
local FrameUtil = ns.FrameUtil
local BarWidget = ns.BarWidget
local Presentation = ns.Presentation
local PCMPresentation = ns.PCMPresentation
local CustomIcons = ns.PCMCustomIcons
local Pixel = ns.Pixel
local Round = Pixel.Round
local _SB_InstallOnce
local _SB_RebuildAll
local _SB_ApplyVisibility
local _SB_PlayerInCombat = InCombatLockdown()
local _SB_RuntimeEnabled = false
local _SB_UpdateQueued = false
local _SB_UpdateFrame = CreateFrame("Frame")
_SB_UpdateFrame:Hide()
local _SB_ClearKnownSpellCache
local _SB_KnownSpellCache = {}

local Cooldowns = ns.Modules.CooldownManager
local __PUI_PCM_SpellBars = {
  bars = {},
}



local P, TrackThis = ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "CustomCooldownBars" })


function Cooldowns:_SpellBars_OnTalentUpdate(event, unit)
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
    return
  end

  __PUI_PCM_SpellBars.pendingSpecTalentRefresh = true
end


local _PUI_SB_TimerInterpLinear = Enum.StatusBarInterpolation.None
local _PUI_SB_TimerDirRemaining = Enum.StatusBarTimerDirection.RemainingTime

_SB_ClearKnownSpellCache = function()
  for key in pairs(_SB_KnownSpellCache) do
    _SB_KnownSpellCache[key] = nil
  end

  Cooldowns:ClearSavedSpellKnownCache()
end

local function _SB_IsTrackedSpellKnown(cfg)
  local spellID = Cooldowns:GetTrackedSpellIDForCurrentSpec(cfg)
  if not spellID or not C_Spell.DoesSpellExist(spellID) then
    return false
  end

  if cfg.forceShow == true then
    return true
  end

  local currentSpecID = Cooldowns:GetCurrentSpecializationID() or 0
  local cacheKey = tostring(spellID) .. ":" .. tostring(currentSpecID)

  local cached = _SB_KnownSpellCache[cacheKey]
  if cached ~= nil then
    return cached == true
  end

  local known = C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)
  _SB_KnownSpellCache[cacheKey] = known

  return known
end

local function _SB_ClearTextDuration(bd)
  if not (bd and bd.text and bd.durationBinding) or bd.__puiTextDurationCleared == true then
    return
  end

  bd.durationBinding:Disable()
  bd.text:SetText("")
  bd.text:Hide()
  bd.__puiTextDurationCleared = true
end

local function _SB_ApplyTextDuration(bd, duration)
  if not (bd and bd.text and bd.durationBinding) then
    return
  end

  bd.durationBinding:SetDuration(duration)
  if bd.__puiTextDurationCleared ~= false then
    bd.durationBinding:Enable()
    bd.text:Show()
    bd.__puiTextDurationCleared = false
  end
  bd.durationBinding:UpdateFontString()
end

local function _SB_EnsureBarFrame(id)
  local bars = __PUI_PCM_SpellBars.bars
  local bd = bars[id]
  if bd and bd.frame and bd.frame.GetObjectType then
    return bd
  end

  local safeId = tostring(id):gsub("[^%w]", "_")
  local name = "PleebUI_PCM_SpellBar_" .. safeId

  bd = Presentation.Create("PCMBar", UIParent, {
    name = name,
    kind = "cooldown",
  })
  bars[id] = bd

  bd.id = id
  bd.frame.__puiSpellBarBD = bd
  bd.frame.barData = bd
  bd.status:Show()
  bd.durationBinding = BarWidget.CreateDurationBinding(bd.valueText)
  bd.readyBar = CreateFrame("StatusBar", nil, bd.barFrame)
  bd.readyBar:SetAllPoints(bd.cooldownBar)
  bd.readyBar:SetFrameStrata(bd.cooldownBar:GetFrameStrata())
  bd.readyBar:SetFrameLevel(bd.cooldownBar:GetFrameLevel())
  bd.readyBar:SetStatusBarTexture(BarWidget.ResolveStatusBarTexture("Pleebar"))
  bd.readyBar:SetMinMaxValues(0, 1)
  bd.readyBar:SetValue(1)
  bd.cooldownBar:SetFrameLevel(bd.cooldownBar:GetFrameLevel() + 1)

  return bd
end


local function _SB_ApplyAnchor(f, cfg, defaultY)
  if not (f and f.ClearAllPoints and f.SetPoint and UIParent) then
    return
  end

  local pos = cfg and cfg.pos or nil

  local point    = (pos and pos.point) or "CENTER"
  local relPoint = (pos and pos.relPoint) or "CENTER"
  local x = (pos and tonumber(pos.x)) or 0
  local y = (pos and tonumber(pos.y)) or defaultY or 0

  -- Pixel-snap anchors for crisp borders.
  x = Round(x or 0)
  y = Round(y or 0)

  f:ClearAllPoints()
  f:SetPoint(point, UIParent, relPoint, x, y)
end

local function _SB_SaveAnchor(f, cfg)
  if not (f and cfg) then
    return
  end

  local x, y = FrameUtil._GetOffsetsForFrame(f)

  cfg.pos = cfg.pos or {}
  cfg.pos.point = "CENTER"
  cfg.pos.rel = "UIParent"
  cfg.pos.relPoint = "CENTER"
  cfg.pos.x = Round(x or 0)
  cfg.pos.y = Round(y or 0)
end

local function _SB_RegisterMover(id, f, cfg)
  local key = "PCM_SpellBar_" .. tostring(id)
  local moverOpts = {
    label = Cooldowns:GetCustomBarDisplayName(cfg),
    optionsString = "CooldownManager,custom_bars,spell:" .. tostring(id),
    useOverlayDrag = true,
    liveFrame = function()
      return f
    end,
    shouldShow = function()
      local bd = f and f.__puiSpellBarBD
      return cfg
        and cfg.enabled ~= false
        and cfg.presentation == "BAR"
        and bd
        and bd.__puiSBRuntimeEnabled == true
    end,
    onDragStop = function(frame)
      _SB_SaveAnchor(frame or f, cfg)
      _SB_ApplyAnchor(f, cfg, 0)
      FrameUtil:RefreshGhostMover(key)
    end,
    quickSettings = function()
      local function Refresh(flags)
        Cooldowns:SpellBars_RefreshBar(id, flags)
        FrameUtil:RefreshGhostMover(key)
        FrameUtil.RefreshSmartSnapState(key)
      end

      return {
        ownerKey = key,
        title = Cooldowns:GetCustomBarDisplayName(cfg),
        description = "Live cooldown bar settings.",
        controls = {
          {
            type = "slider",
            label = "Width",
            min = 80,
            max = 600,
            step = 1,
            commitOnRelease = true,
            get = function() return cfg.width or 250 end,
            set = function(value)
              cfg.width = Round(value)
              Refresh({ presentation = true, layout = true })
            end,
          },
          {
            type = "slider",
            label = "Height",
            min = 6,
            max = 40,
            step = 1,
            get = function() return cfg.height or 25 end,
            set = function(value)
              cfg.height = Round(value)
              Refresh({ presentation = true, layout = true })
            end,
          },
          {
            type = "statusbar",
            label = "Texture",
            values = ns.OptionsUtil.BuildStatusbarValues(false),
            get = function() return cfg.texture or "Pleebar" end,
            set = function(value)
              cfg.texture = value
              Refresh({ presentation = true })
            end,
          },
          {
            type = "slider",
            label = "Border size",
            min = 0,
            max = 8,
            step = 1,
            get = function() return cfg.borderSize or 2 end,
            set = function(value)
              cfg.borderSize = Round(value)
              Refresh({ presentation = true })
            end,
          },
          {
            type = "slider",
            label = "Font size",
            min = 8,
            max = 28,
            step = 1,
            get = function() return cfg.fontSize or 14 end,
            set = function(value)
              cfg.fontSize = Round(value)
              Refresh({ presentation = true })
            end,
          },
        },
      }
    end,
    smartSnap = {
      family = "combatBars",
      syncAxis = "WIDTH",
      syncWidthMin = 80,
      syncWidthMax = 600,
      getSyncWidth = function()
        return cfg.width
      end,
      applySyncWidth = function(width)
        cfg.width = Round(width)
        Cooldowns:SpellBars_RefreshBar(id, { presentation = true, layout = true })
        FrameUtil:RefreshGhostMover(key)
      end,
      getDesign = function()
        local function CopyColor(color)
          if type(color) ~= "table" then return nil end
          return { color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a }
        end
        return {
          texture = cfg.texture,
          borderSize = cfg.borderSize or 2,
          borderColor = CopyColor(cfg.borderColor),
          backgroundColor = CopyColor(cfg.backgroundColor),
        }
      end,
      applyDesign = function(design)
        if type(design) ~= "table" then return end
        local function CopyColor(color)
          if type(color) ~= "table" then return nil end
          return { color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a }
        end
        if design.texture ~= nil then
          cfg.texture = design.texture
        end
        if design.borderSize ~= nil then cfg.borderSize = Round(design.borderSize) end
        if type(design.borderColor) == "table" then cfg.borderColor = CopyColor(design.borderColor) end
        if type(design.backgroundColor) == "table" then cfg.backgroundColor = CopyColor(design.backgroundColor) end
        Cooldowns:SpellBars_RefreshBar(id, { presentation = true })
        FrameUtil:RefreshGhostMover(key)
      end,
    },
  }

  FrameUtil:EnsureGhostMover(key, moverOpts)
end

local function _SB_ApplyBarModeAppearance(bd, cfg)
  local bar = bd.cooldownBar
  local readyBar = bd.readyBar
  local texture = BarWidget.ResolveStatusBarTexture(cfg and cfg.texture)
  local barColor = cfg and cfg.barColor
  local backgroundColor = cfg and (cfg.backgroundColor or cfg.borderColor)
  local barR = barColor and (barColor[1] or barColor.r) or 0.28
  local barG = barColor and (barColor[2] or barColor.g) or 0.67
  local barB = barColor and (barColor[3] or barColor.b) or 0.95
  local barA = barColor and (barColor[4] or barColor.a) or 1
  local bgR = backgroundColor and (backgroundColor[1] or backgroundColor.r) or 0.12
  local bgG = backgroundColor and (backgroundColor[2] or backgroundColor.g) or 0.12
  local bgB = backgroundColor and (backgroundColor[3] or backgroundColor.b) or 0.12
  local direction = tostring(
    cfg and cfg.fillDirection or "RIGHT"
  ):lower()
  local vertical = cfg and cfg.orientation == "vertical"
  local reverseFill = vertical and direction ~= "up"
    or not vertical and direction == "left"

  readyBar:SetStatusBarTexture(texture)
  readyBar:SetStatusBarColor(barR, barG, barB, barA)
  readyBar:SetMinMaxValues(0, 1)
  readyBar:SetValue(1)

  if cfg and cfg.direction == "drain" then
    readyBar:Hide()
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(barR, barG, barB, barA)
    bar:SetReverseFill(reverseFill)
  else
    readyBar:Show()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(bgR, bgG, bgB, 1)
    bar:SetReverseFill(not reverseFill)
  end
end

local function _SB_ApplyPresentation(bd, cfg)
  local frame = bd and bd.frame
  if not frame then
    return 0
  end

  local width = tonumber(cfg and cfg.width) or 240
  local height = tonumber(cfg and cfg.height) or 12
  local isVertical = cfg and cfg.orientation == "vertical"
  local showIcon = cfg and cfg.showIcon == true
  local iconSize = showIcon and math.max(1, height) or 0

  Presentation.Apply("PCMBar", bd, {
    config = cfg,
    skipVisibility = true,
    width = width,
    height = height,
    showIcon = showIcon,
    iconSize = iconSize,
    texture = cfg and cfg.texture,
    font = {
      font = cfg and cfg.font,
      size = cfg and cfg.fontSize or 14,
      flags = cfg and (cfg.fontOutline or cfg.outline) or "OUTLINE",
      color = cfg and cfg.fontColor,
    },
    color = cfg and cfg.barColor,
    visible = true,
    alpha = bd.__puiVisibilityAlpha or 1,
    showText = cfg and cfg.showText ~= false,
  })

  _SB_ApplyBarModeAppearance(bd, cfg)

  PCMPresentation.ConfigureCustomBarBuffGlow(
    "cooldown:" .. tostring(bd.id),
    bd.frame,
    cfg
  )

  local spellID = cfg and tonumber(cfg.trackedSpellID) or nil
  if showIcon and spellID and bd.icon and bd.__puiIconSpellID ~= spellID then
    bd.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    bd.__puiIconSpellID = spellID
  end

  return isVertical and width or math.max(height, iconSize)
end

local function _SB_LayoutOne(bd, cfg, y)
  local frame = bd.frame
  if not frame then
    return y
  end

  local frameHeight = _SB_ApplyPresentation(bd, cfg)
  local defaultY = y - frameHeight * 0.5

  _SB_ApplyAnchor(frame, cfg, defaultY)
  _SB_RegisterMover(bd.id, frame, cfg)

  return y - (frameHeight + 6)
end

local function _SB_ReleaseStateAppearance(bd)
  if not bd then
    return
  end

  PCMPresentation.ReleaseCustomTrackerStateGlow("cooldown-state:" .. tostring(bd.id))
  bd.__puiStateAppearanceMode = nil
  bd.__puiStateAlpha = nil
  bd.__puiStateDesaturated = nil
  bd.__puiStateGlowStyle = nil
  bd.__puiStateGlowR = nil
  bd.__puiStateGlowG = nil
  bd.__puiStateGlowB = nil
  bd.__puiStateGlowA = nil
end

local function _SB_ApplyStateAppearance(bd, cfg)
  if cfg.presentation ~= "BAR" then
    if bd.__puiStateAppearanceMode ~= cfg.presentation then
      _SB_ReleaseStateAppearance(bd)
      bd.__puiStateAppearanceMode = cfg.presentation
    end
    return
  end

  if bd.__puiCooldownStateKnown ~= true then
    return
  end

  bd.__puiStateAppearanceMode = "BAR"

  local active = bd.__puiCooldownActive == true
  local stateAlpha = active and cfg.onCooldownAlpha or cfg.readyAlpha
  local alpha = (tonumber(stateAlpha) or 100) / 100 * (bd.__puiVisibilityAlpha or 1)
  if bd.__puiStateAlpha ~= alpha then
    bd.__puiStateAlpha = alpha
    bd.frame:SetAlpha(alpha)
  end

  local desaturated = active and cfg.desaturateCooldown == true
    or not active and cfg.desaturateReady == true
  if bd.__puiStateDesaturated ~= desaturated then
    bd.__puiStateDesaturated = desaturated
    local texture = bd.cooldownBar and bd.cooldownBar:GetStatusBarTexture()
    if texture then
      texture:SetDesaturated(desaturated)
    end
  end

  local style = alpha > 0 and (active and cfg.cooldownGlowStyle or cfg.readyGlowStyle) or "NONE"
  local color = active and cfg.cooldownGlowColor or cfg.readyGlowColor
  local r = color and tonumber(color[1] or color.r) or 1
  local g = color and tonumber(color[2] or color.g) or 1
  local b = color and tonumber(color[3] or color.b) or 1
  local a = color and tonumber(color[4] or color.a) or 1

  if bd.__puiStateGlowStyle ~= style
    or bd.__puiStateGlowR ~= r
    or bd.__puiStateGlowG ~= g
    or bd.__puiStateGlowB ~= b
    or bd.__puiStateGlowA ~= a
  then
    bd.__puiStateGlowStyle = style
    bd.__puiStateGlowR = r
    bd.__puiStateGlowG = g
    bd.__puiStateGlowB = b
    bd.__puiStateGlowA = a
    PCMPresentation.ApplyCustomTrackerStateGlow(
      "cooldown-state:" .. tostring(bd.id),
      bd.frame,
      style,
      color
    )
  end
end

local function _SB_UpdateCooldownBar(bd, cfg)
  local spellID = cfg and tonumber(cfg.trackedSpellID) or nil

  if bd.__puiTrackedSpellID ~= spellID then
    bd.__puiTrackedSpellID = spellID
    bd.__puiIconSpellID = nil
    bd.__puiCooldownActive = nil
    bd.__puiCooldownStateKnown = nil
    bd.__puiPresentationMode = nil
    bd.__puiTextDurationCleared = nil
    _SB_ReleaseStateAppearance(bd)
    BarWidget.StopTimerBar(bd.cooldownBar)
    _SB_ClearTextDuration(bd)
  end

  local stateKnown = false
  local activeState
  bd.__puiCooldownStateKnown = nil
  if spellID then
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not issecretvalue(cooldownInfo) and type(cooldownInfo) == "table" then
      local isActive = cooldownInfo.isActive
      local isOnGCD = cooldownInfo.isOnGCD
      if not issecretvalue(isActive) and not issecretvalue(isOnGCD) then
        stateKnown = true
        activeState = isActive == true and isOnGCD ~= true
        bd.__puiCooldownActive = activeState
        bd.__puiCooldownStateKnown = true
      end
    end
  end

  local bar = bd.cooldownBar
  local barEnabled = cfg.presentation == "BAR"

  if bd.__puiPresentationMode ~= cfg.presentation then
    bd.__puiPresentationMode = cfg.presentation
    if barEnabled then
      bar:SetShown(true)
      bar:SetMinMaxValues(0, 1)
      bar:SetAlpha(1)
      bd.__puiTextDurationCleared = nil
    else
      bar:SetShown(false)
      BarWidget.StopTimerBar(bar)
      _SB_ClearTextDuration(bd)
      _SB_ReleaseStateAppearance(bd)
      bd.__puiStateAppearanceMode = cfg.presentation
    end
  end

  if not spellID then
    if barEnabled then
      BarWidget.StopTimerBar(bar)
      bar:SetValue(0)
    end
    _SB_ClearTextDuration(bd)
    CustomIcons:Release("cooldown:" .. tostring(bd.id))
    return
  end

  if cfg.showIcon and bd.icon and bd.__puiIconSpellID ~= spellID then
    bd.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    bd.__puiIconSpellID = spellID
  end

  local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
  if barEnabled then
    bar:SetTimerDuration(duration, _PUI_SB_TimerInterpLinear, _PUI_SB_TimerDirRemaining)
    if cfg.showText ~= false then
      _SB_ApplyTextDuration(bd, duration)
    else
      _SB_ClearTextDuration(bd)
    end
    if stateKnown then
      _SB_ApplyStateAppearance(bd, cfg)
    end
  else
    local presentationActive
    if stateKnown then
      presentationActive = activeState
    end
    CustomIcons:UpdateCooldown(
      "cooldown:" .. tostring(bd.id),
      duration,
      presentationActive
    )
  end
end



_SB_ApplyVisibility = function(bd, cfg)
  if not (bd and bd.frame) then
    return
  end

  local alpha = 1
  if cfg and cfg.hideOutOfCombat == true and not _SB_PlayerInCombat then
    local value = tonumber(cfg.outOfCombatAlpha) or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    alpha = value / 100
  end

  if bd.__puiVisibilityAlpha ~= alpha then
    bd.__puiVisibilityAlpha = alpha
  end
  if cfg.presentation == "BAR" then
    PCMPresentation.SetCustomBarBuffGlowContextAlpha(
      "cooldown:" .. tostring(bd.id),
      alpha
    )
  end
  _SB_ApplyStateAppearance(bd, cfg)
  CustomIcons:RefreshVisibility("cooldown:" .. tostring(bd.id), _SB_PlayerInCombat)
end

local function _SB_UpdateVisibilityAll()
  local host = __PUI_PCM_SpellBars
  local bars = host and host.bars
  if not bars then
    return
  end

  for _, bd in pairs(bars) do
    local cfg = bd and bd.cfg or nil
    if bd and bd.frame and cfg and bd.__puiSBRuntimeEnabled == true then
      bd.frame:SetShown(cfg.presentation == "BAR")
      _SB_ApplyVisibility(bd, cfg)
    elseif bd and bd.frame then
      bd.frame:Hide()
    end
  end
end

_SB_RebuildAll = function()
  if InCombatLockdown() then
    __PUI_PCM_SpellBars.pendingSpecTalentRefresh = true
  end

  local root = Cooldowns.GetSpellBarsDB() or {}
  __PUI_PCM_SpellBars._root = root

  local bars = __PUI_PCM_SpellBars.bars

  __PUI_PCM_SpellBars._cfgGen = (__PUI_PCM_SpellBars._cfgGen or 0) + 1

  local sortedKeys = {}
  for k in pairs(root) do
    if type(k) == "number" or type(k) == "string" then
      sortedKeys[#sortedKeys + 1] = k
    end
  end

  table.sort(sortedKeys, function(a, b)
    local ea = root[a]
    local eb = root[b]
    local la = (type(ea) == "table" and ea.label) or ""
    local lb = (type(eb) == "table" and eb.label) or ""
    la = tostring(la or "")
    lb = tostring(lb or "")
    if la == lb then
      return tostring(a) < tostring(b)
    end
    return la < lb
  end)

  local activeKeys = {}
  local activeSet = {}
  local cooldownKeys = {}

  local y = 0
  for i = 1, #sortedKeys do
    local key = sortedKeys[i]
    local cfg = Cooldowns.NormalizeSpellBarEntry(root[key], key)

    local enabled = cfg
      and cfg.enabled ~= false
      and (cfg.presentation == "BAR" or cfg.presentation == "BUTTON")

    if enabled then
      enabled = _SB_IsTrackedSpellKnown(cfg)
    end

    if not enabled then
      local bd = bars[key]
      if not bd then
        local numID = tonumber(key)
        if numID ~= nil then
          bd = bars[numID]
        end
      end

      if bd then
        PCMPresentation.DisableCustomBarBuffGlow("cooldown:" .. tostring(bd.id))
        _SB_ReleaseStateAppearance(bd)
        CustomIcons:Release("cooldown:" .. tostring(bd.id))
        bd.__puiSBRuntimeEnabled = false
        bd.cfg = nil
        _SB_ClearTextDuration(bd)
        BarWidget.StopTimerBar(bd.cooldownBar)

        if bd.cooldownBar and bd.cooldownBar.Hide then
          bd.cooldownBar:Hide()
        end
        if bd.icon and bd.icon.Hide then
          bd.icon:Hide()
        end
        if bd.iconFrame and bd.iconFrame.Hide then
          bd.iconFrame:Hide()
        end
        if bd.frame and bd.frame.Hide then
          bd.frame:Hide()
        end
      end
    else
      local bd = _SB_EnsureBarFrame(key)
      bd.cfg = cfg
      bd.__puiSBRuntimeEnabled = true

      if cfg.presentation == "BUTTON" then
        FrameUtil:UnregisterMover("PCM_SpellBar_" .. tostring(bd.id))
        CustomIcons:Configure("cooldown:" .. tostring(bd.id), cfg, {
          kind = "cooldown",
          label = Cooldowns:GetCustomBarDisplayName(cfg) .. " icon",
          optionsString = "CooldownManager,custom_bars,spell:" .. tostring(bd.id),
          moverKey = "PCM_CustomCooldownIcon_" .. tostring(bd.id),
          defaultY = 120 - ((i - 1) * 50),
          spellID = tonumber(cfg.trackedSpellID),
          texture = C_Spell.GetSpellTexture(cfg.trackedSpellID),
          inCombat = _SB_PlayerInCombat,
        })
      else
        CustomIcons:Release("cooldown:" .. tostring(bd.id))
      end

      activeKeys[#activeKeys + 1] = key
      activeSet[tostring(key)] = true
      cooldownKeys[#cooldownKeys + 1] = key

      bd.frame:SetShown(cfg.presentation == "BAR")
      _SB_ApplyVisibility(bd, cfg)

      if cfg.presentation == "BAR" or cfg.presentation == "BUTTON" then
        bd.mode = "cooldown"
        bd.__puiEffectiveMode = "cooldown"

        if cfg.presentation == "BAR" then
          y = _SB_LayoutOne(bd, cfg, y)
        end

        bd.cooldownBar:SetShown(cfg.presentation == "BAR")
        _SB_UpdateCooldownBar(bd, cfg)
      end
    end
  end

  __PUI_PCM_SpellBars._keys = activeKeys
  __PUI_PCM_SpellBars._keysCount = #activeKeys
  __PUI_PCM_SpellBars._cooldownKeys = cooldownKeys

  for k, bd in pairs(bars) do
    if not activeSet[tostring(k)] then
      if bd then
        PCMPresentation.DisableCustomBarBuffGlow("cooldown:" .. tostring(bd.id))
        _SB_ReleaseStateAppearance(bd)
        CustomIcons:Release("cooldown:" .. tostring(bd.id))
        bd.__puiSBRuntimeEnabled = false
        bd.cfg = nil
        _SB_ClearTextDuration(bd)
        BarWidget.StopTimerBar(bd.cooldownBar)

        if bd.cooldownBar and bd.cooldownBar.Hide then
          bd.cooldownBar:Hide()
        end
        if bd.icon and bd.icon.Hide then
          bd.icon:Hide()
        end
        if bd.iconFrame and bd.iconFrame.Hide then
          bd.iconFrame:Hide()
        end
        if bd.frame and bd.frame.Hide then
          bd.frame:Hide()
        end

        FrameUtil:RefreshGhostMover("PCM_SpellBar_" .. tostring(bd.id))
      end
    end
  end
end

local function _SB_HandleVisibilityCombatEvent(event)
  if event == "PLAYER_REGEN_DISABLED" then
    _SB_PlayerInCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    _SB_PlayerInCombat = false
  else
    return
  end

  _SB_UpdateVisibilityAll()
end

function Cooldowns:_SpellBars_OnVisibilityEvent(event)
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  _SB_HandleVisibilityCombatEvent(event)
end

local _SB_DirtyCooldownSpellIDs = {}
local _SB_DirtyCooldownFlush = {}
local _SB_FullCooldownUpdate = false

local function _SB_GetCooldownSpellIndex()
  local host = __PUI_PCM_SpellBars
  local bars = host and host.bars
  local cooldownKeys = host and host._cooldownKeys
  if type(bars) ~= "table" or type(cooldownKeys) ~= "table" then
    return nil
  end

  local spellIndex = host._cooldownSpellIndex
  if spellIndex and host._cooldownSpellIndexGen == host._cfgGen then
    return spellIndex
  end

  spellIndex = {}

  for i = 1, #cooldownKeys do
    local bd = bars[cooldownKeys[i]]
    local cfg = bd and bd.cfg or nil
    local trackedSpellID = cfg and tonumber(cfg.trackedSpellID) or nil

    if bd and bd.__puiSBRuntimeEnabled == true and trackedSpellID then
      local bucket = spellIndex[trackedSpellID]
      if not bucket then
        bucket = {}
        spellIndex[trackedSpellID] = bucket
      end
      bucket[bd] = true

      local baseSpellID = C_Spell.GetBaseSpell(trackedSpellID)
      if not issecretvalue(baseSpellID)
        and type(baseSpellID) == "number"
        and baseSpellID ~= trackedSpellID
      then
        bucket = spellIndex[baseSpellID]
        if not bucket then
          bucket = {}
          spellIndex[baseSpellID] = bucket
        end
        bucket[bd] = true
      end
    end
  end

  host._cooldownSpellIndex = spellIndex
  host._cooldownSpellIndexGen = host._cfgGen
  return spellIndex
end

local function _SB_UpdateCooldownBarsAll(dirtySpellIDs, updateAll)
  local host = __PUI_PCM_SpellBars
  local bars = host and host.bars
  local cooldownKeys = host and host._cooldownKeys

  if not (bars and cooldownKeys) then
    return
  end

  if dirtySpellIDs == nil then
    updateAll = true
  end

  if updateAll == true then
    for i = 1, #cooldownKeys do
      local bd = bars[cooldownKeys[i]]
      if bd and bd.frame and bd.cfg and bd.__puiSBRuntimeEnabled == true then
        _SB_UpdateCooldownBar(bd, bd.cfg)
      elseif bd and bd.frame then
        bd.frame:Hide()
      end
    end
    return
  end

  local spellIndex = _SB_GetCooldownSpellIndex()
  if not spellIndex then
    return
  end

  local seen = host._cooldownDispatchSeen
  if not seen then
    seen = {}
    host._cooldownDispatchSeen = seen
  else
    for bd in pairs(seen) do
      seen[bd] = nil
    end
  end

  for spellID in pairs(dirtySpellIDs) do
    local bucket = spellIndex[spellID]
    if bucket then
      for bd in pairs(bucket) do
        if not seen[bd] then
          seen[bd] = true
          _SB_UpdateCooldownBar(bd, bd.cfg)
        end
      end
    end
  end
end

local function _SB_HasActiveCooldownPresentations()
  local host = __PUI_PCM_SpellBars
  local cooldownKeys = host and host._cooldownKeys
  return type(cooldownKeys) == "table" and #cooldownKeys > 0
end

local function _SB_MatchesCooldownEvent(spellID, baseSpellID)
  if issecretvalue(spellID) or type(spellID) ~= "number" then
    return true
  end

  local host = __PUI_PCM_SpellBars
  local spellIndex = host and host._cooldownSpellIndex or nil
  if not spellIndex or host._cooldownSpellIndexGen ~= host._cfgGen then
    spellIndex = _SB_GetCooldownSpellIndex()
  end
  if not spellIndex then
    return false
  end

  if spellIndex[spellID] then
    return true
  end

  if not issecretvalue(baseSpellID)
    and type(baseSpellID) == "number"
    and baseSpellID ~= spellID
    and spellIndex[baseSpellID]
  then
    return true
  end

  return false
end

local function _SB_SetCooldownEventRegistered(self, enabled)
  if enabled then
    if self.__puiSB_CooldownEventRegistered then
      return
    end

    self.__puiSB_CooldownEventRegistered = true
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "_SpellBars_OnSpellUpdate")
    return
  end

  if not self.__puiSB_CooldownEventRegistered then
    return
  end

  self.__puiSB_CooldownEventRegistered = false
  self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

local function _SB_FlushCooldownUpdate()
  _SB_UpdateFrame:Hide()
  _SB_UpdateQueued = false

  local dirtySpellIDs = _SB_DirtyCooldownSpellIDs
  _SB_DirtyCooldownSpellIDs = _SB_DirtyCooldownFlush
  _SB_DirtyCooldownFlush = dirtySpellIDs

  for spellID in pairs(_SB_DirtyCooldownSpellIDs) do
    _SB_DirtyCooldownSpellIDs[spellID] = nil
  end

  local updateAll = _SB_FullCooldownUpdate
  _SB_FullCooldownUpdate = false

  local cooldownKeys = __PUI_PCM_SpellBars._cooldownKeys
  if _SB_RuntimeEnabled and type(cooldownKeys) == "table" and #cooldownKeys > 0 then
    _SB_UpdateCooldownBarsAll(_SB_DirtyCooldownFlush, updateAll)
  end

  for spellID in pairs(_SB_DirtyCooldownFlush) do
    _SB_DirtyCooldownFlush[spellID] = nil
  end
end

local function _SB_ScheduleCooldownUpdate(spellID, baseSpellID)
  if not _SB_RuntimeEnabled then
    return
  end

  if not issecretvalue(spellID) and type(spellID) == "number" then
    _SB_DirtyCooldownSpellIDs[spellID] = true
    if not issecretvalue(baseSpellID) and type(baseSpellID) == "number" then
      _SB_DirtyCooldownSpellIDs[baseSpellID] = true
    end
  else
    _SB_FullCooldownUpdate = true
  end

  if _SB_UpdateQueued then
    return
  end

  _SB_UpdateQueued = true
  _SB_UpdateFrame:Show()
end

_SB_UpdateFrame:SetScript("OnUpdate", _SB_FlushCooldownUpdate)

function Cooldowns:_SpellBars_OnSpellUpdate(event, spellID, baseSpellID)
  local cooldownKeys = __PUI_PCM_SpellBars._cooldownKeys
  if not _SB_RuntimeEnabled or type(cooldownKeys) ~= "table" or #cooldownKeys == 0 then
    return
  end

  if _SB_MatchesCooldownEvent(spellID, baseSpellID) then
    _SB_ScheduleCooldownUpdate(spellID, baseSpellID)
  end
end

local function _SB_RemoveKeyFromList(list, target)
  if type(list) ~= "table" then
    return
  end

  local want = tostring(target)
  for i = #list, 1, -1 do
    if tostring(list[i]) == want then
      table.remove(list, i)
    end
  end
end

local function _SB_DeleteRuntimeBar(id)
  local host = __PUI_PCM_SpellBars
  local bars = host and host.bars
  if not bars then
    return
  end

  local key = id
  local bd = bars[key]

  if not bd then
    local numID = tonumber(id)
    if numID ~= nil then
      key = numID
      bd = bars[key]
    end
  end

  if not bd then
    return
  end

  PCMPresentation.ReleaseCustomBarBuffGlow("cooldown:" .. tostring(bd.id))
  _SB_ReleaseStateAppearance(bd)
  bd.cfg = nil
  _SB_ClearTextDuration(bd)
  BarWidget.StopTimerBar(bd.cooldownBar)

  if bd.cooldownBar and bd.cooldownBar.Hide then
    bd.cooldownBar:Hide()
  end
  if bd.text then
    if bd.text.SetText then
      bd.text:SetText("")
    end
    if bd.text.Hide then
      bd.text:Hide()
    end
  end
  if bd.icon and bd.icon.Hide then
    bd.icon:Hide()
  end
  if bd.iconFrame and bd.iconFrame.Hide then
    bd.iconFrame:Hide()
  end
  if bd.frame and bd.frame.Hide then
    bd.frame:Hide()
  end

  bars[key] = nil

  if host._keys then
    _SB_RemoveKeyFromList(host._keys, key)
    _SB_RemoveKeyFromList(host._keys, id)
  end

  if host._cooldownKeys then
    _SB_RemoveKeyFromList(host._cooldownKeys, key)
    _SB_RemoveKeyFromList(host._cooldownKeys, id)
  end
end

function Cooldowns:SpellBars_Rebuild()
  if not ns.PCM_IsModuleEnabledFast() then
    self:SpellBars_Disable()
    return
  end

  _SB_RebuildAll()
  _SB_SetCooldownEventRegistered(self, _SB_RuntimeEnabled and _SB_HasActiveCooldownPresentations())
end

function Cooldowns:SpellBars_RefreshBar(id, flags)
  if not ns.PCM_IsModuleEnabledFast() or not _SB_RuntimeEnabled then
    return
  end

  local host = __PUI_PCM_SpellBars
  local bars = host.bars
  local bd = bars[id]

  if not bd then
    local numID = tonumber(id)
    if numID ~= nil then
      bd = bars[numID]
    end
  end

  if not bd or not bd.cfg or bd.__puiSBRuntimeEnabled ~= true then
    return
  end

  flags = flags or { presentation = true }

  if flags.layout == true then
    local y = 0
    for index = 1, #(host._keys or {}) do
      local current = bars[host._keys[index]]
      if current and current.cfg and current.__puiSBRuntimeEnabled == true then
        if current.cfg.presentation == "BAR" then
          y = _SB_LayoutOne(current, current.cfg, y)
        else
          FrameUtil:UnregisterMover("PCM_SpellBar_" .. tostring(current.id))
        end

        _SB_ApplyVisibility(current, current.cfg)
        _SB_UpdateCooldownBar(current, current.cfg)
      end
    end
    return
  end

  if flags.presentation == true then
    _SB_ApplyPresentation(bd, bd.cfg)
    _SB_UpdateCooldownBar(bd, bd.cfg)
  end
  if flags.visibility == true then
    _SB_ApplyVisibility(bd, bd.cfg)
  end
end

function Cooldowns:SpellBars_DeleteBar(id)
  FrameUtil.ClearSmartSnapForKey("PCM_SpellBar_" .. tostring(id))
  CustomIcons:Delete("cooldown:" .. tostring(id))

  local root = Cooldowns.GetSpellBarsDB()
  if root then
    root[id] = nil

    local numID = tonumber(id)
    if numID ~= nil then
      root[numID] = nil
    end
  end

  _SB_DeleteRuntimeBar(id)
  self:SpellBars_Rebuild()
end

function Cooldowns:SpellBars_RefreshAfterTalentSwap()
  if not ns.PCM_IsModuleEnabledFast() or not _SB_RuntimeEnabled then
    return
  end

  if InCombatLockdown() then
    __PUI_PCM_SpellBars.pendingSpecTalentRefresh = true
    return
  end

  __PUI_PCM_SpellBars.pendingSpecTalentRefresh = false
  _SB_ClearKnownSpellCache()
  self:SpellBars_Rebuild()
end

PCMRuntime:RegisterSubscriber("SpellBars", {
  OnLifecycleEvent = function(event, ...)
    if not _SB_RuntimeEnabled then
      return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      Cooldowns:_SpellBars_OnVisibilityEvent(event)

      if event == "PLAYER_REGEN_ENABLED"
        and __PUI_PCM_SpellBars.pendingSpecTalentRefresh
        and not ns.PCM_IsTransitionPending()
      then
        Cooldowns:SpellBars_RefreshAfterTalentSwap()
      end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
      or event == "PLAYER_TALENT_UPDATE"
      or event == "ACTIVE_TALENT_GROUP_CHANGED"
      or event == "TRAIT_CONFIG_UPDATED"
    then
      Cooldowns:_SpellBars_OnTalentUpdate(event, ...)
    elseif event == "SPELLS_CHANGED" then
      if ns.PCM_IsTransitionPending() then
        __PUI_PCM_SpellBars.pendingSpecTalentRefresh = true
      else
        Cooldowns:SpellBars_RefreshAfterTalentSwap()
      end
    end
  end,
})

function Cooldowns:SpellBars_Enable()
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  _SB_InstallOnce()
  _SB_RuntimeEnabled = true
  PCMRuntime:SetSubscriberEnabled("SpellBars", true)
  self:SpellBars_Rebuild()

  _SB_SetCooldownEventRegistered(self, _SB_HasActiveCooldownPresentations())
end

function Cooldowns:SpellBars_Disable()
  _SB_RuntimeEnabled = false
  _SB_UpdateQueued = false
  _SB_UpdateFrame:Hide()
  wipe(_SB_DirtyCooldownSpellIDs)
  wipe(_SB_DirtyCooldownFlush)
  _SB_FullCooldownUpdate = false
  PCMRuntime:SetSubscriberEnabled("SpellBars", false)
  _SB_SetCooldownEventRegistered(self, false)

  local bars = __PUI_PCM_SpellBars.bars
  if not bars then
    return
  end

  for _, bd in pairs(bars) do
    if bd then
      PCMPresentation.DisableCustomBarBuffGlow("cooldown:" .. tostring(bd.id))
      _SB_ReleaseStateAppearance(bd)
      CustomIcons:Release("cooldown:" .. tostring(bd.id))
      _SB_ClearTextDuration(bd)
      BarWidget.StopTimerBar(bd.cooldownBar)
      if bd.frame and bd.frame.Hide then
        bd.frame:Hide()
      end
    end
  end
end

-- SpellBars self-install: events + integration hooks live here (not in PCM).
_SB_InstallOnce = function()
  if Cooldowns.__puiSB_Installed then
    return
  end

  Cooldowns.__puiSB_Installed = true
end

function Cooldowns:_SpellBars_ApplySettings(flags)
  if not flags then
    return
  end

  if flags.profile == true then
    _SB_ClearKnownSpellCache()
  end
end

function Cooldowns:_SpellBars_SoftRebuild(flags)
  if not flags then
    return
  end

  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    self:SpellBars_Rebuild()
  end
end


  Cooldowns._SpellBars_OnTalentUpdate = P:Def('Cooldowns:_SpellBars_OnTalentUpdate', Cooldowns._SpellBars_OnTalentUpdate)
  _SB_IsTrackedSpellKnown = P:Def('_SB_IsTrackedSpellKnown', _SB_IsTrackedSpellKnown)
  _SB_ClearTextDuration = P:Def('_SB_ClearTextDuration', _SB_ClearTextDuration)
  _SB_ApplyTextDuration = P:Def('_SB_ApplyTextDuration', _SB_ApplyTextDuration)
  _SB_EnsureBarFrame = P:Def('_SB_EnsureBarFrame', _SB_EnsureBarFrame)
  _SB_ApplyAnchor = P:Def('_SB_ApplyAnchor', _SB_ApplyAnchor)
  _SB_SaveAnchor = P:Def('_SB_SaveAnchor', _SB_SaveAnchor)
  _SB_RegisterMover = P:Def('_SB_RegisterMover', _SB_RegisterMover)
  _SB_ApplyBarModeAppearance = P:Def('_SB_ApplyBarModeAppearance', _SB_ApplyBarModeAppearance)
  _SB_ReleaseStateAppearance = P:Def('_SB_ReleaseStateAppearance', _SB_ReleaseStateAppearance)
  _SB_ApplyStateAppearance = P:Def('_SB_ApplyStateAppearance', _SB_ApplyStateAppearance)
  _SB_ApplyPresentation = P:Def('_SB_ApplyPresentation', _SB_ApplyPresentation)
  _SB_LayoutOne = P:Def('_SB_LayoutOne', _SB_LayoutOne)
  _SB_UpdateCooldownBar = P:Def('_SB_UpdateCooldownBar', _SB_UpdateCooldownBar)
  _SB_UpdateVisibilityAll = P:Def('_SB_UpdateVisibilityAll', _SB_UpdateVisibilityAll)
  _SB_HandleVisibilityCombatEvent = P:Def('_SB_HandleVisibilityCombatEvent', _SB_HandleVisibilityCombatEvent)
  Cooldowns._SpellBars_OnVisibilityEvent = P:Def('Cooldowns:_SpellBars_OnVisibilityEvent', Cooldowns._SpellBars_OnVisibilityEvent)
  _SB_GetCooldownSpellIndex = P:Def('_SB_GetCooldownSpellIndex', _SB_GetCooldownSpellIndex)
  _SB_UpdateCooldownBarsAll = P:Def('_SB_UpdateCooldownBarsAll', _SB_UpdateCooldownBarsAll)
  _SB_HasActiveCooldownPresentations = P:Def('_SB_HasActiveCooldownPresentations', _SB_HasActiveCooldownPresentations)
  _SB_MatchesCooldownEvent = P:Def('_SB_MatchesCooldownEvent', _SB_MatchesCooldownEvent)
  _SB_SetCooldownEventRegistered = P:Def('_SB_SetCooldownEventRegistered', _SB_SetCooldownEventRegistered)
  _SB_ScheduleCooldownUpdate = P:Def('_SB_ScheduleCooldownUpdate', _SB_ScheduleCooldownUpdate)
  Cooldowns._SpellBars_OnSpellUpdate = P:Def('Cooldowns:_SpellBars_OnSpellUpdate', Cooldowns._SpellBars_OnSpellUpdate)
  _SB_RemoveKeyFromList = P:Def('_SB_RemoveKeyFromList', _SB_RemoveKeyFromList)
  _SB_DeleteRuntimeBar = P:Def('_SB_DeleteRuntimeBar', _SB_DeleteRuntimeBar)
  Cooldowns.SpellBars_Rebuild = P:Def('Cooldowns:SpellBars_Rebuild', Cooldowns.SpellBars_Rebuild)
  Cooldowns.SpellBars_RefreshBar = P:Def('Cooldowns:SpellBars_RefreshBar', Cooldowns.SpellBars_RefreshBar)
  Cooldowns.SpellBars_DeleteBar = P:Def('Cooldowns:SpellBars_DeleteBar', Cooldowns.SpellBars_DeleteBar)
  Cooldowns.SpellBars_RefreshAfterTalentSwap = P:Def('Cooldowns:SpellBars_RefreshAfterTalentSwap', Cooldowns.SpellBars_RefreshAfterTalentSwap)
  Cooldowns.SpellBars_Enable = P:Def('Cooldowns:SpellBars_Enable', Cooldowns.SpellBars_Enable)
  Cooldowns.SpellBars_Disable = P:Def('Cooldowns:SpellBars_Disable', Cooldowns.SpellBars_Disable)
  Cooldowns._SpellBars_ApplySettings = P:Def('Cooldowns:_SpellBars_ApplySettings', Cooldowns._SpellBars_ApplySettings)
  Cooldowns._SpellBars_SoftRebuild = P:Def('Cooldowns:_SpellBars_SoftRebuild', Cooldowns._SpellBars_SoftRebuild)
  _SB_ApplyVisibility = P:Def('_SB_ApplyVisibility', _SB_ApplyVisibility)
  _SB_RebuildAll = P:Def('_SB_RebuildAll', _SB_RebuildAll)
  _SB_InstallOnce = P:Def('_SB_InstallOnce', _SB_InstallOnce)
