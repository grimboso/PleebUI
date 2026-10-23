local _, ns = ...

local Addon = ns.Addon
local ChildAddons = {
  "PleebUI_ActionBars",
  "PleebUI_DamageMeters",
  "PleebUI_PRD",
  "PleebUI_CooldownManager",
  "PleebUI_UnitFrames",
  "PleebUI_PlayerBuffs",
  "PleebUI_CombatTools",
  "PleebUI_Chat",
}
local ProfileCheckHost = CreateFrame("Frame")
ProfileCheckHost:Hide()
local ReloadPromptCallback
local SessionAddonStates = {}
local ChildAddonLabels = {
  PleebUI_ActionBars = "Action Bars",
  PleebUI_DamageMeters = "Damage Meters",
  PleebUI_PRD = "Personal Resource Display",
  PleebUI_CooldownManager = "Cooldown Manager",
  PleebUI_UnitFrames = "Unit Frames",
  PleebUI_PlayerBuffs = "Player Buffs",
  PleebUI_CombatTools = "Combat Tools",
  PleebUI_Chat = "Chat",
}

function Addon:GetChildAddonChoices()
  local choices = {}
  for _, addonName in ipairs(ChildAddons) do
    choices[#choices + 1] = {
      name = addonName,
      label = ChildAddonLabels[addonName],
      installed = C_AddOns.DoesAddOnExist(addonName),
      enabled = self.db.profile.childAddons[addonName] == true,
    }
  end
  return choices
end

function Addon:MigrateChildAddonProfiles(saved)
  if not saved or saved.global and saved.global.childAddonProfileMigrationVersion == 1 then return end
  local character = UnitNameUnmodified("player")
  for _, profile in pairs(saved.profiles or {}) do
    if profile.childAddons == nil then
      local enabled = {}
      for _, addonName in ipairs(ChildAddons) do
        enabled[addonName] = not C_AddOns.DoesAddOnExist(addonName)
          or C_AddOns.GetAddOnEnableState(addonName, character) ~= Enum.AddOnEnableState.None
      end
      profile.childAddons = enabled
    end
  end
end

function Addon:ApplyChildAddonProfile()
  if InCombatLockdown() then
    self:QueueChildAddonProfileCheck()
    return
  end
  local enabled = self.db.profile.childAddons
  local character = UnitNameUnmodified("player")
  for _, addonName in ipairs(ChildAddons) do
    if C_AddOns.DoesAddOnExist(addonName) then
      if enabled[addonName] then
        C_AddOns.EnableAddOn(addonName, character)
      else
        C_AddOns.DisableAddOn(addonName, character)
      end
    end
  end
  ReloadUI()
end

function Addon:ChildAddonProfileNeedsReload()
  local enabled = self.db.profile.childAddons
  local character = UnitNameUnmodified("player")
  for _, addonName in ipairs(ChildAddons) do
    if C_AddOns.DoesAddOnExist(addonName) then
      local active = C_AddOns.GetAddOnEnableState(addonName, character) ~= Enum.AddOnEnableState.None
      if active ~= enabled[addonName]
        or SessionAddonStates[addonName] ~= nil and SessionAddonStates[addonName] ~= enabled[addonName] then
        return true
      end
    end
  end
  return false
end

local function DismissReloadPrompt()
  ProfileCheckHost:UnregisterEvent("PLAYER_REGEN_DISABLED")
  local dialog = Addon._PUIConfirmDialog
  if ReloadPromptCallback and dialog and dialog._onYes == ReloadPromptCallback then
    dialog:Hide()
    dialog._onYes, dialog._onNo = nil, nil
  end
  ReloadPromptCallback = nil
end

local function CheckProfileAddons()
  ProfileCheckHost:Hide()
  if not IsLoggedIn() then return end
  DismissReloadPrompt()
  if _G.PleebUIOnboardingFrame and _G.PleebUIOnboardingFrame:IsShown() then return end
  if not Addon:ChildAddonProfileNeedsReload() then
    ProfileCheckHost:UnregisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if InCombatLockdown() then
    ProfileCheckHost:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local profileName = Addon.db:GetCurrentProfile()
  ReloadPromptCallback = function()
    DismissReloadPrompt()
    if Addon.db:GetCurrentProfile() ~= profileName then
      Addon:QueueChildAddonProfileCheck()
      return
    end
    Addon:ApplyChildAddonProfile()
  end
  Addon:PUI_ConfirmAction({
    title = "Reload required",
    text = "This profile requires a reload to function properly.\n\nApply this profile's addon choices and reload the UI?",
    yesText = "Apply and reload",
    noText = "Later",
    onYes = ReloadPromptCallback,
    onNo = DismissReloadPrompt,
  })
  ProfileCheckHost:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function Addon:QueueChildAddonProfileCheck()
  ProfileCheckHost:Show()
end

ProfileCheckHost:SetScript("OnUpdate", CheckProfileAddons)
ProfileCheckHost:SetScript("OnEvent", function(self, event)
  self:UnregisterEvent(event)
  if event == "PLAYER_LOGIN" then
    local character = UnitNameUnmodified("player")
    for _, addonName in ipairs(ChildAddons) do
      if C_AddOns.DoesAddOnExist(addonName) then
        SessionAddonStates[addonName] = C_AddOns.GetAddOnEnableState(addonName, character) ~= Enum.AddOnEnableState.None
      end
    end
  end
  self:Show()
end)
ProfileCheckHost:RegisterEvent("PLAYER_LOGIN")
