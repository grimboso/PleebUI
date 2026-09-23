local ADDON_NAME, ns = ...

local Addon = ns.Addon
local FrameUtil = ns.FrameUtil
local IconSkin = ns.IconSkin
local Theme = ns.Theme
local LSM = ns.LSM
local Pixel = ns.Pixel
local FrameScale = ns.FrameScale

local ActionBar = Addon:NewModule("ActionBar", "NumyAceEvent-3.0")
ns.Modules.ActionBar = ActionBar

local Core = {}
ns.ActionBarsCore = Core

local P = select(1, ns.Pleebug:DropIn(Core))
Core.module = ActionBar
Core.LibKeyBound = LibStub("LibKeyBound-1.0")
Core.subsystems = {}
Core.subsystemOrder = {}
Core.bars = {}
Core.alphaBars = {}
Core.skinCache = {}
Core.fontCache = {}
Core.skinVersion = 0
Core.pendingRefreshFlags = {}
Core.pendingSubsystemRefreshes = {}
Core.pendingCooldownStyles = setmetatable({}, { __mode = "k" })
Core.equippedBorderButtons = setmetatable({}, { __mode = "k" })

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local ClearOverrideBindings = ClearOverrideBindings
local SetOverrideBindingClick = SetOverrideBindingClick
local GetBindingKey = GetBindingKey
local SetCVar = SetCVar
local GetCVar = GetCVar
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select
local type = type
local tonumber = tonumber
local tostring = tostring
local math_floor = math.floor
local math_max = math.max
local unpack = unpack
local wipe = wipe

local Round = Pixel.Round

local PADDING_X = 4
local PADDING_Y = 4
local CHARGE_SWIPE_COLOR = { 0, 0, 0, 0.4 }
local EQUIPPED_BORDER_OUTER_ALPHA = 1
local EQUIPPED_BORDER_INNER_ALPHA = 0.5

local STANDARD_BAR_KEYS = {
  ["1"] = true,
  ["2"] = true,
  ["3"] = true,
  ["4"] = true,
  ["5"] = true,
  ["6"] = true,
  ["7"] = true,
  ["8"] = true,
  ["9"] = true,
  ["10"] = true,
  ["11"] = true,
  ["12"] = true,
}

local FLYOUT_DIRECTIONS = {
  UP = true,
  DOWN = true,
  LEFT = true,
  RIGHT = true,
}

local TOOLTIP_MODES = {
  enabled = true,
  nocombat = true,
  disabled = true,
}

local ACTIONBARS_DEFAULTS = {
  profile = {
    movers = {},

    lockActionBars = true,
    castOnKeyDown = true,
    alwaysShowGrid = true,
    countdownForCooldowns = true,
    spellUIForceAlpha = false,
    tooltipMode = "enabled",
    useBlizzardVehicleUI = false,

    bars = {
      ["1"] = { enabled = true, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["2"] = { enabled = true, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["3"] = { enabled = true, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["4"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["5"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["6"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["7"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["8"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["9"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["10"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["11"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },
      ["12"] = { enabled = false, buttonOffset = 0, flyoutDirection = "UP", visibility = {} },

      pet = {
        buttonCount = 10,
        showCooldowns = true,
      },
      stance = {},
    },

    frameBgColor = { 0, 0, 0, 0.7 },
    frameBorderSize = 1,
    frameBorderColor = { 0.20, 0.20, 0.24, 1.00 },

    skin = {
      iconSize = 35,
      iconSpacing = 2,
      iconsPerRow = 12,
      iconsPerBar = 12,

      borderSize = 2,
      borderColor = { 0.20, 0.20, 0.24, 1.00 },

      frameBorderSize = 1,
      frameBorderColor = { 0.20, 0.20, 0.24, 1.00 },
      frameBgColor = { 0, 0, 0, 0.7 },
      showBarBackground = true,

      fontSize = 12,
      fontOutline = "OUTLINE",
      fontColor = { 1, 1, 1, 1 },

      showCooldownText = true,
      showHotkeyText = true,
      showMacroText = true,
      showChargeText = true,

      hotkeyFontFace = nil,
      hotkeyFontSize = 15,
      hotkeyFontOutline = nil,
      hotkeyFontColor = nil,

      macroFontFace = nil,
      macroFontSize = 10,
      macroFontOutline = nil,
      macroFontColor = nil,

      chargeFontFace = nil,
      chargeFontSize = 15,
      chargeFontOutline = nil,
      chargeFontColor = nil,

      cooldownFontFace = nil,
      cooldownFontSize = 12,
      cooldownFontOutline = nil,
      cooldownFontColor = nil,

      alpha = 1.0,
      fadeOutAlpha = 0,
      fadeOutEnabled = false,
      fadeOutDuration = 0,
    },

    overrides = {},
  },
}

local BLIZZARD_MULTI_BAR_FRAMES = {
  "MultiBarBottomLeft",
  "MultiBarBottomRight",
  "MultiBarRight",
  "MultiBarLeft",
  "MultiBar5",
  "MultiBar6",
  "MultiBar7",
}

local BLIZZARD_SPECIAL_BAR_FRAMES = {
  "PetActionBar",
  "StanceBar",
  "PossessActionBar",
}

local BLIZZARD_ACTION_BUTTON_PREFIXES = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
  "MultiBar5Button",
  "MultiBar6Button",
  "MultiBar7Button",
}

-- PleebUI owns the replacement action buttons, the possess page, and optional custom override and vehicle pages.
-- Extra Action, Zone Ability, and Vehicle Exit remain live for SpecialActionBar.
local BLIZZARD_ACTION_BAR_HIDER = CreateFrame("Frame", nil, UIParent)
BLIZZARD_ACTION_BAR_HIDER:Hide()

local function Clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function NormalizeFlyoutDirection(direction)
  return FLYOUT_DIRECTIONS[direction] and direction or "UP"
end

local function NormalizeTooltipMode(mode)
  return TOOLTIP_MODES[mode] and mode or "enabled"
end

function Core:ShouldShowActionTooltip()
  if self.tooltipMode == "disabled" then
    return false
  end
  return self.tooltipMode ~= "nocombat" or not InCombatLockdown()
end

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or fallback or { 1, 1, 1, 1 }
  return {
    color[1] or 1,
    color[2] or 1,
    color[3] or 1,
    color[4] or 1,
  }
end

local function PickField(useCustom, customSkin, baseSkin, field)
  if useCustom and customSkin and customSkin[field] ~= nil then
    return customSkin[field]
  end
  return baseSkin and baseSkin[field]
end

local function PickFontFace(useCustom, customSkin, baseSkin, prefix)
  local face = PickField(useCustom, customSkin, baseSkin, prefix .. "FontFace")
  local useGlobal = PickField(useCustom, customSkin, baseSkin, prefix .. "UseGlobalFont")

  if useGlobal == nil then
    useGlobal = not (type(face) == "string" and face ~= "")
  end

  if useGlobal then
    return nil
  end

  return face
end

function Core:GetDB()
  if not ActionBar.db then
    ActionBar.db = Addon.db:RegisterNamespace("ActionBars", ACTIONBARS_DEFAULTS)
  end

  return ActionBar.db.profile
end

function Core:PrepareProfile()
  local db = self:GetDB()

  db.movers = db.movers or {}
  db.bars = db.bars or {}
  db.overrides = db.overrides or {}
  for barNumber = 1, 12 do
    local barKey = tostring(barNumber)
    local barDB = db.bars[barKey] or {}
    db.bars[barKey] = barDB
    barDB.buttonOffset = math_floor(Clamp(barDB.buttonOffset, 0, 11))
    barDB.flyoutDirection = NormalizeFlyoutDirection(barDB.flyoutDirection)
    if type(barDB.visibility) ~= "table" then
      barDB.visibility = {}
    end
  end
  db.bars.pet = db.bars.pet or {}
  db.bars.pet.buttonCount = Clamp(db.bars.pet.buttonCount or 10, 1, 10)
  db.skin = db.skin or {}
  db.tooltipMode = NormalizeTooltipMode(db.tooltipMode)

  self.lockActionBars = db.lockActionBars ~= false
  self.castOnKeyDown = db.castOnKeyDown ~= false
  self.alwaysShowGrid = db.alwaysShowGrid ~= false
  self.countdownForCooldowns = db.countdownForCooldowns ~= false
  self.spellUIForceAlpha = db.spellUIForceAlpha == true
  self.tooltipMode = db.tooltipMode
  self.useBlizzardVehicleUI = db.useBlizzardVehicleUI == true
end

function Core:RefreshRuntimeSettings()
  local db = self:GetDB()
  self.lockActionBars = db.lockActionBars ~= false
  self.castOnKeyDown = db.castOnKeyDown ~= false
  self.alwaysShowGrid = db.alwaysShowGrid ~= false
  self.countdownForCooldowns = db.countdownForCooldowns ~= false
  self.spellUIForceAlpha = db.spellUIForceAlpha == true
  self.tooltipMode = NormalizeTooltipMode(db.tooltipMode)
  self.useBlizzardVehicleUI = db.useBlizzardVehicleUI == true
end

function Core:InvalidateCaches(flags)
  flags = type(flags) == "table" and flags or { full = true }

  if flags.full or flags.layout or flags.skin or flags.fonts or flags.alpha then
    self.skinCache = {}
  end

  if flags.full or flags.fonts then
    self.fontCache = {}
  end

  if flags.full or flags.skin or flags.fonts then
    self.skinVersion = self.skinVersion + 1
  end
end

function Core:InvalidateBarCache(barKey, flags)
  flags = type(flags) == "table" and flags or { full = true }

  if flags.full or flags.layout or flags.skin or flags.fonts or flags.alpha then
    self.skinCache[barKey] = nil
  end

  if flags.full or flags.skin or flags.fonts then
    self.skinVersion = self.skinVersion + 1
  end
end

function Core:GetEffectiveSkin(barKey, defaultSize)
  local cached = self.skinCache[barKey]
  if cached then
    return cached
  end

  local db = self:GetDB()
  local base = db.skin
  local override = db.overrides[barKey]
  local custom = override and override.skin or nil
  local useCustom = override and override.useCustom == true or false
  local skin = {}

  skin.iconSize = Round(PickField(useCustom, custom, base, "iconSize") or defaultSize or 35)
  skin.iconSpacing = Round(PickField(useCustom, custom, base, "iconSpacing") or 2)
  skin.iconsPerRow = Clamp(PickField(useCustom, custom, base, "iconsPerRow") or 12, 1, 12)
  skin.iconsPerBar = math_floor(Clamp(PickField(useCustom, custom, base, "iconsPerBar") or 12, 1, 12) + 0.5)

  skin.borderSize = tonumber(PickField(useCustom, custom, base, "borderSize")) or 0
  skin.borderColor = CopyColor(PickField(useCustom, custom, base, "borderColor"), { 0.20, 0.20, 0.24, 1 })

  skin.frameBorderSize = tonumber(PickField(useCustom, custom, base, "frameBorderSize") or db.frameBorderSize) or 0
  skin.frameBorderColor = CopyColor(PickField(useCustom, custom, base, "frameBorderColor") or db.frameBorderColor, { 0.20, 0.20, 0.24, 1 })
  skin.frameBgColor = CopyColor(PickField(useCustom, custom, base, "frameBgColor") or db.frameBgColor, { 0, 0, 0, 0.7 })
  skin.showBarBackground = PickField(useCustom, custom, base, "showBarBackground") ~= false

  skin.fontSize = tonumber(PickField(useCustom, custom, base, "fontSize")) or 12
  skin.fontOutline = PickField(useCustom, custom, base, "fontOutline") or "OUTLINE"
  skin.fontColor = CopyColor(PickField(useCustom, custom, base, "fontColor"), { 1, 1, 1, 1 })

  skin.hotkeyFontFace = PickFontFace(useCustom, custom, base, "hotkey")
  skin.hotkeyFontSize = tonumber(PickField(useCustom, custom, base, "hotkeyFontSize")) or skin.fontSize
  skin.hotkeyFontOutline = PickField(useCustom, custom, base, "hotkeyFontOutline") or skin.fontOutline
  skin.hotkeyFontColor = CopyColor(PickField(useCustom, custom, base, "hotkeyFontColor"), skin.fontColor)

  skin.macroFontFace = PickFontFace(useCustom, custom, base, "macro")
  skin.macroFontSize = tonumber(PickField(useCustom, custom, base, "macroFontSize")) or skin.fontSize
  skin.macroFontOutline = PickField(useCustom, custom, base, "macroFontOutline") or skin.fontOutline
  skin.macroFontColor = CopyColor(PickField(useCustom, custom, base, "macroFontColor"), skin.fontColor)

  skin.chargeFontFace = PickFontFace(useCustom, custom, base, "charge")
  skin.chargeFontSize = tonumber(PickField(useCustom, custom, base, "chargeFontSize")) or skin.fontSize
  skin.chargeFontOutline = PickField(useCustom, custom, base, "chargeFontOutline") or skin.fontOutline
  skin.chargeFontColor = CopyColor(PickField(useCustom, custom, base, "chargeFontColor"), skin.fontColor)

  skin.cooldownFontFace = PickFontFace(useCustom, custom, base, "cooldown")
  skin.cooldownFontSize = tonumber(PickField(useCustom, custom, base, "cooldownFontSize")) or skin.fontSize
  skin.cooldownFontOutline = PickField(useCustom, custom, base, "cooldownFontOutline") or skin.fontOutline
  skin.cooldownFontColor = CopyColor(PickField(useCustom, custom, base, "cooldownFontColor"), skin.fontColor)

  skin.showCooldownText = PickField(useCustom, custom, base, "showCooldownText") ~= false
  skin.showHotkeyText = PickField(useCustom, custom, base, "showHotkeyText") ~= false
  skin.showMacroText = PickField(useCustom, custom, base, "showMacroText") ~= false
  skin.showChargeText = PickField(useCustom, custom, base, "showChargeText") ~= false

  skin.alpha = Clamp(PickField(useCustom, custom, base, "alpha") or 1, 0, 1)
  skin.fadeOutAlpha = Clamp(PickField(useCustom, custom, base, "fadeOutAlpha") or 0, 0, 1)
  skin.fadeOutEnabled = PickField(useCustom, custom, base, "fadeOutEnabled") == true
  skin.fadeOutDuration = Clamp(PickField(useCustom, custom, base, "fadeOutDuration") or 0, 0, 10)
  skin.version = self.skinVersion

  self.skinCache[barKey] = skin
  return skin
end

function Core:GetSpecialSkin(barKey, defaultSize)
  local skin = self:GetEffectiveSkin(barKey, defaultSize)
  local db = self:GetDB()
  local override = db.overrides and db.overrides[barKey]
  local customSize = override
    and override.useCustom == true
    and override.skin
    and override.skin.iconSize

  if customSize == nil then
    skin.iconSize = Round(defaultSize)
  end

  return skin
end

function Core:ResolveFont(face)
  local themeFont = Theme.iconTextGlobal and Theme.iconTextGlobal.font or nil
  local key = tostring(face or "") .. "|" .. tostring(themeFont or "")
  local cached = self.fontCache[key]
  if cached then
    return cached
  end

  local path
  if face then
    path = LSM:Fetch("font", face, true)
  end
  if not path and themeFont then
    path = LSM:Fetch("font", themeFont, true)
  end
  path = path or STANDARD_TEXT_FONT
  self.fontCache[key] = path
  return path
end

local function HideRegion(region)
  if not region then return end
  region:Hide()
  region:SetAlpha(0)
end

local function StyleButtonStateTexture(texture, icon, red, green, blue, alpha)
  if not texture or not icon then return end

  texture:SetColorTexture(red, green, blue, alpha)
  texture:ClearAllPoints()
  texture:SetAllPoints(icon)
  texture:SetBlendMode("ADD")
end

local function StyleButtonStateTextures(button, icon)
  if button.__puiActionBarStateTexturesStyled then
    return
  end

  button.__puiActionBarStateTexturesStyled = true

  local pushed = button.GetPushedTexture and button:GetPushedTexture()
  local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
  local checked = button.GetCheckedTexture and button:GetCheckedTexture()

  StyleButtonStateTexture(pushed, icon, 0.9, 0.8, 0.1, 0.3)
  StyleButtonStateTexture(highlight, icon, 1, 1, 1, 0.3)
  StyleButtonStateTexture(checked, icon, 1, 1, 1, 0.3)
end

local function CreateEquippedBorderEdge(parent, alpha)
  local edge = parent:CreateTexture(nil, "OVERLAY")
  Pixel.SetColorTexture(edge, 0, 1, 0, alpha)
  return edge
end

local function LayoutEquippedBorderRing(edges, anchor, inset, edgeSize)
  local sideInset = inset + edgeSize

  edges.top:ClearAllPoints()
  edges.top:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
  edges.top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -inset, -inset)
  edges.top:SetHeight(edgeSize)

  edges.bottom:ClearAllPoints()
  edges.bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", inset, inset)
  edges.bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
  edges.bottom:SetHeight(edgeSize)

  edges.left:ClearAllPoints()
  edges.left:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -sideInset)
  edges.left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", inset, sideInset)
  edges.left:SetWidth(edgeSize)

  edges.right:ClearAllPoints()
  edges.right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -inset, -sideInset)
  edges.right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, sideInset)
  edges.right:SetWidth(edgeSize)
end

local function EnsureEquippedBorderVisual(button, icon)
  local visual = button.__puiActionBarEquippedBorder
  if visual then
    return visual
  end

  local frame = CreateFrame("Frame", nil, button)
  frame:SetFrameLevel(button:GetFrameLevel() + 10)
  frame:EnableMouse(false)
  frame:SetAllPoints(icon or button)
  frame:Hide()

  visual = {
    frame = frame,
    outer = {
      top = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_OUTER_ALPHA),
      bottom = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_OUTER_ALPHA),
      left = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_OUTER_ALPHA),
      right = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_OUTER_ALPHA),
    },
    inner = {
      top = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_INNER_ALPHA),
      bottom = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_INNER_ALPHA),
      left = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_INNER_ALPHA),
      right = CreateEquippedBorderEdge(frame, EQUIPPED_BORDER_INNER_ALPHA),
    },
  }

  button.__puiActionBarEquippedBorder = visual
  return visual
end

local function LayoutEquippedBorderVisual(button)
  local visual = button.__puiActionBarEquippedBorder
  if not visual then
    return
  end

  local onePixel = Pixel.GetOnePixel()
  if visual.onePixel == onePixel then
    return
  end

  visual.onePixel = onePixel
  LayoutEquippedBorderRing(visual.outer, visual.frame, 0, onePixel)
  LayoutEquippedBorderRing(visual.inner, visual.frame, onePixel, onePixel)
end

local function ManagedEquippedBorderShown(border)
  local button = Core.equippedBorderButtons[border]
  if not button then
    return
  end

  border:SetAlpha(0)
  local visual = button.__puiActionBarEquippedBorder
  if visual then
    visual.frame:Show()
  end
end

local function ManagedEquippedBorderHidden(border)
  local button = Core.equippedBorderButtons[border]
  local visual = button and button.__puiActionBarEquippedBorder
  if visual then
    visual.frame:Hide()
  end
end

local function StyleManagedEquippedBorder(button, icon)
  local border = button.Border
  if not border then
    return
  end

  if not button.__puiActionBarEquippedBorderStyled then
    Core.equippedBorderButtons[border] = button
    hooksecurefunc(border, "Show", ManagedEquippedBorderShown)
    hooksecurefunc(border, "Hide", ManagedEquippedBorderHidden)
    button.__puiActionBarEquippedBorderStyled = true
  end

  border:SetAlpha(0)

  if button.__puiActionBarEquippedBorder then
    LayoutEquippedBorderVisual(button)
  elseif border:IsShown() and not InCombatLockdown() then
    EnsureEquippedBorderVisual(button, icon)
    LayoutEquippedBorderVisual(button)
  end

  if border:IsShown() then
    ManagedEquippedBorderShown(border)
  end
end

function Core:NormalizeButtonRegions(button)
  local name = button:GetName()
  local icon = button.icon or button.Icon or (name and _G[name .. "Icon"])
  local cooldown = button.cooldown or button.Cooldown or (name and _G[name .. "Cooldown"])
  local hotkey = button.HotKey or button.hotkey or (name and _G[name .. "HotKey"])
  local count = button.Count or button.count or (name and _G[name .. "Count"])
  local macro = button.Name or button.nameText or (name and _G[name .. "Name"])

  if not button.icon and icon then
    button.icon = icon
  end
  if not button.cooldown and cooldown then
    button.cooldown = cooldown
  end
  if not button.HotKey and hotkey then
    button.HotKey = hotkey
  end
  if not button.Count and count then
    button.Count = count
  end
  if not button.Name and macro then
    button.Name = macro
  end

  return icon
end

function Core:ApplyAuxiliaryFonts(button, skin)
  local hotkey = button.HotKey
  local count = button.Count
  local macro = button.Name

  if hotkey then
    hotkey:SetFont(self:ResolveFont(skin.hotkeyFontFace), Theme.ResolveFontSize(Clamp(skin.hotkeyFontSize, 6, 72), "actionBars"), skin.hotkeyFontOutline or "")
    hotkey:SetTextColor(unpack(skin.hotkeyFontColor))
    hotkey:SetAlpha(skin.showHotkeyText and 1 or 0)
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
  end

  if count then
    count:SetFont(self:ResolveFont(skin.chargeFontFace), Theme.ResolveFontSize(Clamp(skin.chargeFontSize, 6, 72), "actionBars"), skin.chargeFontOutline or "")
    count:SetTextColor(unpack(skin.chargeFontColor))
    count:SetAlpha(skin.showChargeText and 1 or 0)
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  end

  if macro then
    macro:SetFont(self:ResolveFont(skin.macroFontFace), Theme.ResolveFontSize(Clamp(skin.macroFontSize, 6, 72), "actionBars"), skin.macroFontOutline or "")
    macro:SetTextColor(unpack(skin.macroFontColor))
    macro:SetAlpha(skin.showMacroText and 1 or 0)
    macro:ClearAllPoints()
    macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
  end
end

function Core:ApplyCooldownAppearance(cooldown, skin, hideNumbers, swipeColor)
  if not cooldown or cooldown:IsForbidden() then
    return
  end

  local version = skin.version or 0
  local needsStyle = cooldown.__puiActionBarStyleVersion ~= version
  local needsDrawSwipe = cooldown.__puiActionBarDrawSwipe ~= true
  local needsSwipeColor = swipeColor
    and cooldown.__puiActionBarSwipeColor ~= swipeColor
  local needsHideNumbers = cooldown.__puiActionBarHideNumbers ~= hideNumbers

  if not needsStyle and not needsDrawSwipe and not needsSwipeColor and not needsHideNumbers then
    return
  end

  local parent = cooldown:GetParent()
  local protected = cooldown.IsProtected and cooldown:IsProtected()
  if not protected and parent and parent.IsProtected then
    protected = parent:IsProtected()
  end
  if InCombatLockdown() and protected then
    self:QueueCooldownStyle(cooldown, skin, hideNumbers, swipeColor)
    return
  end

  if needsStyle then
    IconSkin.SquareCooldown(cooldown)

    if skin.showCooldownText then
      IconSkin.QueueCooldownText(cooldown, {
        font = self:ResolveFont(skin.cooldownFontFace),
        size = Clamp(skin.cooldownFontSize, 6, 72),
        flags = skin.cooldownFontOutline or "",
        color = CopyColor(skin.cooldownFontColor, skin.fontColor),
        scope = "actionBars",
      })
    end

    cooldown.__puiActionBarStyleVersion = version
  end

  if needsDrawSwipe then
    cooldown.__puiActionBarDrawSwipe = true
    cooldown:SetDrawSwipe(true)
  end

  if needsSwipeColor then
    cooldown.__puiActionBarSwipeColor = swipeColor
    cooldown:SetSwipeColor(unpack(swipeColor))
  end

  if needsHideNumbers then
    cooldown.__puiActionBarHideNumbers = hideNumbers
    cooldown:SetHideCountdownNumbers(hideNumbers)
  end
end

function Core:ApplyButtonCooldownAppearance(button, skin)
  if not button or not skin then return end

  local showNumbers = skin.showCooldownText ~= false
  local chargeCooldown = button.chargeCooldown
  local chargeShown = chargeCooldown and chargeCooldown:IsShown() or false
  button.__puiActionBarChargeShown = chargeShown

  self:ApplyCooldownAppearance(button.cooldown, skin, (not showNumbers) or chargeShown)
  self:ApplyCooldownAppearance(chargeCooldown, skin, not showNumbers, CHARGE_SWIPE_COLOR)

  local lossOfControl = button.lossOfControlCooldown
  if lossOfControl then
    self:ApplyCooldownAppearance(lossOfControl, skin, true)
  end

end

function Core:ApplyButtonAppearance(button, skin)
  if not button or not skin then return end

  local icon = self:NormalizeButtonRegions(button)

  if not button.__puiActionBarStripped then
    button.__puiActionBarStripped = true

    HideRegion(button.SlotBackground)
    HideRegion(button.SlotArt)
    HideRegion(button.NormalTexture)
    HideRegion(button.NewActionTexture)
    HideRegion(button.SpellHighlightTexture)

    IconSkin.MakeIconSquare(button, { crop = 0.08 })
  end

  local visualVersion = skin.version or 0
  if button.__puiActionBarVisualVersion ~= visualVersion then
    button.__puiActionBarVisualVersion = visualVersion

    IconSkin.ApplyBorder(button, {
      thickness = math_max(0, tonumber(skin.borderSize) or 0),
      useThemeColor = false,
      colorOverride = skin.borderColor,
    })

    if icon then
      StyleButtonStateTextures(button, icon)
    end

    if button.__puiActionBarManaged then
      StyleManagedEquippedBorder(button, icon)
    elseif button.Border then
      HideRegion(button.Border)
    end

    self:ApplyAuxiliaryFonts(button, skin)
  end

  button.__puiActionBarSkin = skin
  self:ApplyButtonCooldownAppearance(button, skin)
end

function Core:CreateBar(key, frameName, moverKey, label, defaultPoint, dbKey)
  local existing = self.bars[key]
  if existing then
    return existing
  end

  local frame = CreateFrame("Frame", frameName, UIParent, "SecureHandlerStateTemplate")
  frame:SetFrameStrata("LOW")
  frame:SetFrameLevel(1)
  frame:SetClampedToScreen(true)
  frame.actionButtons = {}
  frame:SetAttributeNoHandler("_onstate-pui-empower", [[
    self:ChildUpdate("pui-empower", "")
  ]])

  local bar = {
    key = key,
    dbKey = dbKey or key,
    frame = frame,
    buttons = frame.actionButtons,
    moverKey = moverKey,
    label = label,
    defaultPoint = defaultPoint,
    enabled = true,
  }

  frame.__puiActionBarObject = bar
  self.bars[key] = bar
  return bar
end

function Core:IsBarEnabled(bar)
  if type(bar.enabled) == "function" then
    return bar.enabled(bar) ~= false
  end
  return bar.enabled ~= false
end

function Core:LayoutButtons(bar, skin, buttonCount, perRow)
  local frame = bar.frame
  local buttons = bar.buttons
  local size = math_max(1, Round(skin.iconSize))
  local spacing = math_max(0, Round(skin.iconSpacing))
  local paddingX = math_max(0, Round(PADDING_X))
  local paddingY = math_max(0, Round(PADDING_Y))
  local count = Clamp(buttonCount or skin.iconsPerBar or #buttons, 1, #buttons > 0 and #buttons or 1)
  local columns = Clamp(perRow or skin.iconsPerRow or count, 1, count)
  local rows = math_floor((count - 1) / columns) + 1
  local width = (columns * size) + ((columns - 1) * spacing) + (paddingX * 2)
  local height = (rows * size) + ((rows - 1) * spacing) + (paddingY * 2)

  frame:SetSize(width, height)

  for index, button in ipairs(buttons) do
    if index <= count then
      local column = (index - 1) % columns
      local row = math_floor((index - 1) / columns)
      button:ClearAllPoints()
      button:SetSize(size, size)
      button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        paddingX + (column * (size + spacing)),
        -paddingY - (row * (size + spacing))
      )
      button:SetAttribute("statehidden", nil)
      button:Show()
    else
      button:SetAttribute("statehidden", true)
      button:Hide()
    end
  end

  bar.visibleButtonCount = count
  self:ApplyBarPosition(bar)
end

function Core:ApplyBackdrop(bar, skin)
  local frame = bar.frame
  local backdrop = bar.backdrop

  if not backdrop then
    backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    backdrop:SetAllPoints(frame)
    backdrop:EnableMouse(false)

    local background = backdrop:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(backdrop)
    backdrop.background = background
    bar.backdrop = backdrop
  end

  if skin.showBarBackground == false then
    backdrop:Hide()
    return
  end

  local bg = skin.frameBgColor
  backdrop.background:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
  IconSkin.ApplyBorder(backdrop, {
    thickness = math_max(0, tonumber(skin.frameBorderSize) or 0),
    colorOverride = skin.frameBorderColor,
  })
  backdrop:Show()
end

function Core:GetMoverOptionsString(moverKey)
  local barNumber = tostring(moverKey):match("^ACTIONBAR_(%d+)$")
  if barNumber then
    return "ACTIONBARS," .. barNumber .. ",general"
  elseif moverKey == "ACTIONBAR_PET" then
    return "ACTIONBARS,special,pet"
  elseif moverKey == "ACTIONBAR_STANCE" then
    return "ACTIONBARS,special,stance"
  end
  return "ACTIONBARS"
end

function Core:GetDataBarLift()
  local dataBar = _G.PleebUI_DataBar
  if not (dataBar and dataBar.IsObjectType and dataBar:IsObjectType("Frame")) then
    return 0
  end
  return (tonumber(dataBar:GetHeight()) or 0) * (tonumber(dataBar:GetScale()) or 1)
end

function Core:ResolveDefaultPoint(defaultPoint)
  if type(defaultPoint) == "function" then
    defaultPoint = defaultPoint()
  end

  local point, relativeTo, relativePoint, x, y = unpack(defaultPoint or {})
  if type(relativeTo) == "string" then
    relativeTo = _G[relativeTo]
  end
  relativeTo = relativeTo or UIParent

  if relativeTo == UIParent and relativePoint == "BOTTOM" then
    y = (tonumber(y) or 0) + self:GetDataBarLift()
  end

  return point or "CENTER", relativeTo, relativePoint or "CENTER", tonumber(x) or 0, tonumber(y) or 0
end

function Core:GetSavedPoint(bar)
  local db = self:GetDB()
  local saved = db.movers[bar.moverKey]

  if saved then
    local relativeName = saved.relName or "UIParent"
    return saved.point or "CENTER", _G[relativeName] or UIParent, saved.relPoint or "CENTER", saved.xOfs or 0, saved.yOfs or 0
  end

  return self:ResolveDefaultPoint(bar.defaultPoint)
end

local HORIZONTAL_CENTER_POINTS = {
  TOP = true,
  CENTER = true,
  BOTTOM = true,
}

local VERTICAL_CENTER_POINTS = {
  LEFT = true,
  CENTER = true,
  RIGHT = true,
}

local function SnapActionBarAnchorOffset(value, frameSize, frameCentered, relativeSize, relativeCentered)
  local onePixel = Pixel.GetOnePixel()
  local valuePixels = (tonumber(value) or 0) / onePixel
  local framePixels = math_floor(((tonumber(frameSize) or 0) / onePixel) + 0.5)
  local relativePixels = math_floor(((tonumber(relativeSize) or 0) / onePixel) + 0.5)
  local frameHalfPixel = frameCentered and (framePixels % 2 == 1)
  local relativeHalfPixel = relativeCentered and (relativePixels % 2 == 1)

  if frameHalfPixel ~= relativeHalfPixel then
    return (math_floor(valuePixels) + 0.5) * onePixel
  end

  return math_floor(valuePixels + 0.5) * onePixel
end

local function SnapActionBarPoint(frame, point, relativeTo, relativePoint, x, y)
  local width, height = frame:GetSize()
  local relativeWidth, relativeHeight = relativeTo:GetSize()

  x = SnapActionBarAnchorOffset(
    x,
    width,
    HORIZONTAL_CENTER_POINTS[point] == true,
    relativeWidth,
    HORIZONTAL_CENTER_POINTS[relativePoint] == true
  )
  y = SnapActionBarAnchorOffset(
    y,
    height,
    VERTICAL_CENTER_POINTS[point] == true,
    relativeHeight,
    VERTICAL_CENTER_POINTS[relativePoint] == true
  )

  return x, y
end

function Core:ApplyBarPosition(bar)
  local point, relativeTo, relativePoint, x, y = self:GetSavedPoint(bar)
  x, y = SnapActionBarPoint(bar.frame, point, relativeTo, relativePoint, x, y)
  bar.frame:ClearAllPoints()
  bar.frame:SetPoint(point, relativeTo, relativePoint, x, y)
end

function Core:SaveMoverPosition(bar, moverFrame)
  local x, y = moverFrame:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if not x or not y or not parentX or not parentY then
    return
  end

  local xOfs, yOfs = SnapActionBarPoint(
    bar.frame,
    "CENTER",
    UIParent,
    "CENTER",
    x - parentX,
    y - parentY
  )

  local db = self:GetDB()
  db.movers[bar.moverKey] = {
    point = "CENTER",
    relName = "UIParent",
    relPoint = "CENTER",
    xOfs = xOfs,
    yOfs = yOfs,
  }

  self:ApplyBarPosition(bar)
end

function Core:RegisterMover(bar)
  if not bar.moverKey then
    return
  end

  if bar.mover then
    FrameUtil:RefreshGhostMover(bar.moverKey)
    return
  end

  local barKey = bar.dbKey

  local function GetCustomSkin()
    local db = self:GetDB()
    local override = db.overrides[barKey]
    if not override then
      override = {}
      db.overrides[barKey] = override
    end
    override.useCustom = true
    override.skin = override.skin or {}
    return override.skin
  end

  local function Refresh(flags)
    if STANDARD_BAR_KEYS[barKey]
      or barKey == "pet"
      or barKey == "stance"
      or barKey == "possess"
    then
      self:RefreshBar(barKey, flags)
    else
      self:RefreshAll(flags)
    end
  end

  local function BuildQuickSettings()
    local db = self:GetDB()
    local skin = self:GetEffectiveSkin(barKey, bar.defaultSize)

    local controls = {
      {
        type = "slider",
        label = "Button size",
        min = 16,
        max = 96,
        step = 1,
        get = function() return skin.iconSize end,
        set = function(value)
          GetCustomSkin().iconSize = Round(value)
          Refresh({ layout = true, skin = true })
        end,
      },
      {
        type = "slider",
        label = "Border size",
        min = 0,
        max = 10,
        step = 1,
        get = function() return skin.borderSize end,
        set = function(value)
          GetCustomSkin().borderSize = value
          Refresh({ skin = true })
        end,
      },
      {
        type = "toggle",
        label = "Show on mouseover",
        get = function() return skin.fadeOutEnabled end,
        set = function(value)
          GetCustomSkin().fadeOutEnabled = value == true
          Refresh({ alpha = true })
        end,
      },
      {
        type = "slider",
        label = "Hidden opacity",
        min = 0,
        max = 1,
        step = 0.05,
        get = function() return skin.fadeOutAlpha end,
        set = function(value)
          GetCustomSkin().fadeOutAlpha = value
          Refresh({ alpha = true })
        end,
      },
      {
        type = "slider",
        label = "Fade-out time",
        min = 0,
        max = 10,
        step = 0.5,
        get = function() return skin.fadeOutDuration end,
        set = function(value)
          GetCustomSkin().fadeOutDuration = value
          Refresh({ alpha = true })
        end,
      },
      {
        type = "toggle",
        label = "Show keybinds",
        get = function() return skin.showHotkeyText end,
        set = function(value)
          GetCustomSkin().showHotkeyText = value == true
          Refresh({ fonts = true })
        end,
      },
      {
        type = "slider",
        label = "Keybind font size",
        min = 6,
        max = 36,
        step = 1,
        get = function() return skin.hotkeyFontSize end,
        set = function(value)
          GetCustomSkin().hotkeyFontSize = Round(value)
          Refresh({ fonts = true })
        end,
      },
      {
        type = "toggle",
        label = "Show macro text",
        get = function() return skin.showMacroText end,
        set = function(value)
          GetCustomSkin().showMacroText = value == true
          Refresh({ fonts = true })
        end,
      },
      {
        type = "slider",
        label = "Macro font size",
        min = 6,
        max = 36,
        step = 1,
        get = function() return skin.macroFontSize end,
        set = function(value)
          GetCustomSkin().macroFontSize = Round(value)
          Refresh({ fonts = true })
        end,
      },
      {
        type = "slider",
        label = "Stack font size",
        min = 6,
        max = 36,
        step = 1,
        get = function() return skin.chargeFontSize end,
        set = function(value)
          GetCustomSkin().chargeFontSize = Round(value)
          Refresh({ fonts = true })
        end,
      },
    }

    if STANDARD_BAR_KEYS[barKey] or barKey == "pet" then
      table.insert(controls, 2, {
        type = "slider",
        label = barKey == "pet" and "Number of buttons" or "Buttons per bar",
        min = 1,
        max = barKey == "pet" and #bar.buttons or 12,
        step = 1,
        get = function()
          if barKey == "pet" then
            return db.bars.pet.buttonCount
          end

          local value = tonumber(skin.iconsPerBar) or 12
          if value < 1 then value = 1 end
          if value > 12 then value = 12 end
          return value
        end,
        set = function(value)
          if barKey == "pet" then
            db.bars.pet.buttonCount = Round(value)
            Refresh({ layout = true, visibility = true })
            return
          end

          local val = tonumber(value) or 12
          if val < 1 then val = 1 end
          if val > 12 then val = 12 end
          GetCustomSkin().iconsPerBar = val
          Addon:ApplyOptionsChange("ActionBars", {
            bars = {
              [barKey] = { layout = true },
            },
          })
        end,
      })
      table.insert(controls, 3, {
        type = "slider",
        label = "Buttons per row",
        min = 1,
        max = #bar.buttons,
        step = 1,
        get = function() return skin.iconsPerRow end,
        set = function(value)
          GetCustomSkin().iconsPerRow = Round(value)
          Refresh({ layout = true })
        end,
      })
    end

    if STANDARD_BAR_KEYS[barKey] then
      table.insert(controls, 1, {
        type = "toggle",
        label = "Show bar",
        get = function() return db.bars[barKey].enabled ~= false end,
        set = function(value)
          db.bars[barKey].enabled = value == true
          Refresh({ full = true, visibility = true, layout = true })
        end,
      })
    end

    return {
      ownerKey = bar.moverKey,
      title = bar.label or "Action Bar",
      description = "Live Action Bar settings.",
      controls = controls,
    }
  end

  bar.mover = FrameUtil:EnsureGhostMover(bar.moverKey, {
    frameName = bar.frame:GetName() .. "Mover",
    label = bar.label or bar.moverKey,
    ghost = false,
    useOverlayDrag = true,
    liveFrame = bar.frame,
    getSize = function(_, liveFrame)
      return liveFrame:GetSize()
    end,
    getPoint = function()
      return self:GetSavedPoint(bar)
    end,
    shouldShow = function()
      return ActionBar:IsEnabled() and ns.Flags.IsEditing and self:IsBarEnabled(bar)
    end,
    savePosition = function(moverFrame)
      self:SaveMoverPosition(bar, moverFrame)
    end,
    onDragStop = function()
      FrameUtil:RefreshGhostMover(bar.moverKey)
    end,
    resetPosition = function()
      local db = self:GetDB()
      db.movers[bar.moverKey] = nil
      self:ApplyBarPosition(bar)
      FrameUtil:RefreshGhostMover(bar.moverKey)
    end,
    optionsString = self:GetMoverOptionsString(bar.moverKey),
    quickSettings = BuildQuickSettings,
    smartSnap = STANDARD_BAR_KEYS[barKey] and {
      family = "actionBars",
      isRuntimeActive = function()
        return ActionBar:IsEnabled() and self:IsBarEnabled(bar)
      end,
      getSizeState = function()
        local effective = self:GetEffectiveSkin(barKey, bar.defaultSize)
        return {
          iconSize = effective.iconSize,
          iconSpacing = effective.iconSpacing,
        }
      end,
      copySizeFrom = function(sourceEntry)
        local sourceOptions = sourceEntry and sourceEntry.opts and sourceEntry.opts.smartSnap
        local sourceState = sourceOptions and type(sourceOptions.getSizeState) == "function"
          and sourceOptions.getSizeState(sourceEntry.frame, sourceEntry.key)
          or nil
        if not sourceState then
          return
        end

        local effective = self:GetEffectiveSkin(barKey, bar.defaultSize)
        local custom = GetCustomSkin()
        custom.iconSize = Round(sourceState.iconSize or effective.iconSize)
        custom.iconSpacing = Round(sourceState.iconSpacing or effective.iconSpacing)
        Refresh({ layout = true, skin = true })
      end,
      getDesign = function()
        local effective = self:GetEffectiveSkin(barKey, bar.defaultSize)
        return {
          borderSize = effective.borderSize,
          borderColor = CopyColor(effective.borderColor),
          frameBorderSize = effective.frameBorderSize,
          frameBorderColor = CopyColor(effective.frameBorderColor),
          frameBgColor = CopyColor(effective.frameBgColor),
          showBarBackground = effective.showBarBackground,
          alpha = effective.alpha,
          fadeOutEnabled = effective.fadeOutEnabled,
          fadeOutAlpha = effective.fadeOutAlpha,
          fadeOutDuration = effective.fadeOutDuration,
          showCooldownText = effective.showCooldownText,
          cooldownFontSize = effective.cooldownFontSize,
          showHotkeyText = effective.showHotkeyText,
          hotkeyFontSize = effective.hotkeyFontSize,
          showMacroText = effective.showMacroText,
          macroFontSize = effective.macroFontSize,
          showChargeText = effective.showChargeText,
          chargeFontSize = effective.chargeFontSize,
        }
      end,
      applyDesign = function(design)
        if type(design) ~= "table" then
          return
        end

        local custom = GetCustomSkin()
        custom.borderSize = design.borderSize
        custom.borderColor = CopyColor(design.borderColor)
        custom.frameBorderSize = design.frameBorderSize
        custom.frameBorderColor = CopyColor(design.frameBorderColor)
        custom.frameBgColor = CopyColor(design.frameBgColor)
        custom.showBarBackground = design.showBarBackground
        custom.alpha = design.alpha
        custom.fadeOutEnabled = design.fadeOutEnabled == true
        custom.fadeOutAlpha = design.fadeOutAlpha
        custom.fadeOutDuration = design.fadeOutDuration
        custom.showCooldownText = design.showCooldownText ~= false
        custom.cooldownFontSize = design.cooldownFontSize
        custom.showHotkeyText = design.showHotkeyText ~= false
        custom.hotkeyFontSize = design.hotkeyFontSize
        custom.showMacroText = design.showMacroText ~= false
        custom.macroFontSize = design.macroFontSize
        custom.showChargeText = design.showChargeText ~= false
        custom.chargeFontSize = design.chargeFontSize
        Refresh({ skin = true, alpha = true, fonts = true })
      end,
    } or (barKey == "pet" and {
      family = "actionBars",
      families = { unitFramesPet = true },
      syncAxis = "NONE",
      isRuntimeActive = function()
        return ActionBar:IsEnabled() and self:IsBarEnabled(bar)
      end,
    } or ((barKey == "stance" or barKey == "vehicleExit") and {
      family = "actionBars",
      syncAxis = "NONE",
      isRuntimeActive = function()
        return ActionBar:IsEnabled() and self:IsBarEnabled(bar)
      end,
    } or ((barKey == "extraAbility" or barKey == "zoneAbility") and {
      family = "positionOnly",
      syncAxis = "NONE",
      isRuntimeActive = function()
        return ActionBar:IsEnabled() and self:IsBarEnabled(bar)
      end,
    } or nil))),
  })
end

function Core:SetBarVisibilityDriver(bar, driver)
  if InCombatLockdown() then
    self:QueueRefresh({ visibility = true })
    return
  end

  local visibilityDriver = driver or (self:IsBarEnabled(bar) and "show" or "hide")
  if bar.visibilityDriver == visibilityDriver then
    return
  end

  UnregisterStateDriver(bar.frame, "visibility")
  RegisterStateDriver(bar.frame, "visibility", visibilityDriver)
  bar.visibilityDriver = visibilityDriver
end

function Core:ReassignBarBindings(bar, mapping)
  if InCombatLockdown() or not bar or not bar.frame then
    return
  end

  ClearOverrideBindings(bar.frame)
  if not mapping or not self:IsBarEnabled(bar) then
    return
  end

  for index, button in ipairs(bar.buttons) do
    local bindingAction = mapping:format(index)
    local buttonName = button:GetName()
    for keyIndex = 1, select("#", GetBindingKey(bindingAction)) do
      local key = select(keyIndex, GetBindingKey(bindingAction))
      if key and key ~= "" then
        SetOverrideBindingClick(bar.frame, false, key, buttonName, "LeftButton")
      end
    end
  end
end

function Core:RegisterSubsystem(key, subsystem)
  if not key or not subsystem then return end

  if not self.subsystems[key] then
    self.subsystemOrder[#self.subsystemOrder + 1] = key
  end

  subsystem.key = key
  subsystem.core = self
  self.subsystems[key] = subsystem
end

function Core:ForEachSubsystem(method, ...)
  for _, key in ipairs(self.subsystemOrder) do
    local subsystem = self.subsystems[key]
    local callback = subsystem and subsystem[method]
    if callback then
      callback(subsystem, ...)
    end
  end
end

local function SetCVarIfChanged(name, value)
  if GetCVar(name) ~= value then
    SetCVar(name, value)
  end
end

function Core:SyncCVars()
  SetCVarIfChanged("lockActionBars", self.lockActionBars ~= false and "1" or "0")
  SetCVarIfChanged("ActionButtonUseKeyDown", self.castOnKeyDown ~= false and "1" or "0")
  SetCVarIfChanged("alwaysShowActionBars", self.alwaysShowGrid ~= false and "1" or "0")
  SetCVarIfChanged("countdownForCooldowns", self.countdownForCooldowns ~= false and "1" or "0")
end


local function HideBlizzardActionFrame(frame, clearEvents)
  if not frame then
    return
  end

  if clearEvents then
    frame:UnregisterAllEvents()
  end

  if frame.system then
    frame.isShownExternal = nil
    local index = 42
    repeat
      if frame[index] == nil then
        frame[index] = nil
      end
      index = index + 1
    until issecurevariable(frame, "isShownExternal")
  end

  if frame.HideBase then
    frame:HideBase()
  else
    frame:Hide()
  end

  frame:SetParent(BLIZZARD_ACTION_BAR_HIDER)
end

local function HideBlizzardActionButton(button)
  if not button then
    return
  end

  button:Hide()
  button:UnregisterAllEvents()
  button:SetAttribute("statehidden", true)
  button.bar = nil
end

function Core:ApplyVehicleUIOwnership()
  if self.useBlizzardVehicleUI then
    _G.OverrideActionBar:SetParent(UIParent)
    if ActionBarController_GetCurrentActionBarState() ~= LE_ACTIONBAR_STATE_OVERRIDE then
      _G.OverrideActionBar:Hide()
    end
  else
    _G.OverrideActionBar:SetParent(BLIZZARD_ACTION_BAR_HIDER)
  end
end

function Core:HideBlizzardBars()
  if self.blizzardBarsHidden then
    return
  end

  HideBlizzardActionFrame(_G.MainActionBar, false)

  for _, frameName in ipairs(BLIZZARD_MULTI_BAR_FRAMES) do
    HideBlizzardActionFrame(_G[frameName], true)
  end

  for index = 1, 12 do
    for _, prefix in ipairs(BLIZZARD_ACTION_BUTTON_PREFIXES) do
      HideBlizzardActionButton(_G[prefix .. index])
    end
  end

  for _, frameName in ipairs(BLIZZARD_SPECIAL_BAR_FRAMES) do
    HideBlizzardActionFrame(_G[frameName], true)
  end

  self:ApplyVehicleUIOwnership()

  self.blizzardBarsHidden = true
end

function Core:ApplyBarAlpha(bar, useFade)
  bar.alphaFadeGroup:Stop()

  if self.actionGridShown
    or (self.spellUIForceAlpha and self.spellUIVisible)
  then
    bar.frame:SetAlpha(1)
    return
  end

  if bar.fadeOutEnabled and not bar.alphaHovered then
    if useFade and bar.fadeOutDuration > 0 and bar.alpha ~= bar.fadeOutAlpha then
      bar.frame:SetAlpha(bar.alpha)
      bar.alphaFadeGroup:Play()
    else
      bar.frame:SetAlpha(bar.fadeOutAlpha)
    end
    return
  end

  bar.frame:SetAlpha(bar.alpha)
end

function Core:SetActionGridShown(shown)
  shown = shown == true
  if self.actionGridShown == shown then
    return
  end

  self.actionGridShown = shown

  for _, bar in pairs(self.bars) do
    local buttons = bar.buttons
    if buttons then
      for _, button in ipairs(buttons) do
        if button.__puiActionActive and button.__puiHasAction ~= true then
          button:SetAlpha((self.alwaysShowGrid ~= false or shown) and 1 or 0)
        end
      end
    end
  end

  for _, bar in ipairs(self.alphaBars) do
    self:ApplyBarAlpha(bar, false)
  end
end

function Core:RefreshBarAlpha(bar, useFade)
  local skin = self:GetEffectiveSkin(bar.dbKey, bar.defaultSize)

  bar.alpha = skin.alpha
  bar.fadeOutAlpha = skin.fadeOutAlpha
  bar.fadeOutEnabled = skin.fadeOutEnabled
  bar.fadeOutDuration = skin.fadeOutDuration

  bar.alphaFadeAnimation:SetFromAlpha(bar.alpha)
  bar.alphaFadeAnimation:SetToAlpha(bar.fadeOutAlpha)
  bar.alphaFadeAnimation:SetDuration(bar.fadeOutDuration)

  self:ApplyBarAlpha(bar, useFade)
end

function Core:AttachAlphaHandlers(bar)
  if not bar.alphaHandlersAttached then
    bar.alphaHandlersAttached = true
    self.alphaBars[#self.alphaBars + 1] = bar
    bar.alphaHovered = false

    local fadeGroup = bar.frame:CreateAnimationGroup()
    fadeGroup:SetToFinalAlpha(true)

    local fadeAnimation = fadeGroup:CreateAnimation("Alpha")

    bar.alphaFadeGroup = fadeGroup
    bar.alphaFadeAnimation = fadeAnimation

    self:RefreshBarAlpha(bar, false)

    local function Enter()
      if bar.alphaHovered then
        return
      end

      bar.alphaHovered = true
      Core:ApplyBarAlpha(bar, false)
    end

    local function Leave()
      if not bar.alphaHovered then
        return
      end

      bar.alphaHovered = false
      Core:ApplyBarAlpha(bar, true)
    end

    local function Show()
      Core:ApplyBarAlpha(bar, false)
    end

    local function Hide()
      bar.alphaHovered = false
      fadeGroup:Stop()
    end

    Enter = P:Def("Core:AttachAlphaHandlers.Enter", Enter)
    Leave = P:Def("Core:AttachAlphaHandlers.Leave", Leave)
    Show = P:Def("Core:AttachAlphaHandlers.Show", Show)
    Hide = P:Def("Core:AttachAlphaHandlers.Hide", Hide)

    bar.frame:HookScript("OnEnter", Enter)
    bar.frame:HookScript("OnLeave", Leave)
    bar.frame:HookScript("OnShow", Show)
    bar.frame:HookScript("OnHide", Hide)
    bar.frame:SetMouseMotionEnabled(true)
    bar.frame:SetMouseClickEnabled(false)
  end

  for _, button in ipairs(bar.buttons or {}) do
    if not button.__puiActionBarMouseMotionPropagates then
      button.__puiActionBarMouseMotionPropagates = true
      button:SetPropagateMouseMotion(true)
    end
  end
end

function Core:UpdateSpellUIVisibility()
  local visible = PlayerSpellsFrame and PlayerSpellsFrame:IsShown() or false
  self.spellUIVisible = visible
  for _, bar in ipairs(self.alphaBars) do
    self:RefreshBarAlpha(bar, false)
  end
end

function Core:RegisterSpellUICallbacks()
  if self.spellUICallbacksRegistered then
    return
  end

  EventRegistry:RegisterCallback("PlayerSpellsFrame.OpenFrame", self.UpdateSpellUIVisibility, self)
  EventRegistry:RegisterCallback("PlayerSpellsFrame.CloseFrame", self.UpdateSpellUIVisibility, self)
  self.spellUICallbacksRegistered = true
end

local function MergeRefreshFlags(target, flags)
  flags = type(flags) == "table" and flags or { full = true }

  for key, value in pairs(flags) do
    if type(value) == "table" then
      local child = target[key]
      if type(child) ~= "table" then
        child = {}
        target[key] = child
      end
      MergeRefreshFlags(child, value)
    elseif value then
      target[key] = value
    end
  end
end

local function HasBarRefreshFlag(barRequests, refreshKey)
  if type(barRequests) ~= "table" then
    return false
  end

  for _, flags in pairs(barRequests) do
    if type(flags) == "table" and flags[refreshKey] then
      return true
    end
  end

  return false
end

function Core:RegisterCombatFlush()
  if self.combatFlushRegistered then
    return
  end

  ActionBar:RegisterEvent("PLAYER_REGEN_ENABLED", Core.DispatchEvent, Core)
  self.combatFlushRegistered = true
end

function Core:QueueRefresh(flags)
  MergeRefreshFlags(self.pendingRefreshFlags, flags)
  if not self.combatFlushRegistered then
    self:RegisterCombatFlush()
  end
end

function Core:QueueBindings()
  if self.pendingBindings then
    return
  end

  self.pendingBindings = true
  if not self.combatFlushRegistered then
    self:RegisterCombatFlush()
  end
end

function Core:QueueSubsystemRefresh(subsystemKey, refreshKey)
  local pending = self.pendingSubsystemRefreshes[subsystemKey]
  if not pending then
    pending = {}
    self.pendingSubsystemRefreshes[subsystemKey] = pending
  elseif pending[refreshKey] then
    return
  end

  pending[refreshKey] = true
  if not self.combatFlushRegistered then
    self:RegisterCombatFlush()
  end
end

function Core:QueueCooldownStyle(cooldown, skin, hideNumbers, swipeColor)
  local version = skin.version or 0
  local request = self.pendingCooldownStyles[cooldown]

  if request then
    if request.version == version
      and request.hideNumbers == hideNumbers
      and request.swipeColor == swipeColor
    then
      return
    end
  else
    request = {}
    self.pendingCooldownStyles[cooldown] = request
  end

  request.skin = skin
  request.version = version
  request.hideNumbers = hideNumbers
  request.swipeColor = swipeColor

  if not self.combatFlushRegistered then
    self:RegisterCombatFlush()
  end
end

function Core:FlushCombatWork()
  ActionBar:UnregisterEvent("PLAYER_REGEN_ENABLED")
  self.combatFlushRegistered = nil

  local refreshFlags = self.pendingRefreshFlags
  local pendingBindings = self.pendingBindings
  local subsystemRefreshes = self.pendingSubsystemRefreshes
  local cooldownStyles = self.pendingCooldownStyles

  self.pendingRefreshFlags = {}
  self.pendingBindings = nil
  self.pendingSubsystemRefreshes = {}
  self.pendingCooldownStyles = setmetatable({}, { __mode = "k" })

  if refreshFlags.full then
    self:RefreshAll(refreshFlags)
    return
  end

  if next(refreshFlags) then
    self:RefreshAll(refreshFlags)
  end

  for subsystemKey, pending in pairs(subsystemRefreshes) do
    local subsystem = self.subsystems[subsystemKey]
    if subsystem and subsystem.RefreshDeferred then
      subsystem:RefreshDeferred(pending)
    end
  end

  if pendingBindings and not refreshFlags.bindings then
    self:UpdateBindings()
  end

  local barRequests = refreshFlags.bars
  if not refreshFlags.skin
    and not refreshFlags.fonts
    and not HasBarRefreshFlag(barRequests, "full")
    and not HasBarRefreshFlag(barRequests, "skin")
    and not HasBarRefreshFlag(barRequests, "fonts")
  then
    for cooldown, request in pairs(cooldownStyles) do
      self:ApplyCooldownAppearance(cooldown, request.skin, request.hideNumbers, request.swipeColor)
    end
  end

  IconSkin.ProcessFontQueue()

end

function Core:RefreshBar(barKey, flags)
  flags = type(flags) == "table" and flags or { full = true }
  self:InvalidateBarCache(barKey, flags)

  if STANDARD_BAR_KEYS[barKey] then
    self.subsystems.standard:RefreshBar(barKey, flags)
  elseif barKey == "pet" then
    self.subsystems.pet:Refresh(flags)
  elseif barKey == "stance" then
    self.subsystems.stance:Refresh(flags)
  else
    return
  end

  for _, bar in pairs(self.bars) do
    if bar.dbKey == barKey then
      if flags.full or flags.layout or flags.visibility then
        FrameUtil:RefreshGhostMover(bar.moverKey)
      end
      if STANDARD_BAR_KEYS[barKey] then
        FrameUtil.RefreshSmartSnapState(bar.moverKey)
      end
      break
    end
  end
end

function Core:RefreshAll(flags)
  flags = type(flags) == "table" and flags or { full = true }

  if InCombatLockdown() then
    self:QueueRefresh(flags)
    return
  end

  if flags.worldState and not flags.full then
    self:ReconcileWorldState()
  end

  if flags.profile then
    self:PrepareProfile()
  elseif flags.full or flags.cvars or flags.tooltips then
    self:RefreshRuntimeSettings()
  end

  self:InvalidateCaches(flags)

  if flags.full or flags.alpha then
    self.spellUIVisible = PlayerSpellsFrame and PlayerSpellsFrame:IsShown() or false
  end

  if flags.full or flags.cvars then
    self:SyncCVars()
  end

  if flags.full then
    self:ApplyVehicleUIOwnership()
  end

  local hasGlobalRefresh = flags.full
    or flags.cvars
    or flags.fonts
    or flags.skin
    or flags.layout
    or flags.visibility
    or flags.alpha
    or flags.bindings

  if hasGlobalRefresh then
    self:ForEachSubsystem("Refresh", flags)
  end

  local barRequests = flags.bars
  if not flags.full and type(barRequests) == "table" then
    for barKey, barFlags in pairs(barRequests) do
      self:RefreshBar(barKey, barFlags)
    end
  end

  if flags.full or flags.tooltips then
    ns.ActionButtonEngine:RefreshTooltipPolicy()
  end


  if flags.pixelGeometry then
    for _, bar in pairs(self.bars) do
      self:ApplyBarPosition(bar)
    end
  end

  if flags.full or flags.layout or flags.visibility then
    FrameUtil:RefreshAllGhostMovers()
  end

  if (flags.full
      or flags.fonts
      or flags.skin
      or HasBarRefreshFlag(barRequests, "full")
      or HasBarRefreshFlag(barRequests, "fonts")
      or HasBarRefreshFlag(barRequests, "skin"))
  then
    IconSkin.ProcessFontQueue()
  end

  if flags.full then
    self.runtimeInitialized = true
  end
end

function Core:ReconcileWorldState()
  if InCombatLockdown() then
    self:QueueRefresh({ worldState = true })
    return
  end

  self:ForEachSubsystem("ReconcileWorldState")
end

function Core:UpdateBindings()
  if InCombatLockdown() then
    self:QueueBindings()
    return
  end

  self:ForEachSubsystem("UpdateBindings")
end

function Core:DispatchEvent(event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:FlushCombatWork()
    return
  end

  if event == "UPDATE_BINDINGS" or event == "GAME_PAD_ACTIVE_CHANGED" then
    self:UpdateBindings()
    return
  end

  if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
    self:SetActionGridShown(event == "ACTIONBAR_SHOWGRID")
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if self.runtimeInitialized then
      self:ReconcileWorldState()
    else
      self:RefreshAll({ full = true })
    end
  end
end

local function ActionBarScaleChanged()
  if Core.runtimeInitialized then
    Core:RefreshAll({ skin = true, layout = true, pixelGeometry = true })
  end
end

function Core:DisableAll()
  self:ForEachSubsystem("Disable")

  for _, bar in ipairs(self.alphaBars) do
    bar.alphaHovered = false
    bar.alphaFadeGroup:Stop()
  end

  FrameUtil:RefreshAllGhostMovers()
end

function ActionBar:OnInitialize()
  Core:PrepareProfile()
  Core:HideBlizzardBars()
end

function ActionBar:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", Core.DispatchEvent, Core)
  self:RegisterEvent("UPDATE_BINDINGS", Core.DispatchEvent, Core)
  self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED", Core.DispatchEvent, Core)
  self:RegisterEvent("ACTIONBAR_SHOWGRID", Core.DispatchEvent, Core)
  self:RegisterEvent("ACTIONBAR_HIDEGRID", Core.DispatchEvent, Core)

  Core:RegisterSpellUICallbacks()
  ns.ActionButtonEngine:Enable()
  FrameScale:RegisterScaleListener(ActionBarScaleChanged)

  Core:RefreshAll({ full = true })
end

function ActionBar:OnDisable()
  self:UnregisterAllEvents()
  FrameScale:UnregisterScaleListener(ActionBarScaleChanged)

  Core:DisableAll()
  ns.ActionButtonEngine:Disable()

  Core.runtimeInitialized = nil
  Core.pendingRefreshFlags = {}
  Core.pendingBindings = nil
  Core.combatFlushRegistered = nil
  Core.pendingSubsystemRefreshes = {}
  Core.pendingCooldownStyles = setmetatable({}, { __mode = "k" })
  Core.actionGridShown = nil

  if Core.spellUICallbacksRegistered then
    EventRegistry:UnregisterCallback("PlayerSpellsFrame.OpenFrame", Core)
    EventRegistry:UnregisterCallback("PlayerSpellsFrame.CloseFrame", Core)
    Core.spellUICallbacksRegistered = nil
  end
end

Core.GetDB = P:Def("Core:GetDB", Core.GetDB)
Core.ShouldShowActionTooltip = P:Def("Core:ShouldShowActionTooltip", Core.ShouldShowActionTooltip)
Core.PrepareProfile = P:Def("Core:PrepareProfile", Core.PrepareProfile)
Core.RefreshRuntimeSettings = P:Def("Core:RefreshRuntimeSettings", Core.RefreshRuntimeSettings)
Core.InvalidateCaches = P:Def("Core:InvalidateCaches", Core.InvalidateCaches)
Core.InvalidateBarCache = P:Def("Core:InvalidateBarCache", Core.InvalidateBarCache)
Core.GetEffectiveSkin = P:Def("Core:GetEffectiveSkin", Core.GetEffectiveSkin)
Core.GetSpecialSkin = P:Def("Core:GetSpecialSkin", Core.GetSpecialSkin)
Core.ResolveFont = P:Def("Core:ResolveFont", Core.ResolveFont)
Core.NormalizeButtonRegions = P:Def("Core:NormalizeButtonRegions", Core.NormalizeButtonRegions)
Core.ApplyAuxiliaryFonts = P:Def("Core:ApplyAuxiliaryFonts", Core.ApplyAuxiliaryFonts)
Core.ApplyCooldownAppearance = P:Def("Core:ApplyCooldownAppearance", Core.ApplyCooldownAppearance)
Core.ApplyButtonCooldownAppearance = P:Def("Core:ApplyButtonCooldownAppearance", Core.ApplyButtonCooldownAppearance)
Core.ApplyButtonAppearance = P:Def("Core:ApplyButtonAppearance", Core.ApplyButtonAppearance)
Core.CreateBar = P:Def("Core:CreateBar", Core.CreateBar)
Core.IsBarEnabled = P:Def("Core:IsBarEnabled", Core.IsBarEnabled)
Core.LayoutButtons = P:Def("Core:LayoutButtons", Core.LayoutButtons)
Core.ApplyBackdrop = P:Def("Core:ApplyBackdrop", Core.ApplyBackdrop)
Core.GetMoverOptionsString = P:Def("Core:GetMoverOptionsString", Core.GetMoverOptionsString)
Core.GetDataBarLift = P:Def("Core:GetDataBarLift", Core.GetDataBarLift)
Core.ResolveDefaultPoint = P:Def("Core:ResolveDefaultPoint", Core.ResolveDefaultPoint)
Core.GetSavedPoint = P:Def("Core:GetSavedPoint", Core.GetSavedPoint)
Core.ApplyBarPosition = P:Def("Core:ApplyBarPosition", Core.ApplyBarPosition)
Core.SaveMoverPosition = P:Def("Core:SaveMoverPosition", Core.SaveMoverPosition)
Core.RegisterMover = P:Def("Core:RegisterMover", Core.RegisterMover)
Core.SetBarVisibilityDriver = P:Def("Core:SetBarVisibilityDriver", Core.SetBarVisibilityDriver)
Core.ReassignBarBindings = P:Def("Core:ReassignBarBindings", Core.ReassignBarBindings)
Core.RegisterSubsystem = P:Def("Core:RegisterSubsystem", Core.RegisterSubsystem)
Core.ForEachSubsystem = P:Def("Core:ForEachSubsystem", Core.ForEachSubsystem)
Core.SyncCVars = P:Def("Core:SyncCVars", Core.SyncCVars)
Core.ApplyVehicleUIOwnership = P:Def("Core:ApplyVehicleUIOwnership", Core.ApplyVehicleUIOwnership)
Core.HideBlizzardBars = P:Def("Core:HideBlizzardBars", Core.HideBlizzardBars)
Core.ApplyBarAlpha = P:Def("Core:ApplyBarAlpha", Core.ApplyBarAlpha)
Core.SetActionGridShown = P:Def("Core:SetActionGridShown", Core.SetActionGridShown)
Core.RefreshBarAlpha = P:Def("Core:RefreshBarAlpha", Core.RefreshBarAlpha)
Core.AttachAlphaHandlers = P:Def("Core:AttachAlphaHandlers", Core.AttachAlphaHandlers)
Core.UpdateSpellUIVisibility = P:Def("Core:UpdateSpellUIVisibility", Core.UpdateSpellUIVisibility)
Core.RegisterSpellUICallbacks = P:Def("Core:RegisterSpellUICallbacks", Core.RegisterSpellUICallbacks)
MergeRefreshFlags = P:Def("MergeRefreshFlags", MergeRefreshFlags)
HasBarRefreshFlag = P:Def("HasBarRefreshFlag", HasBarRefreshFlag)
Core.RegisterCombatFlush = P:Def("Core:RegisterCombatFlush", Core.RegisterCombatFlush)
Core.QueueRefresh = P:Def("Core:QueueRefresh", Core.QueueRefresh)
Core.QueueBindings = P:Def("Core:QueueBindings", Core.QueueBindings)
Core.QueueSubsystemRefresh = P:Def("Core:QueueSubsystemRefresh", Core.QueueSubsystemRefresh)
Core.QueueCooldownStyle = P:Def("Core:QueueCooldownStyle", Core.QueueCooldownStyle)
Core.FlushCombatWork = P:Def("Core:FlushCombatWork", Core.FlushCombatWork)
Core.RefreshBar = P:Def("Core:RefreshBar", Core.RefreshBar)
Core.RefreshAll = P:Def("Core:RefreshAll", Core.RefreshAll)
Core.ReconcileWorldState = P:Def("Core:ReconcileWorldState", Core.ReconcileWorldState)
Core.UpdateBindings = P:Def("Core:UpdateBindings", Core.UpdateBindings)
Core.DispatchEvent = P:Def("Core:DispatchEvent", Core.DispatchEvent)
Core.DisableAll = P:Def("Core:DisableAll", Core.DisableAll)
ActionBar.OnInitialize = P:Def("ActionBar:OnInitialize", ActionBar.OnInitialize)
ActionBar.OnEnable = P:Def("ActionBar:OnEnable", ActionBar.OnEnable)
ActionBar.OnDisable = P:Def("ActionBar:OnDisable", ActionBar.OnDisable)
Clamp = P:Def("Clamp", Clamp)
NormalizeFlyoutDirection = P:Def("NormalizeFlyoutDirection", NormalizeFlyoutDirection)
NormalizeTooltipMode = P:Def("NormalizeTooltipMode", NormalizeTooltipMode)
CopyColor = P:Def("CopyColor", CopyColor)
PickField = P:Def("PickField", PickField)
PickFontFace = P:Def("PickFontFace", PickFontFace)
SetCVarIfChanged = P:Def("SetCVarIfChanged", SetCVarIfChanged)
HideBlizzardActionFrame = P:Def("HideBlizzardActionFrame", HideBlizzardActionFrame)
HideBlizzardActionButton = P:Def("HideBlizzardActionButton", HideBlizzardActionButton)
HideRegion = P:Def("HideRegion", HideRegion)
StyleButtonStateTexture = P:Def("StyleButtonStateTexture", StyleButtonStateTexture)
StyleButtonStateTextures = P:Def("StyleButtonStateTextures", StyleButtonStateTextures)
CreateEquippedBorderEdge = P:Def("CreateEquippedBorderEdge", CreateEquippedBorderEdge)
LayoutEquippedBorderRing = P:Def("LayoutEquippedBorderRing", LayoutEquippedBorderRing)
EnsureEquippedBorderVisual = P:Def("EnsureEquippedBorderVisual", EnsureEquippedBorderVisual)
LayoutEquippedBorderVisual = P:Def("LayoutEquippedBorderVisual", LayoutEquippedBorderVisual)
ManagedEquippedBorderShown = P:Def("ManagedEquippedBorderShown", ManagedEquippedBorderShown)
ManagedEquippedBorderHidden = P:Def("ManagedEquippedBorderHidden", ManagedEquippedBorderHidden)
StyleManagedEquippedBorder = P:Def("StyleManagedEquippedBorder", StyleManagedEquippedBorder)
SnapActionBarAnchorOffset = P:Def("SnapActionBarAnchorOffset", SnapActionBarAnchorOffset)
SnapActionBarPoint = P:Def("SnapActionBarPoint", SnapActionBarPoint)
ActionBarScaleChanged = P:Def("ActionBarScaleChanged", ActionBarScaleChanged)

Core.PADDING_X = PADDING_X
Core.PADDING_Y = PADDING_Y
