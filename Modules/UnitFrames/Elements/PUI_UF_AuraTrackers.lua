local _, ns = ...

local AuraTrackers = {}
ns.UFAuraTrackers = AuraTrackers

local AuraContainers = ns.UFAuraContainers
local AuraFilters = ns.UFAuraFilters

local function BuildSlotOptions(
  container,
  display,
  layout,
  candidateFilters,
  appearance
)
  local options = {
    __puiAuraKind = display.auraType == "HARMFUL" and "debuffs" or "buffs",
    __puiAuraAppearance = appearance,
    size = layout.size,
    candidateFilters = candidateFilters,
    sortMethod = AuraContainers.GetSortMethod(display),
    sortDirection = AuraContainers.GetSortDirection(display),
  }

  options.initializeFrame = function(button)
    AuraContainers.InitializeAuraButton(container, options, button)
    AuraContainers.ApplySlotButtonLayout(button, layout)
  end

  return options
end

function AuraTrackers.CreateRuntime(frame, auraDB, display, sharedHost)
  local layout = AuraContainers.BuildDisplayLayout(frame, display)
  local appearance = AuraFilters.BuildEffectiveAppearance(auraDB, display)
  local candidateFilters = AuraFilters.BuildCandidateFilters(display)
  local filterString = AuraFilters.BuildFilterString(display)
  local container = sharedHost
    and sharedHost.container
    or AuraContainers.CreateAuraElement(frame, layout, appearance)
  local runtime = {
    container = container,
    displayType = "slot",
    enabled = nil,
    shown = nil,
    filterString = filterString,
    candidateSignature = AuraFilters.BuildCandidateFilterSignature(display),
    sortMethod = AuraContainers.GetSortMethod(display),
    sortDirection = AuraContainers.GetSortDirection(display),
    configuredEnabled = nil,
  }

  if sharedHost then
    AuraContainers.RegisterSharedRuntime(sharedHost, runtime)
  end

  runtime.options = BuildSlotOptions(
    container,
    display,
    layout,
    candidateFilters,
    appearance
  )
  runtime.key = container:AddSlot(filterString, runtime.options)

  return runtime
end

function AuraTrackers.ConfigureRuntime(auraDB, display, runtime)
  local candidateSignature = AuraFilters.BuildCandidateFilterSignature(display)
  local filterString = AuraFilters.BuildFilterString(display)
  local sortMethod = AuraContainers.GetSortMethod(display)
  local sortDirection = AuraContainers.GetSortDirection(display)
  local container = runtime.container

  runtime.configuredEnabled = AuraContainers.IsDisplayEnabled(auraDB, display)

  if runtime.filterString ~= filterString then
    runtime.filterString = filterString
    container:SetAuraSlotFilterString(runtime.key, filterString)
  end

  if runtime.candidateSignature ~= candidateSignature then
    runtime.candidateSignature = candidateSignature
    runtime.options.candidateFilters = AuraFilters.BuildCandidateFilters(display)

    if not runtime.candidatesRetired then
      container:SetAuraSlotCandidateFilters(runtime.key, runtime.options.candidateFilters)
    end
  end

  if runtime.sortMethod ~= sortMethod or runtime.sortDirection ~= sortDirection then
    runtime.sortMethod = sortMethod
    runtime.sortDirection = sortDirection
    runtime.options.sortMethod = sortMethod
    runtime.options.sortDirection = sortDirection
    container:SetAuraSlotSortMethod(runtime.key, sortMethod, sortDirection)
  end
end

local P = select(1, ns.Pleebug:DropIn(AuraTrackers, { name = "UnitFrames.AuraTrackers" }))
BuildSlotOptions = P:Def("BuildSlotOptions", BuildSlotOptions)
AuraTrackers.CreateRuntime = P:Def("AuraTrackers.CreateRuntime", AuraTrackers.CreateRuntime)
AuraTrackers.ConfigureRuntime = P:Def("AuraTrackers.ConfigureRuntime", AuraTrackers.ConfigureRuntime)
