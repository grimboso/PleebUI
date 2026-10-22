local _, ns = ...

local Addon = ns.Addon

ns.ActionBarsDefaults = {
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

local DisabledActionBars = {}

local function IsActionBarsAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_ActionBars")
end

function Addon:SetActionBarsAddonEnabled(enabled)
  if IsActionBarsAddonChangeBlocked() then
    return
  end

  self.db.profile.childAddons.PleebUI_ActionBars = enabled == true
  self:ApplyChildAddonProfile()
end

function DisabledActionBars:GetOptions()
  return {
    type = "group",
    name = "Action bars",
    arg = { puiExplicit = true },
    args = {
      disabled = {
        type = "description",
        name = "|cff808080Addon disabled|r",
        order = 1,
      },
      enableAddon = {
        type = "execute",
        name = "Enable addon and reload",
        desc = "Enable Action Bars for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsActionBarsAddonChangeBlocked,
        func = function()
          Addon:SetActionBarsAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsActionBarsAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledActionBars
  if not panel then
    panel = CreateFrame("Frame", nil, host)
    panel:Hide()
    panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.text.__puiOptionsFontOwned = true
    panel.text:SetPoint("CENTER", panel, "CENTER", 0, 22)
    panel.text:SetText("Addon disabled")
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetText("Enable addon and reload")
    button:SetPoint("TOP", panel.text, "BOTTOM", 0, -16)
    button:SetScript("OnClick", function()
      Addon:SetActionBarsAddonEnabled(true)
    end)
    panel.enableButton = button
    panel:SetScript("OnShow", function(self)
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      RefreshEnableButton(self)
    end)
    panel:SetScript("OnHide", function(self)
      self:UnregisterAllEvents()
    end)
    panel:SetScript("OnEvent", RefreshEnableButton)
    host.__puiDisabledActionBars = panel
  end

  panel:SetParent(host)
  panel:ClearAllPoints()
  panel:SetAllPoints(host)
  local colors = ns.Theme.GetColors()
  ns.Theme.SetSquareBackdrop(panel, { bg = colors.disabledControl, border = colors.disabledBorder }, ns.Theme.GetEdgeSize())
  ns.Theme.ApplyFont(panel.text, "body", 14)
  local text = colors.disabledText
  panel.text:SetTextColor(text[1], text[2], text[3], text[4])
  panel:SetAlpha(1)
  ns.Theme.WidgetSkins.UIButton(panel.enableButton)
  panel.enableButton:SetSize(
    math.max(250, math.ceil(panel.enableButton:GetFontString():GetUnboundedStringWidth()) + 30),
    ns.Theme.GetOptionsPointerTargetSize(34)
  )
  RefreshEnableButton(panel)
  return panel
end

local record = Addon:RegisterOptionsSection("ACTIONBARS", function()
  return DisabledActionBars
end, 30, "Action bars")
record.resolveOptionsPath = function()
  return { "ACTIONBARS" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}
