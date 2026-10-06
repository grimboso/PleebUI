local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Lifecycle = {}
local P = ns.Pleebug:DropIn(Lifecycle, { name = "Modules.Chat.Lifecycle" })
local Events = CreateFrame("Frame")
local LoadingBoundary = CreateFrame("Frame")
local Enabled = false
local LayoutReady = false
local RefreshTimer
local DiscoveryTimer
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

local function DiscoverVisuals()
  DiscoveryTimer = nil
  if not Enabled then return end
  ChatLinks:DiscoverChatFrames()
end

function ChatLinks:QueueChatVisualRefresh()
  if not Enabled or RefreshTimer then return end

  if DiscoveryTimer then
    DiscoveryTimer:Cancel()
    DiscoveryTimer = nil
  end

  RefreshTimer = C_Timer.NewTimer(0, RefreshVisuals)
end

function ChatLinks:QueueChatFrameDiscovery()
  if not Enabled or RefreshTimer or DiscoveryTimer then return end
  DiscoveryTimer = C_Timer.NewTimer(0, DiscoverVisuals)
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
  if event == "PLAYER_REGEN_ENABLED" then
    ChatLinks:RefreshPendingChatVisuals()
    return
  end

  if event == "CHAT_MSG_WHISPER"
    or event == "CHAT_MSG_WHISPER_INFORM"
    or event == "CHAT_MSG_BN_WHISPER"
    or event == "CHAT_MSG_BN_WHISPER_INFORM"
  then
    ChatLinks:QueueChatFrameDiscovery()
    return
  end

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

  if RefreshTimer then
    RefreshTimer:Cancel()
    RefreshTimer = nil
  end

  if DiscoveryTimer then
    DiscoveryTimer:Cancel()
    DiscoveryTimer = nil
  end
end

RefreshVisuals = P:Def("RefreshVisuals", RefreshVisuals)
DiscoverVisuals = P:Def("DiscoverVisuals", DiscoverVisuals)
