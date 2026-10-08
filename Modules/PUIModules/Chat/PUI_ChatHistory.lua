local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Addon = ns.Addon
local HistoryOwner = {}
local P = ns.Pleebug:DropIn(HistoryOwner, { name = "Modules.Chat.History" })
local HistoryFrame = CreateFrame("Frame")
local HistoryEnabled = false
local HistoryReplayed = false
local HistoryInitialized = false
local SavedLog
local ReplayWindows
local ReplayConversations
local ReplayLegacy
local ReplayMigratedWindows
local SubscriptionsDirty = true
local SubscriptionsPending = false
local ReplayTimer
local FrameCapacities = setmetatable({}, { __mode = "k" })
local WindowSubscriptions = {}
local ReplayedWindows = {}
local ReplayedConversations = setmetatable({}, { __mode = "k" })
local ConversationAliases = { WHISPER = {}, BN_WHISPER = {} }
local WhisperMode
-- These are zone-channel IDs, independent of local channel numbers and language.
local ExcludedChannels = { [2] = true, [42] = true }
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

local function GetHistoryLimit()
  return math.min(5000, math.max(10, math.floor(ChatLinks.db.profile.chatTweaks.savedLines)))
end

local function IsRetainedEntry(entry)
  if not HistoryEvents[entry.event] and not entry.primaryOnly then return false end
  if entry.event ~= "CHAT_MSG_CHANNEL" then return true end
  local zone = entry.args[7]
  return canaccessvalue(zone) and type(zone) == "number" and not ExcludedChannels[zone]
end

local function ReadHistoryBucket(bucket)
  local entries = {}
  for index = 1, bucket.count do
    entries[index] = bucket.entries[(bucket.start + index - 2) % bucket.limit + 1]
  end
  return entries
end

local function AppendHistoryEntry(bucket, entry)
  if bucket.count == bucket.limit then
    bucket.entries[bucket.start] = entry
    bucket.start = bucket.start % bucket.limit + 1
  else
    bucket.entries[(bucket.start + bucket.count - 1) % bucket.limit + 1] = entry
    bucket.count = bucket.count + 1
  end
end

local function ResizeHistoryBucket(bucket, limit)
  if bucket.limit == limit then return end
  local entries = ReadHistoryBucket(bucket)
  bucket.entries, bucket.start, bucket.count, bucket.limit = {}, 1, 0, limit
  for index = math.max(1, #entries - limit + 1), #entries do AppendHistoryEntry(bucket, entries[index]) end
end

local function GetHistoryBucket(owner, key)
  local bucket = owner[key]
  if not bucket then
    bucket = { entries = {}, start = 1, count = 0, limit = GetHistoryLimit() }
    owner[key] = bucket
  end
  return bucket
end

local function GetEntryConversation(entry)
  if entry.conversationType and entry.conversationKey then return entry.conversationType, entry.conversationKey end
  local event, sender = entry.event, entry.args[2]
  if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
    return "WHISPER", string.lower(sender)
  elseif (event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM") and sender:find("#", 1, true) then
    return "BN_WHISPER", string.lower(sender)
  end
end

local function GetHistoryLog()
  if SavedLog then return SavedLog end
  local log = Addon.db.char.chatHistoryLog
  if not log then
    log = { version = 5, windows = {}, conversations = { WHISPER = {}, BN_WHISPER = {} } }
    Addon.db.char.chatHistoryLog = log
  elseif log.version ~= 5 then
    local entries = {}
    for _, entry in ipairs(log.current) do
      if IsRetainedEntry(entry) then entries[#entries + 1] = entry end
    end
    log = { version = 5, windows = {}, conversations = { WHISPER = {}, BN_WHISPER = {} }, legacy = entries }
    Addon.db.char.chatHistoryLog = log
  end
  if Addon.db.global.chatHistoryLog then log.legacy = log.legacy or {} end
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
        log.legacy[#log.legacy + 1] = {
          event = "CHAT_MSG_SYSTEM", args = args,
          timestamp = entry.timestamp or time(), color = color,
          primaryOnly = true,
        }
      end
    end
    Addon.db.global.chatHistoryLog = nil
  end
  if log.legacy then
    log.migratedWindows = log.migratedWindows or {}
    if not log.migratedConversations then
      for _, entry in ipairs(log.legacy) do
        local kind, key = GetEntryConversation(entry)
        if kind then AppendHistoryEntry(GetHistoryBucket(log.conversations[kind], key), entry) end
      end
      log.migratedConversations = true
    end
  end
  SavedLog = log
  return log
end

local function IsHistoryChannelSubscribed(window, zone, name)
  if not canaccessvalue(zone) or type(zone) ~= "number" or ExcludedChannels[zone] then return false end
  if zone > 0 and window.zones[zone] then return true end
  return canaccessvalue(name) and type(name) == "string" and window.names[string.upper(name)] == true
end

local function IsEntryForWindow(window, entry)
  if not IsRetainedEntry(entry) then return false end
  if entry.primaryOnly then return window.frame == DEFAULT_CHAT_FRAME end
  local category = HistoryEvents[entry.event]
  if category == "CHANNEL" then return IsHistoryChannelSubscribed(window, entry.args[7], entry.args[9]) end
  if category == "WHISPER" and WhisperMode == "popout" then return false end
  local messageType = ChatTypeGroupInverted[entry.event] or entry.event:sub(10)
  return window.groups[messageType] == true
end

local function SaveChatHistory(_, event, ...)
  if not HistoryEnabled then return end
  local category = HistoryEvents[event]
  if not category or (category ~= true and not ChatLinks.db.profile.chatTweaks.historyTypes[category]) then return end
  if category == "CHANNEL" then
    local zone, name = select(7, ...), select(9, ...)
    if not canaccessvalue(zone) or type(zone) ~= "number" or ExcludedChannels[zone] then return end
    local subscribed = false
    for _, window in pairs(WindowSubscriptions) do
      if IsHistoryChannelSubscribed(window, zone, name) then
        subscribed = true
        break
      end
    end
    if not subscribed then return end
  end
  local entry = ChatLinks:CreateChatHistoryEntry(event, ...)
  if not entry then return end
  local log = GetHistoryLog()
  for id, window in pairs(WindowSubscriptions) do
    if IsEntryForWindow(window, entry) then AppendHistoryEntry(GetHistoryBucket(log.windows, id), entry) end
  end
  local kind, key = GetEntryConversation(entry)
  if kind then
    AppendHistoryEntry(GetHistoryBucket(log.conversations[kind], key), entry)
    local sender = select(2, ...)
    ConversationAliases[kind][string.lower(sender)] = key
  end
  return kind, key
end

function ChatLinks:ApplyChatHistoryCapacity(frame)
  if self._puiRuntimeEnabled ~= true or not self:IsChatLayoutReady() then return end
  local capacity = math.max(128, GetHistoryLimit())
  if FrameCapacities[frame] == capacity then return end
  -- SetMaxLines is the destination window's secure capacity entry point.
  frame:SetMaxLines(capacity)
  FrameCapacities[frame] = capacity
end

local function GetHistoryWindowSubscriptions(id)
  local messageTypes = { GetChatWindowMessages(id) }
  local channels = { GetChatWindowChannels(id) }
  local groups, names, zones = {}, {}, {}
  for _, group in ipairs(messageTypes) do
    if not canaccessvalue(group) then return end
    if type(group) == "string" then groups[group] = true end
  end
  for index = 1, #channels, 2 do
    local name, zone = channels[index], channels[index + 1]
    if not canaccessallvalues(name, zone) then return end
    if type(name) == "string" then names[string.upper(name)] = true end
    if type(zone) == "number" and zone > 0 then zones[zone] = true end
  end
  return groups, names, zones, next(groups) ~= nil or next(names) ~= nil
end

local function RefreshHistoryWindowSubscriptions()
  wipe(WindowSubscriptions)
  local mode = GetCVar("whisperMode")
  if canaccessvalue(mode) then WhisperMode = mode end
  local configured, pending = false, false
  -- Temporary conversations have no persisted client window settings.
  for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
    local active = FCF_IsChatWindowIndexActive(id)
    if not canaccessvalue(active) then
      pending = true
    elseif active then
      local frame = FCF_GetChatFrameByID(id)
      if canaccessvalue(frame) and frame then
        local groups, names, zones, hasSubscriptions = GetHistoryWindowSubscriptions(id)
        if groups and hasSubscriptions then
          configured = true
          WindowSubscriptions[id] = { frame = frame, groups = groups, names = names, zones = zones }
        else
          pending = true
        end
      else
        pending = true
      end
    end
  end
  return configured, pending
end

local function MigrateHistoryWindows(log, pending)
  if not log.legacy then return end
  for id, window in pairs(WindowSubscriptions) do
    if not log.migratedWindows[id] then
      local bucket = GetHistoryBucket(log.windows, id)
      local newer = ReadHistoryBucket(bucket)
      bucket.entries, bucket.start, bucket.count = {}, 1, 0
      for _, entry in ipairs(log.legacy) do
        if IsEntryForWindow(window, entry) then AppendHistoryEntry(bucket, entry) end
      end
      for _, entry in ipairs(newer) do AppendHistoryEntry(bucket, entry) end
      log.migratedWindows[id] = true
    end
    if ReplayLegacy and not ReplayMigratedWindows[id] and not ReplayedWindows[id] then
      local saved = ReplayWindows[id] or {}
      local bucket = { entries = {}, start = 1, count = 0, limit = GetHistoryLimit() }
      for _, entry in ipairs(ReplayLegacy) do
        if IsEntryForWindow(window, entry) then AppendHistoryEntry(bucket, entry) end
      end
      for _, entry in ipairs(saved) do AppendHistoryEntry(bucket, entry) end
      ReplayWindows[id] = ReadHistoryBucket(bucket)
    end
  end
  if not pending then
    log.legacy, log.migratedWindows, log.migratedConversations = nil, nil, nil
  end
end

local function ReplayHistoryEntries(frame, entries, window)
  local types = ChatLinks.db.profile.chatTweaks.historyTypes
  ChatLinks:ApplyChatHistoryCapacity(frame)
  for index = #entries, math.max(1, #entries - GetHistoryLimit() + 1), -1 do
    local entry = entries[index]
    local category = HistoryEvents[entry.event]
    if (entry.primaryOnly or category == true or types[category]) and (not window or IsEntryForWindow(window, entry)) then
      ChatLinks:ReplayChatHistoryEvent(frame, entry)
    end
  end
end

local function ReplayConversationHistory()
  if not ReplayConversations or not ChatLinks.db.profile.chatTweaks.historyTypes.WHISPER then return end
  for _, name in ipairs(CHAT_FRAMES) do
    local frame = _G[name]
    if canaccessvalue(frame) and frame and canaccessallvalues(frame.isTemporary, frame.inUse) and frame.isTemporary then
      if not frame.inUse then
        ReplayedConversations[frame] = nil
      elseif canaccessallvalues(frame.chatType, frame.chatTarget) then
        local kind, target = frame.chatType, frame.chatTarget
        if (kind == "WHISPER" or kind == "BN_WHISPER") and type(target) == "string" then
          local alias = string.lower(target)
          local key = ConversationAliases[kind][alias] or (kind == "WHISPER" and alias)
          local entries = key and ReplayConversations[kind][key]
          local previous = ReplayedConversations[frame]
          if entries and (not previous or previous.kind ~= kind or previous.key ~= key) then
            ReplayHistoryEntries(frame, entries)
            ReplayedConversations[frame] = { kind = kind, key = key }
          end
        end
      end
    end
  end
end

local function ReplayChatHistory()
  ReplayTimer = nil
  if not HistoryEnabled then return end
  if not ChatLinks:IsChatLayoutReady() then return end
  if SubscriptionsDirty then
    local configured
    configured, SubscriptionsPending = RefreshHistoryWindowSubscriptions()
    SubscriptionsDirty = false
    if configured then MigrateHistoryWindows(GetHistoryLog(), SubscriptionsPending) end
  end
  if not HistoryReplayed and next(WindowSubscriptions) then
    for id, window in pairs(WindowSubscriptions) do
      if not ReplayedWindows[id] then
        local entries = ReplayWindows[id]
        if entries then ReplayHistoryEntries(window.frame, entries, window) end
        ReplayedWindows[id] = true
      end
    end
    if not SubscriptionsPending then
      HistoryReplayed = true
      ReplayWindows, ReplayLegacy, ReplayMigratedWindows = nil, nil, nil
    end
  end
  ReplayConversationHistory()
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
  local log, limit = GetHistoryLog(), GetHistoryLimit()
  for _, bucket in pairs(log.windows) do ResizeHistoryBucket(bucket, limit) end
  for _, conversations in pairs(log.conversations) do
    for _, bucket in pairs(conversations) do ResizeHistoryBucket(bucket, limit) end
  end
  if HistoryEnabled then return end
  if not HistoryReplayed and not ReplayWindows then
    ReplayWindows, ReplayConversations = {}, { WHISPER = {}, BN_WHISPER = {} }
    for id, bucket in pairs(log.windows) do ReplayWindows[id] = ReadHistoryBucket(bucket) end
    for kind, conversations in pairs(log.conversations) do
      for key, bucket in pairs(conversations) do ReplayConversations[kind][key] = ReadHistoryBucket(bucket) end
    end
    if log.legacy then
      ReplayLegacy, ReplayMigratedWindows = {}, {}
      for _, entry in ipairs(log.legacy) do ReplayLegacy[#ReplayLegacy + 1] = entry end
      for id in pairs(log.migratedWindows) do ReplayMigratedWindows[id] = true end
    end
  end
  HistoryEnabled = true
  -- Read client subscriptions for capture; all native buffer writes still wait for readiness.
  RefreshHistoryWindowSubscriptions()
  SubscriptionsDirty = true
  for event in pairs(HistoryEvents) do HistoryFrame:RegisterEvent(event) end
  for _, event in ipairs({
    "LOADING_SCREEN_DISABLED", "SETTINGS_LOADED", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS",
    "CHANNEL_UI_UPDATE", "CVAR_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
  }) do HistoryFrame:RegisterEvent(event) end
  ReplayTimer = C_Timer.NewTimer(0, ReplayChatHistory)
end

function ChatLinks:StopChatHistory()
  HistoryEnabled = false
  HistoryFrame:UnregisterAllEvents()
  wipe(WindowSubscriptions)
  if ReplayTimer then
    ReplayTimer:Cancel()
    ReplayTimer = nil
  end
end

function ChatLinks:ClearChatHistory()
  local log = GetHistoryLog()
  wipe(log.windows)
  wipe(log.conversations.WHISPER)
  wipe(log.conversations.BN_WHISPER)
  log.legacy, log.migratedWindows, log.migratedConversations = nil, nil, nil
  wipe(ReplayedWindows)
  wipe(ReplayedConversations)
  ReplayWindows, ReplayConversations, ReplayLegacy, ReplayMigratedWindows = nil, nil, nil, nil
  HistoryReplayed = true
  if ReplayTimer then
    ReplayTimer:Cancel()
    ReplayTimer = nil
  end
end

SaveChatHistory = P:Def("SaveChatHistory", SaveChatHistory)
ReplayChatHistory = P:Def("ReplayChatHistory", ReplayChatHistory)
HistoryFrame:SetScript("OnEvent", function(self, event, ...)
  if HistoryEvents[event] then
    local kind, key = SaveChatHistory(self, event, ...)
    if not kind or not ReplayConversations or not ReplayConversations[kind][key] then return end
  else
    if event == "CVAR_UPDATE" then
      local cvar = ...
      if not canaccessvalue(cvar) or cvar ~= "whisperMode" then return end
    end
    SubscriptionsDirty = true
  end
  if HistoryEnabled and not ReplayTimer then
    -- Native creation and delivery finish before history is inserted.
    ReplayTimer = C_Timer.NewTimer(0, ReplayChatHistory)
  end
end)
