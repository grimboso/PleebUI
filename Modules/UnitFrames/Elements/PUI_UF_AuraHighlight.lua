-- File: PUI_UF_AuraHighlight.lua
-- Purpose: Dispel health-color and border presentation driven by one oUF Aura slot.

local _, ns = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local math_max = _G.math.max
local table_concat = _G.table.concat
local tonumber = _G.tonumber
local tostring = _G.tostring

local AuraHighlight = {}
ns.UFAuraHighlight = AuraHighlight

local Round = ns.Pixel.Round

local DISABLED_CANDIDATE_FILTERS = {
  includeSpellIDs = {
    [0] = true,
  },
}

local ENABLED_CANDIDATE_FILTERS = {}

local HIGH_RES_DISPEL_ICON_ASSETS = {
  Magic = {
    asset = "icons_64x64_magic",
    useAtlasSize = false,
  },
  Curse = {
    asset = "icons_64x64_curse",
    useAtlasSize = false,
  },
  Disease = {
    asset = "icons_64x64_disease",
    useAtlasSize = false,
  },
  Bleed = {
    asset = "icons_64x64_bleed",
    useAtlasSize = false,
  },
  Poison = {
    asset = "icons_64x64_poison",
    useAtlasSize = false,
  },
}

function AuraHighlight.GetPreviewDispelIconAtlas(dispelType)
  local customAsset = HIGH_RES_DISPEL_ICON_ASSETS[dispelType]
  return customAsset and customAsset.asset or nil
end

local function GetProfile(frame)
  if frame.__puiGroupKind == "party" then
    return ns.Modules.PartyFrames.db.profile
  elseif frame.__puiGroupKind == "raid" then
    return ns.Modules.RaidFrames.db.profile
  end
end

function AuraHighlight.IsEnabled(frame)
  local profile = frame and GetProfile(frame)
  local mode = profile and profile.debuffHighlighting or "NONE"
  local highlight = profile and profile.debuffHighlight or nil
  return mode ~= "NONE" or (highlight and highlight.blizzardIndicator == true) or false
end

local function RegisterDispelTexture(button, texture, style, customDispelAssetMap)
  button:AddDispelTypeTexture(texture, {
    style = style or Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
    showWhenHarmful = true,
    showWhenHelpful = false,
    showWithoutDispelType = false,
    customDispelAssetMap = customDispelAssetMap,
  })
end

local function CreatePresentationHost(button)
  local host = CreateFrame("Frame", nil, button)
  host:EnableMouse(false)
  return host
end

local function CreateFillPresentation(button)
  local host = CreatePresentationHost(button)
  local texture = host:CreateTexture(nil, "ARTWORK", nil, 1)
  texture:SetAllPoints(host)
  texture:SetColorTexture(1, 1, 1, 1)
  texture:SetBlendMode("BLEND")
  RegisterDispelTexture(button, texture)
  return host, texture
end

local function CreateBorderPresentation(button)
  local host = CreatePresentationHost(button)
  local border = {
    top = host:CreateTexture(nil, "OVERLAY", nil, 7),
    bottom = host:CreateTexture(nil, "OVERLAY", nil, 7),
    left = host:CreateTexture(nil, "OVERLAY", nil, 7),
    right = host:CreateTexture(nil, "OVERLAY", nil, 7),
  }

  for _, texture in pairs(border) do
    texture:SetColorTexture(1, 1, 1, 1)
    RegisterDispelTexture(button, texture)
  end

  return host, border
end

local function CreateBlizzardIndicator(button)
  local host = CreatePresentationHost(button)
  local texture = host:CreateTexture(nil, "OVERLAY", nil, 7)
  texture:SetAllPoints(host)
  RegisterDispelTexture(
    button,
    texture,
    Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
    HIGH_RES_DISPEL_ICON_ASSETS
  )
  return host
end

local function ConfigureBorderTextures(border, health, bottom, edge)
  border.top:ClearAllPoints()
  border.top:SetPoint("BOTTOMLEFT", health, "TOPLEFT", -edge, 0)
  border.top:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", edge, 0)
  border.top:SetHeight(edge)

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", -edge, 0)
  border.bottom:SetPoint("TOPRIGHT", bottom, "BOTTOMRIGHT", edge, 0)
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPRIGHT", health, "TOPLEFT", 0, edge)
  border.left:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMLEFT", 0, -edge)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, edge)
  border.right:SetPoint("BOTTOMLEFT", bottom, "BOTTOMRIGHT", 0, -edge)
  border.right:SetWidth(edge)
end

function AuraHighlight.BuildRuntimeKey(frame)
  local profile = GetProfile(frame)
  if not profile then
    return nil
  end

  local mode = profile and profile.debuffHighlighting or "NONE"
  local highlight = profile and profile.debuffHighlight or nil
  local health = frame.Health
  local healthTexture = health:GetStatusBarTexture()
  local power = frame.Power
  local bottom = power and power:IsShown() and power or health

  return table_concat({
    tostring(mode),
    tostring(highlight and highlight.borderSize or 3),
    highlight and highlight.blizzardIndicator == true and "1" or "0",
    tostring(highlight and highlight.blizzardIndicatorSize or 18),
    tostring(highlight and highlight.blizzardIndicatorPosition or "TOPRIGHT"),
    tostring(highlight and highlight.blizzardIndicatorXOffset or 0),
    tostring(highlight and highlight.blizzardIndicatorYOffset or 0),
    profile and profile.hideHealth == true and "1" or "0",
    tostring(healthTexture),
    tostring(bottom),
    tostring(health:GetFrameStrata()),
    tostring(health:GetFrameLevel()),
  }, "\31")
end

local function ConfigureSlot(runtime)
  local frame = runtime.frame
  local profile = GetProfile(frame)
  local mode = profile and profile.debuffHighlighting or "NONE"
  local highlight = profile and profile.debuffHighlight or nil
  local health = frame.Health
  local healthTexture = health:GetStatusBarTexture()
  local power = frame.Power
  local bottom = power and power:IsShown() and power or health
  local edge = math_max(0, Round(tonumber(highlight and highlight.borderSize) or 3))
  local showHealth = not profile or profile.hideHealth ~= true
  local showFill = showHealth and (mode == "FILL" or mode == "BOTH")
  local showBorder = (mode == "GLOW" or mode == "BOTH") and edge > 0
  local showBlizzardIndicator = highlight and highlight.blizzardIndicator == true
  local blizzardIndicatorSize = math_max(
    8,
    Round(tonumber(highlight and highlight.blizzardIndicatorSize) or 18)
  )
  local blizzardIndicatorPosition = highlight and highlight.blizzardIndicatorPosition or "TOPRIGHT"
  local blizzardIndicatorXOffset = Round(tonumber(highlight and highlight.blizzardIndicatorXOffset) or 0)
  local blizzardIndicatorYOffset = Round(tonumber(highlight and highlight.blizzardIndicatorYOffset) or 0)
  local button = runtime.button

  button:EnableMouse(false)
  button:ClearAllPoints()
  button:SetAllPoints(healthTexture)
  button:SetFrameStrata(health:GetFrameStrata())
  button:SetFrameLevel(health:GetFrameLevel())

  runtime.fillHost:ClearAllPoints()
  runtime.fillHost:SetAllPoints(healthTexture)
  runtime.fillHost:SetFrameStrata(health:GetFrameStrata())
  runtime.fillHost:SetFrameLevel(health:GetFrameLevel())
  runtime.fillHost:SetShown(showFill)

  runtime.borderHost:ClearAllPoints()
  runtime.borderHost:SetAllPoints(frame)
  runtime.borderHost:SetFrameStrata(frame:GetFrameStrata())
  runtime.borderHost:SetFrameLevel(frame:GetFrameLevel() + 1)
  runtime.borderHost:SetShown(showBorder)
  ConfigureBorderTextures(runtime.border, health, bottom, edge)

  runtime.blizzardIndicator:ClearAllPoints()
  runtime.blizzardIndicator:SetPoint(
    blizzardIndicatorPosition,
    frame,
    blizzardIndicatorPosition,
    blizzardIndicatorXOffset,
    blizzardIndicatorYOffset
  )
  runtime.blizzardIndicator:SetSize(blizzardIndicatorSize, blizzardIndicatorSize)
  runtime.blizzardIndicator:SetFrameStrata(frame:GetFrameStrata())
  runtime.blizzardIndicator:SetFrameLevel(frame:GetFrameLevel() + 2)
  runtime.blizzardIndicator:SetShown(showBlizzardIndicator)
end

local function InitializeSlot(runtime, button)
  runtime.button = button
  runtime.fillHost, runtime.fill = CreateFillPresentation(button)
  runtime.borderHost, runtime.border = CreateBorderPresentation(button)
  runtime.blizzardIndicator = CreateBlizzardIndicator(button)
  ConfigureSlot(runtime)
end

function AuraHighlight.SetRuntimeEnabled(runtime, enabled)
  enabled = enabled == true
  if runtime.enabled ~= enabled then
    runtime.enabled = enabled
    runtime.container:SetAuraSlotCandidateFilters(
      runtime.slotKey,
      enabled and ENABLED_CANDIDATE_FILTERS or DISABLED_CANDIDATE_FILTERS
    )
  end
end

function AuraHighlight.AttachContainer(frame, container)
  if not GetProfile(frame) then
    return nil
  end

  local enabled = AuraHighlight.IsEnabled(frame)
  local runtime = {
    frame = frame,
    container = container,
    enabled = enabled,
  }
  local options = {
    candidateFilters = enabled
      and ENABLED_CANDIDATE_FILTERS
      or DISABLED_CANDIDATE_FILTERS,
  }

  options.initializeFrame = function(button)
    InitializeSlot(runtime, button)
  end

  runtime.slotKey = container:AddSlot("HARMFUL|RAID", options)
  return runtime
end

local P = select(1, ns.Pleebug:DropIn(AuraHighlight, { name = "UnitFrames.AuraHighlight" }))
GetProfile = P:Def("GetProfile", GetProfile)
RegisterDispelTexture = P:Def("RegisterDispelTexture", RegisterDispelTexture)
CreatePresentationHost = P:Def("CreatePresentationHost", CreatePresentationHost)
CreateFillPresentation = P:Def("CreateFillPresentation", CreateFillPresentation)
CreateBorderPresentation = P:Def("CreateBorderPresentation", CreateBorderPresentation)
CreateBlizzardIndicator = P:Def("CreateBlizzardIndicator", CreateBlizzardIndicator)
ConfigureBorderTextures = P:Def("ConfigureBorderTextures", ConfigureBorderTextures)
ConfigureSlot = P:Def("ConfigureSlot", ConfigureSlot)
InitializeSlot = P:Def("InitializeSlot", InitializeSlot)
AuraHighlight.BuildRuntimeKey = P:Def(
  "AuraHighlight.BuildRuntimeKey",
  AuraHighlight.BuildRuntimeKey
)
AuraHighlight.GetPreviewDispelIconAtlas = P:Def(
  "AuraHighlight.GetPreviewDispelIconAtlas",
  AuraHighlight.GetPreviewDispelIconAtlas
)
AuraHighlight.IsEnabled = P:Def("AuraHighlight.IsEnabled", AuraHighlight.IsEnabled)
AuraHighlight.SetRuntimeEnabled = P:Def(
  "AuraHighlight.SetRuntimeEnabled",
  AuraHighlight.SetRuntimeEnabled
)
AuraHighlight.AttachContainer = P:Def("AuraHighlight.AttachContainer", AuraHighlight.AttachContainer)
