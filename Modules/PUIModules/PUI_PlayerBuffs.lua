local ADDON_NAME, ns = ...

local Addon = ns.Addon

local PlayerBuffs = Addon:NewModule("PlayerBuffs", "NumyAceEvent-3.0")
ns.Modules.PlayerBuffs = PlayerBuffs


local P = select(1, ns.Pleebug:DropIn(PlayerBuffs, { name = "Modules.PlayerBuffs" }))


local _G = _G

local AnchorUtil = _G.AnchorUtil
local AuraContainerItemEnchantmentSlot = _G.AuraContainerItemEnchantmentSlot
local AuraContainerItemEnchantmentSortMethod = _G.AuraContainerItemEnchantmentSortMethod
local AuraContainerSortDirection = _G.AuraContainerSortDirection
local AuraContainerSortMethod = _G.AuraContainerSortMethod
local CVarCallbackRegistry = _G.CVarCallbackRegistry
local CreateFont = _G.CreateFont
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI
local UIParent = _G.UIParent
local math_ceil = _G.math.ceil
local math_max = _G.math.max
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local Theme = ns.Theme
local LSM = ns.LSM
local FrameUtil = ns.FrameUtil

local PLAYER_BUFFS_DEFAULTS_VERSION = 1
local PLAYER_BUFFS_MOVER_KEY = "PlayerBuffs"
local PLAYER_DEBUFFS_MOVER_KEY = "PlayerDebuffs"
local PLAYER_BUFFS_GROUP_KEY = "pui_player_buffs"
local PLAYER_DEBUFFS_GROUP_KEY = "pui_player_debuffs"
local PLAYER_AURA_TEMPLATE_NAMES = { "PUI_PlayerAuraButtonTemplate" }
local ICONS_PER_ROW = 8
local ICON_SPACING = 5

local FRAME_KIND_BY_KEY = {
  [PLAYER_BUFFS_MOVER_KEY] = "buffs",
  [PLAYER_DEBUFFS_MOVER_KEY] = "debuffs",
}

local DEFAULTS = {
  enabled = true,
  textSize = 12,
  fontOutline = "OUTLINE",
  borderSize = 1,
  buffs = {
    iconSize = 30,
    anchor = {
      moved = false,
      x = 0,
      y = 0,
    },
  },
  debuffs = {
    iconSize = 30,
    anchor = {
      moved = false,
      x = 0,
      y = 0,
    },
  },
}

local playerAuraFont = CreateFont("PUI_PlayerAuraFont")
local blizzardAuraParent = CreateFrame("Frame", nil, UIParent)
local buttonParts = setmetatable({}, { __mode = "k" })

blizzardAuraParent:Hide()

local function CopyTable(src)
  local out = {}

  for k, v in pairs(src) do
    if type(v) == "table" then
      out[k] = CopyTable(v)
    else
      out[k] = v
    end
  end

  return out
end

local function MergeDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = {}
      end
      MergeDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function Clamp(value, minValue, maxValue)
  value = tonumber(value) or minValue

  if value < minValue then
    return minValue
  end

  if value > maxValue then
    return maxValue
  end

  return value
end

local function Round(value)
  return ns.Pixel.Round(tonumber(value) or 0)
end

local function GetProfileDB()
  local profile = Addon.db.profile

  if type(profile.playerBuffs) ~= "table" then
    profile.playerBuffs = CopyTable(DEFAULTS)
  end

  local db = profile.playerBuffs

  if db.__puiDefaultsVersion ~= PLAYER_BUFFS_DEFAULTS_VERSION then
    MergeDefaults(db, DEFAULTS)
    db.__puiDefaultsVersion = PLAYER_BUFFS_DEFAULTS_VERSION
  end

  return db
end

local function GetAuraFrameDB(db, kind)
  kind = kind == "debuffs" and "debuffs" or "buffs"

  local frameDB = db[kind]
  if type(frameDB) ~= "table" then
    frameDB = CopyTable(DEFAULTS[kind])
    db[kind] = frameDB
  end

  frameDB.iconSize = tonumber(frameDB.iconSize) or DEFAULTS[kind].iconSize

  if type(frameDB.anchor) ~= "table" then
    frameDB.anchor = CopyTable(DEFAULTS[kind].anchor)
  end

  return frameDB
end

local function GetAnchorDB(db, kind)
  local frameDB = GetAuraFrameDB(db, kind)
  local anchor = frameDB.anchor

  anchor.moved = anchor.moved == true
  anchor.x = tonumber(anchor.x) or 0
  anchor.y = tonumber(anchor.y) or 0

  return anchor
end

local function GetTopRightOffsets(frame)
  local right = frame:GetRight()
  local top = frame:GetTop()
  local parentRight = UIParent:GetRight()
  local parentTop = UIParent:GetTop()

  if right and top and parentRight and parentTop then
    return Round(right - parentRight), Round(top - parentTop)
  end

  local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
  if point == "TOPRIGHT" and relativeTo == UIParent and relativePoint == "TOPRIGHT" then
    return Round(x), Round(y)
  end

  return 0, 0
end

local function GetActiveUnit()
  return _G.PlayerFrame.unit or "player"
end

local function GetRoot(kind)
  if kind == "debuffs" then
    return PlayerBuffs.debuffRoot
  end

  return PlayerBuffs.buffRoot
end

local function GetMaximumFrameCount(kind)
  if kind == "debuffs" then
    return _G.DEBUFF_MAX_DISPLAY
  end

  return _G.BUFF_MAX_DISPLAY + 2
end

local function GetDisplayMetrics(db, kind)
  local frameDB = GetAuraFrameDB(db, kind)
  local iconSize = Round(Clamp(frameDB.iconSize, 24, 64))
  local textHeight = Round(math_max(10, Clamp(db.textSize, 8, 32) + 2))
  local spacing = Round(ICON_SPACING)
  local elementHeight = iconSize + textHeight
  local width = (iconSize * ICONS_PER_ROW) + (spacing * (ICONS_PER_ROW - 1))
  local rows = math_ceil(GetMaximumFrameCount(kind) / ICONS_PER_ROW)
  local height = (elementHeight * rows) + (spacing * math_max(0, rows - 1))

  return iconSize, textHeight, elementHeight, spacing, width, height
end

local puiStyleSerial = 0
local puiStyleCache = {
  serial = 0,
  fontPath = _G.STANDARD_TEXT_FONT,
  fontSize = DEFAULTS.textSize,
  fontFlags = DEFAULTS.fontOutline,
  textR = 1,
  textG = 1,
  textB = 1,
  textA = 1,
  borderSize = DEFAULTS.borderSize,
  borderThickness = DEFAULTS.borderSize,
  borderR = 0,
  borderG = 0,
  borderB = 0,
  borderA = 1,
}

local function GetFontPath()
  local fontKey = select(1, Theme.GetIconTextGlobal())

  if fontKey then
    local fetched = LSM:Fetch(LSM.MediaType.FONT, fontKey, true)
    if fetched then
      return fetched
    end
  end

  return _G.STANDARD_TEXT_FONT
end

local function GetFontFlags(db)
  local flags = db and db.fontOutline or "OUTLINE"

  flags = Theme.NormalizeOutlineFlags(flags)

  if flags == nil then
    flags = "OUTLINE"
  end

  return flags
end

local function GetThemeStyleColors()
  local colors = Theme.GetColors()
  local text = colors.text
  local border = colors.border

  return text[1] or 1,
    text[2] or 1,
    text[3] or 1,
    text[4] or 1,
    border[1] or 1,
    border[2] or 1,
    border[3] or 1,
    border[4] or 1
end

local function ApplyFontObject(style)
  playerAuraFont:SetFont(style.fontPath, style.fontSize, style.fontFlags)
  playerAuraFont:SetTextColor(style.textR, style.textG, style.textB, style.textA)
  playerAuraFont:SetShadowColor(0, 0, 0, 0.9)
  playerAuraFont:SetShadowOffset(1, -1)
end

local function RefreshStyleCache(db)
  local fontPath = GetFontPath()
  local fontSize = Theme.ResolveFontSize(Clamp(db and db.textSize, 8, 32), "playerBuffs")
  local fontFlags = GetFontFlags(db)
  local textR, textG, textB, textA, borderR, borderG, borderB, borderA = GetThemeStyleColors()
  local borderSize = Clamp(db and db.borderSize, 0, 8)
  local borderThickness = math_max(
    0,
    Round(borderSize * ns.Pixel.GetOnePixel())
  )

  local changed = puiStyleCache.serial == 0
    or puiStyleCache.fontPath ~= fontPath
    or puiStyleCache.fontSize ~= fontSize
    or puiStyleCache.fontFlags ~= fontFlags
    or puiStyleCache.textR ~= textR
    or puiStyleCache.textG ~= textG
    or puiStyleCache.textB ~= textB
    or puiStyleCache.textA ~= textA
    or puiStyleCache.borderSize ~= borderSize
    or puiStyleCache.borderThickness ~= borderThickness
    or puiStyleCache.borderR ~= borderR
    or puiStyleCache.borderG ~= borderG
    or puiStyleCache.borderB ~= borderB
    or puiStyleCache.borderA ~= borderA

  if not changed then
    return false
  end

  puiStyleSerial = puiStyleSerial + 1

  puiStyleCache.serial = puiStyleSerial
  puiStyleCache.fontPath = fontPath
  puiStyleCache.fontSize = fontSize
  puiStyleCache.fontFlags = fontFlags
  puiStyleCache.textR = textR
  puiStyleCache.textG = textG
  puiStyleCache.textB = textB
  puiStyleCache.textA = textA
  puiStyleCache.borderSize = borderSize
  puiStyleCache.borderThickness = borderThickness
  puiStyleCache.borderR = borderR
  puiStyleCache.borderG = borderG
  puiStyleCache.borderB = borderB
  puiStyleCache.borderA = borderA

  ApplyFontObject(puiStyleCache)
  return true
end

local function GetButtonParts(button)
  local parts = buttonParts[button]
  if parts then
    return parts
  end

  parts = {
    icon = button.PUIIcon,
    applicationHolder = button.PUIApplicationHolder,
    applicationText = button.PUIApplicationHolder.PUIApplicationCount,
    durationTextHolder = button.PUIDurationTextHolder,
    durationText = button.PUIDurationTextHolder.PUIDurationText,
    durationCooldown = button.PUIDurationCooldown,
    borderTop = button.PUIBorderTop,
    borderBottom = button.PUIBorderBottom,
    borderLeft = button.PUIBorderLeft,
    borderRight = button.PUIBorderRight,
  }

  buttonParts[button] = parts
  return parts
end

local function ApplyBorder(parts, style)
  local thickness = style.borderThickness

  if parts.borderThickness ~= thickness then
    parts.borderThickness = thickness
    parts.borderTop:SetHeight(thickness)
    parts.borderBottom:SetHeight(thickness)
    parts.borderLeft:SetWidth(thickness)
    parts.borderRight:SetWidth(thickness)
  end

  local colorChanged = parts.borderR ~= style.borderR
    or parts.borderG ~= style.borderG
    or parts.borderB ~= style.borderB
    or parts.borderA ~= style.borderA

  if colorChanged then
    parts.borderR = style.borderR
    parts.borderG = style.borderG
    parts.borderB = style.borderB
    parts.borderA = style.borderA
    parts.borderTop:SetVertexColor(style.borderR, style.borderG, style.borderB, style.borderA)
    parts.borderBottom:SetVertexColor(style.borderR, style.borderG, style.borderB, style.borderA)
    parts.borderLeft:SetVertexColor(style.borderR, style.borderG, style.borderB, style.borderA)
    parts.borderRight:SetVertexColor(style.borderR, style.borderG, style.borderB, style.borderA)
  end

  local shown = thickness > 0
  parts.borderTop:SetShown(shown)
  parts.borderBottom:SetShown(shown)
  parts.borderLeft:SetShown(shown)
  parts.borderRight:SetShown(shown)
end

local function BuildRuntimeVariantKey(db, kind)
  local iconSize, textHeight, _, spacing = GetDisplayMetrics(db, kind)
  local style = puiStyleCache

  return tostring(iconSize)
    .. ":" .. tostring(textHeight)
    .. ":" .. tostring(spacing)
    .. ":" .. tostring(style.borderThickness)
    .. ":" .. tostring(style.borderR)
    .. ":" .. tostring(style.borderG)
    .. ":" .. tostring(style.borderB)
    .. ":" .. tostring(style.borderA)
end

local function BuildGroupLayout(runtime, layoutIndex)
  return {
    elementSpacing = runtime.spacing,
    lineSpacing = runtime.spacing,
    groupSpacing = 0,
    groupLineSpacing = runtime.spacing,
    forceNewLine = false,
    elementWidth = runtime.iconSize,
    elementHeight = runtime.elementHeight,
    layoutIndex = layoutIndex,
  }
end

local function ConfigureAuraButton(runtime, button)
  local parts = GetButtonParts(button)
  local iconSize = runtime.iconSize
  local textHeight = runtime.textHeight

  button:SetSize(iconSize, runtime.elementHeight)

  parts.icon:ClearAllPoints()
  parts.icon:SetPoint("TOP", button, "TOP", 0, 0)
  parts.icon:SetSize(iconSize, iconSize)
  parts.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  parts.icon:SetDrawLayer("ARTWORK", -1)

  parts.applicationHolder:ClearAllPoints()
  parts.applicationHolder:SetAllPoints(parts.icon)
  parts.applicationHolder:SetFrameLevel(button:GetFrameLevel() + 3)

  parts.applicationText:ClearAllPoints()
  parts.applicationText:SetPoint("BOTTOMRIGHT", parts.icon, "BOTTOMRIGHT", -1, 1)
  parts.applicationText:SetDrawLayer("OVERLAY", 7)
  parts.applicationText:SetFontObject(playerAuraFont)

  parts.durationTextHolder:ClearAllPoints()
  parts.durationTextHolder:SetPoint("TOPLEFT", parts.icon, "BOTTOMLEFT", 0, 0)
  parts.durationTextHolder:SetPoint("TOPRIGHT", parts.icon, "BOTTOMRIGHT", 0, 0)
  parts.durationTextHolder:SetHeight(textHeight)
  parts.durationTextHolder:SetFrameLevel(button:GetFrameLevel() + 3)

  parts.durationText:SetDrawLayer("OVERLAY", 7)
  parts.durationText:SetFontObject(playerAuraFont)

  parts.durationCooldown:ClearAllPoints()
  parts.durationCooldown:SetAllPoints(parts.icon)
  parts.durationCooldown:SetFrameLevel(button:GetFrameLevel() + 1)
  parts.durationCooldown:SetDrawEdge(false)
  parts.durationCooldown:SetDrawBling(false)
  parts.durationCooldown:SetUseCircularEdge(false)
  parts.durationCooldown:SetDrawSwipe(true)
  parts.durationCooldown:SetHideCountdownNumbers(true)
  parts.durationCooldown:SetReverse(true)
  parts.durationCooldown:SetSwipeColor(0, 0, 0, 0.65)

  parts.borderTop:ClearAllPoints()
  parts.borderTop:SetPoint("TOPLEFT", parts.icon, "TOPLEFT", 0, 0)
  parts.borderTop:SetPoint("TOPRIGHT", parts.icon, "TOPRIGHT", 0, 0)

  parts.borderBottom:ClearAllPoints()
  parts.borderBottom:SetPoint("BOTTOMLEFT", parts.icon, "BOTTOMLEFT", 0, 0)
  parts.borderBottom:SetPoint("BOTTOMRIGHT", parts.icon, "BOTTOMRIGHT", 0, 0)

  parts.borderLeft:ClearAllPoints()
  parts.borderLeft:SetPoint("TOPLEFT", parts.icon, "TOPLEFT", 0, 0)
  parts.borderLeft:SetPoint("BOTTOMLEFT", parts.icon, "BOTTOMLEFT", 0, 0)

  parts.borderRight:ClearAllPoints()
  parts.borderRight:SetPoint("TOPRIGHT", parts.icon, "TOPRIGHT", 0, 0)
  parts.borderRight:SetPoint("BOTTOMRIGHT", parts.icon, "BOTTOMRIGHT", 0, 0)

  ApplyBorder(parts, puiStyleCache)

  parts.icon:Show()
  parts.applicationHolder:Show()
  parts.applicationText:Show()
  parts.durationTextHolder:Show()
  parts.durationText:Show()
  parts.durationCooldown:Show()

  button:EnableMouse(true)
  button:SetMouseMotionEnabled(true)
  button:SetMouseClickEnabled(runtime.kind == "buffs")
  button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", 0, 0)
  button:SetHideTooltipInCombat(false)
  button:SetCancelAuraButtons(runtime.kind == "buffs" and "RightButtonUp" or nil)

  button:SetIcon(parts.icon)
  button:SetApplicationCount(parts.applicationText, {})
  button:SetDurationCooldown(parts.durationCooldown)
  button:SetDurationText(parts.durationText, {})
end



local function CreateAuraRoot(frameName)
  local root = CreateFrame("Frame", frameName, UIParent)
  root:SetFrameStrata("LOW")
  root:EnableMouse(false)
  root:Hide()
  return root
end

local function CreateAuraRuntime(kind, variantKey)
  local iconSize, textHeight, elementHeight, spacing, width, height = GetDisplayMetrics(PlayerBuffs.db, kind)
  local root = GetRoot(kind)
  local runtime = {
    kind = kind,
    key = variantKey,
    iconSize = iconSize,
    textHeight = textHeight,
    elementHeight = elementHeight,
    spacing = spacing,
    width = width,
    height = height,
  }

  local container = CreateFrame("AuraContainer", nil, root, "CustomAuraContainerTemplate")
  runtime.container = container

  container:SetSize(1, 1)
  container:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
  container:SetFrameStrata("LOW")
  container:SetFlowLayoutAnchorPoint("TOPRIGHT")
  container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
  container:SetFlowLayoutMaximumLineSize(width + ns.Pixel.GetOnePixel())
  container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
  container:SetFlowLayoutPadding(0, 0, 0, 0)
  container:SetUnit(GetActiveUnit())
  container:SetEnabled(false)
  container:Hide()

  local initializeFrame = function(button)
    ConfigureAuraButton(runtime, button)
  end
  local groupKey = kind == "debuffs" and PLAYER_DEBUFFS_GROUP_KEY or PLAYER_BUFFS_GROUP_KEY
  local filterString = kind == "debuffs" and "HARMFUL" or "HELPFUL"
  local maxFrameCount = kind == "debuffs" and _G.DEBUFF_MAX_DISPLAY or _G.BUFF_MAX_DISPLAY
  local groupLayoutIndex = kind == "buffs" and 2 or 1

  if kind == "buffs" then
    container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.MainHand, {
      templateNames = PLAYER_AURA_TEMPLATE_NAMES,
      initializeFrame = initializeFrame,
      hidePermanent = false,
    })
    container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.OffHand, {
      templateNames = PLAYER_AURA_TEMPLATE_NAMES,
      initializeFrame = initializeFrame,
      hidePermanent = false,
    })
    container:SetItemEnchantmentSortMethod(
      AuraContainerItemEnchantmentSortMethod.Slot,
      AuraContainerSortDirection.Normal
    )

    local enchantmentLayout = BuildGroupLayout(runtime, 1)
    enchantmentLayout.placement = _G.CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups
    container:SetItemEnchantmentLayout(enchantmentLayout)
  end

  container:AddAuraGroup(groupKey, filterString, {
    maxFrameCount = maxFrameCount,
    templateNames = PLAYER_AURA_TEMPLATE_NAMES,
    initializeFrame = initializeFrame,
    sortMethod = AuraContainerSortMethod.Default,
    sortDirection = AuraContainerSortDirection.Normal,
    layout = BuildGroupLayout(runtime, groupLayoutIndex),
  })

  return runtime
end

local function DisableAuraRuntime(runtime)
  if not runtime then
    return
  end

  runtime.container:SetEnabled(false)
  runtime.container:Hide()
end

local function ActivateAuraRuntime(kind)
  local db = PlayerBuffs.db
  local variantKey = BuildRuntimeVariantKey(db, kind)
  local variants = PlayerBuffs.runtimeVariants[kind]
  local activeRuntime = PlayerBuffs.activeRuntimes[kind]

  if activeRuntime and activeRuntime.key ~= variantKey then
    DisableAuraRuntime(activeRuntime)
    activeRuntime = nil
  end

  if not activeRuntime then
    activeRuntime = variants[variantKey]

    if not activeRuntime then
      activeRuntime = CreateAuraRuntime(kind, variantKey)
      variants[variantKey] = activeRuntime
    end

    PlayerBuffs.activeRuntimes[kind] = activeRuntime
  end

  local root = GetRoot(kind)
  root:SetSize(activeRuntime.width, activeRuntime.height)

  if PlayerBuffs.runtimeEnabled then
    local unit = GetActiveUnit()
    activeRuntime.container:SetUnit(unit)
    activeRuntime.container:Show()
    activeRuntime.container:SetEnabled(true)
    root:Show()
  end

  return activeRuntime
end

local function CaptureBlizzardAuraOffsets()
  if not PlayerBuffs.defaultBuffOffsets then
    local x, y = GetTopRightOffsets(_G.BuffFrame)
    PlayerBuffs.defaultBuffOffsets = { x = x, y = y }
  end

  if not PlayerBuffs.defaultDebuffOffsets then
    local x, y = GetTopRightOffsets(_G.DebuffFrame)
    PlayerBuffs.defaultDebuffOffsets = { x = x, y = y }
  end
end

local function DisableBlizzardAuraFrames()
  if PlayerBuffs.blizzardFramesDisabled then
    return
  end

  local buffFrame = _G.BuffFrame
  local debuffFrame = _G.DebuffFrame
  local deadlyDebuffFrame = _G.DeadlyDebuffFrame

  PlayerBuffs.blizzardBuffParent = buffFrame:GetParent()
  PlayerBuffs.blizzardDebuffParent = debuffFrame:GetParent()
  PlayerBuffs.blizzardDeadlyDebuffParent = deadlyDebuffFrame:GetParent()

  buffFrame:UnregisterEvent("UNIT_AURA")
  buffFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
  buffFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  buffFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  buffFrame:UnregisterEvent("PLAYER_IN_COMBAT_CHANGED")
  buffFrame:UnregisterEvent("WEAPON_ENCHANT_CHANGED")
  buffFrame:UnregisterEvent("WEAPON_SLOT_CHANGED")

  debuffFrame:UnregisterEvent("UNIT_AURA")
  debuffFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
  debuffFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  debuffFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  debuffFrame:UnregisterEvent("PLAYER_IN_COMBAT_CHANGED")

  CVarCallbackRegistry:UnregisterCallback("consolidateBuffs", buffFrame)
  CVarCallbackRegistry:UnregisterCallback("collapseExpandBuffs", buffFrame)

  buffFrame:SetScript("OnUpdate", nil)
  debuffFrame:SetScript("OnUpdate", nil)

  for _, anchor in ipairs(debuffFrame.PrivateAuraAnchors) do
    anchor:SetUnit(nil)
  end
  debuffFrame.unit = nil

  buffFrame:Hide()
  debuffFrame:Hide()
  deadlyDebuffFrame:Hide()
  buffFrame:SetParent(blizzardAuraParent)
  debuffFrame:SetParent(blizzardAuraParent)
  deadlyDebuffFrame:SetParent(blizzardAuraParent)

  PlayerBuffs.blizzardFramesDisabled = true
end

local function RestoreBlizzardAuraFrames()
  if not PlayerBuffs.blizzardFramesDisabled then
    return
  end

  local buffFrame = _G.BuffFrame
  local debuffFrame = _G.DebuffFrame
  local deadlyDebuffFrame = _G.DeadlyDebuffFrame

  buffFrame:SetParent(PlayerBuffs.blizzardBuffParent)
  debuffFrame:SetParent(PlayerBuffs.blizzardDebuffParent)
  deadlyDebuffFrame:SetParent(PlayerBuffs.blizzardDeadlyDebuffParent)

  PlayerBuffs.blizzardBuffParent = nil
  PlayerBuffs.blizzardDebuffParent = nil
  PlayerBuffs.blizzardDeadlyDebuffParent = nil

  buffFrame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
  buffFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  buffFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  buffFrame:RegisterEvent("PLAYER_IN_COMBAT_CHANGED")
  buffFrame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
  buffFrame:RegisterEvent("WEAPON_SLOT_CHANGED")

  debuffFrame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
  debuffFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  debuffFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  debuffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  debuffFrame:RegisterEvent("PLAYER_IN_COMBAT_CHANGED")

  CVarCallbackRegistry:RegisterCallback(
    "consolidateBuffs",
    buffFrame.OnConsolidationSettingsChanged,
    buffFrame
  )
  CVarCallbackRegistry:RegisterCallback(
    "collapseExpandBuffs",
    buffFrame.OnConsolidationSettingsChanged,
    buffFrame
  )

  buffFrame:Update()
  debuffFrame:Update()
  buffFrame:UpdateShownState()
  debuffFrame:UpdateShownState()

  PlayerBuffs.blizzardFramesDisabled = nil
end

local function EnsureRuntime()
  if PlayerBuffs.buffRoot then
    return false
  end

  CaptureBlizzardAuraOffsets()

  PlayerBuffs.runtimeVariants = {
    buffs = {},
    debuffs = {},
  }
  PlayerBuffs.activeRuntimes = {}
  PlayerBuffs.buffRoot = CreateAuraRoot("PUI_PlayerBuffContainer")
  PlayerBuffs.debuffRoot = CreateAuraRoot("PUI_PlayerDebuffContainer")
  return true
end

local function SetRuntimeEnabled(enabled)
  PlayerBuffs.runtimeEnabled = enabled == true

  if not PlayerBuffs.buffRoot then
    return
  end

  if enabled then
    ActivateAuraRuntime("buffs")
    ActivateAuraRuntime("debuffs")
    return
  end

  DisableAuraRuntime(PlayerBuffs.activeRuntimes.buffs)
  DisableAuraRuntime(PlayerBuffs.activeRuntimes.debuffs)
  PlayerBuffs.buffRoot:Hide()
  PlayerBuffs.debuffRoot:Hide()
end

local function ResolveApplyFlags(flags)
  if flags == nil then
    return true, true, true, true
  end

  if type(flags) ~= "table" then
    return false, false, false, false
  end

  local applyAll = flags.playerBuffs == true or flags.profile == true
  local applyStyle = applyAll
    or flags.playerBuffsStyle == true
    or flags.theme == true
    or flags.fonts == true
  local applyBuffSize = applyAll or flags.playerBuffsBuffSize == true
  local applyDebuffSize = applyAll or flags.playerBuffsDebuffSize == true

  return applyAll, applyStyle, applyBuffSize, applyDebuffSize
end

local function MergePendingApplyFlags(pending, flags)
  pending = pending or {}

  if flags == nil then
    pending.playerBuffs = true
    return pending
  end

  for key, value in pairs(flags) do
    if value == true then
      pending[key] = true
    end
  end

  return pending
end

function PlayerBuffs:ApplyAnchorPosition(kind)
  if not self.buffRoot then
    return
  end

  local function ApplyOne(frameKind)
    local root = GetRoot(frameKind)
    local anchor = GetAnchorDB(self.db, frameKind)
    local defaults = frameKind == "debuffs" and self.defaultDebuffOffsets or self.defaultBuffOffsets
    local x = anchor.moved and anchor.x or defaults.x
    local y = anchor.moved and anchor.y or defaults.y

    root:ClearAllPoints()
    root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", Round(x), Round(y))
  end

  if not kind or kind == "buffs" then
    ApplyOne("buffs")
  end

  if not kind or kind == "debuffs" then
    ApplyOne("debuffs")
  end

  self.pendingAnchorApply = nil
end

function PlayerBuffs:SaveAnchorPosition(frame, key)
  local db = GetProfileDB()
  local kind = FRAME_KIND_BY_KEY[key] or "buffs"
  local anchor = GetAnchorDB(db, kind)
  local x, y = GetTopRightOffsets(frame)

  anchor.moved = true
  anchor.x = x
  anchor.y = y

  self.db = db
  self:ApplyAnchorPosition(kind)
end

function PlayerBuffs:ResetAnchorPosition(_, key)
  local kind = FRAME_KIND_BY_KEY[key] or "buffs"
  local db = GetProfileDB()
  local anchor = GetAnchorDB(db, kind)

  anchor.moved = false
  anchor.x = 0
  anchor.y = 0

  self.db = db
  self:ApplyAnchorPosition(kind)
  self:RefreshMover(kind)
end

function PlayerBuffs:RefreshMover(kind)
  if kind == "buffs" then
    FrameUtil:RefreshGhostMover(PLAYER_BUFFS_MOVER_KEY)
    return
  end

  if kind == "debuffs" then
    FrameUtil:RefreshGhostMover(PLAYER_DEBUFFS_MOVER_KEY)
    return
  end

  FrameUtil:RefreshGhostMover(PLAYER_BUFFS_MOVER_KEY)
  FrameUtil:RefreshGhostMover(PLAYER_DEBUFFS_MOVER_KEY)
end

function PlayerBuffs:EnsureMovers()
  if not self.buffRoot or self.db.enabled == false then
    return
  end

  local function RegisterAuraMover(kind, key, frameName, label)
    FrameUtil:EnsureGhostMover(key, {
      frameName = frameName,
      label = label,
      ghost = false,
      useOverlayDrag = true,
      smartSnap = {
        family = "positionOnly",
        isRuntimeActive = function()
          return GetProfileDB().enabled ~= false
        end,
      },
      liveFrame = function()
        return GetRoot(kind)
      end,
      getSize = function(_, liveFrame)
        return liveFrame:GetSize()
      end,
      getPoint = function(_, liveFrame)
        return liveFrame:GetPoint(1)
      end,
      shouldShow = function()
        return GetProfileDB().enabled ~= false
          and ns.Flags.IsEditing
          and GetRoot(kind):IsShown()
      end,
      savePosition = function(frame, moverKey)
        PlayerBuffs:SaveAnchorPosition(frame, moverKey)
      end,
      onDragStop = function()
        PlayerBuffs:RefreshMover(kind)
      end,
      resetPosition = function(frame, moverKey)
        PlayerBuffs:ResetAnchorPosition(frame, moverKey)
      end,
      optionsSection = "PLAYER_BUFFS",
      optionsKey = kind,
      quickSettings = function()
        local db = GetProfileDB()
        local frameDB = GetAuraFrameDB(db, kind)
        return {
          ownerKey = key,
          title = label,
          description = "Live aura frame settings.",
          controls = {
            {
              type = "slider",
              label = "Icon size",
              min = 24,
              max = 64,
              step = 1,
              get = function() return frameDB.iconSize end,
              set = function(value)
                frameDB.iconSize = Round(Clamp(value, 24, 64))
                PlayerBuffs:ApplySettings({
                  playerBuffsBuffSize = kind == "buffs",
                  playerBuffsDebuffSize = kind == "debuffs",
                })
              end,
            },
            {
              type = "slider",
              label = "Text size",
              min = 6,
              max = 24,
              step = 1,
              get = function() return db.textSize end,
              set = function(value)
                db.textSize = Round(Clamp(value, 8, 32))
                PlayerBuffs:ApplySettings({ playerBuffsStyle = true })
              end,
            },
            {
              type = "slider",
              label = "Border size",
              min = 0,
              max = 8,
              step = 1,
              get = function() return db.borderSize end,
              set = function(value)
                db.borderSize = Round(Clamp(value, 0, 8))
                PlayerBuffs:ApplySettings({ playerBuffsStyle = true })
              end,
            },
          },
        }
      end,
    })
  end

  RegisterAuraMover("buffs", PLAYER_BUFFS_MOVER_KEY, "PUI_PlayerBuffsMover", "Player Buffs")
  RegisterAuraMover("debuffs", PLAYER_DEBUFFS_MOVER_KEY, "PUI_PlayerDebuffsMover", "Player Debuffs")
end

function PlayerBuffs:ApplySettings(flags)
  local applyAll, applyStyle, applyBuffSize, applyDebuffSize = ResolveApplyFlags(flags)

  if not applyAll and not applyStyle and not applyBuffSize and not applyDebuffSize then
    return
  end

  if InCombatLockdown() then
    self.pendingApply = MergePendingApplyFlags(self.pendingApply, flags)
    return
  end

  local db = GetProfileDB()
  self.pendingApply = nil
  self.db = db

  if db.enabled == false then
    SetRuntimeEnabled(false)
    RestoreBlizzardAuraFrames()
    self:RefreshMover()
    return
  end

  local styleChanged = applyStyle and RefreshStyleCache(db)
  if puiStyleCache.serial == 0 then
    styleChanged = RefreshStyleCache(db)
  end

  local runtimeCreated = EnsureRuntime()
  DisableBlizzardAuraFrames()
  self.runtimeEnabled = true

  if runtimeCreated or applyAll or applyStyle or applyBuffSize then
    ActivateAuraRuntime("buffs")
  end

  if runtimeCreated or applyAll or applyStyle or applyDebuffSize then
    ActivateAuraRuntime("debuffs")
  end

  if applyAll then
    self:ApplyAnchorPosition()
    self:EnsureMovers()
    self:RefreshMover()
  else
    if applyBuffSize or styleChanged then
      self:RefreshMover("buffs")
    end

    if applyDebuffSize or styleChanged then
      self:RefreshMover("debuffs")
    end
  end
end

function PlayerBuffs:RefreshFonts()
  local db = GetProfileDB()
  if db.enabled == false then
    return
  end

  RefreshStyleCache(db)
end

function PlayerBuffs:UpdateUnit(event, unit)
  if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE")
    and unit ~= "player"
  then
    return
  end

  if not self.buffRoot or self.db.enabled == false then
    return
  end

  local activeUnit = GetActiveUnit()
  local buffRuntime = self.activeRuntimes.buffs
  local debuffRuntime = self.activeRuntimes.debuffs

  if buffRuntime then
    buffRuntime.container:SetUnit(activeUnit)
  end

  if debuffRuntime then
    debuffRuntime.container:SetUnit(activeUnit)
  end
end

function PlayerBuffs:OnRegenEnabled()
  if self.pendingBlizzardRestore then
    self.pendingBlizzardRestore = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    RestoreBlizzardAuraFrames()
    return
  end

  if self.pendingApply then
    local pending = self.pendingApply
    self.pendingApply = nil
    self:ApplySettings(pending)
  end
end

function PlayerBuffs:GetOptions()
  local function GetValue(info)
    return GetProfileDB()[info[#info]]
  end

  local function SetValue(info, value)
    GetProfileDB()[info[#info]] = value
    self:ApplySettings({ playerBuffsStyle = true })
  end

  return {
    type = "group",
    name = "Player Buffs",
    args = {
      general = {
        type = "group",
        name = "Player buffs",
        order = 10,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Enable player buffs",
            order = 10,
            get = GetValue,
            set = function(_, value)
              local db = GetProfileDB()
              local enabled = value == true
              local previous = db.enabled == true

              if enabled == previous then
                return
              end

              local function RevertEnabled()
                db.enabled = previous
                LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
              end

              db.enabled = enabled

              Addon:PUI_ConfirmAction({
                title = "Reload required",
                text = "Changing Player Buffs requires a reload.\n\nReload now?",
                yesText = "Reload",
                noText = "Cancel",
                onYes = function()
                  if InCombatLockdown() then
                    RevertEnabled()
                    Addon:Print("|cffff4444[PUI]|r Cannot reload while in combat.")
                    return
                  end

                  ReloadUI()
                end,
                onNo = RevertEnabled,
              })
            end,
          },
        },
      },
      iconSize = {
        type = "group",
        name = "Icon size",
        order = 20,
        inline = true,
        args = {
          buffIconSize = {
            type = "range",
            name = "Buff icon size",
            order = 10,
            min = 24,
            max = 64,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return GetAuraFrameDB(GetProfileDB(), "buffs").iconSize
            end,
            set = function(_, value)
              GetAuraFrameDB(GetProfileDB(), "buffs").iconSize = value
              self:ApplySettings({ playerBuffsBuffSize = true })
            end,
          },
          debuffIconSize = {
            type = "range",
            name = "Debuff icon size",
            order = 20,
            min = 24,
            max = 64,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return GetAuraFrameDB(GetProfileDB(), "debuffs").iconSize
            end,
            set = function(_, value)
              GetAuraFrameDB(GetProfileDB(), "debuffs").iconSize = value
              self:ApplySettings({ playerBuffsDebuffSize = true })
            end,
          },
        },
      },
      textAndBorder = {
        type = "group",
        name = "Text and border",
        order = 30,
        inline = true,
        args = {
          textSize = {
            type = "range",
            name = "Text size",
            order = 10,
            min = 8,
            max = 32,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = GetValue,
            set = SetValue,
          },
          fontOutline = {
            type = "select",
            name = "Text outline",
            order = 20,
            values = Theme.GetOutlineList(),
            get = GetValue,
            set = SetValue,
          },
          borderSize = {
            type = "range",
            name = "Border size",
            order = 30,
            min = 0,
            max = 8,
            step = 1,
            get = GetValue,
            set = SetValue,
          },
        },
      },
    },
  }
end

function PlayerBuffs:OnInitialize()
  GetProfileDB()

  Addon:RegisterOptionsSection("PLAYER_BUFFS", function()
    return PlayerBuffs
  end, 32, "Player Buffs", nil, {
    preview = false,
  })
end

function PlayerBuffs:OnEnable()
  local db = GetProfileDB()
  self.db = db
  self.pendingBlizzardRestore = nil

  if db.enabled == false then
    return
  end

  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateUnit")
  self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateUnit")
  self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateUnit")
  self:ApplySettings({ playerBuffs = true })
end

function PlayerBuffs:OnDisable()
  self:UnregisterAllEvents()
  SetRuntimeEnabled(false)

  if InCombatLockdown() then
    self.pendingBlizzardRestore = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
  else
    RestoreBlizzardAuraFrames()
  end

  self:RefreshMover()
end



  CopyTable = P:Def("CopyTable", CopyTable)
  MergeDefaults = P:Def("MergeDefaults", MergeDefaults)
  Clamp = P:Def("Clamp", Clamp)
  Round = P:Def("Round", Round)
  GetProfileDB = P:Def("GetProfileDB", GetProfileDB)
  GetAuraFrameDB = P:Def("GetAuraFrameDB", GetAuraFrameDB)
  GetAnchorDB = P:Def("GetAnchorDB", GetAnchorDB)
  GetTopRightOffsets = P:Def("GetTopRightOffsets", GetTopRightOffsets)
  GetActiveUnit = P:Def("GetActiveUnit", GetActiveUnit)
  GetRoot = P:Def("GetRoot", GetRoot)
  GetMaximumFrameCount = P:Def("GetMaximumFrameCount", GetMaximumFrameCount)
  GetDisplayMetrics = P:Def("GetDisplayMetrics", GetDisplayMetrics)
  GetFontPath = P:Def("GetFontPath", GetFontPath)
  GetFontFlags = P:Def("GetFontFlags", GetFontFlags)
  GetThemeStyleColors = P:Def("GetThemeStyleColors", GetThemeStyleColors)
  ApplyFontObject = P:Def("ApplyFontObject", ApplyFontObject)
  RefreshStyleCache = P:Def("RefreshStyleCache", RefreshStyleCache)
  GetButtonParts = P:Def("GetButtonParts", GetButtonParts)
  ApplyBorder = P:Def("ApplyBorder", ApplyBorder)
  BuildRuntimeVariantKey = P:Def("BuildRuntimeVariantKey", BuildRuntimeVariantKey)
  BuildGroupLayout = P:Def("BuildGroupLayout", BuildGroupLayout)
  ConfigureAuraButton = P:Def("ConfigureAuraButton", ConfigureAuraButton)
  CreateAuraRoot = P:Def("CreateAuraRoot", CreateAuraRoot)
  CreateAuraRuntime = P:Def("CreateAuraRuntime", CreateAuraRuntime)
  DisableAuraRuntime = P:Def("DisableAuraRuntime", DisableAuraRuntime)
  ActivateAuraRuntime = P:Def("ActivateAuraRuntime", ActivateAuraRuntime)
  CaptureBlizzardAuraOffsets = P:Def("CaptureBlizzardAuraOffsets", CaptureBlizzardAuraOffsets)
  DisableBlizzardAuraFrames = P:Def("DisableBlizzardAuraFrames", DisableBlizzardAuraFrames)
  RestoreBlizzardAuraFrames = P:Def("RestoreBlizzardAuraFrames", RestoreBlizzardAuraFrames)
  EnsureRuntime = P:Def("EnsureRuntime", EnsureRuntime)
  SetRuntimeEnabled = P:Def("SetRuntimeEnabled", SetRuntimeEnabled)
  ResolveApplyFlags = P:Def("ResolveApplyFlags", ResolveApplyFlags)
  MergePendingApplyFlags = P:Def("MergePendingApplyFlags", MergePendingApplyFlags)
  PlayerBuffs.ApplyAnchorPosition = P:Def("PlayerBuffs.ApplyAnchorPosition", PlayerBuffs.ApplyAnchorPosition)
  PlayerBuffs.SaveAnchorPosition = P:Def("PlayerBuffs.SaveAnchorPosition", PlayerBuffs.SaveAnchorPosition)
  PlayerBuffs.ResetAnchorPosition = P:Def("PlayerBuffs.ResetAnchorPosition", PlayerBuffs.ResetAnchorPosition)
  PlayerBuffs.RefreshMover = P:Def("PlayerBuffs.RefreshMover", PlayerBuffs.RefreshMover)
  PlayerBuffs.EnsureMovers = P:Def("PlayerBuffs.EnsureMovers", PlayerBuffs.EnsureMovers)
  PlayerBuffs.ApplySettings = P:Def("PlayerBuffs.ApplySettings", PlayerBuffs.ApplySettings)
  PlayerBuffs.RefreshFonts = P:Def("PlayerBuffs.RefreshFonts", PlayerBuffs.RefreshFonts)
  PlayerBuffs.UpdateUnit = P:Def("PlayerBuffs.UpdateUnit", PlayerBuffs.UpdateUnit)
  PlayerBuffs.OnRegenEnabled = P:Def("PlayerBuffs.OnRegenEnabled", PlayerBuffs.OnRegenEnabled)
  PlayerBuffs.GetOptions = P:Def("PlayerBuffs.GetOptions", PlayerBuffs.GetOptions)
  PlayerBuffs.OnInitialize = P:Def("PlayerBuffs.OnInitialize", PlayerBuffs.OnInitialize)
  PlayerBuffs.OnEnable = P:Def("PlayerBuffs.OnEnable", PlayerBuffs.OnEnable)
  PlayerBuffs.OnDisable = P:Def("PlayerBuffs.OnDisable", PlayerBuffs.OnDisable)

_G.PleebUIAPI:RegisterPlugin("PleebUI_PlayerBuffs", {
  name = "Player Buffs",
}):RegisterEditModeParticipant("runtime", {
  order = 150,
  onChanged = function(enable)
    if enable then
      PlayerBuffs:EnsureMovers()
    end
  end,
})
