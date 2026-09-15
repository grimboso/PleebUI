local _, ns = ...

ns.PreviewBox = {}
local PreviewBox = ns.PreviewBox

local _G = _G
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local GameTooltip = _G.GameTooltip
local GetCursorPosition = _G.GetCursorPosition
local ResetCursor = _G.ResetCursor
local SetCursor = _G.SetCursor
local UIParent = _G.UIParent
local ipairs = _G.ipairs
local math_abs = _G.math.abs
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local Theme = ns.Theme
local Pixel = ns.Pixel

local function PUI_PreviewBox_ApplyBackdrop(frame, bgColor, borderColor, edge)
  Theme.SetSquareBackdrop(frame, {
    bg = bgColor,
    border = borderColor,
  }, edge)
end

local function PUI_PreviewBox_ResolveInteractionValue(value, button)
  if type(value) == "function" then
    return value(button)
  end

  return value
end

local function PUI_PreviewBox_SetInteractionHighlight(button, shown)
  button.__puiPreviewInteractionFill:SetShown(shown)

  for index = 1, 4 do
    button.__puiPreviewInteractionEdges[index]:SetShown(shown)
  end
end

local function PUI_PreviewBox_ShowInteractionTooltip(button)
  local options = button.__puiPreviewInteractionOptions or {}
  local title = PUI_PreviewBox_ResolveInteractionValue(options.title, button)
  local description = PUI_PreviewBox_ResolveInteractionValue(options.description, button)

  if not title or title == "" then
    return
  end

  GameTooltip:SetOwner(button, options.tooltipAnchor or "ANCHOR_RIGHT")
  GameTooltip:SetText(title, 1, 1, 1)

  if description and description ~= "" then
    GameTooltip:AddLine(description, 0.82, 0.82, 0.82, true)
  end

  GameTooltip:Show()
end

local function PUI_PreviewBox_HideInteractionTooltip(button)
  if GameTooltip:IsOwned(button) then
    GameTooltip:Hide()
  end
end

function PreviewBox.CreateInteraction(parent, anchor, options)
  options = options or {}

  local colors = Theme.GetColors()
  local hoverColor = options.hoverColor or colors.accent
  local button = CreateFrame("Button", nil, parent)
  local fill = button:CreateTexture(nil, "OVERLAY", nil, 6)
  local edges = {}

  Pixel.AllPoints(button, anchor or parent)
  button:SetFrameLevel(options.frameLevel or (parent:GetFrameLevel() + 20))
  button:RegisterForClicks("LeftButtonUp")

  Pixel.AllPoints(fill, button)
  Pixel.SetColorTexture(fill,
    hoverColor[1] or 1,
    hoverColor[2] or 1,
    hoverColor[3] or 1,
    options.hoverAlpha or 0.10
  )
  fill:Hide()

  for index = 1, 4 do
    local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
    Pixel.SetColorTexture(edge,
      hoverColor[1] or 1,
      hoverColor[2] or 1,
      hoverColor[3] or 1,
      hoverColor[4] or 1
    )
    edge:Hide()
    edges[index] = edge
  end

  local thickness = options.highlightThickness or 2

  Pixel.Point(edges[1], "TOPLEFT", button, "TOPLEFT", 0, 0)
  Pixel.Point(edges[1], "TOPRIGHT", button, "TOPRIGHT", 0, 0)
  Pixel.Height(edges[1], thickness)

  Pixel.Point(edges[2], "BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  Pixel.Point(edges[2], "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  Pixel.Height(edges[2], thickness)

  Pixel.Point(edges[3], "TOPLEFT", edges[1], "BOTTOMLEFT", 0, 0)
  Pixel.Point(edges[3], "BOTTOMLEFT", edges[2], "TOPLEFT", 0, 0)
  Pixel.Width(edges[3], thickness)

  Pixel.Point(edges[4], "TOPRIGHT", edges[1], "BOTTOMRIGHT", 0, 0)
  Pixel.Point(edges[4], "BOTTOMRIGHT", edges[2], "TOPRIGHT", 0, 0)
  Pixel.Width(edges[4], thickness)

  button.__puiPreviewInteractionFill = fill
  button.__puiPreviewInteractionEdges = edges

  function button:SetPreviewInteractionOptions(nextOptions)
    self.__puiPreviewInteractionOptions = nextOptions or {}

    if self.__puiPreviewInteractionOptions.draggable == true then
      self:RegisterForDrag("LeftButton")
    else
      self:RegisterForDrag()
    end
  end

  button:SetScript("OnEnter", function(self)
    local interaction = self.__puiPreviewInteractionOptions or {}

    self.__puiPreviewInteractionHovered = true
    PUI_PreviewBox_SetInteractionHighlight(self, true)

    SetCursor("INTERACT_CURSOR")

    if type(interaction.onEnter) == "function" then
      interaction.onEnter(self)
    end

    PUI_PreviewBox_ShowInteractionTooltip(self)
  end)

  button:SetScript("OnLeave", function(self)
    local interaction = self.__puiPreviewInteractionOptions or {}

    self.__puiPreviewInteractionHovered = nil
    PUI_PreviewBox_SetInteractionHighlight(self, false)

    ResetCursor()

    if type(interaction.onLeave) == "function" then
      interaction.onLeave(self)
    end

    PUI_PreviewBox_HideInteractionTooltip(self)
  end)

  button:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end

    local cursorX, cursorY = GetCursorPosition()

    self.__puiPreviewInteractionMouseX = cursorX
    self.__puiPreviewInteractionMouseY = cursorY
    self.__puiPreviewInteractionDragged = nil
  end)

  button:SetScript("OnMouseUp", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end

    local startX = self.__puiPreviewInteractionMouseX
    local startY = self.__puiPreviewInteractionMouseY

    self.__puiPreviewInteractionMouseX = nil
    self.__puiPreviewInteractionMouseY = nil

    if not startX or not startY then
      return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local deltaX = math_abs((cursorX - startX) / scale)
    local deltaY = math_abs((cursorY - startY) / scale)

    if deltaX > 4 or deltaY > 4 then
      self.__puiPreviewInteractionDragged = true
    end
  end)

  button:SetScript("OnDragStart", function(self)
    local interaction = self.__puiPreviewInteractionOptions or {}

    self.__puiPreviewInteractionDragged = true

    if type(interaction.onDragStart) == "function" then
      interaction.onDragStart(self)
    end
  end)

  button:SetScript("OnDragStop", function(self)
    local interaction = self.__puiPreviewInteractionOptions or {}

    if type(interaction.onDragStop) == "function" then
      interaction.onDragStop(self)
    end
  end)

  button:SetScript("OnClick", function(self, mouseButton)
    local interaction = self.__puiPreviewInteractionOptions or {}

    if self.__puiPreviewInteractionDragged then
      self.__puiPreviewInteractionDragged = nil
      return
    end

    if type(interaction.onClick) == "function" then
      interaction.onClick(self, mouseButton)
    end
  end)

  button:SetScript("OnHide", function(self)
    if not self.__puiPreviewInteractionHovered then
      return
    end

    self.__puiPreviewInteractionHovered = nil
    PUI_PreviewBox_SetInteractionHighlight(self, false)

    ResetCursor()

    PUI_PreviewBox_HideInteractionTooltip(self)
  end)

  button:SetPreviewInteractionOptions(options)
  return button
end

function PreviewBox.CreateZoomControl(parent, options)
  options = options or {}

  local colors = Theme.GetColors()
  local control = CreateFrame("Frame", nil, parent)
  local slider = CreateFrame("Slider", nil, control)
  local label = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local valueText = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local sliderWidth = tonumber(options.sliderWidth) or 110
  local sliderHeight = tonumber(options.sliderHeight) or 14
  local gap = tonumber(options.gap) or 8
  local minimum = tonumber(options.minimum) or 25
  local maximum = tonumber(options.maximum) or 200
  local step = tonumber(options.step) or 5

  Pixel.Size(control,
    tonumber(options.width) or (sliderWidth + 92),
    tonumber(options.height) or sliderHeight
  )
  control:SetFrameLevel(
    tonumber(options.frameLevel) or (parent:GetFrameLevel() + 20)
  )

  Pixel.Point(slider, "CENTER", control, "CENTER", tonumber(options.sliderOffsetX) or 0, 0)
  Pixel.Size(slider, sliderWidth, sliderHeight)
  slider:SetOrientation("HORIZONTAL")
  slider:SetHitRectInsets(0, 0, -8, -8)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  local track = slider:CreateTexture(nil, "ARTWORK")
  Pixel.Point(track, "LEFT", slider, "LEFT", 0, 0)
  Pixel.Point(track, "RIGHT", slider, "RIGHT", 0, 0)
  Pixel.Height(track, 4)
  Pixel.SetColorTexture(track,
    colors.border[1],
    colors.border[2],
    colors.border[3],
    colors.border[4]
  )

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  Pixel.Size(thumb, 10, sliderHeight)
  Pixel.SetColorTexture(thumb,
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    colors.accent[4]
  )
  slider:SetThumbTexture(thumb)

  Pixel.Point(label, "RIGHT", slider, "LEFT", -gap, 0)
  label:SetJustifyH("RIGHT")
  Theme.ApplyFont(label, "tiny", tonumber(options.fontSize) or 9)
  label:SetText(options.label or "Zoom")
  label:SetShown(options.showLabel ~= false)

  Pixel.Point(valueText, "LEFT", slider, "RIGHT", gap, 0)
  valueText:SetJustifyH("LEFT")
  Theme.ApplyFont(valueText, "tiny", tonumber(options.fontSize) or 9)

  function control:SetZoom(zoom)
    local percent = math_floor(
      math_min(maximum, math_max(minimum, (tonumber(zoom) or 1) * 100))
      + 0.5
    )

    slider.__puiSyncingValue = true
    slider:SetValue(percent)
    slider.__puiSyncingValue = nil
    valueText:SetText(tostring(percent) .. "%")
  end

  function control:GetZoom()
    return (tonumber(slider:GetValue()) or 100) / 100
  end

  slider:SetScript("OnValueChanged", function(self, value)
    local percent = math_floor(value + 0.5)
    valueText:SetText(tostring(percent) .. "%")

    if self.__puiSyncingValue then
      return
    end

    if type(options.onValueChanged) == "function" then
      options.onValueChanged(control, percent / 100)
    end
  end)

  slider:SetScript("OnMouseUp", function(self, mouseButton)
    if mouseButton ~= "LeftButton" or self.__puiSyncingValue then
      return
    end

    if type(options.onValueCommitted) == "function" then
      local percent = math_floor((tonumber(self:GetValue()) or 100) + 0.5)
      options.onValueCommitted(control, percent / 100)
    end
  end)

  control.slider = slider
  control.label = label
  control.valueText = valueText
  control:SetZoom(options.value or 1)

  return control
end

local function PUI_PreviewBox_OptionsPathMatches(path, targetPath)
  if type(path) ~= "table" or type(targetPath) ~= "table" then
    return false
  end

  if #path < #targetPath then
    return false
  end

  for index = 1, #targetPath do
    if path[index] ~= targetPath[index] then
      return false
    end
  end

  return true
end

local function PUI_PreviewBox_OptionPathMatches(
  path,
  targetPath,
  sectionKey,
  optionKey
)
  if not PUI_PreviewBox_OptionsPathMatches(path, targetPath) then
    return false
  end

  if path[#path] == optionKey then
    return true
  end

  if sectionKey == nil then
    return false
  end

  for index = #targetPath + 1, #path - 1 do
    if path[index] == sectionKey and path[index + 1] == optionKey then
      return true
    end
  end

  return false
end

local function PUI_PreviewBox_FindOptionWidget(
  root,
  targetPath,
  sectionKey,
  optionKey
)
  local targetWidget
  local targetScroll

  local function Walk(widget, scrollWidget)
    if widget.type == "ScrollFrame" then
      scrollWidget = widget
    end

    if widget.GetUserDataTable then
      local user = widget:GetUserDataTable()

      if PUI_PreviewBox_OptionPathMatches(
        user.path,
        targetPath,
        sectionKey,
        optionKey
      ) then
        targetWidget = widget
        targetScroll = scrollWidget
        return true
      end
    end

    for _, child in ipairs(widget.children or {}) do
      if Walk(child, scrollWidget) then
        return true
      end
    end

    return false
  end

  Walk(root)
  return targetWidget, targetScroll
end

local function PUI_PreviewBox_ShowOptionGlow(targetFrame)
  local glow = PreviewBox.__puiOptionGlow

  if not glow then
    glow = CreateFrame("Frame", nil, UIParent)

    local function CreateEdge()
      local edge = glow:CreateTexture(nil, "OVERLAY")
      Pixel.SetColorTexture(edge, 1, 1, 1, 1)
      return edge
    end

    glow.top = CreateEdge()
    glow.bottom = CreateEdge()
    glow.left = CreateEdge()
    glow.right = CreateEdge()

    Pixel.Height(glow.top, 2)
    Pixel.Point(glow.top, "TOPLEFT")
    Pixel.Point(glow.top, "TOPRIGHT")
    Pixel.Height(glow.bottom, 2)
    Pixel.Point(glow.bottom, "BOTTOMLEFT")
    Pixel.Point(glow.bottom, "BOTTOMRIGHT")
    Pixel.Width(glow.left, 2)
    Pixel.Point(glow.left, "TOPLEFT", glow.top, "BOTTOMLEFT")
    Pixel.Point(glow.left, "BOTTOMLEFT", glow.bottom, "TOPLEFT")
    Pixel.Width(glow.right, 2)
    Pixel.Point(glow.right, "TOPRIGHT", glow.top, "BOTTOMRIGHT")
    Pixel.Point(glow.right, "BOTTOMRIGHT", glow.bottom, "TOPRIGHT")

    PreviewBox.__puiOptionGlow = glow
  end

  local color = Theme.GetColors().accent

  glow:SetParent(targetFrame)
  glow:ClearAllPoints()
  Pixel.AllPoints(glow, targetFrame)
  glow:SetFrameLevel(targetFrame:GetFrameLevel() + 20)
  Pixel.SetColorTexture(glow.top, color[1], color[2], color[3], 1)
  Pixel.SetColorTexture(glow.bottom, color[1], color[2], color[3], 1)
  Pixel.SetColorTexture(glow.left, color[1], color[2], color[3], 1)
  Pixel.SetColorTexture(glow.right, color[1], color[2], color[3], 1)
  glow.elapsed = 0
  glow:SetAlpha(1)
  glow:Show()
  glow:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed

    if self.elapsed >= 0.8 then
      self:Hide()
      self:SetScript("OnUpdate", nil)
      return
    end

    self:SetAlpha(1 - self.elapsed / 0.8)
  end)
end

function PreviewBox.FocusOption(path, sectionKey, optionKey)
  if type(path) ~= "table" or optionKey == nil then
    return
  end

  C_Timer.After(0, function()
    local optionsFrame = ns.Addon._OptionsWindow
    local shell = optionsFrame and optionsFrame.__puiPageShell
    local root = shell and shell.acdContainer

    if not root then
      return
    end

    local targetWidget, scrollWidget = PUI_PreviewBox_FindOptionWidget(
      root,
      path,
      sectionKey,
      optionKey
    )

    if not targetWidget then
      return
    end

    local targetFrame = targetWidget.frame

    if scrollWidget then
      scrollWidget:FixScroll()

      local contentTop = scrollWidget.content:GetTop()
      local targetTop = targetFrame:GetTop()
      local scrollRange = math_max(
        0,
        scrollWidget.content:GetHeight() - scrollWidget.scrollframe:GetHeight()
      )

      if contentTop and targetTop and scrollRange > 0 then
        local offset = math_min(
          scrollRange,
          math_max(0, contentTop - targetTop - 24)
        )

        scrollWidget.scrollbar:SetValue(offset / scrollRange * 1000)
      end
    end

    if targetFrame:IsShown() then
      PUI_PreviewBox_ShowOptionGlow(targetFrame)
    end
  end)
end

function PreviewBox.NavigateToOption(addon, path, sectionKey, optionKey)
  if not addon or type(path) ~= "table" then
    return
  end

  if not addon:NavigateOpenOptionsPath(path) then
    addon:OpenOptions(path, false, true)
  end
  PreviewBox.FocusOption(path, sectionKey, optionKey)
end

function PreviewBox.Create(parent)
  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()
  local box = CreateFrame("Frame", nil, parent)
  box:SetFrameLevel(parent:GetFrameLevel() + 1)

  box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  Pixel.Point(box.title, "TOPLEFT", box, "TOPLEFT", 14, -12)
  Pixel.Point(box.title, "TOPRIGHT", box, "TOPRIGHT", -14, -12)
  box.title:SetJustifyH("LEFT")
  box.title:SetJustifyV("MIDDLE")

  box.description = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  Pixel.Point(box.description, "TOPLEFT", box.title, "BOTTOMLEFT", 0, -4)
  Pixel.Point(box.description, "TOPRIGHT", box.title, "BOTTOMRIGHT", 0, -4)
  box.description:SetJustifyH("LEFT")
  box.description:SetJustifyV("TOP")
  box.description:SetWordWrap(true)

  box.canvas = CreateFrame("Frame", nil, box)
  box.canvas:SetFrameLevel(box:GetFrameLevel() + 1)
  Pixel.Point(box.canvas, "TOPLEFT", box.description, "BOTTOMLEFT", 0, -12)
  Pixel.Point(box.canvas, "TOPRIGHT", box, "TOPRIGHT", -14, 0)
  Pixel.Point(box.canvas, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -14, 14)

  PUI_PreviewBox_ApplyBackdrop(box, colors.background, colors.border, edge)
  PUI_PreviewBox_ApplyBackdrop(box.canvas, colors.background, colors.border, edge)

  Theme.ApplyFont(box.title, "header", 13)
  Theme.ApplyFont(box.description, "tiny", 10)

  function box:SetTitle(text)
    self.title:SetText(text or "")
    self.title:SetShown(text ~= nil and text ~= "")
  end

  function box:SetDescription(text)
    self.description:SetText(text or "")
    self.description:SetShown(text ~= nil and text ~= "")
  end

  function box:GetCanvas()
    return self.canvas
  end

  return box
end
