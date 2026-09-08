local ADDON_NAME, ns = ...

local Secondary = ns.PRDSecondary
local AuraWidget = ns.AuraWidget
local AuraSlotDriver = ns.AuraSlotDriver
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_AuraStacks" })
local _, PLAYER_CLASS = UnitClass("player")
local PLAYER_CLASS_COLOR = RAID_CLASS_COLORS[PLAYER_CLASS]

local nativeSpellSets = setmetatable({}, { __mode = "k" })

local function NativeButtonRestricted()
  return C_Secrets.ShouldAurasBeSecret() == true
end

local function GetNativeFormatter(owner, track)
  local config = track.config
  local textConfig = config.text
  local mode = textConfig.mode or "CUR"
  if mode == "PCT" or mode == "CURP" then
    mode = "CUR"
  end

  local showNumber = textConfig.showNumber ~= false and mode ~= "HIDE"
  local countdown = Secondary.ShouldShowApplicationCountdown(config)
  local key = showNumber
    and table.concat({
      mode,
      track.maximum,
      countdown and 1 or 0,
      config.applicationCountdownMax or 0,
    }, "|")
    or "HIDE"

  if track.formatterKey == key then
    return track.formatter
  end

  track.formatterKey = key

  if not showNumber then
    track.formatter = nil
    return nil
  end

  local formatter = C_StringUtil.CreateNumericRuleFormatter()

  if countdown then
    local countdownMaximum = tonumber(config.applicationCountdownMax) or 0
    for applications = 0, track.maximum do
      formatter:AddBreakpoint({
        threshold = applications,
        format = Secondary.FormatApplicationCountdown(
          config,
          countdownMaximum - applications
        ),
      })
    end
  else
    local format = mode == "BOTH" and ("%.0f / " .. track.maximum) or "%.0f"
    formatter:AddBreakpoint({ threshold = 0, format = format })
  end

  track.formatter = formatter
  return formatter
end

local function GetNativeSpellSet(definition)
  local set = nativeSpellSets[definition]
  if set then
    return set
  end

  set = {}
  for i = 1, #definition.auraSpellIDs do
    set[definition.auraSpellIDs[i]] = true
  end
  nativeSpellSets[definition] = set
  return set
end

local function CopyNativeTextStyle(source, target)
  local fontPath, fontSize, fontFlags = source:GetFont()
  target:SetFont(fontPath, fontSize, fontFlags)
  target:SetTextColor(source:GetTextColor())
  target:SetShadowColor(source:GetShadowColor())
  target:SetShadowOffset(source:GetShadowOffset())
end

local function HideNativeDividers(track)
  local dividers = track and track.dividers
  if dividers then
    for i = 1, #dividers do
      dividers[i]:Hide()
    end
  end

  if track and track.dividerFrame then
    track.dividerFrame:Hide()
  end
end

local function GetNativeTickValues(config, maximum)
  if config.showDividers == false or maximum <= 1 then
    return nil
  end

  local pattern = config.stackTickValues or "ALL"
  if pattern:upper():find("ALL", 1, true) then
    local values = {}
    for value = 1, maximum - 1 do
      values[#values + 1] = value
    end
    return values
  end

  local values = {}
  local seen = {}
  for token in pattern:gmatch("[^,]+") do
    local value = tonumber(token:match("^%s*(.-)%s*$"))
    if value then
      value = math.floor(value + 0.5)
      if value > 0 and value < maximum and not seen[value] then
        seen[value] = true
        values[#values + 1] = value
      end
    end
  end
  table.sort(values)
  return #values > 0 and values or nil
end

local function HasEnabledStackColorThreshold(config)
  local thresholds = config.stackColorThresholds or {}
  for index = 1, #thresholds do
    if thresholds[index].enabled == true then
      return true
    end
  end
  return false
end

local function ShouldUseCDMStackColorSource(track)
  return track.definition.applicationSource ~= "AURA_SLOT"
    and track.definition.cdmViewerKey ~= nil
    and HasEnabledStackColorThreshold(track.config)
end

local function LayoutNativeDividers(track)
  local config = track.config
  local maximum = tonumber(track.maximum) or 0
  local tickValues = GetNativeTickValues(config, maximum)

  if not tickValues then
    HideNativeDividers(track)
    return
  end

  local parent = track.parent
  local dividerFrame = track.dividerFrame
  if not dividerFrame then
    dividerFrame = CreateFrame("Frame", nil, parent)
    dividerFrame:EnableMouse(false)
    track.dividerFrame = dividerFrame
  elseif dividerFrame:GetParent() ~= parent then
    dividerFrame:SetParent(parent)
  end

  dividerFrame:ClearAllPoints()
  dividerFrame:SetAllPoints(parent)
  dividerFrame:SetFrameStrata(parent:GetFrameStrata())
  dividerFrame:SetFrameLevel(math.max(
    parent:GetFrameLevel() + 4,
    (track.applicationThresholdTopFrameLevel or parent:GetFrameLevel() + 3) + 1
  ))
  dividerFrame:Show()

  local width = parent:GetWidth() or 0
  if width <= 0 then
    return
  end

  local dividerSize = Secondary.GetSecondaryDividerSize(config)
  local dividerColor = Secondary.ResolveSecondaryDividerColor(config)
  local dividers = track.dividers
  if not dividers then
    dividers = {}
    track.dividers = dividers
  end

  local dividerCount = #tickValues

  for i = 1, dividerCount do
    local divider = dividers[i]
    if not divider then
      divider = dividerFrame:CreateTexture(nil, "OVERLAY", nil, 7)
      dividers[i] = divider
    end

    local x = (width * tickValues[i] / maximum) - (dividerSize / 2)
    divider:SetDrawLayer("OVERLAY", 7)
    divider:SetColorTexture(
      dividerColor.r,
      dividerColor.g,
      dividerColor.b,
      dividerColor.a
    )
    divider:ClearAllPoints()
    divider:SetWidth(dividerSize)
    divider:SetPoint("TOPLEFT", dividerFrame, "TOPLEFT", x, 0)
    divider:SetPoint("BOTTOMLEFT", dividerFrame, "BOTTOMLEFT", x, 0)
    divider:Show()
  end

  for i = dividerCount + 1, #dividers do
    dividers[i]:Hide()
  end
end

local function AttachNativeDividers(owner, track)
  local view = track.view
  if view and view.secondaryDividerFrame then
    view.secondaryDividerFrame:Hide()
  end

  local parent = track.parent
  parent._puiAuraStackDividerOwner = owner
  parent._puiAuraStackDividerTrack = track

  if parent._puiAuraStackDividerHooked ~= true then
    parent._puiAuraStackDividerHooked = true
    parent:HookScript("OnSizeChanged", function(frame)
      local dividerOwner = frame._puiAuraStackDividerOwner
      local dividerTrack = frame._puiAuraStackDividerTrack
      if dividerOwner and dividerTrack then
        LayoutNativeDividers(dividerTrack)
      end
    end)
  end

  LayoutNativeDividers(track)
end

local function ConfigureNativeCountdownFallback(owner, track, button)
  local config = track.config
  local view = track.view
  local shown = Secondary.ShouldShowApplicationCountdown(config)
  local sourceText = Secondary.PrepareSecondaryText(view, view.secondaryBar)

  if not track.countdownFallbackText then
    track.countdownFallbackText = track.parent:CreateFontString(nil, "OVERLAY")
    track.countdownFallbackText:SetPoint("CENTER", track.parent, "CENTER", 0, 0)
  end

  local fallbackText = track.countdownFallbackText
  CopyNativeTextStyle(sourceText, fallbackText)
  Secondary.ApplyResourceFont(view, fallbackText, config)
  fallbackText:SetText(
    Secondary.FormatApplicationCountdown(
      config,
      config.applicationCountdownMax or 0
    )
  )
  fallbackText:SetShown(shown)

  if not track.countdownCover then
    track.countdownCover = button:CreateTexture(nil, "BACKGROUND", nil, 7)
  end

  local background = config.style.bgColor or { 0, 0, 0, 0.65 }
  local inset = track.inset or 0
  local cover = track.countdownCover
  cover:ClearAllPoints()
  cover:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  cover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  cover:SetColorTexture(
    background[1] or 0,
    background[2] or 0,
    background[3] or 0,
    1
  )
  cover:SetShown(shown)
end

local function ConfigureNativeApplicationVisuals(owner, track, parts, styleApplicationBar)
  local applicationBar = parts.applicationThresholdMirror
  local textureKey = track.config.texture or track.definition.texture
  local texturePath = Secondary.FetchStatusbarTexture(textureKey)
  local applicationTexture = texturePath or "Interface\\Buttons\\WHITE8X8"

  if styleApplicationBar then
    local r, g, b, a = Secondary.ResolveResourceColor(
      track.config,
      track.definition
    )

    applicationBar:SetStatusBarTexture(applicationTexture)
    applicationBar:SetOrientation("HORIZONTAL")
    applicationBar:SetReverseFill(false)
    applicationBar:SetStatusBarColor(r, g, b, a)
    applicationBar:SetAlpha(1)

    AuraWidget.ConfigureApplicationThresholds(
      parts,
      track.config.stackColorThresholds,
      applicationTexture,
      "HORIZONTAL",
      false,
      PLAYER_CLASS_COLOR,
      track.maximum
    )
    track.applicationThresholdTopFrameLevel =
      applicationBar:GetFrameLevel() + (parts.applicationThresholdLayerCount or 0)
  end

  AttachNativeDividers(owner, track)
end

local function CreateNativeResourceView(owner)
  return {
    db = owner.db,
    GetBarBorderThickness = owner.GetBarBorderThickness,
    GetBarBorderColor = owner.GetBarBorderColor,
    ApplyBarBorder = owner.ApplyBarBorder,
    ResolveIconTextFont = owner.ResolveIconTextFont,
  }
end

local function GetNativeResourceView(owner, resource)
  if resource.index == 1 then
    return owner
  end

  owner._puiAuraStackResourceViews = owner._puiAuraStackResourceViews or {}
  local views = owner._puiAuraStackResourceViews
  local resourceKey = resource.definition.resourceKey
  local view = views[resourceKey]

  if not view then
    view = CreateNativeResourceView(owner)
    views[resourceKey] = view
  end

  view.db = owner.db
  view.secondary = resource.frame
  view.secondaryDef = resource.definition
  view.secondaryAdapter = resource.adapter
  view.secondaryMax = resource.maximum
  view.secondaryResolvedMax = resource.maximum
  view.secondaryTexture = resource.texture
  view.secondaryPowerPrecise = resource.precisePower == true
  view.secondaryCurrentDivisor = resource.currentDivisor or 1
  view.secondaryDisplayFloor = resource.definition.displayFloor == true
  view.secondaryResourceConfig = resource.config
  view.secondaryUsesCustom = owner.secondaryUsesCustom
  view.secondaryCustomEnabled = owner.secondaryCustomEnabled
  view._puiSecInactiveAlpha = nil
  view._puiSecColorDirty = true
  view._puiSecFontsDirty = true
  resource.view = view
  return view
end

local function ConfigureNativeButton(owner, track, button, initializing)
  local restricted = initializing ~= true and NativeButtonRestricted()
  if restricted then
    owner._puiAuraStackButtonPending = true
  else
    owner._puiAuraStackButtonPending = nil
  end

  local view = track.view
  local sourceText = Secondary.PrepareSecondaryText(view, view.secondaryBar)
  local parts = track.parts
  if not parts then
    parts = AuraWidget.BindApplicationDurationButton(button)
    track.parts = parts
  end
  local engineBar = parts.applicationBar
  local textHolder = parts.applicationHolder
  local text = parts.applicationText
  local inset = 0

  if not restricted then
    button:ClearAllPoints()
    button:SetAllPoints(track.parent)
    button:SetFrameStrata(track.parent:GetFrameStrata())
    button:SetFrameLevel(track.parent:GetFrameLevel() + 1)
    button:EnableMouse(false)
    parts.applicationBase:Hide()
    ConfigureNativeCountdownFallback(owner, track, button)

    engineBar:ClearAllPoints()
    engineBar:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    engineBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    engineBar:SetFrameLevel(button:GetFrameLevel() + 1)

    local useCDMStackColorSource = ShouldUseCDMStackColorSource(track)
    if not useCDMStackColorSource then
      local textureKey = track.config.texture or track.definition.texture
      local texturePath = Secondary.FetchStatusbarTexture(textureKey)
      local r, g, b, a = Secondary.ResolveResourceColor(track.config, track.definition)

      AuraWidget.DisableApplicationThresholdSource(parts)
      AuraWidget.ClearApplicationThresholdBar(parts)
      view.secondaryStatusBar:Hide()
      engineBar:SetStatusBarTexture(texturePath or "Interface\\Buttons\\WHITE8X8")
      engineBar:SetOrientation("HORIZONTAL")
      engineBar:SetReverseFill(false)
      engineBar:SetStatusBarColor(r, g, b, a)
      engineBar:SetAlpha(1)
      local useStackColorThresholds = HasEnabledStackColorThreshold(track.config)
      AuraWidget.ConfigureApplicationThresholds(
        parts,
        useStackColorThresholds and track.config.stackColorThresholds or nil,
        texturePath,
        "HORIZONTAL",
        false,
        PLAYER_CLASS_COLOR,
        track.maximum
      )
      if useStackColorThresholds then
        AuraWidget.ConfigureApplicationThresholdBarSource(parts)
      end
      track.applicationThresholdTopFrameLevel =
        engineBar:GetFrameLevel() + (parts.applicationThresholdLayerCount or 0)
      AttachNativeDividers(owner, track)
      AuraWidget.ConfigureApplicationBar(
        parts,
        track.maximum,
        Enum.StatusBarInterpolation.ExponentialEaseOut
      )
    else
      local applicationBar = AuraWidget.SetApplicationThresholdBar(
        parts,
        view.secondaryStatusBar
      )
      parts.applicationThresholdInterpolation =
        Enum.StatusBarInterpolation.ExponentialEaseOut
      applicationBar:SetFrameLevel(button:GetFrameLevel() + 2)

      ConfigureNativeApplicationVisuals(owner, track, parts, true)
      AuraWidget.ConfigureApplicationBar(
        parts,
        track.maximum,
        Enum.StatusBarInterpolation.Immediate
      )
      AuraWidget.ConfigureApplicationThresholdSource(
        parts,
        track.definition.auraSpellIDs,
        nil,
        track.definition.cdmViewerKey,
        track.unit
      )
    end
  else
    ConfigureNativeApplicationVisuals(owner, track, parts, false)
  end

  local formatter = GetNativeFormatter(owner, track)
  if not restricted then
    if formatter then
      CopyNativeTextStyle(sourceText, text)
      Secondary.ApplyResourceFont(view, text, track.config)
      textHolder:SetFrameLevel(math.max(
        track.parent:GetFrameLevel() + 5,
        track.applicationThresholdTopFrameLevel + 2
      ))

      textHolder:ClearAllPoints()
      textHolder:SetAllPoints(button)
      text:ClearAllPoints()
      text:SetPoint("CENTER", textHolder, "CENTER", 0, 0)
      AuraWidget.ConfigureApplicationCount(parts, formatter)
    else
      text:SetText("")
      text:Hide()
      textHolder:Hide()
      AuraWidget.DisableApplicationCount(parts)
    end
  end

  sourceText:SetText("")
  sourceText:Hide()

  return restricted ~= true
end

local function EnsureNativeTrack(owner, resource, view)
  owner._puiAuraStackTracks = owner._puiAuraStackTracks or {}
  local definition = resource.definition
  local resourceKey = definition.resourceKey
  local track = owner._puiAuraStackTracks[resourceKey]

  if not track then
    track = {
      key = "pui_prd_secondary_" .. resourceKey,
      resourceKey = resourceKey,
    }
    owner._puiAuraStackTracks[resourceKey] = track
  end

  track.owner = owner
  track.resource = resource
  track.view = view
  track.definition = definition
  track.maximum = resource.maximum
  track.parent = view._puiSecondaryContent
  track.config = resource.config

  local unit = definition.unit or "player"
  local filter = definition.filter or "HELPFUL|PLAYER"
  local spellSet = GetNativeSpellSet(definition)

  if track.auraSlot and track.unit ~= unit then
    AuraSlotDriver:SetSlotActive(track.auraSlot, false)
    track.auraSlot = nil
    track.button = nil
  end

  track.unit = unit

  if track.auraSlot then
    if track.filter ~= filter then
      track.filter = filter
      AuraSlotDriver:SetSlotFilter(track.auraSlot, filter)
    end

    if track.candidateSpellIDs ~= spellSet or track.auraSlot.active ~= true then
      AuraSlotDriver:SetSlotCandidates(track.auraSlot, { includeSpellIDs = spellSet })
      track.candidateSpellIDs = spellSet
    end
    ConfigureNativeButton(owner, track, track.button)
  else
    track.filter = filter
    track.auraSlot = AuraSlotDriver:CreateSlot(unit, filter, {
      candidateFilters = { includeSpellIDs = spellSet },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        track.button = button
        ConfigureNativeButton(owner, track, button, true)
      end,
    })
    track.candidateSpellIDs = spellSet
  end

  AuraSlotDriver:SetSlotActive(track.auraSlot, true)
  return track
end

local function DisableNativeTrack(track)
  if not track then
    return
  end

  if track.parts then
    AuraWidget.DisableApplicationThresholdSource(track.parts)
  end
  HideNativeDividers(track)

  if track.auraSlot then
    AuraSlotDriver:SetSlotActive(track.auraSlot, false)
  end
end

local function BuildNative(owner)
  local activeTracks = {}
  local resources = owner.secondaryResources or {}

  for index = 1, #resources do
    local resource = resources[index]
    local definition = resource.definition

    if definition.adapter == "AURA_STACKS" then
      local view = GetNativeResourceView(owner, resource)
      view.secondaryUsesCustom = owner.secondaryUsesCustom
      view.secondaryCustomEnabled = owner.secondaryCustomEnabled

      Secondary.BuildContinuous(view, resource.maximum, 0)
      Secondary.ApplySecondaryAppearance(view)
      EnsureNativeTrack(owner, resource, view)
      activeTracks[definition.resourceKey] = true
      resource.frame:Show()
    end
  end

  local tracks = owner._puiAuraStackTracks
  if tracks then
    for resourceKey, track in pairs(tracks) do
      if activeTracks[resourceKey] ~= true then
        DisableNativeTrack(track)
        if track.resource and track.resource.frame then
          track.resource.frame:Hide()
        end
      end
    end
  end
end

local NATIVE_EVENTS = {
  SPELLS_CHANGED = true,
  PLAYER_REGEN_ENABLED = true,
  PLAYER_ENTERING_WORLD = true,
  ZONE_CHANGED_NEW_AREA = true,
  ENCOUNTER_END = true,
  ADDON_RESTRICTION_STATE_CHANGED = true,
}

local function GetNativeEvents()
  return NATIVE_EVENTS
end

local function UpdateNative(owner, event)
  if event == "SPELLS_CHANGED" then
    owner:RefreshSecondaryAppearance()
    return
  end

  if owner._puiAuraStackButtonPending and not NativeButtonRestricted() then
    for _, track in pairs(owner._puiAuraStackTracks or {}) do
      if track.button and track.auraSlot and track.auraSlot.active == true then
        ConfigureNativeButton(owner, track, track.button)
      end
    end
    return
  end
end

local function DeactivateNative(owner)
  local tracks = owner._puiAuraStackTracks

  if tracks then
    for _, track in pairs(tracks) do
      DisableNativeTrack(track)

      local view = track.view
      if view and view.secondaryStatusBar then
        view.secondaryStatusBar:SetValue(0)
      end
      if view and view.secondaryBar and view.secondaryBar._puiText then
        view.secondaryBar._puiText:SetText("")
        view.secondaryBar._puiText:Hide()
      end
      if track.resource and track.resource.frame then
        track.resource.frame:Hide()
      end
    end
  end

  owner._puiSecondaryBuildPending = true
end

local function RefreshNativeText(owner)
  local tracks = owner._puiAuraStackTracks
  local resources = owner.secondaryResourceByKey
  if not tracks or not resources then
    return
  end

  for resourceKey, track in pairs(tracks) do
    local resource = resources[resourceKey]
    if resource
      and resource.definition.adapter == "AURA_STACKS"
      and track.button
      and track.auraSlot
      and track.auraSlot.active == true
    then
      local view = GetNativeResourceView(owner, resource)
      track.resource = resource
      track.view = view
      track.config = resource.config
      track.maximum = resource.maximum
      track.parent = view._puiSecondaryContent
      ConfigureNativeButton(owner, track, track.button)
    end
  end
end

local function IsNativeStructureReady(owner)
  local tracks = owner._puiAuraStackTracks
  local resources = owner.secondaryResources or {}
  local hasAuraResource = false

  for index = 1, #resources do
    local resource = resources[index]
    if resource.definition.adapter == "AURA_STACKS" then
      hasAuraResource = true
      local track = tracks and tracks[resource.definition.resourceKey]
      local view = resource.view or (index == 1 and owner or nil)

      if not track
        or not track.auraSlot
        or not view
        or not view.secondaryStatusBar
      then
        return false
      end
    end
  end

  return hasAuraResource
end

NativeButtonRestricted = P:Def("AuraStacks.NativeButtonRestricted", NativeButtonRestricted)
GetNativeFormatter = P:Def("AuraStacks.GetNativeFormatter", GetNativeFormatter)
GetNativeSpellSet = P:Def("AuraStacks.GetNativeSpellSet", GetNativeSpellSet)
CopyNativeTextStyle = P:Def("AuraStacks.CopyNativeTextStyle", CopyNativeTextStyle)
ShouldUseCDMStackColorSource = P:Def(
  "AuraStacks.ShouldUseCDMStackColorSource",
  ShouldUseCDMStackColorSource
)
HideNativeDividers = P:Def("AuraStacks.HideNativeDividers", HideNativeDividers)
LayoutNativeDividers = P:Def("AuraStacks.LayoutNativeDividers", LayoutNativeDividers)
AttachNativeDividers = P:Def("AuraStacks.AttachNativeDividers", AttachNativeDividers)
CreateNativeResourceView = P:Def("AuraStacks.CreateNativeResourceView", CreateNativeResourceView)
GetNativeResourceView = P:Def("AuraStacks.GetNativeResourceView", GetNativeResourceView)
ConfigureNativeCountdownFallback = P:Def("AuraStacks.ConfigureNativeCountdownFallback", ConfigureNativeCountdownFallback)
ConfigureNativeApplicationVisuals = P:Def("AuraStacks.ConfigureNativeApplicationVisuals", ConfigureNativeApplicationVisuals)
ConfigureNativeButton = P:Def("AuraStacks.ConfigureNativeButton", ConfigureNativeButton)
EnsureNativeTrack = P:Def("AuraStacks.EnsureNativeTrack", EnsureNativeTrack)
DisableNativeTrack = P:Def("AuraStacks.DisableNativeTrack", DisableNativeTrack)
BuildNative = P:Def("AuraStacks.BuildNative", BuildNative)
UpdateNative = P:Def("AuraStacks.UpdateNative", UpdateNative)

Secondary:RegisterAdapter("AURA_STACKS", {
  directUpdate = true,
  GetEvents = P:Def("AuraStacks.GetEvents", GetNativeEvents),
  Deactivate = P:Def("AuraStacks.Deactivate", DeactivateNative),
  RefreshText = P:Def("AuraStacks.RefreshText", RefreshNativeText),
  IsStructureReady = P:Def("AuraStacks.IsStructureReady", IsNativeStructureReady),
  Build = BuildNative,
  OnEvent = UpdateNative,
  Update = UpdateNative,
})
