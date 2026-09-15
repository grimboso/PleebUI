local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local Pixel = ns.Pixel
local WidgetSkins = Theme.WidgetSkins
local AceGUI = LibStub("AceGUI-3.0")

local _PUI_StyleCustomTabButton
local _PUI_UpdateTabGroupSelection

local function _PUI_GetSelectedTabValue(widget)
  return (widget.status or widget.localstatus).selected
end

local function _PUI_SetNativeTabTextureAlpha(tab, alpha)
  for _, texture in ipairs({
    tab.LeftDisabled,
    tab.MiddleDisabled,
    tab.RightDisabled,
    tab.Left,
    tab.Middle,
    tab.Right,
    tab.HighlightTexture,
  }) do
    if texture then
      texture:SetAlpha(alpha)
    end
  end
end

local function _PUI_HideNativeTab(tab)
  tab.__puiNativeTabHidden = true
  _PUI_SetNativeTabTextureAlpha(tab, 0)
  tab:SetAlpha(0)
  tab:EnableMouse(false)
  Pixel.Size(tab, 1, 1)
  tab:Hide()
end

local function _PUI_EnsureCustomTabHost(widget)
  local host = widget.__puiCustomTabHost
  if host then
    return host
  end

  host = CreateFrame("Frame", nil, widget.frame, "BackdropTemplate")
  Theme.MarkCreatedWidgetChrome(host)
  host.__puiButtons = {}
  host.__puiWidget = widget
  host:EnableMouse(false)

  widget.__puiCustomTabHost = host
  return host
end

local function _PUI_EnsureCustomTabButton(host, index)
  local btn = host.__puiButtons[index]
  if btn then
    return btn
  end

  btn = CreateFrame("Button", nil, host, "BackdropTemplate")
  btn.__puiTabStripOwned = true
  btn.__puiUseTextureBackdrop = true
  Pixel.Height(btn, 30)
  btn:EnableMouse(true)

  btn.__puiHover = btn:CreateTexture(nil, "BORDER")
  Pixel.AllPoints(btn.__puiHover, btn)
  Pixel.SetTexture(btn.__puiHover, "Interface\\Buttons\\WHITE8x8")
  btn.__puiHover:SetAlpha(0)

  btn.__puiAccent = btn:CreateTexture(nil, "ARTWORK")
  Pixel.Point(btn.__puiAccent, "BOTTOMLEFT", btn, "BOTTOMLEFT", 7, 0)
  Pixel.Point(btn.__puiAccent, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", -7, 0)
  Pixel.Height(btn.__puiAccent, 2)
  Pixel.SetTexture(btn.__puiAccent, "Interface\\Buttons\\WHITE8x8")

  btn.__puiLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.__puiLabel.__puiOptionsFontOwned = true
  Pixel.Point(btn.__puiLabel, "LEFT", btn, "LEFT", 12, 0)
  Pixel.Point(btn.__puiLabel, "RIGHT", btn, "RIGHT", -12, 0)
  btn.__puiLabel:SetJustifyH("CENTER")
  btn.__puiLabel:SetJustifyV("MIDDLE")
  btn.__puiLabel:SetWordWrap(false)
  Theme.ApplyFont(btn.__puiLabel, "tab", 12)

  btn:SetScript("OnEnter", function(self)
    self.__puiHovered = true
    _PUI_StyleCustomTabButton(self, self.__puiValue == _PUI_GetSelectedTabValue(self.__puiWidget))
  end)

  btn:SetScript("OnLeave", function(self)
    self.__puiHovered = false
    _PUI_StyleCustomTabButton(self, self.__puiValue == _PUI_GetSelectedTabValue(self.__puiWidget))
  end)

  btn:SetScript("OnClick", function(self)
    if self.__puiDisabled then
      return
    end

    local owner = self.__puiWidget
    local value = self.__puiValue

    if value == _PUI_GetSelectedTabValue(owner)
      or not Addon:HandleOptionsGroupSelection(owner, value)
    then
      return
    end

    owner:SelectTab(value)
    _PUI_UpdateTabGroupSelection(owner)
  end)

  host.__puiButtons[index] = btn
  return btn
end

_PUI_StyleCustomTabButton = function(btn, isSelected)
  local colors = Theme.GetColors()
  local hovered = btn.__puiHovered == true
  local bg = colors.control
  local bgAlpha = isSelected and 0.94 or 0.62
  local borderAlpha = isSelected and 0.90 or 0.36
  local border = (isSelected or hovered) and colors.accent or colors.border

  if hovered and not isSelected then
    bgAlpha = 0.76
    borderAlpha = 0.70
  elseif hovered then
    bgAlpha = 1
    borderAlpha = 1
  end

  Theme.SetSquareBackdrop(btn, {
    bg = { bg[1], bg[2], bg[3], bgAlpha },
    border = { border[1], border[2], border[3], borderAlpha },
  }, math.max(Theme.GetEdgeSize(), 1))

  btn.__puiHover:SetVertexColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    hovered and 0.10 or 0
  )
  btn.__puiHover:SetShown(hovered)

  btn.__puiAccent:SetVertexColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    isSelected and 1 or 0
  )
  btn.__puiAccent:SetShown(isSelected)

  btn.__puiLabel:SetTextColor(
    colors.text[1],
    colors.text[2],
    colors.text[3],
    isSelected and 1 or 0.66
  )
end

_PUI_UpdateTabGroupSelection = function(widget)
  local host = widget.__puiCustomTabHost
  local tablist = widget.tablist or widget.tabs

  if not host or type(tablist) ~= "table" then
    return
  end

  local selectedValue = _PUI_GetSelectedTabValue(widget)

  for i = 1, #tablist do
    local btn = host.__puiButtons[i]
    if btn then
      _PUI_StyleCustomTabButton(btn, btn.__puiValue == selectedValue)
    end
  end
end

local function _PUI_LayoutCustomTabStrip(widget)
  if widget.__puiAceGUIOwnedByPleebUI ~= true
    or AceGUI:IsReleasing(widget)
    or widget.__puiTabLayoutInProgress
  then
    return
  end

  widget.__puiTabLayoutInProgress = true

  local host = _PUI_EnsureCustomTabHost(widget)
  local tablist = widget.tablist

  if not tablist or #tablist == 0 then
    host:Hide()
    widget.__puiTabLayoutInProgress = nil
    return
  end

  local tabs = widget.tabs
  local tabHeight = 30
  local gap = 6
  local available = tonumber(widget.frame:GetWidth()) or 0

  if available <= 1 then
    available = tonumber(widget.frame.width) or 0
  end

  if available <= 1 then
    host:Hide()
    widget.__puiTabLayoutInProgress = nil
    return
  end

  available = math.floor(available + 0.5)
  widget.__puiLastTabLayoutWidth = available

  host:SetParent(widget.frame)
  host:SetFrameStrata(widget.frame:GetFrameStrata())
  host:SetFrameLevel(widget.frame:GetFrameLevel() + 20)
  host:ClearAllPoints()
  Pixel.Point(host, "TOPLEFT", widget.frame, "TOPLEFT", 0, -2)
  Pixel.Point(host, "TOPRIGHT", widget.frame, "TOPRIGHT", 0, -2)

  local desiredWidths = {}
  local totalDesiredWidth = 0

  for i = 1, #tablist do
    local entry = tablist[i]
    local tab = tabs[i]

    Theme.CaptureCreatedWidgetFrameTree(widget, tab)
    _PUI_HideNativeTab(tab)

    local btn = _PUI_EnsureCustomTabButton(host, i)
    btn.__puiWidget = widget
    btn.__puiNativeTab = tab
    btn.__puiValue = entry.value
    btn.__puiDisabled = entry.disabled == true
    btn.__puiLabel:SetText(entry.text)

    local desiredWidth = math.ceil(btn.__puiLabel:GetUnboundedStringWidth() + 24)
    desiredWidths[i] = desiredWidth
    totalDesiredWidth = totalDesiredWidth + desiredWidth
  end

  local tabCount = #tablist
  local usableWidth = math.max(tabCount, available - ((tabCount - 1) * gap))
  local extraWidth = usableWidth - totalDesiredWidth
  local extraPerTab = extraWidth > 0 and math.floor(extraWidth / tabCount) or 0
  local extraRemainder = extraWidth > 0 and (extraWidth - (extraPerTab * tabCount)) or 0
  local assignedWidth = 0
  local x = 0

  for i = 1, tabCount do
    local btn = host.__puiButtons[i]
    local tabWidth

    if i == tabCount then
      tabWidth = usableWidth - assignedWidth
    elseif extraWidth >= 0 then
      tabWidth = desiredWidths[i] + extraPerTab + (i <= extraRemainder and 1 or 0)
    else
      tabWidth = math.max(1, math.floor((usableWidth * desiredWidths[i]) / totalDesiredWidth))
    end

    assignedWidth = assignedWidth + tabWidth

    btn:SetParent(host)
    btn:SetFrameStrata(host:GetFrameStrata())
    btn:SetFrameLevel(host:GetFrameLevel() + 1)
    Pixel.Size(btn, tabWidth, tabHeight)
    btn:ClearAllPoints()
    Pixel.Point(btn, "TOPLEFT", host, "TOPLEFT", x, 0)
    btn:SetAlpha(btn.__puiDisabled and 0.45 or 1)
    btn:EnableMouse(not btn.__puiDisabled)
    btn:Show()

    x = x + tabWidth + gap
  end

  for i = tabCount + 1, #host.__puiButtons do
    local btn = host.__puiButtons[i]
    btn:Hide()
    btn:ClearAllPoints()
    btn.__puiNativeTab = nil
    btn.__puiValue = nil
    btn.__puiWidget = nil
    btn.__puiDisabled = nil
  end

  local hostHeight = tabHeight + 4
  Pixel.Height(host, hostHeight)
  host:Show()

  widget.borderoffset = hostHeight + 8
  widget.border:SetBackdrop(nil)
  widget.border:SetBackdropColor(0, 0, 0, 0)
  widget.border:SetBackdropBorderColor(0, 0, 0, 0)
  widget.border:ClearAllPoints()
  Pixel.Point(widget.border, "TOPLEFT", widget.frame, "TOPLEFT", 0, -widget.borderoffset)
  Pixel.Point(widget.border, "BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 0, 0)

  _PUI_UpdateTabGroupSelection(widget)
  widget.__puiTabLayoutInProgress = nil
end

function WidgetSkins.TabGroup(widget, forceLayout)
  if widget.__puiAceGUIOwnedByPleebUI ~= true or AceGUI:IsReleasing(widget) then
    return
  end

  if not widget.__puiTabLayoutHooksInstalled then
    widget.__puiTabLayoutHooksInstalled = true

    hooksecurefunc(widget, "BuildTabs", function(self)
      if not self.__puiTabLayoutInProgress then
        _PUI_LayoutCustomTabStrip(self)
      end
    end)

    widget.frame:HookScript("OnSizeChanged", function(_, width)
      if widget.__puiAceGUIOwnedByPleebUI ~= true
        or AceGUI:IsReleasing(widget)
        or widget.__puiTabLayoutInProgress
      then
        return
      end

      local roundedWidth = math.floor((tonumber(width) or 0) + 0.5)
      if widget.__puiLastTabLayoutWidth == roundedWidth then
        return
      end

      widget.__puiLastTabLayoutWidth = roundedWidth
      _PUI_LayoutCustomTabStrip(widget)
    end)
  end

  widget.border:SetBackdrop(nil)
  widget.border:SetBackdropColor(0, 0, 0, 0)
  widget.border:SetBackdropBorderColor(0, 0, 0, 0)

  if forceLayout or not widget.__puiTabChromeHooked then
    widget.__puiTabChromeHooked = true
    _PUI_LayoutCustomTabStrip(widget)
    return
  end

  _PUI_UpdateTabGroupSelection(widget)
  widget.__puiTabLayoutInProgress = nil
end
