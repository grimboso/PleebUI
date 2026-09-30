local _, ns = ...

local AbilityRuntime = {}
ns.PCMAbilityRuntime = AbilityRuntime

local AbilityCatalog = ns.PCMAbilityCatalog
local AbilityLayout = ns.PCMAbilityLayout
local PCMPresentation = ns.PCMPresentation
local IconSettings = ns.PCMIconSettings
local PCMKeybinds = ns.PCMKeybinds
local AuraSlotDriver = ns.AuraSlotDriver

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local C_Item = C_Item
local C_Secrets = C_Secrets
local C_Spell = C_Spell
local C_SpellActivationOverlay = C_SpellActivationOverlay
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetInventoryItemID = GetInventoryItemID
local GetNumTotemSlots = GetNumTotemSlots
local GetTotemInfo = GetTotemInfo
local GetTotemDuration = GetTotemDuration
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue
local pairs = pairs
local ipairs = ipairs
local type = type
local wipe = wipe
local bit_band = bit.band
local bit_bor = bit.bor

local ESSENTIAL_VIEWER = "EssentialCooldownViewer"
local UTILITY_VIEWER = "UtilityCooldownViewer"

local DIRTY_STATE = 0x01
local DIRTY_APPEARANCE = 0x02
local DIRTY_VISIBILITY = 0x04
local DIRTY_LAYOUT = 0x08
local DIRTY_ALL = bit_bor(DIRTY_STATE, DIRTY_APPEARANCE, DIRTY_VISIBILITY, DIRTY_LAYOUT)

local STATE_COOLDOWN = 0x001
local STATE_CHARGE = 0x002
local STATE_USABLE = 0x004
local STATE_RANGE = 0x008
local STATE_PROC = 0x010
local STATE_TOTEM = 0x020
local STATE_EQUIPMENT = 0x040
local STATE_ITEM = 0x080
local STATE_KEYBIND = 0x100
local STATE_ALL = 0x1FF

local APPEARANCE_STYLE = 0x01
local APPEARANCE_ICON = 0x02
local APPEARANCE_KEYBIND = 0x04
local APPEARANCE_ALL = bit_bor(APPEARANCE_STYLE, APPEARANCE_ICON, APPEARANCE_KEYBIND)

AbilityRuntime.DIRTY_STATE = DIRTY_STATE
AbilityRuntime.DIRTY_APPEARANCE = DIRTY_APPEARANCE
AbilityRuntime.DIRTY_VISIBILITY = DIRTY_VISIBILITY
AbilityRuntime.DIRTY_LAYOUT = DIRTY_LAYOUT
AbilityRuntime.DIRTY_ALL = DIRTY_ALL

local enabled = false
local readyNotified = false
local presentationActive = false
local groupLayoutEnabled = false
local groupLayoutReady = false
local activeByCooldownID = {}
local retiredByCooldownID = {}
local verifiedTotemSlots = {}
local rangeSpellRefCounts = {}

local viewers = {
  [ESSENTIAL_VIEWER] = {
    key = ESSENTIAL_VIEWER,
    frame = nil,
    parent = nil,
    entries = {},
    orderedRuntimes = {},
    generation = 0,
    pendingEntries = nil,
    pendingGeneration = nil,
    resolvedStyle = nil,
    layoutDirty = false,
  },
  [UTILITY_VIEWER] = {
    key = UTILITY_VIEWER,
    frame = nil,
    parent = nil,
    entries = {},
    orderedRuntimes = {},
    generation = 0,
    pendingEntries = nil,
    pendingGeneration = nil,
    resolvedStyle = nil,
    layoutDirty = false,
  },
}

local buckets = {}

local function CreateBucket(stateMask)
  return {
    records = {},
    count = 0,
    stateMask = stateMask,
  }
end

buckets.cooldown = CreateBucket(STATE_COOLDOWN)
buckets.charge = CreateBucket(STATE_CHARGE)
buckets.usable = CreateBucket(STATE_USABLE)
buckets.range = CreateBucket(STATE_RANGE)
buckets.proc = CreateBucket(STATE_PROC)
buckets.totem = CreateBucket(STATE_TOTEM)
buckets.equipment = CreateBucket(bit_bor(STATE_EQUIPMENT, STATE_ITEM, STATE_KEYBIND))
buckets.item = CreateBucket(bit_bor(STATE_ITEM, STATE_KEYBIND))
buckets.keybind = CreateBucket(STATE_KEYBIND)
buckets.spellAppearance = CreateBucket(0)

local dirtyQueue = {}
local dirtyHead = 1
local dirtyTail = 0

local eventFrame = CreateFrame("Frame")
local flushFrame = CreateFrame("Frame")
flushFrame:Hide()

local registeredEvents = {}
local eventRegistrationsDirty = true

local SPELL_CATEGORY_ICONS = {
  [4] = "Interface\\Icons\\INV_POTION_114",
  [30] = "Interface\\Icons\\INV_POTION_54",
  [1711] = "Interface\\Icons\\Warlock_ Healthstone",
  [2566] = "Interface\\Icons\\Warlock_ Bloodstone",
}

local RUNTIME_EVENTS = {
  "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
  "SPELL_UPDATE_COOLDOWN",
  "SPELL_UPDATE_CHARGES",
  "SPELL_UPDATE_USES",
  "SPELL_UPDATE_ICON",
  "SPELL_UPDATE_USABLE",
  "SPELL_RANGE_CHECK_UPDATE",
  "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
  "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
  "PLAYER_TOTEM_UPDATE",
  "BAG_UPDATE_COOLDOWN",
  "ITEM_LOCK_CHANGED",
  "ITEM_PUSH",
  "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_REGEN_ENABLED",
  "ADDON_RESTRICTION_STATE_CHANGED",
}

local AURA_RESTRICTION_TYPES = {
  [Enum.AddOnRestrictionType.Combat] = true,
  [Enum.AddOnRestrictionType.Encounter] = true,
  [Enum.AddOnRestrictionType.ChallengeMode] = true,
  [Enum.AddOnRestrictionType.PvPMatch] = true,
  [Enum.AddOnRestrictionType.Map] = true,
}

local function IsSecret(value)
  return issecretvalue(value) == true
end

local function HasMask(mask, flag)
  return bit_band(mask, flag) ~= 0
end

local function IsViewerKey(viewerKey)
  return viewerKey == ESSENTIAL_VIEWER or viewerKey == UTILITY_VIEWER
end

local function GetViewer(viewerKey)
  if IsViewerKey(viewerKey) then
    return viewers[viewerKey]
  end
  return nil
end

local function AddBucketRecord(bucket, record)
  local cooldownID = record.cooldownID
  if bucket.records[cooldownID] then
    return
  end
  bucket.records[cooldownID] = record
  bucket.count = bucket.count + 1
  eventRegistrationsDirty = true
end

local function RemoveBucketRecord(bucket, record)
  local cooldownID = record.cooldownID
  if not bucket.records[cooldownID] then
    return
  end
  bucket.records[cooldownID] = nil
  bucket.count = bucket.count - 1
  eventRegistrationsDirty = true
end

local function RemoveRecordFromBuckets(record)
  for _, bucket in pairs(buckets) do
    RemoveBucketRecord(bucket, record)
  end
end

local function ScheduleFlush()
  if enabled then
    flushFrame:Show()
  end
end

local function QueueRecord(record)
  if record.queued then
    return
  end
  record.queued = true
  dirtyTail = dirtyTail + 1
  dirtyQueue[dirtyTail] = record
  ScheduleFlush()
end

local function MarkRecordDirty(record, dirtyMask, stateMask, appearanceMask)
  record.dirtyMask = bit_bor(record.dirtyMask or 0, dirtyMask)
  if stateMask and stateMask ~= 0 then
    record.stateDirtyMask = bit_bor(record.stateDirtyMask or 0, stateMask)
  end
  if HasMask(dirtyMask, DIRTY_APPEARANCE) then
    record.appearanceDirtyMask = bit_bor(
      record.appearanceDirtyMask or 0,
      appearanceMask or APPEARANCE_ALL
    )
  end
  if HasMask(dirtyMask, DIRTY_LAYOUT) then
    local viewer = viewers[record.viewerKey]
    if viewer then
      viewer.layoutDirty = true
    end
  end
  QueueRecord(record)
end

local function MarkBucket(bucketName, dirtyMask, explicitStateMask, appearanceMask)
  local bucket = buckets[bucketName]
  if not bucket then
    return
  end
  local stateMask = explicitStateMask or bucket.stateMask
  for _, record in pairs(bucket.records) do
    MarkRecordDirty(record, dirtyMask, stateMask, appearanceMask)
  end
end

local function DisableRangeRegistration(record)
  local spellID = record.registeredRangeSpellID
  if spellID then
    local count = (rangeSpellRefCounts[spellID] or 1) - 1
    if count <= 0 then
      rangeSpellRefCounts[spellID] = nil
      C_Spell.EnableSpellRangeCheck(spellID, false)
    else
      rangeSpellRefCounts[spellID] = count
    end
    record.registeredRangeSpellID = nil
  end
end

local function AssignRuntimeSpellIDs(record)
  local entry = record.entry
  if entry.entryKind ~= "spell" then
    record.runtimeSpellID = nil
    record.runtimeChargeSpellID = nil
    return false
  end

  local runtimeSpellID = entry.overrideTooltipSpellID
    or record.runtimeOverrideSpellID
    or entry.baseSpellID
    or entry.staticDisplaySpellID
  if record.runtimeTotemSpellID then
    runtimeSpellID = record.runtimeTotemSpellID
  end
  local runtimeChargeSpellID = record.runtimeOverrideSpellID
    or entry.baseSpellID
    or entry.chargeSpellID

  local changed = record.runtimeSpellID ~= runtimeSpellID
    or record.runtimeChargeSpellID ~= runtimeChargeSpellID
  if changed and record.runtimeSpellID then
    record.previousRuntimeSpellID = record.runtimeSpellID
  end
  record.runtimeSpellID = runtimeSpellID
  record.runtimeChargeSpellID = runtimeChargeSpellID
  return changed
end

local function ConfigureRangeRegistration(record)
  DisableRangeRegistration(record)
  RemoveBucketRecord(buckets.range, record)

  local entry = record.entry
  if entry.entryKind ~= "spell" then
    return
  end

  local spellID = record.runtimeSpellID
  if not spellID then
    return
  end

  local hasRange = C_Spell.SpellHasRange(spellID)
  if not IsSecret(hasRange) and hasRange == true then
    local count = rangeSpellRefCounts[spellID] or 0
    if count == 0 then
      C_Spell.EnableSpellRangeCheck(spellID, true)
    end
    rangeSpellRefCounts[spellID] = count + 1
    record.registeredRangeSpellID = spellID
    AddBucketRecord(buckets.range, record)
  end
end

local function DeactivateAuraSlots(record)
  local auraSlots = record.auraSlots
  if not auraSlots then
    return
  end

  for _, handle in pairs(auraSlots) do
    if handle then
      AuraSlotDriver:SetSlotActive(handle, false)
    end
  end
end

local function BuildCandidateSet(record)
  local includeSpellIDs = {}
  local spellIDs = record.entry.identitySpellIDs
  if spellIDs then
    for _, spellID in ipairs(spellIDs) do
      includeSpellIDs[spellID] = true
    end
  end
  if record.runtimeSpellID then
    includeSpellIDs[record.runtimeSpellID] = true
  end
  return includeSpellIDs
end

local function ResolveRecordStyle(record)
  local viewer = viewers[record.viewerKey]
  local style = IconSettings:ResolveOwnedStyle(
    record.entry,
    record.viewerKey,
    viewer.resolvedStyle
  )
  record.resolvedStyle = style
  return style
end

local function GetRecordStyle(record)
  return record.resolvedStyle or ResolveRecordStyle(record)
end

local function GetAuraFilter(unit)
  if unit == "player" then
    return "HELPFUL|PLAYER"
  end
  return "HARMFUL|PLAYER"
end

local function CanRestyleAuraButton(button)
  return not InCombatLockdown()
    and C_Secrets.ShouldAurasBeSecret() ~= true
    and button:CanBeAccessedInContext()
end

local function PrepareAuraButtonsForRestriction(restrictionType, state)
  if state ~= Enum.AddOnRestrictionState.Activating
    or AURA_RESTRICTION_TYPES[restrictionType] ~= true
  then
    return
  end

  for _, record in pairs(activeByCooldownID) do
    for _, button in pairs(record.auraButtons) do
      if button and button:CanBeAccessedInContext() then
        button:SetAlpha(1)
        record.auraStylePending = true
      end
    end
  end
end

local function ApplyAuraButtonStyle(record, button, unit, initializing)
  if initializing ~= true and not CanRestyleAuraButton(button) then
    record.auraStylePending = true
    return
  end

  PCMPresentation.ConfigureOwnedAuraLayer(
    record.parts,
    button,
    unit,
    GetRecordStyle(record)
  )
  record.auraStylePending = nil
end

local function ConfigureAuraSlot(record, unit, includeSpellIDs)
  local handle = record.auraSlots[unit]
  local hasCandidates = includeSpellIDs and next(includeSpellIDs) ~= nil

  if not hasCandidates then
    if handle then
      AuraSlotDriver:SetSlotActive(handle, false)
    end
    return
  end

  local filter = GetAuraFilter(unit)
  if not handle then
    handle = AuraSlotDriver:CreateSlot(unit, filter, {
      candidateFilters = {
        includeSpellIDs = includeSpellIDs,
      },
      templateNames = {
        "PUI_AuraApplicationDurationTemplate",
      },
      initializeFrame = function(button)
        record.auraButtons[unit] = button
        ApplyAuraButtonStyle(record, button, unit, true)
      end,
    })
    record.auraSlots[unit] = handle
  else
    AuraSlotDriver:SetSlotFilter(handle, filter)
    AuraSlotDriver:SetSlotCandidates(handle, {
      includeSpellIDs = includeSpellIDs,
    })
  end

  AuraSlotDriver:SetSlotActive(handle, enabled and presentationActive)
end

local function ConfigureAuraSlots(record)
  local entry = record.entry
  local style = GetRecordStyle(record)
  local swipe = style.swipe or {}
  local viewerSwipe = style.viewerSwipe or {}
  local useAuraLayer = swipe.source ~= "COOLDOWN"
  if swipe.source == nil then
    if viewerSwipe.forceCooldownSwipe == true then
      useAuraLayer = false
    elseif viewerSwipe.duration == false and style.viewerDurationCount == false then
      useAuraLayer = false
    end
  end

  if not enabled
    or not presentationActive
    or verifiedTotemSlots[record.cooldownID]
    or entry.hasAura ~= true
    or entry.hideAura == true
    or not useAuraLayer
  then
    DeactivateAuraSlots(record)
    return
  end

  if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() == true then
    record.auraStylePending = true
    return
  end

  for _, button in pairs(record.auraButtons) do
    if button and not button:CanBeAccessedInContext() then
      record.auraStylePending = true
      return
    end
  end

  local candidates = BuildCandidateSet(record)
  ConfigureAuraSlot(record, "player", candidates)
  ConfigureAuraSlot(record, "target", candidates)
end

local function QueuePendingAuraStyles()
  if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() == true then
    return
  end

  for _, record in pairs(activeByCooldownID) do
    if record.auraStylePending then
      MarkRecordDirty(record, DIRTY_APPEARANCE, 0, APPEARANCE_STYLE)
    end
  end

  if viewers[ESSENTIAL_VIEWER].pendingEntries
    or viewers[UTILITY_VIEWER].pendingEntries
  then
    ScheduleFlush()
  end
end

local function RefreshRuntimeSpellIdentity(record)
  if not AssignRuntimeSpellIDs(record) then
    return false
  end

  ConfigureRangeRegistration(record)
  ConfigureAuraSlots(record)
  MarkRecordDirty(
    record,
    bit_bor(DIRTY_STATE, DIRTY_APPEARANCE),
    bit_bor(STATE_COOLDOWN, STATE_CHARGE, STATE_USABLE, STATE_RANGE, STATE_PROC),
    bit_bor(APPEARANCE_ICON, APPEARANCE_KEYBIND)
  )
  return true
end

local function SetTotemSpellIdentity(record, spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" or spellID <= 0 then
    return false
  end

  if record.runtimeTotemSpellID == spellID then
    return false
  end

  record.runtimeTotemSpellID = spellID
  RefreshRuntimeSpellIdentity(record)
  return true
end

local function ApplySpellOverride(baseSpellID, overrideSpellID)
  if IsSecret(baseSpellID) or type(baseSpellID) ~= "number" then
    return
  end
  if overrideSpellID ~= nil then
    if IsSecret(overrideSpellID)
      or type(overrideSpellID) ~= "number"
      or overrideSpellID <= 0
    then
      return
    end
  end

  for _, record in pairs(buckets.spellAppearance.records) do
    if record.entry.baseSpellID == baseSpellID then
      record.runtimeOverrideSpellID = overrideSpellID
      RefreshRuntimeSpellIdentity(record)
    end
  end
end

local function RecordMatchesSpellIdentity(record, spellID, baseSpellID)
  if record.runtimeSpellID == spellID
    or record.runtimeSpellID == baseSpellID
    or record.previousRuntimeSpellID == spellID
    or record.previousRuntimeSpellID == baseSpellID
    or record.runtimeChargeSpellID == spellID
    or record.runtimeChargeSpellID == baseSpellID
  then
    return true
  end

  local identitySpellIDs = record.entry.identitySpellIDs
  for index = 1, #identitySpellIDs do
    local identitySpellID = identitySpellIDs[index]
    if identitySpellID == spellID or identitySpellID == baseSpellID then
      return true
    end
  end
  return false
end

local function MarkProcRecordsForSpell(spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" then
    MarkBucket("proc", DIRTY_STATE, STATE_PROC)
    return
  end

  local baseSpellID = C_Spell.GetBaseSpell(spellID)
  if IsSecret(baseSpellID) or type(baseSpellID) ~= "number" then
    MarkBucket("proc", DIRTY_STATE, STATE_PROC)
    return
  end

  for _, record in pairs(buckets.proc.records) do
    if RecordMatchesSpellIdentity(record, spellID, baseSpellID) then
      MarkRecordDirty(record, DIRTY_STATE, STATE_PROC)
    end
  end
end

local function IsAnyIdentityOverlayed(record)
  local runtimeSpellID = record.runtimeSpellID
  if runtimeSpellID then
    local overlayed = C_SpellActivationOverlay.IsSpellOverlayed(runtimeSpellID)
    if not IsSecret(overlayed) and overlayed == true then
      return true
    end
  end

  local identitySpellIDs = record.entry.identitySpellIDs
  for index = 1, #identitySpellIDs do
    local spellID = identitySpellIDs[index]
    if spellID ~= runtimeSpellID then
      local overlayed = C_SpellActivationOverlay.IsSpellOverlayed(spellID)
      if not IsSecret(overlayed) and overlayed == true then
        return true
      end
    end
  end
  return false
end

local function GetUniqueActiveRecordForSpellID(spellID)
  local baseSpellID = C_Spell.GetBaseSpell(spellID)
  if IsSecret(baseSpellID) or type(baseSpellID) ~= "number" then
    return nil, false
  end

  local found
  for _, record in pairs(activeByCooldownID) do
    if RecordMatchesSpellIdentity(record, spellID, baseSpellID) then
      if found and found ~= record then
        return nil, true
      end
      found = record
    end
  end
  return found, false
end

local function ConfigureRecordBuckets(record)
  RemoveRecordFromBuckets(record)
  DisableRangeRegistration(record)

  local entry = record.entry
  AssignRuntimeSpellIDs(record)
  if entry.entryKind == "spell" then
    AddBucketRecord(buckets.cooldown, record)
    AddBucketRecord(buckets.usable, record)
    AddBucketRecord(buckets.proc, record)
    AddBucketRecord(buckets.keybind, record)
    AddBucketRecord(buckets.spellAppearance, record)
    if entry.charges == true then
      AddBucketRecord(buckets.charge, record)
    end
    ConfigureRangeRegistration(record)
  elseif entry.entryKind == "equipmentSlot" then
    AddBucketRecord(buckets.equipment, record)
    AddBucketRecord(buckets.item, record)
    AddBucketRecord(buckets.keybind, record)
  elseif entry.entryKind == "spellCategory" then
    AddBucketRecord(buckets.item, record)
    AddBucketRecord(buckets.keybind, record)
  end

  if verifiedTotemSlots[record.cooldownID] then
    AddBucketRecord(buckets.totem, record)
  end
end

local function RefreshTotemBindings()
  local bestByCooldownID = {}
  local slotCount = GetNumTotemSlots()
  if IsSecret(slotCount) or type(slotCount) ~= "number" then
    return
  end

  for slot = 1, slotCount do
    if GetTotemDuration(slot) ~= nil then
      local spellID = select(7, GetTotemInfo(slot))
      if IsSecret(spellID) then
        return
      end

      if type(spellID) == "number" then
        local record, ambiguous = GetUniqueActiveRecordForSpellID(spellID)
        if record and not ambiguous then
          bestByCooldownID[record.cooldownID] = {
            slot = slot,
            spellID = spellID,
          }
        end
      end
    end
  end

  for cooldownID, slot in pairs(verifiedTotemSlots) do
    local best = bestByCooldownID[cooldownID]
    if not best or best.slot ~= slot then
      verifiedTotemSlots[cooldownID] = nil
      local record = activeByCooldownID[cooldownID]
      if record then
        RemoveBucketRecord(buckets.totem, record)
        record.totemActive = nil
        PCMPresentation.SetTotemDuration(record.parts, nil)
        local hadTotemSpell = record.runtimeTotemSpellID ~= nil
        record.runtimeTotemSpellID = nil
        if hadTotemSpell then
          RefreshRuntimeSpellIdentity(record)
        else
          ConfigureAuraSlots(record)
        end
        MarkRecordDirty(
          record,
          DIRTY_STATE,
          bit_bor(STATE_COOLDOWN, STATE_CHARGE)
        )
      end
    end
  end

  for cooldownID, best in pairs(bestByCooldownID) do
    verifiedTotemSlots[cooldownID] = best.slot
    local record = activeByCooldownID[cooldownID]
    if record then
      SetTotemSpellIdentity(record, best.spellID)
      AddBucketRecord(buckets.totem, record)
      DeactivateAuraSlots(record)
      MarkRecordDirty(record, DIRTY_STATE, STATE_TOTEM)
    end
  end
end

local function AcquireParts(parent)
  return PCMPresentation.CreateOwnedIcon(parent)
end

local function GetSafeSpellTexture(spellID, fallback)
  local iconID, _, conditionalIconID = C_Spell.GetSpellTexture(spellID)
  if not IsSecret(conditionalIconID) and conditionalIconID ~= nil then
    return conditionalIconID
  end
  if not IsSecret(iconID) and iconID ~= nil then
    return iconID
  end
  return fallback
end

local function GetSafeItemTexture(itemID, fallback)
  local texture = C_Item.GetItemIconByID(itemID)
  if not IsSecret(texture) and texture ~= nil then
    return texture
  end
  return fallback
end

local function RefreshSpellAppearance(record)
  local entry = record.entry
  local texture = entry.staticIcon or entry.texture
  if entry.entryKind == "spell" and record.runtimeSpellID then
    local textureSpellID = record.runtimeTotemSpellID
      or entry.overrideTooltipSpellID
      or record.runtimeSpellID
      or entry.baseSpellID
    texture = GetSafeSpellTexture(textureSpellID, texture)
  elseif entry.entryKind == "equipmentSlot" then
    local itemID = record.safeContent.equippedItemID
    if itemID then
      texture = GetSafeItemTexture(itemID, texture)
    end
  elseif entry.entryKind == "spellCategory" then
    local itemID = record.safeContent.categoryItemID
    local spellID = record.safeContent.categorySpellID
    if itemID then
      texture = GetSafeItemTexture(itemID, texture)
    elseif spellID then
      texture = GetSafeSpellTexture(spellID, texture)
    else
      texture = SPELL_CATEGORY_ICONS[entry.spellCategoryID]
    end
  end
  PCMPresentation.SetStaticIcon(record.parts, texture)
end

local function RefreshEquipmentContent(record)
  local equipSlot = record.entry.equipSlot
  if not equipSlot then
    record.safeContent.equippedItemID = nil
    return
  end

  local itemID = GetInventoryItemID("player", equipSlot)
  if IsSecret(itemID) then
    return
  end

  record.safeContent.equippedItemID = itemID
end

local function RefreshSpellCooldown(record)
  local spellID = record.runtimeSpellID
  if not spellID then
    PCMPresentation.SetSpellCooldownDuration(record.parts, nil)
    return
  end

  local style = GetRecordStyle(record)
  local swipe = style.swipe or {}
  local viewerSwipe = style.viewerSwipe or {}
  local showCooldown = swipe.show
  if showCooldown == nil then
    showCooldown = viewerSwipe.cooldown ~= false
  end
  if showCooldown ~= true then
    PCMPresentation.SetSpellCooldownDuration(record.parts, nil)
    return
  end

  local showGCD = swipe.showGCD
  if showGCD == nil then
    showGCD = viewerSwipe.gcd ~= false
  end
  local duration = C_Spell.GetSpellCooldownDuration(spellID, showGCD ~= true)
  PCMPresentation.SetSpellCooldownDuration(record.parts, duration)
end

local function RefreshChargeState(record)
  local chargeSpellID = record.runtimeChargeSpellID
  if not chargeSpellID then
    PCMPresentation.SetChargeDuration(record.parts, nil)
    PCMPresentation.SetDisplayCount(record.parts, nil)
    return
  end

  local duration = C_Spell.GetSpellChargeDuration(chargeSpellID)
  PCMPresentation.SetChargeDuration(record.parts, duration)

  local displayCount = C_Spell.GetSpellDisplayCount(chargeSpellID)
  PCMPresentation.SetDisplayCount(record.parts, displayCount)
end

local function RefreshUsableState(record)
  local spellID = record.runtimeSpellID
  if not spellID then
    record.lastUsableState = nil
    record.hasLastUsableState = nil
    PCMPresentation.SetUsableState(record.parts, nil)
    return
  end

  local usable = C_Spell.IsSpellUsable(spellID)
  if not IsSecret(usable) and type(usable) == "boolean" then
    if record.hasLastUsableState and record.lastUsableState == usable then
      return
    end
    record.lastUsableState = usable
    record.hasLastUsableState = true
  else
    record.lastUsableState = nil
    record.hasLastUsableState = nil
  end
  PCMPresentation.SetUsableState(record.parts, usable)
end

local function RefreshRangeState(record)
  local spellID = record.registeredRangeSpellID
  if not spellID then
    record.lastRangeState = nil
    record.hasLastRangeState = nil
    PCMPresentation.SetRangeState(record.parts, nil)
    return
  end

  local inRange = C_Spell.IsSpellInRange(spellID, "target")
  if not IsSecret(inRange) and type(inRange) == "boolean" then
    if record.hasLastRangeState and record.lastRangeState == inRange then
      return
    end
    record.lastRangeState = inRange
    record.hasLastRangeState = true
  else
    record.lastRangeState = nil
    record.hasLastRangeState = nil
  end
  PCMPresentation.SetRangeState(record.parts, inRange)
end

local function RefreshProcState(record)
  PCMPresentation.SetProcState(
    record.parts,
    IsAnyIdentityOverlayed(record),
    GetRecordStyle(record).procGlow
  )
end

local function ApplyStateAppearance(record, stateName, atMaxCharges)
  local style = GetRecordStyle(record)
  local appearance = style.appearance
  local maximum = atMaxCharges == true
  if record.appliedStateName == stateName
    and record.appliedStateAtMaxCharges == maximum
    and record.appliedStateAppearance == appearance
  then
    return
  end

  PCMPresentation.ApplyOwnedStateAppearance(
    record.parts,
    record.cooldownID,
    appearance,
    stateName,
    maximum
  )
  record.appliedStateName = stateName
  record.appliedStateAtMaxCharges = maximum
  record.appliedStateAppearance = appearance
end

local function RefreshTotemState(record)
  local slot = verifiedTotemSlots[record.cooldownID]
  if not slot then
    record.totemActive = nil
    PCMPresentation.SetTotemDuration(record.parts, nil)
    return false
  end

  local duration = GetTotemDuration(slot)
  PCMPresentation.SetTotemDuration(record.parts, duration)
  record.totemActive = duration ~= nil
  return record.totemActive
end

local function RefreshItemCooldown(record, itemID)
  if not itemID then
    PCMPresentation.SetItemCooldown(record.parts, 0, 0)
    ApplyStateAppearance(record, "READY", false)
    return
  end

  if C_Secrets.ShouldCooldownsBeSecret() == true then
    return
  end

  local startTime, duration = C_Item.GetItemCooldown(itemID)
  if IsSecret(startTime) or IsSecret(duration) then
    return
  end
  PCMPresentation.SetItemCooldown(record.parts, startTime, duration)
  ApplyStateAppearance(record, startTime ~= 0 and "COOLDOWN" or "READY", false)
end

local function RefreshEquipmentCooldown(record)
  local equipSlot = record.entry.equipSlot
  if not equipSlot then
    PCMPresentation.SetItemCooldown(record.parts, 0, 0)
    ApplyStateAppearance(record, "READY", false)
    return
  end

  if C_Secrets.ShouldCooldownsBeSecret() == true then
    return
  end

  local startTime, duration = GetInventoryItemCooldown("player", equipSlot)
  if IsSecret(startTime) or IsSecret(duration) then
    return
  end
  PCMPresentation.SetItemCooldown(record.parts, startTime, duration)
  ApplyStateAppearance(record, startTime ~= 0 and "COOLDOWN" or "READY", false)
end

local function RefreshEquipmentState(record)
  RefreshEquipmentContent(record)
  RefreshSpellAppearance(record)
  RefreshEquipmentCooldown(record)

  local keybind = PCMKeybinds:GetForEntry(record.entry, record)
  PCMPresentation.SetKeybindText(record.parts, keybind)
end

local function RefreshVerifiedSpellCategorySource(record)
  local itemID = record.safeContent.categoryItemID
  local spellID = record.safeContent.categorySpellID
  RefreshSpellAppearance(record)
  if itemID then
    RefreshItemCooldown(record, itemID)
  elseif spellID then
    local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
    PCMPresentation.SetSpellCooldownDuration(record.parts, duration)
    if C_Secrets.ShouldCooldownsBeSecret() == true then
      return
    end
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not cooldownInfo
      or IsSecret(cooldownInfo.isActive)
      or IsSecret(cooldownInfo.isOnGCD)
    then
      return
    end
    ApplyStateAppearance(
      record,
      cooldownInfo.isActive == true and cooldownInfo.isOnGCD ~= true
        and "COOLDOWN"
        or "READY",
      false
    )
  else
    PCMPresentation.SetItemCooldown(record.parts, 0, 0)
    PCMPresentation.SetSpellCooldownDuration(record.parts, nil)
    ApplyStateAppearance(record, "READY", false)
  end
end

local function RefreshSpellCategoryState(record)
  if C_Secrets.ShouldCooldownsBeSecret() == true then
    RefreshVerifiedSpellCategorySource(record)
    return
  end

  local spellID, itemID = C_Spell.GetLastCategoryCooldownSource(record.entry.spellCategoryID)
  if IsSecret(spellID) or IsSecret(itemID) then
    RefreshVerifiedSpellCategorySource(record)
    return
  end

  record.safeContent.categorySpellID = spellID
  record.safeContent.categoryItemID = itemID
  RefreshVerifiedSpellCategorySource(record)
end

local function RefreshKeybind(record)
  local text = PCMKeybinds:GetForEntry(record.entry, record)
  PCMPresentation.SetKeybindText(record.parts, text)
end

local function RefreshStateAppearance(record)
  local entry = record.entry
  if entry.entryKind ~= "spell" or not record.runtimeSpellID then
    return
  end
  if record.totemActive then
    ApplyStateAppearance(record, "AURA", false)
    return
  end
  if C_Secrets.ShouldCooldownsBeSecret() == true then
    return
  end

  local stateName
  local atMaxCharges = false
  if entry.charges == true and record.runtimeChargeSpellID then
    local chargeInfo = C_Spell.GetSpellCharges(record.runtimeChargeSpellID)
    if chargeInfo and not IsSecret(chargeInfo.isActive) then
      atMaxCharges = chargeInfo.isActive ~= true
    end
  end

  local cooldownInfo = C_Spell.GetSpellCooldown(record.runtimeSpellID)
  if not cooldownInfo
    or IsSecret(cooldownInfo.isActive)
    or IsSecret(cooldownInfo.isOnGCD)
  then
    return
  end
  stateName = cooldownInfo.isActive == true and cooldownInfo.isOnGCD ~= true
    and "COOLDOWN"
    or "READY"

  ApplyStateAppearance(record, stateName, atMaxCharges)
end

local function RefreshRecordState(record, stateMask)
  local entry = record.entry

  if HasMask(stateMask, STATE_COOLDOWN) and entry.entryKind == "spell" then
    RefreshSpellCooldown(record)
  end
  if HasMask(stateMask, STATE_CHARGE) and entry.charges == true then
    RefreshChargeState(record)
  end
  if HasMask(stateMask, STATE_USABLE) and entry.entryKind == "spell" then
    RefreshUsableState(record)
  end
  if HasMask(stateMask, STATE_RANGE) then
    RefreshRangeState(record)
  end
  if HasMask(stateMask, STATE_PROC) and entry.entryKind == "spell" then
    RefreshProcState(record)
  end
  if HasMask(stateMask, STATE_EQUIPMENT) and entry.entryKind == "equipmentSlot" then
    RefreshEquipmentState(record)
  elseif HasMask(stateMask, STATE_ITEM) then
    if entry.entryKind == "equipmentSlot" then
      RefreshEquipmentCooldown(record)
    elseif entry.entryKind == "spellCategory" then
      RefreshSpellCategoryState(record)
    end
  end
  if HasMask(stateMask, STATE_KEYBIND) then
    RefreshKeybind(record)
  end
  if verifiedTotemSlots[record.cooldownID]
    and HasMask(stateMask, bit_bor(STATE_COOLDOWN, STATE_CHARGE, STATE_TOTEM))
  then
    RefreshTotemState(record)
  end
  if HasMask(stateMask, bit_bor(STATE_COOLDOWN, STATE_CHARGE)) then
    RefreshStateAppearance(record)
  end
end

local function ApplySpellCategorySource(spellID, baseSpellID, spellCategory, itemID)
  if IsSecret(spellCategory) or type(spellCategory) ~= "number"
    or IsSecret(itemID) or type(itemID) ~= "number"
  then
    return
  end

  if IsSecret(spellID) or (spellID ~= nil and type(spellID) ~= "number")
    or IsSecret(baseSpellID) or (baseSpellID ~= nil and type(baseSpellID) ~= "number")
  then
    return
  end

  for _, record in pairs(buckets.item.records) do
    if record.entry.entryKind == "spellCategory"
      and record.entry.spellCategoryID == spellCategory
    then
      record.safeContent.categorySpellID = baseSpellID or spellID
      record.safeContent.categoryItemID = itemID
    end
  end
end

local function RefreshRecordAppearance(record, appearanceMask)
  if HasMask(appearanceMask, APPEARANCE_STYLE) then
    record.resolvedStyle = nil
    record.appliedStateName = nil
    record.appliedStateAtMaxCharges = nil
    record.appliedStateAppearance = nil
    record.lastUsableState = nil
    record.hasLastUsableState = nil
    record.lastRangeState = nil
    record.hasLastRangeState = nil
    PCMPresentation.ApplyOwnedIconStyle(record.parts, ResolveRecordStyle(record))
    ConfigureAuraSlots(record)
    for unit, button in pairs(record.auraButtons) do
      if button then
        ApplyAuraButtonStyle(record, button, unit, false)
      end
    end
  end

  if HasMask(appearanceMask, APPEARANCE_ICON) then
    if record.entry.entryKind == "equipmentSlot" then
      RefreshEquipmentContent(record)
    end
    RefreshSpellAppearance(record)
  end

  if HasMask(appearanceMask, APPEARANCE_KEYBIND) then
    RefreshKeybind(record)
  end
end

local function RefreshRecordVisibility(record)
  if groupLayoutEnabled and not presentationActive then
    record.parts.frame:Hide()
    return
  end
  PCMPresentation.ApplyOwnedIconVisibility(record.parts, GetRecordStyle(record))
end

local function ReleaseRecord(record)
  if activeByCooldownID[record.cooldownID] ~= record then
    return
  end

  DisableRangeRegistration(record)
  DeactivateAuraSlots(record)
  RemoveRecordFromBuckets(record)

  activeByCooldownID[record.cooldownID] = nil
  record.queued = false
  record.dirtyMask = 0
  record.stateDirtyMask = 0
  record.appearanceDirtyMask = 0
  record.auraStylePending = nil
  record.parts.frame:SetScript("OnEnter", nil)
  record.parts.frame:SetScript("OnLeave", nil)
  PCMPresentation.DeactivateOwnedIcon(record.parts)
  record.parts.frame:Hide()
  record.parts.frame:ClearAllPoints()
  retiredByCooldownID[record.cooldownID] = record
end

local function AcquireRecord(viewer, entry, generation)
  local record = retiredByCooldownID[entry.cooldownID]
  local parts
  if record then
    retiredByCooldownID[entry.cooldownID] = nil
    parts = record.parts
    parts.frame:SetParent(viewer.frame)
    record.entry = entry
    record.catalogGeneration = generation
    record.viewerKey = viewer.key
    record.viewerOrder = entry.viewerOrder
    record.runtimeOverrideSpellID = entry.overrideSpellID
    record.runtimeTotemSpellID = nil
    record.totemActive = nil
    record.runtimeSpellID = nil
    record.runtimeChargeSpellID = nil
    record.previousRuntimeSpellID = nil
    record.registeredRangeSpellID = nil
    record.safeContent.equippedItemID = nil
    record.safeContent.categorySpellID = nil
    record.safeContent.categoryItemID = nil
    record.dirtyMask = 0
    record.stateDirtyMask = 0
    record.appearanceDirtyMask = 0
    record.queued = false
    record.resolvedStyle = nil
    record.appliedStateName = nil
    record.appliedStateAtMaxCharges = nil
    record.appliedStateAppearance = nil
    record.lastUsableState = nil
    record.hasLastUsableState = nil
    record.lastRangeState = nil
    record.hasLastRangeState = nil
  else
    parts = AcquireParts(viewer.frame)
    record = {
      cooldownID = entry.cooldownID,
      entry = entry,
      catalogGeneration = generation,
      viewerKey = viewer.key,
      viewerOrder = entry.viewerOrder,
      parts = parts,
      auraSlots = {
        player = nil,
        target = nil,
      },
      auraButtons = {
        player = nil,
        target = nil,
      },
      runtimeOverrideSpellID = entry.overrideSpellID,
      runtimeTotemSpellID = nil,
      totemActive = nil,
      runtimeSpellID = nil,
      runtimeChargeSpellID = nil,
      previousRuntimeSpellID = nil,
      registeredRangeSpellID = nil,
      safeContent = {
        equippedItemID = nil,
        categorySpellID = nil,
        categoryItemID = nil,
      },
      dirtyMask = 0,
      stateDirtyMask = 0,
      appearanceDirtyMask = 0,
      auraStylePending = nil,
      resolvedStyle = nil,
      appliedStateName = nil,
      appliedStateAtMaxCharges = nil,
      appliedStateAppearance = nil,
      lastUsableState = nil,
      hasLastUsableState = nil,
      lastRangeState = nil,
      hasLastRangeState = nil,
      queued = false,
    }
  end

  local function OnCooldownDone()
    if activeByCooldownID[record.cooldownID] ~= record then
      return
    end
    RefreshTotemBindings()
    MarkRecordDirty(
      record,
      DIRTY_STATE,
      bit_bor(STATE_COOLDOWN, STATE_CHARGE, STATE_TOTEM)
    )
  end
  parts.cooldown:SetScript("OnCooldownDone", OnCooldownDone)
  parts.chargeCooldown:SetScript("OnCooldownDone", OnCooldownDone)

  activeByCooldownID[record.cooldownID] = record
  parts.frame:SetScript("OnEnter", function(frame)
    local owner = ns.Modules.CooldownManager
    if owner:GetViewerTooltipsEnabled(record.viewerKey) ~= true then
      return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local hasTooltip = false
    if record.entry.entryKind == "equipmentSlot" then
      GameTooltip:SetInventoryItem("player", record.entry.equipSlot)
      hasTooltip = true
    elseif record.entry.entryKind == "spellCategory" then
      if record.safeContent.categoryItemID then
        GameTooltip:SetItemByID(record.safeContent.categoryItemID)
        hasTooltip = true
      elseif record.safeContent.categorySpellID then
        GameTooltip:SetSpellByID(record.safeContent.categorySpellID)
        hasTooltip = true
      end
    elseif record.runtimeSpellID then
      GameTooltip:SetSpellByID(record.runtimeSpellID)
      hasTooltip = true
    end
    if hasTooltip then
      GameTooltip:Show()
    else
      GameTooltip:Hide()
    end
  end)
  parts.frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  ConfigureRecordBuckets(record)
  MarkRecordDirty(record, bit_bor(DIRTY_STATE, DIRTY_APPEARANCE, DIRTY_VISIBILITY), STATE_ALL)
  return record
end

local function ReconfigureRecord(record, viewer, entry, generation)
  DeactivateAuraSlots(record)
  PCMPresentation.DeactivateOwnedIcon(record.parts)
  record.entry = entry
  record.catalogGeneration = generation
  record.viewerKey = viewer.key
  record.viewerOrder = entry.viewerOrder
  record.runtimeOverrideSpellID = entry.overrideSpellID
  record.runtimeTotemSpellID = nil
  record.totemActive = nil
  record.previousRuntimeSpellID = nil
  record.safeContent.equippedItemID = nil
  record.safeContent.categorySpellID = nil
  record.safeContent.categoryItemID = nil
  record.resolvedStyle = nil
  record.appliedStateName = nil
  record.appliedStateAtMaxCharges = nil
  record.appliedStateAppearance = nil
  record.lastUsableState = nil
  record.hasLastUsableState = nil
  record.lastRangeState = nil
  record.hasLastRangeState = nil
  ConfigureRecordBuckets(record)
  MarkRecordDirty(record, bit_bor(DIRTY_STATE, DIRTY_APPEARANCE, DIRTY_VISIBILITY), STATE_ALL)
end

local function ApplyPendingCatalog(viewer)
  local entries = viewer.pendingEntries
  if not entries then
    return
  end

  local generation = viewer.pendingGeneration
  viewer.pendingEntries = nil
  viewer.pendingGeneration = nil

  local retained = {}
  local orderedRuntimes = {}

  for index, entry in ipairs(entries) do
    local cooldownID = entry.cooldownID
    retained[cooldownID] = true

    local record = activeByCooldownID[cooldownID]
    if record and record.viewerKey ~= viewer.key then
      ReleaseRecord(record)
      record = nil
    end

    if record then
      ReconfigureRecord(record, viewer, entry, generation)
    else
      record = AcquireRecord(viewer, entry, generation)
    end

    record.viewerOrder = index
    orderedRuntimes[index] = record
  end

  for _, record in ipairs(viewer.orderedRuntimes) do
    if record.viewerKey == viewer.key and not retained[record.cooldownID] then
      ReleaseRecord(record)
    end
  end

  viewer.entries = entries
  viewer.orderedRuntimes = orderedRuntimes
  viewer.generation = generation
  viewer.layoutDirty = true
  RefreshTotemBindings()
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout(true)
  end
end

local function WantsEvent(event)
  if event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
    return buckets.spellAppearance.count > 0
  elseif event == "SPELL_UPDATE_COOLDOWN" then
    return buckets.cooldown.count > 0 or buckets.item.count > 0
  elseif event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_USES" then
    return buckets.charge.count > 0
  elseif event == "SPELL_UPDATE_ICON" then
    return buckets.spellAppearance.count > 0
  elseif event == "SPELL_UPDATE_USABLE" then
    return buckets.usable.count > 0
  elseif event == "SPELL_RANGE_CHECK_UPDATE" then
    return buckets.range.count > 0
  elseif event == "PLAYER_TARGET_CHANGED" then
    return buckets.range.count > 0
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
    or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"
  then
    return buckets.proc.count > 0
  elseif event == "PLAYER_TOTEM_UPDATE" then
    return next(activeByCooldownID) ~= nil
  elseif event == "BAG_UPDATE_COOLDOWN"
    or event == "ITEM_LOCK_CHANGED"
    or event == "ITEM_PUSH"
  then
    return buckets.item.count > 0
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    return buckets.equipment.count > 0
  elseif event == "PLAYER_REGEN_ENABLED" then
    return next(activeByCooldownID) ~= nil
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    return next(activeByCooldownID) ~= nil
  end
  return false
end

local function MarkCooldownEventBucket(bucketName, stateMask, spellID, baseSpellID)
  local bucket = buckets[bucketName]
  local hasSpecificSpell = not IsSecret(spellID) and type(spellID) == "number"
  local hasSpecificBase = not IsSecret(baseSpellID) and type(baseSpellID) == "number"

  for _, record in pairs(bucket.records) do
    if not hasSpecificSpell
      or RecordMatchesSpellIdentity(
        record,
        spellID,
        hasSpecificBase and baseSpellID or spellID
      )
    then
      MarkRecordDirty(record, DIRTY_STATE, stateMask)
    end
  end
end

local function RefreshEventRegistrations()
  if not enabled then
    eventFrame:UnregisterAllEvents()
    for event in pairs(registeredEvents) do
      registeredEvents[event] = nil
    end
    eventRegistrationsDirty = true
    return
  end

  for _, event in ipairs(RUNTIME_EVENTS) do
    local wanted = WantsEvent(event)
    if wanted and not registeredEvents[event] then
      eventFrame:RegisterEvent(event)
      registeredEvents[event] = true
    elseif not wanted and registeredEvents[event] then
      eventFrame:UnregisterEvent(event)
      registeredEvents[event] = nil
    end
  end
  eventRegistrationsDirty = false
end

local function FlushDirtyRecords()
  while dirtyHead <= dirtyTail do
    local record = dirtyQueue[dirtyHead]
    dirtyQueue[dirtyHead] = nil
    dirtyHead = dirtyHead + 1

    if record and activeByCooldownID[record.cooldownID] == record then
      record.queued = false
      local dirtyMask = record.dirtyMask or 0
      local stateMask = record.stateDirtyMask or 0
      local appearanceMask = record.appearanceDirtyMask or 0
      record.dirtyMask = 0
      record.stateDirtyMask = 0
      record.appearanceDirtyMask = 0

      if HasMask(dirtyMask, DIRTY_APPEARANCE) then
        RefreshRecordAppearance(record, appearanceMask)
      end
      if HasMask(dirtyMask, DIRTY_VISIBILITY) then
        RefreshRecordVisibility(record)
      end
      if HasMask(dirtyMask, DIRTY_STATE) then
        RefreshRecordState(record, stateMask)
      end
    end
  end

  dirtyHead = 1
  dirtyTail = 0
end

local function RegisterViewerLayout(viewer)
  if groupLayoutEnabled then
    return
  end

  AbilityLayout:RegisterOwnedViewer(viewer.key, viewer.frame, {
    getOrderedEntries = function()
      return viewer.entries
    end,
    getOrderedFrames = function()
      local frames = {}
      for index, record in ipairs(viewer.orderedRuntimes) do
        frames[index] = record.parts.frame
      end
      return frames
    end,
    getResolvedStyle = function()
      return viewer.resolvedStyle
    end,
    layoutApplied = function(_, plan)
      if viewer.parent and viewer.parent ~= UIParent then
        viewer.parent:SetSize(plan.width, plan.height)
      end
    end,
  })
end

function AbilityRuntime:InitializeViewer(viewerKey, parent)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return nil
  end

  parent = parent or UIParent
  if viewer.frame then
    if viewer.parent ~= parent then
      viewer.parent = parent
      viewer.frame:SetParent(parent)
      viewer.frame:ClearAllPoints()
      viewer.frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
    return viewer.frame
  end

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(1, 1)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
  frame:EnableMouse(false)
  frame:Hide()

  viewer.frame = frame
  viewer.parent = parent
  RegisterViewerLayout(viewer)
  return frame
end

function AbilityRuntime:GetViewerFrame(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.frame or nil
end

function AbilityRuntime:GetOrderedRecords(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.orderedRuntimes or nil
end

function AbilityRuntime:SetGroupLayoutEnabled(active)
  groupLayoutEnabled = active == true
  groupLayoutReady = false

  for _, viewer in pairs(viewers) do
    AbilityLayout:UnregisterOwnedViewer(viewer.key)
    viewer.layoutDirty = true
    if not groupLayoutEnabled and viewer.frame then
      RegisterViewerLayout(viewer)
    end
  end

  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    ScheduleFlush()
  end
end

function AbilityRuntime:SetGroupLayoutReady(ready)
  groupLayoutReady = ready == true
  if groupLayoutReady and not readyNotified and self:IsReady() then
    readyNotified = true
    ns.PCMNativeBridge:Refresh()
  end
end

function AbilityRuntime:SetPresentationActive(active)
  presentationActive = active == true and enabled
  for _, viewer in pairs(viewers) do
    if viewer.frame then
      viewer.frame:SetShown(presentationActive)
    end
    for _, record in ipairs(viewer.orderedRuntimes) do
      if groupLayoutEnabled then
        record.parts.frame:SetShown(presentationActive)
      end
      ConfigureAuraSlots(record)
    end
  end
end

function AbilityRuntime:ReconcileCatalog(viewerKey, entries, generation)
  local viewer = GetViewer(viewerKey)
  if not viewer or not viewer.frame then
    return
  end

  viewer.pendingEntries = entries
  viewer.pendingGeneration = generation
  ScheduleFlush()
end

function AbilityRuntime:OnCatalogChanged(generation)
  for _, viewer in pairs(viewers) do
    local entries = AbilityCatalog:GetViewerEntries(viewer.key)
    self:ReconcileCatalog(viewer.key, entries, generation)
  end
end

function AbilityRuntime:ApplyViewerStyle(viewerKey, resolvedStyle)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return
  end

  viewer.resolvedStyle = resolvedStyle
  viewer.layoutDirty = true
  for _, record in ipairs(viewer.orderedRuntimes) do
    MarkRecordDirty(
      record,
      bit_bor(DIRTY_STATE, DIRTY_APPEARANCE, DIRTY_VISIBILITY),
      STATE_ALL,
      APPEARANCE_STYLE
    )
  end
  ScheduleFlush()
end

function AbilityRuntime:ApplyEntrySettings(cooldownID)
  local record = activeByCooldownID[cooldownID]
  if not record then
    return
  end

  MarkRecordDirty(
    record,
    bit_bor(DIRTY_STATE, DIRTY_APPEARANCE, DIRTY_VISIBILITY),
    STATE_ALL,
    APPEARANCE_ALL
  )
end

function AbilityRuntime:RefreshLayout(viewerKey)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return
  end

  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    AbilityLayout:RequestLayout(viewerKey)
  end
end

function AbilityRuntime:MarkBucketDirty(bucketName, dirtyMask)
  MarkBucket(bucketName, dirtyMask)
end

function AbilityRuntime:Flush()
  if not enabled then
    flushFrame:Hide()
    return
  end

  if not InCombatLockdown() and C_Secrets.ShouldAurasBeSecret() ~= true then
    ApplyPendingCatalog(viewers[ESSENTIAL_VIEWER])
    ApplyPendingCatalog(viewers[UTILITY_VIEWER])
  end
  if eventRegistrationsDirty then
    RefreshEventRegistrations()
  end
  FlushDirtyRecords()

  for _, viewer in pairs(viewers) do
    if viewer.layoutDirty then
      viewer.layoutDirty = false
      if groupLayoutEnabled then
        ns.PCMGroupManager:RequestLayout()
      else
        AbilityLayout:RequestLayout(viewer.key)
      end
    end
  end

  if not readyNotified and self:IsReady() then
    readyNotified = true
    ns.PCMNativeBridge:Refresh()
  end

  flushFrame:Hide()
end

function AbilityRuntime:Enable()
  if enabled then
    return
  end
  enabled = true
  eventRegistrationsDirty = true
  readyNotified = false
  presentationActive = false
  groupLayoutReady = false
  AbilityCatalog:Enable(self)
  AbilityCatalog:RegisterListener(self, self.OnCatalogChanged)
  AbilityCatalog:Refresh()

  for _, viewer in pairs(viewers) do
    if viewer.frame then
      RegisterViewerLayout(viewer)
      local entries, generation = AbilityCatalog:GetViewerEntries(viewer.key)
      viewer.pendingEntries = entries
      viewer.pendingGeneration = generation
      viewer.frame:Hide()
    end
  end

  ScheduleFlush()
end

function AbilityRuntime:Disable()
  if not enabled then
    return
  end
  enabled = false
  readyNotified = false
  presentationActive = false
  AbilityCatalog:UnregisterListener(self)
  AbilityCatalog:Disable(self)

  eventFrame:UnregisterAllEvents()
  for event in pairs(registeredEvents) do
    registeredEvents[event] = nil
  end
  eventRegistrationsDirty = true
  flushFrame:Hide()

  for _, record in pairs(activeByCooldownID) do
    DisableRangeRegistration(record)
    DeactivateAuraSlots(record)
  end

  for _, viewer in pairs(viewers) do
    AbilityLayout:UnregisterOwnedViewer(viewer.key)
    for _, record in ipairs(viewer.orderedRuntimes) do
      ReleaseRecord(record)
    end
    viewer.entries = {}
    viewer.orderedRuntimes = {}
    viewer.generation = 0
    viewer.pendingEntries = nil
    viewer.pendingGeneration = nil
    viewer.layoutDirty = false
    if viewer.frame then
      viewer.frame:SetSize(1, 1)
      viewer.frame:Hide()
    end
  end

  for index = dirtyHead, dirtyTail do
    dirtyQueue[index] = nil
  end
  dirtyHead = 1
  dirtyTail = 0
  wipe(verifiedTotemSlots)
  wipe(rangeSpellRefCounts)
end

function AbilityRuntime:IsReady()
  local generation = AbilityCatalog:GetGeneration()
  return enabled
    and generation > 0
    and viewers[ESSENTIAL_VIEWER].frame ~= nil
    and viewers[UTILITY_VIEWER].frame ~= nil
    and viewers[ESSENTIAL_VIEWER].resolvedStyle ~= nil
    and viewers[UTILITY_VIEWER].resolvedStyle ~= nil
    and viewers[ESSENTIAL_VIEWER].pendingEntries == nil
    and viewers[UTILITY_VIEWER].pendingEntries == nil
    and viewers[ESSENTIAL_VIEWER].generation == generation
    and viewers[UTILITY_VIEWER].generation == generation
    and (
      groupLayoutEnabled and groupLayoutReady
      or AbilityLayout:GetLastPlan(ESSENTIAL_VIEWER) ~= nil
        and AbilityLayout:GetLastPlan(UTILITY_VIEWER) ~= nil
    )
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
  if event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
    ApplySpellOverride(arg1, arg2)
  elseif event == "SPELL_UPDATE_COOLDOWN" then
    ApplySpellCategorySource(arg1, arg2, arg3, arg5)
    MarkCooldownEventBucket("cooldown", STATE_COOLDOWN, arg1, arg2)
    MarkCooldownEventBucket("charge", STATE_CHARGE, arg1, arg2)
    MarkBucket("item", DIRTY_STATE, STATE_ITEM)
  elseif event == "SPELL_UPDATE_CHARGES" then
    MarkBucket("charge", DIRTY_STATE, STATE_CHARGE)
  elseif event == "SPELL_UPDATE_USES" then
    MarkCooldownEventBucket("charge", STATE_CHARGE, arg1, arg2)
  elseif event == "SPELL_UPDATE_ICON" then
    MarkBucket("spellAppearance", DIRTY_APPEARANCE, 0, APPEARANCE_ICON)
  elseif event == "SPELL_UPDATE_USABLE" then
    MarkBucket("usable", DIRTY_STATE, STATE_USABLE)
  elseif event == "SPELL_RANGE_CHECK_UPDATE" then
    MarkCooldownEventBucket("range", STATE_RANGE, arg1, arg1)
  elseif event == "PLAYER_TARGET_CHANGED" then
    MarkBucket("range", DIRTY_STATE, STATE_RANGE)
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
    or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"
  then
    MarkProcRecordsForSpell(arg1)
  elseif event == "PLAYER_TOTEM_UPDATE" then
    RefreshTotemBindings()
    RefreshEventRegistrations()
  elseif event == "BAG_UPDATE_COOLDOWN"
    or event == "ITEM_LOCK_CHANGED"
    or event == "ITEM_PUSH"
  then
    MarkBucket("item", DIRTY_STATE, STATE_ITEM)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    MarkBucket(
      "equipment",
      bit_bor(DIRTY_STATE, DIRTY_APPEARANCE),
      bit_bor(STATE_EQUIPMENT, STATE_ITEM, STATE_KEYBIND),
      bit_bor(APPEARANCE_ICON, APPEARANCE_KEYBIND)
    )
  elseif event == "PLAYER_REGEN_ENABLED" then
    QueuePendingAuraStyles()
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    PrepareAuraButtonsForRestriction(arg1, arg2)
    RefreshTotemBindings()
    MarkBucket("cooldown", DIRTY_STATE, STATE_COOLDOWN)
    MarkBucket("charge", DIRTY_STATE, STATE_CHARGE)
    MarkBucket("usable", DIRTY_STATE, STATE_USABLE)
    MarkBucket("range", DIRTY_STATE, STATE_RANGE)
    MarkBucket("proc", DIRTY_STATE, STATE_PROC)
    MarkBucket("item", DIRTY_STATE, STATE_ITEM)
    MarkBucket(
      "equipment",
      bit_bor(DIRTY_STATE, DIRTY_APPEARANCE),
      bit_bor(STATE_EQUIPMENT, STATE_ITEM, STATE_KEYBIND),
      bit_bor(APPEARANCE_ICON, APPEARANCE_KEYBIND)
    )
    if arg2 == Enum.AddOnRestrictionState.Inactive then
      QueuePendingAuraStyles()
    end
  end
end)

flushFrame:SetScript("OnUpdate", function()
  AbilityRuntime:Flush()
end)

local P = select(1, ns.Pleebug:DropIn(AbilityRuntime, { name = "PCM", bucket = "AbilityRuntime" }))
AbilityRuntime.InitializeViewer = P:Def("AbilityRuntime:InitializeViewer", AbilityRuntime.InitializeViewer)
AbilityRuntime.GetViewerFrame = P:Def("AbilityRuntime:GetViewerFrame", AbilityRuntime.GetViewerFrame)
AbilityRuntime.GetOrderedRecords = P:Def("AbilityRuntime:GetOrderedRecords", AbilityRuntime.GetOrderedRecords)
AbilityRuntime.SetGroupLayoutEnabled = P:Def("AbilityRuntime:SetGroupLayoutEnabled", AbilityRuntime.SetGroupLayoutEnabled)
AbilityRuntime.SetGroupLayoutReady = P:Def("AbilityRuntime:SetGroupLayoutReady", AbilityRuntime.SetGroupLayoutReady)
AbilityRuntime.SetPresentationActive = P:Def("AbilityRuntime:SetPresentationActive", AbilityRuntime.SetPresentationActive)
AbilityRuntime.ReconcileCatalog = P:Def("AbilityRuntime:ReconcileCatalog", AbilityRuntime.ReconcileCatalog)
AbilityRuntime.OnCatalogChanged = P:Def("AbilityRuntime:OnCatalogChanged", AbilityRuntime.OnCatalogChanged)
AbilityRuntime.ApplyViewerStyle = P:Def("AbilityRuntime:ApplyViewerStyle", AbilityRuntime.ApplyViewerStyle)
AbilityRuntime.ApplyEntrySettings = P:Def("AbilityRuntime:ApplyEntrySettings", AbilityRuntime.ApplyEntrySettings)
AbilityRuntime.RefreshLayout = P:Def("AbilityRuntime:RefreshLayout", AbilityRuntime.RefreshLayout)
AbilityRuntime.MarkBucketDirty = P:Def("AbilityRuntime:MarkBucketDirty", AbilityRuntime.MarkBucketDirty)
AbilityRuntime.Flush = P:Def("AbilityRuntime:Flush", AbilityRuntime.Flush)
AbilityRuntime.Enable = P:Def("AbilityRuntime:Enable", AbilityRuntime.Enable)
AbilityRuntime.Disable = P:Def("AbilityRuntime:Disable", AbilityRuntime.Disable)
AbilityRuntime.IsReady = P:Def("AbilityRuntime:IsReady", AbilityRuntime.IsReady)
