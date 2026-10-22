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

  local character = UnitNameUnmodified("player")
  if enabled then
    C_AddOns.EnableAddOn("PleebUI_PRD", character)
  else
    C_AddOns.DisableAddOn("PleebUI_PRD", character)
  end
  ReloadUI()
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
        desc = "Enable Resource Display for this character and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsPRDAddonChangeBlocked,
        func = function()
          Addon:SetPRDAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsPRDAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledPRD
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
      Addon:SetPRDAddonEnabled(true)
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
    host.__puiDisabledPRD = panel
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
