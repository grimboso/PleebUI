local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Archive = {}
local P = ns.Pleebug:DropIn(Archive, { name = "Modules.Chat.Archive" })

local function IsAccessibleTable(value)
  if not canaccessvalue(value) then
    return false
  end
  if type(value) ~= "table" then
    return true
  end
  if not canaccesstable(value) then
    return false
  end
  for key, field in pairs(value) do
    if not canaccessvalue(key) or not IsAccessibleTable(field) then
      return false
    end
  end
  return true
end

local function DecorateAccessibleSender(event, text, sender, language, channel, secondSender, flags, zoneChannel, channelIndex, channelBase, languageID, lineID, senderGUID, accountID, mobile, discordInfo)
  if not canaccessvalue(sender) then
    return sender
  end
  local chatType = string.sub(event, 10)
  local name = Ambiguate(sender, chatType == "GUILD" and "guild" or "none")
  if not canaccessvalue(name) then
    return name
  end
  if IsAccessibleTable(discordInfo) and discordInfo and discordInfo.userID ~= 0 then
    if discordInfo.globalName and discordInfo.type == Enum.DiscordDisplayNameType.GlobalName then
      return ChatFrameUtil.DiscordNameColorize(discordInfo.globalName)
    end
    senderGUID, name = discordInfo.lastOnlineGUID, discordInfo.lastOnlineName
  end
  local info = ChatTypeInfo[chatType == "WHISPER_INFORM" and "WHISPER" or chatType]
  if canaccessvalue(senderGUID) and senderGUID then
    local timerunning = C_ChatInfo.IsTimerunningPlayer(senderGUID)
    if canaccessvalue(timerunning) and timerunning then
      name = TimerunningUtil.AddSmallIcon(name)
    end
    if info and ChatFrameUtil.ShouldColorChatByClass(info) then
      local _, class = GetPlayerInfoByGUID(senderGUID)
      if canaccessvalue(class) and class and RAID_CLASS_COLORS[class] then
        name = RAID_CLASS_COLORS[class]:WrapTextInColorCode(name)
      end
    end
  end
  return ChatFrameUtil.ProcessSenderNameFilters(event, name, text, sender, language, channel, secondSender, flags, zoneChannel, channelIndex, channelBase, languageID, lineID, senderGUID, accountID, mobile, discordInfo)
end

local function CopyHistoryValue(value, visiting)
  if not canaccessvalue(value) then return nil, false end
  local kind = type(value)
  if kind == "nil" or kind == "boolean" or kind == "number" then return value, true end
  if kind == "string" then
    -- Session-only names and moderation links cannot be restored after reload.
    if value:find("|K.-|k") or value:find("censoredmessage:") then return nil, false end
    return value, true
  end
  if kind ~= "table" or not canaccesstable(value) or visiting[value] then return nil, false end
  visiting[value] = true
  local copy = {}
  for key, field in pairs(value) do
    if not canaccessvalue(key) or (type(key) ~= "string" and type(key) ~= "number") then
      visiting[value] = nil
      return nil, false
    end
    local copied, accessible = CopyHistoryValue(field, visiting)
    if not accessible then
      visiting[value] = nil
      return nil, false
    end
    copy[key] = copied
  end
  visiting[value] = nil
  return copy, true
end

local HistoryArgumentDefaults = {
  [3] = "", [4] = "", [5] = "", [6] = "", [7] = 0, [8] = 0,
  [9] = "", [10] = 0, [14] = false, [15] = false, [17] = false,
}

function ChatLinks:CreateChatHistoryEntry(event, ...)
  local text, sender = ...
  local hidden = select(16, ...)
  if not canaccessallvalues(text, sender, hidden) or hidden then return end
  if type(text) ~= "string" or text == "" or type(sender) ~= "string" then return end
  local flags, lineID, accountID = select(6, ...), select(11, ...), select(13, ...)
  if not canaccessvalue(flags) then return end
  if flags == "GM" and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM") then return end
  if canaccessvalue(lineID) and type(lineID) == "number" and lineID ~= 0 then
    local censored = C_ChatInfo.IsChatLineCensored(lineID)
    if not canaccessvalue(censored) or censored then return end
  end
  if event:sub(1, 12) == "CHAT_MSG_BN_" and sender:find("|K.-|k") then
    if not canaccessvalue(accountID) or type(accountID) ~= "number" then return end
    local account = C_BattleNet.GetAccountInfoByID(accountID)
    if not canaccessvalue(account) or not account or not canaccesstable(account) then return end
    sender = account.battleTag
    if not canaccessvalue(sender) or type(sender) ~= "string" then return end
  end

  local args = { n = 18 }
  local visiting = {}
  for i = 1, 18 do
    if i ~= 11 and i ~= 13 then
      local value = select(i, ...)
      if i == 2 then value = sender end
      local copied, accessible = CopyHistoryValue(value, visiting)
      if not accessible and i <= 2 then return end
      if not accessible or copied == nil then copied = HistoryArgumentDefaults[i] end
      args[i] = copied
    end
  end
  -- Identifiers for message moderation and accounts expire with this login.
  args[11] = 0
  local label = DecorateAccessibleSender(event, args[1], args[2], args[3], args[4], args[5], args[6],
    args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[18])
  local savedLabel, accessible = CopyHistoryValue(label, visiting)
  if not accessible or type(savedLabel) ~= "string" then savedLabel = args[2] end
  return { event = event, args = args, timestamp = time(), senderLabel = savedLabel }
end

ChatLinks.CreateChatHistoryEntry = P:Def("CreateChatHistoryEntry", ChatLinks.CreateChatHistoryEntry)

local function RenderHistoryText(frame, entry)
  local kind = entry.event:sub(10)
  local args = entry.args
  local text, sender, language, channel, _, flags, zone, channelIndex = unpack(args, 1, 8)
  local infoType = kind == "CHANNEL" and ("CHANNEL" .. (channelIndex or 0)) or kind
  local info = entry.color or ChatTypeInfo[infoType] or ChatTypeInfo[kind]
  if not info then return end
  if entry.primaryOnly then return text, info end
  local label = entry.senderLabel or sender
  local name = "[" .. label .. "]"
  if kind ~= "BN_WHISPER" and kind ~= "BN_WHISPER_INFORM" and kind:sub(1, 3) ~= "BN_" then
    name = string.format("|Hplayer:%s:0|h%s|h", sender, name)
  end
  if kind == "GUILD_ACHIEVEMENT" then
    text = string.format(text, name)
  elseif kind == "BN_INLINE_TOAST_BROADCAST" then
    text = string.format(BN_INLINE_TOAST_BROADCAST, name, RemoveNewlines(RemoveExtraSpaces(text)))
  else
    local group = ChatFrameUtil.GetChatCategory(kind)
    text = C_ChatInfo.ReplaceIconAndGroupExpressions(text, args[17], not ChatFrameUtil.CanChatGroupPerformExpressionExpansion(group))
    if not canaccessvalue(text) or type(text) ~= "string" then return end
    text = RemoveExtraSpaces(text)
    local prefix = ChatFrameUtil.GetPFlag(flags or "", zone or 0, channelIndex or 0)
    if not canaccessvalue(prefix) or type(prefix) ~= "string" then return end
    if kind == "EMOTE" then
      name = label
      name = string.format("|Hplayer:%s:0|h%s|h", sender, name)
    end
    local header = string.format(ChatFrameUtil.GetOutMessageFormatKey(kind), prefix .. name, sender)
    local defaultLanguage = (kind == "SAY" or kind == "YELL") and frame.alternativeDefaultLanguage or frame.defaultLanguage
    if canaccessvalue(defaultLanguage) and language and language ~= "" and language ~= defaultLanguage then
      header = header .. "[" .. language .. "] "
    end
    if channel and channel ~= "" then
      header = string.format("|Hchannel:channel:%s|h[%s]|h %s", channelIndex or 0, ChatFrameUtil.ResolvePrefixedChannelName(channel), header)
    end
    text = header .. text
  end
  local format = ChatFrameUtil.GetTimestampFormat()
  if format then text = TimeUtil.BetterDate(format, entry.timestamp) .. text end
  return text, info
end

function ChatLinks:ReplayChatHistoryEvent(frame, entry)
  if not IsAccessibleTable(entry) then return end
  if not self.ChatHistoryEvents[entry.event] and not entry.primaryOnly then return end
  local text, info = RenderHistoryText(frame, entry)
  if not canaccessvalue(text) or type(text) ~= "string" then return end
  -- BackFillMessage is the destination window's secure display entry point.
  frame:BackFillMessage(text, info.r, info.g, info.b)
end

RenderHistoryText = P:Def("RenderHistoryText", RenderHistoryText)
