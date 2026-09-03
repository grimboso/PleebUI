-- File: PUI_PCM_Keybinds.lua
-- Purpose:
--   - Resolve live action-bar keybinds and render them on PCM cooldown viewers.
local ADDON_NAME, ns = ...
local Cooldowns = ns.Modules.CooldownManager
local Hooks = ns.PCMHooks
local IconSettings = ns.PCMIconSettings
local PCMRuntime = ns.PCMRuntime
local LSM = ns.LSM
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
local _kbItemMapBuilt = false
local _kbMacroMapBuilt = false
local _kbFallbackMapsBlocked = false
local _kbFormattedKeyCache = {}
local _kbMainBarSlots = nil
local _kbActionSlotKnown = {}
local _kbActionSlotType = {}
local _kbActionSlotID = {}

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

local function _KB_IsEssentialViewerKey(viewerKey)
  if type(viewerKey) ~= "string" or viewerKey == "" then
    return false
  end
  if viewerKey == "UtilityCooldownViewer" then
    return true
  end
  return string.find(viewerKey, "EssentialCooldownViewer", 1, true) == 1
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
  [16] = "MULTIACTIONBAR8BUTTON",
}

local function _KB_PositiveNumber(value)
  if _KB_IsSecret(value) then
    return nil
  end

  value = tonumber(value)
  return value and value > 0 and value or nil
end

local function _KB_IsMappedActionSlot(slot)
  local page = math_ceil(slot / _KB_SLOTS_PER_PAGE)
  return page == 1 or page == 2 or _KB_BAR_COMMANDS[page] ~= nil
end

local function _KB_InvalidateBindings()
  wipe(_kbSpellKeyCache)
  wipe(_kbItemKeyCache)
  wipe(_kbEquipSlotKeyCache)
  wipe(_kbMacroSpellIDToKey)
  wipe(_kbMacroSpellNameToKey)
  _kbMacroMapBuilt = false
  _kbFallbackMapsBlocked = false
end

local function _KB_InvalidateAll()
  _KB_InvalidateBindings()
  wipe(_kbItemSlots)
  _kbItemMapBuilt = false
  _kbMainBarSlots = nil
end

local function _KB_RefreshActionSlotSnapshot()
  wipe(_kbActionSlotKnown)
  wipe(_kbActionSlotType)
  wipe(_kbActionSlotID)

  for slot = 1, 192 do
    if _KB_IsMappedActionSlot(slot) then
      local actionType, actionID = GetActionInfo(slot)
      if not _KB_IsSecret(actionType) and not _KB_IsSecret(actionID) then
        _kbActionSlotKnown[slot] = true
        _kbActionSlotType[slot] = actionType or false
        _kbActionSlotID[slot] = actionID or false
      end
    end
  end
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

        if _kbActionSlotKnown[actionSlot]
          and (_kbActionSlotType[actionSlot] ~= normalizedType or _kbActionSlotID[actionSlot] ~= normalizedID) then
          changed = true
        end

        _kbActionSlotKnown[actionSlot] = true
        _kbActionSlotType[actionSlot] = normalizedType
        _kbActionSlotID[actionSlot] = normalizedID
      end
    end
  end

  return changed
end


local function _KB_MapWholePage(target, page)
  if _KB_IsSecret(page) then
    return false
  end

  page = _KB_PositiveNumber(page)
  if not page then
    return false
  end

  local base = (page - 1) * _KB_SLOTS_PER_PAGE
  for index = 1, _KB_SLOTS_PER_PAGE do
    target[base + index] = index
  end
  return true
end

local function _KB_MapMainPage(target, page)
  if _KB_IsSecret(page) then
    return false
  end

  page = _KB_PositiveNumber(page)
  if not page then
    return false
  end

  local base = (page - 1) * _KB_SLOTS_PER_PAGE
  local mapped = false

  for bindingIndex = 1, _KB_SLOTS_PER_PAGE do
    local button = _G["PUI_ActionButton" .. bindingIndex]
    local actionButtonIndex = button and _KB_PositiveNumber(button.__puiActionButtonIndex) or nil
    if actionButtonIndex then
      target[base + actionButtonIndex] = bindingIndex
      mapped = true
    end
  end

  if mapped then
    return true
  end

  return _KB_MapWholePage(target, page)
end

local function _KB_BuildMainBarSlots()
  local target = {}
  _KB_MapMainPage(target, 1)
  _KB_MapMainPage(target, 2)
  return target
end

local function _KB_MainBarIndexForSlot(slot)
  if not _kbMainBarSlots then
    _kbMainBarSlots = _KB_BuildMainBarSlots()
  end
  return _kbMainBarSlots[slot]
end

local function _KB_BindingForSlot(slot)
  if _KB_IsSecret(slot) then
    return nil, true
  end

  slot = _KB_PositiveNumber(slot)
  if not slot then
    return nil, false
  end

  local mainIndex = _KB_MainBarIndexForSlot(slot)
  if mainIndex then
    return "ACTIONBUTTON" .. mainIndex, false
  end

  local command = _KB_BAR_COMMANDS[math_ceil(slot / _KB_SLOTS_PER_PAGE)]
  if not command then
    return nil, false
  end

  return command .. (((slot - 1) % _KB_SLOTS_PER_PAGE) + 1), false
end

local function _KB_KeybindForSlot(slot)
  local bindingAction, blocked = _KB_BindingForSlot(slot)
  if blocked or not bindingAction then
    return nil, blocked
  end

  local key = GetBindingKey(bindingAction)
  if _KB_IsSecret(key) then
    return nil, true
  end
  return _KB_FormatKeybind(key), false
end

local function _KB_ShortestFromSlots(slots)
  if _KB_IsSecret(slots) then
    return nil, true
  end
  if type(slots) ~= "table" then
    return nil, false
  end

  local best = nil
  local blocked = false

  for index = 1, #slots do
    local slot = slots[index]
    if _KB_IsSecret(slot) then
      blocked = true
    else
      local key, slotBlocked = _KB_KeybindForSlot(slot)
      if slotBlocked then
        blocked = true
      elseif key and (not best or #key < #best) then
        best = key
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
  return not _KB_IsSecret(name) and type(name) == "string" and name ~= "" and name or nil
end

local function _KB_SpellIDFromName(name)
  if _KB_IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
  return _KB_PositiveNumber(C_Spell.GetSpellIDForSpellIdentifier(name))
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

local function _KB_IndexMacroSpell(spellID, key)
  local baseSpellID, currentSpellID, blocked = _KB_NormalizeSpellID(spellID)
  if blocked or not baseSpellID then return end

  _kbMacroSpellIDToKey[baseSpellID] = _kbMacroSpellIDToKey[baseSpellID] or key
  _kbMacroSpellIDToKey[currentSpellID] = _kbMacroSpellIDToKey[currentSpellID] or key

  local name = _KB_SpellName(currentSpellID)
  if name then
    _kbMacroSpellNameToKey[name:lower()] = _kbMacroSpellNameToKey[name:lower()] or key
  end

  if baseSpellID ~= currentSpellID then
    name = _KB_SpellName(baseSpellID)
    if name then
      _kbMacroSpellNameToKey[name:lower()] = _kbMacroSpellNameToKey[name:lower()] or key
    end
  end
end

local function _KB_IndexMacroItem(itemID, key)
  itemID = _KB_PositiveNumber(itemID)
  if itemID and _kbItemKeyCache[itemID] == nil then
    _kbItemKeyCache[itemID] = key
  end
end

local function _KB_IndexMacroSlot(slot, actionID, key)
  local macroIndex = _KB_ResolveMacroIndex(slot, actionID)
  if not macroIndex then return end

  local macroSpell = GetMacroSpell(macroIndex)
  if not _KB_IsSecret(macroSpell) and macroSpell then
    if type(macroSpell) == "number" then
      _KB_IndexMacroSpell(macroSpell, key)
    elseif type(macroSpell) == "string" then
      local spellID = _KB_SpellIDFromName(macroSpell)
      if spellID then _KB_IndexMacroSpell(spellID, key) end
    end
  end

  local _, _, macroItemID = GetMacroItem(macroIndex)
  if not _KB_IsSecret(macroItemID) and macroItemID then
    _KB_IndexMacroItem(macroItemID, key)
  end

  local values = _KB_ParseMacroBody(_KB_GetMacroBodySafe(macroIndex))
  if not values then return end

  for index = 1, #values do
    local value = values[index]
    local equipSlot = tonumber(value)
    local explicitItemID = value:match("^item:(%d+)$")

    if equipSlot == 13 or equipSlot == 14 then
      _kbEquipSlotKeyCache[equipSlot] = _kbEquipSlotKeyCache[equipSlot] or key
    elseif explicitItemID then
      _KB_IndexMacroItem(explicitItemID, key)
    else
      local itemID = C_Item.GetItemInfoInstant(value)
      if not _KB_IsSecret(itemID) and itemID then
        _KB_IndexMacroItem(itemID, key)
      else
        _kbMacroSpellNameToKey[value:lower()] = _kbMacroSpellNameToKey[value:lower()] or key
        local spellID = _KB_SpellIDFromName(value)
        if spellID then _KB_IndexMacroSpell(spellID, key) end
      end
    end
  end
end

local function _KB_BuildFallbackMaps()
  if _kbFallbackMapsBlocked then
    return false
  end

  local needItems = not _kbItemMapBuilt
  local needMacros = not _kbMacroMapBuilt
  if not needItems and not needMacros then
    return true
  end

  if needItems then
    wipe(_kbItemSlots)
  end
  if needMacros then
    wipe(_kbMacroSpellIDToKey)
    wipe(_kbMacroSpellNameToKey)
    wipe(_kbEquipSlotKeyCache)
  end

  local blocked = false
  for slot = 1, 192 do
    if _KB_IsMappedActionSlot(slot) then
      local actionType, actionID = GetActionInfo(slot)
      if _KB_IsSecret(actionType) or _KB_IsSecret(actionID) then
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
      wipe(_kbItemKeyCache)
      wipe(_kbEquipSlotKeyCache)
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
  key, blocked = _KB_ShortestFromSlots(slots)
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

local function _KB_LookupItem(itemID)
  if _KB_IsSecret(itemID) then return nil, true end

  itemID = _KB_PositiveNumber(itemID)
  if not itemID then return nil, false end

  local cached = _kbItemKeyCache[itemID]
  if cached ~= nil then
    return cached or nil, false
  end

  local _, itemSpellID = GetItemSpell(itemID)
  if _KB_IsSecret(itemSpellID) then return nil, true end
  itemSpellID = _KB_PositiveNumber(itemSpellID)
  if itemSpellID then
    local key, blocked = Cooldowns:GetSpellKeybind(itemSpellID)
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

  cached = _kbItemKeyCache[itemID]
  if cached ~= nil then
    return cached or nil, false
  end

  local slots = _kbItemSlots[itemID]
  if slots then
    local key, blocked = _KB_ShortestFromSlots(slots)
    if blocked then return nil, true end
    if key then
      _kbItemKeyCache[itemID] = key
      return key, false
    end
  end

  _kbItemKeyCache[itemID] = false
  return nil, false
end

local function _KB_LookupEquipmentSlot(equipSlot)
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
    local key, blocked = _KB_LookupItem(itemID)
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

  cached = _kbEquipSlotKeyCache[equipSlot]
  if cached ~= nil then
    return cached or nil, false
  end

  _kbEquipSlotKeyCache[equipSlot] = false
  return nil, false
end

function Cooldowns:GetItemKeybind(itemID)
  return _KB_LookupItem(itemID)
end

function Cooldowns:GetEquipmentSlotKeybind(equipSlot)
  return _KB_LookupEquipmentSlot(equipSlot)
end

local function _KB_EnsureHotKeyFontString(item)
  local st = Hooks.GetFrameData(item)
  local fs = st.keybindText
  if fs then
    return fs, false
  end

  local overlay = CreateFrame("Frame", nil, item)
  overlay:SetAllPoints()
  overlay:SetFrameLevel(item:GetFrameLevel() + 20)
  st.keybindOverlay = overlay

  fs = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
  fs:SetDrawLayer("OVERLAY", 7)
  fs:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -2)
  fs:SetJustifyH("LEFT")
  fs:SetText("")
  fs:Hide()

  st.keybindText = fs
  return fs, true
end

local function _KB_ClearItem(item)
  local st = Hooks.PeekFrameData(item)
  local fs = st and st.keybindText
  if fs then
    fs:SetText("")
    fs:Hide()
  end
end

local function _KB_GetSpellIDsFromItem(item)
  local cooldownInfo
  if type(item.GetCooldownInfo) == "function" then
    cooldownInfo = item:GetCooldownInfo()
    if _KB_IsSecret(cooldownInfo) then
      return nil, nil, true
    end
  end

  if cooldownInfo == nil then
    cooldownInfo = item.cooldownInfo
    if _KB_IsSecret(cooldownInfo) then
      return nil, nil, true
    end
  end

  if type(cooldownInfo) ~= "table" then
    return nil, nil, false
  end

  local overrideSpellID = cooldownInfo.overrideSpellID
  if _KB_IsSecret(overrideSpellID) then
    return nil, nil, true
  end
  overrideSpellID = _KB_PositiveNumber(overrideSpellID)

  local baseSpellID = cooldownInfo.spellID
  if _KB_IsSecret(baseSpellID) then
    return nil, nil, true
  end
  baseSpellID = _KB_PositiveNumber(baseSpellID)

  return baseSpellID, overrideSpellID, false
end

local function _KB_GetItemKeybind(item, baseSpellID, overrideSpellID)
  if overrideSpellID then
    local key, blocked = Cooldowns:GetSpellKeybind(overrideSpellID)
    if blocked then return nil, true end
    if key then return key, false end
  end

  if baseSpellID then
    local key, blocked = Cooldowns:GetSpellKeybind(baseSpellID)
    if blocked then return nil, true end
    if key then return key, false end
  end

  if type(item.GetEquipSlot) == "function" then
    local equipSlot = item:GetEquipSlot()
    if _KB_IsSecret(equipSlot) then return nil, true end
    equipSlot = _KB_PositiveNumber(equipSlot)
    if equipSlot then
      local key, blocked = _KB_LookupEquipmentSlot(equipSlot)
      if blocked then return nil, true end
      if key then return key, false end
    end
  end

  if type(item.GetSpellCategory) ~= "function" then
    return nil, false
  end

  local categoryID = item:GetSpellCategory()
  if _KB_IsSecret(categoryID) then return nil, true end
  categoryID = _KB_PositiveNumber(categoryID)
  if not categoryID then return nil, false end

  local itemIDs = Cooldowns:GetConsumableCategoryItemIDs(categoryID)
  if not itemIDs then return nil, false end

  if type(item.GetSpellCategoryTooltipItemID) == "function" then
    local displayedItemID = item:GetSpellCategoryTooltipItemID()
    if _KB_IsSecret(displayedItemID) then return nil, true end
    local key, blocked = _KB_LookupItem(displayedItemID)
    if blocked then return nil, true end
    if key then return key, false end
  end

  for index = 1, #itemIDs do
    local itemID = itemIDs[index]
    if _KB_IsSecret(itemID) then
      return nil, true
    end

    local key, blocked = _KB_LookupItem(itemID)
    if blocked then return nil, true end
    if key then return key, false end
  end

  return nil, false
end

local function _KB_ApplyFontStyle(item, fs, viewerKey)
  local opts = IconSettings:ResolveFontOptions(
    item,
    viewerKey,
    "keybind",
    Cooldowns._ResolveFontOpts("keybind", viewerKey)
  )
  if not (opts and fs and fs.SetFont) then
    return
  end

  local curFont, curSize, curFlags = fs:GetFont()
  local face = curFont

  if opts.font then
    local path = LSM:Fetch("font", opts.font)
    face = (path and path ~= "") and path or opts.font
  end

  fs:SetFont(face, opts.size or curSize or 12, opts.flags or curFlags)

  if opts.color and fs.SetTextColor then
    fs:SetTextColor(
      opts.color[1] or 1,
      opts.color[2] or 1,
      opts.color[3] or 1,
      opts.color[4] or 1
    )
  end

  if fs.ClearAllPoints and fs.SetPoint then
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", item, "TOPLEFT", opts.offsetX or 0, opts.offsetY or 0)
  end
end

function Cooldowns._ApplyKeybindFontStyle(item, viewerKey)
  local st = Hooks.GetFrameData(item)
  local fs = st.keybindText
  if fs then
    _KB_ApplyFontStyle(item, fs, viewerKey)
  end
end

local function _KB_ApplyToItem(item, viewerKey, enabled)
  if not (item and item.CreateFontString) then
    return
  end

  local frameData = Hooks.PeekFrameData(item)
  local record = frameData and frameData.iconSettingsRecord or nil
  local keybindText = record and record.keybind or nil
  if keybindText and keybindText.show ~= nil then
    enabled = keybindText.show == true
  end

  if not enabled then
    _KB_ClearItem(item)
    return
  end

  local baseSpellID, overrideSpellID, blocked = _KB_GetSpellIDsFromItem(item)
  if blocked then
    return
  end

  local key
  key, blocked = _KB_GetItemKeybind(item, baseSpellID, overrideSpellID)
  if blocked then
    return
  end

  if not key or key == "" then
    _KB_ClearItem(item)
    return
  end

  local fs, created = _KB_EnsureHotKeyFontString(item)
  if created then
    _KB_ApplyFontStyle(item, fs, viewerKey)
  end

  fs:SetText(key)
  fs:Show()
end

local function _KB_ForEachActiveViewerItem(viewerKey, callback)
  local items = PCMRuntime:GetViewerItems(viewerKey)
  for index = 1, #items do
    local item = items[index]
    if item and not (item.IsForbidden and item:IsForbidden()) then
      callback(item)
    end
  end

  return true
end

local function _KB_ApplyToViewer(viewerKey)
  local enabled = ns.PCM_IsModuleEnabledFast() == true and Cooldowns:GetKeybindTextEnabled(viewerKey)
  _KB_ForEachActiveViewerItem(viewerKey, function(item)
    _KB_ApplyToItem(item, viewerKey, enabled)
  end)
end

local function _KB_ApplyAll()
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return
  end

  _KB_ApplyToViewer("EssentialCooldownViewer")
  _KB_ApplyToViewer("UtilityCooldownViewer")
end

function Cooldowns:GetKeybindTextEnabled(viewerKey)
  if not viewerKey then
    return true
  end

  local flags = self._GetViewerCountFlagsCached(viewerKey)
  return not flags or flags.keybind == true
end

local function _KB_ClearAll()
  _KB_ForEachActiveViewerItem("EssentialCooldownViewer", _KB_ClearItem)
  _KB_ForEachActiveViewerItem("UtilityCooldownViewer", _KB_ClearItem)
end

local function _KB_HasActiveConsumer()
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return false
  end

  return Cooldowns:GetKeybindTextEnabled("EssentialCooldownViewer")
    or Cooldowns:GetKeybindTextEnabled("UtilityCooldownViewer")
    or IconSettings:HasShownTextOverride("keybind")
    or (Cooldowns:GetConsumableTrackerEnabled() and Cooldowns:GetConsumableTrackerDB().showKeybinds == true)
end

local _kbActive = false
local _kbDirty = false
local _kbFullRebuild = false
local _kbBindingRebuild = false
local _kbBootstrapEventsRegistered = false
local _kbMappingEventsRegistered = false

local _KB_BOOTSTRAP_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "COOLDOWN_VIEWER_DATA_LOADED",
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

local function _KB_DoRefresh(full, bindings)
  if not _kbActive then
    return
  end

  if full then
    _KB_InvalidateAll()
  elseif bindings then
    _KB_InvalidateBindings()
  end

  if full or bindings then
    _KB_BuildFallbackMaps()
  end

  _KB_ApplyAll()
  Cooldowns:ConsumableTracker_RefreshKeybinds()

  if full then
    _KB_RefreshActionSlotSnapshot()
  end
end

local function _KB_OnRefreshFrameUpdate(self)
  self:Hide()
  _kbDirty = false

  local full = _kbFullRebuild
  local bindings = _kbBindingRebuild
  _kbFullRebuild = false
  _kbBindingRebuild = false
  _KB_DoRefresh(full, bindings)
end

_KB_ScheduleRebuild = function(mode)
  if not _kbActive then
    return
  end

  if mode == true then
    _kbFullRebuild = true
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

local function _KB_OnEvent(_, event, arg1)
  if event == "PLAYER_ENTERING_WORLD" or event == "COOLDOWN_VIEWER_DATA_LOADED" then
    _KB_UpdateConsumerState()
    if _kbActive then
      _KB_ScheduleRebuild(true)
    end
    return
  end

  if not _kbActive then
    return
  end

  if event == "ACTIONBAR_SLOT_CHANGED" then
    if _KB_ActionSlotContentChanged(arg1) then
      _KB_ScheduleRebuild(true)
    end
    return
  end

  if _KB_BINDING_REBUILD_EVENTS[event] then
    _KB_ScheduleRebuild(false)
  else
    _KB_ScheduleRebuild()
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

  if _kbActive then
    _KB_ScheduleRebuild()
  else
    _KB_ApplyToViewer(viewerKey)
  end
end

function Cooldowns:ApplyKeybindTextRulesNow(viewerKey)
  if not (ns.PCM_IsModuleEnabledFast() == true) then
    return
  end

  _KB_UpdateConsumerState()

  if viewerKey then
    _KB_ApplyToViewer(viewerKey)
  elseif _kbActive then
    _KB_DoRefresh(true)
  else
    _KB_ClearAll()
  end
end

function Cooldowns:GetKeybindsEnabled(viewerKey)
  return _KB_IsEssentialViewerKey(viewerKey) and self:GetKeybindTextEnabled(viewerKey) == true
end

function Cooldowns:SetKeybindsEnabled(viewerKey, enabled)
  if not _KB_IsEssentialViewerKey(viewerKey) then
    return
  end

  self:SetKeybindTextEnabled(viewerKey, enabled == true)
end

function Cooldowns:_ApplyKeybindTextRule(itemFrame, viewerKey)
  if not (_KB_IsEssentialViewerKey(viewerKey) and itemFrame) then
    return
  end

  _KB_ApplyToItem(itemFrame, viewerKey, self:GetKeybindTextEnabled(viewerKey))
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
  _kbBindingRebuild = false
  _kbEventFrame:Hide()
  _KB_UnregisterMappingEvents()
  _KB_UnregisterBootstrapEvents()
  _KB_ClearAll()
  _KB_InvalidateAll()
  wipe(_kbActionSlotKnown)
  wipe(_kbActionSlotType)
  wipe(_kbActionSlotID)
end

function Cooldowns:_Keybinds_RefreshIconSettings(viewerKey)
  _KB_UpdateConsumerState()

  if viewerKey then
    _KB_ForEachActiveViewerItem(viewerKey, function(item)
      local frameData = Hooks.PeekFrameData(item)
      local fs = frameData and frameData.keybindText
      if fs then
        _KB_ApplyFontStyle(item, fs, viewerKey)
      end
    end)
  end

  if _kbActive then
    _KB_ScheduleRebuild()
  elseif viewerKey then
    _KB_ApplyToViewer(viewerKey)
  end
end


_KB_FormatKeybind = P:Def("_KB_FormatKeybind", _KB_FormatKeybind)
_KB_IsEssentialViewerKey = P:Def("_KB_IsEssentialViewerKey", _KB_IsEssentialViewerKey)
_KB_IsMappedActionSlot = P:Def("_KB_IsMappedActionSlot", _KB_IsMappedActionSlot)
_KB_InvalidateBindings = P:Def("_KB_InvalidateBindings", _KB_InvalidateBindings)
_KB_InvalidateAll = P:Def("_KB_InvalidateAll", _KB_InvalidateAll)
_KB_RefreshActionSlotSnapshot = P:Def("_KB_RefreshActionSlotSnapshot", _KB_RefreshActionSlotSnapshot)
_KB_ActionSlotContentChanged = P:Def("_KB_ActionSlotContentChanged", _KB_ActionSlotContentChanged)
_KB_BuildMainBarSlots = P:Def("_KB_BuildMainBarSlots", _KB_BuildMainBarSlots)
_KB_BindingForSlot = P:Def("_KB_BindingForSlot", _KB_BindingForSlot)
_KB_KeybindForSlot = P:Def("_KB_KeybindForSlot", _KB_KeybindForSlot)
_KB_NormalizeSpellID = P:Def("_KB_NormalizeSpellID", _KB_NormalizeSpellID)
_KB_ParseMacroBody = P:Def("_KB_ParseMacroBody", _KB_ParseMacroBody)
_KB_BuildFallbackMaps = P:Def("_KB_BuildFallbackMaps", _KB_BuildFallbackMaps)
Cooldowns.GetSpellKeybind = P:Def("Cooldowns:GetSpellKeybind", Cooldowns.GetSpellKeybind)
Cooldowns.GetItemKeybind = P:Def("Cooldowns:GetItemKeybind", Cooldowns.GetItemKeybind)
Cooldowns.GetEquipmentSlotKeybind = P:Def("Cooldowns:GetEquipmentSlotKeybind", Cooldowns.GetEquipmentSlotKeybind)
_KB_EnsureHotKeyFontString = P:Def("_KB_EnsureHotKeyFontString", _KB_EnsureHotKeyFontString)
_KB_ClearItem = P:Def("_KB_ClearItem", _KB_ClearItem)
_KB_GetSpellIDsFromItem = P:Def("_KB_GetSpellIDsFromItem", _KB_GetSpellIDsFromItem)
_KB_GetItemKeybind = P:Def("_KB_GetItemKeybind", _KB_GetItemKeybind)
_KB_ApplyFontStyle = P:Def("_KB_ApplyFontStyle", _KB_ApplyFontStyle)
Cooldowns._ApplyKeybindFontStyle = P:Def("Cooldowns._ApplyKeybindFontStyle", Cooldowns._ApplyKeybindFontStyle)
_KB_ApplyToItem = P:Def("_KB_ApplyToItem", _KB_ApplyToItem)
_KB_ForEachActiveViewerItem = P:Def("_KB_ForEachActiveViewerItem", _KB_ForEachActiveViewerItem)
_KB_ApplyToViewer = P:Def("_KB_ApplyToViewer", _KB_ApplyToViewer)
_KB_ApplyAll = P:Def("_KB_ApplyAll", _KB_ApplyAll)
_KB_ClearAll = P:Def("_KB_ClearAll", _KB_ClearAll)
Cooldowns.GetKeybindTextEnabled = P:Def("Cooldowns:GetKeybindTextEnabled", Cooldowns.GetKeybindTextEnabled)
Cooldowns.SetKeybindTextEnabled = P:Def("Cooldowns:SetKeybindTextEnabled", Cooldowns.SetKeybindTextEnabled)
Cooldowns.ApplyKeybindTextRulesNow = P:Def("Cooldowns:ApplyKeybindTextRulesNow", Cooldowns.ApplyKeybindTextRulesNow)
Cooldowns._ApplyKeybindTextRule = P:Def("Cooldowns:_ApplyKeybindTextRule", Cooldowns._ApplyKeybindTextRule)
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
