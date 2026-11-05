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

    experienceBar = {
      enabled = false,
      width = 500,
      height = 14,
      fillColor = { 0.56, 0.36, 0.82, 1 },
      restedColor = { 0.20, 0.47, 0.82, 0.65 },
      showTicks = false,
      text = "blizzard",
    },

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

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledActionBars",
  IsActionBarsAddonChangeBlocked,
  function() Addon:SetActionBarsAddonEnabled(true) end
)

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
