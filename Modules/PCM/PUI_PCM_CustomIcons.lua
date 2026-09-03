local _, ns = ...

local CustomIcons = {}
ns.PCMCustomIcons = CustomIcons

local UIParent = UIParent
local GameTooltip = GameTooltip
local C_Timer = C_Timer
local C_Secrets = C_Secrets
local Presentation = ns.Presentation
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget
local BarWidget = ns.BarWidget
local IconSkin = ns.IconSkin
local FrameUtil = ns.FrameUtil
local Theme = ns.Theme
local LSM = ns.LSM
local Round = ns.Pixel.Round
local LCG = LibStub("LibCustomGlow-1.0")

local records = {}
local retiredCandidates = { includeSpellIDs = { [0] = true } }
local STATE_GLOW_KEY = "PUI_CustomIconState"
local AURA_GLOW_KEY = "PUI_CustomIconAura"
local BLIZZARD_BORDER_TEXTURE = "Interface\\Buttons\\UI-Quickslot2"
local EDIT_MODE_PREVIEW_ALPHA = 0.5

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or fallback
  return {
    tonumber(color[1] or color.r) or 1,
    tonumber(color[2] or color.g) or 1,
    tonumber(color[3] or color.b) or 1,
    tonumber(color[4] or color.a) or 1,
  }
end

local function ResolveFont(fontKey)
  return fontKey and LSM:Fetch("font", fontKey, true)
    or LSM:Fetch("font", Theme.GetFont("cooldown"), true)
    or STANDARD_TEXT_FONT
end

local function ApplyTextAnchor(fontString, parent, point, x, y)
  fontString:ClearAllPoints()
  fontString:SetPoint(point, parent, point, x, y)
end

local function ApplyFont(fontString, parent, icon, count)
  if not fontString then
    return
  end

  local baseSize = count and icon.countFontSize or icon.fontSize
  local scale = count and icon.countTextScale or icon.durationTextScale
  local color = CopyColor(count and icon.countTextColor or icon.durationTextColor, { 1, 1, 1, 1 })
  local point = count and icon.countTextAnchor or icon.durationTextAnchor
  local x = count and icon.countTextX or icon.durationTextX
  local y = count and icon.countTextY or icon.durationTextY

  fontString:SetFont(ResolveFont(icon.font), baseSize * scale / 100, icon.outline)
  fontString:SetTextColor(color[1], color[2], color[3], color[4])
  fontString:SetShadowColor(0, 0, 0, 1)
  fontString:SetShadowOffset(1, -1)
  ApplyTextAnchor(fontString, parent, point, x, y)
end

local function ApplyAnchor(frame, icon, defaultY)
  local pos = icon.pos
  frame:ClearAllPoints()
  frame:SetPoint(
    pos.point or "CENTER",
    UIParent,
    pos.relPoint or "CENTER",
    Round(tonumber(pos.x) or 0),
    Round(tonumber(pos.y) or defaultY or 0)
  )
end

local function SaveAnchor(frame, icon)
  local x, y = FrameUtil._GetOffsetsForFrame(frame)
  icon.pos.point = "CENTER"
  icon.pos.rel = "UIParent"
  icon.pos.relPoint = "CENTER"
  icon.pos.x = Round(x or 0)
  icon.pos.y = Round(y or 0)
end

local function SetTooltip(frame, record)
  frame:EnableMouse(record.icon.showTooltip == true)
  frame:SetScript("OnEnter", record.icon.showTooltip == true and function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(record.spellID)
    GameTooltip:Show()
  end or nil)
  frame:SetScript("OnLeave", record.icon.showTooltip == true and function()
    GameTooltip:Hide()
  end or nil)
end

local function ApplyChrome(frame, icon)
  local background = frame.__puiCustomIconBackground
  if not background then
    background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    frame.__puiCustomIconBackground = background
  end

  local blizzardBorder = frame.__puiCustomIconBlizzardBorder
  if not blizzardBorder then
    blizzardBorder = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    blizzardBorder:SetTexture(BLIZZARD_BORDER_TEXTURE)
    blizzardBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 12)
    blizzardBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 12, -12)
    frame.__puiCustomIconBlizzardBorder = blizzardBorder
  end

  local color = CopyColor(icon.backgroundColor, { 0.03, 0.03, 0.04, 1 })
  background:SetColorTexture(color[1], color[2], color[3], color[4])
  if icon.chromeStyle == "BLIZZARD" then
    BarWidget.ApplyBorder(frame, 0, { 0, 0, 0, 0 })
    blizzardBorder:Show()
  elseif icon.chromeStyle == "SQUARE" then
    BarWidget.ApplyBorder(frame, 1, CopyColor(icon.borderColor, { 0.1, 0.1, 0.12, 1 }))
    blizzardBorder:Hide()
  else
    BarWidget.ApplyBorder(frame, icon.borderSize, CopyColor(icon.borderColor, { 0.1, 0.1, 0.12, 1 }))
    blizzardBorder:Hide()
  end
end

local function ApplyIconCrop(texture, icon)
  if icon.chromeStyle == "SQUARE" then
    texture:SetTexCoord(0, 1, 0, 1)
  else
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local function StopStateGlow(record)
  local frame = record.parts.frame
  if record.stateGlowStyle == "PIXEL" then
    LCG.PixelGlow_Stop(frame, STATE_GLOW_KEY)
  elseif record.stateGlowStyle == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(frame, STATE_GLOW_KEY)
  elseif record.stateGlowStyle == "PROC" then
    LCG.ProcGlow_Stop(frame, STATE_GLOW_KEY)
  end
  record.stateGlowStyle = nil
  record.stateGlowActive = nil
end

local function StopAuraGlow(record)
  local target = record.auraGlowTarget
  if not target then
    record.auraGlowStyle = nil
    return
  end
  if record.auraGlowStyle == "PIXEL" then
    LCG.PixelGlow_Stop(target, AURA_GLOW_KEY)
  elseif record.auraGlowStyle == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(target, AURA_GLOW_KEY)
  elseif record.auraGlowStyle == "PROC" then
    LCG.ProcGlow_Stop(target, AURA_GLOW_KEY)
  end
  record.auraGlowStyle = nil
end

local function ApplyAuraGlow(record)
  local style = record.icon.activeAuraGlowStyle
  StopAuraGlow(record)
  if style == "NONE" then
    return
  end

  local color = CopyColor(record.icon.activeAuraGlowColor, { 1, 0.55, 0.1, 1 })
  local target = record.auraGlowTarget
  if style == "PIXEL" then
    LCG.PixelGlow_Start(target, color, 8, 0.25, nil, 2, 0, 0, true, AURA_GLOW_KEY, 8)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(target, color, 8, 0.25, 1, 0, 0, AURA_GLOW_KEY, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(target, {
      key = AURA_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  end
  record.auraGlowStyle = style
end

local function ApplyStateGlow(record, active)
  if record.kind == "aura" or record.runtimeEnabled ~= true or not record.parts.frame:IsShown() then
    StopStateGlow(record)
    return
  end

  local style = active == true and record.icon.cooldownGlowStyle or record.icon.readyGlowStyle
  if style == "NONE" then
    StopStateGlow(record)
    return
  end
  if record.stateGlowStyle == style and record.stateGlowActive == (active == true) then
    return
  end

  StopStateGlow(record)
  local color = CopyColor(
    active == true and record.icon.cooldownGlowColor or record.icon.readyGlowColor,
    { 1, 1, 1, 1 }
  )
  local frame = record.parts.frame
  if style == "PIXEL" then
    LCG.PixelGlow_Start(frame, color, 8, 0.25, nil, 2, 0, 0, true, STATE_GLOW_KEY, 8)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(frame, color, 8, 0.25, 1, 0, 0, STATE_GLOW_KEY, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(frame, {
      key = STATE_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  end
  record.stateGlowStyle = style
  record.stateGlowActive = active == true
end

local function GetContextAlpha(record)
  local alpha = 1
  if record.icon.combatOnly == true and not record.inCombat then
    alpha = alpha * record.icon.outOfCombatAlpha / 100
  end
  return alpha
end

local BuildQuickSettings
BuildQuickSettings = function(record, moverFrame)
  if not record or record.kind == "aura" then
    return false
  end

  local icon = record.icon
  local chargeKind = record.kind == "charge"
  local controls = {}

  local function RefreshStyle()
    CustomIcons:RefreshStyle(record.key)
  end

  local function RefreshPanel()
    C_Timer.After(0, function()
      if ns.Flags.IsEditing == true then
        ns.EditModeQuickSettings:Refresh(
          record.moverKey,
          moverFrame,
          function(frame)
            return BuildQuickSettings(record, frame)
          end
        )
      end
    end)
  end

  controls[#controls + 1] = {
    type = "slider",
    label = "Button size",
    min = 20,
    max = 96,
    step = 1,
    commitOnRelease = true,
    get = function() return icon.size end,
    set = function(value)
      icon.size = value
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "select",
    label = "Show icon",
    values = chargeKind and {
      ALWAYS = "Always",
      ACTIVE = "While recharging",
      INACTIVE = "At full charges",
    } or {
      ALWAYS = "Always",
      ACTIVE = "While cooling down",
      INACTIVE = "While ready",
    },
    sorting = { "ALWAYS", "ACTIVE", "INACTIVE" },
    get = function() return icon.visibility end,
    set = function(value)
      icon.visibility = value
      RefreshStyle()
      RefreshPanel()
    end,
  }

  controls[#controls + 1] = {
    type = "toggle",
    label = "Only show in combat",
    get = function() return icon.combatOnly == true end,
    set = function(value)
      icon.combatOnly = value == true
      RefreshStyle()
      RefreshPanel()
    end,
  }

  if icon.combatOnly == true then
    controls[#controls + 1] = {
      type = "slider",
      label = "Out-of-combat opacity",
      min = 0,
      max = 100,
      step = 1,
      get = function() return icon.outOfCombatAlpha end,
      set = function(value)
        icon.outOfCombatAlpha = Round(value)
        RefreshStyle()
      end,
    }
  end

  if icon.visibility ~= "ACTIVE" then
    controls[#controls + 1] = {
      type = "slider",
      label = chargeKind and "Full-charge opacity" or "Ready opacity",
      min = 0,
      max = 100,
      step = 1,
      get = function() return icon.readyAlpha end,
      set = function(value)
        icon.readyAlpha = Round(value)
        RefreshStyle()
      end,
    }
    controls[#controls + 1] = {
      type = "toggle",
      label = chargeKind and "Desaturate at full charges" or "Desaturate while ready",
      get = function() return icon.desaturateReady == true end,
      set = function(value)
        icon.desaturateReady = value == true
        RefreshStyle()
      end,
    }
  end

  if icon.visibility ~= "INACTIVE" then
    controls[#controls + 1] = {
      type = "slider",
      label = chargeKind and "Recharging opacity" or "Cooldown opacity",
      min = 0,
      max = 100,
      step = 1,
      get = function() return icon.onCooldownAlpha end,
      set = function(value)
        icon.onCooldownAlpha = Round(value)
        RefreshStyle()
      end,
    }
    controls[#controls + 1] = {
      type = "toggle",
      label = chargeKind and "Desaturate while recharging" or "Desaturate while on cooldown",
      get = function() return icon.desaturateCooldown == true end,
      set = function(value)
        icon.desaturateCooldown = value == true
        RefreshStyle()
      end,
    }
  end

  controls[#controls + 1] = {
    type = "toggle",
    label = "Show cooldown swipe",
    get = function() return icon.showSwipe == true end,
    set = function(value)
      icon.showSwipe = value == true
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "toggle",
    label = "Show countdown",
    get = function() return icon.showDuration == true end,
    set = function(value)
      icon.showDuration = value == true
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "select",
    label = "Icon style",
    values = {
      PLEEBUI = "PleebUI",
      SQUARE = "Square",
      BLIZZARD = "Blizzard",
    },
    sorting = { "PLEEBUI", "SQUARE", "BLIZZARD" },
    get = function() return icon.chromeStyle end,
    set = function(value)
      icon.chromeStyle = value
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "slider",
    label = "Border size",
    min = 0,
    max = 8,
    step = 1,
    get = function() return icon.borderSize end,
    set = function(value)
      icon.borderSize = Round(value)
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "slider",
    label = "Countdown font size",
    min = 8,
    max = 28,
    step = 1,
    get = function() return icon.fontSize end,
    set = function(value)
      icon.fontSize = Round(value)
      RefreshStyle()
    end,
  }

  controls[#controls + 1] = {
    type = "toggle",
    label = "Show tooltip",
    get = function() return icon.showTooltip == true end,
    set = function(value)
      icon.showTooltip = value == true
      RefreshStyle()
    end,
  }

  return {
    ownerKey = record.moverKey,
    title = record.label,
    description = "Live custom icon settings.",
    controls = controls,
  }
end

local function RegisterMover(record)
  local key = record.moverKey
  local frame = record.parts.frame
  FrameUtil:EnsureGhostMover(key, {
    label = record.label,
    optionsString = record.optionsString,
    useOverlayDrag = true,
    liveFrame = function() return frame end,
    shouldShow = function()
      return record.cfg.enabled ~= false
        and record.cfg.presentation == "BUTTON"
        and record.runtimeEnabled == true
    end,
    onDragStop = function(movedFrame)
      SaveAnchor(movedFrame or frame, record.icon)
      ApplyAnchor(frame, record.icon, record.defaultY)
      FrameUtil:RefreshGhostMover(key)
    end,
    quickSettings = record.kind ~= "aura" and function(moverFrame)
      return BuildQuickSettings(record, moverFrame)
    end or nil,
    smartSnap = {
      family = "pcmCustomButtons",
      syncAxis = "BOTH",
      syncDesignLabel = "Sync visibility",
      getSizeState = function()
        return { size = record.icon.size }
      end,
      copySizeFrom = function(sourceEntry)
        local sourceSmartSnap = sourceEntry
          and sourceEntry.opts
          and sourceEntry.opts.smartSnap
        local sourceState = sourceSmartSnap
          and sourceSmartSnap.getSizeState
          and sourceSmartSnap.getSizeState()
        if not sourceState then
          return
        end

        local size = math.max(20, math.min(96, Round(tonumber(sourceState.size) or 40)))
        if record.icon.size == size then
          return
        end

        record.icon.size = size
        frame:SetSize(size, size)

        local pipCount = record.pipCount or 0
        local pips = record.parts.pips
        if pips and pipCount > 0 then
          local gap = 1
          local width = (size - ((pipCount - 1) * gap)) / pipCount
          for index = 1, pipCount do
            local pip = pips[index]
            if pip then
              pip:ClearAllPoints()
              pip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * (width + gap), 0)
              pip:SetSize(width, 3)
            end
          end
        end

        FrameUtil:RefreshGhostMover(key)
      end,
      getDesign = function()
        return {
          visibility = record.icon.visibility,
          combatOnly = record.icon.combatOnly == true,
          outOfCombatAlpha = record.icon.outOfCombatAlpha,
        }
      end,
      applyDesign = function(design)
        if type(design) ~= "table" then
          return
        end

        if design.visibility ~= nil then
          record.icon.visibility = design.visibility
        end
        if design.combatOnly ~= nil then
          record.icon.combatOnly = design.combatOnly == true
        end
        if design.outOfCombatAlpha ~= nil then
          record.icon.outOfCombatAlpha = math.max(
            0,
            math.min(100, tonumber(design.outOfCombatAlpha) or 0)
          )
        end

        CustomIcons:RefreshVisibility(record.key, record.inCombat)
        FrameUtil:RefreshGhostMover(key)
      end,
    },
  })
  FrameUtil:RefreshGhostMover(key)
end

local function EnsureRecord(key)
  local record = records[key]
  if record then return record end
  local parts = Presentation.Create("PCMIcon", UIParent, {
    name = "PleebUI_PCM_CustomIcon_" .. tostring(key):gsub("[^%w]", "_"),
  })
  parts.frame.__puiCustomIconBackground = parts.background
  record = { key = key, parts = parts, runtimeEnabled = false }
  records[key] = record
  parts.frame.__puiCustomIconRecord = record
  return record
end

local function ApplyPlacement(record)
  record.parts.frame:SetParent(UIParent)
  ApplyAnchor(record.parts.frame, record.icon, record.defaultY)
  RegisterMover(record)
end

local function ApplyBaseStyle(record)
  local icon = record.icon
  local parts = record.parts
  local frame = parts.frame
  StopStateGlow(record)
  Presentation.Apply("PCMIcon", parts, {
    size = icon.size,
    borderSize = icon.borderSize,
    borderColor = icon.borderColor,
    backgroundColor = icon.backgroundColor,
    cooldownFont = {
      font = icon.font,
      size = icon.fontSize * icon.durationTextScale / 100,
      flags = icon.outline,
      color = icon.durationTextColor,
    },
    chargeFont = {
      font = icon.font,
      size = icon.countFontSize * icon.countTextScale / 100,
      flags = icon.outline,
      color = icon.countTextColor,
    },
    skipVisibility = true,
  })
  ApplyChrome(frame, icon)
  ApplyIconCrop(parts.icon, icon)
  parts.icon:SetShown(record.kind ~= "aura" or icon.visibility == "ALWAYS")
  if record.kind == "aura" then
    parts.icon:SetDesaturated(icon.desaturateReady == true)
  end
  parts.cooldown:SetDrawSwipe(icon.showSwipe == true)
  parts.cooldown:SetDrawEdge(icon.showSwipe == true)
  parts.cooldown:SetHideCountdownNumbers(icon.showDuration ~= true)
  IconSkin.StyleCooldownText(parts.cooldown, {
    font = icon.font,
    size = icon.fontSize * icon.durationTextScale / 100,
    flags = icon.outline,
    color = icon.durationTextColor,
    point = icon.durationTextAnchor,
    relativePoint = icon.durationTextAnchor,
    offsetX = icon.durationTextX,
    offsetY = icon.durationTextY,
  })
  ApplyFont(parts.chargeText, frame, icon, true)
  parts.chargeText:SetShown(icon.showCount == true and record.kind == "charge")
  parts.cooldownText:Hide()
  parts.keybindText:Hide()
  SetTooltip(frame, record)
  ApplyPlacement(record)
end

local function EnsurePips(record, maximum)
  local parts = record.parts
  parts.pips = parts.pips or {}
  local count = record.icon.showPips == true and math.max(0, math.floor(tonumber(maximum) or 0)) or 0
  local iconSize = tonumber(record.icon.size) or 0

  if record.pipGeometryCount == count and record.pipGeometryIconSize == iconSize then
    record.pipCount = count
    return
  end

  local gap = 1
  local width = count > 0 and ((iconSize - ((count - 1) * gap)) / count) or 0
  for index = 1, count do
    local pip = parts.pips[index]
    if not pip then
      pip = CreateFrame("StatusBar", nil, parts.frame)
      pip:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
      parts.pips[index] = pip
    end
    pip:ClearAllPoints()
    pip:SetPoint("BOTTOMLEFT", parts.frame, "BOTTOMLEFT", (index - 1) * (width + gap), 0)
    pip:SetSize(width, 3)
    pip:SetMinMaxValues(index - 1, index)
    pip:SetStatusBarColor(0.25, 0.75, 1, 1)
    pip:Show()
  end
  for index = count + 1, #parts.pips do parts.pips[index]:Hide() end

  record.pipGeometryCount = count
  record.pipGeometryIconSize = iconSize
  record.pipCount = count
end

local function FeedPips(record, value)
  for index = 1, record.pipCount or 0 do record.parts.pips[index]:SetValue(value) end
end

local function SpellSetsMatch(left, right)
  if left == right then
    return true
  end
  if type(left) ~= "table" or type(right) ~= "table" then
    return false
  end
  for spellID in pairs(left) do
    if right[spellID] ~= true then return false end
  end
  for spellID in pairs(right) do
    if left[spellID] ~= true then return false end
  end
  return true
end

local function EnsureAuraCueBorder(parts, button)
  local border = parts.cueBorder
  if border then
    return border
  end

  local function CreateEdge()
    local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetBlendMode("ADD")
    return edge
  end

  border = {
    top = CreateEdge(),
    bottom = CreateEdge(),
    left = CreateEdge(),
    right = CreateEdge(),
  }
  parts.cueBorder = border
  return border
end

local function ConfigureAuraCueBorder(record, parts, button, shown)
  local border = EnsureAuraCueBorder(parts, button)
  local cfg = record.cfg
  local thickness = math.max(1, math.min(8, math.floor((tonumber(cfg.buffGlowThickness) or 2) + 0.5)))
  local color = CopyColor(cfg.buffGlowColor, { 0.25, 0.75, 1, 1 })

  border.top:ClearAllPoints()
  border.top:SetHeight(thickness)
  border.top:SetPoint("TOPLEFT", button, "TOPLEFT", -thickness, thickness)
  border.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", thickness, thickness)
  border.bottom:ClearAllPoints()
  border.bottom:SetHeight(thickness)
  border.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -thickness, -thickness)
  border.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", thickness, -thickness)
  border.left:ClearAllPoints()
  border.left:SetWidth(thickness)
  border.left:SetPoint("TOPLEFT", border.top, "BOTTOMLEFT", 0, 0)
  border.left:SetPoint("BOTTOMLEFT", border.bottom, "TOPLEFT", 0, 0)
  border.right:ClearAllPoints()
  border.right:SetWidth(thickness)
  border.right:SetPoint("TOPRIGHT", border.top, "BOTTOMRIGHT", 0, 0)
  border.right:SetPoint("BOTTOMRIGHT", border.bottom, "TOPRIGHT", 0, 0)

  for _, edge in pairs(border) do
    edge:SetColorTexture(color[1], color[2], color[3], color[4])
    edge:SetShown(shown == true)
  end
end

local function ResolveButtonAuraSpellIDs(record, cueOnly)
  local cfg = record.cfg
  local icon = record.icon
  if not cfg or not icon then return nil end

  local enabled = cueOnly and cfg.buffGlowEnabled == true
    or not cueOnly and (icon.activeAuraEnabled == true or cfg.buffGlowEnabled == true)
  if not enabled then return nil end

  local spellID = tonumber(cfg.buffGlowSpellID or cfg.trackedSpellID)
  if not spellID or spellID <= 0 then return nil end

  if cfg.buffGlowSource == "CUSTOM" and cfg.buffGlowSpellID then
    return { [spellID] = true }
  end

  local _, spellIDs = ns.Modules.CooldownManager:ResolveCustomBarAuraEntry(spellID)
  return spellIDs
end

local function ConfigureActiveAuraParts(record, button, parts)
  local icon = record.icon
  AuraWidget.BindApplicationDurationButton(button, parts)
  button:ClearAllPoints()
  button:SetAllPoints(record.parts.frame)
  button:SetFrameStrata(record.parts.frame:GetFrameStrata())
  button:SetFrameLevel(record.parts.frame:GetFrameLevel() + 6)
  button:EnableMouse(false)

  if not record.auraGlowTarget or record.auraGlowTarget:GetParent() ~= button then
    StopAuraGlow(record)
    record.auraGlowTarget = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    record.auraGlowTarget:SetAllPoints(button)
    record.auraGlowTarget:EnableMouse(false)
  end
  record.auraGlowTarget:SetFrameLevel(button:GetFrameLevel() + 8)

  if icon.activeAuraEnabled == true then
    AuraWidget.ConfigureIcon(parts)
    ApplyIconCrop(parts.icon, icon)
    parts.icon:SetAllPoints(button)
    parts.icon:SetDesaturated(icon.activeAuraDesaturate == true)
    if icon.showSwipe == true or icon.showDuration == true then
      AuraWidget.ConfigureDurationCooldown(parts)
      parts.durationCooldown:SetAllPoints(button)
      parts.durationCooldown:SetReverse(true)
      parts.durationCooldown:SetSwipeColor(0, 0, 0, 0.72)
      parts.durationCooldown:SetDrawSwipe(icon.showSwipe == true)
      parts.durationCooldown:SetDrawEdge(icon.showSwipe == true)
      parts.durationCooldown:SetHideCountdownNumbers(icon.showDuration ~= true)
      IconSkin.StyleCooldownText(parts.durationCooldown, {
        font = icon.font,
        size = icon.fontSize * icon.durationTextScale / 100,
        flags = icon.outline,
        color = icon.durationTextColor,
        point = icon.durationTextAnchor,
        relativePoint = icon.durationTextAnchor,
        offsetX = icon.durationTextX,
        offsetY = icon.durationTextY,
      })
    else
      AuraWidget.DisableDurationCooldown(parts)
    end
    ApplyAuraGlow(record)
  else
    AuraWidget.DisableIcon(parts)
    AuraWidget.DisableDurationCooldown(parts)
    StopAuraGlow(record)
  end

  local showCueBorder = record.cfg.buffGlowEnabled == true
    and (icon.activeAuraEnabled ~= true or icon.activeAuraGlowStyle == "NONE")
  ConfigureAuraCueBorder(record, parts, button, showCueBorder)
  button:SetAlpha(icon.activeAuraEnabled == true and icon.activeAuraAlpha / 100 or 1)
end

local function ConfigureActiveAuraTrack(record)
  if record.kind == "aura" then
    return
  end
  if record.runtimeEnabled ~= true then
    if record.activeAuraSlot then
      AuraSlotDriver:SetSlotActive(record.activeAuraSlot, false)
    end
    return
  end

  local spellIDs = ResolveButtonAuraSpellIDs(record, false)
  if type(spellIDs) ~= "table" or next(spellIDs) == nil then
    if record.activeAuraSlot then
      AuraSlotDriver:SetSlotActive(record.activeAuraSlot, false)
    end
    return
  end

  if not record.activeAuraSlot then
    record.activeAuraSlot = AuraSlotDriver:CreateSlot("player", "HELPFUL|PLAYER", {
      candidateFilters = { includeSpellIDs = spellIDs },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        record.activeAuraParts = {}
        ConfigureActiveAuraParts(record, button, record.activeAuraParts)
      end,
    })
    record.activeAuraSpellIDs = spellIDs
  else
    if not SpellSetsMatch(record.activeAuraSpellIDs, spellIDs) then
      AuraSlotDriver:SetSlotCandidates(record.activeAuraSlot, { includeSpellIDs = spellIDs })
      record.activeAuraSpellIDs = spellIDs
    end
    if record.activeAuraParts and C_Secrets.ShouldAurasBeSecret() ~= true then
      ConfigureActiveAuraParts(record, record.activeAuraParts.button, record.activeAuraParts)
    end
  end
  AuraSlotDriver:SetSlotActive(record.activeAuraSlot, true)
end

local function ConfigureCueAuraParts(record, button, parts)
  AuraWidget.BindApplicationDurationButton(button, parts)
  button:ClearAllPoints()
  button:SetAllPoints(record.parts.frame)
  button:SetFrameStrata(record.parts.frame:GetFrameStrata())
  button:SetFrameLevel(record.parts.frame:GetFrameLevel() + 7)
  button:EnableMouse(false)
  AuraWidget.DisableIcon(parts)
  AuraWidget.DisableDurationCooldown(parts)
  AuraWidget.DisableDurationText(parts)
  AuraWidget.DisableDurationBar(parts)
  AuraWidget.DisableApplicationCount(parts)
  AuraWidget.DisableApplicationBar(parts)
  ConfigureAuraCueBorder(record, parts, button, true)
  button:SetAlpha(1)
end

local function ConfigureCueAuraTrack(record)
  if record.runtimeEnabled ~= true then
    if record.cueAuraSlot then AuraSlotDriver:SetSlotActive(record.cueAuraSlot, false) end
    return
  end

  local useSeparateCue = record.kind == "aura"
    and record.cfg.buffGlowEnabled == true
    and tonumber(record.cfg.buffGlowSpellID) ~= nil
  if not useSeparateCue then
    if record.cueAuraSlot then AuraSlotDriver:SetSlotActive(record.cueAuraSlot, false) end
    return
  end

  local spellIDs = ResolveButtonAuraSpellIDs(record, true)
  if type(spellIDs) ~= "table" or next(spellIDs) == nil then
    if record.cueAuraSlot then AuraSlotDriver:SetSlotActive(record.cueAuraSlot, false) end
    return
  end
  if SpellSetsMatch(record.auraCandidateSpellIDs, spellIDs) then
    if record.cueAuraSlot then AuraSlotDriver:SetSlotActive(record.cueAuraSlot, false) end
    return
  end

  if not record.cueAuraSlot then
    record.cueAuraSlot = AuraSlotDriver:CreateSlot("player", "HELPFUL|PLAYER", {
      candidateFilters = { includeSpellIDs = spellIDs },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        record.cueAuraParts = {}
        ConfigureCueAuraParts(record, button, record.cueAuraParts)
      end,
    })
    record.cueAuraSpellIDs = spellIDs
  else
    if not SpellSetsMatch(record.cueAuraSpellIDs, spellIDs) then
      AuraSlotDriver:SetSlotCandidates(record.cueAuraSlot, { includeSpellIDs = spellIDs })
      record.cueAuraSpellIDs = spellIDs
    end
    if record.cueAuraParts and C_Secrets.ShouldAurasBeSecret() ~= true then
      ConfigureCueAuraParts(record, record.cueAuraParts.button, record.cueAuraParts)
    end
  end
  AuraSlotDriver:SetSlotActive(record.cueAuraSlot, true)
end

local function ApplyStateVisibility(record, active)
  local icon = record.icon
  local visible = record.runtimeEnabled == true
  if visible and icon.combatOnly == true and not record.inCombat then
    visible = icon.outOfCombatAlpha > 0
  end
  if visible and icon.visibility == "ACTIVE" then
    visible = active == true
  elseif visible and icon.visibility == "INACTIVE" then
    visible = active ~= true
  end

  local alpha = active == true and icon.onCooldownAlpha / 100 or icon.readyAlpha / 100
  if icon.combatOnly == true and not record.inCombat then
    alpha = icon.outOfCombatAlpha / 100
  end

  if ns.Flags.IsEditing == true and record.runtimeEnabled == true then
    visible = true
    alpha = math.max(alpha, EDIT_MODE_PREVIEW_ALPHA)
  elseif alpha <= 0 then
    visible = false
  end

  if record.stateVisible ~= visible then
    record.stateVisible = visible
    record.parts.frame:SetShown(visible)
  end
  if record.stateAlpha ~= alpha then
    record.stateAlpha = alpha
    record.parts.frame:SetAlpha(alpha)
  end

  local mouseEnabled = ns.Flags.IsEditing ~= true
    and visible
    and alpha > 0
    and icon.showTooltip == true
  if record.stateMouseEnabled ~= mouseEnabled then
    record.stateMouseEnabled = mouseEnabled
    record.parts.frame:EnableMouse(mouseEnabled)
  end

  local desaturated = active == true and icon.desaturateCooldown == true
    or active ~= true and icon.desaturateReady == true
  if record.stateDesaturated ~= desaturated then
    record.stateDesaturated = desaturated
    record.parts.icon:SetDesaturated(desaturated)
  end

  record.active = active == true
  ApplyStateGlow(record, active)
end

function CustomIcons:Configure(key, cfg, options)
  local record = EnsureRecord(key)
  record.cfg = cfg
  record.icon = cfg.icon
  record.kind = options.kind
  record.label = options.label
  record.optionsString = options.optionsString
  record.moverKey = options.moverKey
  record.defaultY = options.defaultY
  record.spellID = options.spellID
  record.inCombat = options.inCombat == true
  record.runtimeEnabled = cfg.enabled ~= false and cfg.presentation == "BUTTON"
  record.stateVisible = nil
  record.stateAlpha = nil
  record.stateMouseEnabled = nil
  record.stateDesaturated = nil
  record.cooldownShown = nil
  record.chargeTextShown = nil
  record.parts.icon:SetTexture(options.texture)
  ApplyBaseStyle(record)
  ConfigureActiveAuraTrack(record)
  if record.kind ~= "aura" then
    ConfigureCueAuraTrack(record)
  end
  if not record.runtimeEnabled then
    record.parts.frame:Hide()
  end
  return record
end

function CustomIcons:UpdateCooldown(key, duration, active)
  local record = records[key]
  if not record or not record.runtimeEnabled then return end
  local cooldown = record.parts.cooldown
  local cooldownShown = record.icon.showSwipe == true or record.icon.showDuration == true
  if record.cooldownShown ~= cooldownShown then
    record.cooldownShown = cooldownShown
    cooldown:SetShown(cooldownShown)
    if not cooldownShown then
      cooldown:Clear()
    end
  end
  if cooldownShown then
    cooldown:SetCooldownFromDurationObject(duration, true)
  end
  if active ~= nil then
    ApplyStateVisibility(record, active)
  end
end

function CustomIcons:UpdateCharge(key, duration, currentCharges, maximum, active)
  local record = records[key]
  if not record or not record.runtimeEnabled then return end
  local cooldown = record.parts.cooldown
  local cooldownShown = record.icon.showSwipe == true or record.icon.showDuration == true
  if record.cooldownShown ~= cooldownShown then
    record.cooldownShown = cooldownShown
    cooldown:SetShown(cooldownShown)
    if not cooldownShown then
      cooldown:Clear()
    end
  end
  if cooldownShown then
    cooldown:SetCooldownFromDurationObject(duration, true)
  end

  local chargeTextShown = record.icon.showCount == true
  if record.chargeTextShown ~= chargeTextShown then
    record.chargeTextShown = chargeTextShown
    record.parts.chargeText:SetShown(chargeTextShown)
  end
  if chargeTextShown then record.parts.chargeText:SetText(currentCharges) end
  EnsurePips(record, maximum)
  FeedPips(record, currentCharges)
  ApplyStateVisibility(record, active)
end

local function ConfigureAuraParts(record, button, parts)
  local icon = record.icon
  AuraWidget.BindApplicationDurationButton(button, parts)
  AuraWidget.ConfigureApplicationThresholdSource(
    parts,
    record.auraCandidateSpellIDs,
    record.cfg.__puiCooldownID,
    "BuffIconCooldownViewer",
    record.auraUnit
  )
  parts.durationCooldown:SetHideCountdownNumbers(true)
  parts.durationCooldown:SetReverse(true)
  parts.durationCooldown:SetSwipeColor(0, 0, 0, 0.72)
  button:ClearAllPoints()
  button:SetAllPoints(record.parts.frame)
  button:SetFrameStrata(record.parts.frame:GetFrameStrata())
  button:SetFrameLevel(record.parts.frame:GetFrameLevel() + 2)
  if not record.auraGlowTarget or record.auraGlowTarget:GetParent() ~= button then
    StopAuraGlow(record)
    record.auraGlowTarget = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    record.auraGlowTarget:SetAllPoints(button)
    record.auraGlowTarget:EnableMouse(false)
  end
  record.auraGlowTarget:SetFrameLevel(button:GetFrameLevel() + 8)
  ApplyChrome(button, icon)

  AuraWidget.ConfigureIcon(parts)
  ApplyIconCrop(parts.icon, icon)
  if icon.showSwipe == true then
    AuraWidget.ConfigureDurationCooldown(parts)
    parts.durationCooldown:SetDrawEdge(true)
  else
    AuraWidget.DisableDurationCooldown(parts)
  end
  if icon.showDuration == true then
    AuraWidget.ConfigureDurationText(parts, BarWidget.GetDurationFormatter())
    ApplyFont(parts.durationText, button, icon, false)
  else
    AuraWidget.DisableDurationText(parts)
  end

  if record.auraKind == "stack" and icon.showCount == true then
    parts.applicationFormatter = parts.applicationFormatter or C_StringUtil.CreateNumericRuleFormatter()
    if not parts.applicationFormatterReady then
      parts.applicationFormatter:AddBreakpoint({ threshold = 0, format = "%.0f" })
      parts.applicationFormatterReady = true
    end
    AuraWidget.ConfigureApplicationCount(parts, parts.applicationFormatter)
    ApplyFont(parts.applicationText, button, icon, true)
  else
    AuraWidget.DisableApplicationCount(parts)
  end

  if record.auraKind == "stack" and icon.showStackStrip == true then
    parts.applicationBar:ClearAllPoints()
    parts.applicationBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    parts.applicationBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    parts.applicationBar:SetHeight(3)
    parts.applicationBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local thresholdMirror = AuraWidget.SetApplicationThresholdHost(parts, record.parts.frame)
    thresholdMirror:ClearAllPoints()
    thresholdMirror:SetPoint("BOTTOMLEFT", record.parts.frame, "BOTTOMLEFT", 1, 1)
    thresholdMirror:SetPoint("BOTTOMRIGHT", record.parts.frame, "BOTTOMRIGHT", -1, 1)
    thresholdMirror:SetHeight(3)
    local class = select(2, UnitClass("player"))
    local classColor = class and RAID_CLASS_COLORS[class]
    local color = record.cfg.useClassColor ~= false and classColor or record.cfg.barColor
    color = color or { 0.25, 0.75, 1, 1 }
    parts.applicationBar:SetStatusBarColor(
      color.r or color[1] or 0.25,
      color.g or color[2] or 0.75,
      color.b or color[3] or 1,
      color.a or color[4] or 1
    )
    AuraWidget.ConfigureApplicationThresholds(
      parts,
      record.cfg.stackColorThresholds,
      "Interface\\Buttons\\WHITE8x8",
      "HORIZONTAL",
      false,
      classColor,
      record.maximum
    )
    AuraWidget.ConfigureApplicationBar(
      parts,
      record.maximum,
      Enum.StatusBarInterpolation.Immediate
    )
  else
    AuraWidget.DisableApplicationBar(parts)
  end

  parts.icon:SetAllPoints(button)
  parts.icon:SetDesaturated(icon.activeAuraDesaturate == true)
  parts.durationCooldown:SetAllPoints(button)
  parts.durationTextHolder:SetAllPoints(button)
  parts.applicationHolder:SetAllPoints(button)
  SetTooltip(button, record)
  button:SetAlpha(icon.activeAuraAlpha / 100)
  ApplyAuraGlow(record)
  ConfigureAuraCueBorder(
    record,
    parts,
    button,
    record.cfg.buffGlowEnabled == true and tonumber(record.cfg.buffGlowSpellID) == nil
      and icon.activeAuraGlowStyle == "NONE"
  )
end

function CustomIcons:ConfigureAura(key, cfg, options)
  local record = self:Configure(key, cfg, {
    kind = "aura",
    label = options.label,
    optionsString = options.optionsString,
    moverKey = options.moverKey,
    defaultY = options.defaultY,
    spellID = options.spellID,
    texture = options.texture,
    inCombat = options.inCombat,
  })
  record.auraKind = options.auraKind
  record.maximum = math.max(1, math.floor(tonumber(options.maximum) or 1))
  record.auraCandidateSpellIDs = options.candidateSpellIDs
  StopStateGlow(record)
  if not record.runtimeEnabled then
    if record.auraSlot then AuraSlotDriver:SetSlotActive(record.auraSlot, false) end
    if record.auraParts then
      AuraWidget.DisableApplicationThresholdSource(record.auraParts)
    end
    return
  end

  record.parts.cooldown:Hide()
  record.parts.chargeText:Hide()
  if cfg.icon.visibility == "ACTIVE" then
    record.parts.icon:Hide()
    record.parts.background:SetColorTexture(0, 0, 0, 0)
    BarWidget.ApplyBorder(record.parts.frame, 0, { 0, 0, 0, 0 })
    if record.parts.frame.__puiCustomIconBlizzardBorder then
      record.parts.frame.__puiCustomIconBlizzardBorder:Hide()
    end
    record.parts.frame:EnableMouse(false)
  end

  if not record.auraSlot or record.auraUnit ~= options.unit then
    if record.auraSlot then AuraSlotDriver:SetSlotActive(record.auraSlot, false) end
    if record.auraParts then
      AuraWidget.DisableApplicationThresholdSource(record.auraParts)
    end
    record.auraUnit = options.unit
    record.auraParts = nil
    record.auraSlot = AuraSlotDriver:CreateSlot(options.unit, options.filter, {
      candidateFilters = { includeSpellIDs = options.candidateSpellIDs },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        record.auraParts = {}
        ConfigureAuraParts(record, button, record.auraParts)
      end,
    })
  else
    AuraSlotDriver:SetSlotFilter(record.auraSlot, options.filter)
    AuraSlotDriver:SetSlotCandidates(record.auraSlot, { includeSpellIDs = options.candidateSpellIDs })
    if record.auraParts and C_Secrets.ShouldAurasBeSecret() ~= true then
      ConfigureAuraParts(record, record.auraParts.button, record.auraParts)
    end
  end
  AuraSlotDriver:SetSlotActive(record.auraSlot, true)
  ConfigureCueAuraTrack(record)
  self:RefreshVisibility(key, record.inCombat)
  return record
end

function CustomIcons:RefreshStyle(key)
  local record = records[key]
  if not record or record.runtimeEnabled ~= true then
    return
  end

  ApplyBaseStyle(record)
  if record.kind == "charge" and (record.pipCount or 0) > 0 then
    EnsurePips(record, record.pipCount)
  end
  ConfigureActiveAuraTrack(record)
  if record.kind ~= "aura" then
    ConfigureCueAuraTrack(record)
  end
  self:RefreshVisibility(key, record.inCombat)
end

function CustomIcons:RefreshVisibility(key, inCombat)
  local record = records[key]
  if not record then return end
  record.inCombat = inCombat == true
  if record.kind == "aura" then
    local contextAlpha = GetContextAlpha(record)
    local visible = record.runtimeEnabled and contextAlpha > 0
    local baseAlpha = record.icon.visibility == "ALWAYS"
      and contextAlpha * record.icon.readyAlpha / 100 or contextAlpha
    record.parts.frame:SetShown(visible)
    record.parts.frame:SetAlpha(baseAlpha)
    record.parts.frame:EnableMouse(
      visible and baseAlpha > 0 and record.icon.visibility == "ALWAYS" and record.icon.showTooltip == true
    )
  else
    ApplyStateVisibility(record, record.active)
  end
end

function CustomIcons:RefreshAllVisibility()
  for key, record in pairs(records) do
    if record.runtimeEnabled == true then
      self:RefreshVisibility(key, record.inCombat)
    end
  end
end

function CustomIcons:FlushAuraStyles()
  if C_Secrets.ShouldAurasBeSecret() == true then return end
  for _, record in pairs(records) do
    if record.runtimeEnabled then
      if record.auraParts then
        ConfigureAuraParts(record, record.auraParts.button, record.auraParts)
      end
      if record.activeAuraParts then
        ConfigureActiveAuraParts(record, record.activeAuraParts.button, record.activeAuraParts)
      end
      if record.cueAuraParts then
        ConfigureCueAuraParts(record, record.cueAuraParts.button, record.cueAuraParts)
      end
    end
  end
end

function CustomIcons:Release(key)
  local record = records[key]
  if not record then return end
  record.runtimeEnabled = false
  StopStateGlow(record)
  StopAuraGlow(record)
  if record.auraSlot then
    AuraSlotDriver:SetSlotCandidates(record.auraSlot, retiredCandidates)
    AuraSlotDriver:SetSlotActive(record.auraSlot, false)
  end
  if record.auraParts then
    AuraWidget.DisableApplicationThresholdSource(record.auraParts)
  end
  if record.activeAuraSlot then
    AuraSlotDriver:SetSlotCandidates(record.activeAuraSlot, retiredCandidates)
    AuraSlotDriver:SetSlotActive(record.activeAuraSlot, false)
  end
  if record.cueAuraSlot then
    AuraSlotDriver:SetSlotCandidates(record.cueAuraSlot, retiredCandidates)
    AuraSlotDriver:SetSlotActive(record.cueAuraSlot, false)
  end
  record.parts.cooldown:Clear()
  record.parts.frame:Hide()
  FrameUtil:RefreshGhostMover(record.moverKey)
end

function CustomIcons:Delete(key)
  local record = records[key]
  if not record then return end
  self:Release(key)
  FrameUtil.ClearSmartSnapForKey(record.moverKey)
  FrameUtil:UnregisterMover(record.moverKey)
  records[key] = nil
end

local P = select(1, ns.Pleebug:DropIn(CustomIcons, { name = "PCM", bucket = "CustomIcons" }))
CustomIcons.Configure = P:Def("CustomIcons:Configure", CustomIcons.Configure)
CustomIcons.UpdateCooldown = P:Def("CustomIcons:UpdateCooldown", CustomIcons.UpdateCooldown)
CustomIcons.UpdateCharge = P:Def("CustomIcons:UpdateCharge", CustomIcons.UpdateCharge)
CustomIcons.ConfigureAura = P:Def("CustomIcons:ConfigureAura", CustomIcons.ConfigureAura)
CustomIcons.RefreshStyle = P:Def("CustomIcons:RefreshStyle", CustomIcons.RefreshStyle)
CustomIcons.RefreshVisibility = P:Def("CustomIcons:RefreshVisibility", CustomIcons.RefreshVisibility)
CustomIcons.RefreshAllVisibility = P:Def("CustomIcons:RefreshAllVisibility", CustomIcons.RefreshAllVisibility)
CustomIcons.FlushAuraStyles = P:Def("CustomIcons:FlushAuraStyles", CustomIcons.FlushAuraStyles)
CustomIcons.Release = P:Def("CustomIcons:Release", CustomIcons.Release)
CustomIcons.Delete = P:Def("CustomIcons:Delete", CustomIcons.Delete)
