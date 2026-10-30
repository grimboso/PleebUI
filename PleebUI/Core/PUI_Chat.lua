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

  self.db.profile.childAddons.PleebUI_Chat = enabled == true
  self:ApplyChildAddonProfile()
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
        desc = "Enable Chat for this profile and reload the UI. Your settings are kept.",
        order = 2,
        disabled = IsChatAddonChangeBlocked,
        func = function()
          Addon:SetChatAddonEnabled(true)
        end,
      },
    },
  }
end

local BuildDisabledPage = Addon:CreateDisabledChildAddonPage(
  "__puiDisabledChat",
  IsChatAddonChangeBlocked,
  function() Addon:SetChatAddonEnabled(true) end
)

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
      desc = "Disable Chat for this profile and reload the UI. Your settings are kept.",
      disabled = InCombatLockdown,
      func = function() Addon:SetChatAddonEnabled(false) end,
    } },
  }
end
