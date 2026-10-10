local _, ns = ...

local AceHooks = {}
ns.AceHooks = AceHooks

local PUI_SELF_OWNED_WIDGET_TYPES = {
  PUI_Button = true,
  PUI_Checkbox = true,
  PUI_Dropdown = true,
  PUI_EditBox = true,
  PUI_Heading = true,
  PUI_Label = true,
  PUI_MultiLineEditBox = true,
  PUI_Slider = true,
}

local PUI_OWNED_WIDGETS = setmetatable({}, { __mode = "k" })

local function HideDisabledTooltip(widget)
  local tooltip = widget.__puiDisabledTooltip
  if tooltip and tooltip:GetOwner() == widget.frame then tooltip:Hide() end
  widget.__puiDisabledTooltip = nil
end

local function ShowDisabledTooltip(widget)
  HideDisabledTooltip(widget)
  widget:Fire("OnEnter")
  local reason = ns.OptionsSchema.GetDisabledReason(widget:GetUserDataTable())
  local tooltip = LibStub("AceConfigDialog-3.0").tooltip
  if not tooltip:IsShown() or tooltip:GetOwner() ~= widget.frame then
    tooltip = GameTooltip
    if not tooltip:IsShown() or tooltip:GetOwner() ~= widget.frame then
      if not reason then return end
      tooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
      local option = widget:GetUserData("option")
      tooltip:SetText(type(option.name) == "string" and option.name or "Unavailable setting")
    end
  end
  if reason and reason ~= "" then
    local colors = ns.Theme.GetColors()
    tooltip:AddLine(reason, colors.text[1], colors.text[2], colors.text[3], true)
  end
  tooltip:Show()
  widget.__puiDisabledTooltip = tooltip
end

local function RefreshDisabledHover(widget)
  local hover = widget.__puiDisabledHover
  if not widget.__puiAceGUIOwnedByPleebUI or not widget.disabled then
    if hover then hover:Hide() end
    return
  end
  if not hover then
    -- A separate hover surface keeps disabled inputs and buttons non-interactive.
    hover = CreateFrame("Frame", nil, widget.frame)
    hover:SetAllPoints(widget.frame)
    hover:EnableMouse(true)
    hover:EnableMouseWheel(false)
    hover:SetScript("OnEnter", function() ShowDisabledTooltip(widget) end)
    hover:SetScript("OnLeave", function()
      HideDisabledTooltip(widget)
      widget:Fire("OnLeave")
    end)
    hover:SetScript("OnHide", function() HideDisabledTooltip(widget) end)
    widget.__puiDisabledHover = hover
  end
  hover:SetFrameLevel(widget.frame:GetFrameLevel() + 20)
  hover:Show()
end

local function InstallDisabledHover(widget)
  if not widget.SetDisabled then return end
  if not widget.__puiDisabledHoverHooked then
    widget.__puiDisabledHoverHooked = true
    hooksecurefunc(widget, "SetDisabled", function(self)
      if self.__puiAceGUIOwnedByPleebUI then
        if self.type == "ColorPicker" then ns.Theme.WidgetSkins.ColorPicker(self) end
        RefreshDisabledHover(self)
      end
    end)
  end
  RefreshDisabledHover(widget)
end

local function _PUI_IsPleebUIAceTooltipOwner(owner)
  if not owner then
    return false
  end

  if owner.__puiAceGUIOwnedByPleebUI == true then
    return true
  end

  local widget = owner.obj
  return widget and widget.__puiAceGUIOwnedByPleebUI == true
end

local function _PUI_RefreshAceTooltipBackground(tooltip)
  ns.Theme.SetAceTooltipSolidBackground(
    tooltip,
    _PUI_IsPleebUIAceTooltipOwner(tooltip:GetOwner())
  )
end

local function _PUI_HideAceTooltipBackground(tooltip)
  ns.Theme.SetAceTooltipSolidBackground(tooltip, false)
end

local function _PUI_InstallAceTooltipHook(tooltip)
  if not tooltip or tooltip.__puiAceTooltipBackgroundHooked == true then
    return
  end

  tooltip.__puiAceTooltipBackgroundHooked = true
  tooltip:HookScript("OnShow", _PUI_RefreshAceTooltipBackground)
  tooltip:HookScript("OnHide", _PUI_HideAceTooltipBackground)
end

local function _PUI_InstallAceGUIHooks()
  local AceGUI = LibStub("AceGUI-3.0")
  _PUI_InstallAceTooltipHook(AceGUI.tooltip)

  local function ClearOwnership(widget)
    if not widget then
      return
    end

    PUI_OWNED_WIDGETS[widget] = nil
    if widget.__puiDisabledHover then widget.__puiDisabledHover:Hide() end
    HideDisabledTooltip(widget)

    widget.__puiAceGUIOwnershipSerial = (widget.__puiAceGUIOwnershipSerial or 0) + 1
    widget.__puiAceGUIOwnedByPleebUI = nil
    widget.__puiCreatedWidgetInitialized = nil
    widget.__puiACDHostContainer = nil

    if widget.frame then
      widget.frame.__puiAceGUIOwnedByPleebUI = nil
      widget.frame.__puiACDHostContainer = nil
    end

    if widget.content then
      widget.content.__puiAceGUIOwnedByPleebUI = nil
      widget.content.__puiACDHostContainer = nil
    end

    ns.Theme.ReleaseCreatedWidget(widget)
    ns.Theme.ReleaseWidgetRowBackground(widget)

    widget.__puiWrapLabel = nil
    widget.__puiWidgetRowIndex = nil
    widget.__puiWidgetRowStamp = nil
    widget.__puiWidgetBoxHeight = nil
    widget.__puiResolvedLSMFontList = nil
    widget.__puiDropdownValueText = nil
    widget.__puiDropdownRefreshStatusbar = nil
    widget.__puiDropdownLayoutStateApplied = nil
    widget.__puiDropdownGeometryApplied = nil
    widget.__puiRegularDropdownGeometryApplied = nil
    widget.__puiLSMDropdownGeometryApplied = nil
    widget.__puiCheckboxControlType = nil
    widget.__puiGroupHeaderOffset = nil
    widget.__puiLastTreeResizeWidth = nil
    widget.__puiLastTreeNativeRows = nil
    widget.__puiLastTreePCMRows = nil
  end

  local function IsPleebUIOwner(owner)
    if not owner then
      return false
    end

    return owner:GetUserData("appName") == "PleebUI"
      or owner.__puiACDHostContainer == true
      or owner.__puiAceGUIOwnedByPleebUI == true
      or owner.frame.__puiACDHostContainer == true
      or owner.frame.__puiAceGUIOwnedByPleebUI == true
      or (owner.content and owner.content.__puiAceGUIOwnedByPleebUI == true)
  end

  local function InitializeCreatedWidget(widget)
    if not widget.__puiCreatedWidgetLease then
      widget.__puiAceGUIOwnershipSerial = (widget.__puiAceGUIOwnershipSerial or 0) + 1
    end

    widget.__puiAceGUIOwnedByPleebUI = true
    widget.frame.__puiAceGUIOwnedByPleebUI = true
    PUI_OWNED_WIDGETS[widget] = true
    InstallDisabledHover(widget)

    if PUI_SELF_OWNED_WIDGET_TYPES[widget.type] then
      widget.__puiCreatedWidgetInitialized = true
      ns.Theme.ApplyCreatedWidgetSizing(widget)
      widget:RefreshTheme()
      ns.Theme.ApplyWidgetRowBackground(widget)
      return
    end

    ns.Theme.BeginCreatedWidgetLease(widget)
    ns.Theme.InitializeCreatedWidget(widget)
    if widget.type == "DropdownGroup" and not widget.__puiGroupSelectionHooked then
      widget.__puiGroupSelectionHooked = true
      local originalOnWidthSet = widget.OnWidthSet
      local originalOnHeightSet = widget.OnHeightSet
      local originalLayoutFinished = widget.LayoutFinished
      local originalSetTitle = widget.SetTitle
      widget.OnWidthSet = function(self, width)
        originalOnWidthSet(self, width)
        local user = self:GetUserDataTable()
        local headerHeight = 26
        if self.__puiAceGUIOwnedByPleebUI == true and user.appName == "PleebUI"
          and user.path and user.path[1] == "CooldownManager" and user.path[4] == "entries"
        then
          self.titletext:SetText("")
          self.dropdown:SetLabel("Spell or item")
          ns.Theme.WidgetSkins.Dropdown(self.dropdown)
          self.dropdown.frame:ClearAllPoints()
          self.dropdown.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
          self:SetDropdownWidth(math.min(420, math.max(1, (width - 26) * 0.65)))
          headerHeight = self.dropdown.frame:GetHeight() + 8
        end
        self.__puiGroupHeaderOffset = headerHeight - 26
        self.border:ClearAllPoints()
        self.border:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -headerHeight)
        self.border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 3)
        self:OnHeightSet(self.frame:GetHeight())
      end
      widget.OnHeightSet = function(self, height)
        originalOnHeightSet(self, height - (self.__puiGroupHeaderOffset or 0))
      end
      widget.LayoutFinished = function(self, width, height)
        originalLayoutFinished(self, width, (height or 0) + (self.__puiGroupHeaderOffset or 0))
      end
      widget.SetTitle = function(self, title)
        originalSetTitle(self, title)
        self:OnWidthSet(self.frame:GetWidth())
      end
      local dropdown = widget.dropdown
      local selectedGroup = dropdown.events.OnValueChanged
      dropdown:SetCallback("OnValueChanged", function(control, event, value)
        local owner = control.parentgroup
        local user = owner:GetUserDataTable()
        if owner.__puiAceGUIOwnedByPleebUI == true
          and user.appName == "PleebUI" and user.path and user.path[1] == "CooldownManager"
          and not ns.Addon:HandleOptionsGroupSelection(owner, value)
        then
          return
        end
        selectedGroup(control, event, value)
      end)
    end
  end

  function AceHooks.TakeOwnership(widget)
    if not widget then
      return false
    end

    InitializeCreatedWidget(widget)
    return true
  end

  local originalRelease = AceGUI.Release
  AceGUI.Release = function(gui, widget)
    local wasQueuedForRelease = widget and widget.isQueuedForRelease

    if widget
      and not widget.isQueuedForRelease
      and (
        widget.__puiAceGUIOwnedByPleebUI == true
        or widget.__puiCreatedWidgetInitialized == true
        or widget.__puiACDHostContainer == true
      )
    then
      ClearOwnership(widget)
    end

    local result = originalRelease(gui, widget)
    if widget and not wasQueuedForRelease then
      widget.parent = nil
    end
    return result
  end

  local function PrepareChildOwnership(parent, child)
    local ownedByPleebUI = IsPleebUIOwner(parent)

    if ownedByPleebUI then
      AceHooks.TakeOwnership(child)
    elseif child.__puiAceGUIOwnedByPleebUI == true
      or child.__puiCreatedWidgetInitialized == true
    then
      ClearOwnership(child)
    end
  end

  local widgetContainerBase = AceGUI.WidgetContainerBase
  local originalAddChild = widgetContainerBase.AddChild
  widgetContainerBase.AddChild = function(self, child, beforeWidget)
    PrepareChildOwnership(self, child)
    return originalAddChild(self, child, beforeWidget)
  end

  local originalAddChildren = widgetContainerBase.AddChildren
  widgetContainerBase.AddChildren = function(self, ...)
    for i = 1, select("#", ...) do
      PrepareChildOwnership(self, select(i, ...))
    end

    return originalAddChildren(self, ...)
  end
end

local function _PUI_InstallAceConfigDialogHooks()
  local AceConfigDialog = LibStub("AceConfigDialog-3.0")
  _PUI_InstallAceTooltipHook(AceConfigDialog.tooltip)

  hooksecurefunc("StaticPopup_Show", function(which, _, _, data)
    local popup = StaticPopup_FindVisible(which, data)
    if popup then
      ns.Addon:Theme_SkinStaticPopup(popup)
    end
  end)

  local originalOpen = AceConfigDialog.Open
  AceConfigDialog.Open = function(dialog, appName, container, ...)
    if appName == "PleebUI" then
      ns.Theme.ResetWidgetRowBackgrounds()
    end

    return originalOpen(dialog, appName, container, ...)
  end
end

function AceHooks.RefreshOwnedWidgets()
  for widget in pairs(PUI_OWNED_WIDGETS) do
    if widget.__puiAceGUIOwnedByPleebUI == true and widget.isQueuedForRelease ~= true then
      ns.Theme.ApplyCreatedWidgetSizing(widget)
      if PUI_SELF_OWNED_WIDGET_TYPES[widget.type] then
        widget:RefreshTheme()
      else
        ns.Theme.ApplyAce3Skin(widget)
        ns.Theme.ApplyCreatedWidgetFonts(widget)
      end

      ns.Theme.ApplyWidgetRowBackground(widget)
    end
  end
end

function AceHooks.Install()
  _PUI_InstallAceGUIHooks()
  _PUI_InstallAceConfigDialogHooks()
end
