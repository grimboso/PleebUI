local _, ns = ...

local Addon = ns.Addon

ns.ChatDefaults = {
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
  }

local DisabledChat = {}

local function IsChatAddonChangeBlocked()
  return InCombatLockdown() or not C_AddOns.DoesAddOnExist("PleebUI_Chat")
end

function Addon:SetChatAddonEnabled(enabled)
  if IsChatAddonChangeBlocked() then
    return
  end

  local character = UnitNameUnmodified("player")
  if enabled then
    C_AddOns.EnableAddOn("PleebUI_Chat", character)
  else
    C_AddOns.DisableAddOn("PleebUI_Chat", character)
  end
  ReloadUI()
end

function DisabledChat:GetOptions()
  return {
    type = "group",
    name = "Chat",
    arg = { puiExplicit = true },
    args = {
      disabled = {
        type = "description",
        name = "|cff808080Addon disabled|r",
        order = 1,
      },
      enableAddon = {
        type = "execute",
        name = "Enable addon and reload",
        desc = "Enable Chat for this character and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsChatAddonChangeBlocked,
        func = function()
          Addon:SetChatAddonEnabled(true)
        end,
      },
    },
  }
end

local function RefreshEnableButton(panel)
  panel.enableButton:SetEnabled(not IsChatAddonChangeBlocked())
end

local function BuildDisabledPage(host)
  local panel = host.__puiDisabledChat
  if not panel then
    panel = CreateFrame("Frame", nil, host)
    panel:Hide()
    panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.text.__puiOptionsFontOwned = true
    panel.text:SetPoint("CENTER", panel, "CENTER", 0, 22)
    panel.text:SetText("Addon disabled")
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetText("Enable addon and reload")
    button:SetPoint("TOP", panel.text, "BOTTOM", 0, -16)
    button:SetScript("OnClick", function()
      Addon:SetChatAddonEnabled(true)
    end)
    panel.enableButton = button
    panel:SetScript("OnShow", function(self)
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      RefreshEnableButton(self)
    end)
    panel:SetScript("OnHide", function(self)
      self:UnregisterAllEvents()
    end)
    panel:SetScript("OnEvent", RefreshEnableButton)
    host.__puiDisabledChat = panel
  end

  panel:SetParent(host)
  panel:ClearAllPoints()
  panel:SetAllPoints(host)
  local colors = ns.Theme.GetColors()
  ns.Theme.SetSquareBackdrop(panel, { bg = colors.disabledControl, border = colors.disabledBorder }, ns.Theme.GetEdgeSize())
  ns.Theme.ApplyFont(panel.text, "body", 14)
  local text = colors.disabledText
  panel.text:SetTextColor(text[1], text[2], text[3], text[4])
  panel:SetAlpha(1)
  ns.Theme.WidgetSkins.UIButton(panel.enableButton)
  panel.enableButton:SetSize(
    math.max(250, math.ceil(panel.enableButton:GetFontString():GetUnboundedStringWidth()) + 30),
    ns.Theme.GetOptionsPointerTargetSize(34)
  )
  RefreshEnableButton(panel)
  return panel
end

local record = Addon:RegisterOptionsSection("Chat", function()
  return DisabledChat
end, 60, "Chat")
record.resolveOptionsPath = function()
  return { "Chat" }
end
record.customPage = {
  ownsHeader = true,
  build = BuildDisabledPage,
  refresh = BuildDisabledPage,
}

function Addon:GetChatAddonControl()
  return {
    type = "group", name = function() return "" end, inline = true, order = -10,
    arg = { puiExplicit = true },
    args = { disableAddon = {
      type = "execute", name = "Disable addon and reload", order = 1,
      desc = "Disable Chat for this character and reload the UI. Your settings are kept.",
      disabled = InCombatLockdown,
      func = function() Addon:SetChatAddonEnabled(false) end,
    } },
  }
end
