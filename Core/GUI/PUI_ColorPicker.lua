local ADDON_NAME, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel
local WidgetSkins = Theme.WidgetSkins

local ColorControls = {}
ns.ColorControls = ColorControls

local session, palette, copiedColor
local COLOR_LIMIT = 8

local function SameColor(first, second)
  for index = 1, 4 do
    if math.abs(first[index] - second[index]) > 0.00001 then return false end
  end
  return true
end

local function GetPaletteDB()
  local options = ns.Addon:GetGlobalOptionsDB()
  options.colorPalette = options.colorPalette or { recent = {}, favorites = {} }
  return options.colorPalette
end

local function CurrentColor()
  local r, g, b = ColorPickerFrame:GetColorRGB()
  return { r, g, b, session.widget.HasAlpha and ColorPickerFrame:GetColorAlpha() or 1 }
end

local function ColorDescription(color)
  local r, g, b = math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5)
  return string.format("#%02X%02X%02X  RGB %d, %d, %d\nOpacity: %.0f%%", r, g, b, r, g, b, color[4] * 100)
end

function ColorControls.AppendTooltip(widget, tooltip)
  local colors = Theme.GetColors()
  tooltip:AddLine(ColorDescription({ widget.r, widget.g, widget.b, widget.HasAlpha and widget.a or 1 }),
    colors.text[1], colors.text[2], colors.text[3], true)
end

local function HideColorTooltip(widget)
  local tooltip = widget.__puiColorTooltip
  if tooltip and tooltip:GetOwner() == widget.frame then tooltip:Hide() end
  widget.__puiColorTooltip = nil
end

local function ShowColorTooltip(widget)
  local tooltip = LibStub("AceConfigDialog-3.0").tooltip
  if not tooltip:IsShown() or tooltip:GetOwner() ~= widget.frame then
    tooltip = GameTooltip
    if not tooltip:IsShown() or tooltip:GetOwner() ~= widget.frame then
      tooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
      tooltip:SetText(widget.text:GetText() or "")
    end
  end
  ColorControls.AppendTooltip(widget, tooltip)
  tooltip:Show()
  widget.__puiColorTooltip = tooltip
end

local function RefreshColorState(widget)
  local chrome = widget.frame.__puiColorSwatchBg
  local background, border, text = Theme.GetControlStateColors(widget.disabled == true,
    widget.__puiColorHovered == true, false, widget.__puiColorOpen == true)
  chrome:SetBackdropColor(unpack(background))
  chrome:SetBackdropBorderColor(unpack(border))
  widget.text:SetTextColor(unpack(text))
end

local function RememberColor(color)
  local recent = GetPaletteDB().recent
  for index = #recent, 1, -1 do
    if SameColor(recent[index], color) then table.remove(recent, index) end
  end
  table.insert(recent, 1, color)
  if #recent > COLOR_LIMIT then table.remove(recent) end
end

local function ApplyPaletteColor(color)
  if not session or session.widget.disabled then return end
  local picker = ColorPickerFrame.Content.ColorPicker
  if session.widget.HasAlpha then picker:SetColorAlpha(color[4]) end
  picker:SetColorRGB(color[1], color[2], color[3])
end

local function RefreshFavoriteState()
  local favorites, current = GetPaletteDB().favorites, CurrentColor()
  local isFavorite = false
  for _, color in ipairs(favorites) do if SameColor(color, current) then isFavorite = true; break end end
  local text = isFavorite and "Remove favorite" or "Save favorite"
  local enabled = isFavorite or #favorites < COLOR_LIMIT
  if palette.favorite:GetText() ~= text then palette.favorite:SetText(text) end
  if palette.favorite:IsEnabled() ~= enabled then palette.favorite:SetEnabled(enabled) end
end

local function RefreshPalette()
  local db = GetPaletteDB()
  local height = math.max(24, Theme.GetOptionsFontHeight("body") + 10)
  local width = math.max(320, height * COLOR_LIMIT + 36)
  palette:SetSize(width, height * 7 + 24)
  local colors = Theme.GetColors()
  palette:SetBackdropColor(unpack(colors.background))
  palette:SetBackdropBorderColor(unpack(colors.controlBorder))
  for index, button in ipairs(palette.actions) do
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", palette, "TOPLEFT", 12 + (index - 1) * (width - 24) / 2, -12)
    button:SetSize((width - 28) / 2, height)
    Theme.WidgetSkins.UIButton(button)
  end
  palette.paste:SetEnabled(copiedColor ~= nil)
  palette.favorite:ClearAllPoints()
  palette.favorite:SetPoint("TOPLEFT", palette, "TOPLEFT", 12, -12 - height)
  palette.favorite:SetSize(width - 24, height)
  Theme.WidgetSkins.UIButton(palette.favorite)
  RefreshFavoriteState()
  for row, key in ipairs({ "recent", "favorites" }) do
    local title = palette[key .. "Title"]
    Theme.ApplyFont(title, "body")
    title:SetTextColor(unpack(colors.text))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", palette, "TOPLEFT", 12, -12 - height * (row * 2))
    title:SetText(key == "recent" and (#db.recent == 0 and "Recent colors — none yet" or "Recent colors")
      or (#db.favorites == 0 and "Favorites — save up to 8 colors" or "Favorites"))
    for index, button in ipairs(palette[key]) do
      local color = db[key][index]
      button.color = color
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", palette, "TOPLEFT", 12 + (index - 1) * (width - 24) / COLOR_LIMIT,
        -12 - height * (row * 2 + 1))
      button:SetSize((width - 24) / COLOR_LIMIT - 4, height - 4)
      button:SetShown(color ~= nil)
      Theme.WidgetSkins.UIButton(button)
      button.checkers:SetTexture(188523)
      button.checkers:SetAlpha(1)
      button.checkers:Show()
      if color then button.swatch:SetColorTexture(unpack(color)) end
      button.swatch:SetAlpha(1)
      button.swatch:Show()
    end
  end
end

local function EnsurePalette()
  if palette then return end
  palette = CreateFrame("Frame", nil, ColorPickerFrame, "BackdropTemplate")
  palette:EnableMouse(true)
  palette:SetClampedToScreen(true)
  palette:SetPoint("TOPLEFT", ColorPickerFrame, "TOPRIGHT", 8, 0)
  palette:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = Theme.ControlBorderSize })
  palette.actions = {}
  for index, text in ipairs({ "Copy color", "Paste color" }) do
    local button = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    button:SetText(text)
    palette.actions[index] = button
  end
  palette.paste = palette.actions[2]
  palette.actions[1]:SetScript("OnClick", function() copiedColor = CurrentColor(); RefreshPalette() end)
  palette.paste:SetScript("OnClick", function() ApplyPaletteColor(copiedColor); RefreshPalette() end)
  palette.favorite = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
  palette.favorite:SetScript("OnClick", function()
    local favorites, color = GetPaletteDB().favorites, CurrentColor()
    for index, favorite in ipairs(favorites) do
      if SameColor(favorite, color) then table.remove(favorites, index); RefreshPalette(); return end
    end
    if #favorites < COLOR_LIMIT then favorites[#favorites + 1] = color end
    RefreshPalette()
  end)
  for _, key in ipairs({ "recent", "favorites" }) do
    palette[key .. "Title"] = palette:CreateFontString(nil, "OVERLAY")
    palette[key] = {}
    for index = 1, COLOR_LIMIT do
      local button = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
      local checkers = button:CreateTexture(nil, "BACKGROUND")
      button.checkers = checkers
      checkers:SetAllPoints()
      checkers:SetTexture(188523)
      button.swatch = button:CreateTexture(nil, "ARTWORK")
      button.swatch:SetPoint("TOPLEFT", 2, -2)
      button.swatch:SetPoint("BOTTOMRIGHT", -2, 2)
      button:SetScript("OnClick", function(self) ApplyPaletteColor(self.color); RefreshPalette() end)
      button:SetScript("OnEnter", function(self)
        palette.tooltipOwner = self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ColorDescription(self.color))
        GameTooltip:Show()
      end)
      button:SetScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
      end)
      palette[key][index] = button
    end
  end
  palette:HookScript("OnHide", function()
    if palette.tooltipOwner and GameTooltip:GetOwner() == palette.tooltipOwner then GameTooltip:Hide() end
    palette.tooltipOwner = nil
  end)
  palette:Hide()
end

local function FinishColorSession()
  local finished = session
  if not finished then return end
  session = nil
  palette:Hide()
  local widget = finished.widget
  widget.__puiColorOpen = nil
  if widget.__puiAceGUIOwnedByPleebUI then
    RefreshColorState(widget)
    if not finished.cancelled then
      RememberColor({ widget.r, widget.g, widget.b, widget.HasAlpha and widget.a or 1 })
      widget:Fire("OnValueConfirmed", widget.r, widget.g, widget.b, widget.HasAlpha and widget.a or 1)
    end
  end
end

function ColorControls.Release(widget)
  HideColorTooltip(widget)
  if session and session.widget == widget then
    local active = session
    active.cancelled = true
    FinishColorSession()
    active.cancel()
    if ColorPickerFrame.swatchFunc == active.swatch then ColorPickerFrame:Hide() end
  end
  widget.__puiColorHovered, widget.__puiColorOpen = nil, nil
end

local function OpenColorSession(widget)
  if widget.disabled or not ColorPickerFrame:IsShown() then return end
  EnsurePalette()
  local active = { widget = widget, cancel = ColorPickerFrame.cancelFunc, swatch = ColorPickerFrame.swatchFunc }
  session = active
  ColorPickerFrame.cancelFunc = function(...)
    active.cancelled = true
    return active.cancel(...)
  end
  widget.__puiColorOpen = true
  RefreshColorState(widget)
  RefreshPalette()
  palette:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 10)
  palette:Show()
  if not palette.pickerHooked then
    palette.pickerHooked = true
    ColorPickerFrame:HookScript("OnHide", FinishColorSession)
    ColorPickerFrame.Content.ColorPicker:HookScript("OnColorSelect", function()
      if session then RefreshFavoriteState() end
    end)
    hooksecurefunc(ColorPickerFrame, "SetupColorPickerAndShow", function()
      if session and ColorPickerFrame.swatchFunc ~= session.swatch then
        local active = session
        active.cancelled = true
        FinishColorSession()
        active.cancel()
      end
    end)
  end
end

local function InstallColorControl(widget)
  if widget.__puiColorControlHooked then return end
  widget.__puiColorControlHooked = true
  widget.frame:HookScript("OnEnter", function()
    if not widget.__puiAceGUIOwnedByPleebUI then return end
    widget.__puiColorHovered = true
    RefreshColorState(widget)
    ShowColorTooltip(widget)
  end)
  widget.frame:HookScript("OnLeave", function()
    if not widget.__puiAceGUIOwnedByPleebUI then return end
    widget.__puiColorHovered = nil
    RefreshColorState(widget)
    HideColorTooltip(widget)
  end)
  widget.frame:HookScript("OnClick", function()
    if widget.__puiAceGUIOwnedByPleebUI then OpenColorSession(widget) end
  end)
  widget.frame:HookScript("OnHide", function()
    if widget.__puiAceGUIOwnedByPleebUI then ColorControls.Release(widget) end
  end)
  hooksecurefunc(widget, "SetDisabled", function(self)
    if not self.__puiAceGUIOwnedByPleebUI then return end
    if self.disabled then ColorControls.Release(self) end
    RefreshColorState(self)
  end)
end

function WidgetSkins.ColorPicker(widget)
  local frame = widget.frame
  local swatch = widget.colorSwatch
  local background = swatch.background
  local checkers = swatch.checkers
  local label = widget.text
  local geom = Theme.GetWidgetRowGeometry(widget)
  local controlSize = geom.controlHeight
  local controlLeft = geom.controlLeft
  local controlRight = geom.controlRight
  local controlYOffset = geom.controlYOffset
  local controlGap = geom.controlGap
  local edge = Theme.ControlBorderSize

  local swatchBG = frame.__puiColorSwatchBg
  if not swatchBG then
    swatchBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    swatchBG:EnableMouse(false)
    Theme.MarkCreatedWidgetChrome(swatchBG)
    frame.__puiColorSwatchBg = swatchBG
  end

  swatchBG:ClearAllPoints()
  Pixel.Point(swatchBG, "LEFT", frame, "LEFT", controlLeft, controlYOffset)
  Pixel.Size(swatchBG, controlSize, controlSize)
  swatchBG:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edge,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  swatchBG:Show()

  background:Hide()

  checkers:ClearAllPoints()
  checkers:SetParent(swatchBG)
  Pixel.Point(checkers, "TOPLEFT", swatchBG, "TOPLEFT", 1, -1)
  Pixel.Point(checkers, "BOTTOMRIGHT", swatchBG, "BOTTOMRIGHT", -1, 1)
  checkers:SetDrawLayer("BACKGROUND")
  checkers:Show()

  Pixel.SetTexture(swatch, "Interface\\Buttons\\WHITE8x8")
  swatch:ClearAllPoints()
  swatch:SetParent(swatchBG)
  Pixel.Point(swatch, "TOPLEFT", swatchBG, "TOPLEFT", 1, -1)
  Pixel.Point(swatch, "BOTTOMRIGHT", swatchBG, "BOTTOMRIGHT", -1, 1)
  Pixel.SetTexCoord(swatch, 0, 1, 0, 1)
  swatch:SetDrawLayer("ARTWORK")
  swatch:Show()

  Theme.ApplyFont(label, "body")
  label:ClearAllPoints()
  Pixel.Point(label, "LEFT", swatchBG, "RIGHT", controlGap, 0)
  Pixel.Point(label, "RIGHT", frame, "RIGHT", -controlRight, 0)
  Pixel.Height(label, controlSize)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("MIDDLE")
  InstallColorControl(widget)
  RefreshColorState(widget)
  if session and session.widget == widget then RefreshPalette() end
end
