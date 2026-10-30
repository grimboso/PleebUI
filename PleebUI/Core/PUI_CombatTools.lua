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

  self.db.profile.childAddons.PleebUI_CombatTools = enabled == true
  self:ApplyChildAddonProfile()
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
        desc = "Enable Combat Tools for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsCombatToolsAddonChangeBlocked,
        func = function()
          Addon:SetCombatToolsAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledCombatTools",
  IsCombatToolsAddonChangeBlocked,
  function() Addon:SetCombatToolsAddonEnabled(true) end
)

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
      desc = "Disable Combat Tools for this profile and reload the UI. Your settings are kept.",
      disabled = InCombatLockdown,
      func = function() Addon:SetCombatToolsAddonEnabled(false) end,
    } },
  }
end
