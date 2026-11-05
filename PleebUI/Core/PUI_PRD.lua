local _, ns = ...

local Addon = ns.Addon

ns.PRDDefaults = {
  profile = {
    enabled = true,
    locked  = false,

    anchor = {
      point    = "CENTER",
      rel      = "UIParent",
      relPoint = "CENTER",
      x        = 0,
      y        = -250,
    },


    size = {
      width = 250,
      gap   = 0,
      spacingByPair = {},
    },

    appearance = {
      unified       = true,
      height        = 15,
      texture       = "Pleebar",
      squareTexture = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      text = {
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
    },

    outerBorder = {
      enabled = false,
      size = 1,
      color = { 0.20, 0.20, 0.24, 1.00 },
    },

    health = {
      height                 = 15,
      texture                = "Pleebar",
      squareTexture          = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      text = {
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
      colorMode              = "DEFAULT",
      useCustomColor         = false,
      useBlizzardHealthColor = true,
      customColor            = { 1, 1, 1, 1 },
    },

    hideHealth  = false,
    hidePrimary = false,
    showSwingTimer = false,
    swingTimer = {
      height = 8,
      detached = false,
      width = 250,
      anchor = { point = "CENTER", x = 0, y = -285 },
      texture = "Pleebar",
      mainHandColor = { 0.90, 0.66, 0.28, 1 },
      offHandColor = { 0.72, 0.48, 0.24, 1 },
      rangedColor = { 0.35, 0.75, 0.45, 1 },
      borderSize = 1,
      borderColor = { 0.20, 0.20, 0.24, 1 },
      showCountdown = false,
      fontSize = 10,
      showWindup = true,
      windupLead = 0.5,
    },
    usePlayerHealth = false,
    stackOrder = { "health", "primary" },

    primary = {
      height                 = 15,
      texture                = "Pleebar",
      squareTexture          = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      detached              = false,
      hideAlternateMana     = false,
      colorMode             = "DEFAULT",
      useCustomColor        = false,
      useBlizzardPowerColor = true,
      customColor           = { 1, 1, 1, 1 },
      resourceSettings = {},

      anchor = {

        point = "CENTER",
        x     = 0,
        y     = -250,
      },
      width = nil,
    },

    secondary = {
      detached              = false,
      height                = 15,
      perSegment            = false,
      texture               = "Pleebar",
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      useCustomColor        = false,
      useBlizzardPowerColor = true,
      customColor           = { 1, 1, 1, 1 },
      resourceSettings      = {},
      inactiveAlpha         = 0.15,
      showDividers          = true,
      dividerSize           = 1,
      dividerColor          = { 0.20, 0.20, 0.24, 1.00 },
      gap       = 2,

      anchor = {
        point = "CENTER",
        x     = 0,
        y     = -230,
      },
      width = nil,
    },

    text = {
      health = {
        leftVisibility = "ALWAYS",
        rightVisibility = "HIDE",
        centerText = true,
        left = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
        right = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
      },
      secondary = {
        mode = "CUR",
        showNumber = true,
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
    },
    class = {
      DRUID = {
        forms = {
          CAT     = { primary = {} },
          BEAR    = { primary = {} },
          MOONKIN = { primary = {} },
          CASTER  = { primary = {} },
        },
      },
    },
  },
  char = {
    __puiSeededHidePrimaryBySpec = false,
  },
}

local DisabledPRD = {}

local function IsPRDAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_PRD")
end

function Addon:SetPRDAddonEnabled(enabled)
  if IsPRDAddonChangeBlocked() then
    return
  end

  self.db.profile.childAddons.PleebUI_PRD = enabled == true
  self:ApplyChildAddonProfile()
end

function DisabledPRD:GetOptions()
  return {
    type = "group",
    name = "Resource Display",
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
        desc = "Enable Resource Display for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsPRDAddonChangeBlocked,
        func = function()
          Addon:SetPRDAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledPRD",
  IsPRDAddonChangeBlocked,
  function() Addon:SetPRDAddonEnabled(true) end
)

local record = Addon:RegisterOptionsSection("PRD", function()
  return DisabledPRD
end, 40, "Personal Resource Display", nil, {
  preview = false,
})
record.resolveOptionsPath = function()
  return { "PRD" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}
