local _, ns = ...

local Addon = ns.Addon

local DisabledCombatTools = { name = "Combat Tools" }

local function IsCombatToolsAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_CombatTools")
end

function Addon:SetCombatToolsAddonEnabled(enabled)
  if IsCombatToolsAddonChangeBlocked() then
    return
  end

  local character = UnitNameUnmodified("player")
  if enabled then
    C_AddOns.EnableAddOn("PleebUI_CombatTools", character)
  else
    C_AddOns.DisableAddOn("PleebUI_CombatTools", character)
  end
  ReloadUI()
end

function DisabledCombatTools:GetOptions()
  return {
    type = "group",
    name = self.name,
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
        desc = "Enable Combat Tools for this character and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsCombatToolsAddonChangeBlocked,
        func = function()
          Addon:SetCombatToolsAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsCombatToolsAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledCombatTools
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
      Addon:SetCombatToolsAddonEnabled(true)
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
    host.__puiDisabledCombatTools = panel
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

ns.CombatToolsDisabledOptions = DisabledCombatTools
ns.CombatToolsDisabledPage = { ownsHeader = true, build = BuildDisabledPage, refresh = BuildDisabledPage }
for _, tab in ipairs({ { "combatTab", "Combat", 1 }, { "cursorTab", "Position indicators", 2 }, { "groupTab", "Group tools", 3 }, { "MovementWarning", "Movement Reminder", 3 } }) do
  local provider = { name = tab[2], GetOptions = DisabledCombatTools.GetOptions }
  local record = Addon:RegisterOptionsSection(tab[1], function() return provider end, tab[3], tab[2], "Quality")
  record.customPage = ns.CombatToolsDisabledPage
end

function Addon:GetCombatToolsAddonControl()
  return {
    type = "group", name = function() return "" end, inline = true, order = -10,
    arg = { puiExplicit = true },
    args = { disableAddon = {
      type = "execute", name = "Disable addon and reload", order = 1,
      desc = "Disable Combat Tools for this character and reload the UI. Your settings are kept.",
      disabled = InCombatLockdown,
      func = function() Addon:SetCombatToolsAddonEnabled(false) end,
    } },
  }
end
