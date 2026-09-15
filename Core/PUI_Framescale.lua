local _, ns = ...
local Addon = ns.Addon
local FrameScale = Addon:NewModule("FrameScale", "NumyAceEvent-3.0")
local Pixel = ns.Pixel

local registered = {}
local basePx = 1
local px = 1
local physicalWidth, physicalHeight = 0, 0

local resolutionScalePresets = {
  ["1080p"] = 0.711111,
  ["1440p"] = 0.533333333333333,
  ["4K"] = 0.355556,
}

local function ClampUIScale(scale)
  return math.max(0.1, math.min(1.25, tonumber(scale) or UIParent:GetScale()))
end

local function RecomputePixelContext()
  physicalWidth, physicalHeight = GetPhysicalScreenSize()
  basePx = 768 / physicalHeight
  px = basePx / UIParent:GetEffectiveScale()
end

local function NotifyScaleChanged()
  for func in pairs(registered) do
    func(FrameScale, px)
  end
end

function FrameScale:GetUIScale()
  return ClampUIScale(Addon:GetGlobalOptionsDB().UIScale)
end

function FrameScale:GetResolutionScalePreset(key)
  return resolutionScalePresets[key]
end

function FrameScale:PixelBestSize()
  return math.max(0.4, math.min(1.15, 768 / physicalHeight))
end

function FrameScale:ApplyUIScaleFromProfile()
  local options = Addon:GetGlobalOptionsDB()

  if options.useCustomUIScale == false then
    RecomputePixelContext()
    return
  end

  local scale = self:GetUIScale()
  options.UIScale = scale

  if InCombatLockdown() then
    Addon._puiPendingUIScaleApply = true
    return
  end

  Addon.__puiApplyingUIScale = true
  UIParent:SetScale(scale)
  Addon.__puiApplyingUIScale = nil
  RecomputePixelContext()
end

function FrameScale:SetUIScale(scale, deferApply)
  local options = Addon:GetGlobalOptionsDB()
  options.UIScale = ClampUIScale(scale)
  options.useCustomUIScale = true

  if not deferApply then
    self:_OnScaleContextChanged("SET_UI_SCALE")
  end
end

function FrameScale:SetUseCustomUIScale(enabled)
  local options = Addon:GetGlobalOptionsDB()
  options.useCustomUIScale = enabled == true

  if options.useCustomUIScale then
    self:_OnScaleContextChanged("SET_USE_CUSTOM_UI_SCALE")
  else
    RecomputePixelContext()
    NotifyScaleChanged()
  end
end

function FrameScale:ApplyPendingUIScale()
  if Addon._puiPendingUIScaleApply then
    Addon._puiPendingUIScaleApply = nil
    self:_OnScaleContextChanged("PLAYER_REGEN_ENABLED")
  end
end

function Pixel.Round(value)
  if px == 1 or value == 0 then
    return value
  end

  local quotient = value / px
  if quotient >= 0 then
    quotient = math.floor(quotient + 0.5)
  else
    quotient = math.ceil(quotient - 0.5)
  end

  return quotient * px
end

function Pixel.GetOnePixel()
  return px
end

local function ScalePointArgument(value)
  if type(value) == "number" then
    return Pixel.Round(value)
  end

  return value
end

-- PleebUI owns pixel rounding, so addon-owned textures must not apply a second native snap.
function Pixel.DisableSnap(object)
  if object.SetSnapToPixelGrid then
    object:SetSnapToPixelGrid(false)
    object:SetTexelSnappingBias(0)
    return
  end

  if object.GetStatusBarTexture then
    local texture = object:GetStatusBarTexture()
    if texture and texture.SetSnapToPixelGrid then
      texture:SetSnapToPixelGrid(false)
      texture:SetTexelSnappingBias(0)
    end
  end
end

function Pixel.SetTexture(object, ...)
  object:SetTexture(...)
  Pixel.DisableSnap(object)
end

function Pixel.SetColorTexture(object, ...)
  object:SetColorTexture(...)
  Pixel.DisableSnap(object)
end

function Pixel.SetStatusBarTexture(object, ...)
  object:SetStatusBarTexture(...)
  Pixel.DisableSnap(object)
end

function Pixel.SetTexCoord(object, ...)
  object:SetTexCoord(...)
  Pixel.DisableSnap(object)
end

function Pixel.SetVertexColor(object, ...)
  object:SetVertexColor(...)
  Pixel.DisableSnap(object)
end

function Pixel.Point(object, point, relativeTo, relativePoint, offsetX, offsetY, ...)
  if relativeTo == nil then
    relativeTo = object:GetParent()
  end

  Pixel.DisableSnap(object)
  object:SetPoint(
    point,
    ScalePointArgument(relativeTo),
    ScalePointArgument(relativePoint),
    ScalePointArgument(offsetX),
    ScalePointArgument(offsetY),
    ...
  )
end

function Pixel.Size(object, width, height, ...)
  local scaledWidth = Pixel.Round(width)

  Pixel.DisableSnap(object)
  object:SetSize(scaledWidth, height and Pixel.Round(height) or scaledWidth, ...)
end

function Pixel.Width(object, width, ...)
  Pixel.DisableSnap(object)
  object:SetWidth(Pixel.Round(width), ...)
end

function Pixel.Height(object, height, ...)
  Pixel.DisableSnap(object)
  object:SetHeight(Pixel.Round(height), ...)
end

function Pixel.AllPoints(object, relativeTo, ...)
  Pixel.DisableSnap(object)
  object:SetAllPoints(relativeTo, ...)
end

function FrameScale:RegisterScaleListener(func)
  registered[func] = true
  func(self, px)
end

function FrameScale:UnregisterScaleListener(func)
  registered[func] = nil
end

function FrameScale:_OnScaleContextChanged(event)
  if event == "UI_SCALE_CHANGED" and Addon.__puiApplyingUIScale then
    return
  end

  local oldWidth, oldHeight = physicalWidth, physicalHeight
  local oldPx, oldBasePx = px, basePx

  self:ApplyUIScaleFromProfile()
  RecomputePixelContext()

  if physicalWidth ~= oldWidth
    or physicalHeight ~= oldHeight
    or math.abs(px - oldPx) > 1e-6
    or math.abs(basePx - oldBasePx) > 1e-6
  then
    NotifyScaleChanged()
  end
end

function FrameScale:OnInitialize()
  RecomputePixelContext()
end

function FrameScale:OnEnable()
  self:ApplyUIScaleFromProfile()
  RecomputePixelContext()
  NotifyScaleChanged()

  self:RegisterEvent("PLAYER_ENTERING_WORLD", "_OnScaleContextChanged")
  self:RegisterEvent("DISPLAY_SIZE_CHANGED", "_OnScaleContextChanged")
  self:RegisterEvent("UI_SCALE_CHANGED", "_OnScaleContextChanged")
end

function FrameScale:OnDisable()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("DISPLAY_SIZE_CHANGED")
  self:UnregisterEvent("UI_SCALE_CHANGED")
end

ns.FrameScale = FrameScale
Addon.FrameScale = FrameScale

