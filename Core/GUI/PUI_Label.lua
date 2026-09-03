local _, ns = ...

local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins
local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = _G.CreateFrame
local CreateFont = _G.CreateFont
local UIParent = _G.UIParent
local math_max = math.max
local select = _G.select

local PUI_LABEL_TYPE = "PUI_Label"
local PUI_LABEL_VERSION = 1
local PUI_HEADING_TYPE = "PUI_Heading"
local PUI_HEADING_VERSION = 1

function WidgetSkins.Label(widget)
  local text = widget.label
  local color = Theme.GetColors().text

  Theme.ApplyFont(text, "body")
  text:SetTextColor(color[1], color[2], color[3], color[4])
end

function WidgetSkins.Heading(widget)
  local text = widget.label
  local color = Theme.GetColors().text

  Theme.ApplyFont(text, "header")
  text:SetTextColor(color[1], color[2], color[3], color[4])
end

local function PUI_Label_UpdateLayout(widget)
  if widget.resizing then
    return
  end

  local frame = widget.frame
  local width = frame.width or frame:GetWidth() or 0
  local image = widget.image
  local label = widget.label
  local height

  label:ClearAllPoints()
  image:ClearAllPoints()

  if widget.imageshown then
    local imageWidth = image:GetWidth()

    if width - imageWidth < 200 or (label:GetText() or "") == "" then
      image:SetPoint("TOP")
      label:SetPoint("TOP", image, "BOTTOM")
      label:SetPoint("LEFT")
      label:SetWidth(width)
      height = image:GetHeight() + label:GetStringHeight()
    else
      image:SetPoint("TOPLEFT")

      if image:GetHeight() > label:GetStringHeight() then
        label:SetPoint("LEFT", image, "RIGHT", 4, 0)
      else
        label:SetPoint("TOPLEFT", image, "TOPRIGHT", 4, 0)
      end

      label:SetWidth(width - imageWidth - 4)
      height = math_max(image:GetHeight(), label:GetStringHeight())
    end
  else
    label:SetPoint("TOPLEFT")
    label:SetWidth(width)
    height = label:GetStringHeight()
  end

  if not height or height == 0 then
    height = 1
  end

  widget.resizing = true
  frame:SetHeight(height)
  frame.height = height
  widget.resizing = nil
end

local PUI_Label_Methods = {
  OnAcquire = function(self)
    self.resizing = true
    self:SetWidth(200)
    self:SetText(nil)
    self:SetImage(nil)
    self:SetImageSize(16, 16)
    self:SetColor(1, 1, 1)
    self:SetFontObject(nil)
    self:SetJustifyH("LEFT")
    self:SetJustifyV("TOP")
    self.resizing = nil
    PUI_Label_UpdateLayout(self)
  end,

  OnWidthSet = function(self)
    PUI_Label_UpdateLayout(self)
  end,

  SetText = function(self, text)
    self.label:SetText(text or "")
    PUI_Label_UpdateLayout(self)
  end,

  SetColor = function(self, r, g, b)
    self.label:SetVertexColor(r or 1, g or 1, b or 1)
  end,

  SetImage = function(self, path, ...)
    self.image:SetTexture(path)

    if self.image:GetTexture() then
      self.imageshown = true
      local count = select("#", ...)

      if count == 4 or count == 8 then
        self.image:SetTexCoord(...)
      else
        self.image:SetTexCoord(0, 1, 0, 1)
      end
    else
      self.imageshown = nil
    end

    PUI_Label_UpdateLayout(self)
  end,

  SetFont = function(self, font, height, flags)
    if not self.fontObject then
      self.fontObject = CreateFont("PUIAceGUILabelFont" .. AceGUI:GetNextWidgetNum(PUI_LABEL_TYPE))
    end

    self.fontObject:SetFont(font, height, flags)
    self:SetFontObject(self.fontObject)
  end,

  SetFontObject = function(self, fontObject)
    self.label:SetFontObject(fontObject or GameFontHighlightSmall)
    PUI_Label_UpdateLayout(self)
  end,

  SetImageSize = function(self, width, height)
    self.image:SetSize(width, height)
    PUI_Label_UpdateLayout(self)
  end,

  SetJustifyH = function(self, justify)
    self.label:SetJustifyH(justify)
  end,

  SetJustifyV = function(self, justify)
    self.label:SetJustifyV(justify)
  end,

  RefreshTheme = function(self)
    WidgetSkins.Label(self)
    PUI_Label_UpdateLayout(self)
  end,
}

local function PUI_Label_Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:Hide()

  local label = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
  label.__puiOptionsFontOwned = true

  local image = frame:CreateTexture(nil, "BACKGROUND")

  local widget = {
    type = PUI_LABEL_TYPE,
    frame = frame,
    label = label,
    image = image,
  }

  for method, func in pairs(PUI_Label_Methods) do
    widget[method] = func
  end

  frame.obj = widget

  return AceGUI:RegisterAsWidget(widget)
end

local PUI_Heading_Methods = {
  OnAcquire = function(self)
    self:SetText(nil)
    self:SetFullWidth(true)
    self:SetHeight(18)
  end,

  SetText = function(self, text)
    self.label:SetText(text or "")

    if text and text ~= "" then
      self.left:SetPoint("RIGHT", self.label, "LEFT", -5, 0)
      self.right:Show()
    else
      self.left:SetPoint("RIGHT", -3, 0)
      self.right:Hide()
    end
  end,

  RefreshTheme = function(self)
    WidgetSkins.Heading(self)
  end,
}

local function PUI_Heading_Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:Hide()

  local label = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
  label.__puiOptionsFontOwned = true
  label:SetPoint("TOP")
  label:SetPoint("BOTTOM")
  label:SetJustifyH("CENTER")

  local left = frame:CreateTexture(nil, "BACKGROUND")
  left:SetHeight(8)
  left:SetPoint("LEFT", 3, 0)
  left:SetPoint("RIGHT", label, "LEFT", -5, 0)
  left:SetTexture(137057)
  left:SetTexCoord(0.81, 0.94, 0.5, 1)

  local right = frame:CreateTexture(nil, "BACKGROUND")
  right:SetHeight(8)
  right:SetPoint("RIGHT", -3, 0)
  right:SetPoint("LEFT", label, "RIGHT", 5, 0)
  right:SetTexture(137057)
  right:SetTexCoord(0.81, 0.94, 0.5, 1)

  local widget = {
    type = PUI_HEADING_TYPE,
    frame = frame,
    label = label,
    left = left,
    right = right,
  }

  for method, func in pairs(PUI_Heading_Methods) do
    widget[method] = func
  end

  frame.obj = widget

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(PUI_LABEL_TYPE, PUI_Label_Constructor, PUI_LABEL_VERSION)
AceGUI:RegisterWidgetType(PUI_HEADING_TYPE, PUI_Heading_Constructor, PUI_HEADING_VERSION)