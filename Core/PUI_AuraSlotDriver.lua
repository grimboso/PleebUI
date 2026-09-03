local _, ns = ...

local AuraSlotDriver = {}
ns.AuraSlotDriver = AuraSlotDriver

local CreateFrame = CreateFrame
local UIParent = UIParent

local RETIRED_CANDIDATES = {
  includeSpellIDs = {
    [0] = true,
  },
}

local unitRuntimes = {}
local sequence = 0
local targetDriver = CreateFrame("Frame")

local function EnsureUnitRuntime(unit)
  local runtime = unitRuntimes[unit]
  if runtime then
    return runtime
  end

  local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
  container:SetSize(1, 1)
  container:SetUnit(unit)
  container:SetEnabled(false)
  container:Hide()

  runtime = {
    unit = unit,
    container = container,
    activeSlots = 0,
  }
  unitRuntimes[unit] = runtime
  return runtime
end

local function UpdateTargetDriver()
  local runtime = unitRuntimes.target
  if runtime and runtime.activeSlots > 0 then
    targetDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
    targetDriver:RegisterUnitEvent("UNIT_FACTION", "target")
    targetDriver:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", "target")
  else
    targetDriver:UnregisterEvent("PLAYER_TARGET_CHANGED")
    targetDriver:UnregisterEvent("UNIT_FACTION")
    targetDriver:UnregisterEvent("UNIT_TARGETABLE_CHANGED")
  end
end

local function UpdateUnitRuntime(runtime)
  local active = runtime.activeSlots > 0
  runtime.container:SetEnabled(active)
  runtime.container:SetShown(active)

  if runtime.unit == "target" then
    UpdateTargetDriver()
  end
end

function AuraSlotDriver:CreateSlot(unit, filter, options)
  local runtime = EnsureUnitRuntime(unit)
  sequence = sequence + 1

  local key = "pui_shared_aura_slot_" .. tostring(sequence)
  local slot = runtime.container:AddAuraSlot(key, filter, options)

  return {
    runtime = runtime,
    container = runtime.container,
    unit = unit,
    key = key,
    slot = slot,
    filter = filter,
    active = false,
  }
end

function AuraSlotDriver:SetSlotFilter(handle, filter)
  if handle.filter == filter then
    return
  end

  handle.filter = filter
  handle.container:SetAuraSlotFilterString(handle.key, filter)
end

function AuraSlotDriver:SetSlotCandidates(handle, candidateFilters)
  handle.container:SetAuraSlotCandidateFilters(handle.key, candidateFilters)
end

function AuraSlotDriver:SetSlotActive(handle, active)
  active = active == true
  if handle.active == active then
    return
  end

  local runtime = handle.runtime
  if active then
    runtime.activeSlots = runtime.activeSlots + 1
  else
    runtime.activeSlots = math.max(0, runtime.activeSlots - 1)
    handle.container:SetAuraSlotCandidateFilters(handle.key, RETIRED_CANDIDATES)
  end

  handle.active = active
  UpdateUnitRuntime(runtime)
end

function AuraSlotDriver:RefreshUnit(unit)
  local runtime = unitRuntimes[unit]
  if runtime and runtime.activeSlots > 0 then
    runtime.container:UpdateAllAuras()
  end
end

targetDriver:SetScript("OnEvent", function()
  AuraSlotDriver:RefreshUnit("target")
end)
local P = select(1, ns.Pleebug:DropIn(AuraSlotDriver, { name = "Core.AuraSlotDriver" }))
EnsureUnitRuntime = P:Def("AuraSlotDriver.EnsureUnitRuntime", EnsureUnitRuntime)
UpdateTargetDriver = P:Def("AuraSlotDriver.UpdateTargetDriver", UpdateTargetDriver)
UpdateUnitRuntime = P:Def("AuraSlotDriver.UpdateUnitRuntime", UpdateUnitRuntime)
AuraSlotDriver.CreateSlot = P:Def("AuraSlotDriver:CreateSlot", AuraSlotDriver.CreateSlot)
AuraSlotDriver.SetSlotFilter = P:Def("AuraSlotDriver:SetSlotFilter", AuraSlotDriver.SetSlotFilter)
AuraSlotDriver.SetSlotCandidates = P:Def("AuraSlotDriver:SetSlotCandidates", AuraSlotDriver.SetSlotCandidates)
AuraSlotDriver.SetSlotActive = P:Def("AuraSlotDriver:SetSlotActive", AuraSlotDriver.SetSlotActive)
AuraSlotDriver.RefreshUnit = P:Def("AuraSlotDriver:RefreshUnit", AuraSlotDriver.RefreshUnit)
