-- File: PUI_Chat.lua

local ADDON_NAME, ns = ...



local Addon    = ns.Addon

local FrameUtil = ns.FrameUtil
local OptionsUtil = ns.OptionsUtil


local ChatLinks = Addon:NewModule("ChatLinks", "NumyAceEvent-3.0")
ns.Registry.ChatLinks = ChatLinks


local LibStub = _G.LibStub
local P, TrackThis = ns.Pleebug:DropIn(ChatLinks, { name = "Modules.Chat" })

local function ClampInt(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then value = minimum end
  if value > maximum then value = maximum end
  return value
end

local function ForEachBlizzardChatFrame(callback)
  for _, chatFrameName in pairs(_G.CHAT_FRAMES) do
    local chatFrame = _G[chatFrameName]
    if chatFrame then
      callback(chatFrame)
    end
  end
end

local function _PUI_IsChatMessagingRestricted()
  if InCombatLockdown() then
    return true
  end

  local inChatMessagingLockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  return inChatMessagingLockdown and inChatMessagingLockdown() == true
end


local function _PUI_AreChatArgumentsAccessible(...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if not canaccessvalue(value) then
      return false
    end
  end

  return true
end

local function _PUI_IsTemporaryChatFrame(chatFrame)
  if not chatFrame then
    return false
  end

  local isTemporary = chatFrame.isTemporary
  if issecretvalue(isTemporary) then
    return true
  end

  return isTemporary == true
end

local function _PUI_IsChattynatorLoaded()
  return C_AddOns.IsAddOnLoaded("Chattynator") == true
end

local function _PUI_IsPratLoaded()
  return C_AddOns.IsAddOnLoaded("Prat-3.0") == true
end

local function _PUI_GetChatConflictDB()
  local root = Addon.db
  root.global = root.global or {}
  root.global.chatConflicts = root.global.chatConflicts or {}
  local g = root.global.chatConflicts

  if g.chattynator ~= "ask" and g.chattynator ~= "pui" and g.chattynator ~= "chattynator" then
    g.chattynator = "ask"
  end
  if g.prat ~= "ask" and g.prat ~= "pui" and g.prat ~= "prat" then
    g.prat = "ask"
  end

  return g
end

local function _PUI_ConfirmDisablePUIChatAndReload(self)
  local onYes = function()
    local dbp = self.db.profile
    dbp.enabled = false
    dbp.manualDisabled = true

    _PUI_GetChatConflictDB().chattynator = "chattynator"

    ReloadUI()
  end

  Addon:PUI_ConfirmAction({
    title   = "Use Chattynator?",
    text    = "This will disable PleebUI Chat and reload the UI.\n\nYou can re-enable PleebUI Chat later by disabling Chattynator (or resetting Chat settings).",
    yesText = "Disable + Reload",
    noText  = CANCEL,
    onYes   = function()
      if InCombatLockdown() then
        Addon:Print("|cffff4444[PUI]|r Cannot reload while in combat.")
        return
      end
      onYes()
    end,
  })
end

local function _PUI_ConfirmDisablePUIChatAndReload_PrAt(self)
  local onYes = function()
    local dbp = self.db.profile
    dbp.enabled = false
    dbp.manualDisabled = true

    _PUI_GetChatConflictDB().prat = "prat"

    ReloadUI()
  end

  Addon:PUI_ConfirmAction({
    title   = "Use Prat?",
    text    = "This will disable PleebUI Chat and reload the UI.\n\nYou can re-enable PleebUI Chat later by disabling Prat (or resetting Chat settings).",
    yesText = "Disable + Reload",
    noText  = CANCEL,
    onYes   = function()
      if InCombatLockdown() then
        Addon:Print("|cffff4444[PUI]|r Cannot reload while in combat.")
        return
      end
      onYes()
    end,
  })
end

local function _PUI_ShowChattynatorChoicePopup(self)
  if not StaticPopupDialogs["PUI_CHAT_CHATTYNATOR_CHOICE"] then
    StaticPopupDialogs["PUI_CHAT_CHATTYNATOR_CHOICE"] = {
      text = "We see that you have Chattynator installed.\n\nPlease choose if you want to use PleebUI Chat or Chattynator.",
      button1 = "PleebUI",
      button2 = "Chattynator",
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnAccept = function(_, data)
        local mod = data

        local dbp = mod.db.profile
        dbp.manualDisabled = false
        dbp.enabled = true

        _PUI_GetChatConflictDB().chattynator = "pui"
        Addon:Print("|cffffcc00[PUI]|r PleebUI Chat selected. Please disable Chattynator in the AddOns list and /reload for best results.")
      end,
      OnCancel = function(_, data)
        local mod = data
        _PUI_ConfirmDisablePUIChatAndReload(mod)
      end,
    }
  end

  StaticPopup_Show("PUI_CHAT_CHATTYNATOR_CHOICE", nil, nil, self)
end

local function _PUI_ShowPratChoicePopup(self)
  if not StaticPopupDialogs["PUI_CHAT_PRAT_CHOICE"] then
    StaticPopupDialogs["PUI_CHAT_PRAT_CHOICE"] = {
      text = "We see that you have Prat installed.\n\nPlease choose if you want to use PleebUI Chat or Prat.",
      button1 = "PleebUI",
      button2 = "Prat",
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnAccept = function(_, data)
        local mod = data

        local dbp = mod.db.profile
        dbp.manualDisabled = false
        dbp.enabled = true

        _PUI_GetChatConflictDB().prat = "pui"
        Addon:Print("|cffffcc00[PUI]|r PleebUI Chat selected. Please disable Prat in the AddOns list and /reload for best results.")
      end,
      OnCancel = function(_, data)
        local mod = data
        _PUI_ConfirmDisablePUIChatAndReload_PrAt(mod)
      end,
    }
  end

  StaticPopup_Show("PUI_CHAT_PRAT_CHOICE", nil, nil, self)
end


function ChatLinks:OnInitialize()
  self.db = Addon.db:RegisterNamespace("ChatLinks", {
    profile = {
      enabled         = true,   -- last runtime state (auto-managed)
      manualDisabled  = false,  -- user explicitly turned PleebUI Chat off
      enableUrlCopy   = true,   -- clickable URLs
      enableCopyFrame = true,   -- chat copy button + window
      enableChatTools = true,

      -- Copy behavior
      copyClean = false,       -- "Clean chat" inside copy window (strip colors/textures/links)

      -- Chat tweaks
      chatTweaks = {
        persistHistory = true,   -- persist chat history between sessions
        maxLines       = 500,    -- visible lines restored back into the chat frame
        savedLines     = 5000,
        scrollMessages = 3,
      },

      -- Chat formatting
      chatFormat = {
        timestamps = true,          -- use Blizzard timestamp prefix (before name)
        tsPreset   = "HM24",        -- "HM24","HMS24","HM12","HMS12"
        channelNumsOnly = false,    -- (disabled)
      },

      -- Edit Mode anchor for the Copy Chat window
      copyFrame = {
        point         = "CENTER",
        relativeTo    = "UIParent",
        relativePoint = "CENTER",
        x             = 0,
        y             = 0,

        -- Copy window size (persisted)
        w             = 600,
        h             = 350,
      },


      -- Copy window custom style (independent of Theme background/border colors)
      copyWindowStyle = {
        bg = { 0.05, 0.05, 0.05, 0.92 },     -- r,g,b,a
        border = { 0.20, 0.20, 0.20, 1.00 }, -- r,g,b,a
        borderSize = 1,                      -- pixels
      },

      -- Chat window shell style (independent of Theme preset colors)
      chatWindowStyle = {
        bg = { 0.05, 0.05, 0.05, 1.00 },     -- r,g,b,a (opaque like your current shell)
        border = { 0.20, 0.20, 0.20, 1.00 }, -- r,g,b,a
        borderSize = 1,                      -- pixels
      },

      chatTypography = {
        message = {
          useGlobalFont = true,
        },
        tab = {
          useGlobalFont = true,
        },
        input = {
          useGlobalFont = true,
        },
      },


      -- Edit Mode layout for the addon-owned primary chat holder.
      chatFrame1 = {
        point         = "BOTTOMLEFT",
        relativeTo    = "UIParent",
        relativePoint = "BOTTOMLEFT",
        x             = 32,
        y             = 32,
        width         = 430,
        height        = 180,
      },



      -- Chat fade behaviour for the *primary* chat frame only.
      chatFade = {
        enabled      = true,  -- master toggle
        activeAlpha  = 0.9,   -- when chatting / hovered
        idleAlpha    = 0.4,   -- when idle
        idleDelay    = 10,    -- seconds after focus lost before fading

        -- Smooth fade
        animate      = true,  -- master toggle for alpha interpolation
        fadeDuration = 1.25,  -- seconds to fade active -> idle
      },
    },
  })

  ns.Registry.EditModeParticipants.chat = self
end

local HISTORY_VERSION = 2
local HISTORY_TRIM_BUFFER = 128

local function ApplyChatTweaks(atPlayerEnteringWorld)
  if not ChatLinks or not ChatLinks.db or not ChatLinks.db.profile or not ChatLinks.db.profile.chatTweaks then
    return
  end

  if InCombatLockdown() and atPlayerEnteringWorld ~= true then
    ChatLinks._puiPendingChatTweaks = true
    return
  end

  ChatLinks._puiPendingChatTweaks = nil

  local t = ChatLinks.db.profile.chatTweaks

  local maxLines = tonumber(t.maxLines) or 500
  if maxLines < 128 then maxLines = 128 end
  if maxLines > 5000 then maxLines = 5000 end

  ForEachBlizzardChatFrame(function(chatFrame)
    if chatFrame.SetMaxLines then
      chatFrame:SetMaxLines(maxLines)
    end
  end)
end

local function GetNewLog()
  return { current = {}, version = HISTORY_VERSION, cleanIndex = 0 }
end

local function _PUI_GetPersistentHistoryDB()
  Addon.db.global = Addon.db.global or {}
  Addon.db.global.chatHistoryLog = Addon.db.global.chatHistoryLog or GetNewLog()

  local log = Addon.db.global.chatHistoryLog
  if type(log) ~= "table" then
    log = GetNewLog()
    Addon.db.global.chatHistoryLog = log
  elseif log.version ~= HISTORY_VERSION or type(log.current) ~= "table" then
    local current = type(log.current) == "table" and log.current or {}
    log = {
      current = current,
      version = HISTORY_VERSION,
      cleanIndex = tonumber(log.cleanIndex) or 0,
    }
    Addon.db.global.chatHistoryLog = log
  end

  log.cleanIndex = tonumber(log.cleanIndex) or 0

  return log
end

local function _PUI_GetHistoryOptions()
  local db = ChatLinks and ChatLinks.db and ChatLinks.db.profile
  if not db then
    return nil
  end

  db.chatTweaks = db.chatTweaks or {}

  local t = db.chatTweaks
  if t.persistHistory == nil then t.persistHistory = true end
  if t.maxLines == nil then t.maxLines = 500 end
  if t.savedLines == nil then t.savedLines = 5000 end
  if t.scrollMessages == nil then t.scrollMessages = 3 end

  return t
end

local function _PUI_CleanStore(store, index)
  if type(store) ~= "table" then
    return 0
  end

  if #store <= index then
    return #store
  end

  for i = index + 1, #store do
    local data = store[i]
    if type(data) == "table" and type(data.text) == "string" then
      if data.text:find("|K.-|k") or (data.typeInfo and data.typeInfo.player and type(data.typeInfo.player.name) == "string" and data.typeInfo.player.name:find("|K.-|k")) then
        data.text = data.text:gsub("|K.-|k", "???")
        data.text = data.text:gsub("|HBNplayer.-|h(.-)|h", "%1")
        if data.typeInfo and data.typeInfo.player and type(data.typeInfo.player.name) == "string" then
          data.typeInfo.player.name = data.typeInfo.player.name:gsub("|K.-|k", "UNKNOWN")
        end
      end

      if data.text:find("censoredmessage:") then
        data.text = data.text:gsub("|Hcensoredmessage:.-|h.-|h", "[CENSORED]")
      end

      if data.text:find("reportcensoredmessage:") then
        data.text = data.text:gsub("|Hreportcensoredmessage:.-|h.-|h", "[???]")
      end
    end
  end

  return #store
end

local function _PUI_GetHistoryState()
  if ChatLinks._puiHistoryState then
    return ChatLinks._puiHistoryState
  end

  local log = _PUI_GetPersistentHistoryDB()
  if not log then
    return nil
  end

  if log.cleanIndex <= #log.current then
    log.cleanIndex = _PUI_CleanStore(log.current, log.cleanIndex)
  end

  local state = {
    messages = log.current,
    messageCount = #log.current,
    bootstrapped = false,
  }

  ChatLinks._puiHistoryState = state
  return state
end

local function _PUI_TrimHistoryState(state, force)
  local t = _PUI_GetHistoryOptions()
  if not state or not t then
    return
  end

  local limit = ClampInt(t.savedLines, 128, 20000)
  local threshold = limit + (force and 0 or HISTORY_TRIM_BUFFER)
  if state.messageCount <= threshold then
    return
  end

  if InCombatLockdown() then
    ChatLinks._puiPendingHistoryReduce = true
    return
  end

  local oldMessages = state.messages
  local newMessages = {}
  local first = state.messageCount - limit + 1
  for i = first, state.messageCount do
    newMessages[#newMessages + 1] = oldMessages[i]
  end

  state.messages = newMessages
  state.messageCount = #newMessages

  local log = _PUI_GetPersistentHistoryDB()
  log.current = newMessages
  log.cleanIndex = _PUI_CleanStore(newMessages, 0)
  ChatLinks._puiPendingHistoryReduce = nil
end

local function _PUI_AddOwnedMessage(text, r, g, b)
  if ChatLinks.db.profile.chatTweaks.persistHistory == false then
    return
  end

  if issecretvalue(text)
    or issecretvalue(r)
    or issecretvalue(g)
    or issecretvalue(b)
  then
    return
  end

  if type(text) ~= "string" then
    return
  end

  if text == "" then
    return
  end

  local state = _PUI_GetHistoryState()
  if not state then
    return
  end

  local data = {
    text = text,
    color = { r = r or 1, g = g or 1, b = b or 1 },
    timestamp = time(),
  }

  state.messageCount = state.messageCount + 1
  state.messages[state.messageCount] = data
  local log = _PUI_GetPersistentHistoryDB()
  log.cleanIndex = _PUI_CleanStore(state.messages, log.cleanIndex)
  _PUI_TrimHistoryState(state, false)
end

local function _PUI_ClearSavedHistory()
  local log = _PUI_GetPersistentHistoryDB()
  wipe(log.current)
  log.cleanIndex = 0

  ChatLinks._puiHistoryState = {
    messages = log.current,
    messageCount = 0,
    bootstrapped = true,
  }
  ChatLinks._puiPendingHistoryReduce = nil
end

local function _PUI_GetRenderableMessages()
  local t = _PUI_GetHistoryOptions()
  if not t or t.persistHistory == false then
    return {}
  end

  local state = _PUI_GetHistoryState()
  if not state then
    return {}
  end

  local maxLines = tonumber(t.maxLines) or 500
  if maxLines < 1 then
    maxLines = 1
  end

  if state.messageCount <= maxLines then
    return state.messages
  end

  local trimmed = {}
  for i = state.messageCount - maxLines + 1, state.messageCount do
    trimmed[#trimmed + 1] = state.messages[i]
  end

  return trimmed
end

local function _PUI_CaptureExistingDefaultChatFrame()
  local cf = _G.DEFAULT_CHAT_FRAME
  if not cf or not cf.GetNumMessages or not cf.GetMessageInfo then
    return
  end

  ChatLinks._puiHistoryCapturingStartup = true

  local messageCount = cf:GetNumMessages()
  if issecretvalue(messageCount) or type(messageCount) ~= "number" then
    ChatLinks._puiHistoryCapturingStartup = nil
    return
  end

  for i = 1, messageCount do
    local text, r, g, b = cf:GetMessageInfo(i)
    _PUI_AddOwnedMessage(text, r, g, b)
  end

  ChatLinks._puiHistoryCapturingStartup = nil
end

local function _PUI_RenderHistoryIntoDefaultFrame()
  local cf = _G.DEFAULT_CHAT_FRAME
  if not cf or not cf.AddMessage then
    return
  end

  local renderMessages = _PUI_GetRenderableMessages()

  ChatLinks._puiHistoryRendering = true

  if cf.Clear then
    cf:Clear()
  end

  for _, entry in ipairs(renderMessages) do
    local color = entry.color or {}
    cf:AddMessage(entry.text, color.r or 1, color.g or 1, color.b or 1)
  end

  ChatLinks._puiHistoryRendering = nil
end

local _PUI_InstallPersistentHistoryHook

local function _PUI_IsChatRuntimeEnabled()
  local db = ChatLinks.db.profile

  if db.manualDisabled or db.enabled == false then
    return false
  end

  local cdb = _PUI_GetChatConflictDB()
  if _PUI_IsChattynatorLoaded() and cdb.chattynator == "chattynator" then
    return false
  end

  if _PUI_IsPratLoaded() and cdb.prat == "prat" then
    return false
  end

  return true
end

local function _PUI_RefreshChatRuntimeState()
  ChatLinks._puiRuntimeEnabled = _PUI_IsChatRuntimeEnabled()
  return ChatLinks._puiRuntimeEnabled
end

local function _PUI_BootHistoryOwner()
  if ChatLinks._puiRuntimeEnabled ~= true or _PUI_IsChatMessagingRestricted() then
    return
  end

  local t = _PUI_GetHistoryOptions()
  if not t or t.persistHistory == false then
    return
  end

  local state = _PUI_GetHistoryState()
  if not state or state.bootstrapped then
    return
  end

  state.bootstrapped = true

  _PUI_CaptureExistingDefaultChatFrame()
  _PUI_InstallPersistentHistoryHook()
  _PUI_RenderHistoryIntoDefaultFrame()
end

_PUI_InstallPersistentHistoryHook = function()
  if ChatLinks.__puiPersistentHistoryHooked then
    return
  end

  local cf = _G.DEFAULT_CHAT_FRAME
  if not cf then
    return
  end

  ChatLinks.__puiPersistentHistoryHooked = true

  hooksecurefunc(cf, "AddMessage", function(_, text, r, g, b)
    if ChatLinks._puiRuntimeEnabled ~= true then
      return
    end

    if ChatLinks._puiHistoryRendering or ChatLinks._puiHistoryCapturingStartup then
      return
    end

    _PUI_AddOwnedMessage(text, r, g, b)
  end)
end


local _PUI_GetTypographyDB

local function ChatProvider(AddonObj)
  local provider = {}

  local _puiChatFadeQueued = false
  local function ApplyFadeNow()
    if _puiChatFadeQueued then
      return
    end
    _puiChatFadeQueued = true

    C_Timer.After(0, function()
      _puiChatFadeQueued = false
      ChatLinks:ApplyInitialFade()
    end)
  end


  local function _EnsureCopyStyleDB(db)
    db.copyWindowStyle = db.copyWindowStyle or {}
    db.copyWindowStyle.bg = db.copyWindowStyle.bg or { 0.05, 0.05, 0.05, 0.92 }
    db.copyWindowStyle.border = db.copyWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
    if db.copyWindowStyle.borderSize == nil then
      db.copyWindowStyle.borderSize = 1
    end
  end

  local _puiCopyStyleQueued = false
  local function _ApplyCopyStyleLive()
    if _puiCopyStyleQueued then
      return
    end
    _puiCopyStyleQueued = true

    C_Timer.After(0, function()
      _puiCopyStyleQueued = false
      ChatLinks:ApplyCopyWindowStyle()
    end)
  end


  function provider:GetOptions()
    local db = ChatLinks.db.profile
    db.chatFade = db.chatFade or {}
    db.chatTweaks = db.chatTweaks or {}
    db.chatFormat = db.chatFormat or {}
    db.chatWindowStyle = db.chatWindowStyle or {}
    db.chatWindowStyle.bg = db.chatWindowStyle.bg or { 0.05, 0.05, 0.05, 1.00 }
    db.chatWindowStyle.border = db.chatWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
    if db.chatWindowStyle.borderSize == nil then
      db.chatWindowStyle.borderSize = 1
    end

    _EnsureCopyStyleDB(db)
    local typography = _PUI_GetTypographyDB()

    local t = db.chatTweaks
    if t.persistHistory == nil then t.persistHistory = true end
    if t.maxLines == nil then t.maxLines = 500 end
    if t.savedLines == nil then t.savedLines = 5000 end
    if t.scrollMessages == nil then t.scrollMessages = 3 end

    local f = db.chatFormat
    if f.timestamps == nil then f.timestamps = true end
    if f.tsPreset ~= "HM24" and f.tsPreset ~= "HMS24" and f.tsPreset ~= "HM12" and f.tsPreset ~= "HMS12" then
      f.tsPreset = "HM24"
    end

    local function IsLocked()
      local cdb = _PUI_GetChatConflictDB()

      local chattyChoice = cdb.chattynator
      local chattyLoaded = _PUI_IsChattynatorLoaded()
      local lockedForChatty = chattyLoaded and (chattyChoice == "chattynator")

      local pratChoice = cdb.prat
      local pratLoaded = _PUI_IsPratLoaded()
      local lockedForPrat = pratLoaded and (pratChoice == "prat")

      return lockedForChatty or lockedForPrat
    end

    local function GetLockedAddonName()
      local cdb = _PUI_GetChatConflictDB()

      local chattyChoice = cdb.chattynator
      local chattyLoaded = _PUI_IsChattynatorLoaded()
      if chattyLoaded and chattyChoice == "chattynator" then
        return "Chattynator"
      end

      local pratChoice = cdb.prat
      local pratLoaded = _PUI_IsPratLoaded()
      if pratLoaded and pratChoice == "prat" then
        return "Prat"
      end

      return nil
    end

    local function Clamp01(x)
      x = tonumber(x) or 0
      if x < 0 then x = 0 end
      if x > 1 then x = 1 end
      return x
    end

    local function ClampRange(x, minv, maxv)
      x = tonumber(x) or minv
      if x < minv then x = minv end
      if x > maxv then x = maxv end
      return x
    end

    local function TsPreview(preset)
      if preset == "HMS24" then
        return date("%H:%M:%S")
      elseif preset == "HM12" then
        return date("%I:%M %p")
      elseif preset == "HMS12" then
        return date("%I:%M:%S %p")
      else
        return date("%H:%M")
      end
    end

    local function ApplyTypographyNow()
      ChatLinks:ApplyChatTypography()
    end

    local function BuildTypographyControls(areaKey)
      local area = typography[areaKey]
      return {
        useGlobalFont = {
          type = "toggle",
          name = "Use global font",
          order = 1,
          disabled = IsLocked,
          get = function()
            return area.useGlobalFont == true
          end,
          set = function(_, value)
            area.useGlobalFont = value == true
            ApplyTypographyNow()
          end,
        },
        font = {
          type = "select",
          name = "Font",
          order = 2,
          dialogControl = "LSM30_Font",
          values = function()
            return OptionsUtil.BuildFontValues(false)
          end,
          disabled = function()
            return IsLocked() or area.useGlobalFont == true
          end,
          get = function()
            return OptionsUtil.ResolveFontKey(area.font, false)
          end,
          set = function(_, value)
            area.font = value
            ApplyTypographyNow()
          end,
        },
        outline = {
          type = "select",
          name = "Outline",
          order = 3,
          values = function()
            return OptionsUtil.BuildOutlineValues(true, "Use global outline", ns.Theme.STANDARD_OUTLINE_KEY)
          end,
          disabled = IsLocked,
          get = function()
            return OptionsUtil.GetStoredOutlineValue(area.outline, ns.Theme.STANDARD_OUTLINE_KEY)
          end,
          set = function(_, value)
            area.outline = OptionsUtil.SetStoredOutlineValue(value, ns.Theme.STANDARD_OUTLINE_KEY)
            ApplyTypographyNow()
          end,
        },
      }
    end

    local options = {
      type = "group",
      name = "Chat",
      args = {
        status = {
          type = "group",
          name = "Status",
          order = 1,
          args = {
            lockedNote = {
              type = "description",
              order = 1,
              hidden = function()
                return not IsLocked()
              end,
              name = function()
                local name = GetLockedAddonName() or "Another addon"
                return "|cffff8888" .. name .. " is currently enabled.|r\nDisable " .. name .. " in the AddOns list to use PleebUI Chat."
              end,
            },
          },
        },

        features = {
          type = "group",
          name = "Features",
          order = 2,
          args = {
            enabled = {
              type = "toggle",
              name = "Enable PleebUI Chat",
              order = 1,

              disabled = function()
                return IsLocked()
              end,
              get = function()
                return not db.manualDisabled
              end,
              set = function(_, v)
                v = not not v
                db.manualDisabled = not v
                db.enabled = v

                if v and _PUI_IsChattynatorLoaded() then
                  _PUI_GetChatConflictDB().chattynator = "ask"
                  _PUI_RefreshChatRuntimeState()
                  _PUI_ShowChattynatorChoicePopup(ChatLinks)
                  return
                end

                if v and _PUI_IsPratLoaded() then
                  _PUI_GetChatConflictDB().prat = "ask"
                  _PUI_RefreshChatRuntimeState()
                  _PUI_ShowPratChoicePopup(ChatLinks)
                  return
                end

                _PUI_RefreshChatRuntimeState()
                ChatLinks:SetUrlFiltersEnabled(
                  ChatLinks._puiRuntimeEnabled == true and db.enableUrlCopy == true
                )

                local doReload = function()
                  if InCombatLockdown() then
                    Addon:Print("|cffff4444[PUI]|r Cannot reload while in combat.")
                    return
                  end
                  ReloadUI()
                end

                Addon:PUI_ConfirmAction({
                  title = "Reload required",
                  text = "Chat changes require a reload to fully apply.",
                  yesText = "Reload",
                  noText = CANCEL,
                  onYes = doReload,
                })
              end,
            },

            clickableUrls = {
              type = "toggle",
              name = "Clickable URLs",
              order = 2,

              disabled = function()
                return IsLocked()
              end,
              get = function()
                return not not db.enableUrlCopy
              end,
              set = function(_, v)
                db.enableUrlCopy = not not v
                ChatLinks:SetUrlFiltersEnabled(db.enableUrlCopy and ChatLinks._puiRuntimeEnabled == true)
              end,
            },

            copyWindow = {
              type = "toggle",
              name = "Copy button and window",
              order = 3,

              disabled = function()
                return IsLocked()
              end,
              get = function()
                return not not db.enableCopyFrame
              end,
              set = function(_, v)
                db.enableCopyFrame = not not v
                ChatLinks:RefreshChatFrames()
              end,
            },

            chatTools = {
              type = "toggle",
              name = "Compact chat tools",
              order = 4,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                return db.enableChatTools == true
              end,
              set = function(_, value)
                db.enableChatTools = value == true
                ChatLinks:RefreshChatFrames()
              end,
            },
          },
        },

        copyStyle = {
          type = "group",
          name = "Copy window",
          order = 3,
          args = {
            behavior = {
              type = "group",
              name = "Behavior",
              inline = true,
              order = 1,
              args = {
                clean = {
                  type = "toggle",
                  name = "Clean copied text",
                  desc = "Remove colors, textures, and link payloads while keeping readable link text.",
                  order = 1,
                  disabled = IsLocked,
                  get = function()
                    return db.copyClean == true
                  end,
                  set = function(_, value)
                    db.copyClean = value == true
                    ChatLinks:RefreshCopyWindow()
                  end,
                },
              },
            },
            appearance = {
              type = "group",
              name = "Appearance",
              inline = true,
              order = 2,
              args = {
                bg = {
                  type = "color",
                  name = "Background color",
                  order = 1,
                  hasAlpha = true,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    local c = db.copyWindowStyle.bg or { 0, 0, 0, 0.85 }
                    return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
                  end,
                  set = function(_, r, g, b, a)
                    db.copyWindowStyle.bg = { r, g, b, a }
                    _ApplyCopyStyleLive()
                  end,
                },

                border = {
                  type = "color",
                  name = "Border color",
                  order = 2,
                  hasAlpha = true,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    local c = db.copyWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
                    return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
                  end,
                  set = function(_, r, g, b, a)
                    db.copyWindowStyle.border = { r, g, b, a }
                    _ApplyCopyStyleLive()
                  end,
                },

                borderSize = {
                  type = "range",
                  name = "Border size",
                  order = 3,
                  min = 0,
                  max = 8,
                  step = 1,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return tonumber(db.copyWindowStyle.borderSize) or 2
                  end,
                  set = function(_, val)
                    db.copyWindowStyle.borderSize = math.floor(tonumber(val) or 2)
                    _ApplyCopyStyleLive()
                  end,
                },
              },
            },
            size = {
              type = "group",
              name = "Size",
              inline = true,
              order = 3,
              args = {
                width = {
                  type = "range",
                  name = "Width",
                  order = 4,
                  min = 320,
                  max = 1200,
                  step = 10,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return tonumber((db.copyFrame and db.copyFrame.w) or 600) or 600
                  end,
                  set = function(_, val)
                    db.copyFrame = db.copyFrame or {}
                    db.copyFrame.w = ClampInt(val, 320, 1200)
                    if CopyFrame and CopyFrame.SetSize then
                      local _, h = CopyFrame:GetSize()
                      CopyFrame:SetSize(db.copyFrame.w, h)
                    end
                  end,
                },

                height = {
                  type = "range",
                  name = "Height",
                  order = 5,
                  min = 180,
                  max = 900,
                  step = 10,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return tonumber((db.copyFrame and db.copyFrame.h) or 350) or 350
                  end,
                  set = function(_, val)
                    db.copyFrame = db.copyFrame or {}
                    db.copyFrame.h = ClampInt(val, 180, 900)
                    if CopyFrame and CopyFrame.SetSize then
                      local w = CopyFrame:GetWidth()
                      CopyFrame:SetSize(w, db.copyFrame.h)
                    end
                  end,
                },
              },
            },
          },
        },

        chatStyle = {
          type = "group",
          name = "Chat window",
          order = 4,
          args = {
            bg = {
              type = "color",
              name = "Chat background",
              order = 1,
              hasAlpha = true,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                local c = db.chatWindowStyle.bg or { 0.05, 0.05, 0.05, 1.00 }
                return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
              end,
              set = function(_, r, g, b, a)
                db.chatWindowStyle.bg = { r, g, b, a }
                ChatLinks:ApplyChatWindowStyle()
              end,
            },

            border = {
              type = "color",
              name = "Chat border",
              order = 2,
              hasAlpha = true,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                local c = db.chatWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
                return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
              end,
              set = function(_, r, g, b, a)
                db.chatWindowStyle.border = { r, g, b, a }
                ChatLinks:ApplyChatWindowStyle()
              end,
            },

            borderSize = {
              type = "range",
              name = "Chat border size",
              order = 3,
              min = 0,
              max = 8,
              step = 1,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                return tonumber(db.chatWindowStyle.borderSize) or 1
              end,
              set = function(_, val)
                db.chatWindowStyle.borderSize = math.floor(tonumber(val) or 1)
                ChatLinks:ApplyChatWindowStyle()
              end,
            },
          },
        },

        formatting = {
          type = "group",
          name = "Formatting",
          order = 5,
          args = {
            timestamps = {
              type = "toggle",
              name = "Timestamps",
              order = 1,

              disabled = function()
                return IsLocked()
              end,
              get = function()
                return not not f.timestamps
              end,
              set = function(_, v)
                f.timestamps = not not v
                ChatLinks:ApplyChatFormatting()
              end,
            },

            tsPreset = {
              type = "select",
              name = "Timestamp format",
              order = 2,
              disabled = function()
                return IsLocked()
              end,
              values = {
                HM24 = TsPreview("HM24") .. " (default)",
                HMS24 = TsPreview("HMS24"),
                HM12 = TsPreview("HM12"),
                HMS12 = TsPreview("HMS12"),
              },
              get = function()
                return f.tsPreset or "HM24"
              end,
              set = function(_, key)
                if key ~= "HM24" and key ~= "HMS24" and key ~= "HM12" and key ~= "HMS12" then
                  key = "HM24"
                end
                f.tsPreset = key
                ChatLinks:ApplyChatFormatting()
              end,
            },
          },
        },

        typography = {
          type = "group",
          name = "Typography",
          order = 6,
          args = {
            message = {
              type = "group",
              name = "Chat text",
              inline = true,
              order = 1,
              args = BuildTypographyControls("message"),
            },
            tab = {
              type = "group",
              name = "Tabs",
              inline = true,
              order = 2,
              args = BuildTypographyControls("tab"),
            },
            input = {
              type = "group",
              name = "Input",
              inline = true,
              order = 3,
              args = BuildTypographyControls("input"),
            },
          },
        },

        fade = {
          type = "group",
          name = "Fade",
          order = 7,
          args = {
            behavior = {
              type = "group",
              name = "Behavior",
              inline = true,
              order = 1,
              args = {
                enabled = {
                  type = "toggle",
                  name = "Enable fade",
                  order = 1,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return not not db.chatFade.enabled
                  end,
                  set = function(_, v)
                    db.chatFade.enabled = not not v
                    ApplyFadeNow()
                  end,
                },

                animate = {
                  type = "toggle",
                  name = "Animate fade",
                  order = 2,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return not not db.chatFade.animate
                  end,
                  set = function(_, v)
                    db.chatFade.animate = not not v
                    ApplyFadeNow()
                  end,
                },

                applyNow = {
                  type = "execute",
                  name = "Apply now",
                  order = 3,
                  disabled = function()
                    return IsLocked()
                  end,
                  func = function()
                    ApplyFadeNow()
                  end,
                },
              },
            },
            opacity = {
              type = "group",
              name = "Opacity",
              inline = true,
              order = 2,
              args = {
                activeAlpha = {
                  type = "range",
                  name = "Active background opacity",
                  order = 4,
                  min = 0,
                  max = 1,
                  step = 0.01,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return Clamp01(db.chatFade.activeAlpha or 0.9)
                  end,
                  set = function(_, val)
                    db.chatFade.activeAlpha = Clamp01(val)
                    ChatLinks:ChatInputActivated(_G.ChatFrame1)
                  end,
                },

                idleAlpha = {
                  type = "range",
                  name = "Idle background opacity",
                  order = 5,
                  min = 0,
                  max = 1,
                  step = 0.01,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return Clamp01(db.chatFade.idleAlpha or 0.4)
                  end,
                  set = function(_, val)
                    db.chatFade.idleAlpha = Clamp01(val)
                    ApplyFadeNow()
                  end,
                },
              },
            },
            timing = {
              type = "group",
              name = "Timing",
              inline = true,
              order = 3,
              args = {
                idleDelay = {
                  type = "range",
                  name = "Idle delay",
                  order = 6,
                  min = 0,
                  max = 60,
                  step = 1,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return ClampRange(db.chatFade.idleDelay or 10, 0, 60)
                  end,
                  set = function(_, val)
                    db.chatFade.idleDelay = ClampRange(val, 0, 60)
                    ApplyFadeNow()
                  end,
                },

                fadeDuration = {
                  type = "range",
                  name = "Background fade time",
                  order = 7,
                  min = 0,
                  max = 5,
                  step = 0.05,
                  disabled = function()
                    return IsLocked()
                  end,
                  get = function()
                    return ClampRange(db.chatFade.fadeDuration or 1.25, 0, 5)
                  end,
                  set = function(_, val)
                    db.chatFade.fadeDuration = ClampRange(val, 0, 5)
                    ApplyFadeNow()
                  end,
                },

              },
            },
          },
        },

        tweaks = {
          type = "group",
          name = "Chat tweaks",
          order = 8,
          args = {
            persistHistory = {
              type = "toggle",
              name = "Persistent chat history",
              order = 1,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                return not not t.persistHistory
              end,
              set = function(_, v)
                t.persistHistory = not not v
                if t.persistHistory then
                  _PUI_BootHistoryOwner()
                end
              end,
            },

            maxLines = {
              type = "range",
              name = "Max visible chat lines",
              order = 2,
              min = 128,
              max = 5000,
              step = 64,
              disabled = function()
                return IsLocked()
              end,
              get = function()
                return tonumber(t.maxLines) or 500
              end,
              set = function(_, v)
                t.maxLines = math.floor(tonumber(v) or 500)
                ApplyChatTweaks()
              end,
            },

            savedLines = {
              type = "range",
              name = "Saved history lines",
              order = 3,
              min = 128,
              max = 20000,
              step = 128,
              disabled = function()
                return IsLocked() or t.persistHistory == false
              end,
              get = function()
                return ClampInt(t.savedLines, 128, 20000)
              end,
              set = function(_, value)
                t.savedLines = ClampInt(value, 128, 20000)
                _PUI_TrimHistoryState(_PUI_GetHistoryState(), true)
              end,
            },

            scrollMessages = {
              type = "range",
              name = "Mouse wheel lines",
              order = 4,
              min = 1,
              max = 12,
              step = 1,
              disabled = IsLocked,
              get = function()
                return ClampInt(t.scrollMessages, 1, 12)
              end,
              set = function(_, value)
                t.scrollMessages = ClampInt(value, 1, 12)
              end,
            },

            clearHistory = {
              type = "execute",
              name = "Clear saved history",
              order = 5,
              disabled = function()
                return IsLocked() or t.persistHistory == false
              end,
              func = function()
                Addon:PUI_ConfirmAction({
                  title = "Clear saved chat history?",
                  text = "This permanently removes PleebUI's saved chat history.",
                  yesText = "Clear",
                  noText = CANCEL,
                  onYes = function()
                    _PUI_ClearSavedHistory()
                    ChatLinks:RefreshCopyWindow()
                  end,
                })
              end,
            },
          },
        },
      },
    }

    local sections = options.args or {}
    local statusGroup = sections.status or {}
    local featuresGroup = sections.features or {}
    local statusArgs = statusGroup.args or {}
    local featureArgs = featuresGroup.args or {}

    local topLine = {
      type = "group",
      name = "",
      inline = true,
      order = 1,
      args = {},
    }

    if statusArgs.lockedNote then
      statusArgs.lockedNote.order = 1
      topLine.args.lockedNote = statusArgs.lockedNote
    end

    if featureArgs.enabled then
      featureArgs.enabled.order = 10

      topLine.args.enabled = featureArgs.enabled
    end

    if featureArgs.clickableUrls then
      featureArgs.clickableUrls.order = 20

      topLine.args.clickableUrls = featureArgs.clickableUrls
    end

    if featureArgs.copyWindow then
      featureArgs.copyWindow.order = 30

      topLine.args.copyWindow = featureArgs.copyWindow
    end

    if featureArgs.chatTools then
      featureArgs.chatTools.order = 40
      topLine.args.chatTools = featureArgs.chatTools
    end

    local pages = {
      type = "group",
      name = "",
      order = 20,
      inline = true,
      childGroups = "tree",
      args = {},
    }

    if sections.copyStyle then
      sections.copyStyle.order = 10
      pages.args.copyStyle = sections.copyStyle
    end

    if sections.chatStyle then
      sections.chatStyle.order = 20
      pages.args.chatStyle = sections.chatStyle
    end

    if sections.formatting then
      sections.formatting.order = 30
      pages.args.formatting = sections.formatting
    end

    if sections.typography then
      sections.typography.order = 40
      pages.args.typography = sections.typography
    end

    if sections.fade then
      sections.fade.order = 50
      pages.args.fade = sections.fade
    end

    if sections.tweaks then
      sections.tweaks.order = 60
      pages.args.tweaks = sections.tweaks
    end

    options.childGroups = nil
    options.args = {
      topLine = topLine,
      pages = pages,
    }

    return options
  end

  return provider
end

Addon:RegisterOptionsSection("Chat", ChatProvider, 60, "Chat", nil, {
  preview = false,
})




local InitializePrimaryChatLayout

local ChatTweaksBoot = CreateFrame("Frame", "PleebUI_ChatTweaksBoot")
ChatTweaksBoot:RegisterEvent("PLAYER_ENTERING_WORLD")
ChatTweaksBoot:RegisterEvent("PLAYER_LOGIN")
ChatTweaksBoot:RegisterEvent("PLAYER_REGEN_ENABLED")
ChatTweaksBoot:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    if _PUI_RefreshChatRuntimeState() then
      InitializePrimaryChatLayout()
      ChatLinks:RefreshChatFrames(true)
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    if _PUI_RefreshChatRuntimeState() then
      _PUI_BootHistoryOwner()
    end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    if ChatLinks._puiRuntimeEnabled == true then
      _PUI_BootHistoryOwner()
      ChatLinks:RefreshChatFrames()
    end

    if ChatLinks._puiPendingHistoryReduce then
      ChatLinks._puiPendingHistoryReduce = nil

      if ChatLinks._puiRuntimeEnabled ~= true then
        return
      end

      _PUI_TrimHistoryState(_PUI_GetHistoryState(), true)
    end
  end
end)


local URL_PROTOCOL_REPLACEMENT = "|cff00ccff|Haddon:pleebuiurl:%1|h[%1]|h|r"
local URL_HTTP_REPLACEMENT = "|cff00ccff|Haddon:pleebuiurl:http://%1|h[%1]|h|r"
local URL_HTTPS_REPLACEMENT = "|cff00ccff|Haddon:pleebuiurl:https://%1|h[%1]|h|r"
local URL_MAILTO_REPLACEMENT = "|cff00ccff|Haddon:pleebuiurl:mailto:%1|h[%1]|h|r"

local _PUI_OnSetItemRef

local function _SafeLinkify(msg, hasProtocol, hasWWW, hasDiscord, hasEmail, hasBareDomain)
  local s = msg

  if hasProtocol then
    s = s:gsub("%f[%S]([%a][%w+.-]*://%S+)", URL_PROTOCOL_REPLACEMENT)
  end

  if hasWWW then
    s = s:gsub("%f[%S](www%.[-%w_%%]+%.[%a%a]+/%S+)", URL_HTTP_REPLACEMENT)
    s = s:gsub("%f[%S](www%.[-%w_%%]+%.[%a%a]+)", URL_HTTP_REPLACEMENT)
  end

  if hasDiscord then
    s = s:gsub("%f[%S](discord%.gg/%S+)", URL_HTTPS_REPLACEMENT)
  end

  if hasEmail then
    s = s:gsub("%f[%S]([%w%._%%%-]+@[%w%._%%%-]+%.[%a%a]+)", URL_MAILTO_REPLACEMENT)
  end

  if hasBareDomain then
    s = s:gsub("%f[%S]([-%w_%%]+%.[%a%a]+/%S+)", URL_HTTP_REPLACEMENT)
  end

  return s
end

local function _PUI_UrlMessageFilter(chatFrame, _, msg, ...)
  if ChatLinks._puiRuntimeEnabled ~= true
    or ChatLinks.db.profile.enableUrlCopy ~= true
    or _PUI_IsChatMessagingRestricted()
    or chatFrame == _G.ChatFrame2
  then
    return
  end

  if not _PUI_AreChatArgumentsAccessible(msg, ...) or type(msg) ~= "string" then
    return
  end

  local hasProtocol = msg:find("://", 1, true) ~= nil
  local hasWWW = msg:find("www.", 1, true) ~= nil
  local hasDiscord = msg:find("discord.gg/", 1, true) ~= nil
  local hasEmail = msg:find("@", 1, true) ~= nil
  local hasBareDomain = false

  if msg:find(".", 1, true) and msg:find("/", 1, true) then
    hasBareDomain = msg:find("%f[%S][-%w_%%]+%.[%a%a]+/%S+") ~= nil
  end

  if (hasProtocol or hasWWW or hasDiscord or hasEmail or hasBareDomain)
    and not msg:find("|Haddon:pleebuiurl:", 1, true)
  then
    return false, _SafeLinkify(msg, hasProtocol, hasWWW, hasDiscord, hasEmail, hasBareDomain), ...
  end
end

function ChatLinks:SetUrlFiltersEnabled(enabled)
  enabled = enabled == true

  if enabled == (self.__puiUrlFiltersEnabled == true) then
    return
  end

  self.__puiUrlFiltersEnabled = enabled

  for event in pairs(_G.ChatTypeGroupInverted) do
    if event:sub(1, 8) == "CHAT_MSG" then
      if enabled then
        ChatFrameUtil.AddMessageEventFilter(event, _PUI_UrlMessageFilter)
      else
        ChatFrameUtil.RemoveMessageEventFilter(event, _PUI_UrlMessageFilter)
      end
    end
  end

  if enabled then
    EventRegistry:RegisterCallback("SetItemRef", _PUI_OnSetItemRef, self)
  else
    EventRegistry:UnregisterCallback("SetItemRef", self)
  end
end



local function _PUI_CF_GetFormatDB()
  local db = ChatLinks.db.profile
  db.chatFormat = db.chatFormat or {}
  local f = db.chatFormat

  if f.timestamps == nil then f.timestamps = true end

  if f.tsPreset ~= "HM24" and f.tsPreset ~= "HMS24" and f.tsPreset ~= "HM12" and f.tsPreset ~= "HMS12" then
    f.tsPreset = "HM24"
  end

  return f
end


local function _PUI_CF_SetShowTimestamps(fmt)
  -- Blizzard shows the timestamp prefix before the name/prefix.
  -- Add a trailing space so it does not glue to the next token.
  local preset = fmt and fmt.tsPreset or "HM24"
  local cvar = "none"

  if fmt and fmt.timestamps then
    if preset == "HMS24" then
      cvar = "[%H:%M:%S] "
    elseif preset == "HM12" then
      cvar = "[%I:%M %p] "
    elseif preset == "HMS12" then
      cvar = "[%I:%M:%S %p] "
    else
      cvar = "[%H:%M] "
    end
  end

  C_CVar.SetCVar("showTimestamps", cvar)
end

function ChatLinks:ApplyChatFormatting()
  if not self.db or not self.db.profile then return end
  local fmt = _PUI_CF_GetFormatDB()
  if not fmt then return end

  -- Apply Blizzard timestamps (before name)
  _PUI_CF_SetShowTimestamps(fmt)
end


local UrlPopupFrame
local UrlPopupEditBox

local function EnsureUrlPopupFrame()
  if UrlPopupFrame and UrlPopupFrame.IsObjectType and UrlPopupFrame:IsObjectType("Frame") then
    return UrlPopupFrame
  end

  local f = CreateFrame("Frame", "PleebUI_UrlCopyFrame", UIParent, "BackdropTemplate")
  UrlPopupFrame = f

  f:SetSize(460, 120)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(9999)
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)

  ns.Theme.WidgetSkins.Frame(f)


  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetPoint("RIGHT", -16, 0)
  title:SetJustifyH("LEFT")
  title:SetText("Copy URL (Ctrl+C)")
  f._title = title

  local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  edit:SetAutoFocus(true)
  edit:SetMultiLine(false)
  edit:SetSize(410, 20)
  edit:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
  edit:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  edit:SetScript("OnEscapePressed", function()
    f:Hide()
  end)
  UrlPopupEditBox = edit

  local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btn:SetSize(120, 24)
  btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  btn:SetText(OKAY)

  ns.Theme.WidgetSkins.UIButton(btn)


  btn:SetScript("OnClick", function()
    f:Hide()
  end)

  f:Hide()
  return f
end

local function ShowUrlPopup(url)
  local f = EnsureUrlPopupFrame()
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:Show()

  if UrlPopupEditBox then
    UrlPopupEditBox:SetText(url or "")
    UrlPopupEditBox:SetFocus()
    UrlPopupEditBox:HighlightText()
  end
end

_PUI_OnSetItemRef = function(_, link)
  if ChatLinks._puiRuntimeEnabled ~= true
    or ChatLinks.db.profile.enableUrlCopy ~= true
    or _PUI_IsChatMessagingRestricted()
  then
    return
  end

  if issecretvalue(link) or type(link) ~= "string" then
    return
  end

  local url = link:match("^addon:pleebuiurl:(.*)")
  if url then
    ShowUrlPopup(url)
  end
end

_PUI_GetTypographyDB = function()
  local db = ChatLinks.db.profile
  db.chatTypography = db.chatTypography or {}

  local typography = db.chatTypography
  typography.message = typography.message or {}
  typography.tab = typography.tab or {}
  typography.input = typography.input or {}

  if typography.message.useGlobalFont == nil then typography.message.useGlobalFont = true end
  if typography.tab.useGlobalFont == nil then typography.tab.useGlobalFont = true end
  if typography.input.useGlobalFont == nil then typography.input.useGlobalFont = true end

  typography.message.useWindowSize = nil
  typography.message.fontSize = nil
  typography.tab.fontSize = nil
  typography.input.fontSize = nil

  return typography
end

local function _PUI_GetTypographyFont(area)
  local fontPath = OptionsUtil.FetchFontPath(area.font, area.useGlobalFont)
  local outline = area.outline
  if outline == nil then
    outline = ns.Theme.GetGlobalUIOutline()
  end

  return fontPath, ns.Theme.NormalizeOutlineFlags(outline) or ""
end

local function _PUI_SkinTypographyFont(fontObject, area)
  if not fontObject or not fontObject.SetFont or not fontObject.GetFont then
    return
  end

  local _, currentSize = fontObject:GetFont()
  if not canaccessvalue(currentSize) then
    return
  end

  currentSize = tonumber(currentSize)
  if not currentSize or currentSize <= 0 then
    return
  end

  local fontPath, outline = _PUI_GetTypographyFont(area)
  fontObject:SetFont(fontPath, currentSize, outline)
end

local function _PUI_ApplyTypographyToChatFrame(chatFrame)
  local typography = _PUI_GetTypographyDB()

  _PUI_SkinTypographyFont(chatFrame, typography.message)

  local name = chatFrame.GetName and chatFrame:GetName()
  local tab = chatFrame.tab or (name and _G[name .. "Tab"])
  local tabText = tab and (tab.Text or tab.text or (tab.GetFontString and tab:GetFontString()))
  _PUI_SkinTypographyFont(tabText, typography.tab)

  local editBox = chatFrame.editBox or (name and _G[name .. "EditBox"])
  if editBox then
    _PUI_SkinTypographyFont(editBox, typography.input)

    for _, fontString in ipairs({ editBox.header, editBox.headerSuffix, editBox.languageHeader, editBox.prompt }) do
      _PUI_SkinTypographyFont(fontString, typography.input)
    end
  end
end

function ChatLinks:ApplyChatTypography()
  self._puiPendingTypography = nil
  ForEachBlizzardChatFrame(_PUI_ApplyTypographyToChatFrame)
end

function ChatLinks:RefreshFonts()
  if self._puiRuntimeEnabled ~= true then
    return
  end

  self:ApplyChatTypography()
end

local CopyFrame
local CopyEditBox
local CopySearchBox
local CopyCountText
local CopyCleanButton
local CopySourceLines = {}

local function GetChatFrameLines(chatFrame)
  if not chatFrame or not chatFrame.GetNumMessages then
    return {}
  end

  local out = {}
  local num = chatFrame:GetNumMessages()
  if issecretvalue(num) or type(num) ~= "number" then
    return out
  end

  for i = 1, num do
    local msg = chatFrame:GetMessageInfo(i)
    if not issecretvalue(msg) and type(msg) == "string" then
      out[#out + 1] = msg
    end
  end

  return out
end

local function _PUI_CleanCopyText(text)
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|T.-|t", "")
  text = text:gsub("|A.-|a", "")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  return text
end

local function _PUI_RefreshCopyWindow()
  if not CopyEditBox then
    return
  end

  local query = CopySearchBox and CopySearchBox:GetText() or ""
  query = query:lower()

  local clean = ChatLinks.db.profile.copyClean == true
  local filtered = {}
  for i = 1, #CopySourceLines do
    local line = CopySourceLines[i]
    if query == "" or line:lower():find(query, 1, true) then
      if clean then
        filtered[#filtered + 1] = _PUI_CleanCopyText(line)
      else
        -- Raw UI escape sequences hide payload characters when rendered, which
        -- makes EditBox selection geometry diverge from its editable text.
        filtered[#filtered + 1] = line:gsub("|", "||")
      end
    end
  end

  CopyEditBox:SetText(table.concat(filtered, "\n"))
  if CopyCountText then
    CopyCountText:SetFormattedText("%d of %d lines", #filtered, #CopySourceLines)
  end
  if CopyCleanButton then
    CopyCleanButton:SetText(clean and "Clean: On" or "Clean: Off")
    ns.Theme.WidgetSkins.UIButton(CopyCleanButton)
  end
end

function ChatLinks:RefreshCopyWindow()
  _PUI_RefreshCopyWindow()
end


local function _GetCopyStyle()
  local db = ChatLinks.db.profile

  db.copyWindowStyle = db.copyWindowStyle or {}

  db.copyWindowStyle.bg = db.copyWindowStyle.bg or { 0.05, 0.05, 0.05, 0.92 }
  db.copyWindowStyle.border = db.copyWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
  if db.copyWindowStyle.borderSize == nil then
    db.copyWindowStyle.borderSize = 1
  end

  return db.copyWindowStyle
end

local function _GetChatWindowStyle()
  local db = ChatLinks.db.profile

  db.chatWindowStyle = db.chatWindowStyle or {}

  db.chatWindowStyle.bg = db.chatWindowStyle.bg or { 0.05, 0.05, 0.05, 1.00 }
  db.chatWindowStyle.border = db.chatWindowStyle.border or { 0.20, 0.20, 0.20, 1.00 }
  if db.chatWindowStyle.borderSize == nil then
    db.chatWindowStyle.borderSize = 1
  end

  return db.chatWindowStyle
end

-- Forward declare so ApplyChatWindowStyle binds local helpers defined below.
local _ApplyBackdropStyle
local _ApplyDirectChatShellBackdrop

function ChatLinks:ApplyChatWindowStyle()
  if self._puiRuntimeEnabled ~= true or _PUI_IsChatMessagingRestricted() then
    return
  end

  self:RefreshChatFrames()
end



local function _PUI_GetBackdropTarget(frame)
  if not frame then
    return nil
  end

  if frame._puiBg and frame._puiBg.SetBackdrop then
    return frame._puiBg
  end

  return frame
end

local function _ApplyBorderSize(frame, borderSize)
  frame = _PUI_GetBackdropTarget(frame)
  if not frame or not frame.GetBackdrop or not frame.SetBackdrop then
    return
  end

  local edgeSize = tonumber(borderSize) or 0
  if edgeSize < 0 then edgeSize = 0 end
  if edgeSize > 32 then edgeSize = 32 end

  -- Cache a stable "base" backdrop table once, then only mutate edgeSize.
  -- This avoids flicker/white flash from swapping backdrop tables repeatedly.
  frame.__puiBackdropBase = frame.__puiBackdropBase or frame:GetBackdrop()
  local bd = frame.__puiBackdropBase
  if not bd then
    return
  end

  if frame.__puiBackdropEdgeSize == edgeSize then
    return
  end
  frame.__puiBackdropEdgeSize = edgeSize

  bd.edgeSize = edgeSize
  frame:SetBackdrop(bd)

  -- Re-assert colors immediately after changing backdrop (prevents transient defaults).
  if frame.__puiBackdropColor and frame.SetBackdropColor then
    local c = frame.__puiBackdropColor
    frame:SetBackdropColor(c[1], c[2], c[3], c[4])
  end
  if frame.__puiBackdropBorderColor and frame.SetBackdropBorderColor then
    local c = frame.__puiBackdropBorderColor
    frame:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
  end
end


_ApplyBackdropStyle = function(frame, style)
  frame = _PUI_GetBackdropTarget(frame)
  if not frame or not style then
    return
  end

  local bg = style.bg
  local br = style.border

  if bg and frame.SetBackdropColor then
    frame.__puiBackdropColor = frame.__puiBackdropColor or {}
    frame.__puiBackdropColor[1] = bg[1]
    frame.__puiBackdropColor[2] = bg[2]
    frame.__puiBackdropColor[3] = bg[3]
    frame.__puiBackdropColor[4] = bg[4]
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  end

  if br and frame.SetBackdropBorderColor then
    frame.__puiBackdropBorderColor = frame.__puiBackdropBorderColor or {}
    frame.__puiBackdropBorderColor[1] = br[1]
    frame.__puiBackdropBorderColor[2] = br[2]
    frame.__puiBackdropBorderColor[3] = br[3]
    frame.__puiBackdropBorderColor[4] = br[4]
    frame:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
  end

  _ApplyBorderSize(frame, style.borderSize)
end

local function _PUI_EnsureTextureBackdrop(frame)
  if not frame then
    return nil
  end

  local visual = frame._puiTextureBackdrop
  if visual then
    return visual
  end

  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  fill:SetAllPoints(frame)

  local top = frame:CreateTexture(nil, "BORDER")
  top:SetTexture("Interface\\Buttons\\WHITE8x8")
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

  local bottom = frame:CreateTexture(nil, "BORDER")
  bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local left = frame:CreateTexture(nil, "BORDER")
  left:SetTexture("Interface\\Buttons\\WHITE8x8")
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

  local right = frame:CreateTexture(nil, "BORDER")
  right:SetTexture("Interface\\Buttons\\WHITE8x8")
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  visual = {
    fill = fill,
    top = top,
    bottom = bottom,
    left = left,
    right = right,
  }
  frame._puiTextureBackdrop = visual
  return visual
end

local function _PUI_ApplyTextureBackdrop(frame, bg, br, edgeSize)
  local visual = _PUI_EnsureTextureBackdrop(frame)
  if not visual then
    return
  end

  edgeSize = tonumber(edgeSize) or 1
  if edgeSize < 0 then edgeSize = 0 end
  if edgeSize > 32 then edgeSize = 32 end

  visual.fill:SetVertexColor(bg[1], bg[2], bg[3], bg[4])

  local showBorder = edgeSize > 0
  visual.top:SetVertexColor(br[1], br[2], br[3], br[4])
  visual.bottom:SetVertexColor(br[1], br[2], br[3], br[4])
  visual.left:SetVertexColor(br[1], br[2], br[3], br[4])
  visual.right:SetVertexColor(br[1], br[2], br[3], br[4])
  visual.top:SetShown(showBorder)
  visual.bottom:SetShown(showBorder)
  visual.left:SetShown(showBorder)
  visual.right:SetShown(showBorder)

  if showBorder then
    visual.top:SetHeight(edgeSize)
    visual.bottom:SetHeight(edgeSize)
    visual.left:SetWidth(edgeSize)
    visual.right:SetWidth(edgeSize)
  end
end

_ApplyDirectChatShellBackdrop = function(frame, style, preset)
  if not frame then
    return
  end

  local bg = (style and style.bg) or (preset and preset.bg) or { 0.05, 0.05, 0.05, 1.00 }
  local br = (style and style.border) or (preset and preset.border) or { 0.20, 0.20, 0.20, 1.00 }

  local edgeSize = tonumber(style and style.borderSize)
  if edgeSize == nil then
    edgeSize = ns.Theme.GetEdgeSize()
  end

  _PUI_ApplyTextureBackdrop(frame, bg, br, edgeSize)
end

local function _DisableChatButtonFrame(chatFrame)
  if not chatFrame then
    return
  end

  local buttonFrame = chatFrame.buttonFrame
    or (chatFrame.GetName and _G[chatFrame:GetName() .. "ButtonFrame"])
    or nil

  if not buttonFrame then
    return
  end

  if buttonFrame.EnableMouse then
    buttonFrame:EnableMouse(false)
  end

  if buttonFrame.minimizeButton and buttonFrame.minimizeButton.Hide then
    buttonFrame.minimizeButton:Hide()
  end

  if buttonFrame.SetAlpha then
    buttonFrame:SetAlpha(0)
  end
end



function ChatLinks:ApplyCopyWindowStyle()
  local style = _GetCopyStyle()
  _ApplyBackdropStyle(CopyFrame, style)
  _ApplyBackdropStyle(CopyEditBox, style)
  _ApplyBackdropStyle(CopySearchBox, style)
end


local function SaveCopyFramePosition(f)
  local db = ChatLinks.db and ChatLinks.db.profile
  if not db then
    return
  end

  db.copyFrame = db.copyFrame or {}

  local p, relTo, rp, xOfs, yOfs = f:GetPoint(1)
  local relN = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
  if relN == "" then
    relN = "UIParent"
  end

  db.copyFrame.point         = p or "CENTER"
  db.copyFrame.relativeTo    = relN
  db.copyFrame.relativePoint = rp or db.copyFrame.point
  db.copyFrame.x             = xOfs or 0
  db.copyFrame.y             = yOfs or 0

  if f.GetSize then
    local w, h = f:GetSize()
    db.copyFrame.w = math.floor(tonumber(w) or 600)
    db.copyFrame.h = math.floor(tonumber(h) or 350)
  end
end


local function ApplyCopyFramePosition(f)
  local cfg
  if ChatLinks.db and ChatLinks.db.profile then
    ChatLinks.db.profile.copyFrame = ChatLinks.db.profile.copyFrame or {}
    cfg = ChatLinks.db.profile.copyFrame
  end

  local point   = cfg and cfg.point         or "CENTER"
  local relName = cfg and cfg.relativeTo    or "UIParent"
  local rel     = _G[relName] or UIParent
  local relPt   = cfg and cfg.relativePoint or point
  local x       = cfg and cfg.x             or 0
  local y       = cfg and cfg.y             or 0

  local w = cfg and tonumber(cfg.w) or 600
  local h = cfg and tonumber(cfg.h) or 350
  if w < 320 then w = 320 end
  if h < 180 then h = 180 end

  if f.SetSize then
    f:SetSize(w, h)
  end

  f:ClearAllPoints()
  f:SetPoint(point, rel, relPt, x, y)
end


local function _RegisterAsSpecialFrame(frameName)
  if not frameName or frameName == "" or not UISpecialFrames then
    return
  end
  for i = 1, #UISpecialFrames do
    if UISpecialFrames[i] == frameName then
      return
    end
  end
  UISpecialFrames[#UISpecialFrames + 1] = frameName
end

local function EnsureCopyFrame()
  if CopyFrame and CopyEditBox then
    return
  end

  local Theme = ns.Theme

  CopyFrame = CreateFrame("Frame", "PleebUIChatCopyFrame", UIParent, "BackdropTemplate")

  do
    local cfg = ChatLinks.db and ChatLinks.db.profile and ChatLinks.db.profile.copyFrame
    local w = cfg and tonumber(cfg.w) or 600
    local h = cfg and tonumber(cfg.h) or 350
    if w < 320 then w = 320 end
    if h < 180 then h = 180 end
    CopyFrame:SetSize(w, h)
  end

  CopyFrame:SetClampedToScreen(true)
  CopyFrame:EnableMouse(true)
  CopyFrame:SetMovable(true)
  CopyFrame:RegisterForDrag("LeftButton")

  -- Resizable + resize grip
  CopyFrame:SetResizable(true)
  CopyFrame:SetResizeBounds(320, 180)

  -- Resize grip (no XML template dependency)
  local sizer = CreateFrame("Button", nil, CopyFrame)
  sizer:SetSize(16, 16)
  sizer:SetPoint("BOTTOMRIGHT", -2, 2)

  -- Classic size-grabber textures exist in all modern clients
  sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

  sizer:SetScript("OnMouseDown", function()
    if CopyFrame and CopyFrame.StartSizing then
      CopyFrame:StartSizing("BOTTOMRIGHT")
    end
  end)

  sizer:SetScript("OnMouseUp", function()
    if CopyFrame and CopyFrame.StopMovingOrSizing then
      CopyFrame:StopMovingOrSizing()
    end
  end)

  CopyFrame._puiSizer = sizer

  CopyFrame:HookScript("OnSizeChanged", function(f)
    SaveCopyFramePosition(f)
    ChatLinks:ApplyCopyWindowStyle()
  end)

  -- Above everything
  CopyFrame:SetFrameStrata("TOOLTIP")
  CopyFrame:SetFrameLevel(9999)
  CopyFrame:SetToplevel(true)

  -- Esc closes via UISpecialFrames
  _RegisterAsSpecialFrame("PleebUIChatCopyFrame")

  CopyFrame:SetScript("OnDragStart", function(f)
    f:StartMoving()
  end)

  CopyFrame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    SaveCopyFramePosition(f)
  end)

  ns.Theme.WidgetSkins.Frame(CopyFrame)

  -- Title
  local title = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -10)
  title:SetText("PleebUI - Copy Chat")
  Theme.ApplyFont(title, "header", 14, "OUTLINE")

-- Close button (top right)
local close = CreateFrame("Button", nil, CopyFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)
close:SetSize(24, 24)
close:SetFrameLevel((CopyFrame:GetFrameLevel() or 0) + 50)
close:Show()

ns.Theme.WidgetSkins.CloseButton(close)
if close.SetAlpha then
close:SetAlpha(1)
end
if close.GetNormalTexture and close.SetNormalTexture and not close:GetNormalTexture() then
close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
end

  CopySearchBox = CreateFrame("EditBox", "PleebUIChatCopySearchBox", CopyFrame, "BackdropTemplate")
  CopySearchBox:SetHeight(24)
  CopySearchBox:SetPoint("TOPLEFT", 16, -34)
  CopySearchBox:SetPoint("TOPRIGHT", -260, -34)
  CopySearchBox:SetAutoFocus(false)
  CopySearchBox:SetFontObject(GameFontHighlightSmall)
  CopySearchBox:SetTextInsets(6, 6, 0, 0)

  local searchHint = CopySearchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchHint:SetPoint("LEFT", 7, 0)
  searchHint:SetText("Search chat...")
  CopySearchBox._puiHint = searchHint
  CopySearchBox:SetScript("OnTextChanged", function(self)
    searchHint:SetShown(self:GetText() == "")
    _PUI_RefreshCopyWindow()
  end)
  CopySearchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  CopyCleanButton = CreateFrame("Button", nil, CopyFrame, "UIPanelButtonTemplate")
  CopyCleanButton:SetSize(100, 24)
  CopyCleanButton:SetPoint("TOPRIGHT", -140, -34)
  CopyCleanButton:SetScript("OnClick", function()
    ChatLinks.db.profile.copyClean = ChatLinks.db.profile.copyClean ~= true
    _PUI_RefreshCopyWindow()
  end)
  ns.Theme.WidgetSkins.UIButton(CopyCleanButton)

  local clearHistory = CreateFrame("Button", nil, CopyFrame, "UIPanelButtonTemplate")
  clearHistory:SetSize(116, 24)
  clearHistory:SetPoint("TOPRIGHT", -16, -34)
  clearHistory:SetText("Clear history")
  clearHistory:SetScript("OnClick", function()
    Addon:PUI_ConfirmAction({
      title = "Clear saved chat history?",
      text = "This permanently removes PleebUI's saved chat history.",
      yesText = "Clear",
      noText = CANCEL,
      onYes = function()
        _PUI_ClearSavedHistory()
      end,
    })
  end)
  ns.Theme.WidgetSkins.UIButton(clearHistory)

  CopyCountText = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  CopyCountText:SetPoint("TOPLEFT", 16, -63)
  CopyCountText:SetText("0 of 0 lines")
  Theme.ApplyFont(CopyCountText, "body", 11)


  -- ScrollFrame + EditBox
  local scroll = CreateFrame("ScrollFrame", "PleebUIChatCopyScrollFrame", CopyFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 16)

  ns.Theme.WidgetSkins.Scrollbar(scroll)


  CopyEditBox = CreateFrame("EditBox", "PleebUIChatCopyEditBox", scroll, "BackdropTemplate")
  CopyEditBox:SetMultiLine(true)
  CopyEditBox:SetMaxLetters(0)
  CopyEditBox:EnableMouse(true)
  CopyEditBox:SetAutoFocus(false)
  CopyEditBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  CopyEditBox:SetWidth(540)

  scroll:HookScript("OnSizeChanged", function(self)
    CopyEditBox:SetWidth(math.max(1, self:GetWidth() - 4))
  end)

  CopyEditBox:SetScript("OnEscapePressed", function()
    CopyFrame:Hide()
  end)

  scroll:SetScrollChild(CopyEditBox)


  -- Apply custom Copy window style (bg/border/borderSize)
  ChatLinks:ApplyCopyWindowStyle()


  -- Position from DB (and allow normal dragging outside Edit Mode without any mover)
  ApplyCopyFramePosition(CopyFrame)
end

local PRIMARY_CHAT_MOVER_LEFT_INSET = 5
local PRIMARY_CHAT_MOVER_RIGHT_INSET = 23
local PRIMARY_CHAT_MOVER_TOP_INSET = 27
local PRIMARY_CHAT_MOVER_BOTTOM_INSET = 34
local PRIMARY_CHAT_RESIZE_IDLE_ALPHA = 0.18

local function EnsurePrimaryChatHolder()
  local holder = ChatLinks._primaryChatHolder
  if holder then
    return holder
  end

  holder = CreateFrame("Frame", "PleebUI_PrimaryChatHolder", UIParent)
  holder:SetSize(430, 180)
  holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 32)
  holder:SetClampRectInsets(0, 0, 0, 0)
  holder:SetClampedToScreen(false)
  holder:SetMovable(true)
  holder:EnableMouse(false)
  ChatLinks._primaryChatHolder = holder
  return holder
end

local function ApplyPrimaryChatHolderLayout(db)
  if not db then
    return
  end

  local cfg = db.chatFrame1
  if not cfg then
    return
  end

  local holder = EnsurePrimaryChatHolder()

  local point      = cfg.point or "BOTTOMLEFT"
  local relName    = cfg.relativeTo or "UIParent"
  local relFrame   = _G[relName] or UIParent
  local relPoint   = cfg.relativePoint or point
  local x          = cfg.x or 32
  local y          = cfg.y or 32

  -- Normalize the removed DataBar anchor without reading its runtime geometry.
  if relName == "PleebUI_DataBar" then
    relName = "UIParent"
    relFrame = UIParent
    relPoint = point
    cfg.relativeTo = relName
    cfg.relativePoint = relPoint
  end

  holder:ClearAllPoints()
  holder:SetPoint(point, relFrame, relPoint, x, y)
  holder:SetSize(tonumber(cfg.width) or 430, tonumber(cfg.height) or 180)
  return holder
end

local function BindPrimaryChatFrame(holder, chatFrame)
  if not holder or not chatFrame then
    return
  end

  chatFrame:ClearAllPoints()
  chatFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  chatFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  chatFrame:SetClampRectInsets(0, 0, 0, 0)
  chatFrame:SetClampedToScreen(false)
end

-- This is the only lifecycle path that writes Blizzard chat-frame anchors.
InitializePrimaryChatLayout = function()
  if ChatLinks._puiRuntimeEnabled ~= true then
    return
  end

  local db = ChatLinks.db and ChatLinks.db.profile
  if not db then
    return
  end

  local holder = ApplyPrimaryChatHolderLayout(db)
  BindPrimaryChatFrame(holder, _G.ChatFrame1)
end


local function GetPrimaryChatMoverInsets(holder)
  if not holder then
    return 0, 0, 0, 0
  end

  return
    PRIMARY_CHAT_MOVER_LEFT_INSET,
    PRIMARY_CHAT_MOVER_RIGHT_INSET,
    PRIMARY_CHAT_MOVER_TOP_INSET,
    PRIMARY_CHAT_MOVER_BOTTOM_INSET
end

local function SavePrimaryChatLayout(holder)
  local db = ChatLinks.db and ChatLinks.db.profile
  if not db then
    return
  end

  db.chatFrame1 = db.chatFrame1 or {}
  local cfg = db.chatFrame1

  local point, relativeTo, relativePoint, x, y = holder:GetPoint(1)
  local relativeName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "UIParent"
  if relativeName == "" then
    relativeName = "UIParent"
  end

  cfg.point = point or "BOTTOMLEFT"
  cfg.relativeTo = relativeName
  cfg.relativePoint = relativePoint or cfg.point
  cfg.x = x or 0
  cfg.y = y or 0
  cfg.width = ClampInt(holder:GetWidth(), 220, 1000)
  cfg.height = ClampInt(holder:GetHeight(), 100, 700)
end

local function StopPrimaryChatMove()
  if ChatLinks._primaryChatMoving ~= true then
    return
  end

  ChatLinks._primaryChatMoving = nil

  local holder = ChatLinks._primaryChatHolder
  if holder then
    holder:StopMovingOrSizing()
    SavePrimaryChatLayout(holder)
  end
end

local function StartPrimaryChatMove()
  if ChatLinks._puiRuntimeEnabled ~= true or ns.Flags.IsEditing or InCombatLockdown() then
    return
  end

  local holder = ChatLinks._primaryChatHolder
  if not holder then
    return
  end

  ChatLinks._primaryChatMoving = true
  holder:StartMoving()
end

local function EnablePrimaryChatTabDragging(tab, chatFrame)
  if chatFrame ~= _G.ChatFrame1 or not tab or tab._puiPrimaryDragHooked then
    return
  end

  tab._puiPrimaryDragHooked = true
  tab:HookScript("OnDragStart", function(_, button)
    if button == "LeftButton" then
      StartPrimaryChatMove()
    end
  end)
  tab:HookScript("OnDragStop", StopPrimaryChatMove)
  tab:HookScript("OnHide", StopPrimaryChatMove)
end

local function StopPrimaryChatResize()
  local handle = ChatLinks._primaryChatResizeHandle
  if not handle or not handle._resizeState then
    return
  end

  handle._resizeState = nil
  handle:SetScript("OnUpdate", nil)
  handle:SetAlpha(PRIMARY_CHAT_RESIZE_IDLE_ALPHA)

  local holder = ChatLinks._primaryChatHolder
  if holder then
    SavePrimaryChatLayout(holder)
    ChatLinks:ApplyChatWindowStyle()
  end
end

local function UpdatePrimaryChatResize(handle)
  local state = handle._resizeState
  if not state then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  if not scale or scale <= 0 then
    scale = 1
  end
  cursorX = cursorX / scale
  cursorY = cursorY / scale

  local width = ClampInt(state.width + cursorX - state.cursorX, 220, 1000)
  local height = ClampInt(state.height - cursorY + state.cursorY, 100, 700)

  state.holder:ClearAllPoints()
  state.holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", state.left, state.top)
  state.holder:SetSize(width, height)
end

local function StartPrimaryChatResize(handle)
  if ChatLinks._puiRuntimeEnabled ~= true or InCombatLockdown() then
    return
  end

  local holder = ChatLinks._primaryChatHolder
  local left = holder and holder:GetLeft()
  local top = holder and holder:GetTop()
  if not left or not top then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  if not scale or scale <= 0 then
    scale = 1
  end

  handle._resizeState = {
    holder = holder,
    cursorX = cursorX / scale,
    cursorY = cursorY / scale,
    left = left,
    top = top,
    width = holder:GetWidth(),
    height = holder:GetHeight(),
  }
  handle:SetScript("OnUpdate", UpdatePrimaryChatResize)
end

local function EnsurePrimaryChatResizeHandle(holder)
  local handle = ChatLinks._primaryChatResizeHandle
  if handle then
    handle:ClearAllPoints()
    handle:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
    return handle
  end

  handle = CreateFrame("Button", "PleebUI_PrimaryChatResizeHandle", UIParent)
  ChatLinks._primaryChatResizeHandle = handle

  handle:SetSize(22, 22)
  handle:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
  handle:SetFrameStrata("TOOLTIP")
  handle:SetFrameLevel(1000)
  handle:RegisterForDrag("LeftButton")
  handle:EnableMouse(true)

  local texture = handle:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(handle)
  texture:SetAtlas("damagemeters-scalehandle")

  local highlight = handle:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(handle)
  highlight:SetAtlas("damagemeters-scalehandle-hover")

  handle:SetAlpha(PRIMARY_CHAT_RESIZE_IDLE_ALPHA)
  handle:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Resize chat")
    GameTooltip:AddLine("Drag to change the chat width and height.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  handle:SetScript("OnLeave", function(self)
    if not self._resizeState then
      self:SetAlpha(PRIMARY_CHAT_RESIZE_IDLE_ALPHA)
    end
    GameTooltip:Hide()
  end)
  handle:SetScript("OnDragStart", StartPrimaryChatResize)
  handle:SetScript("OnDragStop", StopPrimaryChatResize)
  handle:SetScript("OnHide", StopPrimaryChatResize)
  handle:Hide()

  return handle
end

local function SetPrimaryChatResizeHandleShown(show)
  if not show then
    StopPrimaryChatResize()
    if ChatLinks._primaryChatResizeHandle then
      ChatLinks._primaryChatResizeHandle:Hide()
    end
    return
  end

  local holder = ChatLinks._primaryChatHolder
  if holder then
    EnsurePrimaryChatResizeHandle(holder):Show()
  end
end


local function RegisterPrimaryChatMover()
  local db = ChatLinks.db and ChatLinks.db.profile
  if not db then
    SetPrimaryChatResizeHandleShown(false)
    return
  end

  if ChatLinks._puiRuntimeEnabled ~= true then
    SetPrimaryChatResizeHandleShown(false)
    return
  end

  local holder = EnsurePrimaryChatHolder()

  FrameUtil:RegisterMover("Chat_Primary", holder, {
    label = "Chat - Primary",
    overlayInsets = GetPrimaryChatMoverInsets,

    onDragStop = SavePrimaryChatLayout,

    resetPosition = function(f)
      local db = ChatLinks.db and ChatLinks.db.profile
      if not db then
        return
      end

      db.chatFrame1 = {
        point         = "BOTTOMLEFT",
        relativeTo    = "UIParent",
        relativePoint = "BOTTOMLEFT",
        x             = 32,
        y             = 32,
        width         = 430,
        height        = 180,
      }

      f:ClearAllPoints()
      f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 32)
      f:SetSize(430, 180)
    end,

    optionsString = "Chat",
    quickSettings = function()
      local cfg = ChatLinks.db.profile.chatFrame1
      return {
        ownerKey = "Chat_Primary",
        title = "Chat - Primary",
        description = "Live chat window settings.",
        controls = {
          {
            type = "slider",
            label = "Width",
            min = 220,
            max = 1000,
            step = 5,
            get = function() return tonumber(cfg.width) or holder:GetWidth() end,
            set = function(value)
              cfg.width = ClampInt(value, 220, 1000)
              holder:SetWidth(cfg.width)
            end,
          },
          {
            type = "slider",
            label = "Height",
            min = 100,
            max = 700,
            step = 5,
            get = function() return tonumber(cfg.height) or holder:GetHeight() end,
            set = function(value)
              cfg.height = ClampInt(value, 100, 700)
              holder:SetHeight(cfg.height)
            end,
          },
          {
            type = "slider",
            label = "Border size",
            min = 0,
            max = 8,
            step = 1,
            get = function()
              return tonumber(ChatLinks.db.profile.chatWindowStyle.borderSize) or 1
            end,
            set = function(value)
              ChatLinks.db.profile.chatWindowStyle.borderSize = ClampInt(value, 0, 8)
              ChatLinks:ApplyChatWindowStyle()
            end,
          },
        },
      }
    end,

  })

  -- The shared mover clamps targets by default; chat may sit flush with the screen edge.
  holder:SetClampRectInsets(0, 0, 0, 0)
  holder:SetClampedToScreen(false)

  SetPrimaryChatResizeHandleShown(true)
end

function ChatLinks:OnEditModeChanged(enable)
  if enable then
    RegisterPrimaryChatMover()
  else
    SetPrimaryChatResizeHandleShown(self._puiRuntimeEnabled == true)
  end
end

local C_Timer = C_Timer

local function _PUI_ForEachChatVisual(chatFrame, callback)
  if not chatFrame then
    return
  end

  local editBox = chatFrame.editBox
  for _, visual in ipairs({
    chatFrame._puiShell,
    editBox and editBox._puiInputBar,
    chatFrame.PleebUICopyButton,
    chatFrame.PleebUIChatToolsButton,
  }) do
    if visual then
      callback(visual)
    end
  end
end

-- Internal: set alpha on the primary chat frame + its shell if present.
function ChatLinks:_SetChatVisualAlpha(chatFrame, alpha)
  if not chatFrame or alpha == nil then
    return
  end

  _PUI_ForEachChatVisual(chatFrame, function(visual)
    visual:SetAlpha(alpha)
  end)

  self._chatAlphaCurrent = alpha
end

function ChatLinks:_CancelFadeTimers()
  if self._chatFadeTimer then
    self._chatFadeTimer:Cancel()
    self._chatFadeTimer = nil
  end

  _PUI_ForEachChatVisual(_G.ChatFrame1, function(visual)
    local animationGroup = visual._puiChatFadeAnimation
    if animationGroup and animationGroup:IsPlaying() then
      animationGroup:Stop()
    end
  end)
end

function ChatLinks:_AnimateChatVisualAlpha(chatFrame, fromAlpha, toAlpha, duration)
  if not chatFrame then
    return
  end

  self:_CancelFadeTimers()

  duration = tonumber(duration) or 0
  if duration <= 0 then
    self:_SetChatVisualAlpha(chatFrame, toAlpha)
    return
  end

  _PUI_ForEachChatVisual(chatFrame, function(visual)
    local animationGroup = visual._puiChatFadeAnimation
    local alphaAnimation
    if not animationGroup then
      animationGroup = visual:CreateAnimationGroup()
      alphaAnimation = animationGroup:CreateAnimation("Alpha")
      visual._puiChatFadeAnimation = animationGroup
      visual._puiChatFadeAlpha = alphaAnimation
      animationGroup:SetScript("OnFinished", function()
        visual:SetAlpha(visual._puiChatFadeTarget or 1)
      end)
    else
      alphaAnimation = visual._puiChatFadeAlpha
    end

    visual._puiChatFadeTarget = toAlpha
    visual:SetAlpha(1)
    alphaAnimation:SetFromAlpha(fromAlpha)
    alphaAnimation:SetToAlpha(toAlpha)
    alphaAnimation:SetDuration(duration)
    animationGroup:Play()
  end)

  self._chatAlphaCurrent = toAlpha
end

function ChatLinks:_ScheduleIdleVisualFade(chatFrame)
  local db = self.db.profile.chatFade
  if not db.enabled then return end
  if not chatFrame then return end

  if self._chatFadeTimer then
    self._chatFadeTimer:Cancel()
    self._chatFadeTimer = nil
  end

  local delay = tonumber(db.idleDelay) or 15
  self._chatFadeTimer = C_Timer.NewTimer(delay, function()
    self._chatFadeTimer = nil

    local toAlpha = tonumber(db.idleAlpha) or 0.4
    if db.animate then
      local fromAlpha = self._chatAlphaCurrent
      if fromAlpha == nil then
        fromAlpha = tonumber(db.activeAlpha) or 1.0
      end

      local duration = tonumber(db.fadeDuration) or 0
      self:_AnimateChatVisualAlpha(chatFrame, fromAlpha, toAlpha, duration)
    else
      self:_SetChatVisualAlpha(chatFrame, toAlpha)
    end
  end)
end

function ChatLinks:ChatInputActivated(chatFrame)
  local db = self.db.profile.chatFade
  if not db.enabled then return end
  if not chatFrame or chatFrame ~= _G.ChatFrame1 then return end

  self:_CancelFadeTimers()
  self:_SetChatVisualAlpha(chatFrame, tonumber(db.activeAlpha) or 1.0)
end

function ChatLinks:ChatInputDeactivated(chatFrame)
  local db = self.db.profile.chatFade
  if not db.enabled then return end
  if not chatFrame or chatFrame ~= _G.ChatFrame1 then return end

  self:_ScheduleIdleVisualFade(chatFrame)
end

function ChatLinks:ApplyInitialFade()
  local cf = _G.ChatFrame1
  local db = self.db.profile.chatFade

  self:_CancelFadeTimers()

  if not cf then
    return
  end

  self:_SetChatVisualAlpha(cf, tonumber(db.activeAlpha) or 1.0)

  if not db.enabled then
    return
  end

  self:_ScheduleIdleVisualFade(cf)
end

function ChatLinks:OpenCopyWindow(chatFrame)
  if _PUI_IsChatMessagingRestricted() then
    if InCombatLockdown() then
      self._pendingCopyOpenFrame = chatFrame or _G.DEFAULT_CHAT_FRAME

      if not self._pendingCopyOpenHooked then
        self._pendingCopyOpenHooked = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
          local f = self._pendingCopyOpenFrame
          self._pendingCopyOpenFrame = nil

          if self._pendingCopyOpenHooked then
            self._pendingCopyOpenHooked = nil
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
          end

          self:OpenCopyWindow(f)
        end)
      end

      Addon:Print("Copy Chat is blocked in combat. It will open when combat ends.")
    else
      Addon:Print("Copy Chat is blocked by encounter chat restrictions.")
    end
    return
  end

  EnsureCopyFrame()

  local frame = chatFrame or _G.DEFAULT_CHAT_FRAME
  CopySourceLines = GetChatFrameLines(frame)
  CopySearchBox:SetText("")
  _PUI_RefreshCopyWindow()
  CopyEditBox:HighlightText()
  CopyEditBox:SetFocus()

  CopyFrame:Show()
end



-- Chat frame shell, tabs, side buttons and copy button wiring.

-- Chat input background bar behind the edit box (so the input does not float).
local function EnsureChatInputBar(editBox)
  if not editBox then return end

  local bg = editBox._puiInputBar
  if not bg then
    bg = CreateFrame("Frame", nil, editBox)
    bg:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
    bg:EnableMouse(false)

    if bg.SetFrameStrata and editBox.GetFrameStrata then
      bg:SetFrameStrata(editBox:GetFrameStrata())
    end
    if bg.SetFrameLevel and editBox.GetFrameLevel then
      local lvl = (editBox:GetFrameLevel() or 1) - 1
      if lvl < 0 then lvl = 0 end
      bg:SetFrameLevel(lvl)
    end

    editBox._puiInputBar = bg
  end

  local colors = ns.Theme.GetColors()
  _PUI_ApplyTextureBackdrop(bg, colors.control, colors.border, ns.Theme.GetEdgeSize())
end

-- Skin the chat edit box (bottom input)
local function SkinChatEditBox(chatFrame)
  if not chatFrame then return end
  local name = chatFrame.GetName and chatFrame:GetName()
  if not name then return end

  local editBox = _G[name .. "EditBox"]
  if not editBox then
    return
  end

  EnsureChatInputBar(editBox)

  if editBox._puiSkinned then
    return
  end

  local Theme = ns.Theme

  -- Hide Blizzard textures
  for _, suffix in ipairs({ "EditBoxLeft", "EditBoxRight", "EditBoxMid" }) do
    local tex = _G[name .. suffix]
    if tex and tex.SetAlpha then
      tex:SetAlpha(0)
    end
  end

  if editBox.focusLeft and editBox.focusLeft.SetAlpha then
    editBox.focusLeft:SetAlpha(0)
  end
  if editBox.focusRight and editBox.focusRight.SetAlpha then
    editBox.focusRight:SetAlpha(0)
  end
  if editBox.focusMid and editBox.focusMid.SetAlpha then
    editBox.focusMid:SetAlpha(0)
  end

  for _, region in ipairs({ editBox:GetRegions() }) do
    if region:IsObjectType("FontString") then
      Theme.ApplyFont(region, "body", 12, "OUTLINE")
    end
  end

  -- Hook focus events so we can adjust chat alpha.
  -- We only care about the primary chat frame for fading.
  if chatFrame == _G.ChatFrame1 then
    editBox:HookScript("OnEditFocusGained", function()
      ChatLinks:ChatInputActivated(chatFrame)
    end)
    editBox:HookScript("OnEditFocusLost", function()
      ChatLinks:ChatInputDeactivated(chatFrame)
    end)
  end

  editBox._puiSkinned = true
end

-- Skin the main tab for a chat frame (General, Combat Log, etc.)
local function SkinChatTab(chatFrame)
  if not chatFrame then return end
  local name = chatFrame.GetName and chatFrame:GetName()
  if not name then return end

  local tab = _G[name .. "Tab"]
  if not tab then
    return
  end

  EnablePrimaryChatTabDragging(tab, chatFrame)

  local Theme = ns.Theme
  local style = _GetChatWindowStyle()
  local fill = style.bg
  local border = style.border
  local edgeSize = tonumber(style.borderSize) or Theme.GetEdgeSize()

  local text = tab.Text or _G[name .. "TabText"]
  if not text then
    local r = select(2, tab:GetRegions())
    if r and r.GetObjectType and r:GetObjectType() == "FontString" then
      text = r
    end
  end

  if not tab._puiSkinned then
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
      local tex = tab[key] or _G[name .. "Tab" .. key]
      if tex and tex.SetTexture then
        tex:SetTexture(nil)
      end
    end

    local bg = CreateFrame("Frame", nil, tab)
    bg:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1)
    bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
    bg:SetHeight(24)
    bg:EnableMouse(false)
    if bg.SetIgnoreParentAlpha then
      bg:SetIgnoreParentAlpha(true)
    end
    tab._puiTabBG = bg

    if bg.SetFrameStrata and tab.GetFrameStrata then
      bg:SetFrameStrata(tab:GetFrameStrata())
    end
    if bg.SetFrameLevel and tab.GetFrameLevel then
      local lvl = (tab:GetFrameLevel() or 1) - 1
      if lvl < 0 then lvl = 0 end
      bg:SetFrameLevel(lvl)
    end

    tab._puiSkinned = true
  end

  local colors = Theme.GetColors()
  local accent = colors.accent or { 0.20, 0.65, 1.00, 1.00 }
  local white = "Interface\\Buttons\\WHITE8x8"
  local bg = tab._puiTabBG

  for _, key in ipairs({
    "SelectedLeft", "SelectedRight",
    "ActiveLeft", "ActiveRight",
  }) do
    local texture = tab[key] or _G[name .. "Tab" .. key]
    if texture then
      texture:SetTexture(nil)
    end
  end

  for _, key in ipairs({ "SelectedMiddle", "ActiveMiddle" }) do
    local texture = tab[key] or _G[name .. "Tab" .. key]
    if texture then
      texture:SetTexture(white)
      texture:SetVertexColor(accent[1], accent[2], accent[3], 0.32)
      texture:ClearAllPoints()
      texture:SetAllPoints(bg)
    end
  end

  for _, key in ipairs({ "HighlightLeft", "HighlightRight" }) do
    local texture = tab[key] or _G[name .. "Tab" .. key]
    if texture then
      texture:SetTexture(nil)
    end
  end

  local highlight = tab.HighlightMiddle or _G[name .. "TabHighlightMiddle"]
  if highlight then
    highlight:SetTexture(white)
    highlight:SetVertexColor(accent[1], accent[2], accent[3], 0.18)
    highlight:ClearAllPoints()
    highlight:SetAllPoints(bg)
  end

  local glow = tab.glow or _G[name .. "TabGlow"]
  if glow then
    glow:SetTexture(white)
    glow:SetVertexColor(accent[1], accent[2], accent[3], 1)
    glow:ClearAllPoints()
    glow:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 4, 1)
    glow:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -4, 1)
    glow:SetHeight(2)
  end

  if text then
    if text.ClearAllPoints then
      text:ClearAllPoints()
      text:SetPoint("CENTER", bg, "CENTER", tab.conversationIcon and 8 or 0, 0)
    end

    if text.SetJustifyH then
      text:SetJustifyH("CENTER")
    end
    if text.SetJustifyV then
      text:SetJustifyV("MIDDLE")
    end
  end

  if tab.conversationIcon then
    tab.conversationIcon:ClearAllPoints()
    tab.conversationIcon:SetPoint("LEFT", bg, "LEFT", 5, 0)
  end

  if bg then
    _PUI_ApplyTextureBackdrop(bg, fill, border, edgeSize)
  end

  if text then
    _PUI_SkinTypographyFont(text, _PUI_GetTypographyDB().tab)
  end
end

local function CreateJumpToBottomButton(chatFrame)
  if chatFrame.PleebUIJumpToBottomButton then
    return chatFrame.PleebUIJumpToBottomButton
  end

  local button = CreateFrame("Button", nil, chatFrame)
  button:SetSize(20, 20)
  button:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 11, 3)

  local normal = button:CreateTexture(nil, "ARTWORK")
  normal:SetAllPoints()
  normal:SetAtlas("minimal-scrollbar-arrow-returntobottom")
  button:SetNormalTexture(normal)

  local pushed = button:CreateTexture(nil, "ARTWORK")
  pushed:SetAllPoints()
  pushed:SetAtlas("minimal-scrollbar-arrow-returntobottom-down")
  button:SetPushedTexture(pushed)

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetAtlas("minimal-scrollbar-arrow-returntobottom-over")
  button:SetHighlightTexture(highlight)

  button:SetScript("OnClick", function()
    chatFrame:ScrollToBottom()
    button:Hide()
  end)
  button:Hide()

  chatFrame:HookScript("OnMouseWheel", function(_, delta)
    local lines = ClampInt(ChatLinks.db.profile.chatTweaks.scrollMessages, 1, 12)
    if delta > 0 then
      button:Show()
    end

    for _ = 2, lines do
      if delta > 0 then
        chatFrame:ScrollUp()
      else
        chatFrame:ScrollDown()
      end
    end
  end)

  hooksecurefunc(chatFrame, "ScrollToBottom", function()
    button:Hide()
  end)

  chatFrame.PleebUIJumpToBottomButton = button
  return button
end

local function SkinChatFrame(chatFrame)
  if not chatFrame then
    return
  end

  local name = chatFrame.GetName and chatFrame:GetName()

  if chatFrame._puiSkinned then
    if chatFrame._puiShell then
      local style = _GetChatWindowStyle and _GetChatWindowStyle()
      _ApplyDirectChatShellBackdrop(chatFrame._puiShell, style)
    end

    _DisableChatButtonFrame(chatFrame)
    SkinChatEditBox(chatFrame)
    SkinChatTab(chatFrame)
    CreateJumpToBottomButton(chatFrame)
    return
  end


  -- 1) Hide Blizzard background and disable the unused side-button input surface.
  if name then
    local bg = _G[name .. "Background"]
    if bg then
      if bg.SetAlpha    then bg:SetAlpha(0) end
      if bg.Hide        then bg:Hide() end
      if bg.EnableMouse then bg:EnableMouse(false) end
    end
  end
  _DisableChatButtonFrame(chatFrame)


  -- 2) Our visual shell is parented to the actual chat frame.
  local shell = chatFrame._puiShell
  if not shell then
    shell = CreateFrame("Frame", nil, chatFrame)
    if shell.EnableMouse then
      shell:EnableMouse(false)
    end
    chatFrame._puiShell = shell
  elseif shell.GetParent and shell:GetParent() ~= chatFrame then
    shell:SetParent(chatFrame)
  end

  local function RefreshShellAnchors()
    local scrollbarWidth = 0
    if chatFrame.ScrollBar then
      scrollbarWidth = 8
    end

    shell:ClearAllPoints()
    shell:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -2, 3)
    shell:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 15 + scrollbarWidth, 3)
    shell:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -2, -6)
    shell:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 15 + scrollbarWidth, -6)
  end

  if chatFrame.GetFrameStrata then
    shell:SetFrameStrata(chatFrame:GetFrameStrata())
  end
  if chatFrame.GetFrameLevel then
    local lvl = (chatFrame:GetFrameLevel() or 1) - 1
    if lvl < 0 then lvl = 0 end
    shell:SetFrameLevel(lvl)
    if shell.SetIgnoreParentAlpha then
      shell:SetIgnoreParentAlpha(true)
    end
  end

  RefreshShellAnchors()

  local style = _GetChatWindowStyle and _GetChatWindowStyle()
  _ApplyDirectChatShellBackdrop(shell, style)


  -- 3) Strip leftover Blizzard textures on the chat frame itself
  local regions = { chatFrame:GetRegions() }
  for i = 1, #regions do
    local r = regions[i]
    if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.SetAlpha then
      r:SetAlpha(0)
    end
  end


  -- 4) Hide Blizzard scrollbar / minimize / scroll-to-bottom extras
  local scrollBar = chatFrame.ScrollBar or (name and _G[name .. "ScrollBar"])
  if scrollBar then
    local sRegions = { scrollBar:GetRegions() }
    for i = 1, #sRegions do
      local r = sRegions[i]
      if r and r:GetObjectType() == "Texture" then
        r:SetTexture(nil)
        r:SetAlpha(0)
      end
    end

    for _, tex in ipairs({
      scrollBar.Background,
      scrollBar.BackgroundTop,
      scrollBar.BackgroundBottom,
      scrollBar.TrackBG,
      scrollBar.Top,
      scrollBar.Bottom,
      scrollBar.Middle,
    }) do
      if tex then
        tex:SetTexture(nil)
        tex:SetAlpha(0)
      end
    end

    scrollBar:Hide()
    scrollBar:SetAlpha(0)
    scrollBar:EnableMouse(false)
  end

  local scrollToBottom = chatFrame.ScrollToBottomButton or (name and _G[name .. "ScrollToBottomButton"])
  if scrollToBottom then
    scrollToBottom:Hide()
    scrollToBottom:SetAlpha(0)
    scrollToBottom:EnableMouse(false)
  end

  local minimize = (chatFrame.buttonFrame and chatFrame.buttonFrame.minimizeButton) or (name and _G[name .. "MinimizeButton"])
  if minimize then
    minimize:Hide()
    minimize:SetAlpha(0)
    minimize:EnableMouse(false)
  end

  chatFrame._puiSkinned = true

  SkinChatEditBox(chatFrame)
  SkinChatTab(chatFrame)
  CreateJumpToBottomButton(chatFrame)

  if chatFrame == _G.ChatFrame1 then
    chatFrame:HookScript("OnEnter", function()
      ChatLinks:ChatInputActivated(chatFrame)
    end)
    chatFrame:HookScript("OnLeave", function()
      ChatLinks:ChatInputDeactivated(chatFrame)
    end)
  end
end

local function HideChatSideButtons()
  local sideButtons = {
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameMenuButton",
    "QuickJoinToastButton",
    "TextToSpeechButton",
  }

  for _, n in ipairs(sideButtons) do
    local f = _G[n]
    if f then
      f:Hide()
      f:SetAlpha(0)
      f:EnableMouse(false)
    end
  end

  local ttsFrame = _G.TextToSpeechButtonFrame
  if ttsFrame then
    ttsFrame:Hide()
    ttsFrame:SetAlpha(0)
    ttsFrame:EnableMouse(false)
  end
end

local function _PUI_ClickBlizzardChatTool(buttonName)
  local button = _G[buttonName]
  if not button then
    Addon:Print("That Blizzard chat tool is not available right now.")
    return
  end

  if InCombatLockdown() and button.IsProtected and button:IsProtected() then
    Addon:Print("That Blizzard chat tool is blocked in combat.")
    return
  end

  button:Click("LeftButton")
end

local function EnsureChatToolsButton(chatFrame)
  local button = chatFrame.PleebUIChatToolsButton
  if button then
    local panel = button._puiPanel
    if panel then
      local colors = ns.Theme.GetColors()
      _PUI_ApplyTextureBackdrop(panel, colors.background, colors.border, ns.Theme.GetEdgeSize())
    end
    return button
  end

  button = CreateFrame("Button", nil, chatFrame, "UIPanelButtonTemplate")
  button:SetSize(20, 20)
  button:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -27, -3)
  button:SetText("...")
  ns.Theme.WidgetSkins.UIButton(button)

  local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  panel:SetSize(166, 132)
  panel:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 4)
  panel:SetFrameStrata("DIALOG")
  panel:EnableMouse(true)

  local colors = ns.Theme.GetColors()
  _PUI_ApplyTextureBackdrop(panel, colors.background, colors.border, ns.Theme.GetEdgeSize())

  local entries = {
    { "Voice channels", "ChatFrameChannelButton" },
    { "Text to speech", "TextToSpeechButton" },
    { "Quick Join", "QuickJoinToastButton" },
    { "Mute microphone", "ChatFrameToggleVoiceMuteButton" },
    { "Deafen voice", "ChatFrameToggleVoiceDeafenButton" },
  }

  for index, entry in ipairs(entries) do
    local buttonName = entry[2]
    local tool = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    tool:SetPoint("TOPLEFT", 6, -6 - ((index - 1) * 24))
    tool:SetPoint("TOPRIGHT", -6, -6 - ((index - 1) * 24))
    tool:SetHeight(22)
    tool:SetText(entry[1])
    tool:SetScript("OnClick", function()
      panel:Hide()
      _PUI_ClickBlizzardChatTool(buttonName)
    end)
    ns.Theme.WidgetSkins.UIButton(tool)
  end

  button:SetScript("OnClick", function()
    panel:SetShown(not panel:IsShown())
  end)
  panel:Hide()

  button._puiPanel = panel
  chatFrame.PleebUIChatToolsButton = button
  return button
end

local function CreateCopyButton(chatFrame)
  if not chatFrame or chatFrame.PleebUICopyButton then
    return
  end

  local btn = CreateFrame("Button", nil, chatFrame)
  btn:SetSize(18, 18)
  btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -4, -4)

  -- Simple texture so we see it; you can replace this with a custom icon later
  local tex = btn:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
  btn:SetNormalTexture(tex)

  btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

  btn:SetScript("OnClick", function()
    ChatLinks:OpenCopyWindow(chatFrame)
  end)


  -- Always visible so it is obvious
  btn:Show()

  chatFrame.PleebUICopyButton = btn
end

function ChatLinks:RefreshChatFrames(atPlayerEnteringWorld)
  if not self.db or not self.db.profile or self._puiRuntimeEnabled ~= true then
    return
  end

  ForEachBlizzardChatFrame(function(chatFrame)
    SkinChatFrame(chatFrame)
  end)

  ApplyChatTweaks(atPlayerEnteringWorld == true)
  self:ApplyChatTypography()

  local enableCopyFrame = self.db.profile.enableCopyFrame == true
  ForEachBlizzardChatFrame(function(chatFrame)
    local copyButton = chatFrame.PleebUICopyButton
    if enableCopyFrame and not _PUI_IsTemporaryChatFrame(chatFrame) then
      copyButton = copyButton or CreateCopyButton(chatFrame)
    end
    if copyButton then
      copyButton:SetShown(enableCopyFrame)
    end
  end)

  local primaryChat = _G.ChatFrame1
  if primaryChat then
    local toolsButton = primaryChat.PleebUIChatToolsButton
    if self.db.profile.enableChatTools == true then
      toolsButton = toolsButton or EnsureChatToolsButton(primaryChat)
    end
    if toolsButton then
      toolsButton:SetShown(self.db.profile.enableChatTools == true)
      if self.db.profile.enableChatTools ~= true and toolsButton._puiPanel then
        toolsButton._puiPanel:Hide()
      end
    end
  end

  if atPlayerEnteringWorld == true or not InCombatLockdown() then
    HideChatSideButtons()
  end
end

function ChatLinks:RefreshTheme()
  if not self.db or not self.db.profile then
    return
  end

  if self._puiRuntimeEnabled ~= true or _PUI_IsChatMessagingRestricted() then
    return
  end

  self:RefreshChatFrames()

  if CopyFrame then
    self:ApplyCopyWindowStyle()
  end
end

function ChatLinks:OnProfileChanged()

  if not self.db or not self.db.profile then
    return
  end

  if not _PUI_RefreshChatRuntimeState() then
    self:SetUrlFiltersEnabled(false)
    return
  end

  self:SetUrlFiltersEnabled(self.db.profile.enableUrlCopy == true)

  -- Per-profile chat tweaks (history)
  ApplyChatTweaks()

  -- Re-apply addon-owned frame positions immediately on profile switch.
  if CopyFrame then
    ApplyCopyFramePosition(CopyFrame)
  end
  ApplyPrimaryChatHolderLayout(self.db.profile)

  -- Refresh mover callbacks against the active profile.
  RegisterPrimaryChatMover()

  -- Per-profile styling
  self:ApplyChatWindowStyle()
  if CopyFrame then
    self:ApplyCopyWindowStyle()
  end

  -- Fade uses per-profile values; refresh its initial state.
  self:ApplyInitialFade()
  self:ApplyChatFormatting()
end



function ChatLinks:OnEnable()
  if not self.db or not self.db.profile then
    return
  end

  local db  = self.db.profile
  local cdb = _PUI_GetChatConflictDB()

  local chattyLoaded = _PUI_IsChattynatorLoaded()
  local pratLoaded = _PUI_IsPratLoaded()
  _PUI_RefreshChatRuntimeState()


  -- 1) Respect explicit manual disable from options
  if db.manualDisabled then
    db.enabled = false
    return
  end

  local chattyChoice = cdb.chattynator
  local pratChoice   = cdb.prat

  -- 2) Chattynator or Prat already loaded at enable time
  if chattyLoaded then
    if chattyChoice == "chattynator" then
      db.manualDisabled = true
      db.enabled = false
      return
    end

    if chattyChoice == "ask" then
      if db.enabled ~= false and not self.__puiChattynatorPrompted then
        self.__puiChattynatorPrompted = true
        _PUI_ShowChattynatorChoicePopup(self)
      end
      return
    end
  end

  if pratLoaded then
    if pratChoice == "prat" then
      db.manualDisabled = true
      db.enabled = false
      return
    end

    if pratChoice == "ask" then
      if db.enabled ~= false and not self.__puiPratPrompted then
        self.__puiPratPrompted = true
        _PUI_ShowPratChoicePopup(self)
      end
      return
    end
  end

  -- 3) Chattynator NOT loaded (yet)
  -- Watch for Chattynator or Prat loading later in this session.
  if not self.__puiChatConflictAddonHook then
    self.__puiChatConflictAddonHook = true
    self:RegisterEvent("ADDON_LOADED", function(_, event, addonName)
      if addonName ~= "Chattynator" and addonName ~= "Prat-3.0" then
        return
      end

      local dbp = self.db.profile
      _PUI_RefreshChatRuntimeState()

      if dbp.manualDisabled then
        return
      end

      local cdb = _PUI_GetChatConflictDB()

      if addonName == "Chattynator" then
        local choice = cdb.chattynator
        if choice == "chattynator" then
          dbp.manualDisabled = true
          dbp.enabled = false
          _PUI_RefreshChatRuntimeState()
          self:SetUrlFiltersEnabled(false)
          return
        end
        if dbp.enabled == false or choice ~= "ask" then
          return
        end
        if not self.__puiChattynatorPrompted then
          self.__puiChattynatorPrompted = true
          _PUI_ShowChattynatorChoicePopup(self)
        end
        return
      end

      if addonName == "Prat-3.0" then
        local choice = cdb.prat
        if choice == "prat" then
          dbp.manualDisabled = true
          dbp.enabled = false
          _PUI_RefreshChatRuntimeState()
          self:SetUrlFiltersEnabled(false)
          return
        end
        if dbp.enabled == false or choice ~= "ask" then
          return
        end
        if not self.__puiPratPrompted then
          self.__puiPratPrompted = true
          _PUI_ShowPratChoicePopup(self)
        end
        return
      end
    end)
  end

  -- If PleebUI Chat is disabled for any other reason, stop here.
  if db.enabled == false then
    return
  end

  -- 4) From here on, PleebUI Chat is enabled for this
  --    session and Chattynator is NOT loaded.

  self:SetUrlFiltersEnabled(self.db.profile.enableUrlCopy == true)

  -- Blizzard creates both permanent and temporary chat frames.
  -- Refresh visual skinning for the current set and for later frame lifecycle updates.
  self:RefreshChatFrames()
  self:RegisterEvent("UPDATE_CHAT_WINDOWS", "RefreshChatFrames")
  self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "RefreshChatFrames")

  -- Temporary whisper creation must not be hooked synchronously; Blizzard
  -- continues through secret-capable chat/tab state after this function returns.
  if not self._puiTemporaryChatRefreshFrame then
    local tempFrame = CreateFrame("Frame")
    tempFrame:SetScript("OnEvent", function()
      if ChatLinks._puiRuntimeEnabled ~= true or ChatLinks._puiTemporaryChatRefreshTimer then
        return
      end

      ChatLinks._puiTemporaryChatRefreshTimer = C_Timer.NewTimer(0, function()
        ChatLinks._puiTemporaryChatRefreshTimer = nil

        if ChatLinks._puiRuntimeEnabled == true then
          ChatLinks:RefreshChatFrames()
        end
      end)
    end)
    self._puiTemporaryChatRefreshFrame = tempFrame
  end

  local tempFrame = self._puiTemporaryChatRefreshFrame
  tempFrame:RegisterEvent("CHAT_MSG_WHISPER")
  tempFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
  tempFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
  tempFrame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")

  ApplyPrimaryChatHolderLayout(self.db.profile)

  -- Primary chat holder mover
  RegisterPrimaryChatMover()

  -- Start chat fading behaviour once everything exists
  self:ApplyInitialFade()
end


function ChatLinks:OnDisable()
  self._puiRuntimeEnabled = false
  self:SetUrlFiltersEnabled(false)
  self:UnregisterEvent("UPDATE_CHAT_WINDOWS")
  self:UnregisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if self._puiTemporaryChatRefreshFrame then
    self._puiTemporaryChatRefreshFrame:UnregisterAllEvents()
  end
  if self._puiTemporaryChatRefreshTimer then
    self._puiTemporaryChatRefreshTimer:Cancel()
    self._puiTemporaryChatRefreshTimer = nil
  end
  self._pendingCopyOpenFrame = nil
  self._pendingCopyOpenHooked = nil
  self:_CancelFadeTimers()

  local cf = _G.ChatFrame1
  if cf then
    self:_SetChatVisualAlpha(cf, 1)
  end

  StopPrimaryChatMove()
  SetPrimaryChatResizeHandleShown(false)
  FrameUtil:UnregisterMover("Chat_Primary")
end


  _PUI_IsChattynatorLoaded = P:Def("_PUI_IsChattynatorLoaded", _PUI_IsChattynatorLoaded)
  _PUI_IsPratLoaded = P:Def("_PUI_IsPratLoaded", _PUI_IsPratLoaded)
  _PUI_GetChatConflictDB = P:Def("_PUI_GetChatConflictDB", _PUI_GetChatConflictDB)
  _PUI_ConfirmDisablePUIChatAndReload = P:Def("_PUI_ConfirmDisablePUIChatAndReload", _PUI_ConfirmDisablePUIChatAndReload)
  _PUI_ConfirmDisablePUIChatAndReload_PrAt = P:Def("_PUI_ConfirmDisablePUIChatAndReload_PrAt", _PUI_ConfirmDisablePUIChatAndReload_PrAt)
  _PUI_ShowChattynatorChoicePopup = P:Def("_PUI_ShowChattynatorChoicePopup", _PUI_ShowChattynatorChoicePopup)
  _PUI_ShowPratChoicePopup = P:Def("_PUI_ShowPratChoicePopup", _PUI_ShowPratChoicePopup)
  ChatLinks.OnInitialize = P:Def("ChatLinks.OnInitialize", ChatLinks.OnInitialize)
  ForEachBlizzardChatFrame = P:Def("ForEachBlizzardChatFrame", ForEachBlizzardChatFrame)
  ApplyChatTweaks = P:Def("ApplyChatTweaks", ApplyChatTweaks)
  GetNewLog = P:Def("GetNewLog", GetNewLog)
  _PUI_GetPersistentHistoryDB = P:Def("_PUI_GetPersistentHistoryDB", _PUI_GetPersistentHistoryDB)
  _PUI_GetHistoryOptions = P:Def("_PUI_GetHistoryOptions", _PUI_GetHistoryOptions)
  _PUI_CleanStore = P:Def("_PUI_CleanStore", _PUI_CleanStore)
  _PUI_GetHistoryState = P:Def("_PUI_GetHistoryState", _PUI_GetHistoryState)
  _PUI_TrimHistoryState = P:Def("_PUI_TrimHistoryState", _PUI_TrimHistoryState)
  _PUI_ClearSavedHistory = P:Def("_PUI_ClearSavedHistory", _PUI_ClearSavedHistory)
  _PUI_GetRenderableMessages = P:Def("_PUI_GetRenderableMessages", _PUI_GetRenderableMessages)
  _PUI_CaptureExistingDefaultChatFrame = P:Def("_PUI_CaptureExistingDefaultChatFrame", _PUI_CaptureExistingDefaultChatFrame)
  _PUI_RenderHistoryIntoDefaultFrame = P:Def("_PUI_RenderHistoryIntoDefaultFrame", _PUI_RenderHistoryIntoDefaultFrame)
  _PUI_IsChatRuntimeEnabled = P:Def("_PUI_IsChatRuntimeEnabled", _PUI_IsChatRuntimeEnabled)
  _PUI_RefreshChatRuntimeState = P:Def("_PUI_RefreshChatRuntimeState", _PUI_RefreshChatRuntimeState)
  _PUI_BootHistoryOwner = P:Def("_PUI_BootHistoryOwner", _PUI_BootHistoryOwner)
  _PUI_InstallPersistentHistoryHook = P:Def("_PUI_InstallPersistentHistoryHook", _PUI_InstallPersistentHistoryHook)
  ChatProvider = P:Def("ChatProvider", ChatProvider)
  _SafeLinkify = P:Def("_SafeLinkify", _SafeLinkify)
  ChatLinks.SetUrlFiltersEnabled = P:Def("ChatLinks.SetUrlFiltersEnabled", ChatLinks.SetUrlFiltersEnabled)
  _PUI_CF_GetFormatDB = P:Def("_PUI_CF_GetFormatDB", _PUI_CF_GetFormatDB)
  _PUI_CF_SetShowTimestamps = P:Def("_PUI_CF_SetShowTimestamps", _PUI_CF_SetShowTimestamps)
  ChatLinks.ApplyChatFormatting = P:Def("ChatLinks.ApplyChatFormatting", ChatLinks.ApplyChatFormatting)
  EnsureUrlPopupFrame = P:Def("EnsureUrlPopupFrame", EnsureUrlPopupFrame)
  ShowUrlPopup = P:Def("ShowUrlPopup", ShowUrlPopup)
  _PUI_GetTypographyDB = P:Def("_PUI_GetTypographyDB", _PUI_GetTypographyDB)
  _PUI_GetTypographyFont = P:Def("_PUI_GetTypographyFont", _PUI_GetTypographyFont)
  _PUI_SkinTypographyFont = P:Def("_PUI_SkinTypographyFont", _PUI_SkinTypographyFont)
  _PUI_ApplyTypographyToChatFrame = P:Def("_PUI_ApplyTypographyToChatFrame", _PUI_ApplyTypographyToChatFrame)
  ChatLinks.ApplyChatTypography = P:Def("ChatLinks.ApplyChatTypography", ChatLinks.ApplyChatTypography)
  ChatLinks.RefreshFonts = P:Def("ChatLinks.RefreshFonts", ChatLinks.RefreshFonts)
  GetChatFrameLines = P:Def("GetChatFrameLines", GetChatFrameLines)
  _PUI_CleanCopyText = P:Def("_PUI_CleanCopyText", _PUI_CleanCopyText)
  _PUI_RefreshCopyWindow = P:Def("_PUI_RefreshCopyWindow", _PUI_RefreshCopyWindow)
  ChatLinks.RefreshCopyWindow = P:Def("ChatLinks.RefreshCopyWindow", ChatLinks.RefreshCopyWindow)
  _GetCopyStyle = P:Def("_GetCopyStyle", _GetCopyStyle)
  _GetChatWindowStyle = P:Def("_GetChatWindowStyle", _GetChatWindowStyle)
  ChatLinks.ApplyChatWindowStyle = P:Def("ChatLinks.ApplyChatWindowStyle", ChatLinks.ApplyChatWindowStyle)
  _PUI_GetBackdropTarget = P:Def("_PUI_GetBackdropTarget", _PUI_GetBackdropTarget)
  _ApplyBorderSize = P:Def("_ApplyBorderSize", _ApplyBorderSize)
  _ApplyBackdropStyle = P:Def("_ApplyBackdropStyle", _ApplyBackdropStyle)
  _PUI_EnsureTextureBackdrop = P:Def("_PUI_EnsureTextureBackdrop", _PUI_EnsureTextureBackdrop)
  _PUI_ApplyTextureBackdrop = P:Def("_PUI_ApplyTextureBackdrop", _PUI_ApplyTextureBackdrop)
  _ApplyDirectChatShellBackdrop = P:Def("_ApplyDirectChatShellBackdrop", _ApplyDirectChatShellBackdrop)
  _DisableChatButtonFrame = P:Def("_DisableChatButtonFrame", _DisableChatButtonFrame)
  ChatLinks.ApplyCopyWindowStyle = P:Def("ChatLinks.ApplyCopyWindowStyle", ChatLinks.ApplyCopyWindowStyle)
  SaveCopyFramePosition = P:Def("SaveCopyFramePosition", SaveCopyFramePosition)
  ApplyCopyFramePosition = P:Def("ApplyCopyFramePosition", ApplyCopyFramePosition)
  _RegisterAsSpecialFrame = P:Def("_RegisterAsSpecialFrame", _RegisterAsSpecialFrame)
  EnsureCopyFrame = P:Def("EnsureCopyFrame", EnsureCopyFrame)
  ApplyPrimaryChatHolderLayout = P:Def("ApplyPrimaryChatHolderLayout", ApplyPrimaryChatHolderLayout)
  BindPrimaryChatFrame = P:Def("BindPrimaryChatFrame", BindPrimaryChatFrame)
  InitializePrimaryChatLayout = P:Def("InitializePrimaryChatLayout", InitializePrimaryChatLayout)
  GetPrimaryChatMoverInsets = P:Def("GetPrimaryChatMoverInsets", GetPrimaryChatMoverInsets)
  SavePrimaryChatLayout = P:Def("SavePrimaryChatLayout", SavePrimaryChatLayout)
  StopPrimaryChatMove = P:Def("StopPrimaryChatMove", StopPrimaryChatMove)
  StartPrimaryChatMove = P:Def("StartPrimaryChatMove", StartPrimaryChatMove)
  EnablePrimaryChatTabDragging = P:Def("EnablePrimaryChatTabDragging", EnablePrimaryChatTabDragging)
  StopPrimaryChatResize = P:Def("StopPrimaryChatResize", StopPrimaryChatResize)
  UpdatePrimaryChatResize = P:Def("UpdatePrimaryChatResize", UpdatePrimaryChatResize)
  StartPrimaryChatResize = P:Def("StartPrimaryChatResize", StartPrimaryChatResize)
  EnsurePrimaryChatResizeHandle = P:Def("EnsurePrimaryChatResizeHandle", EnsurePrimaryChatResizeHandle)
  SetPrimaryChatResizeHandleShown = P:Def("SetPrimaryChatResizeHandleShown", SetPrimaryChatResizeHandleShown)
  RegisterPrimaryChatMover = P:Def("RegisterPrimaryChatMover", RegisterPrimaryChatMover)
  ChatLinks.OnEditModeChanged = P:Def("ChatLinks.OnEditModeChanged", ChatLinks.OnEditModeChanged)
  ChatLinks._SetChatVisualAlpha = P:Def("ChatLinks._SetChatVisualAlpha", ChatLinks._SetChatVisualAlpha)
  ChatLinks._CancelFadeTimers = P:Def("ChatLinks._CancelFadeTimers", ChatLinks._CancelFadeTimers)
  ChatLinks._AnimateChatVisualAlpha = P:Def("ChatLinks._AnimateChatVisualAlpha", ChatLinks._AnimateChatVisualAlpha)
  ChatLinks._ScheduleIdleVisualFade = P:Def("ChatLinks._ScheduleIdleVisualFade", ChatLinks._ScheduleIdleVisualFade)
  ChatLinks.ChatInputActivated = P:Def("ChatLinks.ChatInputActivated", ChatLinks.ChatInputActivated)
  ChatLinks.ChatInputDeactivated = P:Def("ChatLinks.ChatInputDeactivated", ChatLinks.ChatInputDeactivated)
  ChatLinks.ApplyInitialFade = P:Def("ChatLinks.ApplyInitialFade", ChatLinks.ApplyInitialFade)
  ChatLinks.OpenCopyWindow = P:Def("ChatLinks.OpenCopyWindow", ChatLinks.OpenCopyWindow)
  EnsureChatInputBar = P:Def("EnsureChatInputBar", EnsureChatInputBar)
  SkinChatEditBox = P:Def("SkinChatEditBox", SkinChatEditBox)
  SkinChatTab = P:Def("SkinChatTab", SkinChatTab)
  CreateJumpToBottomButton = P:Def("CreateJumpToBottomButton", CreateJumpToBottomButton)
  SkinChatFrame = P:Def("SkinChatFrame", SkinChatFrame)
  HideChatSideButtons = P:Def("HideChatSideButtons", HideChatSideButtons)
  _PUI_ClickBlizzardChatTool = P:Def("_PUI_ClickBlizzardChatTool", _PUI_ClickBlizzardChatTool)
  EnsureChatToolsButton = P:Def("EnsureChatToolsButton", EnsureChatToolsButton)
  CreateCopyButton = P:Def("CreateCopyButton", CreateCopyButton)
  ChatLinks.RefreshChatFrames = P:Def("ChatLinks.RefreshChatFrames", ChatLinks.RefreshChatFrames)
  ChatLinks.RefreshTheme = P:Def("ChatLinks.RefreshTheme", ChatLinks.RefreshTheme)
  ChatLinks.OnProfileChanged = P:Def("ChatLinks.OnProfileChanged", ChatLinks.OnProfileChanged)
  ChatLinks.OnEnable = P:Def("ChatLinks.OnEnable", ChatLinks.OnEnable)
  ChatLinks.OnDisable = P:Def("ChatLinks.OnDisable", ChatLinks.OnDisable)





