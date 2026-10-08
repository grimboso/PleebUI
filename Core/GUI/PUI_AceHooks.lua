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
