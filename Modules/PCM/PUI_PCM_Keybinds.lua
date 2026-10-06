-- File: PUI_PCM_Keybinds.lua
-- Purpose:
--   - Resolve live action-bar keybinds and render them on PCM cooldown viewers.
local ADDON_NAME, ns = ...
local Cooldowns = ns.Modules.CooldownManager
local IconSettings = ns.PCMIconSettings
local DB = ns.PCM_DBExports
local P = select(1, ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "Keybinds" }))

local _G = _G
local wipe = wipe
local type = type
local tonumber = tonumber
local math_ceil = math.ceil
local GetBindingKey = GetBindingKey
local C_ActionBar = C_ActionBar
local C_Spell = C_Spell
local CreateFrame = CreateFrame
local _KB_IsSecret = issecretvalue

local _KB_ScheduleRebuild
local _KB_UpdateConsumerState

local _kbSpellKeyCache = {}
local _kbItemKeyCache = {}
local _kbEquipSlotKeyCache = {}
local _kbMacroSpellIDToKey = {}
local _kbMacroSpellNameToKey = {}
local _kbItemSlots = {}
local _kbMacroItemToKey = {}
local _kbMacroEquipSlotToKey = {}
local _kbMacroSlotEntries = {}
local _kbActionSnapshotReady = false
local _kbItemMapBuilt = false
local _kbMacroMapBuilt = false
local _kbFallbackMapsBlocked = false
local _kbCacheReady = false
local _kbFormattedKeyCache = {}
local _kbActionSlotKnown = {}
local _kbActionSlotType = {}
local _kbActionSlotID = {}
local _kbMappedPages = {}
local _kbExtraBarPages = {}
local _kbBarOffsets = {}

local _KB_MOD_LABELS = {
  SHIFT = "S",
  CTRL = "C",
  ALT = "A",
  STRG = "C",
}

local _KB_KEY_LABELS = {
  MOUSEWHEELUP = "WU",
  MOUSEWHEELDOWN = "WD",
  NUMPADPLUS = "N+",
  NUMPADMINUS = "N-",
  NUMPADDIVIDE = "N/",
  NUMPADMULTIPLY = "N*",
  NUMPADDECIMAL = "N.",
  NUMPADENTER = "NE",
  PAGEUP = "PU",
  PAGEDOWN = "PD",
  INSERT = "Ins",
  DELETE = "Del",
  SPACE = "Spc",
  SPACEBAR = "Spc",
  ESCAPE = "Esc",
  BACKSPACE = "BkSp",
  CAPSLOCK = "Caps",
  HOME = "Hm",
  END = "End",
}

local _KB_PREFIX_LABELS = {
  MOUSEBUTTON = "M",
  BUTTON = "M",
  NUMPAD = "N",
}

local function _KB_FormatKeybind(key)
  if _KB_IsSecret(key) or not key or key == "" then
    return nil
  end

  local raw = tostring(key)
  local cached = _kbFormattedKeyCache[raw]
  if cached then
    return cached
  end

  key = raw:upper()
  local result = ""
  local position = 1

  while true do
    local separator = key:find("-", position, true)
    if not separator then
      break
    end

    local modifier = _KB_MOD_LABELS[key:sub(position, separator - 1)]
    if not modifier then
      break
    end

    result = result .. modifier
    position = separator + 1
  end

  local base = key:sub(position)
  local label = _KB_KEY_LABELS[base]
  if not label then
    local prefix, number = base:match("^(%a+)(%d+)$")
    if prefix and _KB_PREFIX_LABELS[prefix] then
      label = _KB_PREFIX_LABELS[prefix] .. number
    else
      label = base
    end
  end

  result = result .. label
  _kbFormattedKeyCache[raw] = result
  return result
end

local function _KB_IsAbilityViewerKey(viewerKey)
  return viewerKey == "EssentialCooldownViewer"
    or viewerKey == "UtilityCooldownViewer"
end

local _KB_SLOTS_PER_PAGE = 12

local _KB_BAR_COMMANDS = {
  [3] = "MULTIACTIONBAR3BUTTON",
  [4] = "MULTIACTIONBAR4BUTTON",
  [5] = "MULTIACTIONBAR2BUTTON",
  [6] = "MULTIACTIONBAR1BUTTON",
  [7] = "PUIACTIONBAR9BUTTON",
  [8] = "PUIACTIONBAR10BUTTON",
  [9] = "PUIACTIONBAR11BUTTON",
  [10] = "PUIACTIONBAR12BUTTON",
  [13] = "MULTIACTIONBAR5BUTTON",
  [14] = "MULTIACTIONBAR6BUTTON",
  [15] = "MULTIACTIONBAR7BUTTON",
}

local _KB_BAR_UI_KEYS = {
  [3] = "4",
  [4] = "5",
  [5] = "3",
  [6] = "2",
  [7] = "9",
  [8] = "10",
  [9] = "11",
  [10] = "12",
  [13] = "6",
  [14] = "7",
  [15] = "8",
}

local _KB_MAIN_STABLE_PAGES = {
  [1] = true,
  [7] = true,
  [8] = true,
  [9] = true,
  [10] = true,
  [11] = true,
}

local function _KB_PositiveNumber(value)
  if _KB_IsSecret(value) then
    return nil
  end

  value = tonumber(value)
  return value and value > 0 and value or nil
end

local function _KB_RefreshBarTopology()
  wipe(_kbMappedPages)
  wipe(_kbExtraBarPages)
  wipe(_kbBarOffsets)

  local bars = ns.ActionBarsCore:GetDB().bars
  _kbBarOffsets["1"] = bars["1"].buttonOffset or 0

  for page in pairs(_KB_MAIN_STABLE_PAGES) do
    _kbMappedPages[page] = true
  end

  for page, uiKey in pairs(_KB_BAR_UI_KEYS) do
    local barDB = bars[uiKey]
    if barDB.enabled ~= false then
      _kbMappedPages[page] = true
      _kbExtraBarPages[page] = true
      _kbBarOffsets[uiKey] = barDB.buttonOffset or 0
    end
  end
end

local function _KB_IsMappedActionSlot(slot)
  local page = math_ceil(slot / _KB_SLOTS_PER_PAGE)
  return _kbMappedPages[page] == true
end

local function _KB_InvalidateBindings()
  wipe(_kbMacroSlotEntries)
  wipe(_kbSpellKeyCache)
  wipe(_kbItemKeyCache)
  wipe(_kbEquipSlotKeyCache)
  wipe(_kbMacroSpellIDToKey)
  wipe(_kbMacroSpellNameToKey)
  wipe(_kbMacroItemToKey)
  wipe(_kbMacroEquipSlotToKey)
  _kbMacroMapBuilt = false
  _kbFallbackMapsBlocked = false
  _kbCacheReady = false
end

local function _KB_InvalidateAll()
  _KB_InvalidateBindings()
  wipe(_kbItemSlots)
  _kbItemMapBuilt = false
  _kbActionSnapshotReady = false
end

local function _KB_InvalidateActionContent()
  wipe(_kbSpellKeyCache)
  wipe(_kbItemKeyCache)
  wipe(_kbEquipSlotKeyCache)
  _kbFallbackMapsBlocked = false
  _kbCacheReady = false
end

local function _KB_ActionSlotContentChanged(slot)
  if _KB_IsSecret(slot) then
    return false
  end

  slot = tonumber(slot)
  if not slot then
    return false
  end
  if slot ~= 0 and not _KB_IsMappedActionSlot(slot) then
    return false
  end

  local firstSlot = slot == 0 and 1 or slot
  local lastSlot = slot == 0 and 192 or slot
  local changed = false

  for actionSlot = firstSlot, lastSlot do
    if _KB_IsMappedActionSlot(actionSlot) then
      local actionType, actionID = GetActionInfo(actionSlot)
      if not _KB_IsSecret(actionType) and not _KB_IsSecret(actionID) then
        local normalizedType = actionType or false
        local normalizedID = actionID or false

        local previousType = _kbActionSlotType[actionSlot]
        if not _kbActionSlotKnown[actionSlot]
          or previousType ~= normalizedType or _kbActionSlotID[actionSlot] ~= normalizedID then
          changed = true
          if previousType == "item" or normalizedType == "item" then
            _kbItemMapBuilt = false
          end
          if previousType == "macro" or normalizedType == "macro" then
            _kbMacroMapBuilt = false
            _kbMacroSlotEntries[actionSlot] = nil
          end
        end

        _kbActionSlotKnown[actionSlot] = true
        _kbActionSlotType[actionSlot] = normalizedType
        _kbActionSlotID[actionSlot] = normalizedID
      elseif _kbActionSlotKnown[actionSlot] then
        _kbActionSlotKnown[actionSlot] = nil
        _kbItemMapBuilt = false
        _kbMacroMapBuilt = false
        changed = true
      end
    end
  end

  return changed
end


local function _KB_ButtonIndexForActionIndex(actionIndex, uiKey)
  local buttonOffset = _kbBarOffsets[uiKey] or 0
  return ((actionIndex - buttonOffset - 1) % _KB_SLOTS_PER_PAGE) + 1
end

local function _KB_KeybindForBinding(bindingAction)
  local key = GetBindingKey(bindingAction)
  if _KB_IsSecret(key) then
    return nil, true
  end

  return _KB_FormatKeybind(key), false
end

local function _KB_KeybindForSlot(slot)
  if _KB_IsSecret(slot) then
    return nil, true
  end

  slot = _KB_PositiveNumber(slot)
  if not slot then
    return nil, false
  end

  local page = math_ceil(slot / _KB_SLOTS_PER_PAGE)
  local actionIndex = ((slot - 1) % _KB_SLOTS_PER_PAGE) + 1
  local blocked = false

  if page == 1 then
    local bindingIndex = _KB_ButtonIndexForActionIndex(actionIndex, "1")
    local key, keyBlocked = _KB_KeybindForBinding("ACTIONBUTTON" .. bindingIndex)
    if keyBlocked then
      blocked = true
    elseif key then
      return key, false, 1
    end
  end

  if _kbExtraBarPages[page] then
    local uiKey = _KB_BAR_UI_KEYS[page]
    local command = _KB_BAR_COMMANDS[page]
    local bindingIndex = _KB_ButtonIndexForActionIndex(actionIndex, uiKey)
    local key, keyBlocked = _KB_KeybindForBinding(command .. bindingIndex)
    if keyBlocked then
      blocked = true
    elseif key then
      return key, false, tonumber(uiKey) or 50
    end
  end

  if page ~= 1 and _KB_MAIN_STABLE_PAGES[page] then
    local bindingIndex = _KB_ButtonIndexForActionIndex(actionIndex, "1")
    local key, keyBlocked = _KB_KeybindForBinding("ACTIONBUTTON" .. bindingIndex)
    if keyBlocked then
      blocked = true
    elseif key then
      return key, false, 100 + page
    end
  end

  return nil, blocked
end

local function _KB_SelectKeybindFromSlots(slots)
  if _KB_IsSecret(slots) then
    return nil, true
  end
  if type(slots) ~= "table" then
    return nil, false
  end

  local best = nil
  local bestRank = nil
  local blocked = false

  for index = 1, #slots do
    local slot = slots[index]
    if _KB_IsSecret(slot) then
      blocked = true
    else
      local key, slotBlocked, rank = _KB_KeybindForSlot(slot)
      if slotBlocked then
        blocked = true
      elseif key and (not bestRank or rank < bestRank or (rank == bestRank and #key < #best)) then
        best = key
        bestRank = rank
      end
    end
  end

  if best then
    return best, false
  end
  return nil, blocked
end

local function _KB_NormalizeSpellID(spellID)
  if _KB_IsSecret(spellID) then
    return nil, nil, true
  end

  local current = _KB_PositiveNumber(spellID)
  if not current then
    return nil, nil, false
  end

  local base = C_Spell.GetBaseSpell(current)
  if _KB_IsSecret(base) then
    return nil, nil, true
  end
  base = _KB_PositiveNumber(base) or current

  return base, current, false
end

local function _KB_SpellName(spellID)
  spellID = _KB_PositiveNumber(spellID)
  if not spellID then return nil end

  local name = C_Spell.GetSpellName(spellID)
  if _KB_IsSecret(name) then return nil, true end
  return type(name) == "string" and name ~= "" and name or nil
end

local function _KB_SpellIDFromName(name)
  if _KB_IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
  local spellID = C_Spell.GetSpellIDForSpellIdentifier(name)
  if _KB_IsSecret(spellID) then return nil, true end
  return _KB_PositiveNumber(spellID)
end

local function _KB_CacheSpell(baseSpellID, currentSpellID, key)
  if not key then
    return
  end

  if baseSpellID then _kbSpellKeyCache[baseSpellID] = key end
  if currentSpellID then _kbSpellKeyCache[currentSpellID] = key end
end

local function _KB_ParseMacroBody(body)
  if _KB_IsSecret(body) or type(body) ~= "string" or body == "" then return nil end
  local results = nil

  for line in body:gmatch("[^\r\n]+") do
    local command, args = line:match("^/(%S+)%s+(.+)$")
    if command and args then
      command = command:lower()
      if command == "cast" or command == "use" or command == "castsequence" then
        if command == "castsequence" then
          args = args:gsub("^reset=%S+%s*", "")
        end
        for segment in args:gmatch("([^;]+)") do
          local token = segment:gsub("%[.-%]%s*", ""):gsub("!+", ""):match("^%s*(.-)%s*$")
          if token and token ~= "" then
            for part in token:gmatch("([^,]+)") do
              local value = part:match("^%s*(.-)%s*$")
              if value and value ~= "" then
                results = results or {}
                results[#results + 1] = value
              end
            end
          end
        end
      end
    end
  end

  return results
end

local function _KB_GetMacroBodySafe(macroIndex)
  macroIndex = _KB_PositiveNumber(macroIndex)
  if not macroIndex then return nil end

  local body = GetMacroBody(macroIndex)
  if not _KB_IsSecret(body) and type(body) == "string" and body ~= "" then
    return body
  end

  local _, _, infoBody = GetMacroInfo(macroIndex)
  if not _KB_IsSecret(infoBody) and type(infoBody) == "string" and infoBody ~= "" then
    return infoBody
  end
  return nil
end

local function _KB_ResolveMacroIndex(slot, actionID)
  local macroName = GetActionText(slot)
  if not _KB_IsSecret(macroName) and type(macroName) == "string" and macroName ~= "" then
    local macroIndex = _KB_PositiveNumber(GetMacroIndexByName(macroName))
    if macroIndex then return macroIndex end
  end

  actionID = _KB_PositiveNumber(actionID)
  if actionID then
    local name = GetMacroInfo(actionID)
    if not _KB_IsSecret(name) and name then
      return actionID
    end
  end

  return nil
end

local function _KB_IndexMacroSpell(entry, spellID, key)
  local baseSpellID, currentSpellID, blocked = _KB_NormalizeSpellID(spellID)
  if blocked then
    entry.reusable = false
    return
  end
  if not baseSpellID then return end

  entry.spells[baseSpellID] = entry.spells[baseSpellID] or key
  entry.spells[currentSpellID] = entry.spells[currentSpellID] or key

  local name, nameBlocked = _KB_SpellName(currentSpellID)
  if nameBlocked then entry.reusable = false end
  if name then
    entry.names[name:lower()] = entry.names[name:lower()] or key
  end

  if baseSpellID ~= currentSpellID then
    name, nameBlocked = _KB_SpellName(baseSpellID)
    if nameBlocked then entry.reusable = false end
    if name then
      entry.names[name:lower()] = entry.names[name:lower()] or key
    end
  end
end

local function _KB_IndexMacroItem(entry, itemID, key)
  itemID = _KB_PositiveNumber(itemID)
  if itemID and entry.items[itemID] == nil then
    entry.items[itemID] = key
  end
end

local function _KB_ReadMacroSlot(slot, actionID, key)
  local macroIndex = _KB_ResolveMacroIndex(slot, actionID)
  if not macroIndex then return end

  local entry = { spells = {}, names = {}, items = {}, equipSlots = {}, reusable = true }
  local macroSpell = GetMacroSpell(macroIndex)
  if _KB_IsSecret(macroSpell) then
    entry.reusable = false
  elseif macroSpell then
    if type(macroSpell) == "number" then
      _KB_IndexMacroSpell(entry, macroSpell, key)
    elseif type(macroSpell) == "string" then
      local spellID, blocked = _KB_SpellIDFromName(macroSpell)
      if blocked then entry.reusable = false end
      if spellID then _KB_IndexMacroSpell(entry, spellID, key) end
    end
  end

  local _, _, macroItemID = GetMacroItem(macroIndex)
  if _KB_IsSecret(macroItemID) then
    entry.reusable = false
  elseif macroItemID then
    _KB_IndexMacroItem(entry, macroItemID, key)
  end

  local body = _KB_GetMacroBodySafe(macroIndex)
  if not body then
    entry.reusable = false
    return entry
  end
  local values = _KB_ParseMacroBody(body)
  if not values then return entry end

  for index = 1, #values do
    local value = values[index]
    local equipSlot = tonumber(value)
    local explicitItemID = value:match("^item:(%d+)$")

    if equipSlot == 13 or equipSlot == 14 then
      entry.equipSlots[equipSlot] = entry.equipSlots[equipSlot] or key
    elseif explicitItemID then
      _KB_IndexMacroItem(entry, explicitItemID, key)
    else
      local itemID = C_Item.GetItemInfoInstant(value)
      if _KB_IsSecret(itemID) then
        entry.reusable = false
      end
      if not _KB_IsSecret(itemID) and itemID then
        _KB_IndexMacroItem(entry, itemID, key)
      else
        entry.names[value:lower()] = entry.names[value:lower()] or key
        local spellID, blocked = _KB_SpellIDFromName(value)
        if blocked then entry.reusable = false end
        if spellID then _KB_IndexMacroSpell(entry, spellID, key) end
      end
    end
  end
  return entry
end

local function _KB_IndexMacroSlot(slot, actionID, key)
  local entry = _kbMacroSlotEntries[slot]
  if not entry then
    entry = _KB_ReadMacroSlot(slot, actionID, key)
    if not entry then return end
    if entry.reusable then
      _kbMacroSlotEntries[slot] = entry
    end
  end

  for spellID, binding in pairs(entry.spells) do
    _kbMacroSpellIDToKey[spellID] = _kbMacroSpellIDToKey[spellID] or binding
  end
  for name, binding in pairs(entry.names) do
    _kbMacroSpellNameToKey[name] = _kbMacroSpellNameToKey[name] or binding
  end
  for itemID, binding in pairs(entry.items) do
    _kbMacroItemToKey[itemID] = _kbMacroItemToKey[itemID] or binding
  end
  for equipSlot, binding in pairs(entry.equipSlots) do
    _kbMacroEquipSlotToKey[equipSlot] = _kbMacroEquipSlotToKey[equipSlot] or binding
  end
end

local function _KB_BuildFallbackMaps()
  if _kbFallbackMapsBlocked then
    return false
  end

  local needItems = not _kbItemMapBuilt
  local needMacros = not _kbMacroMapBuilt
  local refreshSnapshot = not _kbActionSnapshotReady
  if not refreshSnapshot and not needItems and not needMacros then
    return true
  end

  if refreshSnapshot then
    _kbActionSnapshotReady = true
    wipe(_kbActionSlotKnown)
    wipe(_kbActionSlotType)
    wipe(_kbActionSlotID)
  end
  if needItems then
    wipe(_kbItemSlots)
  end
  if needMacros then
    wipe(_kbMacroSpellIDToKey)
    wipe(_kbMacroSpellNameToKey)
    wipe(_kbMacroItemToKey)
    wipe(_kbMacroEquipSlotToKey)
  end

  local blocked = false
  for slot = 1, 192 do
    if _KB_IsMappedActionSlot(slot) then
      if refreshSnapshot then
        local actionType, actionID = GetActionInfo(slot)
        if _KB_IsSecret(actionType) or _KB_IsSecret(actionID) then
          blocked = true
        else
          _kbActionSlotKnown[slot] = true
          _kbActionSlotType[slot] = actionType or false
          _kbActionSlotID[slot] = actionID or false
        end
      end

      local actionType = _kbActionSlotType[slot]
      local actionID = _kbActionSlotID[slot]
      if not _kbActionSlotKnown[slot] then
        blocked = true
      elseif needItems and actionType == "item" then
        local itemID = _KB_PositiveNumber(actionID)
        if itemID then
          local slots = _kbItemSlots[itemID]
          if not slots then
            slots = {}
            _kbItemSlots[itemID] = slots
          end
          slots[#slots + 1] = slot
        end
      elseif needMacros and actionType == "macro" then
        local macroID = _KB_PositiveNumber(actionID)
        if macroID then
          local key = _KB_KeybindForSlot(slot)
          if key then _KB_IndexMacroSlot(slot, macroID, key) end
        end
      end
    end
  end

  if blocked then
    if needItems then
      wipe(_kbItemSlots)
    end
    if needMacros then
      wipe(_kbMacroSpellIDToKey)
      wipe(_kbMacroSpellNameToKey)
      wipe(_kbMacroItemToKey)
      wipe(_kbMacroEquipSlotToKey)
    end
    _kbFallbackMapsBlocked = true
    return false
  end

  if needItems then
    _kbItemMapBuilt = true
  end
  if needMacros then
    _kbMacroMapBuilt = true
  end
  return true
end

function Cooldowns:GetSpellKeybind(spellID)
  if _KB_IsSecret(spellID) then return nil, true end

  local requested = _KB_PositiveNumber(spellID)
  if not requested then return nil, false end

  local cached = _kbSpellKeyCache[requested]
  if cached ~= nil then
    return cached or nil, false
  end

  local baseSpellID, currentSpellID, blocked = _KB_NormalizeSpellID(requested)
  if blocked then return nil, true end

  cached = _kbSpellKeyCache[baseSpellID]
  if cached ~= nil then
    _kbSpellKeyCache[requested] = cached
    _kbSpellKeyCache[currentSpellID] = cached
    return cached or nil, false
  end

  local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
  local key
  key, blocked = _KB_SelectKeybindFromSlots(slots)
  if blocked then return nil, true end
  if key then
    _KB_CacheSpell(baseSpellID, currentSpellID, key)
    _kbSpellKeyCache[requested] = key
    return key, false
  end

  if not _kbMacroMapBuilt then
    if _kbFallbackMapsBlocked or not _KB_BuildFallbackMaps() then
      return nil, true
    end
  end

  key = _kbMacroSpellIDToKey[baseSpellID] or _kbMacroSpellIDToKey[currentSpellID]
  if not key then
    local name = _KB_SpellName(currentSpellID)
    key = name and _kbMacroSpellNameToKey[name:lower()] or nil
  end
  if not key and baseSpellID ~= currentSpellID then
    local name = _KB_SpellName(baseSpellID)
    key = name and _kbMacroSpellNameToKey[name:lower()] or nil
  end

  if key then
    _KB_CacheSpell(baseSpellID, currentSpellID, key)
    _kbSpellKeyCache[requested] = key
  else
    _kbSpellKeyCache[baseSpellID] = false
    _kbSpellKeyCache[currentSpellID] = false
    _kbSpellKeyCache[requested] = false
  end
  return key, false
end

function Cooldowns:GetItemKeybind(itemID)
  if _KB_IsSecret(itemID) then return nil, true end

  itemID = _KB_PositiveNumber(itemID)
  if not itemID then return nil, false end

  local cached = _kbItemKeyCache[itemID]
  if cached ~= nil then
    return cached or nil, false
  end

  local _, itemSpellID = C_Item.GetItemSpell(itemID)
  if _KB_IsSecret(itemSpellID) then return nil, true end
  itemSpellID = _KB_PositiveNumber(itemSpellID)
  if itemSpellID then
    local key, blocked = self:GetSpellKeybind(itemSpellID)
    if blocked then return nil, true end
    if key then
      _kbItemKeyCache[itemID] = key
      return key, false
    end
  end

  if not _kbItemMapBuilt or not _kbMacroMapBuilt then
    if _kbFallbackMapsBlocked or not _KB_BuildFallbackMaps() then
      return nil, true
    end
  end

  cached = _kbMacroItemToKey[itemID]
  if cached then
    _kbItemKeyCache[itemID] = cached
    return cached, false
  end

  local slots = _kbItemSlots[itemID]
  if slots then
    local key, blocked = _KB_SelectKeybindFromSlots(slots)
    if blocked then return nil, true end
    if key then
      _kbItemKeyCache[itemID] = key
      return key, false
    end
  end

  _kbItemKeyCache[itemID] = false
  return nil, false
end

function Cooldowns:GetEquipmentSlotKeybind(equipSlot)
  if _KB_IsSecret(equipSlot) then return nil, true end

  equipSlot = _KB_PositiveNumber(equipSlot)
  if not equipSlot then return nil, false end

  local cached = _kbEquipSlotKeyCache[equipSlot]
  if cached ~= nil then
    return cached or nil, false
  end

  local itemID = GetInventoryItemID("player", equipSlot)
  if _KB_IsSecret(itemID) then return nil, true end
  itemID = _KB_PositiveNumber(itemID)
  if itemID then
    local key, blocked = self:GetItemKeybind(itemID)
    if blocked then return nil, true end
    if key then
      _kbEquipSlotKeyCache[equipSlot] = key
      return key, false
    end
  end

  if not _kbItemMapBuilt or not _kbMacroMapBuilt then
    if _kbFallbackMapsBlocked or not _KB_BuildFallbackMaps() then
      return nil, true
    end
  end

  cached = _kbMacroEquipSlotToKey[equipSlot]
  if cached then
    _kbEquipSlotKeyCache[equipSlot] = cached
    return cached, false
  end

  _kbEquipSlotKeyCache[equipSlot] = false
  return nil, false
end

local function _KB_RefreshOwnedKeybinds()
  ns.PCMAbilityRuntime:MarkBucketDirty(
    "keybind",
    ns.PCMAbilityRuntime.DIRTY_STATE
  )
end

function Cooldowns:GetKeybindTextEnabled(viewerKey)
  if not viewerKey then
    return true
  end

  local flags = self._GetViewerCountFlagsCached(viewerKey)
  return not flags or flags.keybind == true
end

local function _KB_HasActiveConsumer()
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return false
  end

  return Cooldowns:GetKeybindTextEnabled("EssentialCooldownViewer")
    or Cooldowns:GetKeybindTextEnabled("UtilityCooldownViewer")
    or IconSettings:HasShownTextOverride("keybind")
    or (Cooldowns:GetConsumableTrackerEnabled() and DB.GetConsumableTrackerDB().showKeybinds == true)
end

local _kbActive = false
local _kbDirty = false
local _kbFullRebuild = false
local _kbContentRebuild = false
local _kbBindingRebuild = false
local _kbBootstrapEventsRegistered = false
local _kbMappingEventsRegistered = false

local _KB_BOOTSTRAP_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "COOLDOWN_VIEWER_DATA_LOADED",
  "ADDON_RESTRICTION_STATE_CHANGED",
}

local _KB_MAPPING_EVENTS = {
  "ACTIONBAR_SLOT_CHANGED",
  "UPDATE_BINDINGS",
  "UPDATE_MACROS",
}

local _KB_BINDING_REBUILD_EVENTS = {
  UPDATE_BINDINGS = true,
  UPDATE_MACROS = true,
}

local _kbEventFrame = CreateFrame("Frame")
_kbEventFrame:Hide()

local function _KB_DoRefresh(full, content, bindings)
  if not _kbActive then
    return
  end

  if full then
    _KB_RefreshBarTopology()
    _KB_InvalidateAll()
  else
    if content then
      _KB_InvalidateActionContent()
    end
    if bindings then
      _KB_InvalidateBindings()
    end
  end

  _kbCacheReady = _KB_BuildFallbackMaps()
  _KB_RefreshOwnedKeybinds()
  Cooldowns:ConsumableTracker_RefreshKeybinds()
end

local function _KB_OnRefreshFrameUpdate(self)
  self:Hide()

  _kbDirty = false

  local full = _kbFullRebuild
  local content = _kbContentRebuild
  local bindings = _kbBindingRebuild
  _kbFullRebuild = false
  _kbContentRebuild = false
  _kbBindingRebuild = false
  _KB_DoRefresh(full, content, bindings)
end

_KB_ScheduleRebuild = function(mode)
  if not _kbActive then
    return
  end

  if mode == true then
    _kbFullRebuild = true
  elseif mode == "content" then
    _kbContentRebuild = true
  elseif mode == false then
    _kbBindingRebuild = true
  end
  if _kbDirty then
    return
  end

  _kbDirty = true
  _kbEventFrame:Show()
end



local function _KB_RegisterBootstrapEvents()
  if _kbBootstrapEventsRegistered then
    return
  end

  for index = 1, #_KB_BOOTSTRAP_EVENTS do
    _kbEventFrame:RegisterEvent(_KB_BOOTSTRAP_EVENTS[index])
  end
  _kbBootstrapEventsRegistered = true
end

local function _KB_UnregisterBootstrapEvents()
  if not _kbBootstrapEventsRegistered then
    return
  end

  for index = 1, #_KB_BOOTSTRAP_EVENTS do
    _kbEventFrame:UnregisterEvent(_KB_BOOTSTRAP_EVENTS[index])
  end
  _kbBootstrapEventsRegistered = false
end

local function _KB_RegisterMappingEvents()
  if _kbMappingEventsRegistered then
    return
  end

  for index = 1, #_KB_MAPPING_EVENTS do
    _kbEventFrame:RegisterEvent(_KB_MAPPING_EVENTS[index])
  end
  _kbMappingEventsRegistered = true
end

local function _KB_UnregisterMappingEvents()
  if not _kbMappingEventsRegistered then
    return
  end

  for index = 1, #_KB_MAPPING_EVENTS do
    _kbEventFrame:UnregisterEvent(_KB_MAPPING_EVENTS[index])
  end
  _kbMappingEventsRegistered = false
end

_KB_UpdateConsumerState = function()
  local nowActive = _KB_HasActiveConsumer()
  if nowActive == _kbActive then
    return
  end

  _kbActive = nowActive
  if _kbActive then
    _KB_RegisterMappingEvents()
    _KB_ScheduleRebuild(true)
  else
    _KB_UnregisterMappingEvents()
  end
end

local function _KB_OnEvent(_, event, arg1, arg2)
  if event == "PLAYER_ENTERING_WORLD" or event == "COOLDOWN_VIEWER_DATA_LOADED" then
    _KB_UpdateConsumerState()
    if _kbActive and not _kbCacheReady and not _kbDirty then
      _KB_ScheduleRebuild(true)
    end
    return
  end

  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if arg2 == Enum.AddOnRestrictionState.Inactive and _kbActive and _kbFallbackMapsBlocked then
      _KB_ScheduleRebuild(true)
    end
    return
  end

  if not _kbActive then
    return
  end

  if event == "ACTIONBAR_SLOT_CHANGED" then
    if _KB_ActionSlotContentChanged(arg1) then
      _KB_ScheduleRebuild("content")
    end
    return
  end

  if _KB_BINDING_REBUILD_EVENTS[event] then
    _KB_ScheduleRebuild(false)
  end
end

function Cooldowns:SetKeybindTextEnabled(viewerKey, enabled)
  local cfg = ns.PCM_DBExports.GetViewerCountDB(viewerKey)
  if not cfg then
    return
  end

  cfg.keybind = enabled == true
  self._SetViewerCountFlagCached(viewerKey, "keybind", cfg.keybind)
  _KB_UpdateConsumerState()
  _KB_RefreshOwnedKeybinds()
end

local PCMKeybinds = {}
ns.PCMKeybinds = PCMKeybinds

function PCMKeybinds:GetForEntry(entry, runtimeRecord)
  if not entry then
    return nil
  end

  local record = ns.PCMIconSettings:GetRecordForEntry(entry, false)
  local show = record and record.keybind and record.keybind.show
  if show == nil then
    show = Cooldowns:GetKeybindTextEnabled(entry.viewerKey)
  end
  if show ~= true then
    return nil
  end

  if entry.entryKind == "equipmentSlot" then
    return Cooldowns:GetEquipmentSlotKeybind(entry.equipSlot)
  end

  if entry.entryKind == "spellCategory" then
    local itemID = runtimeRecord
      and runtimeRecord.safeContent
      and runtimeRecord.safeContent.categoryItemID
    if itemID then
      local keybind = Cooldowns:GetItemKeybind(itemID)
      if keybind then
        return keybind
      end
    end

    local itemIDs = Cooldowns:GetConsumableCategoryItemIDs(entry.spellCategoryID)
    for index = 1, #(itemIDs or {}) do
      local keybind = Cooldowns:GetItemKeybind(itemIDs[index])
      if keybind then
        return keybind
      end
    end
    return nil
  end

  local runtimeSpellID = runtimeRecord and runtimeRecord.runtimeSpellID
  if runtimeSpellID then
    local keybind = Cooldowns:GetSpellKeybind(runtimeSpellID)
    if keybind then
      return keybind
    end
  end

  for index = 1, #entry.identitySpellIDs do
    local spellID = entry.identitySpellIDs[index]
    local keybind = spellID ~= runtimeSpellID and Cooldowns:GetSpellKeybind(spellID)
    if keybind then
      return keybind
    end
  end

  return nil
end

function Cooldowns:ApplyKeybindTextRulesNow(viewerKey)
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return
  end

  _KB_UpdateConsumerState()
  _KB_RefreshOwnedKeybinds()
  Cooldowns:ConsumableTracker_RefreshKeybinds()
end

function Cooldowns:GetKeybindsEnabled(viewerKey)
  return _KB_IsAbilityViewerKey(viewerKey) and self:GetKeybindTextEnabled(viewerKey) == true
end

function Cooldowns:SetKeybindsEnabled(viewerKey, enabled)
  if not _KB_IsAbilityViewerKey(viewerKey) then
    return
  end

  self:SetKeybindTextEnabled(viewerKey, enabled == true)
end

function Cooldowns.RefreshKeybinds()
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return
  end

  _KB_UpdateConsumerState()
  if _kbActive then
    _KB_ScheduleRebuild(true)
  end
end

function Cooldowns:_Keybinds_Enable()
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return
  end

  _KB_RegisterBootstrapEvents()
  _KB_UpdateConsumerState()
  if _kbActive then
    _KB_ScheduleRebuild(true)
  end
end

function Cooldowns:_Keybinds_Disable()
  _kbActive = false
  _kbDirty = false
  _kbFullRebuild = false
  _kbContentRebuild = false
  _kbBindingRebuild = false
  _kbEventFrame:Hide()
  _KB_UnregisterMappingEvents()
  _KB_UnregisterBootstrapEvents()
  _KB_InvalidateAll()
  wipe(_kbActionSlotKnown)
  wipe(_kbActionSlotType)
  wipe(_kbActionSlotID)
end

function Cooldowns:_Keybinds_RefreshIconSettings(viewerKey)
  _KB_UpdateConsumerState()
  _KB_RefreshOwnedKeybinds()
end


_KB_FormatKeybind = P:Def("_KB_FormatKeybind", _KB_FormatKeybind)
_KB_IsAbilityViewerKey = P:Def("_KB_IsAbilityViewerKey", _KB_IsAbilityViewerKey)
_KB_RefreshBarTopology = P:Def("_KB_RefreshBarTopology", _KB_RefreshBarTopology)
_KB_IsMappedActionSlot = P:Def("_KB_IsMappedActionSlot", _KB_IsMappedActionSlot)
_KB_InvalidateBindings = P:Def("_KB_InvalidateBindings", _KB_InvalidateBindings)
_KB_InvalidateAll = P:Def("_KB_InvalidateAll", _KB_InvalidateAll)
_KB_InvalidateActionContent = P:Def("_KB_InvalidateActionContent", _KB_InvalidateActionContent)
_KB_ActionSlotContentChanged = P:Def("_KB_ActionSlotContentChanged", _KB_ActionSlotContentChanged)
_KB_ButtonIndexForActionIndex = P:Def("_KB_ButtonIndexForActionIndex", _KB_ButtonIndexForActionIndex)
_KB_KeybindForBinding = P:Def("_KB_KeybindForBinding", _KB_KeybindForBinding)
_KB_KeybindForSlot = P:Def("_KB_KeybindForSlot", _KB_KeybindForSlot)
_KB_NormalizeSpellID = P:Def("_KB_NormalizeSpellID", _KB_NormalizeSpellID)
_KB_ParseMacroBody = P:Def("_KB_ParseMacroBody", _KB_ParseMacroBody)
_KB_BuildFallbackMaps = P:Def("_KB_BuildFallbackMaps", _KB_BuildFallbackMaps)
Cooldowns.GetSpellKeybind = P:Def("Cooldowns:GetSpellKeybind", Cooldowns.GetSpellKeybind)
Cooldowns.GetItemKeybind = P:Def("Cooldowns:GetItemKeybind", Cooldowns.GetItemKeybind)
Cooldowns.GetEquipmentSlotKeybind = P:Def("Cooldowns:GetEquipmentSlotKeybind", Cooldowns.GetEquipmentSlotKeybind)
Cooldowns.GetKeybindTextEnabled = P:Def("Cooldowns:GetKeybindTextEnabled", Cooldowns.GetKeybindTextEnabled)
Cooldowns.SetKeybindTextEnabled = P:Def("Cooldowns:SetKeybindTextEnabled", Cooldowns.SetKeybindTextEnabled)
Cooldowns.ApplyKeybindTextRulesNow = P:Def("Cooldowns:ApplyKeybindTextRulesNow", Cooldowns.ApplyKeybindTextRulesNow)
Cooldowns.GetKeybindsEnabled = P:Def("Cooldowns:GetKeybindsEnabled", Cooldowns.GetKeybindsEnabled)
Cooldowns.SetKeybindsEnabled = P:Def("Cooldowns:SetKeybindsEnabled", Cooldowns.SetKeybindsEnabled)
_KB_HasActiveConsumer = P:Def("_KB_HasActiveConsumer", _KB_HasActiveConsumer)
_KB_DoRefresh = P:Def("_KB_DoRefresh", _KB_DoRefresh)
_KB_OnRefreshFrameUpdate = P:Def("_KB_OnRefreshFrameUpdate", _KB_OnRefreshFrameUpdate)
_KB_ScheduleRebuild = P:Def("_KB_ScheduleRebuild", _KB_ScheduleRebuild)
_KB_RegisterBootstrapEvents = P:Def("_KB_RegisterBootstrapEvents", _KB_RegisterBootstrapEvents)
_KB_UnregisterBootstrapEvents = P:Def("_KB_UnregisterBootstrapEvents", _KB_UnregisterBootstrapEvents)
_KB_RegisterMappingEvents = P:Def("_KB_RegisterMappingEvents", _KB_RegisterMappingEvents)
_KB_UnregisterMappingEvents = P:Def("_KB_UnregisterMappingEvents", _KB_UnregisterMappingEvents)
_KB_UpdateConsumerState = P:Def("_KB_UpdateConsumerState", _KB_UpdateConsumerState)
_KB_OnEvent = P:Def("_KB_OnEvent", _KB_OnEvent)
Cooldowns.RefreshKeybinds = P:Def("Cooldowns:RefreshKeybinds", Cooldowns.RefreshKeybinds)
Cooldowns._Keybinds_Enable = P:Def("Cooldowns:_Keybinds_Enable", Cooldowns._Keybinds_Enable)
Cooldowns._Keybinds_Disable = P:Def("Cooldowns:_Keybinds_Disable", Cooldowns._Keybinds_Disable)
Cooldowns._Keybinds_RefreshIconSettings = P:Def("Cooldowns:_Keybinds_RefreshIconSettings", Cooldowns._Keybinds_RefreshIconSettings)

_kbEventFrame:SetScript("OnUpdate", _KB_OnRefreshFrameUpdate)
_kbEventFrame:SetScript("OnEvent", _KB_OnEvent)
