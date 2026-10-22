local _, ns = ...

local Addon = ns.Addon

ns.DamageMetersDefaults = {
  profile = {
    enabled = true,
    visible = true,
    windowCount = 1,
    refreshRate = 1,
    headerHeight = 30,
    barHeight = 20,
    barSpacing = 2,
    fontSize = 11,
    barAlpha = 0.82,
    showSpecIcons = true,
    history = {
      saveBossKills = true,
      bossKillsToKeep = 15,
      saveKeystones = true,
      dungeonSummariesToKeep = 10,
    },
    breakdown = {
      position = "AUTO",
      width = 360,
      height = 260,
      targetHeight = 150,
      x = 0,
      y = 0,
      showIcons = true,
      amounts = "BOTH",
      showPercent = true,
      maxSpells = 20,
      showSpellTooltips = true,
    },
    minimap = {
      hide = false,
      minimapPos = 250,
    },
    windows = {
      [1] = {
        meter = "DAMAGE_DONE",
        session = "CURRENT",
        syncSegments = false,
        autoCurrentOnCombat = false,
        locked = true,
        shown = true,
        width = 320,
        height = 180,
        x = 420,
        y = -250,
      },
    },
  },
  char = {
    history = {
      savedSegments = {},
      savedDungeons = {},
      nextRecordID = 0,
    },
  },
}

local DisabledDamageMeters = {}

local function IsDamageMetersAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_DamageMeters")
end

function Addon:SetDamageMetersAddonEnabled(enabled)
  if IsDamageMetersAddonChangeBlocked() then
    return
  end

  local character = UnitNameUnmodified("player")
  if enabled then
    C_AddOns.EnableAddOn("PleebUI_DamageMeters", character)
  else
    C_AddOns.DisableAddOn("PleebUI_DamageMeters", character)
  end
  ReloadUI()
end

function DisabledDamageMeters:GetOptions()
  return {
    type = "group",
    name = "Damage Meters",
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
        desc = "Enable Damage Meters for this character and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsDamageMetersAddonChangeBlocked,
        func = function()
          Addon:SetDamageMetersAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsDamageMetersAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledDamageMeters
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
      Addon:SetDamageMetersAddonEnabled(true)
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
    host.__puiDisabledDamageMeters = panel
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

local record = Addon:RegisterOptionsSection("DamageMeters", function()
  return DisabledDamageMeters
end, 55, "Damage Meters", nil, {
  preview = false,
})
record.resolveOptionsPath = function()
  return { "DamageMeters" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}
