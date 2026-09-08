local ADDON_NAME, ns = ...



local _G = _G
local UIParent = _G.UIParent
local InCombatLockdown = _G.InCombatLockdown
local PLAYER_CLASS = select(2, _G.UnitClass("player"))
local C_ClassColor = _G.C_ClassColor
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local Cooldowns = ns.Modules.CooldownManager
local PCMRuntime = ns.PCMRuntime
local P = ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "CustomChargeCooldownBars" })


local FrameUtil = ns.FrameUtil
local FrameScale = ns.FrameScale
local BarWidget = ns.BarWidget
local Presentation = ns.Presentation
local PCMPresentation = ns.PCMPresentation
local CustomIcons = ns.PCMCustomIcons
local Pixel = ns.Pixel
local Round = Pixel.Round
local math_floor = _G.math.floor
local tostring = _G.tostring
local _CSB_KnownSpellCache = {}
local _CSB_ClassColorR, _CSB_ClassColorG, _CSB_ClassColorB


local _CSB_InstallOnce
local _CSB_RebuildAll
local _CSB_UpdateAll
local _CSB_QueueUpdateAll
local _CSB_SetChargeEventRegistered
local _CSB_ApplyVisibility
local _CSB_UpdateOneBar


local __PUI_PCM_CooldownStackBars = {
  bars = {},
  keys = {},
  inCombat = false,
  chargeEventRegistered = false,
  chargeUpdateQueued = false,
  chargeEventFrame = _G.CreateFrame("Frame"),
  chargeUpdateFrame = _G.CreateFrame("Frame"),
}
__PUI_PCM_CooldownStackBars.chargeUpdateFrame:Hide()

local INTERP = Enum.StatusBarInterpolation.None
local DIR_ELAPSED = Enum.StatusBarTimerDirection.ElapsedTime


local function _CSB_Snap(value)
  value = tonumber(value) or 0

  return FrameScale:Scale(value)
end

local function _CSB_GetClassColor()
  if _CSB_ClassColorR then
    return _CSB_ClassColorR, _CSB_ClassColorG, _CSB_ClassColorB
  end

  local c = C_ClassColor.GetClassColor(PLAYER_CLASS)
  local r, g, b = c.r, c.g, c.b

  _CSB_ClassColorR, _CSB_ClassColorG, _CSB_ClassColorB = r, g, b
  return r, g, b
end

local function _CSB_ClearKnownSpellCache()
  for spellID in pairs(_CSB_KnownSpellCache) do
    _CSB_KnownSpellCache[spellID] = nil
  end

  Cooldowns:ClearSavedSpellKnownCache()
end

local function _CSB_IsTrackedSpellKnown(cfg)
  local spellID = Cooldowns:GetTrackedSpellIDForCurrentSpec(cfg)
  if not spellID then
    return false
  end

  local currentSpecID = Cooldowns:GetCurrentSpecializationID() or 0
  local cacheKey = tostring(spellID) .. ":" .. tostring(currentSpecID)

  local cached = _CSB_KnownSpellCache[cacheKey]
  if cached ~= nil then
    return cached == true
  end

  local known = C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)
  _CSB_KnownSpellCache[cacheKey] = known

  return known
end

local function _CSB_SetFontStringShown(fontString, shown)
  if fontString then
    fontString:SetShown(shown == true)
  end
end

local function _CSB_DisableDurationBinding(binding, fontString, text, shown)
  if binding then
    binding:Disable()
  end

  if fontString then
    fontString:SetText(text or "")
    _CSB_SetFontStringShown(fontString, shown)
  end
end

local function _CSB_ForEachChargeSlot(barData, callback)
  for _, slot in ipairs(barData and barData.chargeSlots or {}) do
    callback(slot)
  end

  for _, slot in ipairs(barData and barData.chargeSlotPool or {}) do
    callback(slot)
  end
end

local function _CSB_DeactivateChargeSlot(slot)
  if not slot then
    return
  end

  if slot.rechargeBar then
    BarWidget.StopTimerBar(slot.rechargeBar)
    slot.rechargeBar:Hide()
  end
  if slot.fullBar then
    slot.fullBar:SetValue(0)
  end
  if slot.frame then
    slot.frame:Hide()
  end
end

local function _CSB_EnsureBarFrame(id)
  local bars = __PUI_PCM_CooldownStackBars.bars
  local bd = bars[id]
  if bd and bd.frame and bd.frame.GetObjectType then
    return bd
  end

  local safeId = tostring(id):gsub("[^%w]", "_")
  local frameName = "PleebUI_PCM_CooldownStackBar_" .. safeId

  bd = Presentation.Create("PCMBar", UIParent, {
    name = frameName,
    template = "charge",
  })
  bars[id] = bd

  bd.id = id
  bd.frame.__puiCooldownStackBarData = bd
  bd.frame.barData = bd
  bd.timerBinding = BarWidget.CreateDurationBinding(bd.timerText)
  bd.hiddenBySpec = false

  return bd
end

local function _CSB_RegisterMover(barData, cfg)
  if not (barData and barData.frame and cfg) then
    return
  end

  local key = "PCMChargeCooldownBar:" .. tostring(barData.id)
  local label = Cooldowns:GetCustomBarDisplayName(cfg)

  local function SavePosition(frame)
    local root = Cooldowns.GetCooldownStackBarsDB()
    local entry = root and root[barData.id]
    local anchorFrame = frame or barData.frame
    if not entry or not anchorFrame then
      return
    end

    local x, y = FrameUtil.GetMoverOffsets(anchorFrame)
    entry.posX = Round(x or 0)
    entry.posY = Round(y or 0)

    barData.frame:ClearAllPoints()
    barData.frame:SetPoint(
      "CENTER",
      UIParent,
      "CENTER",
      _CSB_Snap(entry.posX),
      _CSB_Snap(entry.posY)
    )
  end

  local moverOpts = {
    label = label,
    optionsString = "CooldownManager,custom_bars,chargeSpell:" .. tostring(barData.id),
    useOverlayDrag = true,
    liveFrame = function()
      return barData.frame
    end,
    shouldShow = function()
      return cfg.enabled ~= false
        and cfg.presentation == "BAR"
        and barData.hiddenBySpec ~= true
    end,
    savePosition = SavePosition,
    onDragStop = function()
      FrameUtil:RefreshGhostMover(key)
    end,
    resetPosition = function()
      local root = Cooldowns.GetCooldownStackBarsDB()
      local entry = root and root[barData.id]
      if not entry then
        return
      end
      entry.posX = nil
      entry.posY = nil
      _CSB_RebuildAll()
      FrameUtil:RefreshGhostMover(key)
    end,
    quickSettings = function()
      local function Refresh(flags)
        Cooldowns:CooldownStackBars_RefreshBar(barData.id, flags)
        FrameUtil:RefreshGhostMover(key)
        FrameUtil.RefreshSmartSnapState(key)
      end

      return {
        ownerKey = key,
        title = label,
        description = "Live charge bar settings.",
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
            max = 5,
            step = 1,
            get = function()
              if cfg.showSlotBorder ~= true then
                return 0
              end
              return cfg.slotBorderThickness or 2
            end,
            set = function(value)
              local borderSize = Round(value)
              cfg.slotBorderThickness = borderSize
              cfg.showSlotBorder = borderSize > 0
              Refresh({ presentation = true })
            end,
          },
          {
            type = "slider",
            label = "Font size",
            min = 6,
            max = 30,
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
        Cooldowns:CooldownStackBars_RefreshBar(barData.id, { presentation = true, layout = true })
        FrameUtil:RefreshGhostMover(key)
      end,
      getDesign = function()
        local function CopyColor(color)
          if type(color) ~= "table" then return nil end
          return { color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a }
        end
        return {
          texture = cfg.texture,
          borderSize = cfg.showSlotBorder == true and (cfg.slotBorderThickness or 2) or 0,
          borderColor = CopyColor(cfg.slotBorderColor),
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
        if design.borderSize ~= nil then
          local borderSize = Round(design.borderSize)
          if borderSize < 0 then borderSize = 0 end
          if borderSize > 5 then borderSize = 5 end
          cfg.slotBorderThickness = borderSize
          cfg.showSlotBorder = borderSize > 0
        end
        if type(design.borderColor) == "table" then cfg.slotBorderColor = CopyColor(design.borderColor) end
        Cooldowns:CooldownStackBars_RefreshBar(barData.id, { presentation = true })
        FrameUtil:RefreshGhostMover(key)
      end,
    },
  }

  FrameUtil:EnsureGhostMover(key, moverOpts)
end

local function _CSB_ApplyPresentation(barData, cfg)
  local color
  if cfg.useClassColor then
    local r, g, b = _CSB_GetClassColor()
    color = { r, g, b, 1 }
  else
    color = cfg.barColor
  end

  Presentation.Apply("PCMBar", barData, {
    config = cfg,
    skipVisibility = true,
    width = cfg.width,
    height = cfg.height,
    showIcon = cfg.showIcon == true,
    iconSize = cfg.height,
    maxCharges = barData.maxCharges or cfg.maxCharges or 2,
    color = color,
    font = {
      font = cfg.font,
      size = cfg.fontSize or 14,
      flags = cfg.fontOutline or cfg.outline or "OUTLINE",
      color = cfg.fontColor,
    },
    visible = cfg.enabled ~= false,
    showText = cfg.showText ~= false,
  })

  PCMPresentation.ConfigureCustomBarBuffGlow(
    "charge:" .. tostring(barData.id),
    barData.frame,
    cfg
  )

  local spellID = tonumber(cfg.trackedSpellID)
  if cfg.showIcon and spellID and barData.icon and barData.__iconSpellID ~= spellID then
    barData.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    barData.__iconSpellID = spellID
  end
end

local function _CSB_ApplyLayout(barData, cfg, index)
  barData.__puiCSBDurationStateApplied = false
  barData.__puiCSBDurationStateCleared = nil
  barData.__puiCSBAppliedAlpha = nil
  barData.__puiCSBAppliedDesaturated = nil
  _CSB_ApplyPresentation(barData, cfg)

  local frame = barData.frame
  local x = tonumber(cfg.posX)
  local y = tonumber(cfg.posY)
  frame:ClearAllPoints()
  if x and y then
    frame:SetPoint("CENTER", UIParent, "CENTER", Round(x), Round(y))
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, Round(180 - ((index - 1) * 44)))
  end

  _CSB_RegisterMover(barData, cfg)
end

local function _CSB_ResolveMaxCharges(barData, cfg, chargeInfo)
  local maxCharges = tonumber(cfg and cfg.maxCharges) or tonumber(barData and barData.maxCharges) or 2
  local liveMax
  if chargeInfo then
    liveMax = chargeInfo.maxCharges
  end

  if not _G.issecretvalue(liveMax) then
    maxCharges = tonumber(liveMax) or maxCharges
  end

  maxCharges = math_floor(maxCharges + 0.5)
  if maxCharges < 1 then maxCharges = 1 end
  if maxCharges > 60 then maxCharges = 60 end

  return maxCharges
end

local function _CSB_ApplyResolvedMaxCharges(barData, maxCharges)
  if not barData then
    return false
  end

  maxCharges = tonumber(maxCharges) or 1
  maxCharges = math_floor(maxCharges + 0.5)
  if maxCharges < 1 then maxCharges = 1 end
  if maxCharges > 60 then maxCharges = 60 end

  if tonumber(barData.maxCharges) == maxCharges and barData.chargeSlots and #barData.chargeSlots == maxCharges then
    return false
  end

  barData.maxCharges = maxCharges
  return true
end


local function _CSB_ClearDurationState(barData)
  if not barData or barData.__puiCSBDurationStateCleared == true then
    return
  end

  _CSB_DisableDurationBinding(barData.timerBinding, barData.timerText, "", false)
  barData.timerTextContainer:Hide()

  for _, slot in ipairs(barData.chargeSlots or {}) do
    BarWidget.StopTimerBar(slot.rechargeBar)
    slot.rechargeBar:Hide()
  end

  barData.__puiCSBDurationStateApplied = false
  barData.__puiCSBDurationStateCleared = true
end

local function _CSB_ApplyDurationState(barData, cfg, duration)
  local showText = cfg.showText ~= false
  local direction = cfg.durationBarFillMode == "drain"
    and Enum.StatusBarTimerDirection.RemainingTime
    or DIR_ELAPSED
  local stateChanged = not barData.__puiCSBDurationStateApplied
    or barData.__puiCSBShowText ~= showText
    or barData.__puiCSBDirection ~= direction

  for _, slot in ipairs(barData.chargeSlots) do
    if stateChanged then
      slot.rechargeBar:Show()
    end
    slot.rechargeBar:SetTimerDuration(duration, INTERP, direction)
  end

  if showText then
    barData.timerBinding:SetDuration(duration)
    if stateChanged then
      barData.timerBinding:Enable()
      _CSB_SetFontStringShown(barData.timerText, true)
      barData.timerTextContainer:Show()
    end
  elseif stateChanged then
    _CSB_DisableDurationBinding(barData.timerBinding, barData.timerText, "", false)
    barData.timerTextContainer:Hide()
  end

  if stateChanged then
    barData.__puiCSBDurationStateApplied = true
    barData.__puiCSBShowText = showText
    barData.__puiCSBDirection = direction
  end
  barData.__puiCSBDurationStateCleared = nil
end

local function _CSB_ApplyStateAppearance(barData, cfg)
  if cfg.presentation ~= "BAR" then
    PCMPresentation.ReleaseCustomTrackerStateGlow("charge-state:" .. tostring(barData.id))
    return
  end
  local active = barData.__puiChargeActive == true
  local stateAlpha = active and cfg.onCooldownAlpha or cfg.readyAlpha
  local alpha = (tonumber(stateAlpha) or 100) / 100 * (barData.__puiCSBAlpha or 1)
  if barData.__puiCSBAppliedAlpha ~= alpha then
    barData.__puiCSBAppliedAlpha = alpha
    barData.frame:SetAlpha(alpha)
  end

  local desaturated = active and cfg.desaturateCooldown == true or not active and cfg.desaturateReady == true
  if barData.__puiCSBAppliedDesaturated ~= desaturated then
    barData.__puiCSBAppliedDesaturated = desaturated
    for index = 1, #(barData.chargeSlots or {}) do
      local slot = barData.chargeSlots[index]
      local texture = slot and slot.rechargeBar and slot.rechargeBar:GetStatusBarTexture()
      if texture then
        texture:SetDesaturated(desaturated)
      end
    end
  end
  local style = active and cfg.cooldownGlowStyle or cfg.readyGlowStyle
  local color = active and cfg.cooldownGlowColor or cfg.readyGlowColor
  PCMPresentation.ApplyCustomTrackerStateGlow(
    "charge-state:" .. tostring(barData.id),
    barData.frame,
    alpha > 0 and style or "NONE",
    color
  )
end

_CSB_UpdateOneBar = function(barData, cfg, chargeInfo)
  if not (barData and barData.frame and cfg) then
    return
  end

  local barEnabled = cfg.presentation == "BAR"
  if barEnabled and (not barData.chargeSlots or #barData.chargeSlots == 0) then
    return
  end

  local spellID = tonumber(cfg.trackedSpellID)
  if not spellID then
    _CSB_ClearDurationState(barData)
    barData.frame:Hide()
    CustomIcons:Release("charge:" .. tostring(barData.id))
    return
  end

  if barData.hiddenBySpec then
    _CSB_ClearDurationState(barData)
    barData.frame:Hide()
    return
  end

  if chargeInfo == nil then
    chargeInfo = C_Spell.GetSpellCharges(spellID)
  end

  local duration = C_Spell.GetSpellChargeDuration(spellID)
  barData.__puiChargeActive = chargeInfo.isActive == true

  barData.frame:SetShown(barEnabled)

  if cfg.showIcon and barData.icon and barData.__iconSpellID ~= spellID then
    barData.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    barData.__iconSpellID = spellID
  end

  if barEnabled then
    PCMPresentation.ApplyChargeCount(barData, chargeInfo.currentCharges)
    _CSB_ApplyDurationState(barData, cfg, duration)
  else
    _CSB_ClearDurationState(barData)
  end
  CustomIcons:UpdateCharge(
    "charge:" .. tostring(barData.id),
    duration,
    chargeInfo.currentCharges,
    barData.maxCharges,
    chargeInfo.isActive == true
  )
  _CSB_ApplyStateAppearance(barData, cfg)
end


_CSB_ApplyVisibility = function(barData, cfg)
  if not (barData and barData.frame and barData.frame.SetAlpha) then
    return
  end

  local alpha = 1
  if cfg.hideOutOfCombat == true and not __PUI_PCM_CooldownStackBars.inCombat then
    local a = tonumber(cfg.outOfCombatAlpha) or 0
    if a < 0 then a = 0 end
    if a > 100 then a = 100 end
    alpha = a / 100
  end

  if barData.__puiCSBAlpha ~= alpha then
    barData.__puiCSBAlpha = alpha
  end
  if cfg.presentation == "BAR" then
    PCMPresentation.SetCustomBarBuffGlowContextAlpha(
      "charge:" .. tostring(barData.id),
      alpha
    )
  end
  _CSB_ApplyStateAppearance(barData, cfg)
  CustomIcons:RefreshVisibility("charge:" .. tostring(barData.id), __PUI_PCM_CooldownStackBars.inCombat)
end

_CSB_RebuildAll = function()
  if InCombatLockdown() then
    __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh = true
  end

  local root = Cooldowns.GetCooldownStackBarsDB() or {}
  local bars = __PUI_PCM_CooldownStackBars.bars
  local sortedKeys = {}

  for key in pairs(root) do
    if type(key) == "number" or type(key) == "string" then
      sortedKeys[#sortedKeys + 1] = key
    end
  end

  table.sort(sortedKeys, function(a, b)
    local ea = root[a]
    local eb = root[b]
    local la = tostring((type(ea) == "table" and ea.label) or "")
    local lb = tostring((type(eb) == "table" and eb.label) or "")
    if la == lb then
      return tostring(a) < tostring(b)
    end
    return la < lb
  end)

  local activeKeys = {}
  local activeSet = {}
  local order = 1

  for i = 1, #sortedKeys do
    local key = sortedKeys[i]
    local cfg = Cooldowns.NormalizeCooldownStackBarEntry(root[key], key)
    local shouldShow = cfg.enabled ~= false
      and (cfg.presentation == "BAR" or cfg.presentation == "BUTTON")
      and _CSB_IsTrackedSpellKnown(cfg)
    local chargeInfo

    if shouldShow then
      chargeInfo = C_Spell.GetSpellCharges(cfg.trackedSpellID)
      shouldShow = chargeInfo ~= nil
    end

    if not shouldShow then
      local barData = bars[key]
      if not barData then
        local numID = tonumber(key)
        if numID ~= nil then
          barData = bars[numID]
        end
      end

      if barData then
        PCMPresentation.DisableCustomBarBuffGlow("charge:" .. tostring(barData.id))
        PCMPresentation.ReleaseCustomTrackerStateGlow("charge-state:" .. tostring(barData.id))
        CustomIcons:Release("charge:" .. tostring(barData.id))
        barData.hiddenBySpec = true
        _CSB_ClearDurationState(barData)
        if barData.frame then
          barData.frame:Hide()
        end
      end
    else
      local barData = _CSB_EnsureBarFrame(key)

      barData.cfg = cfg
      barData.__order = order
      barData.hiddenBySpec = false
      barData.maxCharges = _CSB_ResolveMaxCharges(barData, cfg, chargeInfo)
      _CSB_ApplyResolvedMaxCharges(barData, barData.maxCharges)

      if cfg.presentation == "BUTTON" then
        FrameUtil:UnregisterMover("PCMChargeCooldownBar:" .. tostring(barData.id))
        CustomIcons:Configure("charge:" .. tostring(barData.id), cfg, {
          kind = "charge",
          label = Cooldowns:GetCustomBarDisplayName(cfg) .. " icon",
          optionsString = "CooldownManager,custom_bars,chargeSpell:" .. tostring(barData.id),
          moverKey = "PCM_CustomChargeIcon_" .. tostring(barData.id),
          defaultY = 60 - ((i - 1) * 50),
          spellID = tonumber(cfg.trackedSpellID),
          texture = C_Spell.GetSpellTexture(cfg.trackedSpellID),
          inCombat = __PUI_PCM_CooldownStackBars.inCombat,
        })
      else
        CustomIcons:Release("charge:" .. tostring(barData.id))
      end

      activeKeys[#activeKeys + 1] = key
      activeSet[tostring(key)] = true

      if cfg.presentation == "BAR" then
        _CSB_ApplyLayout(barData, cfg, order)
      else
        barData.frame:Hide()
      end
      _CSB_UpdateOneBar(barData, cfg, chargeInfo)
      _CSB_ApplyVisibility(barData, cfg)
      if cfg.presentation == "BAR" then
        order = order + 1
      end
    end
  end

  __PUI_PCM_CooldownStackBars.keys = activeKeys
  _CSB_SetChargeEventRegistered(#activeKeys > 0)

  for key, barData in pairs(bars) do
    if not activeSet[tostring(key)] and barData then
      PCMPresentation.DisableCustomBarBuffGlow("charge:" .. tostring(barData.id))
      PCMPresentation.ReleaseCustomTrackerStateGlow("charge-state:" .. tostring(barData.id))
      CustomIcons:Release("charge:" .. tostring(barData.id))
      barData.hiddenBySpec = true
      if barData.cfg then
        _CSB_ClearDurationState(barData)
      end
      if barData.frame then
        barData.frame:Hide()
      end

      FrameUtil:RefreshGhostMover("PCMChargeCooldownBar:" .. tostring(barData.id))
    end
  end
end

_CSB_UpdateAll = function()
  local keys = __PUI_PCM_CooldownStackBars.keys
  local bars = __PUI_PCM_CooldownStackBars.bars

  for i = 1, #keys do
    local key = keys[i]
    local barData = bars[key]
    if barData and barData.frame and barData.cfg then
      _CSB_UpdateOneBar(barData, barData.cfg)
    end
  end
end

_CSB_QueueUpdateAll = function()
  local host = __PUI_PCM_CooldownStackBars
  if host.chargeUpdateQueued == true or host.chargeEventRegistered ~= true then
    return
  end

  host.chargeUpdateQueued = true
  host.chargeUpdateFrame:Show()
end

__PUI_PCM_CooldownStackBars.chargeUpdateFrame:SetScript("OnUpdate", function(frame)
  frame:Hide()

  local host = __PUI_PCM_CooldownStackBars
  if host.chargeUpdateQueued ~= true then
    return
  end

  host.chargeUpdateQueued = false
  if host.chargeEventRegistered == true and ns.PCM_IsModuleEnabledFast() then
    _CSB_UpdateAll()
  end
end)

_CSB_SetChargeEventRegistered = function(enabled)
  local host = __PUI_PCM_CooldownStackBars
  local want = enabled == true

  if host.chargeEventRegistered == want then
    return
  end

  host.chargeEventRegistered = want
  if want then
    host.chargeEventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
  else
    host.chargeEventFrame:UnregisterEvent("SPELL_UPDATE_CHARGES")
    host.chargeUpdateQueued = false
    host.chargeUpdateFrame:Hide()
  end
end

__PUI_PCM_CooldownStackBars.chargeEventFrame:SetScript("OnEvent", function()
  if ns.PCM_IsModuleEnabledFast() then
    _CSB_QueueUpdateAll()
  end
end)

local function _CSB_RemoveKeyFromList(list, target)
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

local function _CSB_DeleteRuntimeBar(id)
  local host = __PUI_PCM_CooldownStackBars
  local bars = host and host.bars
  if not bars then
    return
  end

  local key = id
  local barData = bars[key]

  if not barData then
    local numID = tonumber(id)
    if numID ~= nil then
      key = numID
      barData = bars[key]
    end
  end

  if not barData then
    return
  end

    PCMPresentation.ReleaseCustomBarBuffGlow("charge:" .. tostring(barData.id))
    PCMPresentation.ReleaseCustomTrackerStateGlow("charge-state:" .. tostring(barData.id))
  barData.cfg = nil

  _CSB_DisableDurationBinding(barData.timerBinding, barData.timerText, "", false)
  if barData.timerTextContainer then
    barData.timerTextContainer:Hide()
  end

  _CSB_ForEachChargeSlot(barData, function(slot)
    _CSB_DeactivateChargeSlot(slot)
    if slot.background then slot.background:Hide() end
    if slot.fullBar then slot.fullBar:Hide() end
    if slot.borderFrame then slot.borderFrame:Hide() end
  end)

  if barData.iconFrame then
    barData.iconFrame:Hide()
  end

  if barData.frame then
    barData.frame:Hide()
  end

  local moverKey = "PCMChargeCooldownBar:" .. tostring(barData.id)
  local ghost = FrameUtil:RefreshGhostMover(moverKey)
  if ghost then
    ghost:Hide()
  end
  FrameUtil:UnregisterMover(moverKey)

  bars[key] = nil

  if host.keys then
    _CSB_RemoveKeyFromList(host.keys, key)
    _CSB_RemoveKeyFromList(host.keys, id)
  end
end

function Cooldowns:CooldownStackBars_Rebuild()
  if not ns.PCM_IsModuleEnabledFast() then
    self:CooldownStackBars_Disable()
    return
  end

  _CSB_RebuildAll()
  ns.Modules.PCM_BB:RefreshViewerHiddenState()
end

function Cooldowns:CooldownStackBars_RefreshBar(id, flags)
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  local bars = __PUI_PCM_CooldownStackBars.bars
  local barData = bars[id]

  if not barData then
    local numID = tonumber(id)
    if numID ~= nil then
      barData = bars[numID]
    end
  end

  if not barData or not barData.cfg or barData.hiddenBySpec == true then
    return
  end

  flags = flags or { presentation = true }

  if flags.layout == true then
    if barData.cfg.presentation == "BAR" then
      _CSB_ApplyLayout(barData, barData.cfg, barData.__order or 1)
    else
      FrameUtil:UnregisterMover("PCMChargeCooldownBar:" .. tostring(barData.id))
    end
  elseif flags.presentation == true then
    _CSB_ApplyPresentation(barData, barData.cfg)
  end

  if flags.presentation == true or flags.layout == true then
    _CSB_UpdateOneBar(barData, barData.cfg)
  end

  if flags.visibility == true or flags.layout == true then
    _CSB_ApplyVisibility(barData, barData.cfg)
  end
end

function Cooldowns:CooldownStackBars_DeleteBar(id)
  FrameUtil.ClearSmartSnapForKey("PCMChargeCooldownBar:" .. tostring(id))
  CustomIcons:Delete("charge:" .. tostring(id))

  local root = Cooldowns.GetCooldownStackBarsDB()
  if root then
    root[id] = nil

    local numID = tonumber(id)
    if numID ~= nil then
      root[numID] = nil
    end
  end

  _CSB_DeleteRuntimeBar(id)
  self:CooldownStackBars_Rebuild()
end

function Cooldowns:CooldownStackBars_Enable()
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  _CSB_InstallOnce()
  PCMRuntime:SetSubscriberEnabled("CooldownStackBars", true)
  self:CooldownStackBars_Rebuild()
end

function Cooldowns:CooldownStackBars_Disable()
  PCMRuntime:SetSubscriberEnabled("CooldownStackBars", false)
  _CSB_SetChargeEventRegistered(false)

  local bars = __PUI_PCM_CooldownStackBars.bars
  for _, barData in pairs(bars) do
    if barData then
      PCMPresentation.DisableCustomBarBuffGlow("charge:" .. tostring(barData.id))
      PCMPresentation.ReleaseCustomTrackerStateGlow("charge-state:" .. tostring(barData.id))
      CustomIcons:Release("charge:" .. tostring(barData.id))
      _CSB_DisableDurationBinding(barData.timerBinding, barData.timerText, "", false)
      if barData.timerTextContainer then
        barData.timerTextContainer:Hide()
      end
      _CSB_ForEachChargeSlot(barData, _CSB_DeactivateChargeSlot)
      if barData.frame then
        barData.frame:Hide()
      end
    end
  end
end

function Cooldowns:_CooldownStackBars_OnCombatEvent(event)
  __PUI_PCM_CooldownStackBars.inCombat = event == "PLAYER_REGEN_DISABLED"

  local keys = __PUI_PCM_CooldownStackBars.keys
  local bars = __PUI_PCM_CooldownStackBars.bars

  for i = 1, #keys do
    local barData = bars[keys[i]]
    if barData and barData.cfg then
      _CSB_ApplyVisibility(barData, barData.cfg)
    end
  end
end

function Cooldowns:_CooldownStackBars_OnSpecTalentEvent(event, unit)
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
    return
  end

  __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh = true
end

function Cooldowns:CooldownStackBars_RefreshAfterTalentSwap()
  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  if InCombatLockdown() then
    __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh = true
    return
  end

  __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh = false
  _CSB_ClearKnownSpellCache()
  self:CooldownStackBars_Rebuild()
end

PCMRuntime:RegisterSubscriber("CooldownStackBars", {
  OnLifecycleEvent = function(event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      Cooldowns:_CooldownStackBars_OnCombatEvent(event)

      if event == "PLAYER_REGEN_ENABLED"
        and __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh
        and not ns.PCM_IsTransitionPending()
      then
        Cooldowns:CooldownStackBars_RefreshAfterTalentSwap()
      end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
      if __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh
        and not ns.PCM_IsTransitionPending()
      then
        Cooldowns:CooldownStackBars_RefreshAfterTalentSwap()
      end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
      or event == "PLAYER_TALENT_UPDATE"
      or event == "ACTIVE_TALENT_GROUP_CHANGED"
      or event == "TRAIT_CONFIG_UPDATED"
    then
      Cooldowns:_CooldownStackBars_OnSpecTalentEvent(event, ...)
    elseif event == "SPELLS_CHANGED" then
      if ns.PCM_IsTransitionPending() then
        __PUI_PCM_CooldownStackBars.pendingSpecTalentRefresh = true
      else
        Cooldowns:CooldownStackBars_RefreshAfterTalentSwap()
      end
    end
  end,
})

_CSB_InstallOnce = function()
  if __PUI_PCM_CooldownStackBars.installed then
    return
  end
  __PUI_PCM_CooldownStackBars.installed = true
  __PUI_PCM_CooldownStackBars.inCombat = InCombatLockdown()
end

function Cooldowns:_CooldownStackBars_ApplySettings(flags)
  if not flags then
    return
  end

  if flags.profile == true then
    _CSB_ClassColorR, _CSB_ClassColorG, _CSB_ClassColorB = nil, nil, nil
    _CSB_ClearKnownSpellCache()
  end
end

function Cooldowns:_CooldownStackBars_SoftRebuild(flags)
  if not flags then
    return
  end

  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    self:CooldownStackBars_Rebuild()
  end
end


  _CSB_Snap = P:Def('_CSB_Snap', _CSB_Snap)
  _CSB_GetClassColor = P:Def('_CSB_GetClassColor', _CSB_GetClassColor)
  _CSB_IsTrackedSpellKnown = P:Def('_CSB_IsTrackedSpellKnown', _CSB_IsTrackedSpellKnown)
  _CSB_SetFontStringShown = P:Def('_CSB_SetFontStringShown', _CSB_SetFontStringShown)
  _CSB_DisableDurationBinding = P:Def('_CSB_DisableDurationBinding', _CSB_DisableDurationBinding)
  _CSB_ForEachChargeSlot = P:Def('_CSB_ForEachChargeSlot', _CSB_ForEachChargeSlot)
  _CSB_EnsureBarFrame = P:Def('_CSB_EnsureBarFrame', _CSB_EnsureBarFrame)
  _CSB_RegisterMover = P:Def('_CSB_RegisterMover', _CSB_RegisterMover)
  _CSB_ApplyPresentation = P:Def('_CSB_ApplyPresentation', _CSB_ApplyPresentation)
  _CSB_ApplyLayout = P:Def('_CSB_ApplyLayout', _CSB_ApplyLayout)
  _CSB_ResolveMaxCharges = P:Def('_CSB_ResolveMaxCharges', _CSB_ResolveMaxCharges)
  _CSB_ApplyResolvedMaxCharges = P:Def('_CSB_ApplyResolvedMaxCharges', _CSB_ApplyResolvedMaxCharges)
  _CSB_RemoveKeyFromList = P:Def('_CSB_RemoveKeyFromList', _CSB_RemoveKeyFromList)
  _CSB_DeleteRuntimeBar = P:Def('_CSB_DeleteRuntimeBar', _CSB_DeleteRuntimeBar)
  Cooldowns.CooldownStackBars_Rebuild = P:Def('Cooldowns:CooldownStackBars_Rebuild', Cooldowns.CooldownStackBars_Rebuild)
  Cooldowns.CooldownStackBars_RefreshBar = P:Def('Cooldowns:CooldownStackBars_RefreshBar', Cooldowns.CooldownStackBars_RefreshBar)
  Cooldowns.CooldownStackBars_DeleteBar = P:Def('Cooldowns:CooldownStackBars_DeleteBar', Cooldowns.CooldownStackBars_DeleteBar)
  Cooldowns.CooldownStackBars_Enable = P:Def('Cooldowns:CooldownStackBars_Enable', Cooldowns.CooldownStackBars_Enable)
  Cooldowns.CooldownStackBars_Disable = P:Def('Cooldowns:CooldownStackBars_Disable', Cooldowns.CooldownStackBars_Disable)
  Cooldowns._CooldownStackBars_OnCombatEvent = P:Def('Cooldowns:_CooldownStackBars_OnCombatEvent', Cooldowns._CooldownStackBars_OnCombatEvent)
  Cooldowns._CooldownStackBars_OnSpecTalentEvent = P:Def('Cooldowns:_CooldownStackBars_OnSpecTalentEvent', Cooldowns._CooldownStackBars_OnSpecTalentEvent)
  Cooldowns.CooldownStackBars_RefreshAfterTalentSwap = P:Def('Cooldowns:CooldownStackBars_RefreshAfterTalentSwap', Cooldowns.CooldownStackBars_RefreshAfterTalentSwap)
  Cooldowns._CooldownStackBars_ApplySettings = P:Def('Cooldowns:_CooldownStackBars_ApplySettings', Cooldowns._CooldownStackBars_ApplySettings)
  Cooldowns._CooldownStackBars_SoftRebuild = P:Def('Cooldowns:_CooldownStackBars_SoftRebuild', Cooldowns._CooldownStackBars_SoftRebuild)
  _CSB_ClearKnownSpellCache = P:Def('_CSB_ClearKnownSpellCache', _CSB_ClearKnownSpellCache)
  _CSB_ClearDurationState = P:Def('_CSB_ClearDurationState', _CSB_ClearDurationState)
  _CSB_ApplyDurationState = P:Def('_CSB_ApplyDurationState', _CSB_ApplyDurationState)
  _CSB_UpdateOneBar = P:Def('_CSB_UpdateOneBar', _CSB_UpdateOneBar)
  _CSB_ApplyStateAppearance = P:Def('_CSB_ApplyStateAppearance', _CSB_ApplyStateAppearance)
  _CSB_ApplyVisibility = P:Def('_CSB_ApplyVisibility', _CSB_ApplyVisibility)
  _CSB_RebuildAll = P:Def('_CSB_RebuildAll', _CSB_RebuildAll)
  _CSB_UpdateAll = P:Def('_CSB_UpdateAll', _CSB_UpdateAll)
  _CSB_QueueUpdateAll = P:Def('_CSB_QueueUpdateAll', _CSB_QueueUpdateAll)
  _CSB_SetChargeEventRegistered = P:Def('_CSB_SetChargeEventRegistered', _CSB_SetChargeEventRegistered)
  _CSB_InstallOnce = P:Def('_CSB_InstallOnce', _CSB_InstallOnce)
