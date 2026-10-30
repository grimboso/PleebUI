local _, ns = ...

local Addon = ns.Addon

local DisabledUnitFrames = {}

local function IsUnitFramesAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_UnitFrames")
end

function Addon:SetUnitFramesAddonEnabled(enabled)
  if IsUnitFramesAddonChangeBlocked() then
    return
  end

  self.db.profile.childAddons.PleebUI_UnitFrames = enabled == true
  self:ApplyChildAddonProfile()
end

function DisabledUnitFrames:GetOptions()
  return {
    type = "group",
    name = "Unit Frames",
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
        desc = "Enable Unit Frames for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsUnitFramesAddonChangeBlocked,
        func = function()
          Addon:SetUnitFramesAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledUnitFrames",
  IsUnitFramesAddonChangeBlocked,
  function() Addon:SetUnitFramesAddonEnabled(true) end
)

local record = Addon:RegisterOptionsSection("unitframes", function()
  return DisabledUnitFrames
end, 40, "Unit Frames")
record.resolveOptionsPath = function()
  return { "unitframes" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}
