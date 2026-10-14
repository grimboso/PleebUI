local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local Tabs = {}
local P = ns.Pleebug:DropIn(Tabs, { name = "Modules.Chat.Tabs" })
local TabOwners = setmetatable({}, { __mode = "k" })
local TabLabelWidths = setmetatable({}, { __mode = "k" })
local Enabled = false
local DockLayoutReady = false
local DockUpdateHooked = false

local function SetTabTextShown(tab, shown)
  tab.Text:SetShown(shown)
  if tab.conversationIcon then tab.conversationIcon:SetShown(shown) end
end

local function RefreshTabText(tab)
  if not Enabled then return end
  local owner = TabOwners[tab]
  SetTabTextShown(tab, not owner.fadeText or owner.tabHovered or owner.frameHovered)
end

function ChatLinks:AlignChatDockTabs(dock, nativeUpdated)
  if not Enabled or not canaccessvalue(dock) or dock ~= GeneralDockManager then return end
  if InCombatLockdown() then
    self._puiPendingChatDockLayout = true
    return
  end

  local primary = dock.primary
  if not canaccessvalue(primary) or not primary then return end
  if not nativeUpdated then
    DockLayoutReady = true
    FCFDock_UpdateTabs(dock, true)
    return
  end

  local primaryTab = _G[primary:GetName() .. "Tab"]
  local staticTab = primaryTab
  local combatLog = _G.ChatFrame2
  if combatLog and canaccessvalue(combatLog.isDocked) and combatLog.isDocked then
    staticTab = _G.ChatFrame2Tab
  end

  primaryTab:ClearAllPoints()
  primaryTab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
  if staticTab ~= primaryTab then
    staticTab:ClearAllPoints()
    staticTab:SetPoint("BOTTOMLEFT", primaryTab, "BOTTOMRIGHT", 1, 0)
  end

  local overflow = dock.overflowButton
  overflow:ClearAllPoints()
  overflow:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)

  local overflowShown = overflow:IsShown()
  if not canaccessvalue(overflowShown) then return end

  local scrollFrame = dock.scrollFrame
  scrollFrame:ClearAllPoints()
  scrollFrame:SetPoint("TOPLEFT", staticTab, "TOPRIGHT", 1, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)

  local totalWidth, tabCount = 0, 0
  for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
    if canaccessvalue(frame.isStaticDocked) and not frame.isStaticDocked then
      local tab = _G[frame:GetName() .. "Tab"]
      local textWidth = tab.Text:GetStringWidth()
      local width
      if canaccessvalue(textWidth) then
        width = math.max(tab.Left:GetWidth() + tab.Right:GetWidth(), textWidth + 20 + (tab.sizePadding or 0))
      else
        -- Blizzard gives tabs with restricted names a fixed, readable width.
        width = tab:GetWidth()
      end
      if not canaccessvalue(width) then return end
      TabLabelWidths[tab] = width
      totalWidth = totalWidth + width
      tabCount = tabCount + 1
    end
  end
  totalWidth = totalWidth + math.max(0, tabCount - 1)
  local availableWidth = scrollFrame:GetWidth()
  if not canaccessvalue(availableWidth) then return end
  local fitLabels = totalWidth <= availableWidth
  if fitLabels then
    overflow:Hide()
    scrollFrame:SetScript("OnUpdate", nil)
    scrollFrame:SetHorizontalScroll(0)
    -- Native drag insertion still needs every compact tab counted as visible.
    if tabCount > 0 then scrollFrame.dynTabSize = totalWidth / tabCount end
  elseif overflowShown then
    scrollFrame:SetPoint("BOTTOMRIGHT", overflow, "BOTTOMLEFT", -5, 0)
  end
  local scrollChild = scrollFrame:GetScrollChild()
  scrollChild:SetHeight(22)
  local previousTab
  for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
    if canaccessvalue(frame.isStaticDocked) and not frame.isStaticDocked then
      local tab = _G[frame:GetName() .. "Tab"]
      if fitLabels then
        local width = TabLabelWidths[tab]
        tab:SetWidth(width)
        tab.Text:SetWidth(width - 20 - (tab.sizePadding or 0))
      end
      tab:ClearAllPoints()
      if previousTab then
        tab:SetPoint("BOTTOMLEFT", previousTab, "BOTTOMRIGHT", 1, 0)
      else
        tab:SetPoint("BOTTOMLEFT", scrollChild, "BOTTOMLEFT", 0, 0)
      end
      previousTab = tab
    end
  end
  DockLayoutReady = true
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
  if not DockUpdateHooked then
    DockUpdateHooked = true
    hooksecurefunc("FCFDock_UpdateTabs", function(dock)
      if Enabled and DockLayoutReady then
        ChatLinks:AlignChatDockTabs(dock, true)
      end
    end)
  end
end

function ChatLinks:StopChatTabs()
  Enabled = false
  DockLayoutReady = false
  if not InCombatLockdown() then FCFDock_UpdateTabs(GeneralDockManager, true) end
  for tab, owner in pairs(TabOwners) do
    SetTabTextShown(tab, true)
    owner.fadeText, owner.tabHovered, owner.frameHovered = false, false, false
  end
end

RefreshTabText = P:Def("RefreshTabText", RefreshTabText)
