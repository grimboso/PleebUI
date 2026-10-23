local _, ns = ...
local PUI_OptionsProfiler = select(1, ns.Pleebug:DropIn({}))

local Addon = ns.Addon
local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins


local function _PUI_NormalizeTreeButtonLabel(label)
  label = tostring(label or "")
  label = label:gsub("|T.-|t%s*", "")
  label = label:gsub("|c%x%x%x%x%x%x%x%xPUI_PCM_TRACKER:[A-Z]+|r%s*", "")
  label = label:gsub("|c%x%x%x%x%x%x%x%x", "")
  label = label:gsub("|r", "")
  label = label:gsub("^%[Cooldown%]%s*", "")
  label = label:gsub("^%[Charge Cooldown%]%s*", "")
  label = label:gsub("^%[Duration%]%s*", "")
  label = label:gsub("^%[Stack%]%s*", "")
  return label:gsub("^%s+", ""):gsub("%s+$", "")
end
_PUI_NormalizeTreeButtonLabel = PUI_OptionsProfiler:Def("_PUI_NormalizeTreeButtonLabel", _PUI_NormalizeTreeButtonLabel)



local function _PUI_TreeGroupUsesCustomCards(widget)
  local user = widget:GetUserDataTable()
  if user.appName == "PleebUI" then
    return true
  end

  local owner = widget.frame
  while owner do
    if owner.__puiOwnedApp == "PleebUI" or owner.__puiCustomOptionsWindow == true or owner.__puiNavShell or owner.__puiContentShell then
      return true
    end
    owner = owner:GetParent()
  end

  return false
end
_PUI_TreeGroupUsesCustomCards = PUI_OptionsProfiler:Def("_PUI_TreeGroupUsesCustomCards", _PUI_TreeGroupUsesCustomCards)


local function _PUI_IsPCMManagerTree(widget)
  local hasOverview = false
  local hasGroups = false
  for index = 1, #(widget.lines or {}) do
    local value = widget.lines[index].value
    if value == "overview" then
      hasOverview = true
    elseif value == "groups" then
      hasGroups = true
    end
  end
  return hasOverview and hasGroups
end
_PUI_IsPCMManagerTree = PUI_OptionsProfiler:Def("_PUI_IsPCMManagerTree", _PUI_IsPCMManagerTree)


local TREE_ROW_HEIGHT = 46
local TREE_EDGE_INSET = 1
local TREE_CHILD_INDENT = 10
local TREE_CHILD_HEIGHT_RATIO = 0.8
local function _PUI_GetTreeScrollbarLane()
  return Theme.GetOptionsPointerTargetSize(20) + 6 + TREE_EDGE_INSET
end
_PUI_GetTreeScrollbarLane = PUI_OptionsProfiler:Def("_PUI_GetTreeScrollbarLane", _PUI_GetTreeScrollbarLane)


local function _PUI_ConfigureTreeExpandTarget(toggle, baseSize)
  local size = Theme.GetOptionsPointerTargetSize(baseSize)
  local expanded = Theme.GetOptionsPointerTargetSize(0) > 0
  local inset = not expanded and baseSize == 12 and -3 or 0
  toggle:SetSize(size, size)
  toggle:SetHitRectInsets(inset, inset, inset, inset)
  toggle.__puiExpandIconSize = expanded and 12 or nil
  for _, texture in ipairs({ toggle:GetNormalTexture(), toggle:GetPushedTexture() }) do
    texture:ClearAllPoints()
    if expanded then
      texture:SetPoint("CENTER", toggle, "CENTER", 0, 0)
      texture:SetSize(12, 12)
    else
      texture:SetAllPoints(toggle)
    end
  end
end
_PUI_ConfigureTreeExpandTarget = PUI_OptionsProfiler:Def("_PUI_ConfigureTreeExpandTarget", _PUI_ConfigureTreeExpandTarget)


local function _PUI_GetTreeRowHeight()
  return math.max(TREE_ROW_HEIGHT, Theme.GetOptionsFontHeight("nav", 12) + 16)
end
_PUI_GetTreeRowHeight = PUI_OptionsProfiler:Def("_PUI_GetTreeRowHeight", _PUI_GetTreeRowHeight)


local function _PUI_GetTreeButtonHeight(entry)
  local height = _PUI_GetTreeRowHeight()
  if (entry.level or 1) > 1 then
    return math.floor(height * TREE_CHILD_HEIGHT_RATIO + 0.5)
  end
  return height
end
_PUI_GetTreeButtonHeight = PUI_OptionsProfiler:Def("_PUI_GetTreeButtonHeight", _PUI_GetTreeButtonHeight)


local function _PUI_GetTreeButtonIndent(button)
  return math.max(0, (button.level or 1) - 1) * TREE_CHILD_INDENT
end
_PUI_GetTreeButtonIndent = PUI_OptionsProfiler:Def("_PUI_GetTreeButtonIndent", _PUI_GetTreeButtonIndent)


local function _PUI_GetTreeVisibleRows(widget)
  local metrics = Theme.GetControlMetrics()
  local gap = metrics.treeButtonGap
  local availableHeight = math.max(1, widget.treeframe:GetHeight() - metrics.treeGroupTopInset * 2)
  return math.max(1, math.floor((availableHeight + gap) / (_PUI_GetTreeRowHeight() + gap)))
end
_PUI_GetTreeVisibleRows = PUI_OptionsProfiler:Def("_PUI_GetTreeVisibleRows", _PUI_GetTreeVisibleRows)




local function _PUI_GetTreePixelGeometry(widget, lineCount)
  local metrics = Theme.GetControlMetrics()
  local rowHeight = _PUI_GetTreeRowHeight()
  local gap = metrics.treeButtonGap
  local topInset = metrics.treeGroupTopInset
  local step = rowHeight + gap
  local viewport = widget.__puiTreeViewport
  local viewportHeight = viewport and viewport:GetHeight() or 0
  if viewportHeight <= 0 then
    viewportHeight = (widget.treeframe:GetHeight() or 0) - topInset * 2
  end
  viewportHeight = math.max(1, viewportHeight)
  local contentHeight = math.max(0, lineCount * step - gap)
  return step, viewportHeight, math.max(0, (contentHeight - viewportHeight) / step), contentHeight
end
_PUI_GetTreePixelGeometry = PUI_OptionsProfiler:Def("_PUI_GetTreePixelGeometry", _PUI_GetTreePixelGeometry)


local function _PUI_PositionScrolledTreeButtons(widget)
  local viewport = widget.__puiTreeViewport
  local first = widget.buttons[1]
  if not viewport or not first or not first:IsShown() then
    return
  end

  local step = _PUI_GetTreePixelGeometry(widget, #widget.lines)
  local offset = ((widget.__puiTreeSmoothScroll or 0) - (widget.__puiTreeNativeScroll or 0)) * step
  first:ClearAllPoints()
  first:SetPoint("TOPLEFT", viewport, "TOPLEFT", _PUI_GetTreeButtonIndent(first), offset)
  first:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", 0, offset)
end
_PUI_PositionScrolledTreeButtons = PUI_OptionsProfiler:Def("_PUI_PositionScrolledTreeButtons", _PUI_PositionScrolledTreeButtons)


local function _PUI_RefreshPixelTree(widget, originalRefreshTree, scrollToSelection, fromOnUpdate)
  local status = widget.status or widget.localstatus
  local nativeRows = math.max(1, math.floor(((widget.treeframe:GetHeight() or 0) - 20) / 18))
  local lineCount = #(widget.lines or {})
  local step, viewportHeight, maxScroll = _PUI_GetTreePixelGeometry(widget, lineCount)
  local scroll = math.max(0, math.min(widget.__puiTreeSmoothScroll or status.scrollvalue or 0, maxScroll))
  local nativeScroll = math.min(math.max(0, math.floor(scroll) - 1), math.max(0, lineCount - nativeRows))
  scrollToSelection = scrollToSelection or status.scrollToSelection

  status.scrollToSelection = nil
  status.scrollvalue = nativeScroll
  widget.__puiTreeSliderUpdating = true
  originalRefreshTree(widget, false, fromOnUpdate)
  widget.__puiTreeSliderUpdating = nil

  lineCount = #(widget.lines or {})
  step, viewportHeight, maxScroll = _PUI_GetTreePixelGeometry(widget, lineCount)
  scroll = math.min(scroll, maxScroll)

  if scrollToSelection and status.selected then
    for index = 1, lineCount do
      if widget.lines[index].uniquevalue == status.selected then
        local top = (index - 1) * step
        local bottom = top + _PUI_GetTreeButtonHeight(widget.lines[index])
        local pixels = scroll * step
        if top < pixels then
          scroll = top / step
        elseif bottom > pixels + viewportHeight then
          scroll = (bottom - viewportHeight) / step
        end
        scroll = math.max(0, math.min(scroll, maxScroll))
        break
      end
    end
  end

  local correctedNativeScroll = math.min(math.max(0, math.floor(scroll) - 1), math.max(0, lineCount - nativeRows))
  if correctedNativeScroll ~= status.scrollvalue then
    status.scrollvalue = correctedNativeScroll
    widget.__puiTreeSliderUpdating = true
    originalRefreshTree(widget, false, fromOnUpdate)
    widget.__puiTreeSliderUpdating = nil
  end

  widget.__puiTreeNativeScroll = correctedNativeScroll
  local firstButton = widget.buttons[1]
  if firstButton and firstButton.treeline and firstButton:IsShown() then
    for index = 1, lineCount do
      if widget.lines[index].uniquevalue == firstButton.treeline.uniquevalue then
        widget.__puiTreeNativeScroll = index - 1
        break
      end
    end
  end

  widget.__puiTreeSmoothScroll = scroll
  widget.__puiTreeRenderedRow = math.floor(scroll)
  status.scrollvalue = math.floor(scroll)

  widget.__puiTreeSliderUpdating = true
  widget:ShowScroll(maxScroll > 0)
  widget.scrollbar:SetMinMaxValues(0, maxScroll)
  widget.scrollbar:SetValue(scroll)
  widget.__puiTreeSliderUpdating = nil
end
_PUI_RefreshPixelTree = PUI_OptionsProfiler:Def("_PUI_RefreshPixelTree", _PUI_RefreshPixelTree)


local function _PUI_SkinGenericTreeButton(button, isSelected)
  local colors = Theme.GetColors()

  button.__puiUseTextureBackdrop = true
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")

  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.82 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.42 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4] * 0.72 }
      or { colors.controlBorder[1], colors.controlBorder[2], colors.controlBorder[3], colors.controlBorder[4] * 0.55 },
  }, Theme.GetEdgeSize())

  if button.__puiSelectedAccent then
    button.__puiSelectedAccent:Hide()
  end

  local text = button.text
  text.__puiOptionsFontOwned = true
  Theme.ApplyFont(text, "label", 11)
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], isSelected and colors.text[4] or colors.text[4] * 0.82)
  text:Show()
end
_PUI_SkinGenericTreeButton = PUI_OptionsProfiler:Def("_PUI_SkinGenericTreeButton", _PUI_SkinGenericTreeButton)


local PCM_TRACKER_TREE_REGIONS = {
  "__puiPCMTrackerSpellIcon",
  "__puiPCMTrackerPreviewBack",
  "__puiPCMTrackerPreviewFill",
  "__puiPCMTrackerPreviewIcon",
  "__puiPCMTrackerSwipe",
  "__puiPCMTrackerDividerOne",
  "__puiPCMTrackerDividerTwo",
  "__puiPCMTrackerTitle",
}

local function _PUI_HidePCMTrackerTreeCard(button)
  for index = 1, #PCM_TRACKER_TREE_REGIONS do
    local region = button[PCM_TRACKER_TREE_REGIONS[index]]
    if region then
      region:Hide()
    end
  end
end
_PUI_HidePCMTrackerTreeCard = PUI_OptionsProfiler:Def("_PUI_HidePCMTrackerTreeCard", _PUI_HidePCMTrackerTreeCard)


local function _PUI_GetPCMTrackerTreeData(button)
  local raw = button.text and button.text:GetText() or ""
  local kind = raw:match("PUI_PCM_TRACKER:([A-Z]+)")
  if not kind then
    return nil
  end

  return {
    kind = kind,
    texture = raw:match("|T([^:|]+):") or "134400",
    label = _PUI_NormalizeTreeButtonLabel(raw),
    unavailable = raw:sub(1, 10) == "|cff808080",
  }
end
_PUI_GetPCMTrackerTreeData = PUI_OptionsProfiler:Def("_PUI_GetPCMTrackerTreeData", _PUI_GetPCMTrackerTreeData)


local function _PUI_SkinPCMTrackerTreeButton(button, isSelected, data)
  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()

  button.__puiUseTextureBackdrop = true
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")
  button:SetHeight(_PUI_GetTreeButtonHeight(button))
  button:SetHitRectInsets(0, 0, 0, 0)

  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.92 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.56 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4] * 0.72 }
      or { colors.controlBorder[1], colors.controlBorder[2], colors.controlBorder[3], colors.controlBorder[4] * 0.55 },
  }, edge)

  if not button.__puiSelectedAccent then
    button.__puiSelectedAccent = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiSelectedAccent)
  end
  button.__puiSelectedAccent:ClearAllPoints()
  button.__puiSelectedAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.__puiSelectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  button.__puiSelectedAccent:SetWidth(3)
  button.__puiSelectedAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
  if isSelected then
    button.__puiSelectedAccent:SetVertexColor(
      colors.accent[1], colors.accent[2], colors.accent[3], 1
    )
    button.__puiSelectedAccent:Show()
  else
    button.__puiSelectedAccent:Hide()
  end

  if not button.__puiPCMTrackerSpellIcon then
    button.__puiPCMTrackerSpellIcon = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerSpellIcon)
  end
  local spellIcon = button.__puiPCMTrackerSpellIcon
  spellIcon:ClearAllPoints()
  spellIcon:SetPoint("LEFT", button, "LEFT", 8, 0)
  spellIcon:SetSize(24, 24)
  spellIcon:SetTexture(data.texture)
  spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  spellIcon:SetDesaturated(data.unavailable)
  spellIcon:SetAlpha(data.unavailable and 0.45 or 1)
  spellIcon:Show()

  if not button.__puiPCMTrackerPreviewBack then
    button.__puiPCMTrackerPreviewBack = button:CreateTexture(nil, "ARTWORK")
    button.__puiPCMTrackerPreviewBack:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewBack)
  end
  if not button.__puiPCMTrackerPreviewFill then
    button.__puiPCMTrackerPreviewFill = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.__puiPCMTrackerPreviewFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewFill)
  end
  if not button.__puiPCMTrackerPreviewIcon then
    button.__puiPCMTrackerPreviewIcon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewIcon)
  end
  if not button.__puiPCMTrackerSwipe then
    button.__puiPCMTrackerSwipe = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerSwipe:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerSwipe)
  end
  if not button.__puiPCMTrackerDividerOne then
    button.__puiPCMTrackerDividerOne = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerDividerOne:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerDividerOne)
  end
  if not button.__puiPCMTrackerDividerTwo then
    button.__puiPCMTrackerDividerTwo = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerDividerTwo:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerDividerTwo)
  end

  local back = button.__puiPCMTrackerPreviewBack
  local fill = button.__puiPCMTrackerPreviewFill
  local previewIcon = button.__puiPCMTrackerPreviewIcon
  local swipe = button.__puiPCMTrackerSwipe
  local dividerOne = button.__puiPCMTrackerDividerOne
  local dividerTwo = button.__puiPCMTrackerDividerTwo

  back:Hide()
  fill:Hide()
  previewIcon:Hide()
  swipe:Hide()
  dividerOne:Hide()
  dividerTwo:Hide()

  if data.kind == "ICON" then
    previewIcon:ClearAllPoints()
    previewIcon:SetPoint("LEFT", spellIcon, "RIGHT", 10, 0)
    previewIcon:SetSize(22, 22)
    previewIcon:SetTexture(data.texture)
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    previewIcon:SetDesaturated(data.unavailable)
    previewIcon:SetAlpha(data.unavailable and 0.45 or 1)
    previewIcon:Show()

    swipe:ClearAllPoints()
    swipe:SetPoint("TOPRIGHT", previewIcon, "TOPRIGHT", 0, 0)
    swipe:SetPoint("BOTTOMRIGHT", previewIcon, "BOTTOMRIGHT", 0, 0)
    swipe:SetWidth(11)
    swipe:SetVertexColor(0, 0, 0, data.unavailable and 0.35 or 0.62)
    swipe:Show()
  else
    back:ClearAllPoints()
    back:SetPoint("LEFT", spellIcon, "RIGHT", 10, 0)
    back:SetSize(42, 10)
    back:SetVertexColor(
      colors.background[1], colors.background[2], colors.background[3],
      data.unavailable and 0.35 or 0.9
    )
    back:Show()

    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", back, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(data.kind == "STACK" and 26 or 20)
    fill:SetVertexColor(
      colors.accent[1], colors.accent[2], colors.accent[3],
      data.unavailable and 0.35 or 0.9
    )
    fill:Show()

    dividerOne:ClearAllPoints()
    dividerOne:SetPoint("TOP", back, "TOP", 0, -1)
    dividerOne:SetPoint("BOTTOM", back, "BOTTOM", 0, 1)
    dividerOne:SetWidth(1)
    dividerOne:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.75)
    dividerOne:Show()

    if data.kind == "STACK" then
      dividerOne:ClearAllPoints()
      dividerOne:SetPoint("TOP", back, "TOP", -7, -1)
      dividerOne:SetPoint("BOTTOM", back, "BOTTOM", -7, 1)

      dividerTwo:ClearAllPoints()
      dividerTwo:SetPoint("TOP", back, "TOP", 7, -1)
      dividerTwo:SetPoint("BOTTOM", back, "BOTTOM", 7, 1)
      dividerTwo:SetWidth(1)
      dividerTwo:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.75)
      dividerTwo:Show()
    end
  end

  if not button.__puiPCMTrackerTitle then
    button.__puiPCMTrackerTitle = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.__puiPCMTrackerTitle.__puiOptionsFontOwned = true
    button.__puiPCMTrackerTitle:SetJustifyH("LEFT")
    button.__puiPCMTrackerTitle:SetJustifyV("MIDDLE")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerTitle)
  end
  local title = button.__puiPCMTrackerTitle
  local titleFontSize = (button.level or 1) > 1 and 9 or 11
  Theme.ApplyFont(title, "nav", titleFontSize)
  title:ClearAllPoints()
  if data.kind == "ICON" then
    title:SetPoint("LEFT", previewIcon, "RIGHT", 10, 0)
  else
    title:SetPoint("LEFT", back, "RIGHT", 10, 0)
  end
  title:SetPoint("RIGHT", button.toggle, "LEFT", -8, 0)
  title:SetHeight(Theme.GetOptionsFontHeight("nav", titleFontSize))
  title:SetText(data.label)
  if data.unavailable then
    title:SetTextColor(
      colors.text[1], colors.text[2], colors.text[3], colors.text[4] * 0.45
    )
  else
    title:SetTextColor(
      colors.text[1], colors.text[2], colors.text[3],
      isSelected and colors.text[4] or colors.text[4] * 0.86
    )
  end
  title:Show()

  button.text:Hide()
  button.toggle:ClearAllPoints()
  button.toggle:SetPoint("RIGHT", button, "RIGHT", -8, 0)
end
_PUI_SkinPCMTrackerTreeButton = PUI_OptionsProfiler:Def("_PUI_SkinPCMTrackerTreeButton", _PUI_SkinPCMTrackerTreeButton)


function WidgetSkins.TreeButton(button, isSelected)
  ns.OptionsMotion.StyleTreeHover(button)
  _PUI_ConfigureTreeExpandTarget(button.toggle, button.__puiCompactPCMTree == true and 26 or 12)
  local trackerData = _PUI_GetPCMTrackerTreeData(button)
  if button.__puiUseTreeCards == true and trackerData then
    button.__puiTreeCardLayoutKey = nil
    return _PUI_SkinPCMTrackerTreeButton(button, isSelected, trackerData)
  end

  if button.__puiCompactPCMTree == true then
    button.__puiTreeCardLayoutKey = nil
    _PUI_HidePCMTrackerTreeCard(button)
    button.text:Show()
    _PUI_SkinGenericTreeButton(button, isSelected)
    button:SetHeight(_PUI_GetTreeButtonHeight(button))

    local child = (button.level or 1) > 1
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", button, "LEFT", 12, 0)
    button.text:SetPoint("RIGHT", button.toggle, "LEFT", -8, 0)
    button.text:SetHeight(math.max(20, Theme.GetOptionsFontHeight("nav", child and 10 or nil)))
    Theme.ApplyFont(button.text, "nav", child and 10 or nil)

    local toggle = button.toggle
    toggle:ClearAllPoints()
    toggle:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    toggle:SetHighlightTexture("")

    Theme.SetSquareBackdrop(toggle, {
      bg = { 0, 0, 0, 0 },
      border = { 0, 0, 0, 0 },
    }, 0)

    return
  end

  _PUI_HidePCMTrackerTreeCard(button)
  button.text:Show()

  if button.__puiUseTreeCards ~= true then
    button.__puiTreeCardLayoutKey = nil
    return _PUI_SkinGenericTreeButton(button, isSelected)
  end

  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()

  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")

  local isChild = (button.level or 1) > 1
  local labelFontSize = isChild and 10 or 12
  local rowHeight = _PUI_GetTreeButtonHeight(button)
  local currentHeight = math.floor((tonumber(button:GetHeight()) or 0) + 0.5)
  if currentHeight ~= rowHeight then
    button:SetHeight(rowHeight)
  end

  if button.__puiTreeCardHitRectSet ~= true then
    button.__puiTreeCardHitRectSet = true
    button:SetHitRectInsets(0, 0, 0, 0)
  end

  local buttonWidth = math.floor((tonumber(button:GetWidth()) or 0) + 0.5)
  local layoutKey = table.concat({
    tostring(buttonWidth),
    tostring(rowHeight),
    tostring(labelFontSize),
    tostring(button.toggle ~= nil),
  }, "\030")

  local layoutChanged = button.__puiTreeCardLayoutKey ~= layoutKey

  button.__puiUseTextureBackdrop = true
  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.92 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.56 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4] * 0.72 }
      or { colors.controlBorder[1], colors.controlBorder[2], colors.controlBorder[3], colors.controlBorder[4] * 0.55 },
  }, edge)

  if not button.__puiSelectedAccent then
    button.__puiSelectedAccent = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiSelectedAccent)
    layoutChanged = true
  end

  if layoutChanged then
    button.__puiSelectedAccent:ClearAllPoints()
    button.__puiSelectedAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.__puiSelectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.__puiSelectedAccent:SetWidth(3)
    button.__puiSelectedAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
  end

  if isSelected then
    local accent = colors.accent
    button.__puiSelectedAccent:SetVertexColor(accent[1], accent[2], accent[3], 1)
    button.__puiSelectedAccent:Show()
  else
    button.__puiSelectedAccent:Hide()
  end

  if layoutChanged then
    button.toggle:ClearAllPoints()
    button.toggle:SetPoint("RIGHT", button, "RIGHT", -10, 0)
  end

  local text = button.text
  text.__puiOptionsFontOwned = true

  Theme.ApplyFont(text, "nav", labelFontSize)

  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], isSelected and colors.text[4] or colors.text[4] * 0.86)

  -- The native tree refresh resets these anchors even when card dimensions stay unchanged.
  text:ClearAllPoints()
  text:SetPoint("LEFT", button, "LEFT", 12, 0)
  text:SetPoint("RIGHT", button.toggle, "LEFT", -8, 0)
  text:SetHeight(Theme.GetOptionsFontHeight("nav", labelFontSize))

  text:SetJustifyH("LEFT")
  button.__puiTreeCardLayoutKey = layoutKey
end
WidgetSkins.TreeButton = PUI_OptionsProfiler:Def("WidgetSkins.TreeButton", WidgetSkins.TreeButton)


function WidgetSkins.InlineGroup(widget)
  local colors = Theme.GetColors()
  local metrics = Theme.GetControlMetrics()
  local edge = math.max(Theme.GetEdgeSize(), 2)
  local frame = widget.frame
  local outer = widget.content:GetParent()
  local title = widget.titletext
  local padX = metrics.inlineGroupPaddingX
  local padY = metrics.inlineGroupPaddingY
  local hasTitle = title:GetText() ~= ""
  title.__puiOptionsFontOwned = true
  Theme.ApplyFont(title, "header")
  title:ClearAllPoints()
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", padX, 0)
  title:SetWordWrap(false)
  title:SetWidth(math.max(1, math.ceil(title:GetUnboundedStringWidth()) + 4))
  local titleHeight = math.max(18, Theme.GetOptionsFontHeight("header"), math.ceil(title:GetStringHeight() or 0) + 2)
  local contentTopInset = hasTitle and math.max(padY + 4, titleHeight - 17 + padY) or padY
  widget.__puiInlineGroupExtraHeight = math.max(0, 17 + contentTopInset + padY - 3 - 40)

  if not widget.__puiInlineGroupLayoutHooked then
    widget.__puiInlineGroupLayoutHooked = true
    local originalLayoutFinished = widget.LayoutFinished
    local originalSetTitle = widget.SetTitle
    widget.LayoutFinished = PUI_OptionsProfiler:DefCallback("WidgetSkins.InlineGroup > widget.LayoutFinished", function(self, width, height)
      local extraHeight = self.__puiAceGUIOwnedByPleebUI == true and self.__puiInlineGroupExtraHeight or 0
      originalLayoutFinished(self, width, (height or 0) + extraHeight)
    end)
    widget.SetTitle = PUI_OptionsProfiler:DefCallback("WidgetSkins.InlineGroup > widget.SetTitle", function(self, text)
      originalSetTitle(self, text)
      if self.__puiAceGUIOwnedByPleebUI == true then
        WidgetSkins.InlineGroup(self)
      end
    end)
  end

  outer:SetBackdrop(nil)
  outer:SetBackdropColor(0, 0, 0, 0)
  outer:SetBackdropBorderColor(0, 0, 0, 0)

  local bg = Theme.EnsureBackdropFrame(outer)
  Theme.SetSquareBackdrop(outer, {
    bg = { 0, 0, 0, 0 },
    border = { 0, 0, 0, 0 },
  }, edge)

  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  bg:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", 0, 0)
  bg:SetFrameLevel(math.max(outer:GetFrameLevel() - 1, 0))

  local accent = outer.__puiInlineAccent
  if not accent then
    accent = outer:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(accent)
    outer.__puiInlineAccent = accent
  end

  accent:SetHeight(2)
  accent:SetTexture("Interface\\Buttons\\WHITE8x8")
  accent:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.35)
  accent:Show()

  if outer.__puiInlineDivider then
    outer.__puiInlineDivider:Hide()
  end

  widget.content:ClearAllPoints()
  widget.content:SetPoint("TOPLEFT", outer, "TOPLEFT", padX, -contentTopInset)
  widget.content:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -padX, -padY)

  title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  title:SetJustifyH("LEFT")
  title:SetJustifyV("MIDDLE")
  title:SetHeight(titleHeight)
  title:SetShown(hasTitle)

  accent:ClearAllPoints()
  if hasTitle then
    accent:SetPoint("LEFT", title, "RIGHT", 8, 0)
  else
    accent:SetPoint("LEFT", frame, "TOPLEFT", 0, -titleHeight / 2)
  end
  accent:SetPoint("RIGHT", frame, "TOPRIGHT", 0, -titleHeight / 2)
end
WidgetSkins.InlineGroup = PUI_OptionsProfiler:Def("WidgetSkins.InlineGroup", WidgetSkins.InlineGroup)


local function _PUI_StyleTreeButtons(widget)
  local metrics = Theme.GetControlMetrics()
  local pcmManagerTree = _PUI_IsPCMManagerTree(widget)
  local buttonGap = metrics.treeButtonGap
  local rowStep = _PUI_GetTreeRowHeight() + buttonGap
  local topInset = metrics.treeGroupTopInset
  local useCustomCards = _PUI_TreeGroupUsesCustomCards(widget)
  local buttons = widget.buttons
  local prev
  local smoothTree = widget.__puiTreePixelScroll == true
  local buttonParent = smoothTree and widget.__puiTreeViewport or widget.treeframe
  local treeWidth = math.floor((tonumber(widget.treeframe:GetWidth()) or 0) + 0.5)
  local rightInset = _PUI_GetTreeScrollbarLane()
  local treeLayoutKey = table.concat({
    tostring(useCustomCards == true),
    tostring(pcmManagerTree == true),
    tostring(rightInset),
    tostring(buttonGap),
    tostring(_PUI_GetTreeRowHeight()),
    tostring(topInset),
    tostring(treeWidth),
    tostring(#buttons),
  }, "\030")

  for i = 1, #buttons do
    local button = buttons[i]

    Theme.CaptureCreatedWidgetFrameTree(widget, button)

    if button:GetParent() ~= buttonParent then
      button:SetParent(buttonParent)
      button.__puiTreeButtonLayoutKey = nil
    end

    if button:IsShown() and (useCustomCards or pcmManagerTree) then
      local indent = _PUI_GetTreeButtonIndent(button)
      local previousIndent = prev and _PUI_GetTreeButtonIndent(prev) or 0
      local buttonLayoutKey = treeLayoutKey .. "\030" .. tostring(i) .. "\030" .. tostring(button.level or 1) .. "\030" .. tostring(prev or "root")
      if smoothTree or button.__puiTreeButtonLayoutKey ~= buttonLayoutKey then
        button.__puiTreeButtonLayoutKey = buttonLayoutKey
        button:ClearAllPoints()

        if prev and smoothTree then
          button:SetPoint("TOPLEFT", prev, "TOPLEFT", indent - previousIndent, -rowStep)
          button:SetPoint("TOPRIGHT", prev, "TOPRIGHT", 0, -rowStep)
        elseif prev then
          button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", indent - previousIndent, -buttonGap)
          button:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -buttonGap)
        elseif smoothTree then
          button:SetPoint("TOPLEFT", buttonParent, "TOPLEFT", indent, 0)
          button:SetPoint("TOPRIGHT", buttonParent, "TOPRIGHT", 0, 0)
        else
          button:SetPoint("TOPLEFT", widget.treeframe, "TOPLEFT", TREE_EDGE_INSET + indent, -topInset)
          button:SetPoint("TOPRIGHT", widget.treeframe, "TOPRIGHT", -rightInset, -topInset)
        end
      end

      prev = button
    else
      button.__puiTreeButtonLayoutKey = nil
    end

    button.__puiUseTreeCards = useCustomCards
    button.__puiCompactPCMTree = pcmManagerTree
    WidgetSkins.TreeButton(button, button.selected == true)

    local groups = (button.obj.status or button.obj.localstatus).groups
    Theme.ApplyExpandCollapseButton(button.toggle, groups[button.uniquevalue] == true)
  end

  if smoothTree then
    _PUI_PositionScrolledTreeButtons(widget)
  end
end
_PUI_StyleTreeButtons = PUI_OptionsProfiler:Def("_PUI_StyleTreeButtons", _PUI_StyleTreeButtons)


local function _PUI_RefreshTreeSelection(widget)
  local previousValue = widget.__puiPreviousTreeSelection
  local selectedValue = widget.__puiNextTreeSelection
  widget.__puiTreeSelectionOnlyRefresh = nil
  widget.__puiPreviousTreeSelection = nil
  widget.__puiNextTreeSelection = nil

  for index = 1, #(widget.buttons or {}) do
    local button = widget.buttons[index]
    if button.uniquevalue == previousValue or button.uniquevalue == selectedValue then
      local isSelected = button.uniquevalue == selectedValue
      button.selected = isSelected
      if isSelected then
        button:LockHighlight()
      else
        button:UnlockHighlight()
      end
      WidgetSkins.TreeButton(button, isSelected)
    end
  end
end
_PUI_RefreshTreeSelection = PUI_OptionsProfiler:Def("_PUI_RefreshTreeSelection", _PUI_RefreshTreeSelection)


local function _PUI_HandleTreeGroupClick(widget, _, uniquevalue, wasSelected)
  widget.__puiTreeSelectionOnlyRefresh = nil
  widget.__puiPreviousTreeSelection = nil
  widget.__puiNextTreeSelection = nil

  if not wasSelected then
    local status = widget.status or widget.localstatus
    local previousValue = status and status.selected or nil
    local applied, optionsModelChanged = Addon:HandleOptionsGroupSelection(widget, uniquevalue)
    if applied and not optionsModelChanged then
      widget.__puiTreeSelectionOnlyRefresh = true
      widget.__puiPreviousTreeSelection = previousValue
      widget.__puiNextTreeSelection = uniquevalue
    end
  end
end
_PUI_HandleTreeGroupClick = PUI_OptionsProfiler:Def("_PUI_HandleTreeGroupClick", _PUI_HandleTreeGroupClick)


function WidgetSkins.TreeGroup(widget)
  if widget.__puiAceGUIOwnedByPleebUI ~= true then
    return
  end

  widget:SetCallback("OnClick", _PUI_HandleTreeGroupClick)

  local pcmManagerTree = _PUI_IsPCMManagerTree(widget)
  widget.__puiPCMManagerTree = pcmManagerTree
  local user = widget:GetUserDataTable()
  widget.__puiTreePixelScroll = user.appName == "PleebUI"
  widget.__puiBlizzardTree = widget.__puiTreePixelScroll
    and user.path and user.path[1] == "BlizzardWindows"

  if widget.__puiTreePixelScroll then
    if widget.__puiTreeSmoothScroll == nil then
      widget.scrollbar:SetValueStep(0.01)
    end
    local step = _PUI_GetTreePixelGeometry(widget, #(widget.lines or {}))
    widget.scrollbar.scrollStep = 42 / step
  end

  if widget.__puiTreePixelScroll and not widget.__puiTreeSmoothInputHooked then
    widget.__puiTreeSmoothInputHooked = true
    local originalSliderScript = widget.scrollbar:GetScript("OnValueChanged")
    widget.scrollbar:SetScript("OnValueChanged", PUI_OptionsProfiler:DefCallback("WidgetSkins.TreeGroup > widget.scrollbar.SetScript OnValueChanged", function(slider, value)
      if not widget.__puiTreePixelScroll or widget.__puiAceGUIOwnedByPleebUI ~= true then
        return originalSliderScript(slider, value)
      end
      if widget.__puiTreeSliderUpdating then
        return
      end

      widget.__puiTreeSmoothScroll = value
      if math.floor(value) ~= widget.__puiTreeRenderedRow then
        widget:RefreshTree()
      else
        _PUI_PositionScrolledTreeButtons(widget)
      end
    end))

    local treeframe = widget.treeframe
    local originalWheelScript = treeframe:GetScript("OnMouseWheel")
    treeframe:SetScript("OnMouseWheel", PUI_OptionsProfiler:DefCallback("WidgetSkins.TreeGroup > treeframe.SetScript OnMouseWheel", function(frame, delta)
      if not widget.__puiTreePixelScroll or widget.__puiAceGUIOwnedByPleebUI ~= true then
        return originalWheelScript(frame, delta)
      end
      if widget.showscroll then
        local step = _PUI_GetTreePixelGeometry(widget, #widget.lines)
        widget.scrollbar:SetValue(widget.scrollbar:GetValue() - delta * 42 / step)
      end
    end))
  end

  if not widget.__puiTreeShowScrollHooked then
    widget.__puiTreeShowScrollHooked = true
    local originalShowScroll = widget.ShowScroll
    widget.ShowScroll = PUI_OptionsProfiler:DefCallback("WidgetSkins.TreeGroup > widget.ShowScroll", function(self, show)
      if self.__puiAceGUIOwnedByPleebUI == true and self.__puiTreePixelScroll then
        self.showscroll = show
        self.scrollbar:SetShown(show)
        return
      end

      originalShowScroll(self, show)

      if self.__puiAceGUIOwnedByPleebUI ~= true then
        return
      end

      local firstButton = self.buttons and self.buttons[1]
      if not firstButton then
        return
      end

      local topInset = Theme.GetControlMetrics().treeGroupTopInset
      local rightInset = _PUI_GetTreeScrollbarLane()
      firstButton:ClearAllPoints()
      firstButton:SetPoint("TOPLEFT", self.treeframe, "TOPLEFT", TREE_EDGE_INSET, -topInset)
      firstButton:SetPoint("TOPRIGHT", self.treeframe, "TOPRIGHT", -rightInset, -topInset)
    end)
  end

  if not widget.__puiTreeRefreshHooked then
    widget.__puiTreeRefreshHooked = true
    local originalRefreshTree = widget.RefreshTree
    widget.RefreshTree = PUI_OptionsProfiler:DefCallback("WidgetSkins.TreeGroup > widget.RefreshTree", function(self, ...)
      if self.__puiTreeSelectionOnlyRefresh == true then
        _PUI_RefreshTreeSelection(self)
        return
      end

      if self.__puiTreePixelScroll then
        _PUI_RefreshPixelTree(self, originalRefreshTree, ...)
      else
        originalRefreshTree(self, ...)
      end

      if self.__puiAceGUIOwnedByPleebUI == true then
        WidgetSkins.TreeGroup(self)
      end
    end)
  end

  local treeframe = widget.treeframe
  if not widget.__puiTreeResizeHooked then
    widget.__puiTreeResizeHooked = true
    treeframe:SetScript("OnSizeChanged", PUI_OptionsProfiler:DefCallback("WidgetSkins.TreeGroup > treeframe.SetScript OnSizeChanged", function(_, width, height)
      local user = widget:GetUserDataTable()
      if user.appName ~= "PleebUI" or not user.path or user.path[1] ~= "CooldownManager" then
        widget:RefreshTree()
        return
      end

      local roundedWidth = math.floor(width + 0.5)
      local nativeRows = math.max(0, math.floor((height - 20) / 18))
      local pcmRows = widget.__puiPCMManagerTree == true
        and _PUI_GetTreeVisibleRows(widget) or nil

      if widget.__puiLastTreeResizeWidth == roundedWidth
        and widget.__puiLastTreeNativeRows == nativeRows
        and widget.__puiLastTreePCMRows == pcmRows
      then
        return
      end

      widget.__puiLastTreeResizeWidth = roundedWidth
      widget.__puiLastTreeNativeRows = nativeRows
      widget.__puiLastTreePCMRows = pcmRows
      widget:RefreshTree()
    end))
  end

  local border = widget.border
  local metrics = Theme.GetControlMetrics()
  local status = widget.status or widget.localstatus
  local treeWidth = status.treewidth or metrics.treeGroupWidth
  if treeWidth == 175 or treeWidth == 190 then
    treeWidth = metrics.treeGroupWidth
  end
  if pcmManagerTree then
    treeWidth = math.max(treeWidth, math.floor(metrics.treeGroupWidth * 1.3 + 0.5))
  end
  if treeWidth ~= status.treewidth then
    widget:SetTreeWidth(treeWidth, status.treesizable)
  end

  border:SetBackdrop(nil)
  border:SetBackdropColor(0, 0, 0, 0)
  border:SetBackdropBorderColor(0, 0, 0, 0)

  treeframe:SetWidth(treeWidth)
  treeframe:SetBackdrop(nil)
  treeframe:SetBackdropColor(0, 0, 0, 0)
  treeframe:SetBackdropBorderColor(0, 0, 0, 0)

  if widget.__puiTreePixelScroll then
    local viewport = widget.__puiTreeViewport
    if not viewport then
      viewport = CreateFrame("Frame", nil, treeframe)
      viewport:SetClipsChildren(true)
      viewport:EnableMouse(false)
      Theme.MarkCreatedWidgetChrome(viewport)
      widget.__puiTreeViewport = viewport
    end
    local inset = metrics.treeGroupTopInset
    local rightInset = _PUI_GetTreeScrollbarLane()
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", treeframe, "TOPLEFT", 8, -inset)
    viewport:SetPoint("BOTTOMRIGHT", treeframe, "BOTTOMRIGHT", -(rightInset + 6), inset)
    viewport:Show()
  end

  if not treeframe.__puiTreeNativeTexturesStripped then
    treeframe.__puiTreeNativeTexturesStripped = true
    for i = 1, treeframe:GetNumRegions() do
      local region = select(i, treeframe:GetRegions())
      if region:GetObjectType() == "Texture" then
        region:SetTexture(nil)
        region:SetAlpha(0)
        region:Hide()
      end
    end
  end

  local colors = Theme.GetColors()
  treeframe.__puiUseTextureBackdrop = true
  Theme.SetSquareBackdrop(treeframe, {
    bg = widget.__puiBlizzardTree
      and { colors.background[1], colors.background[2], colors.background[3], 1 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.45 },
    border = widget.__puiBlizzardTree and colors.controlBorder or colors.border,
  }, Theme.GetEdgeSize())

  widget.scrollbar:ClearAllPoints()
  local scrollbarInset = _PUI_GetTreeScrollbarLane()
  widget.scrollbar:SetPoint("TOPRIGHT", treeframe, "TOPRIGHT", -6, -scrollbarInset)
  widget.scrollbar:SetPoint("BOTTOMRIGHT", treeframe, "BOTTOMRIGHT", -6, scrollbarInset)
  if widget.__puiTreePixelScroll then
    local _, visibleHeight, _, contentHeight = _PUI_GetTreePixelGeometry(widget, #(widget.lines or {}))
    WidgetSkins.Scrollbar(widget.scrollbar, visibleHeight, contentHeight, 72)
  else
    WidgetSkins.Scrollbar(widget.scrollbar)
  end
  widget.__puiTreeChromeHooked = true
  _PUI_StyleTreeButtons(widget)

  local rowHeight = _PUI_GetTreeRowHeight()
  if _PUI_TreeGroupUsesCustomCards(widget) and widget.__puiTreeRowHeight ~= rowHeight then
    widget.__puiTreeRowHeight = rowHeight
    widget:RefreshTree()
  elseif widget.__puiTreePixelScroll and widget.__puiTreeRenderedRow == nil then
    widget:RefreshTree()
  end
end
WidgetSkins.TreeGroup = PUI_OptionsProfiler:Def("WidgetSkins.TreeGroup", WidgetSkins.TreeGroup)
