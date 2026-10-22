local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local M = ns.Modules.PRD
local AuraWidget = ns.PRDAuraWidget
local Secondary = setmetatable({}, { __index = ns.ResourceSettings })
ns.PRDSecondary = Secondary

Secondary.Adapters = {}

local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Registry" })
local function Noop()
end

local function IsDefaultStructureReady(owner)
  return owner.secondaryBar ~= nil
    or owner.secondaryStatusBar ~= nil
    or owner.secondarySegments and #owner.secondarySegments > 0
end

function Secondary:RegisterAdapter(key, adapter)
  adapter.key = key
  adapter.Deactivate = adapter.Deactivate or Noop
  adapter.Suspend = adapter.Suspend or Noop
  adapter.RefreshText = adapter.RefreshText or Noop
  adapter.IsStructureReady = adapter.IsStructureReady or IsDefaultStructureReady
  self.Adapters[key] = adapter
  return adapter
end

local PLAYER_CLASS = select(2, UnitClass("player"))
local GetPlayerSpecID = ns.ResourceSettings.GetPlayerSpecialization
local GetResolvedDefinitionCandidates = ns.ResourceSettings.GetResolvedDefinitionCandidates
local RESOURCE_NAMES = ns.ResourceSettings.ResourceNames
local NUMERIC_CUE_RESOURCES = ns.ResourceSettings.NumericCueResources
local APPLICATION_COUNTDOWN_MAX_BY_RESOURCE = ns.ResourceSettings.ApplicationCountdownMaxByResource

local function IsDefinitionEnabled(definition, profile, specID)
  if type(definition) ~= "table" then
    return false
  end

  if definition.isAlternatePower == true then
    return profile.primary.hideAlternateMana ~= true
  end

  local settings = Secondary:GetResourceSettings(profile, definition.resourceKey, PLAYER_CLASS, specID)
  return settings.enabled ~= false
end

local function ResolveMaximum(definition, deferSecretAuraMaximum, specID)
  local resolvedMax = tonumber(definition.max) or 0

  if definition.configurableMaximum then
    local settings = Secondary:GetResourceSettings(M.db.profile, definition.resourceKey, PLAYER_CLASS, specID)
    resolvedMax = settings.behavior.stackCeiling
  elseif definition.knownMaxSpellID then
    if C_SpellBook.IsSpellKnown(definition.knownMaxSpellID) then
      resolvedMax = tonumber(definition.maxWhenKnown) or resolvedMax
    else
      resolvedMax = tonumber(definition.maxWhenUnknown) or resolvedMax
    end
  elseif definition.maxAuraSpellID then
    local auraMaximum = C_Spell.GetSpellMaxCumulativeAuraApplications(definition.maxAuraSpellID)
    if issecretvalue(auraMaximum) then
      if deferSecretAuraMaximum then
        return nil
      end
    elseif auraMaximum > 0 then
      resolvedMax = auraMaximum
    end
  elseif definition.maxFromPowerType ~= nil then
    resolvedMax = UnitPowerMax("player", definition.maxFromPowerType) or 0
  end

  resolvedMax = tonumber(resolvedMax) or 0
  if resolvedMax < 0 then
    resolvedMax = 0
  end

  return resolvedMax
end

local function BuildResourceConfigStateKey(config)
  local anchor = config.anchor
  local style = config.style
  local text = config.text
  local font = config.font
  local cues = config.cues
  local behavior = config.behavior
  local customColor = config.customColor
  local defaultColor = config.defaultColor
  local borderColor = style.borderColor
  local backgroundColor = style.bgColor
  local dividerColor = config.dividerColor
  local glowColor = cues.glowColor
  local buffGlowColor = cues.buffGlowColor

  return table.concat({
    config.resourceKey,
    config.specID,
    config.detached and 1 or 0,
    config.height, config.width,
    anchor.point, anchor.x, anchor.y,
    config.perSegment and 1 or 0,
    config.showApplicationsRemaining and 1 or 0,
    config.applicationCountdownMax or 0,
    config.texture or "",
    config.useCustomColor and 1 or 0,
    config.useBlizzardPowerColor and 1 or 0,
    config.useClassColor and 1 or 0,
    customColor[1], customColor[2], customColor[3], customColor[4],
    defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4],
    style.borderSize,
    borderColor[1], borderColor[2], borderColor[3], borderColor[4],
    backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4],
    text.mode, text.showNumber and 1 or 0,
    font.font or "", font.size or 14, font.flags or "", font.useGlobalFont and 1 or 0,
    config.inactiveAlpha, config.showDividers and 1 or 0, config.stackTickValues or "", config.dividerSize,
    dividerColor[1], dividerColor[2], dividerColor[3], dividerColor[4],
    config.showSpellIcon and 1 or 0, config.iconGap,
    cues.desaturateMode, cues.desaturateThreshold,
    cues.glowMode, cues.glowThreshold, cues.glowType,
    glowColor[1], glowColor[2], glowColor[3], glowColor[4],
    cues.buffGlowSpellID,
    buffGlowColor[1], buffGlowColor[2], buffGlowColor[3], buffGlowColor[4],
    behavior.showRechargeTime and 1 or 0,
    behavior.showQueuedRuneTime and 1 or 0,
    behavior.showReadyGlow and 1 or 0,
    behavior.completionAnimation or "",
    behavior.rechargeDirection or "",
    behavior.useSeverityColors and 1 or 0,
    behavior.showSeverityLabel and 1 or 0,
    behavior.yellowThreshold or "",
    behavior.redThreshold or "",
    behavior.fillCeiling,
    behavior.fillMode,
    behavior.simpleRunes and 1 or 0,
    behavior.customRechargeColor and 1 or 0,
    behavior.rechargeColor[1], behavior.rechargeColor[2], behavior.rechargeColor[3], behavior.rechargeColor[4],
    behavior.darkenPartial and 1 or 0,
    behavior.colorChargedPoints and 1 or 0,
    behavior.chargedColor[1], behavior.chargedColor[2], behavior.chargedColor[3], behavior.chargedColor[4],
    behavior.fiveBarStyle and 1 or 0,
    behavior.overflowColor[1], behavior.overflowColor[2], behavior.overflowColor[3], behavior.overflowColor[4],
  }, "|")
end

local function BuildResourceConfigStructureKey(config)
  return table.concat({
    config.resourceKey,
    config.specID,
    config.perSegment and 1 or 0,
    config.behavior.fiveBarStyle and 1 or 0,
  }, "|")
end

local function CopyColor(color, r, g, b, a)
  color = color or {}
  return {
    tonumber(color[1] or color.r) or r,
    tonumber(color[2] or color.g) or g,
    tonumber(color[3] or color.b) or b,
    tonumber(color[4] or color.a) or a,
  }
end

local function ResolveResourceConfig(profile, definition, specID)
  if not definition then
    return nil
  end

  local revision = M._puiRuntimeConfigRevision or 0
  local cacheKey = definition.resourceKey
  local cached = M._puiResourceConfigCache[cacheKey]
  if cached
    and cached.profile == profile
    and cached.definition == definition
    and cached.specID == specID
    and cached.revision == revision
  then
    return cached.config
  end

  local shared = profile.secondary
  local settings = Secondary:GetResourceSettings(profile, definition.resourceKey, PLAYER_CLASS, specID)
  local appearance = settings
  local text = settings.text
  local font = settings.text
  local colorSource = settings

  local sourceStyle = appearance.style
  local sourceBehavior = settings.behavior
  local sourceCues = settings.cues
  local sourceAnchor = settings.anchor
  local customColor = CopyColor(
    colorSource.customColor or definition.defaultColor,
    1, 1, 1, 1
  )
  local stackColorThresholds
  if definition.adapter == "AURA_STACKS"
    and Secondary:ResourceSupportsStackColorShifts(definition.resourceKey)
  then
    local thresholds = AuraWidget.EnsureStackColorThresholds(settings)
    if thresholds and #thresholds > 0 then
      stackColorThresholds = {}
      for index = 1, #thresholds do
        local threshold = thresholds[index]
        stackColorThresholds[index] = {
          enabled = threshold.enabled == true,
          value = threshold.value,
          colorMode = threshold.colorMode,
          color = CopyColor(threshold.color, 1, 0.82, 0, 1),
        }
      end
    end
  end
  local dividerColor = CopyColor(
    settings.dividerColor or shared.dividerColor,
    0.20, 0.20, 0.24, 1
  )

  local config = {
    resourceKey = definition.resourceKey,
    specID = specID,
    visibilityMode = settings.visibilityMode,
    resourceName = RESOURCE_NAMES[definition.resourceKey] or definition.resourceKey,
    thresholdGlowKey = "PUI_PRD_THRESHOLD_" .. definition.resourceKey,
    detached = settings.detached == true,
    height = tonumber(appearance.height) or 15,
    width = tonumber(settings.width) or shared.width or profile.size.width or 240,
    anchor = {
      point = sourceAnchor.point,
      x = sourceAnchor.x,
      y = sourceAnchor.y,
    },
    perSegment = settings.perSegment == true,
    showApplicationsRemaining = settings.showApplicationsRemaining == true
      and APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[definition.resourceKey] ~= nil,
    applicationCountdownMax = tonumber(
      APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[definition.resourceKey]
    ) or 0,
    texture = appearance.texture,
    useCustomColor = colorSource.useCustomColor == true,
    useBlizzardPowerColor = colorSource.useBlizzardPowerColor ~= false,
    useClassColor = colorSource.useClassColor == true,
    customColor = customColor,
    stackColorThresholds = stackColorThresholds,
    style = {
      borderSize = tonumber(sourceStyle.borderSize) or 1,
      borderColor = CopyColor(sourceStyle.borderColor, 0.20, 0.20, 0.24, 1),
      bgColor = CopyColor(sourceStyle.bgColor, 0, 0, 0, 0.65),
    },
    text = {
      mode = text.mode or "CUR",
      showNumber = text.showNumber ~= false,
    },
    font = {
      font = font.font,
      size = tonumber(font.size) or 14,
      flags = font.flags or "",
      useGlobalFont = font.useGlobalFont == true,
    },
    inactiveAlpha = tonumber(settings.inactiveAlpha) or shared.inactiveAlpha or 0.15,
    showDividers = settings.showDividers ~= false,
    stackTickValues = settings.stackTickValues or "ALL",
    dividerSize = tonumber(settings.dividerSize) or shared.dividerSize or 1,
    dividerColor = dividerColor,
    showSpellIcon = settings.showSpellIcon == true and definition.auraSpellIDs ~= nil,
    iconGap = tonumber(settings.iconGap) or 2,
    iconSpellID = definition.auraSpellIDs and definition.auraSpellIDs[1] or nil,
    behavior = {
      showRechargeTime = sourceBehavior.showRechargeTime ~= false,
      showQueuedRuneTime = sourceBehavior.showQueuedRuneTime == true,
      showReadyGlow = sourceBehavior.showReadyGlow ~= false,
      completionAnimation = sourceBehavior.completionAnimation or "FADE",
      rechargeDirection = sourceBehavior.rechargeDirection or "LTR",
      useSeverityColors = sourceBehavior.useSeverityColors ~= false,
      showSeverityLabel = sourceBehavior.showSeverityLabel == true,
      yellowThreshold = tonumber(sourceBehavior.yellowThreshold) or 30,
      redThreshold = tonumber(sourceBehavior.redThreshold) or 60,
      fillCeiling = tonumber(sourceBehavior.fillCeiling) or 100,
      fillMode = sourceBehavior.fillMode or "STACKS",
      simpleRunes = sourceBehavior.simpleRunes == true,
      customRechargeColor = sourceBehavior.customRechargeColor == true,
      rechargeColor = CopyColor(sourceBehavior.rechargeColor, 0.5, 0.5, 0.5, 1),
      darkenPartial = sourceBehavior.darkenPartial == true,
      colorChargedPoints = PLAYER_CLASS == "ROGUE" and sourceBehavior.colorChargedPoints == true,
      chargedColor = CopyColor(sourceBehavior.chargedColor, 0.44, 0.77, 1, 1),
      fiveBarStyle = definition.resourceKey == "MAELSTROM_WEAPON" and sourceBehavior.fiveBarStyle == true,
      overflowColor = CopyColor(sourceBehavior.overflowColor, 1, 0.6, 0.2, 1),
    },
    cues = {
      desaturateMode = sourceCues.desaturateMode or "NONE",
      desaturateThreshold = tonumber(sourceCues.desaturateThreshold) or 0,
      glowMode = sourceCues.glowMode or "NONE",
      glowThreshold = tonumber(sourceCues.glowThreshold) or 0,
      glowType = sourceCues.glowType or "PIXEL",
      glowColor = CopyColor(sourceCues.glowColor, 1, 0.82, 0, 1),
      buffGlowSpellID = sourceCues.buffGlowEnabled == true and (tonumber(sourceCues.buffGlowSpellID) or 0) or 0,
      buffGlowColor = CopyColor(sourceCues.buffGlowColor, 0.25, 0.75, 1, 1),
    },
    supportsNumericCues = NUMERIC_CUE_RESOURCES[definition.resourceKey] == true,
    defaultColor = CopyColor(
      definition.defaultColorBySpec and definition.defaultColorBySpec[specID] or definition.defaultColor,
      1, 1, 1, 1
    ),
  }

  config.stateKey = BuildResourceConfigStateKey(config)
  config.structureKey = BuildResourceConfigStructureKey(config)
  M._puiResourceConfigCache[cacheKey] = {
    profile = profile,
    definition = definition,
    specID = specID,
    revision = revision,
    config = config,
  }
  return config
end

local function ResolveDefinitions()
  local candidates, specID = GetResolvedDefinitionCandidates()
  if not candidates then
    return nil, specID
  end

  local profile = M.db.profile
  local resources = {}

  for index = 1, #candidates do
    local definition = candidates[index]
    local appliesToSpec = type(definition.specIDs) ~= "table"
      or definition.specIDs[specID] == true

    if appliesToSpec and IsDefinitionEnabled(definition, profile, specID) then
      local resolvedMax = ResolveMaximum(definition, false, specID)
      local minimum = tonumber(definition.minRealMax) or 0

      if minimum <= 0 or resolvedMax >= minimum then
        local resolvedTexture = definition.textureBySpec
          and (definition.textureBySpec[specID] or definition.texture)
          or definition.texture

        local precisePower = definition.preciseResourceCount == true
        if definition.preciseResourceCountBySpec then
          precisePower = definition.preciseResourceCountBySpec[specID] == true
        end

        local currentDivisor = definition.currentDivisor or 1
        if definition.currentDivisorBySpec then
          currentDivisor = definition.currentDivisorBySpec[specID] or currentDivisor
        end

        resources[#resources + 1] = {
          definition = definition,
          adapter = Secondary.Adapters[definition.adapter],
          maximum = resolvedMax,
          texture = resolvedTexture,
          precisePower = precisePower == true,
          currentDivisor = currentDivisor,
          config = ResolveResourceConfig(profile, definition, specID),
        }
      end
    end
  end

  if #resources == 0 then
    return nil, specID
  end

  return resources, specID
end

local function IsResourceVisibilityAllowed(resource)
  if resource.definition.isAlternatePower == true then
    return true
  end

  local mode = resource.config.visibilityMode
  if mode == "COMBAT" then
    return UnitAffectingCombat("player") == true
  elseif mode == "TARGET" then
    return UnitExists("target") == true
  elseif mode == "COMBAT_OR_TARGET" then
    return UnitAffectingCombat("player") == true or UnitExists("target") == true
  end
  return true
end

function M:GetSecondaryDefinition()
  local profile = self.db.profile
  local revision = self._puiRuntimeConfigRevision or 0
  local configReady = self._puiSecondaryDefinitionReady == true
    and self._puiSecondaryDefinitionDirty ~= true
    and self._puiSecondaryDefinitionProfile == profile
    and self._puiSecondaryDefinitionRevision == revision
  if configReady and self._puiSecondaryVisibilityDirty ~= true then
    return self.secondaryDef
  end

  local resources, specID
  if configReady then
    resources, specID = self.secondaryResources, self.secondarySpecID
  else
    -- Spec events can reach the new profile before its deferred settings refresh.
    if profile.secondary.__puiSpecResourcesMigrated ~= true then
      Secondary:NormalizeProfile(profile)
    end
    resources, specID = ResolveDefinitions()
    resources = resources or {}
  end

  local hasVisibleResources = false
  for index = 1, #resources do
    local resource = resources[index]
    resource.visible = IsResourceVisibilityAllowed(resource)
    hasVisibleResources = hasVisibleResources or resource.visible
  end
  self._puiSecondaryHasVisibleResources = hasVisibleResources
  local primary = resources[1]
  local definition = primary and primary.definition or nil

  self.secondaryResources = resources
  self.secondaryResourceByKey = {}
  self.secondaryAdapters = {}

  local seenAdapters = {}
  for index = 1, #self.secondaryResources do
    local resource = self.secondaryResources[index]
    local resourceKey = resource.definition.resourceKey
    local adapter = resource.adapter

    resource.index = index
    self.secondaryResourceByKey[resourceKey] = resource

    if resource.visible and adapter and seenAdapters[adapter] ~= true then
      seenAdapters[adapter] = true
      self.secondaryAdapters[#self.secondaryAdapters + 1] = adapter
    end
  end

  self.secondaryDef = definition
  self.secondarySpecID = specID
  self.secondaryResolvedMax = primary and primary.maximum or 0
  self.secondaryTexture = primary and primary.texture or nil
  self.secondaryPowerPrecise = primary and primary.precisePower == true or false
  self.secondaryCurrentDivisor = primary and primary.currentDivisor or 1
  self.secondaryDisplayFloor = definition and definition.displayFloor == true or false
  self.secondaryAdapter = primary and primary.adapter or nil
  self.secondaryResourceConfig = primary and primary.config or nil
  self._puiSecColorDirty = true

  if self.secondary then
    self:AssignSecondaryResourceFrames()
  end

  self._puiSecondaryDefinitionProfile = profile
  self._puiSecondaryDefinitionRevision = revision
  self._puiSecondaryDefinitionDirty = nil
  self._puiSecondaryVisibilityDirty = nil
  self._puiSecondaryDefinitionReady = true

  return definition
end

function M:ResolveSecondaryType()
  local definition = self:GetSecondaryDefinition()
  if not definition then
    return nil, nil, 0
  end

  return definition.powerType, definition.token, self.secondaryResolvedMax
end

Secondary.RegisterAdapter = P:Def("RegisterAdapter", Secondary.RegisterAdapter)
IsDefinitionEnabled = P:Def("IsDefinitionEnabled", IsDefinitionEnabled)
ResolveMaximum = P:Def("ResolveMaximum", ResolveMaximum)
Secondary.ResolveMaximum = ResolveMaximum
IsResourceVisibilityAllowed = P:Def("IsResourceVisibilityAllowed", IsResourceVisibilityAllowed)
BuildResourceConfigStateKey = P:Def("BuildResourceConfigStateKey", BuildResourceConfigStateKey)
BuildResourceConfigStructureKey = P:Def(
  "BuildResourceConfigStructureKey",
  BuildResourceConfigStructureKey
)
CopyColor = P:Def("CopyColor", CopyColor)
ResolveResourceConfig = P:Def("ResolveResourceConfig", ResolveResourceConfig)
ResolveDefinitions = P:Def("ResolveDefinitions", ResolveDefinitions)
M.GetSecondaryDefinition = P:Def("GetSecondaryDefinition", M.GetSecondaryDefinition)
M.ResolveSecondaryType = P:Def("ResolveSecondaryType", M.ResolveSecondaryType)
