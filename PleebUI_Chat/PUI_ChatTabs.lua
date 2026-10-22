local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
local ChatLinks = ns.Registry.ChatLinks
local Tabs = {}
local P = ns.Pleebug:DropIn(Tabs, { name = "Modules.Chat.Tabs" })
local TabOwners = setmetatable({}, { __mode = "k" })
local Enabled = false

local function SetTabTextShown(tab, shown)
  tab.Text:SetShown(shown)
  if tab.conversationIcon then tab.conversationIcon:SetShown(shown) end
end

local function RefreshTabText(tab)
  if not Enabled then return end
  local owner = TabOwners[tab]
  SetTabTextShown(tab, not owner.fadeText or owner.tabHovered or owner.frameHovered)
end

function ChatLinks:AlignChatDockTabs(dock)
  if not Enabled or not canaccessvalue(dock) or dock ~= GeneralDockManager then return end
  if InCombatLockdown() then
    self._puiPendingChatDockLayout = true
    return
  end

  local primary = dock.primary
  if not canaccessvalue(primary) or not primary then return end
  local staticTab = _G[primary:GetName() .. "Tab"]
  local combatLog = _G.ChatFrame2
  if combatLog and canaccessvalue(combatLog.isDocked) and combatLog.isDocked then
    staticTab = _G.ChatFrame2Tab
  end

  local overflow = dock.overflowButton
  overflow:ClearAllPoints()
  overflow:SetPoint("RIGHT", dock, "RIGHT", -4, 0)

  local scrollFrame = dock.scrollFrame
  scrollFrame:ClearAllPoints()
  scrollFrame:SetPoint("RIGHT", overflow, "LEFT", 0, 0)
  scrollFrame:SetPoint("TOPLEFT", staticTab, "TOPRIGHT", 0, 0)
  scrollFrame:SetHeight(22)
  scrollFrame:GetScrollChild():SetHeight(22)
end

function ChatLinks:ApplyChatWindowFading(frame)
  local db = self.db.profile.chatFade
  frame:SetTimeVisible(db.idleDelay)
  frame:SetFading(db.enabled)
end

function ChatLinks:UpdateChatFading()
  if not Enabled then return end
  for _, name in ipairs(CHAT_FRAMES) do
    local frame = _G[name]
    if canaccessvalue(frame) and frame then self:ApplyChatWindowFading(frame) end
  end
end

function ChatLinks:AttachChatTabVisuals(frame)
  local tab = _G[frame:GetName() .. "Tab"]
  local owner = TabOwners[tab]
  if not owner then
    owner = { frame = frame, tabHovered = false, frameHovered = false }
    TabOwners[tab] = owner
    tab:HookScript("OnEnter", function()
      if Enabled then owner.tabHovered = true; RefreshTabText(tab) end
    end)
    tab:HookScript("OnLeave", function()
      if Enabled then owner.tabHovered = false; RefreshTabText(tab) end
    end)
    frame:HookScript("OnEnter", function()
      if Enabled then owner.frameHovered = true; RefreshTabText(tab) end
    end)
    frame:HookScript("OnLeave", function()
      if Enabled then owner.frameHovered = false; RefreshTabText(tab) end
    end)
  end
  local db = self.db.profile
  local docked = frame.isDocked
  owner.fadeText = canaccessvalue(docked) and ((docked and db.chatFade.fadeTabsNoBackdrop and db.chatWindowStyle.bg[4] == 0)
    or (not docked and db.chatFade.fadeUndockedTabs))
  RefreshTabText(tab)
end

function ChatLinks:StartChatTabs()
  Enabled = true
end

function ChatLinks:StopChatTabs()
  Enabled = false
  for tab, owner in pairs(TabOwners) do
    SetTabTextShown(tab, true)
    owner.fadeText, owner.tabHovered, owner.frameHovered = false, false, false
  end
end

RefreshTabText = P:Def("RefreshTabText", RefreshTabText)
