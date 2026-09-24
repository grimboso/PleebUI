local ADDON_NAME, ns = ...

local Startup = ns.Addon:NewModule("Startup", "NumyAceEvent-3.0")

local function CompleteStartupLayout(self)
  if not ns.FrameUtil:CompleteStartupLayout() then
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  self:UnregisterEvent("LOADING_SCREEN_DISABLED")
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function Startup:OnEnable()
  self:RegisterEvent("LOADING_SCREEN_DISABLED")
end

function Startup:LOADING_SCREEN_DISABLED()
  CompleteStartupLayout(self)
end

function Startup:PLAYER_REGEN_ENABLED()
  CompleteStartupLayout(self)
end
