-- File: PUI_UF_Portrait.lua
-- Purpose: PleebUI geometry and styling for the oUF Portrait element.

local ADDON_NAME, ns = ...

ns.UFPortrait = ns.UFPortrait or {}
local Portrait = ns.UFPortrait
local P = select(1, ns.Pleebug:DropIn(Portrait, { name = "UnitFrames.Portrait" }))

local _G = _G
local CreateFrame = _G.CreateFrame
local SetPortraitTexture = _G.SetPortraitTexture
local math_max = _G.math.max
local math_min = _G.math.min
local tonumber = _G.tonumber
local type = _G.type

local function IsBossUnit(unit)
  return type(unit) == "string" and unit:match("^boss%d$") ~= nil
end

local function IsPartyUnit(unit)
  return type(unit) == "string" and unit:match("^party%d$") ~= nil
end

function Portrait.IsApplicableUnit(unit, groupKind)
  if groupKind == "raid" then
    return false
  end

  if groupKind == "party" then
    return IsPartyUnit(unit) or unit == "player"
  end

  return unit == "player"
    or unit == "target"
    or unit == "focus"
    or IsBossUnit(unit)
end

local function ClampZoom(value)
  value = tonumber(value) or 0
  return math_max(0, math_min(1, value))
end

local function ApplyTextureZoom(texture, zoom)
  local crop = ClampZoom(zoom) * 0.45
  texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
end

local function ApplyModelVisualZoom(model, container, zoom)
  local size = container:GetWidth()
  local scale = 1 + (ClampZoom(zoom) * 1.5)

  model:ClearAllPoints()
  model:SetPoint("CENTER", container, "CENTER", 0, 0)
  model:SetSize(size * scale, size * scale)
end

local function ApplyGeometry(container, layout)
  local size = layout.portraitSize or layout.totalHeight or 0
  local side = layout.portraitSide or "LEFT"

  container:ClearAllPoints()
  container:SetSize(size, size)

  if side == "RIGHT" then
    container:SetPoint("TOPRIGHT", container:GetParent(), "TOPRIGHT", 0, 0)
  else
    container:SetPoint("TOPLEFT", container:GetParent(), "TOPLEFT", 0, 0)
  end
end

local function EnsureRuntime(frame)
  local runtime = frame.__puiPortraitRuntime
  if runtime then
    return runtime
  end

  local container = CreateFrame("Frame", nil, frame)
  container:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
  container:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
  container:SetClipsChildren(true)
  container:EnableMouse(false)
  container:Hide()

  runtime = {
    container = container,
  }

  frame.__puiPortraitRuntime = runtime
  return runtime
end

local function EnsureTexture(runtime)
  if runtime.texture then
    return runtime.texture
  end

  local texture = runtime.container:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(runtime.container)
  texture:Hide()

  runtime.texture = texture
  return texture
end

local function EnsureModel(runtime)
  if runtime.model then
    return runtime.model
  end

  local model = CreateFrame("PlayerModel", nil, runtime.container)
  model:EnableMouse(false)
  model:Hide()

  runtime.model = model
  return model
end

local function GetConfiguredElement(runtime, portraitDB)
  if portraitDB.style == "3D" then
    return EnsureModel(runtime)
  end

  return EnsureTexture(runtime)
end

local function SetRuntimeElement(frame, runtime, element)
  if runtime.element == element then
    return false
  end

  local initialized = frame.__puiUF_oUFInitialized == true
  local enabled = initialized and frame:IsElementEnabled("Portrait") == true
  local paused = initialized and frame:IsElementPaused("Portrait")

  if enabled and not paused then
    frame:DisableElement("Portrait")
  end

  if runtime.element then
    runtime.element:Hide()
  end

  runtime.element = element
  frame.Portrait = element

  if initialized and not paused then
    frame:EnableElement("Portrait")
  end

  return true
end

function Portrait.PrepareFrame(frame, cfg)
  local portraitDB = cfg and cfg.portrait
  if not frame or not portraitDB or portraitDB.enabled ~= true then
    return
  end

  local runtime = EnsureRuntime(frame)
  local element = GetConfiguredElement(runtime, portraitDB)

  runtime.element = element
  frame.Portrait = element
end

function Portrait.ConfigureFrame(frame, unit, cfg, layout)
  local portraitDB = cfg and cfg.portrait
  if not frame or not unit or not portraitDB or portraitDB.enabled ~= true then
    Portrait.Disable(frame)
    return
  end

  local runtime = EnsureRuntime(frame)
  local element = GetConfiguredElement(runtime, portraitDB)
  local changed = SetRuntimeElement(frame, runtime, element)

  if frame.__puiUF_oUFInitialized == true
    and not frame:IsElementEnabled("Portrait")
    and not frame:IsElementPaused("Portrait")
  then
    frame:EnableElement("Portrait")
    changed = true
  end

  ApplyGeometry(runtime.container, layout)

  if element:IsObjectType("PlayerModel") then
    ApplyModelVisualZoom(element, runtime.container, portraitDB.zoom)
  else
    ApplyTextureZoom(element, portraitDB.zoom)
  end

  runtime.container:Show()
  frame.__puiPortraitEnabled = true

  if frame.__puiUF_oUFInitialized == true
    and frame:IsElementEnabled("Portrait")
    and not frame:IsElementPaused("Portrait")
    and changed
  then
    element:ForceUpdate()
  end

  runtime.zoom = portraitDB.zoom
end

function Portrait.Disable(frame)
  local runtime = frame and frame.__puiPortraitRuntime
  if not runtime then
    return
  end

  if frame.__puiUF_oUFInitialized == true and frame:IsElementEnabled("Portrait") then
    frame:DisableElement("Portrait")
  end

  if runtime.element then
    runtime.element:Hide()
  end

  runtime.container:Hide()
  runtime.zoom = nil
  frame.__puiPortraitEnabled = nil
end

local function EnsurePreview(frame)
  local preview = frame.__puiPortraitPreview
  if preview then
    return preview
  end

  local container = CreateFrame("Frame", nil, frame)
  container:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
  container:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
  container:SetClipsChildren(true)
  container:EnableMouse(false)
  container:Hide()

  local texture = container:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(container)
  texture:Hide()

  preview = {
    container = container,
    texture = texture,
  }

  frame.__puiPortraitPreview = preview
  return preview
end

local function EnsurePreviewModel(preview)
  if preview.model then
    return preview.model
  end

  local model = CreateFrame("PlayerModel", nil, preview.container)
  model:SetCamera(0)
  model:EnableMouse(false)
  model:Hide()

  preview.model = model
  return model
end

function Portrait.ConfigurePreview(frame, cfg, layout)
  local portraitDB = cfg and cfg.portrait
  if not frame or not portraitDB or portraitDB.enabled ~= true then
    return
  end

  local preview = EnsurePreview(frame)

  ApplyGeometry(preview.container, layout)
  preview.container:Show()
  frame.__puiPortraitPreviewEnabled = true

  if portraitDB.style == "3D" then
    local model = EnsurePreviewModel(preview)
    preview.texture:Hide()
    model:ClearModel()
    model:SetUnit("player")
    ApplyModelVisualZoom(model, preview.container, portraitDB.zoom)
    model:Show()
  else
    if preview.model then
      preview.model:ClearModel()
      preview.model:Hide()
    end

    ApplyTextureZoom(preview.texture, portraitDB.zoom)
    SetPortraitTexture(preview.texture, "player")
    preview.texture:Show()
  end
end

function Portrait.DisablePreview(frame)
  if not frame or frame.__puiPortraitPreviewEnabled ~= true then
    return
  end

  local preview = frame.__puiPortraitPreview
  if preview then
    preview.texture:Hide()
    if preview.model then
      preview.model:ClearModel()
      preview.model:Hide()
    end
    preview.container:Hide()
  end

  frame.__puiPortraitPreviewEnabled = nil
end

IsBossUnit = P:Def("IsBossUnit", IsBossUnit)
IsPartyUnit = P:Def("IsPartyUnit", IsPartyUnit)
Portrait.IsApplicableUnit = P:Def("Portrait.IsApplicableUnit", Portrait.IsApplicableUnit)
ClampZoom = P:Def("ClampZoom", ClampZoom)
ApplyTextureZoom = P:Def("ApplyTextureZoom", ApplyTextureZoom)
ApplyModelVisualZoom = P:Def("ApplyModelVisualZoom", ApplyModelVisualZoom)
ApplyGeometry = P:Def("ApplyGeometry", ApplyGeometry)
EnsureRuntime = P:Def("EnsureRuntime", EnsureRuntime)
EnsureTexture = P:Def("EnsureTexture", EnsureTexture)
EnsureModel = P:Def("EnsureModel", EnsureModel)
GetConfiguredElement = P:Def("GetConfiguredElement", GetConfiguredElement)
SetRuntimeElement = P:Def("SetRuntimeElement", SetRuntimeElement)
Portrait.PrepareFrame = P:Def("Portrait.PrepareFrame", Portrait.PrepareFrame)
Portrait.ConfigureFrame = P:Def("Portrait.ConfigureFrame", Portrait.ConfigureFrame)
Portrait.Disable = P:Def("Portrait.Disable", Portrait.Disable)
EnsurePreview = P:Def("EnsurePreview", EnsurePreview)
EnsurePreviewModel = P:Def("EnsurePreviewModel", EnsurePreviewModel)
Portrait.ConfigurePreview = P:Def("Portrait.ConfigurePreview", Portrait.ConfigurePreview)
Portrait.DisablePreview = P:Def("Portrait.DisablePreview", Portrait.DisablePreview)
