local _, ns = ...

local Addon = ns.Addon

ns.PlayerBuffsDefaults = {
  enabled = true,
  buffs = {
    iconSize = 30,
    textSize = 12,
    fontOutline = "OUTLINE",
    borderSize = 1,
    anchor = {
      moved = false,
      x = 0,
      y = 0,
    },
  },
  debuffs = {
    iconSize = 30,
    textSize = 12,
    fontOutline = "OUTLINE",
    borderSize = 1,
    anchor = {
      moved = false,
      x = 0,
      y = 0,
    },
  },
}



local DisabledPlayerBuffs = {}

local function IsPlayerBuffsAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_PlayerBuffs")
end

function Addon:SetPlayerBuffsAddonEnabled(enabled)
  if IsPlayerBuffsAddonChangeBlocked() then
    return
  end

  self.db.profile.childAddons.PleebUI_PlayerBuffs = enabled == true
  self:ApplyChildAddonProfile()
end

function DisabledPlayerBuffs:GetOptions()
  return {
    type = "group",
    name = "Player Buffs",
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
        desc = "Enable Player Buffs for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsPlayerBuffsAddonChangeBlocked,
        func = function()
          Addon:SetPlayerBuffsAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsPlayerBuffsAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledPlayerBuffs
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
      Addon:SetPlayerBuffsAddonEnabled(true)
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
    host.__puiDisabledPlayerBuffs = panel
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

local record = Addon:RegisterOptionsSection("PLAYER_BUFFS", function()
  return DisabledPlayerBuffs
end, 32, "Player Buffs")
record.resolveOptionsPath = function()
  return { "PLAYER_BUFFS" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}

function Addon:GetPlayerBuffsAddonControl()
  return {
    type = "group", name = function() return "" end, inline = true, order = -10,
    arg = { puiExplicit = true },
    args = { disableAddon = {
      type = "execute", name = "Disable addon and reload", order = 1,
      desc = "Disable Player Buffs for this profile and reload the UI. Your settings are kept.",
      disabled = InCombatLockdown,
      func = function() Addon:SetPlayerBuffsAddonEnabled(false) end,
    } },
  }
end
