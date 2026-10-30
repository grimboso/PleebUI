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

  self.db.profile.childAddons.PleebUI_DamageMeters = enabled == true
  self:ApplyChildAddonProfile()
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
        desc = "Enable Damage Meters for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsDamageMetersAddonChangeBlocked,
        func = function()
          Addon:SetDamageMetersAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledDamageMeters",
  IsDamageMetersAddonChangeBlocked,
  function() Addon:SetDamageMetersAddonEnabled(true) end
)

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
