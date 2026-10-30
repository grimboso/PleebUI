local _, ns = ...

local Addon = ns.Addon

local DisabledCooldownManager = {}

local function IsCooldownManagerAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_CooldownManager")
end

function Addon:SetCooldownManagerAddonEnabled(enabled)
  if IsCooldownManagerAddonChangeBlocked() then
    return
  end

  self.db.profile.childAddons.PleebUI_CooldownManager = enabled == true
  self:ApplyChildAddonProfile()
end

function DisabledCooldownManager:GetOptions()
  return {
    type = "group",
    name = "Cooldown Manager",
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
        desc = "Enable Cooldown Manager for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsCooldownManagerAddonChangeBlocked,
        func = function()
          Addon:SetCooldownManagerAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledCooldownManager",
  IsCooldownManagerAddonChangeBlocked,
  function() Addon:SetCooldownManagerAddonEnabled(true) end
)

local record = Addon:RegisterOptionsSection("CooldownManager", function()
  return DisabledCooldownManager
end, 50, "Cooldown Manager")
record.resolveOptionsPath = function()
  return { "CooldownManager" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}
