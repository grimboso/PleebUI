local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Lifecycle = {}
local P = ns.Pleebug:DropIn(Lifecycle, { name = "Modules.Chat.Lifecycle" })
local Events = CreateFrame("Frame")
local LoadingBoundary = CreateFrame("Frame")
local Enabled = false
local LayoutReady = false
local RefreshTimer
local WindowEvents = {
  "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "UPDATE_CHAT_COLOR",
  "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE",
  "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
  "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}

local function RefreshVisuals()
  RefreshTimer = nil
  if not Enabled then return end
  ChatLinks:RefreshChatFrames()
end

function ChatLinks:QueueChatVisualRefresh()
  if not Enabled or RefreshTimer then return end
  -- Discovery/layout runs after native window construction, without wrapping it.
  RefreshTimer = C_Timer.NewTimer(0, RefreshVisuals)
end

function ChatLinks:IsChatLayoutReady()
  return LayoutReady
end

LoadingBoundary:RegisterEvent("LOADING_SCREEN_DISABLED")
LoadingBoundary:SetScript("OnEvent", function(self)
  LayoutReady = true
  self:UnregisterAllEvents()
  if Enabled then ChatLinks:QueueChatVisualRefresh() end
end)

Events:SetScript("OnEvent", function(_, event, ...)
  -- Only the CVar branch binds arguments; secret whisper payloads stay untouched.
  if event == "CVAR_UPDATE" then
    local cvar = ...
    if not canaccessvalue(cvar) or (cvar ~= "chatStyle" and cvar ~= "textToSpeech") then return end
  end
  ChatLinks:QueueChatVisualRefresh()
end)

function ChatLinks:StartChatVisualLifecycle()
  if Enabled then
    self:QueueChatVisualRefresh()
    return
  end
  Enabled = true
  EventRegistry:RegisterCallback("EditMode.Exit", function() ChatLinks:QueueChatVisualRefresh() end, Lifecycle)
  for _, event in ipairs(WindowEvents) do Events:RegisterEvent(event) end
  self:QueueChatVisualRefresh()
end

function ChatLinks:StopChatVisualLifecycle()
  Enabled = false
  Events:UnregisterAllEvents()
  EventRegistry:UnregisterCallback("EditMode.Exit", Lifecycle)
  if RefreshTimer then RefreshTimer:Cancel(); RefreshTimer = nil end
end

RefreshVisuals = P:Def("RefreshVisuals", RefreshVisuals)
