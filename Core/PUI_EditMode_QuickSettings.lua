local _, ns = ...

local AceGUI = LibStub("AceGUI-3.0")
local UIParent = UIParent
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local math_max = math.max
local math_min = math.min
local type = type

local QuickSettings = {}
ns.EditModeQuickSettings = QuickSettings

local PANEL_WIDTH = 360
local PANEL_PADDING = 14
local HEADER_HEIGHT = 54
local CONTROL_GAP = 2
local FOOTER_HEIGHT = 28
local FOOTER_GAP = 10
local SCROLLBAR_WIDTH = 24
local PANEL_SCREEN_MARGIN = 60
local PANEL_ANCHOR_GAP = 32

local function HideControlTooltip(panel)
  local owner = panel and panel.tooltipOwner
  if owner and GameTooltip:GetOwner() == owner then
    GameTooltip:Hide()
  end
  if panel then
    panel.tooltipOwner = nil
  end
end

local function ReleaseControls(panel)
  HideControlTooltip(panel)

  for index = #panel.controls, 1, -1 do
    AceGUI:Release(panel.controls[index])
    panel.controls[index] = nil
  end
  panel.cursorY = 0
end

local function LockPanelPosition(panel)
  panel:StopMovingOrSizing()

  local panelX, panelY = panel:GetCenter()
  local centerX, centerY = UIParent:GetCenter()
  if not panelX or not panelY or not centerX or not centerY then
    return
  end

  panel:ClearAllPoints()
  panel:SetPoint("CENTER", UIParent, "CENTER", panelX - centerX, panelY - centerY)
  panel.positionLocked = true
end

local function AnchorPanel(panel, anchor)
  if panel.positionLocked == true then
    panel:Show()
    panel:Raise()
    return
  end

  panel:ClearAllPoints()

  local anchorX = anchor and anchor:GetCenter()
  local screenX = UIParent:GetCenter()
  if anchorX and screenX and anchorX < screenX then
    panel:SetPoint("LEFT", anchor, "RIGHT", PANEL_ANCHOR_GAP, 0)
  else
    panel:SetPoint(
      "RIGHT",
      anchor or UIParent,
      anchor and "LEFT" or "RIGHT",
      anchor and -PANEL_ANCHOR_GAP or -30,
      0
    )
  end

  panel:Show()
  panel:Raise()
  LockPanelPosition(panel)
end

local function StylePanel(panel)
  local Theme = ns.Theme
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(panel, {
    bg = colors.background,
    border = colors.border,
  }, math_max(2, Theme.GetEdgeSize()))
  Theme.ApplyFont(panel.title, "header", 14)
  Theme.ApplyFont(panel.description, "tiny", 10)
  panel.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4] or 1)
  panel.description:SetTextColor(colors.text[1], colors.text[2], colors.text[3], (colors.text[4] or 1) * 0.72)
  Theme.WidgetSkins.CloseButton(panel.closeButton)
  Theme.WidgetSkins.UIButton(panel.allSettingsButton)
  if panel.scroll and panel.scroll.ScrollBar then
    Theme.WidgetSkins.Scrollbar(panel.scroll.ScrollBar)
  end
end

function QuickSettings:EnsurePanel()
  if self.panel then
    return self.panel
  end

  local panel = CreateFrame("Frame", "PleebUI_EditModeQuickSettings", UIParent, "BackdropTemplate")
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(1200)
  panel:SetSize(PANEL_WIDTH, 100)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  panel:SetScript("OnDragStop", function(self)
    LockPanelPosition(self)
  end)
  panel:Hide()

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, -12)
  panel.title:SetPoint("RIGHT", panel, "RIGHT", -38, 0)
  panel.title:SetJustifyH("LEFT")

  panel.description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.description:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
  panel.description:SetPoint("RIGHT", panel, "RIGHT", -PANEL_PADDING, 0)
  panel.description:SetJustifyH("LEFT")

  panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  panel.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
  panel.closeButton:SetScript("OnClick", function()
    QuickSettings:Hide()
  end)

  panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, -HEADER_HEIGHT)
  panel.scroll:SetWidth(PANEL_WIDTH - (PANEL_PADDING * 2))
  panel.scroll:SetHeight(1)
  panel.scroll:SetClipsChildren(true)
  panel.scroll:EnableMouseWheel(true)
  panel.scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = self:GetVerticalScrollRange()
    local target = self:GetVerticalScroll() - (delta * 42)
    self:SetVerticalScroll(math_max(0, math_min(maxScroll, target)))
  end)

  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetPoint("TOPLEFT", panel.scroll, "TOPLEFT", 0, 0)
  panel.content:SetWidth(PANEL_WIDTH - (PANEL_PADDING * 2))
  panel.content:SetHeight(1)
  panel.scroll:SetScrollChild(panel.content)
  panel.controls = {}
  panel.cursorY = 0

  panel.allSettingsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  panel.allSettingsButton:SetText("All settings...")
  panel.allSettingsButton:SetHeight(FOOTER_HEIGHT)
  panel.allSettingsButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PANEL_PADDING, PANEL_PADDING)
  panel.allSettingsButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PANEL_PADDING, PANEL_PADDING)
  panel.allSettingsButton:SetScript("OnClick", function()
    local callback = panel.openAllSettings
    QuickSettings:Hide()

    if callback then
      callback()
    end
  end)
  panel.allSettingsButton:Hide()

  StylePanel(panel)
  self.panel = panel
  return panel
end

local function AddControl(panel, control)
  local widgetType
  if control.type == "toggle" then
    widgetType = "PUI_Checkbox"
  elseif control.type == "slider" then
    widgetType = "PUI_Slider"
  elseif control.type == "select" then
    widgetType = "PUI_Dropdown"
  elseif control.type == "font" then
    widgetType = "PUI_Dropdown"
  elseif control.type == "statusbar" then
    widgetType = "LSM30_Statusbar"
  elseif control.type == "color" then
    widgetType = "ColorPicker"
  elseif control.type == "heading" then
    widgetType = "PUI_Heading"
  elseif control.type == "description" then
    widgetType = "PUI_Label"
  elseif control.type == "button" then
    widgetType = "PUI_Button"
  end

  if not widgetType then
    return
  end

  local widget = AceGUI:Create(widgetType)
  widget:SetUserData("puiDensity", "compact")
  ns.AceHooks.TakeOwnership(widget)
  panel.controls[#panel.controls + 1] = widget
  widget:SetWidth(panel.content:GetWidth())
  widget.frame:SetParent(panel.content)
  widget.frame:ClearAllPoints()
  widget.frame:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -panel.cursorY)
  widget.frame:Show()

  if control.type == "heading" then
    widget:SetText(control.label)
  elseif control.type == "description" then
    widget:SetText(control.text or "")
  elseif control.type == "button" then
    widget:SetText(control.label or "Apply")
  elseif control.label then
    widget:SetLabel(control.label)
  end

  if control.type == "toggle" then
    widget:SetValue(control.get() == true)
    widget:SetCallback("OnValueChanged", function(_, _, value)
      control.set(value == true)
    end)
  elseif control.type == "slider" then
    widget:SetCommitOnRelease(control.commitOnRelease == true)
    widget:SetSliderValues(control.min, control.max, control.step or 1)
    local value = control.get()
    widget:SetValue(tonumber(value) or control.min)
    if control.commitOnRelease == true then
      if control.liveSet then
        widget:SetCallback("OnValueChanging", function(_, _, value)
          control.liveSet(value)
        end)
      end
      widget:SetCallback("OnMouseUp", function(_, _, value)
        control.set(value)
      end)
    else
      widget:SetCallback("OnValueChanged", function(_, _, value)
        control.set(value)
      end)
    end
  elseif control.type == "select"
    or control.type == "font"
    or control.type == "statusbar"
  then
    widget:SetList(control.values, control.sorting)
    widget:SetValue(control.get())
    widget:SetCallback("OnValueChanged", function(currentWidget, _, value)
      currentWidget:SetValue(value)
      control.set(value)
    end)
  elseif control.type == "color" then
    local color = control.get()
    widget:SetHasAlpha(control.hasAlpha ~= false)
    widget:SetColor(color[1], color[2], color[3], color[4] or 1)
    widget:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
      control.set(r, g, b, a)
    end)
  elseif control.type == "button" then
    widget:SetCallback("OnClick", function()
      if type(control.action) == "function" then
        control.action()
      end
    end)

    if control.tooltip and control.tooltip ~= "" then
      local tooltipOwner = widget.button or widget.frame

      widget:SetCallback("OnEnter", function()
        panel.tooltipOwner = tooltipOwner
        GameTooltip:SetOwner(tooltipOwner, "ANCHOR_RIGHT")
        GameTooltip:SetText(control.label or "")
        GameTooltip:AddLine(control.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
      end)

      widget:SetCallback("OnLeave", function()
        if GameTooltip:GetOwner() == tooltipOwner then
          GameTooltip:Hide()
        end
        if panel.tooltipOwner == tooltipOwner then
          panel.tooltipOwner = nil
        end
      end)
    end
  end

  if control.disabled then
    widget:SetDisabled(control.disabled() == true)
  end

  local height = widget.frame:GetHeight()
  if not height or height <= 0 then
    height = control.type == "heading" and 24 or 42
  end
  panel.cursorY = panel.cursorY + height + CONTROL_GAP
end

function QuickSettings:Open(anchor, spec)
  if InCombatLockdown() or type(spec) ~= "table" then
    return false
  end

  local optionsFrame = ns.Addon._OptionsWindow
  if optionsFrame and optionsFrame:IsShown() then
    optionsFrame:Hide()
  end

  local panel = self:EnsurePanel()
  local sameSession = panel:IsShown()
    and panel.ownerKey == spec.ownerKey
    and panel.anchor == anchor
  local openAllSettings = spec.openAllSettings

  if not sameSession then
    panel.positionLocked = nil
  end

  if openAllSettings == nil and sameSession then
    openAllSettings = panel.openAllSettings
  end

  ReleaseControls(panel)

  panel.title:SetText(spec.title or "Quick settings")
  panel.description:SetText(spec.description or "Changes apply immediately.")
  panel.openAllSettings = openAllSettings

  for _, control in ipairs(spec.controls or {}) do
    AddControl(panel, control)
  end

  local moverKey = ns.FrameUtil.GetMoverKeyForAnchor(anchor)
  if moverKey then
    AddControl(panel, {
      type = "button",
      label = "Hide mover",
      tooltip = "Hides only this mover for the current Edit Mode session. The frame and its position stay unchanged. Close and reopen /PE to show the mover again.",
      action = function()
        ns.FrameUtil.HideMoverForEditSession(moverKey)
      end,
    })
  end

  local footerHeight = PANEL_PADDING
  if type(panel.openAllSettings) == "function" then
    panel.allSettingsButton:Show()
    footerHeight = FOOTER_GAP + FOOTER_HEIGHT + PANEL_PADDING
  else
    panel.allSettingsButton:Hide()
  end

  local contentHeight = math_max(1, panel.cursorY)
  local desiredHeight = HEADER_HEIGHT + contentHeight + footerHeight
  local screenHeight = UIParent:GetHeight() or desiredHeight
  local maxHeight = math_max(
    HEADER_HEIGHT + footerHeight + 120,
    screenHeight - PANEL_SCREEN_MARGIN
  )
  local panelHeight = math_min(desiredHeight, maxHeight)
  local viewportHeight = math_max(1, panelHeight - HEADER_HEIGHT - footerHeight)

  local hasScroll = contentHeight > viewportHeight
  local contentWidth = PANEL_WIDTH - (PANEL_PADDING * 2) - (hasScroll and SCROLLBAR_WIDTH or 0)

  panel:SetHeight(panelHeight)
  panel.scroll:SetHeight(viewportHeight)
  panel.content:SetWidth(contentWidth)
  panel.content:SetHeight(math_max(contentHeight, viewportHeight))
  for _, widget in ipairs(panel.controls) do
    widget:SetWidth(contentWidth)
  end
  panel.scroll:SetVerticalScroll(0)
  panel.scroll:UpdateScrollChildRect()
  panel.scroll.ScrollBar:SetShown(hasScroll)
  panel.ownerKey = spec.ownerKey
  panel.anchor = anchor
  AnchorPanel(panel, anchor)
  return true
end

function QuickSettings:Refresh(ownerKey, anchor, provider)
  local panel = self.panel
  if not panel or not panel:IsShown() or panel.ownerKey ~= ownerKey then
    return false
  end

  local spec = type(provider) == "function" and provider(anchor) or provider
  return self:Open(anchor, spec)
end

function QuickSettings:Hide()
  if not self.panel then
    return
  end

  self.panel:StopMovingOrSizing()
  ReleaseControls(self.panel)
  self.panel.ownerKey = nil
  self.panel.anchor = nil
  self.panel.openAllSettings = nil
  self.panel.positionLocked = nil
  self.panel.allSettingsButton:Hide()
  self.panel:Hide()
end

function QuickSettings:RefreshTheme()
  if self.panel then
    StylePanel(self.panel)
  end
end

local P = select(1, ns.Pleebug:DropIn(QuickSettings, { name = "Core.EditModeQuickSettings" }))
QuickSettings.EnsurePanel = P:Def("QuickSettings:EnsurePanel", QuickSettings.EnsurePanel)
QuickSettings.Open = P:Def("QuickSettings:Open", QuickSettings.Open)
QuickSettings.Refresh = P:Def("QuickSettings:Refresh", QuickSettings.Refresh)
QuickSettings.Hide = P:Def("QuickSettings:Hide", QuickSettings.Hide)
QuickSettings.RefreshTheme = P:Def("QuickSettings:RefreshTheme", QuickSettings.RefreshTheme)
