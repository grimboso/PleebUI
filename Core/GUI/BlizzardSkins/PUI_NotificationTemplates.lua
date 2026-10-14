local _, ns = ...
local Skins = ns.BlizzardSkins
local Notifications = {}
ns.NotificationSkins = Notifications
local registrations = {}
local pending = setmetatable({}, { __mode = "k" })
local installed = setmetatable({}, { __mode = "k" })
local driver = CreateFrame("Frame")
local initialized = false

local function StyleAlert(entry, frame)
  if frame:IsForbidden() then return end
  if InCombatLockdown() then
    pending[frame] = entry
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if not installed[frame] then
    entry.install(frame)
    installed[frame] = true
  end
  entry.repaint(frame)
end

function Notifications.Register(name, label, systemName, install, repaint)
  ns.BlizzardSkinOptions.Register(name, label, "Notifications")
  registrations[#registrations + 1] = {
    name = name, system = systemName, install = install, repaint = repaint,
  }
end

local function InstallSystems()
  if InCombatLockdown() then
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  initialized = true
  for _, entry in ipairs(registrations) do
    if ns.BlizzardSkinOptions.IsEnabled(entry.name) then
      local system = _G[entry.system]
      -- AlertFrame stays hidden; each native queue owns the actual pooled toasts.
      Skins.Hook(system, "setUpFunction", function(frame) StyleAlert(entry, frame) end)
      for frame in system.alertFramePool:EnumerateActive() do StyleAlert(entry, frame) end
    end
  end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    InstallSystems()
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not initialized then InstallSystems() end
    for frame, entry in pairs(pending) do
      pending[frame] = nil
      local shown = frame:IsShown()
      if not issecretvalue(shown) and shown then StyleAlert(entry, frame) end
    end
  end
end)
