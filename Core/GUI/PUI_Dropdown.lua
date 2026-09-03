local _, ns = ...

local Theme = ns.Theme
local LSM = ns.LSM
local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local UIParent = _G.UIParent
local ipairs = _G.ipairs
local pairs = _G.pairs
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local table_sort = _G.table.sort
local string_find = _G.string.find
local string_lower = _G.string.lower
local math_max = _G.math.max
local math_min = _G.math.min

local WidgetSkins = Theme.WidgetSkins

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local ARROW_TEXTURE = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"


local function IsLSMDropdown(widgetType)
  return widgetType == "LSM30_Font"
    or widgetType == "LSM30_Sound"
    or widgetType == "LSM30_Border"
    or widgetType == "LSM30_Background"
    or widgetType == "LSM30_Statusbar"
end

local function SanitizeLSMFontList(widget)
  if widget.type ~= "LSM30_Font" or widget.__puiResolvedLSMFontList == widget.list then
    return
  end

  local resolved = {}
  for key in pairs(widget.list) do
    resolved[key] = LSM:Fetch("font", key, true)
  end

  widget.list = resolved
  widget.__puiResolvedLSMFontList = resolved
end


local function StripRegion(region, keep)
  if region ~= keep and region:GetObjectType() == "Texture" then
    region:SetTexture(nil)
    region:SetAlpha(0)
    region:Hide()
  end
end

local function StripFrame(frame, keep)
  local rowBackground = frame.__puiWidgetRowBackground

  for _, region in ipairs({ frame:GetRegions() }) do
    if region ~= rowBackground then
      StripRegion(region, keep)
    end
  end

  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end

  if frame._puiBg then
    frame._puiBg:Hide()
  end
end

local function ApplyRowSize(widget, frame, geom)
  Theme.ApplyCreatedWidgetSizing(widget)

  local height = geom.rowHeight
  frame.__puiWidgetBoxHeight = height
  frame.height = height
  frame:SetHeight(height)

  widget.__puiDropdownLayoutStateApplied = true
  widget.__puiDropdownGeometryApplied = true
  widget.__puiRegularDropdownGeometryApplied = true
  widget.__puiLSMDropdownGeometryApplied = true
end

local function CreateBox(widget, frame, geom)
  local colors = Theme.GetColors()
  local edge = math_max(Theme.GetEdgeSize(), 2)
  local box = widget.__puiDropdownBox

  if not box then
    box = CreateFrame("Frame", nil, frame)
    box:EnableMouse(false)
    Theme.MarkCreatedWidgetChrome(box)
    widget.__puiDropdownBox = box
  end

  box:SetParent(frame)
  box:SetFrameStrata(frame:GetFrameStrata())
  box:SetFrameLevel(frame:GetFrameLevel() + 5)
  box:ClearAllPoints()
  box:SetHeight(geom.controlHeight)
  box:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.controlLeft, -geom.controlTop)
  box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -geom.controlRight, -geom.controlTop)

  Theme.SetSquareBackdrop(box, {
    bg = colors.control,
    border = colors.border,
  }, edge)

  box._puiBg:ClearAllPoints()
  box._puiBg:SetAllPoints(box)
  box._puiBg:SetFrameLevel(math_max(box:GetFrameLevel() - 1, 1))
  box:Show()

  return box, colors, edge
end

local function CollapseLegacyFrame(frame, box, keepMouse)
  frame:ClearAllPoints()
  frame:SetAllPoints(box)
  frame:SetAlpha(0)
  frame:SetFrameStrata(box:GetFrameStrata())

  if keepMouse then
    frame:EnableMouse(true)
    frame:SetFrameLevel(box:GetFrameLevel() + 30)
  else
    frame:EnableMouse(false)
    frame:SetFrameLevel(math_max(box:GetFrameLevel() - 1, 1))
  end

  frame:Show()
end

local function SkinLabel(label, box)
  label:ClearAllPoints()
  label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 0)
  label:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -2, 0)
  label:SetHeight(14)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  Theme.ApplyFont(label, "body")

  local colors = Theme.GetColors()
  label:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
end

local function SkinArrowBox(widget, box, colors)
  local geom = Theme.GetWidgetRowGeometry(widget)
  local arrowSize = math_max(10, geom.controlHeight - 4)
  local arrowBox = widget.__puiDropdownArrowBox

  if not arrowBox then
    arrowBox = CreateFrame("Frame", nil, box)
    arrowBox:EnableMouse(false)
    Theme.MarkCreatedWidgetChrome(arrowBox)
    widget.__puiDropdownArrowBox = arrowBox
  end

  arrowBox:SetParent(box)
  arrowBox:SetFrameStrata(box:GetFrameStrata())
  arrowBox:SetFrameLevel(box:GetFrameLevel() + 10)
  arrowBox:ClearAllPoints()
  arrowBox:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -2)
  arrowBox:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
  arrowBox:SetWidth(arrowSize + 4)

  local arrow = arrowBox.__puiDropdownArrow
  if not arrow then
    arrow = arrowBox:CreateTexture(nil, "ARTWORK")
    arrowBox.__puiDropdownArrow = arrow
  end

  arrow:ClearAllPoints()
  arrow:SetPoint("CENTER", arrowBox, "CENTER", 0, 0)
  arrow:SetSize(arrowSize, arrowSize)
  arrow:SetTexture(ARROW_TEXTURE)
  arrow:SetAlpha(1)
  arrow:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.95)
  arrow:Show()

  arrowBox:Show()
  return arrowBox
end

local function ApplyValueFont(widget, widgetType, text)
  if widgetType == "LSM30_Font" then
    SanitizeLSMFontList(widget)

    local _, currentSize, currentFlags = text:GetFont()
    local role = Theme.GetFontRoleInfo("body")
    local fontSize = tonumber(role.size) or tonumber(currentSize) or 12
    local fontFlags = currentFlags or ""
    local fontKey = widget.value

    if fontKey == nil or fontKey == "" then
      Theme.ApplyFont(text, "body", fontSize, fontFlags)
    else
      local fontFile = LSM:Fetch("font", fontKey, true)
      if type(fontFile) == "string" and fontFile ~= "" then
        text:SetFont(fontFile, fontSize, fontFlags)
      else
        Theme.ApplyFont(text, "body", fontSize, fontFlags)
      end
    end
  else
    Theme.ApplyFont(text, "body")
  end

  local colors = Theme.GetColors()
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
end

local function SkinValueText(widget, widgetType, text, box, button)
  widget.__puiDropdownValueText = text

  if widgetType == "LSM30_Font" then
    text.__puiSkipOptionsGlobalFont = true
  end

  local layer = widget.__puiDropdownTextLayer
  if not layer then
    layer = CreateFrame("Frame", nil, box)
    layer:EnableMouse(false)
    Theme.MarkCreatedWidgetChrome(layer)
    widget.__puiDropdownTextLayer = layer
  end

  layer:SetParent(box)
  layer:SetAllPoints(box)
  layer:SetFrameStrata(box:GetFrameStrata())
  layer:SetFrameLevel(box:GetFrameLevel() + 15)
  layer:Show()

  text:SetParent(layer)
  text:ClearAllPoints()
  text:SetPoint("LEFT", layer, "LEFT", 6, 0)
  text:SetPoint("RIGHT", button, "LEFT", -4, 0)
  text:SetJustifyH("RIGHT")
  text:SetJustifyV("MIDDLE")
  text:SetDrawLayer("OVERLAY", 5)

  if widgetType == "LSM30_Statusbar" then
    local selected = widget.value or widget:GetValue()
    if selected and selected ~= "" then
      text:SetText(selected)
    end
  end

  ApplyValueFont(widget, widgetType, text)
end

local function SkinStatusbarPreview(widget, box, button)
  local preview = widget.__puiDropdownStatusbarPreview

  if not preview then
    preview = CreateFrame("Frame", nil, box)
    preview:EnableMouse(false)
    Theme.MarkCreatedWidgetChrome(preview)
    widget.__puiDropdownStatusbarPreview = preview
  end

  preview:SetParent(box)
  preview:SetFrameStrata(box:GetFrameStrata())
  preview:SetFrameLevel(box:GetFrameLevel() + 2)
  preview:ClearAllPoints()
  preview:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
  preview:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -4, 2)

  local texture = widget.__puiDropdownStatusbarTexture
  if not texture then
    texture = preview:CreateTexture(nil, "ARTWORK")
    widget.__puiDropdownStatusbarTexture = texture
  end

  texture:ClearAllPoints()
  texture:SetAllPoints(preview)

  local function Refresh()
    local selected = widget.value or widget:GetValue()
    local path = selected and LSM:Fetch("statusbar", selected, true)

    if not path then
      path = widget.bar:GetTexture()
    end

    if path then
      texture:SetTexture(path)
      texture:SetAlpha(0.70)
      texture:Show()
    else
      texture:SetTexture(nil)
      texture:Hide()
    end

    widget.bar:Hide()
  end

  widget.__puiDropdownRefreshStatusbar = Refresh

  if not widget.__puiDropdownStatusbarValueHooked then
    hooksecurefunc(widget, "SetValue", function(self)
      if self.__puiAceGUIOwnedByPleebUI == true and self.__puiDropdownRefreshStatusbar then
        self.__puiDropdownRefreshStatusbar()
      end
    end)
    widget.__puiDropdownStatusbarValueHooked = true
  end

  Refresh()
  preview:Show()

  return preview
end

local function SkinSoundButton(widget, box)
  local button = widget.soundbutton

  button:SetParent(box)
  button:ClearAllPoints()
  button:SetPoint("LEFT", box, "LEFT", 2, 0)
  WidgetSkins.Button(button, widget)
end

local function EnsurePulloutBackground(frame, colors, edge)
  Theme.SetSquareBackdrop(frame, {
    bg = colors.control,
    border = colors.border,
  }, edge)

  frame._puiBg:Show()
  return frame._puiBg
end

local PUI_DROPDOWN_PULL_OUT_VISIBLE_ROWS = 12
local PUI_DROPDOWN_PULL_OUT_ROW_GAP = 2
local PUI_DROPDOWN_SEARCH_MIN_ITEMS = 9
local PUI_DROPDOWN_SEARCH_SIDE_INSET = 8
local PUI_DROPDOWN_SEARCH_TOP_INSET = 6
local PUI_DROPDOWN_SEARCH_HEADER_GAP = 2

local function GetDropdownPulloutItemHeight()
  local role = Theme.GetFontRoleInfo("body")
  local fontSize = tonumber(role and role.size) or 12
  return math_max(20, fontSize + 8)
end

local function GetDropdownPulloutMetrics(pullout)
  local rowHeight = GetDropdownPulloutItemHeight()
  local rowGap = PUI_DROPDOWN_PULL_OUT_ROW_GAP
  local itemStep = rowHeight + rowGap
  local searchHeaderHeight = tonumber(pullout and pullout.__puiDropdownSearchHeaderHeight) or 0
  local maxHeight = itemStep * PUI_DROPDOWN_PULL_OUT_VISIBLE_ROWS + 34 + searchHeaderHeight
  return rowHeight, rowGap, itemStep, maxHeight, searchHeaderHeight
end

local function ApplyDropdownPulloutLayering(pullout)
  local frame = pullout.frame
  local scrollFrame = pullout.scrollFrame
  local itemFrame = pullout.itemFrame
  local slider = pullout.slider
  local searchBox = pullout.__puiDropdownSearchBox
  local items = pullout.items or {}
  local strata = frame:GetFrameStrata()
  local baseLevel = frame:GetFrameLevel()
  local itemCount = #items

  if pullout.__puiDropdownLayerStrata == strata
    and pullout.__puiDropdownLayerBase == baseLevel
    and pullout.__puiDropdownLayerItemCount == itemCount
    and pullout.__puiDropdownLayerSearchBox == searchBox
  then
    return
  end

  if frame._puiBg then
    frame._puiBg:SetFrameStrata(strata)
    frame._puiBg:SetFrameLevel(math_max(baseLevel - 1, 0))
  end

  if scrollFrame then
    scrollFrame:SetToplevel(false)
    scrollFrame:SetFrameStrata(strata)
    scrollFrame:SetFrameLevel(baseLevel + 1)
  end

  if itemFrame then
    itemFrame:SetToplevel(false)
    itemFrame:SetFrameStrata(strata)
    itemFrame:SetFrameLevel(baseLevel + 2)
  end

  if slider then
    slider:SetFrameStrata(strata)
    slider:SetFrameLevel(baseLevel + 3)
    if slider._puiBg then
      slider._puiBg:SetFrameStrata(strata)
      slider._puiBg:SetFrameLevel(baseLevel + 2)
    end
  end

  for index = 1, itemCount do
    local item = items[index]
    if item and item.frame then
      item.frame:SetToplevel(false)
      item.frame:SetFrameStrata(strata)
      item.frame:SetFrameLevel(baseLevel + 3)
    end
  end

  if searchBox then
    searchBox:SetToplevel(false)
    searchBox:SetFrameStrata(strata)
    searchBox:SetFrameLevel(baseLevel + 4)
    if searchBox._puiBg then
      searchBox._puiBg:SetFrameStrata(strata)
      searchBox._puiBg:SetFrameLevel(baseLevel + 3)
    end
  end

  pullout.__puiDropdownLayerStrata = strata
  pullout.__puiDropdownLayerBase = baseLevel
  pullout.__puiDropdownLayerItemCount = itemCount
  pullout.__puiDropdownLayerSearchBox = searchBox
end

local function RefreshDropdownPulloutLayout(pullout)
  if not pullout or not pullout.items or not pullout.itemFrame or not pullout.frame then
    return
  end

  local rowHeight, _, itemStep, maxHeight, searchHeaderHeight = GetDropdownPulloutMetrics(pullout)

  if pullout.SetMaxHeight then
    pullout:SetMaxHeight(maxHeight)
  else
    pullout.maxHeight = maxHeight
  end

  if pullout.scrollFrame then
    pullout.scrollFrame:ClearAllPoints()
    pullout.scrollFrame:SetPoint("TOPLEFT", pullout.frame, "TOPLEFT", 6, -12 - searchHeaderHeight)
    pullout.scrollFrame:SetPoint("BOTTOMRIGHT", pullout.frame, "BOTTOMRIGHT", -6, 12)
  end

  local items = pullout.items
  local visibleIndex = 0

  for index = 1, #items do
    local item = items[index]
    if item and item.frame then
      if item.userdata and item.userdata.__puiDropdownFilteredOut == true then
        item:Hide()
      else
        visibleIndex = visibleIndex + 1
        item.frame:SetHeight(rowHeight)
        item.frame:ClearAllPoints()

        local yOffset = -2 - (visibleIndex - 1) * itemStep
        item:SetPoint("TOPLEFT", pullout.itemFrame, "TOPLEFT", 0, yOffset)
        item:SetPoint("TOPRIGHT", pullout.itemFrame, "TOPRIGHT", 0, yOffset)
        item:Show()
      end
    end
  end

  local contentHeight = visibleIndex * itemStep
  pullout.itemFrame:SetHeight(8 + contentHeight)
  pullout.frame:SetHeight(math.min(contentHeight + 34 + searchHeaderHeight, pullout.maxHeight or maxHeight))

  ApplyDropdownPulloutLayering(pullout)

  if pullout.FixScroll then
    pullout:FixScroll()
  end
end

local function EnsureDropdownPulloutLayout(pullout)
  if not pullout then
    return
  end

  if not pullout.__puiDropdownLayoutHooked then
    pullout.__puiDropdownLayoutHooked = true

    local originalAddItem = pullout.AddItem
    pullout.AddItem = function(self, item)
      local result = originalAddItem(self, item)
      RefreshDropdownPulloutLayout(self)
      return result
    end

    local originalOpen = pullout.Open
    pullout.Open = function(self, ...)
      local result = originalOpen(self, ...)
      RefreshDropdownPulloutLayout(self)
      return result
    end
  end

  RefreshDropdownPulloutLayout(pullout)
end

local function SkinPulloutFrame(frame, slider, colors, edge)
  if not frame then
    return
  end

  StripFrame(frame)

  frame:SetFrameStrata("TOOLTIP")
  frame:SetToplevel(true)
  frame:Raise()
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)

  EnsurePulloutBackground(frame, colors, edge)

  local thumb = slider:GetThumbTexture()
  StripFrame(slider, thumb)
  Theme.SetSquareBackdrop(slider, {
    bg = colors.control,
    border = colors.border,
  }, edge)

  slider:SetThumbTexture(WHITE8)
  thumb = slider:GetThumbTexture()
  thumb:SetTexCoord(0, 1, 0, 1)
  thumb:SetSize(8, 18)
  thumb:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.90)
  thumb:Show()
end

local function ResetLSMFontDropdownSearchFrame(dropdown)
  local searchBox = dropdown and dropdown.__puiLSMFontSearchBox
  if searchBox then
    searchBox.obj = nil
    searchBox:SetText("")
    searchBox:ClearFocus()
    searchBox:Hide()
  end

  if not dropdown or not dropdown.scrollframe then
    return
  end

  dropdown.scrollframe:ClearAllPoints()
  dropdown.scrollframe:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 14, -13)
  dropdown.scrollframe:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -14, 12)
end

local function RefreshLSMFontDropdownSearch(widget)
  local dropdown = widget and widget.dropdown
  local searchBox = dropdown and dropdown.__puiLSMFontSearchBox
  local contentframe = dropdown and dropdown.contentframe
  local scrollframe = dropdown and dropdown.scrollframe
  local slider = dropdown and dropdown.slider
  local rows = dropdown and dropdown.contentRepo

  if not searchBox or not contentframe or not scrollframe or not slider or not rows then
    return
  end

  local query = string_lower(searchBox:GetText() or "")
  local previous
  local contentHeight = 0

  for index = 1, #rows do
    local row = rows[index]
    local rowText = row and row.text and string_lower(row.text:GetText() or "") or ""
    local visible = query == "" or string_find(rowText, query, 1, true) ~= nil

    if row then
      row:ClearAllPoints()

      if visible then
        if previous then
          row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
        else
          row:SetPoint("TOPLEFT", contentframe, "TOPLEFT", 0, 0)
        end
        row:SetPoint("RIGHT", contentframe, "RIGHT", 0, 0)
        row:Show()

        contentHeight = contentHeight + row:GetHeight()
        previous = row
      else
        row:Hide()
      end
    end
  end

  contentframe:SetHeight(contentHeight)

  local searchHeight = GetDropdownPulloutItemHeight()
  local searchHeaderHeight = PUI_DROPDOWN_SEARCH_TOP_INSET
    + searchHeight
    + PUI_DROPDOWN_SEARCH_HEADER_GAP
  local maxHeight = UIParent:GetHeight() * 2 / 5
  local popupHeight = math_min(contentHeight + 25 + searchHeaderHeight, maxHeight)
  local viewportHeight = math_max(1, popupHeight - 25 - searchHeaderHeight)
  local scrollable = contentHeight > viewportHeight

  dropdown:SetHeight(popupHeight)

  scrollframe:ClearAllPoints()
  scrollframe:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 14, -13 - searchHeaderHeight)
  scrollframe:SetPoint(
    "BOTTOMRIGHT",
    dropdown,
    "BOTTOMRIGHT",
    scrollable and -28 or -14,
    12
  )

  contentframe:SetWidth(scrollframe:GetWidth())
  scrollframe:SetVerticalScroll(0)

  if scrollable then
    slider:SetMinMaxValues(0, contentHeight - viewportHeight)
    slider:SetValue(0)
    slider:Show()
  else
    slider:SetMinMaxValues(0, 0)
    slider:SetValue(0)
    slider:Hide()
  end
end

local function LSMFontDropdownSearchTextChanged(searchBox)
  local widget = searchBox.obj
  if not widget or widget.dropdown ~= searchBox:GetParent() then
    return
  end

  if searchBox.Instructions then
    searchBox.Instructions:SetShown(searchBox:GetText() == "" and not searchBox:HasFocus())
  end

  RefreshLSMFontDropdownSearch(widget)
end

local function LSMFontDropdownSearchFocusGained(searchBox)
  local widget = searchBox.obj
  if widget then
    AceGUI:SetFocus(widget)
  end

  if searchBox.Instructions then
    searchBox.Instructions:Hide()
  end
end

local function LSMFontDropdownSearchFocusLost(searchBox)
  if searchBox.Instructions then
    searchBox.Instructions:SetShown(searchBox:GetText() == "")
  end
end

local function LSMFontDropdownSearchEscapePressed(searchBox)
  local widget = searchBox.obj
  searchBox:ClearFocus()

  if widget then
    widget:ClearFocus()
  end

  AceGUI:ClearFocus()
end

local function EnsureLSMFontDropdownSearch(widget)
  local dropdown = widget and widget.dropdown
  if not dropdown or widget.type ~= "LSM30_Font" then
    return
  end

  local rows = dropdown.contentRepo or {}
  local searchBox = dropdown.__puiLSMFontSearchBox

  if #rows < PUI_DROPDOWN_SEARCH_MIN_ITEMS then
    if searchBox then
      searchBox:Hide()
    end
    return
  end

  if not searchBox then
    searchBox = CreateFrame("EditBox", nil, dropdown)
    searchBox.__puiOptionsFontOwned = true
    searchBox:SetAutoFocus(false)
    searchBox:SetJustifyH("LEFT")
    searchBox:SetJustifyV("MIDDLE")
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:SetScript("OnTextChanged", LSMFontDropdownSearchTextChanged)
    searchBox:SetScript("OnEditFocusGained", LSMFontDropdownSearchFocusGained)
    searchBox:SetScript("OnEditFocusLost", LSMFontDropdownSearchFocusLost)
    searchBox:SetScript("OnEscapePressed", LSMFontDropdownSearchEscapePressed)

    local instructions = searchBox:CreateFontString(nil, "OVERLAY")
    instructions.__puiOptionsFontOwned = true
    Theme.ApplyFont(instructions, "body")
    instructions:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    instructions:SetPoint("RIGHT", searchBox, "RIGHT", -6, 0)
    instructions:SetJustifyH("LEFT")
    instructions:SetJustifyV("MIDDLE")
    instructions:SetText("Search...")
    searchBox.Instructions = instructions

    dropdown.__puiLSMFontSearchBox = searchBox

    if not dropdown.__puiLSMFontSearchHideHooked then
      dropdown.__puiLSMFontSearchHideHooked = true
      dropdown:HookScript("OnHide", ResetLSMFontDropdownSearchFrame)
    end
  end

  if searchBox.obj ~= widget then
    searchBox.obj = widget
    searchBox:SetText("")
  end

  WidgetSkins.UIEditBox(searchBox)
  searchBox:SetParent(dropdown)
  searchBox:SetFrameStrata(dropdown:GetFrameStrata())
  searchBox:SetFrameLevel(dropdown:GetFrameLevel() + 110)
  searchBox:ClearAllPoints()
  searchBox:SetPoint(
    "TOPLEFT",
    dropdown,
    "TOPLEFT",
    PUI_DROPDOWN_SEARCH_SIDE_INSET,
    -PUI_DROPDOWN_SEARCH_TOP_INSET
  )
  searchBox:SetPoint(
    "TOPRIGHT",
    dropdown,
    "TOPRIGHT",
    -PUI_DROPDOWN_SEARCH_SIDE_INSET,
    -PUI_DROPDOWN_SEARCH_TOP_INSET
  )
  searchBox:SetHeight(GetDropdownPulloutItemHeight())
  searchBox:Show()

  RefreshLSMFontDropdownSearch(widget)
end

local function OwnStandardDropdownChildren(widget)
  local pullout = widget.pullout
  local AceHooks = ns.AceHooks

  if not pullout then
    return
  end

  AceHooks.TakeOwnership(pullout)

  if not pullout.__puiDropdownAddItemHooked then
    pullout.__puiDropdownAddItemHooked = true

    hooksecurefunc(pullout, "AddItem", function(self, item)
      if self.__puiAceGUIOwnedByPleebUI == true and item then
        AceHooks.TakeOwnership(item)
      end
    end)
  end

  for _, item in pullout:IterateItems() do
    AceHooks.TakeOwnership(item)
  end
end

local function SkinDropdownPullout(widget, isLSM, colors, edge)
  if isLSM then
    local frame = widget.dropdown
    if frame then
      SkinPulloutFrame(frame, frame.slider, colors, edge)
      EnsureLSMFontDropdownSearch(widget)
    end
    return
  end

  local pullout = widget.pullout
  if pullout then
    EnsureDropdownPulloutLayout(pullout)
    SkinPulloutFrame(pullout.frame, pullout.slider, colors, edge)
  end
end

local function SkinDropdown(widget, isLSM)
  local frame = widget.frame
  local label = isLSM and frame.label or widget.label
  local text = isLSM and frame.text or widget.text
  local clickTarget = isLSM and frame.dropButton or widget.button_cover
  local geom = Theme.GetWidgetRowGeometry(widget)

  if not isLSM then
    OwnStandardDropdownChildren(widget)
  end

  ApplyRowSize(widget, frame, geom)
  StripFrame(frame, widget.bar)

  if isLSM then
    StripFrame(frame.dropButton, widget.bar)
  else
    StripFrame(widget.dropdown, widget.bar)
    StripFrame(widget.button, widget.bar)
    StripFrame(widget.button_cover, widget.bar)
  end

  local box, colors, edge = CreateBox(widget, frame, geom)
  local arrowBox = SkinArrowBox(widget, box, colors)

  if widget.type == "LSM30_Statusbar" then
    SkinStatusbarPreview(widget, box, arrowBox)
  elseif widget.__puiDropdownStatusbarPreview then
    widget.__puiDropdownStatusbarPreview:Hide()
  end

  SkinLabel(label, box)
  SkinValueText(widget, widget.type, text, box, arrowBox)

  if widget.type == "LSM30_Sound" then
    SkinSoundButton(widget, box)
  end

  if not clickTarget.__puiDropdownPulloutClickHooked then
    clickTarget.__puiDropdownPulloutClickHooked = true
    clickTarget:HookScript("OnClick", function()
      if widget.__puiAceGUIOwnedByPleebUI ~= true or AceGUI:IsReleasing(widget) then
        return
      end

      local ownershipSerial = widget.__puiAceGUIOwnershipSerial

      local function RefreshPullout()
        if widget.__puiAceGUIOwnershipSerial ~= ownershipSerial
          or widget.__puiAceGUIOwnedByPleebUI ~= true
          or AceGUI:IsReleasing(widget)
        then
          return
        end

        SkinDropdownPullout(widget, isLSM, Theme.GetColors(), math_max(Theme.GetEdgeSize(), 2))
      end

      RefreshPullout()
      C_Timer.After(0, RefreshPullout)
    end)
  end

  if isLSM then
    CollapseLegacyFrame(frame.dropButton, box, true)
  else
    CollapseLegacyFrame(widget.dropdown, box, false)
    CollapseLegacyFrame(widget.button, box, false)
    CollapseLegacyFrame(widget.button_cover, box, true)
  end
end

function WidgetSkins.DropdownPullout(widget)
  SkinPulloutFrame(widget.frame, widget.slider, Theme.GetColors(), math_max(Theme.GetEdgeSize(), 2))
end

function WidgetSkins.Dropdown(widget)
  SkinDropdown(widget, IsLSMDropdown(widget.type))
end

function WidgetSkins.DropdownItem(widget)
  local colors = Theme.GetColors()
  local frame = widget.frame
  local text = widget.text
  local highlight = widget.highlight
  local check = widget.check
  local sub = widget.sub
  local bar = widget.bar
  local accent = colors.accent
  local rowHeight = GetDropdownPulloutItemHeight()

  frame:SetHeight(rowHeight)

  if bar then
    bar:SetAlpha(0.75)
    bar:SetDrawLayer("ARTWORK", 1)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -1)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 1)
    bar:Show()
  end

  highlight:SetTexture(WHITE8)
  highlight:ClearAllPoints()
  highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -1)
  highlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 1)
  highlight:SetVertexColor(accent[1], accent[2], accent[3], 0.14)

  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:ClearAllPoints()
  check:SetPoint("LEFT", frame, "LEFT", 3, 0)
  check:SetSize(16, 16)
  check:SetVertexColor(accent[1], accent[2], accent[3], 0.95)

  sub:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  sub:ClearAllPoints()
  sub:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
  sub:SetSize(16, 16)
  sub:SetVertexColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

  Theme.ApplyFont(text, "body")
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  text:ClearAllPoints()
  text:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -1)
  text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 1)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("MIDDLE")
end
local PUI_DROPDOWN_TYPE = "PUI_Dropdown"
local PUI_DROPDOWN_VERSION = 1

local function PUI_Dropdown_SetTextureColor(texture, color, alphaMultiplier)
  texture:SetColorTexture(
    color[1],
    color[2],
    color[3],
    (color[4] or 1) * (alphaMultiplier or 1)
  )
end

local function PUI_Dropdown_CreateChrome(parent)
  local background = parent:CreateTexture(nil, "BACKGROUND")
  background:SetTexture(WHITE8)

  local border = {
    top = parent:CreateTexture(nil, "BORDER"),
    bottom = parent:CreateTexture(nil, "BORDER"),
    left = parent:CreateTexture(nil, "BORDER"),
    right = parent:CreateTexture(nil, "BORDER"),
  }

  for _, texture in pairs(border) do
    texture:SetTexture(WHITE8)
  end

  return {
    background = background,
    border = border,
  }
end

local function PUI_Dropdown_LayoutChrome(parent, chrome)
  local edge = Theme.GetEdgeSize()
  local border = chrome.border

  chrome.background:ClearAllPoints()
  chrome.background:SetPoint("TOPLEFT", parent, "TOPLEFT", edge, -edge)
  chrome.background:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, edge)

  border.top:ClearAllPoints()
  border.top:SetPoint("TOPLEFT", parent, "TOPLEFT")
  border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  border.top:SetHeight(edge)

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
  border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -edge)
  border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, edge)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -edge)
  border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, edge)
  border.right:SetWidth(edge)
end

local function PUI_Dropdown_SetChromeColors(chrome, backgroundColor, borderColor, alphaMultiplier)
  PUI_Dropdown_SetTextureColor(chrome.background, backgroundColor, alphaMultiplier)

  for _, texture in pairs(chrome.border) do
    PUI_Dropdown_SetTextureColor(texture, borderColor, alphaMultiplier)
  end
end

local function PUI_Dropdown_Layout(widget, width)
  local geom = Theme.GetWidgetRowGeometry(widget)
  local frameWidth = tonumber(width) or widget.frame:GetWidth() or 200
  local controlTop = widget.label:IsShown()
    and geom.controlTop
    or math_max(0, ((widget.frame:GetHeight() or geom.rowHeight) - geom.controlHeight) * 0.5)

  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.labelLeft, -geom.labelTop)
  widget.label:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.labelRight, -geom.labelTop)
  widget.label:SetHeight(geom.labelHeight)

  widget.button:ClearAllPoints()
  widget.button:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.controlLeft, -controlTop)
  widget.button:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.controlRight, -controlTop)
  widget.button:SetHeight(geom.controlHeight)

  local arrowSize = math_max(10, geom.controlHeight - 4)
  widget.arrow:ClearAllPoints()
  widget.arrow:SetPoint("RIGHT", widget.button, "RIGHT", -4, 0)
  widget.arrow:SetSize(arrowSize, arrowSize)

  widget.text:ClearAllPoints()
  widget.text:SetPoint("LEFT", widget.button, "LEFT", 6, 0)
  widget.text:SetPoint("RIGHT", widget.arrow, "LEFT", -4, 0)
  widget.text:SetHeight(geom.controlHeight - 4)

  PUI_Dropdown_LayoutChrome(widget.button, widget.chrome)
  widget.frame:SetWidth(frameWidth)
end

local function PUI_Dropdown_RefreshVisualState(widget)
  local colors = Theme.GetColors()
  local disabled = widget.disabled == true
  local hovered = widget.button.__puiHovered == true
  local textColor = disabled and colors.disabledText or colors.text
  local controlColor = disabled and colors.disabledControl or colors.control
  local borderColor = disabled and colors.disabledBorder or colors.border
  local arrowColor = disabled and colors.disabledText or colors.accent

  if hovered and not disabled then
    borderColor = colors.accent
  end

  PUI_Dropdown_SetChromeColors(widget.chrome, controlColor, borderColor, 1)

  widget.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.arrow:SetVertexColor(
    arrowColor[1],
    arrowColor[2],
    arrowColor[3],
    arrowColor[4]
  )
end

local function PUI_Dropdown_ShowMultiselectText(widget)
  local text

  for _, item in widget.pullout:IterateItems() do
    if item.type == "Dropdown-Item-Toggle" and item:GetValue() then
      local itemText = item:GetText()
      text = text and (text .. ", " .. itemText) or itemText
    end
  end

  widget:SetText(text)
end

local function PUI_Dropdown_ItemMatchesSearch(item, query)
  if query == "" then
    return true
  end

  local searchText = item.userdata and item.userdata.__puiDropdownSearchText or ""
  return string_find(searchText, query, 1, true) ~= nil
end

local function PUI_Dropdown_ApplySearch(widget)
  local pullout = widget and widget.pullout
  if not pullout then
    return
  end

  local searchBox = pullout.__puiDropdownSearchBox
  local query = searchBox and string_lower(searchBox:GetText() or "") or ""

  for _, item in pullout:IterateItems() do
    if item.userdata then
      local keepVisible = item.userdata.__puiDropdownClose == true
        or PUI_Dropdown_ItemMatchesSearch(item, query)
      item.userdata.__puiDropdownFilteredOut = not keepVisible
    end
  end

  RefreshDropdownPulloutLayout(pullout)
end

local function PUI_Dropdown_OnSearchTextChanged(editbox)
  local widget = editbox.obj
  if not widget or not widget.pullout then
    return
  end

  if editbox.Instructions then
    if editbox:GetText() == "" and not editbox:HasFocus() then
      editbox.Instructions:Show()
    else
      editbox.Instructions:Hide()
    end
  end

  PUI_Dropdown_ApplySearch(widget)
end

local function PUI_Dropdown_OnSearchFocusGained(editbox)
  local widget = editbox.obj
  if widget then
    AceGUI:SetFocus(widget)
  end

  if editbox.Instructions then
    editbox.Instructions:Hide()
  end
end

local function PUI_Dropdown_OnSearchFocusLost(editbox)
  if editbox.Instructions then
    if editbox:GetText() == "" then
      editbox.Instructions:Show()
    else
      editbox.Instructions:Hide()
    end
  end
end

local function PUI_Dropdown_OnSearchEscapePressed(editbox)
  local widget = editbox.obj
  editbox:ClearFocus()

  if widget and widget.open then
    widget.pullout:Close()
  end

  AceGUI:ClearFocus()
end

local function PUI_Dropdown_EnsureSearchBox(widget)
  local pullout = widget.pullout
  local searchBox = pullout.__puiDropdownSearchBox

  if not searchBox then
    searchBox = CreateFrame("EditBox", nil, pullout.frame)
    searchBox.__puiOptionsFontOwned = true
    searchBox:SetAutoFocus(false)
    searchBox:SetJustifyH("LEFT")
    searchBox:SetJustifyV("MIDDLE")
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:SetScript("OnTextChanged", PUI_Dropdown_OnSearchTextChanged)
    searchBox:SetScript("OnEditFocusGained", PUI_Dropdown_OnSearchFocusGained)
    searchBox:SetScript("OnEditFocusLost", PUI_Dropdown_OnSearchFocusLost)
    searchBox:SetScript("OnEscapePressed", PUI_Dropdown_OnSearchEscapePressed)

    local instructions = searchBox:CreateFontString(nil, "OVERLAY")
    instructions.__puiOptionsFontOwned = true
    Theme.ApplyFont(instructions, "body")
    instructions:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    instructions:SetPoint("RIGHT", searchBox, "RIGHT", -6, 0)
    instructions:SetJustifyH("LEFT")
    instructions:SetJustifyV("MIDDLE")
    instructions:SetText("Search...")
    searchBox.Instructions = instructions

    pullout.__puiDropdownSearchBox = searchBox
  end

  searchBox.obj = widget
  WidgetSkins.UIEditBox(searchBox)
  return searchBox
end

local function PUI_Dropdown_UpdateSearchAvailability(widget)
  local pullout = widget.pullout
  if not pullout then
    return
  end

  local enabled = (widget.listItemCount or 0) >= PUI_DROPDOWN_SEARCH_MIN_ITEMS
  widget.searchEnabled = enabled

  if not enabled then
    local searchBox = pullout.__puiDropdownSearchBox
    if searchBox then
      searchBox:SetText("")
      searchBox:ClearFocus()
      searchBox:Hide()
    end

    pullout.__puiDropdownSearchHeaderHeight = 0
    PUI_Dropdown_ApplySearch(widget)
    return
  end

  local searchBox = PUI_Dropdown_EnsureSearchBox(widget)
  local searchHeight = GetDropdownPulloutItemHeight()

  searchBox:ClearAllPoints()
  searchBox:SetPoint(
    "TOPLEFT",
    pullout.frame,
    "TOPLEFT",
    PUI_DROPDOWN_SEARCH_SIDE_INSET,
    -PUI_DROPDOWN_SEARCH_TOP_INSET
  )
  searchBox:SetPoint(
    "TOPRIGHT",
    pullout.frame,
    "TOPRIGHT",
    -PUI_DROPDOWN_SEARCH_SIDE_INSET,
    -PUI_DROPDOWN_SEARCH_TOP_INSET
  )
  searchBox:SetHeight(searchHeight)
  searchBox:Show()

  pullout.__puiDropdownSearchHeaderHeight = searchHeight + PUI_DROPDOWN_SEARCH_HEADER_GAP
  PUI_Dropdown_ApplySearch(widget)
end

local function PUI_Dropdown_ResetSearch(widget)
  local pullout = widget.pullout
  local searchBox = pullout and pullout.__puiDropdownSearchBox

  if searchBox then
    searchBox:SetText("")
    searchBox:ClearFocus()
  end

  PUI_Dropdown_ApplySearch(widget)
end

local function PUI_Dropdown_OnPulloutOpen(pullout)
  local widget = pullout.userdata.obj
  local value = widget.value

  if not widget.multiselect then
    for _, item in pullout:IterateItems() do
      item:SetValue(item.userdata.value == value)
    end
  end

  widget.open = true
  widget:Fire("OnOpened")
end

local function PUI_Dropdown_OnPulloutClose(pullout)
  local widget = pullout.userdata.obj
  widget.open = nil
  PUI_Dropdown_ResetSearch(widget)
  widget:Fire("OnClosed")
end

local function PUI_Dropdown_OnItemValueChanged(item, _, checked)
  local widget = item.userdata.obj
  local value = item.userdata.value

  if widget.multiselect then
    widget:Fire("OnValueChanged", value, checked)
    PUI_Dropdown_ShowMultiselectText(widget)
  else
    if checked then
      widget:SetValue(value)
      widget:Fire("OnValueChanged", value)
    else
      item:SetValue(true)
    end

    if widget.open then
      widget.pullout:Close()
    end
  end
end

local function PUI_Dropdown_Toggle(button)
  local widget = button.obj

  if widget.disabled then
    return
  end

  if widget.open then
    widget.pullout:Close()
    AceGUI:ClearFocus()
  else
    PUI_Dropdown_UpdateSearchAvailability(widget)
    EnsureDropdownPulloutLayout(widget.pullout)
    widget.pullout:SetWidth(widget.pulloutWidth or widget.button:GetWidth())
    widget.pullout:Open("TOPLEFT", widget.button, "BOTTOMLEFT", 0, -2)
    AceGUI:SetFocus(widget)
  end
end

local function PUI_Dropdown_OnEnter(button)
  local widget = button.obj
  button.__puiHovered = true
  PUI_Dropdown_RefreshVisualState(widget)
  widget:Fire("OnEnter")
end

local function PUI_Dropdown_OnLeave(button)
  local widget = button.obj
  button.__puiHovered = nil
  PUI_Dropdown_RefreshVisualState(widget)
  widget:Fire("OnLeave")
end

local function PUI_Dropdown_OnHide(frame)
  local widget = frame.obj

  if widget.open then
    widget.pullout:Close()
  end
end

local function PUI_Dropdown_SortKeys(left, right)
  local leftNumber = tonumber(left)
  local rightNumber = tonumber(right)

  if leftNumber and rightNumber then
    return leftNumber < rightNumber
  end

  return tostring(left) < tostring(right)
end

local function PUI_Dropdown_AddListItem(widget, value, text, itemType)
  local item = AceGUI:Create(itemType or "Dropdown-Item-Toggle")
  item:SetText(text)
  item.userdata.obj = widget
  item.userdata.value = value
  item.userdata.__puiDropdownSearchText = string_lower(tostring(text or ""))
    .. "\n"
    .. string_lower(tostring(value or ""))
  item.userdata.__puiDropdownFilteredOut = nil
  item:SetCallback("OnValueChanged", PUI_Dropdown_OnItemValueChanged)
  widget.pullout:AddItem(item)
  ns.AceHooks.TakeOwnership(item)
end

local function PUI_Dropdown_AddCloseButton(widget)
  if widget.hasClose then
    return
  end

  local close = AceGUI:Create("Dropdown-Item-Execute")
  close:SetText(CLOSE)
  close.userdata.__puiDropdownClose = true
  close.userdata.__puiDropdownFilteredOut = nil
  widget.pullout:AddItem(close)
  ns.AceHooks.TakeOwnership(close)
  widget.hasClose = true
end

local PUI_Dropdown_Methods = {
  OnAcquire = function(self)
    local pullout = AceGUI:Create("Dropdown-Pullout")

    self.pullout = pullout
    pullout.userdata.obj = self
    pullout:SetCallback("OnClose", PUI_Dropdown_OnPulloutClose)
    pullout:SetCallback("OnOpen", PUI_Dropdown_OnPulloutOpen)
    ns.AceHooks.TakeOwnership(pullout)
    pullout.frame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
    EnsureDropdownPulloutLayout(pullout)

    self:SetHeight(Theme.GetControlMetrics().widgetBoxHeight)
    self:SetWidth(200)
    self:SetLabel(nil)
    self:SetPulloutWidth(nil)
    self:SetMultiselect(false)
    self:SetDisabled(false)
    self.list = {}
    self.listItemCount = 0
    self.value = nil
    self.open = nil
    self.hasClose = nil
    self.searchEnabled = nil
    self.button.__puiHovered = nil
    self:SetText("")
    self:RefreshTheme()
  end,

  OnRelease = function(self)
    if self.open then
      self.pullout:Close()
    end

    PUI_Dropdown_ResetSearch(self)

    local searchBox = self.pullout.__puiDropdownSearchBox
    if searchBox then
      searchBox.obj = nil
      searchBox:Hide()
    end
    self.pullout.__puiDropdownSearchHeaderHeight = 0
    RefreshDropdownPulloutLayout(self.pullout)

    self.pullout.frame:SetToplevel(false)
    self.pullout.scrollFrame:SetToplevel(true)
    self.pullout.itemFrame:SetToplevel(true)
    for _, item in self.pullout:IterateItems() do
      if item.frame then
        item.frame:SetToplevel(true)
      end
    end

    self.pullout.__puiDropdownLayerStrata = nil
    self.pullout.__puiDropdownLayerBase = nil
    self.pullout.__puiDropdownLayerItemCount = nil
    self.pullout.__puiDropdownLayerSearchBox = nil

    AceGUI:Release(self.pullout)
    self.pullout = nil
    self.button.__puiHovered = nil
    self.list = nil
    self.listItemCount = nil
    self.value = nil
    self.open = nil
    self.hasClose = nil
    self.searchEnabled = nil
    self.multiselect = nil
    self.pulloutWidth = nil
  end,

  OnWidthSet = function(self, width)
    PUI_Dropdown_Layout(self, width)
  end,

  OnHeightSet = function(self)
    PUI_Dropdown_Layout(self, self.frame:GetWidth())
  end,

  SetDisabled = function(self, disabled)
    disabled = disabled == true
    self.disabled = disabled

    if disabled then
      self.button:Disable()
      self.button.__puiHovered = nil
      self:ClearFocus()
    else
      self.button:Enable()
    end

    PUI_Dropdown_RefreshVisualState(self)
  end,

  ClearFocus = function(self)
    if self.open then
      self.pullout:Close()
    end
  end,

  SetText = function(self, text)
    self.text:SetText(text or "")
  end,

  SetLabel = function(self, text)
    if text and text ~= "" then
      self.label:SetText(text)
      self.label:Show()
    else
      self.label:SetText("")
      self.label:Hide()
    end

    PUI_Dropdown_Layout(self, self.frame:GetWidth())
  end,

  SetValue = function(self, value)
    self.value = value
    self:SetText(self.list and self.list[value] or "")
  end,

  GetValue = function(self)
    return self.value
  end,

  SetItemValue = function(self, value, checked)
    if not self.multiselect then
      return
    end

    for _, item in self.pullout:IterateItems() do
      if item.userdata.value == value and item.SetValue then
        item:SetValue(checked)
        break
      end
    end

    PUI_Dropdown_ShowMultiselectText(self)
  end,

  SetItemDisabled = function(self, value, disabled)
    for _, item in self.pullout:IterateItems() do
      if item.userdata.value == value then
        item:SetDisabled(disabled)
        break
      end
    end
  end,

  SetList = function(self, list, order, itemType, sortByValue)
    self.list = list or {}
    self.listItemCount = 0
    self.pullout:Clear()
    self.hasClose = nil

    if not list then
      PUI_Dropdown_UpdateSearchAvailability(self)
      self:SetText("")
      return
    end

    local keys = {}

    if type(order) == "table" then
      for i = 1, #order do
        keys[i] = order[i]
      end
    else
      for key in pairs(list) do
        keys[#keys + 1] = key
      end

      if sortByValue then
        table_sort(keys, function(left, right)
          local leftText = tostring(list[left] or "")
          local rightText = tostring(list[right] or "")

          if leftText == rightText then
            return PUI_Dropdown_SortKeys(left, right)
          end

          return leftText < rightText
        end)
      else
        table_sort(keys, PUI_Dropdown_SortKeys)
      end
    end

    self.listItemCount = #keys

    for i = 1, #keys do
      local key = keys[i]
      PUI_Dropdown_AddListItem(self, key, list[key], itemType)
    end

    if self.multiselect then
      PUI_Dropdown_ShowMultiselectText(self)
      PUI_Dropdown_AddCloseButton(self)
    end

    PUI_Dropdown_UpdateSearchAvailability(self)
  end,

  AddItem = function(self, value, text, itemType)
    local isNewValue = self.list[value] == nil
    self.list[value] = text
    PUI_Dropdown_AddListItem(self, value, text, itemType)

    if isNewValue then
      self.listItemCount = (self.listItemCount or 0) + 1
    end

    PUI_Dropdown_UpdateSearchAvailability(self)
  end,

  SetMultiselect = function(self, multiselect)
    self.multiselect = multiselect == true

    if self.multiselect then
      PUI_Dropdown_ShowMultiselectText(self)
      PUI_Dropdown_AddCloseButton(self)
    end
  end,

  GetMultiselect = function(self)
    return self.multiselect == true
  end,

  SetPulloutWidth = function(self, width)
    self.pulloutWidth = width
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.label, "body")
    Theme.ApplyFont(self.text, "body")

    if self.pullout and self.pullout.__puiDropdownSearchBox then
      WidgetSkins.UIEditBox(self.pullout.__puiDropdownSearchBox)
      PUI_Dropdown_UpdateSearchAvailability(self)
    end

    PUI_Dropdown_Layout(self, self.frame:GetWidth())
    PUI_Dropdown_RefreshVisualState(self)
  end,
}

local function PUI_Dropdown_Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetScript("OnHide", PUI_Dropdown_OnHide)

  local label = frame:CreateFontString(nil, "OVERLAY")
  label.__puiOptionsFontOwned = true
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  Theme.ApplyFont(label, "body")

  local button = CreateFrame("Button", nil, frame)
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", PUI_Dropdown_Toggle)
  button:SetScript("OnEnter", PUI_Dropdown_OnEnter)
  button:SetScript("OnLeave", PUI_Dropdown_OnLeave)

  local text = button:CreateFontString(nil, "OVERLAY")
  text.__puiOptionsFontOwned = true
  text:SetJustifyH("RIGHT")
  text:SetJustifyV("MIDDLE")
  Theme.ApplyFont(text, "body")

  local arrow = button:CreateTexture(nil, "ARTWORK")
  arrow:SetTexture(ARROW_TEXTURE)

  local widget = {
    type = PUI_DROPDOWN_TYPE,
    frame = frame,
    label = label,
    button = button,
    text = text,
    arrow = arrow,
    chrome = PUI_Dropdown_CreateChrome(button),
    alignoffset = 0,
  }

  for method, func in pairs(PUI_Dropdown_Methods) do
    widget[method] = func
  end

  frame.obj = widget
  button.obj = widget

  PUI_Dropdown_Layout(widget, 200)
  PUI_Dropdown_RefreshVisualState(widget)

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(PUI_DROPDOWN_TYPE, PUI_Dropdown_Constructor, PUI_DROPDOWN_VERSION)
