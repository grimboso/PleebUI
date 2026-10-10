local _, ns = ...

local Addon    = ns.Addon

local FrameUtil = ns.FrameUtil
local OptionsUtil = ns.OptionsUtil
local Round = ns.Pixel.Round

local ChatLinks = Addon:NewModule("ChatLinks", "NumyAceEvent-3.0")
ns.Registry.ChatLinks = ChatLinks

local P = ns.Pleebug:DropIn(ChatLinks, { name = "Modules.Chat" })

local function ClampInt(value, minimum, maximum)
  value = math.floor(tonumber(value) or minimum)
  if value < minimum then value = minimum end
  if value > maximum then value = maximum end
  return value
end

local function ForEachBlizzardChatFrame(callback)
  for _, chatFrameName in pairs(_G.CHAT_FRAMES) do
    local chatFrame = _G[chatFrameName]
    if canaccessvalue(chatFrame) and chatFrame then
      callback(chatFrame)
    end
  end
end

local function _PUI_IsTemporaryChatFrame(chatFrame)
  if not chatFrame then
    return false
  end

  return canaccessvalue(chatFrame.isTemporary) and chatFrame.isTemporary == true
end

local function _PUI_IsChatFrameOpen(chatFrame)
  if not chatFrame then
    return false
  end

  if not canaccessallvalues(chatFrame.isTemporary, chatFrame.inUse) then return false end
  if chatFrame.isTemporary == true then
    return chatFrame.inUse == true
  end

  local id = chatFrame:GetID()
  return id > 0 and FCF_IsChatWindowIndexActive(id)
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
        mod:OnEnable()
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
        mod:OnEnable()
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

      -- Chat tweaks
      chatTweaks = {
        persistHistory = true,   -- persist chat history between sessions
        savedLines     = 256,
        historyTypes = {
          WHISPER = true, GUILD = true, PARTY = true, RAID = true, INSTANCE = true,
          CHANNEL = true, SAY = true, YELL = true, EMOTE = true,
        },
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

      chatFade = {
        fadeWindow = false,
        windowDelay = 2,
        windowFadeInAlpha = 1,
        windowFadeOutAlpha = 0,
        windowFadeInDuration = 0.3,
        windowFadeOutDuration = 0.3,
        enabled = true,
        idleDelay = 100,
        fadeUndockedTabs = false,
        fadeTabsNoBackdrop = true,
      },
    },
  })
  self.db.profile.chatTweaks.maxLines = nil
  self.db.profile.copyClean = nil

  _G.PleebUIAPI:RegisterPlugin("PleebUI_Chat", {
    name = "Chat",
  }):RegisterEditModeParticipant("runtime", {
    order = 20,
    onChanged = function(enable)
      self:OnEditModeChanged(enable)
    end,
  })
end

local HideChatSideButtons

local ChatFrameState = setmetatable({}, { __mode = "k" })
local ChatTabState = setmetatable({}, { __mode = "k" })
local ChatEditBoxState = setmetatable({}, { __mode = "k" })
local NativeVisuals = setmetatable({}, { __mode = "k" })

local function CanChangeChatLayout(region)
  if not InCombatLockdown() then return true end
  local protected = region:IsProtected()
  return canaccessvalue(protected) and not protected
end

local function SaveNativeVisual(region, geometry)
  local state = NativeVisuals[region]
  if not state then
    state = {}
    NativeVisuals[region] = state
    local shown = region:IsShown()
    if region.IsMouseEnabled then
      local mouse = region:IsMouseEnabled()
      if canaccessvalue(mouse) then state.mouse = mouse end
    end
    if canaccessvalue(shown) then state.shown = shown end
    if region:IsObjectType("Texture") then
      local texture, atlas = region:GetTexture(), region:GetAtlas()
      local r, g, b, a = region:GetVertexColor()
      if canaccessallvalues(texture, atlas, r, g, b, a) then
        state.texture = { path = texture, atlas = atlas, r = r, g = g, b = b, a = a }
      end
    elseif region.SetFont and region.GetFont then
      if region:IsObjectType("FontString") then
        local r, g, b, a = region:GetTextColor()
        local horizontal, vertical, wrap = region:GetJustifyH(), region:GetJustifyV(), region:CanWordWrap()
        if canaccessallvalues(r, g, b, a, horizontal, vertical, wrap) then
          state.textStyle = {r, g, b, a, horizontal, vertical, wrap}
        end
      end
      local font, size, flags = region:GetFont()
      if canaccessallvalues(font, size, flags) and font and size then state.font = {font, size, flags} end
    end
  end
  if geometry and not state.points then
    local count = region:GetNumPoints()
    if not canaccessvalue(count) then return end
    local points = {}
    for i = 1, count do
      local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
      if not canaccessallvalues(point, relativeTo, relativePoint, x, y) then return end
      points[i] = {point, relativeTo, relativePoint, x, y}
    end
    state.points = points
    local width, height = region:GetSize()
    if canaccessallvalues(width, height) then state.size = {width, height} end
  end
end

local function RestoreNativeVisuals()
  for region, state in pairs(NativeVisuals) do
    if state.opacityReset then region:SetAlpha(1) end
    if state.texture then
      local texture = state.texture
      if texture.atlas then region:SetAtlas(texture.atlas) else region:SetTexture(texture.path) end
      region:SetVertexColor(texture.r, texture.g, texture.b, texture.a)
    end
    if state.mouse ~= nil and CanChangeChatLayout(region) then region:EnableMouse(state.mouse) end
    if state.font then region:SetFont(unpack(state.font)) end
    if state.textStyle then
      local style = state.textStyle
      region:SetTextColor(style[1], style[2], style[3], style[4])
      region:SetJustifyH(style[5])
      region:SetJustifyV(style[6])
      region:SetWordWrap(style[7])
    end
    if state.points and CanChangeChatLayout(region) then
      if state.size then region:SetSize(unpack(state.size)) end
      region:ClearAllPoints()
      for _, point in ipairs(state.points) do region:SetPoint(unpack(point)) end
    end
    if state.shown ~= nil and CanChangeChatLayout(region) then region:SetShown(state.shown) end
  end
end

local function GetChatFrameState(chatFrame)
  local state = ChatFrameState[chatFrame]
  if not state then
    state = {}
    ChatFrameState[chatFrame] = state
  end
  return state
end

local function GetChatTabState(tab)
  local state = ChatTabState[tab]
  if not state then
    state = {}
    ChatTabState[tab] = state
  end
  return state
end

local function GetChatEditBoxState(editBox)
  local state = ChatEditBoxState[editBox]
  if not state then
    state = {}
    ChatEditBoxState[editBox] = state
  end
  return state
end

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

local _PUI_GetTypographyDB

local function ChatProvider(AddonObj)
  local provider = {}

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
    if t.savedLines == nil then t.savedLines = 256 end
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

                if v then
                  ChatLinks:OnEnable()
                else
                  ChatLinks:OnDisable()
                end

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
            copyHint = {
              type = "description",
              name = "Open chat text ready to copy with Ctrl+C. Colors, icons, and link codes are removed while keeping readable names.",
              order = 1,
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
                return IsLocked() or f.timestamps == false
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
            fadeWindow = {
              type = "toggle",
              name = "Fade chat window",
              desc = "Fade the entire chat window when you are not typing or hovering over it.",
              order = 5,
              disabled = IsLocked,
              get = function() return db.chatFade.fadeWindow end,
              set = function(_, value)
                db.chatFade.fadeWindow = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            windowDelay = {
              type = "range",
              name = "Fade-out delay",
              desc = "Seconds to wait after a new message, leaving the chat window, or finishing typing.",
              order = 6,
              min = 0,
              max = 30,
              step = 0.5,
              disabled = function() return IsLocked() or not db.chatFade.fadeWindow end,
              get = function() return db.chatFade.windowDelay end,
              set = function(_, value)
                db.chatFade.windowDelay = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            windowFadeInAlpha = {
              type = "range",
              name = "Fade-in opacity",
              desc = "Chat opacity while typing, hovering, or reading a new message.",
              order = 7,
              min = 0,
              max = 1,
              step = 0.05,
              isPercent = true,
              disabled = function() return IsLocked() or not db.chatFade.fadeWindow end,
              get = function() return db.chatFade.windowFadeInAlpha end,
              set = function(_, value)
                db.chatFade.windowFadeInAlpha = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            windowFadeOutAlpha = {
              type = "range",
              name = "Fade-out opacity",
              desc = "Chat opacity after the fade-out delay.",
              order = 8,
              min = 0,
              max = 1,
              step = 0.05,
              isPercent = true,
              disabled = function() return IsLocked() or not db.chatFade.fadeWindow end,
              get = function() return db.chatFade.windowFadeOutAlpha end,
              set = function(_, value)
                db.chatFade.windowFadeOutAlpha = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            windowFadeInDuration = {
              type = "range",
              name = "Fade-in duration",
              desc = "Seconds for the chat to reach its fade-in opacity. Zero changes it instantly.",
              order = 9,
              min = 0,
              max = 5,
              step = 0.05,
              disabled = function() return IsLocked() or not db.chatFade.fadeWindow end,
              get = function() return db.chatFade.windowFadeInDuration end,
              set = function(_, value)
                db.chatFade.windowFadeInDuration = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            windowFadeOutDuration = {
              type = "range",
              name = "Fade-out duration",
              desc = "Seconds for the chat to reach its fade-out opacity. Zero changes it instantly.",
              order = 10,
              min = 0,
              max = 5,
              step = 0.05,
              disabled = function() return IsLocked() or not db.chatFade.fadeWindow end,
              get = function() return db.chatFade.windowFadeOutDuration end,
              set = function(_, value)
                db.chatFade.windowFadeOutDuration = value
                ChatLinks:UpdateChatFocusFading(ns.Flags.IsEditing)
              end,
            },
            enabled = {
              type = "toggle",
              name = "Fade chat text",
              desc = "Fade older messages after a period of inactivity.",
              order = 1,
              disabled = IsLocked,
              get = function() return db.chatFade.enabled end,
              set = function(_, value)
                db.chatFade.enabled = value
                ChatLinks:UpdateChatFading()
              end,
            },
            idleDelay = {
              type = "range",
              name = "Inactivity timer",
              order = 2,
              min = 5,
              max = 600,
              softMax = 120,
              step = 1,
              disabled = function() return IsLocked() or not db.chatFade.enabled end,
              get = function() return db.chatFade.idleDelay end,
              set = function(_, value)
                db.chatFade.idleDelay = value
                ChatLinks:UpdateChatFading()
              end,
            },
            fadeUndockedTabs = {
              type = "toggle",
              name = "Fade undocked tabs",
              desc = "Show undocked tab text while hovering over the tab or chat window.",
              order = 3,
              disabled = IsLocked,
              get = function() return db.chatFade.fadeUndockedTabs end,
              set = function(_, value)
                db.chatFade.fadeUndockedTabs = value
                ChatLinks:RefreshChatTabs()
              end,
            },
            fadeTabsNoBackdrop = {
              type = "toggle",
              name = "Fade tabs without a background",
              desc = "Show docked tab text on hover when the chat background is transparent.",
              order = 4,
              disabled = IsLocked,
              get = function() return db.chatFade.fadeTabsNoBackdrop end,
              set = function(_, value)
                db.chatFade.fadeTabsNoBackdrop = value
                ChatLinks:RefreshChatTabs()
              end,
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
                  ChatLinks:StartChatHistory()
                else
                  ChatLinks:StopChatHistory()
                end
              end,
            },

            savedLines = {
              type = "range",
              name = "History lines per tab",
              desc = "Maximum saved messages per tab and per whisper conversation. Trade and Services are never saved.",
              order = 3,
              min = 10,
              max = 5000,
              step = 1,
              disabled = function()
                return IsLocked() or t.persistHistory == false
              end,
              get = function()
                return ClampInt(t.savedLines, 10, 5000)
              end,
              set = function(_, value)
                t.savedLines = ClampInt(value, 10, 5000)
                ChatLinks:StartChatHistory()
                ChatLinks:QueueChatVisualRefresh()
              end,
            },

            historyTypes = {
              type = "multiselect",
              name = "History types",
              desc = "Save and restore these chat types. Channels exclude Trade and Services.",
              order = 4,
              values = ChatLinks.ChatHistoryTypes,
              disabled = function()
                return IsLocked() or t.persistHistory == false
              end,
              get = function(_, category)
                return t.historyTypes[category]
              end,
              set = function(_, category, enabled)
                t.historyTypes[category] = enabled
              end,
            },

            scrollMessages = {
              type = "range",
              name = "Mouse wheel lines",
              order = 5,
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
              order = 6,
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
                    ChatLinks:ClearChatHistory()
                    ChatLinks:RefreshCopyWindow()
                  end,
                })
              end,
            },
          },
        },
      },
    }

    local sections = options.args
    local featureArgs = sections.features.args
    featureArgs.lockedNote = sections.status.args.lockedNote
    featureArgs.lockedNote.order = 0
    featureArgs.timestamps = sections.formatting.args.timestamps
    featureArgs.tsPreset = sections.formatting.args.tsPreset
    featureArgs.timestamps.order, featureArgs.tsPreset.order = 50, 60
    featureArgs.scrollMessages = sections.tweaks.args.scrollMessages
    featureArgs.scrollMessages.order = 70
    sections.tweaks.args.scrollMessages = nil
    sections.tweaks.name, sections.tweaks.inline = "Saved chat history", true
    local style = sections.chatStyle
    style.inline, style.order = true, 10
    style.args.bg.name, style.args.border.name = "Background color", "Border color"
    style.args.borderSize.name = "Border thickness"
    local typography = sections.typography.args
    typography.message.order, typography.tab.order, typography.input.order = 20, 30, 40
    local copy = sections.copyStyle
    local copyArgs = copy.args.appearance.args
    copyArgs.width, copyArgs.height = copy.args.size.args.width, copy.args.size.args.height
    copyArgs.copyHint = copy.args.copyHint
    copyArgs.copyHint.order = 0
    copyArgs.borderSize.name = "Border thickness"
    copy.args, copy.inline, copy.order = copyArgs, true, 10
    local fade = sections.fade.args
    fade.windowDelay.name = "Fade-out delay (seconds)"
    fade.windowFadeInDuration.name = "Fade-in time (seconds)"
    fade.windowFadeOutDuration.name = "Fade-out time (seconds)"
    fade.idleDelay.name = "Inactivity time (seconds)"
    options.childGroups = "tree"
    options.arg = { puiExplicit = true }
    options.args = {
      general = { type = "group", name = "General", order = 10, args = {
        features = { type = "group", name = "Features and formatting", inline = true, order = 10, args = featureArgs },
        history = sections.tweaks,
      } },
      appearance = { type = "group", name = "Appearance", order = 20, args = {
        window = style, message = typography.message, tab = typography.tab, input = typography.input,
      } },
      tools = { type = "group", name = "Copying and fading", order = 30, args = {
        copy = copy,
        windowFade = { type = "group", name = "Window fading", inline = true, order = 20, args = {
          fadeWindow = fade.fadeWindow, windowDelay = fade.windowDelay,
          windowFadeInAlpha = fade.windowFadeInAlpha, windowFadeOutAlpha = fade.windowFadeOutAlpha,
          windowFadeInDuration = fade.windowFadeInDuration, windowFadeOutDuration = fade.windowFadeOutDuration,
        } },
        textFade = { type = "group", name = "Text and tab fading", inline = true, order = 30, args = {
          enabled = fade.enabled, idleDelay = fade.idleDelay,
          fadeUndockedTabs = fade.fadeUndockedTabs, fadeTabsNoBackdrop = fade.fadeTabsNoBackdrop,
        } },
      } },
    }

    return options
  end

  return provider
end

Addon:RegisterOptionsSection("Chat", ChatProvider, 60, "Chat", nil, {
  preview = false,
})

local ApplyPrimaryChatLayout
local _PUI_OnSetItemRef

local function LinkifyChatURLs(message)
  local linked = message:gsub("%S+", function(word)
    if word:find("|", 1, true) then
      return word
    end
    local url
    if word:match("^[%a][%w+.-]*://") then
      url = word
    elseif word:match("^www%.") then
      url = "http://" .. word
    elseif word:match("^discord%.gg/") then
      url = "https://" .. word
    elseif word:match("^[%w%._%%%-]+@[%w%._%%%-]+%.%a+$") then
      url = "mailto:" .. word
    elseif word:match("^[-%w_%%]+%.%a+/") then
      url = "http://" .. word
    end
    if url then
      return "|cff00ccff|Haddon:pleebuiurl:" .. url .. "|h[" .. word .. "]|h|r"
    end
    return word
  end)
  return linked
end

local function _PUI_UrlMessageFilter(chatFrame, _, msg, ...)
  if ChatLinks._puiRuntimeEnabled ~= true
    or ChatLinks.db.profile.enableUrlCopy ~= true
    or not canaccessallvalues(chatFrame, _G.ChatFrame2)
    or chatFrame == _G.ChatFrame2
  then
    return
  end

  if C_ChatInfo.InChatMessagingLockdown() or not canaccessvalue(msg) or type(msg) ~= "string" then
    return
  end

  local hasProtocol = msg:find("://", 1, true) ~= nil
  local hasWWW = msg:find("www.", 1, true) ~= nil
  local hasDiscord = msg:find("discord.gg/", 1, true) ~= nil
  local hasEmail = msg:find("@", 1, true) ~= nil
  local hasBareDomain = false

  if msg:find(".", 1, true) and msg:find("/", 1, true) then
    hasBareDomain = msg:find("%f[%w][-%w_%%]+%.%a+/%S+") ~= nil
  end

  if (hasProtocol or hasWWW or hasDiscord or hasEmail or hasBareDomain)
    and not msg:find("|Haddon:pleebuiurl:", 1, true)
  then
    return false, LinkifyChatURLs(msg), ...
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
  then
    return
  end

  if not canaccessvalue(link) or type(link) ~= "string" then
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

  SaveNativeVisual(fontObject)
  local fontPath, outline = _PUI_GetTypographyFont(area)
  fontObject:SetFont(fontPath, currentSize, outline)
end

local function _PUI_ApplyTypographyToChatFrame(chatFrame)
  local typography = _PUI_GetTypographyDB()

  _PUI_SkinTypographyFont(chatFrame, typography.message)

  local name = chatFrame.GetName and chatFrame:GetName()
  if canaccessvalue(chatFrame.isDocked) and not chatFrame.isDocked and not _PUI_IsTemporaryChatFrame(chatFrame) then
    local tab = chatFrame.tab or (name and _G[name .. "Tab"])
    local tabText = tab and (tab.Text or tab.text or (tab.GetFontString and tab:GetFontString()))
    _PUI_SkinTypographyFont(tabText, typography.tab)
  end

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

  self:QueueChatVisualRefresh()
end

local CopyFrame
local CopyEditBox
local CopySearchBox
local CopyCountText
local CopyTextButton
local CopySourceLines = {}

local function GetChatFrameLines(chatFrame)
  if not chatFrame or not chatFrame.GetNumMessages then
    return {}
  end

  local out = {}
  local num = chatFrame:GetNumMessages()
  if not canaccessvalue(num) or type(num) ~= "number" then
    return out
  end

  for i = 1, num do
    local msg, r, g, b = chatFrame:GetMessageInfo(i)
    if canaccessallvalues(msg, r, g, b) and type(msg) == "string" and not msg:find("|K", 1, true) then
      out[#out + 1] = { text = msg, r = r, g = g, b = b }
    end
  end

  return out
end

local function _PUI_CleanCopyText(text)
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|T.-|t", "")
  text = text:gsub("|A.-|a", "")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|cn[%w_]+:", "")
  text = text:gsub("|r", "")
  return text
end

function ChatLinks:RefreshCopyWindow()
  if not CopyEditBox then
    return
  end

  local query = CopySearchBox:GetText():lower()
  local copied = {}
  for i = 1, #CopySourceLines do
    local cleanText = _PUI_CleanCopyText(CopySourceLines[i].text)
    if query == "" or cleanText:lower():find(query, 1, true) then
      copied[#copied + 1] = cleanText
    end
  end

  CopyEditBox:SetText(table.concat(copied, "\n"))
  CopyEditBox:HighlightText()
  CopyCountText:SetFormattedText("%d of %d lines", #copied, #CopySourceLines)
  CopyTextButton:SetEnabled(#copied > 0)
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
  if self._puiRuntimeEnabled ~= true then
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

  CopyFrame:HookScript("OnSizeChanged", function(f)
    SaveCopyFramePosition(f)
    ChatLinks:ApplyCopyWindowStyle()
  end)

  CopyFrame:SetFrameStrata("DIALOG")
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
  CopySearchBox:SetScript("OnTextChanged", function(self)
    searchHint:SetShown(self:GetText() == "")
    ChatLinks:RefreshCopyWindow()
  end)
  CopySearchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  CopyTextButton = CreateFrame("Button", nil, CopyFrame, "UIPanelButtonTemplate")
  CopyTextButton:SetSize(100, 24)
  CopyTextButton:SetPoint("TOPRIGHT", -140, -34)
  CopyTextButton:SetText("Select all")
  CopyTextButton:SetScript("OnClick", function()
    CopySearchBox:ClearFocus()
    CopyEditBox:SetFocus()
    CopyEditBox:HighlightText()
  end)
  ns.Theme.WidgetSkins.UIButton(CopyTextButton)

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
        ChatLinks:ClearChatHistory()
      end,
    })
  end)
  ns.Theme.WidgetSkins.UIButton(clearHistory)

  CopyCountText = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  CopyCountText:SetPoint("TOPLEFT", 16, -63)
  CopyCountText:SetText("0 of 0 lines")
  Theme.ApplyFont(CopyCountText, "body", 11)

  local copyHint = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  copyHint:SetPoint("BOTTOMLEFT", 16, 12)
  copyHint:SetText("Press Ctrl+C to copy the selected text.")

  local scroll = CreateFrame("ScrollFrame", "PleebUIChatCopyScrollFrame", CopyFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -84)
  scroll:SetPoint("BOTTOMRIGHT", -34, 34)
  ns.Theme.WidgetSkins.Scrollbar(scroll)

  CopyEditBox = CreateFrame("EditBox", "PleebUIChatCopyEditBox", scroll, "BackdropTemplate")
  CopyEditBox:SetMultiLine(true)
  CopyEditBox:SetMaxLetters(0)
  CopyEditBox:EnableMouse(true)
  CopyEditBox:SetAutoFocus(false)
  CopyEditBox:SetFontObject(ChatFontNormal)
  CopyEditBox:SetTextColor(1, 1, 1)
  CopyEditBox:SetWidth(540)

  scroll:HookScript("OnSizeChanged", function(self)
    CopyEditBox:SetWidth(math.max(1, self:GetWidth() - 4))
  end)
  CopyEditBox:SetScript("OnEscapePressed", function()
    CopyFrame:Hide()
  end)
  CopyFrame:SetScript("OnHide", function()
    CopyEditBox:ClearFocus()
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

local BindPrimaryChatFrame

local function PositionAddonPointFromFrame(visual, target, point, xOffset, yOffset)
  if not visual or not target then
    return false
  end
  visual:ClearAllPoints()
  visual:SetPoint(point, target, point, xOffset or 0, yOffset or 0)
  return true
end

local function EnsurePrimaryChatHolder()
  local holder = ChatLinks._primaryChatHolder
  if holder then
    return holder
  end

  holder = CreateFrame("Frame", "PleebUI_PrimaryChatHolder", UIParent)
  holder:SetSize(Round(430), Round(180))
  holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Round(32), Round(32))
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

  if not CanChangeChatLayout(holder) or not CanChangeChatLayout(_G.ChatFrame1) then
    ChatLinks._puiPendingPrimaryChatBind = true
    return holder
  end

  local point      = cfg.point or "BOTTOMLEFT"
  local relName    = cfg.relativeTo or "UIParent"
  local relFrame   = _G[relName] or UIParent
  local relPoint   = cfg.relativePoint or point
  local x          = Round(tonumber(cfg.x) or 32)
  local y          = Round(tonumber(cfg.y) or 32)

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
  holder:SetSize(Round(tonumber(cfg.width) or 430), Round(tonumber(cfg.height) or 180))
  BindPrimaryChatFrame(holder, _G.ChatFrame1)
  return holder
end

BindPrimaryChatFrame = function(holder, chatFrame)
  if ChatLinks._puiRuntimeEnabled ~= true or not holder or not chatFrame then
    return false
  end

  if not ChatLinks:IsChatLayoutReady() or not CanChangeChatLayout(chatFrame) then
    ChatLinks._puiPendingPrimaryChatBind = true
    return false
  end

  chatFrame:ClearAllPoints()
  chatFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  chatFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  chatFrame:SetClampRectInsets(0, 0, 0, 0)
  chatFrame:SetClampedToScreen(false)
  ChatLinks._puiPendingPrimaryChatBind = nil

  return true
end

-- This is the only lifecycle path that writes Blizzard chat-frame anchors.
ApplyPrimaryChatLayout = function()
  if ChatLinks._puiRuntimeEnabled ~= true then
    return
  end

  local db = ChatLinks.db and ChatLinks.db.profile
  if not db then
    return
  end

  ApplyPrimaryChatHolderLayout(db)
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
  cfg.x = Round(x or 0)
  cfg.y = Round(y or 0)
  cfg.width = ClampInt(holder:GetWidth(), 220, 1000)
  cfg.height = ClampInt(holder:GetHeight(), 100, 700)
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
    ApplyPrimaryChatHolderLayout(ChatLinks.db.profile)
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

  local width = Round(ClampInt(state.width + cursorX - state.cursorX, 220, 1000))
  local height = Round(ClampInt(state.height - cursorY + state.cursorY, 100, 700))

  state.holder:ClearAllPoints()
  state.holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", Round(state.left), Round(state.top))
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
    left = Round(left),
    top = Round(top),
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
    moduleKey = "chat",
    moduleLabel = "Chat",
    overlayInsets = GetPrimaryChatMoverInsets,

    savePosition = SavePrimaryChatLayout,

    resetPosition = function()
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

      ApplyPrimaryChatHolderLayout(db)
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
              ApplyPrimaryChatHolderLayout(ChatLinks.db.profile)
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
              ApplyPrimaryChatHolderLayout(ChatLinks.db.profile)
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
  self:UpdateChatFocusFading(enable)
  if enable then
    RegisterPrimaryChatMover()
  else
    SetPrimaryChatResizeHandleShown(self._puiRuntimeEnabled == true)
  end
end

function ChatLinks:OpenCopyWindow(chatFrame)
  if self._puiRuntimeEnabled ~= true or self.db.profile.enableCopyFrame ~= true then
    return
  end

  EnsureCopyFrame()

  local frame = chatFrame or _G.DEFAULT_CHAT_FRAME
  CopySourceLines = GetChatFrameLines(frame)
  local font, size, flags = frame:GetFont()
  if canaccessallvalues(font, size, flags) and font and size then
    CopyEditBox:SetFont(font, size, flags)
  end
  CopySearchBox:SetText("")
  ChatLinks:RefreshCopyWindow()
  CopyFrame:Show()
  CopySearchBox:ClearFocus()
  CopyEditBox:SetFocus()
  CopyEditBox:HighlightText()
end

-- Chat frame shell, tabs, side buttons and copy button wiring.

-- Skin the chat edit box (bottom input)
local function SkinChatEditBox(chatFrame)
  if not chatFrame then return end
  local name = chatFrame.GetName and chatFrame:GetName()
  if not name then return end

  local editBox = _G[name .. "EditBox"]
  if not editBox then
    return
  end

  local colors = ns.Theme.GetColors()
  _PUI_ApplyTextureBackdrop(editBox, colors.control, colors.border, ns.Theme.GetEdgeSize())
  editBox._puiTextureBackdrop.fill:Show()

  local state = GetChatEditBoxState(editBox)
  if state.skinned then
    return
  end

  local Theme = ns.Theme

  -- Hide Blizzard textures
  for _, suffix in ipairs({ "EditBoxLeft", "EditBoxRight", "EditBoxMid" }) do
    local tex = _G[name .. suffix]
    if tex and tex.SetAlpha then
      SaveNativeVisual(tex)
      tex:SetAlpha(0)
    end
  end

  if editBox.focusLeft and editBox.focusLeft.SetAlpha then
    SaveNativeVisual(editBox.focusLeft)
    editBox.focusLeft:SetAlpha(0)
  end
  if editBox.focusRight and editBox.focusRight.SetAlpha then
    SaveNativeVisual(editBox.focusRight)
    editBox.focusRight:SetAlpha(0)
  end
  if editBox.focusMid and editBox.focusMid.SetAlpha then
    SaveNativeVisual(editBox.focusMid)
    editBox.focusMid:SetAlpha(0)
  end

  for _, region in ipairs({ editBox:GetRegions() }) do
    if region:IsObjectType("FontString") then
      SaveNativeVisual(region)
      Theme.ApplyFont(region, "body", 12, "OUTLINE")
    end
  end

  state.skinned = true
end

local function SkinChatTab(chatFrame)
  local tab = _G[chatFrame:GetName() .. "Tab"]
  if not tab then return end
  local state = GetChatTabState(tab)
  local Theme = ns.Theme
  local style = _GetChatWindowStyle()
  _PUI_ApplyTextureBackdrop(tab, style.bg, style.border, tonumber(style.borderSize) or Theme.GetEdgeSize())
  SaveNativeVisual(tab, true)
  tab:SetHeight(22)

  if not state.skinned then
    for _, key in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveRight", "HighlightLeft", "HighlightRight" }) do
      local texture = tab[key]
      if texture then SaveNativeVisual(texture); texture:SetTexture(nil) end
    end
    SaveNativeVisual(tab.ActiveMiddle, true)
    SaveNativeVisual(tab.HighlightMiddle, true)
    SaveNativeVisual(tab.glow, true)
    tab.ActiveMiddle:SetTexture("Interface\\Buttons\\WHITE8x8")
    tab.ActiveMiddle:SetAllPoints(tab)
    tab.HighlightMiddle:SetTexture("Interface\\Buttons\\WHITE8x8")
    tab.HighlightMiddle:SetAllPoints(tab)
    tab.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    tab.glow:ClearAllPoints()
    tab.glow:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 1)
    tab.glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 1)
    tab.glow:SetHeight(2)
    state.skinned = true
  end
  local colors = Theme.GetColors()
  local accent = colors.accent
  tab.ActiveMiddle:SetVertexColor(accent[1], accent[2], accent[3], 0.32)
  tab.HighlightMiddle:SetVertexColor(accent[1], accent[2], accent[3], 0.18)

  local text = tab.Text
  local icon = tab.conversationIcon
  local labelOffset = (_PUI_IsTemporaryChatFrame(chatFrame) and icon) and 9 or 0
  -- Reserve half the icon-and-gap width so the whole label stays centered.
  SaveNativeVisual(text, true)
  text:ClearAllPoints()
  text:SetPoint("CENTER", tab, "CENTER", labelOffset, -1)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  if icon then
    SaveNativeVisual(icon, true)
    icon:SetSize(16, 16)
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", text, "LEFT", -2, 0)
  end
  local fontPath, outline = _PUI_GetTypographyFont(_PUI_GetTypographyDB().tab)
  text:SetFont(fontPath, 12, outline)
  text:SetWordWrap(false)
  if _PUI_IsTemporaryChatFrame(chatFrame) and canaccessvalue(chatFrame.chatType) then
    local info = ChatTypeInfo[chatFrame.chatType]
    if info then
      text:SetTextColor(info.r, info.g, info.b, 1)
      tab.glow:SetVertexColor(info.r, info.g, info.b, 1)
    end
  else
    text:SetTextColor(1, 1, 1, 1)
  end
  ChatLinks:AttachChatTabVisuals(chatFrame)
end

local function SkinChatFrame(chatFrame)
  local state = GetChatFrameState(chatFrame)
  local name = chatFrame:GetName()

  if not state.skinned then
    chatFrame:SetClampRectInsets(0, 0, 0, 0)
    chatFrame:SetClampedToScreen(false)
    for _, region in ipairs({ chatFrame:GetRegions() }) do
      if region:IsObjectType("Texture") then SaveNativeVisual(region); region:Hide() end
    end
    local shell = CreateFrame("Frame", nil, chatFrame)
    shell:EnableMouse(false)
    local level = chatFrame:GetFrameLevel()
    if canaccessvalue(level) and type(level) == "number" then shell:SetFrameLevel(math.max(0, level - 1)) end
    shell:SetIgnoreParentAlpha(true)
    shell:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -2, 3)
    shell:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 23, -6)
    state.shell = shell
    state.skinned = true
  end

  for _, suffix in pairs(CHAT_FRAME_TEXTURES) do
    local texture = _G[name .. suffix]
    if texture then SaveNativeVisual(texture); texture:Hide() end
  end
  _ApplyDirectChatShellBackdrop(state.shell, _GetChatWindowStyle())
  state.shell:Show()
  SkinChatEditBox(chatFrame)
  SkinChatTab(chatFrame)

  if not state.wheelHooked then
    state.wheelHooked = true
    chatFrame:HookScript("OnMouseWheel", function(_, delta)
      if ChatLinks._puiRuntimeEnabled ~= true then return end
      local lines = ClampInt(ChatLinks.db.profile.chatTweaks.scrollMessages, 1, 12)
      for _ = 2, lines do
        if delta > 0 then chatFrame:ScrollUp() else chatFrame:ScrollDown() end
      end
    end)
  end
end

HideChatSideButtons = function()
  ChatLinks._puiPendingChatSideButtons = nil
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
      if not CanChangeChatLayout(f) then
        ChatLinks._puiPendingChatSideButtons = true
      else
        SaveNativeVisual(f)
        NativeVisuals[f].opacityReset = true
        f:Hide()
        f:SetAlpha(0)
        f:EnableMouse(false)
      end
    end
  end

  local ttsFrame = _G.TextToSpeechButtonFrame
  if ttsFrame then
    if not CanChangeChatLayout(ttsFrame) then
      ChatLinks._puiPendingChatSideButtons = true
    else
      SaveNativeVisual(ttsFrame)
      NativeVisuals[ttsFrame].opacityReset = true
      ttsFrame:Hide()
      ttsFrame:SetAlpha(0)
      ttsFrame:EnableMouse(false)
    end
  end
end

local function _PUI_ClickBlizzardChatTool(buttonName)
  local button = _G[buttonName]
  if not button then
    Addon:Print("That Blizzard chat tool is not available right now.")
    return
  end

  if not CanChangeChatLayout(button) then
    Addon:Print("That Blizzard chat tool is blocked in combat.")
    return
  end

  button:Click("LeftButton")
end

local function EnsureChatToolsButton(chatFrame)
  local state = GetChatFrameState(chatFrame)
  local button = state.toolsButton
  if button then
    PositionAddonPointFromFrame(button, chatFrame, "TOPRIGHT", -27, -3)
    local panel = button._puiPanel
    if panel then
      local colors = ns.Theme.GetColors()
      _PUI_ApplyTextureBackdrop(panel, colors.background, colors.border, ns.Theme.GetEdgeSize())
    end
    return button
  end

  button = CreateFrame("Button", nil, chatFrame, "UIPanelButtonTemplate")
  button:SetSize(20, 20)
  PositionAddonPointFromFrame(button, chatFrame, "TOPRIGHT", -27, -3)
  button:SetText("...")
  ns.Theme.WidgetSkins.UIButton(button)

  local panel = CreateFrame("Frame", nil, button, "BackdropTemplate")
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
  state.toolsButton = button
  return button
end

local function CreateCopyButton(chatFrame)
  if not chatFrame then
    return nil
  end

  local state = GetChatFrameState(chatFrame)
  if state.copyButton then
    PositionAddonPointFromFrame(state.copyButton, chatFrame, "TOPRIGHT", -4, -4)
    return state.copyButton
  end

  local btn = CreateFrame("Button", nil, chatFrame)
  btn:SetSize(18, 18)
  PositionAddonPointFromFrame(btn, chatFrame, "TOPRIGHT", -4, -4)

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

  state.copyButton = btn
  return btn
end

local function HideChatFrameVisuals(chatFrame)
  local state = ChatFrameState[chatFrame]
  if state then
    for _, key in ipairs({"shell", "copyButton", "toolsButton"}) do
      local visual = state[key]
      if visual then
        visual:Hide()
      end
    end
    if state.toolsButton and state.toolsButton._puiPanel then
      state.toolsButton._puiPanel:Hide()
    end
  end
end

function ChatLinks:RefreshChatFrameVisuals(chatFrame, refreshStyle)
  if self._puiRuntimeEnabled ~= true or not chatFrame then
    return
  end

  local state = ChatFrameState[chatFrame]
  if not _PUI_IsChatFrameOpen(chatFrame) then
    if state then
      if state.open then
        HideChatFrameVisuals(chatFrame)
      end
      state.open = nil
      state.pendingVisualRefresh = nil
      state.pendingVisualStyle = nil
    end
    return
  end

  state = state or GetChatFrameState(chatFrame)
  if state.open and refreshStyle ~= true and not state.pendingVisualRefresh then
    return
  end

  self:ApplyChatWindowFading(chatFrame)
  self:ApplyChatHistoryCapacity(chatFrame)

  if not CanChangeChatLayout(chatFrame) then
    state.open = true
    state.pendingVisualRefresh = true
    state.pendingVisualStyle = refreshStyle == true
    return
  end

  SkinChatFrame(chatFrame)
  _PUI_ApplyTypographyToChatFrame(chatFrame)

  local copyButton = state.copyButton
  local enableCopyFrame = self.db.profile.enableCopyFrame == true
  if enableCopyFrame and not _PUI_IsTemporaryChatFrame(chatFrame) then
    if not copyButton then
      copyButton = CreateCopyButton(chatFrame)
      copyButton:SetAlpha(0.35)
    end
  end
  if copyButton then
    copyButton:SetShown(enableCopyFrame)
  end

  self:AttachChatFocusFading(chatFrame, state)

  state.open = true
  state.pendingVisualRefresh = nil
  state.pendingVisualStyle = nil

  if not state.visibilityHooked then
    state.visibilityHooked = true
    chatFrame:HookScript("OnShow", function()
      if ChatLinks._puiRuntimeEnabled == true and not state.open then
        ChatLinks:RefreshChatFrameVisuals(chatFrame)
      end
    end)
  end
end

function ChatLinks:RefreshChatTabs()
  if self._puiRuntimeEnabled ~= true then
    return
  end
  ForEachBlizzardChatFrame(function(chatFrame)
    local state = ChatFrameState[chatFrame]
    if state and state.skinned and _PUI_IsChatFrameOpen(chatFrame) and CanChangeChatLayout(chatFrame) then
      SkinChatTab(chatFrame)
      self:AttachChatFocusFading(chatFrame, state)
    end
  end)
  self:RefreshChatDockFocusFading()
end

local function ApplyChatDockLayout()
  if not ChatLinks:IsChatLayoutReady() then
    return
  end

  local dock = GeneralDockManager
  local primary = dock.primary
  if not canaccessvalue(primary) or not primary then
    return
  end

  if not CanChangeChatLayout(dock) then
    ChatLinks._puiPendingChatDockLayout = true
    return
  end

  ChatLinks._puiPendingChatDockLayout = nil

  dock:ClearAllPoints()
  dock:SetPoint("BOTTOMLEFT", primary, "TOPLEFT", 0, 3)
  dock:SetPoint("BOTTOMRIGHT", primary, "TOPRIGHT", 0, 3)
  dock:SetHeight(22)
  ChatLinks:AlignChatDockTabs(dock)
end

function ChatLinks:DiscoverChatFrames()
  if not self.db or not self.db.profile or self._puiRuntimeEnabled ~= true then
    return
  end

  ForEachBlizzardChatFrame(function(chatFrame)
    local state = ChatFrameState[chatFrame]
    local open = _PUI_IsChatFrameOpen(chatFrame)

    if open then
      if not state or not state.open then
        self:RefreshChatFrameVisuals(chatFrame)
      end
    elseif state and state.open then
      self:RefreshChatFrameVisuals(chatFrame)
    end
  end)
end

function ChatLinks:RefreshPendingChatVisuals()
  if not self.db or not self.db.profile or self._puiRuntimeEnabled ~= true then
    return
  end

  for chatFrame, state in pairs(ChatFrameState) do
    if state.pendingVisualRefresh then
      self:RefreshChatFrameVisuals(chatFrame, state.pendingVisualStyle == true)
    elseif state.open then
      self:ApplyChatHistoryCapacity(chatFrame)
    end
  end

  if self._puiPendingChatDockLayout then
    ApplyChatDockLayout()
  end

  if self._puiPendingPrimaryChatBind then
    ApplyPrimaryChatLayout()
  end

  if self._puiPendingChatSideButtons then
    HideChatSideButtons()
  end
end

function ChatLinks:RefreshChatFrames()
  if not self.db or not self.db.profile or self._puiRuntimeEnabled ~= true then
    return
  end

  ForEachBlizzardChatFrame(function(chatFrame)
    self:RefreshChatFrameVisuals(chatFrame, true)
  end)

  ApplyChatDockLayout()
  ApplyPrimaryChatLayout()

  local primaryChat = _G.ChatFrame1
  if primaryChat then
    local primaryState = GetChatFrameState(primaryChat)
    local toolsButton = primaryState.toolsButton
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

  if primaryChat and ChatFrameState[primaryChat].skinned then
    self:AttachChatFocusFading(primaryChat, ChatFrameState[primaryChat])
  end

  self:RefreshChatDockFocusFading()
  HideChatSideButtons()
end

function ChatLinks:RefreshTheme()
  if not self.db or not self.db.profile then
    return
  end

  if self._puiRuntimeEnabled ~= true then
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
    self:OnDisable()
    return
  end

  self:OnEnable()
  if CopyFrame then
    ApplyCopyFramePosition(CopyFrame)
    self:ApplyCopyWindowStyle()
  end
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
  self._puiRuntimeEnabled = false

  -- 1) Respect explicit manual disable from options
  if db.manualDisabled then
    db.enabled = false
    self:OnDisable()
    return
  end

  local chattyChoice = cdb.chattynator
  local pratChoice   = cdb.prat

  -- 2) Chattynator or Prat already loaded at enable time
  if chattyLoaded then
    if chattyChoice == "chattynator" then
      db.manualDisabled = true
      db.enabled = false
      self:OnDisable()
      return
    end

    if chattyChoice == "ask" then
      self:OnDisable()
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
      self:OnDisable()
      return
    end

    if pratChoice == "ask" then
      self:OnDisable()
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
          self:OnDisable()
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
          self:OnDisable()
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
    self:OnDisable()
    return
  end

  -- 4) From here on, PleebUI Chat is enabled for this
  --    session and Chattynator is NOT loaded.

  self._puiRuntimeEnabled = true
  self:StartChatTabs()
  self:StartChatFocusFading()
  RegisterPrimaryChatMover()
  self:StartChatVisualLifecycle()
  self:UpdateChatFocusFading(ns.Flags.IsEditing)
  self:ApplyChatFormatting()
  self:UpdateChatFading()
  self:SetUrlFiltersEnabled(self.db.profile.enableUrlCopy == true)
  self:StartChatHistory()

end

function ChatLinks:OnDisable()
  self._puiRuntimeEnabled = false
  self:UnregisterEvent("ADDON_LOADED")
  self.__puiChatConflictAddonHook = nil
  self:StopChatHistory()
  self:StopChatVisualLifecycle()
  self:StopChatTabs()
  self:StopChatFocusFading()
  self:SetUrlFiltersEnabled(false)

  ForEachBlizzardChatFrame(function(chatFrame)
    local state = ChatFrameState[chatFrame]
    if state then
      for _, key in ipairs({"shell", "copyButton", "toolsButton"}) do
        local visual = state[key]
        if visual then
          visual:Hide()
        end
      end

      if state.toolsButton and state.toolsButton._puiPanel then
        state.toolsButton._puiPanel:Hide()
      end
    end

    local editBox = chatFrame.editBox
    if editBox and ChatEditBoxState[editBox] then
      for _, texture in pairs(editBox._puiTextureBackdrop) do texture:Hide() end
    end

    local name = chatFrame.GetName and chatFrame:GetName()
    local tab = name and _G[name .. "Tab"]
    if tab and tab._puiTextureBackdrop then
      for _, texture in pairs(tab._puiTextureBackdrop) do texture:Hide() end
    end
  end)

  RestoreNativeVisuals()
  for _, chatFrameName in ipairs(CHAT_FRAMES) do
    local editBox = _G[chatFrameName .. "EditBox"]
    if editBox and ChatEditBoxState[editBox] then
      for _, suffix in ipairs({"EditBoxLeft", "EditBoxRight", "EditBoxMid"}) do
        local texture = _G[chatFrameName .. suffix]
        if texture then texture:SetAlpha(1) end
      end
      for _, key in ipairs({"focusLeft", "focusRight", "focusMid"}) do
        local texture = editBox[key]
        if texture then texture:SetAlpha(1) end
      end
      ChatEditBoxState[editBox].skinned = nil
    end
    local tab = _G[chatFrameName .. "Tab"]
    if tab and ChatTabState[tab] then ChatTabState[tab].skinned = nil end
  end
  self._puiPendingPrimaryChatBind = nil
  self._puiPendingChatSideButtons = nil
  if CopyFrame then
    CopyFrame:Hide()
  end
  if UrlPopupFrame then
    UrlPopupFrame:Hide()
  end

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
  _PUI_IsChatRuntimeEnabled = P:Def("_PUI_IsChatRuntimeEnabled", _PUI_IsChatRuntimeEnabled)
  _PUI_RefreshChatRuntimeState = P:Def("_PUI_RefreshChatRuntimeState", _PUI_RefreshChatRuntimeState)
  ChatProvider = P:Def("ChatProvider", ChatProvider)
  LinkifyChatURLs = P:Def("LinkifyChatURLs", LinkifyChatURLs)
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
  ChatLinks.ApplyCopyWindowStyle = P:Def("ChatLinks.ApplyCopyWindowStyle", ChatLinks.ApplyCopyWindowStyle)
  SaveCopyFramePosition = P:Def("SaveCopyFramePosition", SaveCopyFramePosition)
  ApplyCopyFramePosition = P:Def("ApplyCopyFramePosition", ApplyCopyFramePosition)
  _RegisterAsSpecialFrame = P:Def("_RegisterAsSpecialFrame", _RegisterAsSpecialFrame)
  EnsureCopyFrame = P:Def("EnsureCopyFrame", EnsureCopyFrame)
  ApplyPrimaryChatHolderLayout = P:Def("ApplyPrimaryChatHolderLayout", ApplyPrimaryChatHolderLayout)
  BindPrimaryChatFrame = P:Def("BindPrimaryChatFrame", BindPrimaryChatFrame)
  ApplyPrimaryChatLayout = P:Def("ApplyPrimaryChatLayout", ApplyPrimaryChatLayout)
  GetPrimaryChatMoverInsets = P:Def("GetPrimaryChatMoverInsets", GetPrimaryChatMoverInsets)
  SavePrimaryChatLayout = P:Def("SavePrimaryChatLayout", SavePrimaryChatLayout)
  StopPrimaryChatResize = P:Def("StopPrimaryChatResize", StopPrimaryChatResize)
  UpdatePrimaryChatResize = P:Def("UpdatePrimaryChatResize", UpdatePrimaryChatResize)
  StartPrimaryChatResize = P:Def("StartPrimaryChatResize", StartPrimaryChatResize)
  EnsurePrimaryChatResizeHandle = P:Def("EnsurePrimaryChatResizeHandle", EnsurePrimaryChatResizeHandle)
  SetPrimaryChatResizeHandleShown = P:Def("SetPrimaryChatResizeHandleShown", SetPrimaryChatResizeHandleShown)
  RegisterPrimaryChatMover = P:Def("RegisterPrimaryChatMover", RegisterPrimaryChatMover)
  ChatLinks.OnEditModeChanged = P:Def("ChatLinks.OnEditModeChanged", ChatLinks.OnEditModeChanged)
  ChatLinks.OpenCopyWindow = P:Def("ChatLinks.OpenCopyWindow", ChatLinks.OpenCopyWindow)
  SkinChatEditBox = P:Def("SkinChatEditBox", SkinChatEditBox)
  SkinChatTab = P:Def("SkinChatTab", SkinChatTab)
  SkinChatFrame = P:Def("SkinChatFrame", SkinChatFrame)
  HideChatSideButtons = P:Def("HideChatSideButtons", HideChatSideButtons)
  _PUI_ClickBlizzardChatTool = P:Def("_PUI_ClickBlizzardChatTool", _PUI_ClickBlizzardChatTool)
  EnsureChatToolsButton = P:Def("EnsureChatToolsButton", EnsureChatToolsButton)
  CreateCopyButton = P:Def("CreateCopyButton", CreateCopyButton)
  ChatLinks.RefreshChatFrameVisuals = P:Def("ChatLinks.RefreshChatFrameVisuals", ChatLinks.RefreshChatFrameVisuals)
  ChatLinks.RefreshChatTabs = P:Def("ChatLinks.RefreshChatTabs", ChatLinks.RefreshChatTabs)
  ApplyChatDockLayout = P:Def("ApplyChatDockLayout", ApplyChatDockLayout)
  ChatLinks.DiscoverChatFrames = P:Def("ChatLinks.DiscoverChatFrames", ChatLinks.DiscoverChatFrames)
  ChatLinks.RefreshPendingChatVisuals = P:Def("ChatLinks.RefreshPendingChatVisuals", ChatLinks.RefreshPendingChatVisuals)
  ChatLinks.RefreshChatFrames = P:Def("ChatLinks.RefreshChatFrames", ChatLinks.RefreshChatFrames)
  ChatLinks.RefreshTheme = P:Def("ChatLinks.RefreshTheme", ChatLinks.RefreshTheme)
  ChatLinks.OnProfileChanged = P:Def("ChatLinks.OnProfileChanged", ChatLinks.OnProfileChanged)
  ChatLinks.OnEnable = P:Def("ChatLinks.OnEnable", ChatLinks.OnEnable)
  ChatLinks.OnDisable = P:Def("ChatLinks.OnDisable", ChatLinks.OnDisable)

