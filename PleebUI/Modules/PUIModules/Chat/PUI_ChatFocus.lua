local _, ns = ...
local ChatLinks = ns.Registry.ChatLinks
local FocusFade = {}
local P = ns.Pleebug:DropIn(FocusFade, { name = "Modules.Chat.Focus" })
local Driver = CreateFrame("Frame")
local MessageEvents = CreateFrame("Frame")
local Windows = {}
local Widgets = {}
local Panels = {}
local Animating = {}
local Enabled = false
local Editing = false
local DockPanel
local MessageTimer
local RefreshPanel

local function CancelPanelTimer(panel)
  if panel.timer then panel.timer:Cancel(); panel.timer = nil end
end

local function ApplyPanelAlpha(panel)
  for owner in pairs(panel.windows) do
    for region, opacity in pairs(owner.regions) do region:SetAlpha(panel.alpha * opacity) end
  end
end

local function AnimatePanels(_, elapsed)
  for panel in pairs(Animating) do
    panel.elapsed = math.min(panel.duration, panel.elapsed + elapsed)
    panel.alpha = panel.startAlpha + (panel.targetAlpha - panel.startAlpha) * (panel.elapsed / panel.duration)
    ApplyPanelAlpha(panel)
    if panel.elapsed == panel.duration then Animating[panel] = nil end
  end
  if not next(Animating) then Driver:SetScript("OnUpdate", nil) end
end

local function FadePanel(panel, alpha, duration)
  if panel.targetAlpha == alpha and (not Animating[panel] or panel.duration == duration) then return end
  panel.startAlpha, panel.targetAlpha, panel.duration, panel.elapsed = panel.alpha, alpha, duration, 0
  if duration == 0 or panel.alpha == alpha then
    Animating[panel] = nil
    panel.alpha = alpha
    ApplyPanelAlpha(panel)
    if not next(Animating) then Driver:SetScript("OnUpdate", nil) end
    return
  end
  Animating[panel] = true
  Driver:SetScript("OnUpdate", AnimatePanels)
end

local function PanelHasVisibleWindow(panel)
  for owner in pairs(panel.windows) do
    if owner.visible then return true end
  end
  return false
end

local function PanelHasFocus(panel)
  for owner in pairs(panel.windows) do
    if owner.visible then
      if owner.inputFocused or owner.dragging then return true end
      for _, hovered in pairs(owner.widgets) do
        if hovered then return true end
      end
    end
  end
  return false
end

RefreshPanel = function(panel)
  if not Enabled then return end
  local fade = ChatLinks.db.profile.chatFade
  if not PanelHasVisibleWindow(panel) or Editing or not fade.fadeWindow then
    CancelPanelTimer(panel)
    panel.idle = false
    FadePanel(panel, 1, 0)
  elseif PanelHasFocus(panel) then
    CancelPanelTimer(panel)
    panel.idle = false
    FadePanel(panel, fade.windowFadeInAlpha, fade.windowFadeInDuration)
  elseif panel.idle then
    FadePanel(panel, fade.windowFadeOutAlpha, fade.windowFadeOutDuration)
  else
    FadePanel(panel, fade.windowFadeInAlpha, fade.windowFadeInDuration)
    if not panel.timer then
      panel.timer = C_Timer.NewTimer(fade.windowDelay, function()
        panel.timer = nil
        if Enabled and not Editing and PanelHasVisibleWindow(panel) and not PanelHasFocus(panel) then
          panel.idle = true
          local current = ChatLinks.db.profile.chatFade
          FadePanel(panel, current.windowFadeOutAlpha, current.windowFadeOutDuration)
        end
      end)
    end
  end
end

function ChatLinks:RevealChatForMessage()
  if not Enabled then return end
  -- Native routing stays private. A message wakes the visible presentation panels.
  for panel in pairs(Panels) do
    if PanelHasVisibleWindow(panel) then
      CancelPanelTimer(panel)
      panel.idle = false
      RefreshPanel(panel)
    end
  end
end

MessageEvents:SetScript("OnEvent", function()
  if not MessageTimer then
    MessageTimer = C_Timer.NewTimer(0, function()
      MessageTimer = nil
      ChatLinks:RevealChatForMessage()
    end)
  end
end)

local function CreatePanel()
  local panel = { windows = {}, alpha = 1, targetAlpha = 1, idle = false }
  Panels[panel] = true
  return panel
end

local function WidgetEnter(widget)
  if not Enabled then return end
  local owner = Widgets[widget]
  owner.widgets[widget] = true
  if owner.panel then RefreshPanel(owner.panel) end
end

local function WidgetLeave(widget)
  if not Enabled then return end
  local owner = Widgets[widget]
  owner.widgets[widget] = false
  if owner.dragging == widget then owner.dragging = nil end
  if owner.panel then RefreshPanel(owner.panel) end
end

local function AttachFocusWidget(owner, widget)
  if not widget then return end
  if not Widgets[widget] then
    Widgets[widget] = owner
    widget:HookScript("OnEnter", WidgetEnter)
    widget:HookScript("OnLeave", WidgetLeave)
    widget:HookScript("OnHide", WidgetLeave)
  end
  local hovered = widget:IsMouseMotionFocus()
  if canaccessvalue(hovered) then owner.widgets[widget] = hovered end
end

local function DragStarted(widget)
  if not Enabled then return end
  local owner = Widgets[widget]
  owner.dragging = widget
  if owner.panel then RefreshPanel(owner.panel) end
end

local function DragStopped(widget)
  if not Enabled then return end
  local owner = Widgets[widget]
  if owner.dragging == widget then owner.dragging = nil end
  if owner.panel then RefreshPanel(owner.panel) end
end

local function InputFocusChanged(_, editBox, focused)
  if not Enabled or not canaccessvalue(editBox) then return end
  local owner = Widgets[editBox]
  if not owner then return end
  owner.inputFocused = focused
  if owner.panel then RefreshPanel(owner.panel) end
end

local function InputFocusGained(self, editBox)
  InputFocusChanged(self, editBox, true)
end

local function InputFocusLost(self, editBox)
  InputFocusChanged(self, editBox, false)
end

function ChatLinks:AttachChatFocusFading(frame, state)
  if not Enabled then return end
  local docked = frame.isDocked
  if not canaccessvalue(docked) then return end
  local owner = Windows[frame]
  if not owner then
    owner = { widgets = {}, regions = {}, inputFocused = false, visible = false }
    Windows[frame] = owner
    local hover = CreateFrame("Frame", nil, frame)
    hover:EnableMouse(false)
    hover:EnableMouseMotion(true)
    hover:SetPropagateMouseMotion(true)
    hover:SetPoint("TOPLEFT", state.shell, "TOPLEFT")
    hover:SetPoint("BOTTOMRIGHT", state.shell, "BOTTOMRIGHT")
    owner.hover = hover
    frame:HookScript("OnShow", function()
      if not Enabled then return end
      owner.visible = true
      owner.hover:Show()
      if owner.panel then RefreshPanel(owner.panel) end
    end)
    frame:HookScript("OnHide", function()
      owner.visible, owner.inputFocused, owner.dragging = false, false, nil
      wipe(owner.widgets)
      if Enabled and owner.panel then RefreshPanel(owner.panel) end
    end)
  end
  local panel
  if docked then
    DockPanel = DockPanel or CreatePanel()
    panel = DockPanel
  else
    owner.undockedPanel = owner.undockedPanel or CreatePanel()
    panel = owner.undockedPanel
  end
  local previous = owner.panel
  if previous ~= panel then
    if previous then previous.windows[owner] = nil end
    owner.panel = panel
    panel.windows[owner] = true
    if previous then RefreshPanel(previous) end
  end

  local tab = _G[frame:GetName() .. "Tab"]
  -- Fade rendering children; never set native frame/tab/dock alpha or parents.
  owner.regions[frame.FontStringContainer] = 1
  owner.regions[state.shell] = 1
  owner.regions[tab.Text] = 1
  if tab.conversationIcon then owner.regions[tab.conversationIcon] = 1 end
  for _, region in pairs(tab._puiTextureBackdrop) do owner.regions[region] = 1 end
  owner.regions[tab.ActiveMiddle], owner.regions[tab.HighlightMiddle] = 1, 1
  if state.copyButton then owner.regions[state.copyButton] = 0.35 end
  if state.toolsButton then owner.regions[state.toolsButton] = 1 end
  if not owner.dragHooks then
    owner.dragHooks = true
    tab:HookScript("OnDragStart", DragStarted)
    tab:HookScript("OnDragStop", DragStopped)
  end
  local shown = frame:IsShown()
  if canaccessvalue(shown) then owner.visible = shown end
  local input = frame.editBox
  if input then
    AttachFocusWidget(owner, input)
    local focused = input:HasFocus()
    if canaccessvalue(focused) then owner.inputFocused = focused end
  end
  AttachFocusWidget(owner, frame)
  AttachFocusWidget(owner, tab)
  AttachFocusWidget(owner, state.copyButton)
  AttachFocusWidget(owner, state.toolsButton)
  if state.toolsButton then AttachFocusWidget(owner, state.toolsButton._puiPanel) end
  owner.hover:SetShown(owner.visible)
  AttachFocusWidget(owner, owner.hover)
  ApplyPanelAlpha(panel)
  RefreshPanel(panel)
end

function ChatLinks:RefreshChatDockFocusFading()
  if not Enabled or not DockPanel then return end
  local primary = GeneralDockManager.primary
  if not canaccessvalue(primary) then return end
  local owner = Windows[primary]
  if not owner then return end
  AttachFocusWidget(owner, GeneralDockManager.overflowButton)
  AttachFocusWidget(owner, GeneralDockManager.overflowButton.list)
  local handle = self._primaryChatResizeHandle
  if handle then
    AttachFocusWidget(owner, handle)
    if not owner.resizeHooks then
      owner.resizeHooks = true
      handle:HookScript("OnDragStart", DragStarted)
      handle:HookScript("OnDragStop", DragStopped)
    end
  end
end

function ChatLinks:UpdateChatFocusFading(editing)
  if self._puiRuntimeEnabled ~= true then return end
  if not self.db.profile.chatFade.fadeWindow then self:StopChatFocusFading(); return end
  if not Enabled then
    self:StartChatFocusFading()
    self:RefreshChatFrames()
  end
  Editing = editing == true
  for panel in pairs(Panels) do CancelPanelTimer(panel); RefreshPanel(panel) end
end

function ChatLinks:StartChatFocusFading()
  if not self.db.profile.chatFade.fadeWindow then self:StopChatFocusFading(); return end
  if Enabled then return end
  Enabled = true
  Editing = ns.Flags.IsEditing == true
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", InputFocusGained, FocusFade)
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", InputFocusLost, FocusFade)
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxHide", InputFocusLost, FocusFade)
  for event in pairs(ChatTypeGroupInverted) do
    if event:sub(1, 9) == "CHAT_MSG_" then MessageEvents:RegisterEvent(event) end
  end
end

function ChatLinks:StopChatFocusFading()
  if not Enabled then return end
  Enabled = false
  EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxFocusGained", FocusFade)
  EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxFocusLost", FocusFade)
  EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxHide", FocusFade)
  MessageEvents:UnregisterAllEvents()
  if MessageTimer then MessageTimer:Cancel(); MessageTimer = nil end
  Driver:SetScript("OnUpdate", nil)
  wipe(Animating)
  for panel in pairs(Panels) do
    CancelPanelTimer(panel)
    panel.alpha, panel.targetAlpha, panel.idle = 1, 1, false
    ApplyPanelAlpha(panel)
    wipe(panel.windows)
  end
  for _, owner in pairs(Windows) do
    owner.hover:Hide()
    wipe(owner.widgets)
    owner.inputFocused, owner.dragging, owner.panel = false, nil, nil
  end
end

AnimatePanels = P:Def("AnimatePanels", AnimatePanels)
RefreshPanel = P:Def("RefreshPanel", RefreshPanel)
