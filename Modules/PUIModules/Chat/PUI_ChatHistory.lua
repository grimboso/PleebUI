local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Addon = ns.Addon
local HistoryOwner = {}
local P = ns.Pleebug:DropIn(HistoryOwner, { name = "Modules.Chat.History" })
local HistoryFrame = CreateFrame("Frame")
local HistoryEnabled = false
local HistoryReplayed = false
local HistoryInitialized = false
local ReplayEntries
local ReplayTimer
local FrameCapacities = setmetatable({}, { __mode = "k" })
local HistoryEvents = {
  CHAT_MSG_WHISPER = "WHISPER",
  CHAT_MSG_WHISPER_INFORM = "WHISPER",
  CHAT_MSG_BN_WHISPER = "WHISPER",
  CHAT_MSG_BN_WHISPER_INFORM = "WHISPER",
  CHAT_MSG_BN_INLINE_TOAST_BROADCAST = true,
  CHAT_MSG_GUILD = "GUILD",
  CHAT_MSG_GUILD_ACHIEVEMENT = "GUILD",
  CHAT_MSG_PARTY = "PARTY",
  CHAT_MSG_PARTY_LEADER = "PARTY",
  CHAT_MSG_RAID = "RAID",
  CHAT_MSG_RAID_LEADER = "RAID",
  CHAT_MSG_RAID_WARNING = "RAID",
  CHAT_MSG_INSTANCE_CHAT = "INSTANCE",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE",
  CHAT_MSG_CHANNEL = "CHANNEL",
  CHAT_MSG_SAY = "SAY",
  CHAT_MSG_YELL = "YELL",
  CHAT_MSG_EMOTE = "EMOTE",
}

ChatLinks.ChatHistoryEvents = HistoryEvents
ChatLinks.ChatHistoryTypes = {
  WHISPER = "Whispers", GUILD = "Guild", PARTY = "Party", RAID = "Raid",
  INSTANCE = "Instance", CHANNEL = "Channels", SAY = "Say", YELL = "Yell", EMOTE = "Emotes",
}

local function TrimChatHistory(messages)
  local limit = math.min(5000, math.max(10, math.floor(ChatLinks.db.profile.chatTweaks.savedLines)))
  if #messages <= limit then return end
  local count = #messages
  local removed = count - limit
  for i = 1, limit do messages[i] = messages[i + removed] end
  for i = count, limit + 1, -1 do messages[i] = nil end
end

local function GetHistoryLog()
  local log = Addon.db.char.chatHistoryLog
  if not log then
    log = { version = 4, current = {} }
    Addon.db.char.chatHistoryLog = log
  end
  local legacy = Addon.db.global.chatHistoryLog
  if legacy then
    -- Earlier releases only retained rendered text, so its original event is unknown.
    for _, entry in ipairs(legacy.current) do
      local text = entry.text
      local color = entry.color
      if canaccessvalue(color) and type(color) == "table" and canaccesstable(color) then
        if canaccessallvalues(color.r, color.g, color.b) then
          color = { r = color.r, g = color.g, b = color.b }
        else
          color = nil
        end
      else
        color = nil
      end
      if canaccessallvalues(text, entry.timestamp) and type(text) == "string" then
        text = text:gsub("|K.-|k", "???"):gsub("|HBNplayer.-|h(.-)|h", "%1")
        text = text:gsub("|Hplayer:[^|]-|h(.-)|h", "%1")
        text = text:gsub("|Hcensoredmessage:.-|h.-|h", "[CENSORED]")
        text = text:gsub("|Hreportcensoredmessage:.-|h.-|h", "[???]")
        local args = { n = 18, text, "", "", "", "", "", 0, 0, "", 0, 0 }
        log.current[#log.current + 1] = {
          event = "CHAT_MSG_SYSTEM", args = args,
          timestamp = entry.timestamp or time(), color = color,
          primaryOnly = true,
        }
      end
    end
    Addon.db.global.chatHistoryLog = nil
  end
  if log.version == 3 then
    local messages, retained = log.current, 0
    for _, entry in ipairs(messages) do
      if HistoryEvents[entry.event] or entry.primaryOnly then
        retained = retained + 1
        messages[retained] = entry
      end
    end
    for i = #messages, retained + 1, -1 do messages[i] = nil end
    TrimChatHistory(messages)
    log.version = 4
  end
  return log
end

local function SaveChatHistory(_, event, ...)
  if not HistoryEnabled then return end
  local category = HistoryEvents[event]
  if not category or (category ~= true and not ChatLinks.db.profile.chatTweaks.historyTypes[category]) then return end
  local entry = ChatLinks:CreateChatHistoryEntry(event, ...)
  if not entry then return end
  local messages = GetHistoryLog().current
  messages[#messages + 1] = entry
  TrimChatHistory(messages)
end

function ChatLinks:ApplyChatHistoryCapacity(frame)
  if self._puiRuntimeEnabled ~= true or not self:IsChatLayoutReady()
    or InCombatLockdown() or C_ChatInfo.InChatMessagingLockdown() then return end
  local capacity = math.max(128, math.min(5000, math.floor(self.db.profile.chatTweaks.savedLines)))
  if FrameCapacities[frame] == capacity then return end
  -- Keep native buffer mutations inside the intrinsic secure entry point.
  ns.SetChatMaxLines(frame, capacity)
  FrameCapacities[frame] = capacity
end

local function GetHistoryChannelSubscriptions(frame)
  local names, zones = {}, {}
  local channels = frame.channelList
  if not canaccessvalue(channels) or type(channels) ~= "table" or not canaccesstable(channels) then
    return names, zones
  end
  local zoneChannels = frame.zoneChannelList
  local zonesAccessible = canaccessvalue(zoneChannels) and type(zoneChannels) == "table" and canaccesstable(zoneChannels)
  for index, name in pairs(channels) do
    if canaccessvalue(name) and type(name) == "string" then names[string.upper(name)] = true end
    if zonesAccessible and canaccessvalue(index) then
      local zone = zoneChannels[index]
      if canaccessvalue(zone) and type(zone) == "number" and zone > 0 then zones[zone] = true end
    end
  end
  return names, zones
end

local function ReplayChatHistory()
  ReplayTimer = nil
  if not HistoryEnabled or HistoryReplayed then return end
  if #ReplayEntries == 0 then
    HistoryReplayed = true
    ReplayEntries = nil
    return
  end
  if not ChatLinks:IsChatLayoutReady() or InCombatLockdown() or C_ChatInfo.InChatMessagingLockdown() then return end
  HistoryReplayed = true
  local selectedTypes = ChatLinks.db.profile.chatTweaks.historyTypes
  for _, frameName in ipairs(CHAT_FRAMES) do
    local frame = _G[frameName]
    if canaccessvalue(frame) and frame and canaccessvalue(frame.isTemporary) and not frame.isTemporary then
      ChatLinks:ApplyChatHistoryCapacity(frame)
      local groups = frame.messageTypeList
      local groupsAccessible = canaccessvalue(groups) and type(groups) == "table" and canaccesstable(groups)
      local channelNames, channelZones = GetHistoryChannelSubscriptions(frame)
      for index = #ReplayEntries, 1, -1 do
        local entry = ReplayEntries[index]
        local category = HistoryEvents[entry.event]
        if entry.primaryOnly then
          if frame == DEFAULT_CHAT_FRAME then ChatLinks:ReplayChatHistoryEvent(frame, entry) end
        elseif category and (category == true or selectedTypes[category]) then
          if category == "CHANNEL" then
            local zone, name = entry.args[7], entry.args[9]
            local enabled = (canaccessvalue(zone) and type(zone) == "number" and zone > 0 and channelZones[zone])
              or (canaccessvalue(name) and type(name) == "string" and channelNames[string.upper(name)])
            if enabled then ChatLinks:ReplayChatHistoryEvent(frame, entry) end
          elseif groupsAccessible then
            local messageType = ChatTypeGroupInverted[entry.event] or entry.event:sub(10)
            for _, group in pairs(groups) do
              if canaccessvalue(group) and group == messageType then
                ChatLinks:ReplayChatHistoryEvent(frame, entry)
                break
              end
            end
          end
        end
      end
    end
  end
  ReplayEntries = nil
end

function ChatLinks:StartChatHistory()
  if self._puiRuntimeEnabled ~= true then
    self:StopChatHistory()
    return
  end
  if not HistoryInitialized then
    HistoryInitialized = true
    if self.db.profile.chatTweaks.persistHistory == false then self:ClearChatHistory() end
  end
  if self.db.profile.chatTweaks.persistHistory == false then
    self:StopChatHistory()
    return
  end
  local messages = GetHistoryLog().current
  TrimChatHistory(messages)
  if ReplayEntries then TrimChatHistory(ReplayEntries) end
  if HistoryEnabled then return end
  if not HistoryReplayed and not ReplayEntries then
    ReplayEntries = {}
    for i = 1, #messages do ReplayEntries[i] = messages[i] end
  end
  HistoryEnabled = true
  for event in pairs(HistoryEvents) do HistoryFrame:RegisterEvent(event) end
  HistoryFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
  HistoryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  HistoryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  HistoryFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
  HistoryFrame:RegisterEvent("CHALLENGE_MODE_RESET")
  if not HistoryReplayed then ReplayTimer = C_Timer.NewTimer(0, ReplayChatHistory) end
end

function ChatLinks:StopChatHistory()
  HistoryEnabled = false
  HistoryFrame:UnregisterAllEvents()
  if ReplayTimer then
    ReplayTimer:Cancel()
    ReplayTimer = nil
  end
end

function ChatLinks:ClearChatHistory()
  wipe(GetHistoryLog().current)
  ReplayEntries = nil
  HistoryReplayed = true
  if ReplayTimer then
    ReplayTimer:Cancel()
    ReplayTimer = nil
  end
end

SaveChatHistory = P:Def("SaveChatHistory", SaveChatHistory)
ReplayChatHistory = P:Def("ReplayChatHistory", ReplayChatHistory)
HistoryFrame:SetScript("OnEvent", function(self, event, ...)
  if event:sub(1, 9) == "CHAT_MSG_" then
    SaveChatHistory(self, event, ...)
  end
  if HistoryEnabled and not HistoryReplayed and not ReplayTimer
    and ChatLinks:IsChatLayoutReady() and not InCombatLockdown() and not C_ChatInfo.InChatMessagingLockdown() then
    ReplayTimer = C_Timer.NewTimer(0, ReplayChatHistory)
  end
end)
