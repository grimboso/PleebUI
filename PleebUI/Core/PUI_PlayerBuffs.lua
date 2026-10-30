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

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledPlayerBuffs",
  IsPlayerBuffsAddonChangeBlocked,
  function() Addon:SetPlayerBuffsAddonEnabled(true) end
)

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
