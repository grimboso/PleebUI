local ADDON_NAME, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel
local WidgetSkins = Theme.WidgetSkins

function WidgetSkins.ColorPicker(widget)
  local frame = widget.frame
  local swatch = widget.colorSwatch
  local background = swatch.background
  local checkers = swatch.checkers
  local label = widget.text
  local colors = Theme.GetColors()
  local geom = Theme.GetWidgetRowGeometry(widget)
  local controlSize = geom.controlHeight
  local controlLeft = geom.controlLeft
  local controlRight = geom.controlRight
  local controlYOffset = geom.controlYOffset
  local controlGap = geom.controlGap
  local edge = math.max(Theme.GetEdgeSize(), 2)

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
  swatchBG:SetBackdropColor(colors.background[1], colors.background[2], colors.background[3], colors.background[4])
  swatchBG:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4])
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

  local textColor = colors.text
  Theme.ApplyFont(label, "body")
  label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  label:ClearAllPoints()
  Pixel.Point(label, "LEFT", swatchBG, "RIGHT", controlGap, 0)
  Pixel.Point(label, "RIGHT", frame, "RIGHT", -controlRight, 0)
  Pixel.Height(label, controlSize)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("MIDDLE")
end
