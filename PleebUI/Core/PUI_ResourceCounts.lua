local _, ns = ...
local Addon = ns.Addon
local Counts = {}
ns.ResourceCounts = Counts

Counts.ViewerDefaults = {
  cooldown = true,
  buff = true,
  charge = true,
  keybind = true,
}

local function GetCurrentSpecializationID()
  local specializationIndex = GetSpecialization()
  if not specializationIndex then
    return nil
  end
  return GetSpecializationInfo(specializationIndex)
end

local function GetProfileRoot(create)
  local db = Addon.db
  local profile = db and db.profile
  if not profile then
    return nil
  end

  local root = profile.cooldownManager
  if not root and create then
    root = {}
    profile.cooldownManager = root
  end
  return root
end

function Counts:GetStore(create)
  local root = GetProfileRoot(create)
  if not root then return nil end
  local counts = root.resourceCounts
  if not counts then
    if not create then return nil end
    counts = {}
    root.resourceCounts = counts
  end
  if root.__puiSpecResourceCountsMigrated ~= true then
    local legacy = {}
    for key, value in pairs(counts) do
      if type(key) == "string" then legacy[key] = value end
    end
    if next(legacy) then
      for _, spec in ipairs(ns.ResourceSettings.Specializations) do
        local settings = counts[spec.id] or {}
        counts[spec.id] = settings
        for key, value in pairs(legacy) do
          if settings[key] == nil then settings[key] = value end
        end
      end
      for key in pairs(legacy) do counts[key] = nil end
    end
    root.__puiSpecResourceCountsMigrated = true
  end
  local specID = GetCurrentSpecializationID()
  if not specID then return nil end
  local settings = counts[specID]
  if not settings and create then
    settings = {}
    counts[specID] = settings
  end
  return settings
end

local function GetViewerChargeDefault(root, viewerKey)
  local settings = root and root.count and root.count[viewerKey]
  if not settings then return true end
  if settings.charge == nil and not settings.__puiSeeded then return true end
  return settings.charge == true
end

function Counts:GetEnabled(resourceKey)
  if ns.Modules.CooldownManager then
    return ns.PCMIconSettings:GetResourceCountEnabled(resourceKey)
  end
  local settings = self:GetStore(false)
  if settings and settings[resourceKey] ~= nil then return settings[resourceKey] end
  local root = GetProfileRoot(false)
  return GetViewerChargeDefault(root, "EssentialCooldownViewer")
    or GetViewerChargeDefault(root, "UtilityCooldownViewer")
end

function Counts:SetEnabled(resourceKey, enabled)
  if ns.Modules.CooldownManager then
    ns.PCMIconSettings:SetResourceCountEnabled(resourceKey, enabled)
    return
  end
  self:GetStore(true)[resourceKey] = enabled == true
  local root = GetProfileRoot(true)
  local specID = GetCurrentSpecializationID()
  root.__puiPendingResourceCounts = root.__puiPendingResourceCounts or {}
  local pending = root.__puiPendingResourceCounts
  pending[specID] = pending[specID] or {}
  pending[specID][resourceKey] = true
end
