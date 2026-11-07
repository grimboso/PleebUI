local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
if not ns.Client.IsForever then return end

local WeaponWarnings = {}
ns.WeaponWarnings = WeaponWarnings

local _, class = UnitClass("player")
local hands = {
  { inventorySlot = INVSLOT_MAINHAND, weaponSlot = Enum.WeaponSlot.MainHand, name = "MAIN-HAND" },
  { inventorySlot = INVSLOT_OFFHAND, weaponSlot = Enum.WeaponSlot.OffHand, name = "OFF-HAND" },
}
local imbueSpells = {
  SHAMAN = { 8017, 8024, 8033, 8232 },
  WARLOCK = { 6366, 2362 },
}
local events = CreateFrame("Frame")
local warning
local warningText
local profile
local pendingUpdate

local function GetClassWeaponBuff()
  if class == "ROGUE" then
    local level = UnitLevel("player")
    if not issecretvalue(level) and level >= 20 then return "POISON" end
    return
  end

  local spells = imbueSpells[class]
  if spells then
    for _, spellID in ipairs(spells) do
      if C_SpellBook.IsSpellKnown(spellID) then return "IMBUE" end
    end
  end
end

function WeaponWarnings.IsEnabled(db)
  if db.weaponBuffWarnings ~= nil then return db.weaponBuffWarnings == true end
  return class == "ROGUE" or imbueSpells[class] ~= nil
end

local function IsMissingWeaponBuff(hand, enchantType)
  local itemID = GetInventoryItemID("player", hand.inventorySlot)
  if issecretvalue(itemID) or not itemID then return false end

  local _, _, _, _, _, itemClass = C_Item.GetItemInfoInstant(itemID)
  if itemClass ~= Enum.ItemClass.Weapon then return false end

  local enchants = C_Item.GetWeaponEnchantInfo(hand.weaponSlot)
  if issecretvalue(enchants) then return false end
  for _, enchant in pairs(enchants) do
    if issecretvalue(enchant) then return false end
    local active, kind = enchant.hasEnchant, enchant.enchantType
    if issecretvalue(active) or issecretvalue(kind) then return false end
    if active and kind == enchantType then return false end
  end
  return true
end

function WeaponWarnings.RefreshFont()
  if warningText then
    ns.Theme.SetRuntimeFont(
      warningText,
      STANDARD_TEXT_FONT,
      ns.Theme.ResolveFontSize(32, "qualityOfLife"),
      "OUTLINE"
    )
  end
end

local function ShowWarning(message)
  if not warning then
    warning = CreateFrame("Frame", nil, UIParent)
    warning:SetSize(460, 70)
    warning:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    warning:SetFrameStrata("LOW")
    warning:EnableMouse(false)
    warningText = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    warningText:SetPoint("CENTER")
    warningText:SetJustifyH("CENTER")
    WeaponWarnings.RefreshFont()
    warningText:SetTextColor(1, 0.1, 0.1, 1)
  end

  warningText:SetText(message)
  warning:Show()
end

local function UpdateWarning()
  if InCombatLockdown() then
    if warning then warning:Hide() end
    return
  end

  local dead = UnitIsDeadOrGhost("player")
  if not issecretvalue(dead) and not dead then
    local buff = GetClassWeaponBuff()
    if buff or (class ~= "ROGUE" and not imbueSpells[class]) then
      local enchantType = buff and Enum.ItemEnchantType.Imbue or Enum.ItemEnchantType.Temporary
      local suffix = " " .. (buff or "WEAPON COATING") .. " MISSING"
      local message
      for _, hand in ipairs(hands) do
        if IsMissingWeaponBuff(hand, enchantType) then
          local line = hand.name .. suffix
          message = message and (message .. "\n" .. line) or line
        end
      end
      if message then
        ShowWarning(message)
        return
      end
    end
  end
  if warning then warning:Hide() end
end

local function FlushUpdate()
  pendingUpdate = nil
  UpdateWarning()
end

local function UpdateEvents(enteringCombat)
  if pendingUpdate then
    pendingUpdate:Cancel()
    pendingUpdate = nil
  end
  events:UnregisterAllEvents()
  if not WeaponWarnings.IsEnabled(profile) then
    if warning then warning:Hide() end
    return
  end

  if enteringCombat or InCombatLockdown() then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if warning then warning:Hide() end
    return
  end

  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
  events:RegisterEvent("WEAPON_SLOT_CHANGED")
  events:RegisterEvent("PLAYER_DEAD")
  events:RegisterEvent("PLAYER_ALIVE")
  events:RegisterEvent("PLAYER_UNGHOST")
  if class == "ROGUE" then
    events:RegisterEvent("PLAYER_LEVEL_UP")
  elseif imbueSpells[class] then
    events:RegisterEvent("SPELLS_CHANGED")
  end
  UpdateWarning()
end

events:SetScript("OnEvent", function(_, event, slot)
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    UpdateEvents(event == "PLAYER_REGEN_DISABLED")
  elseif event == "PLAYER_DEAD" then
    if warning then warning:Hide() end
  elseif not pendingUpdate and (event ~= "PLAYER_EQUIPMENT_CHANGED"
    or slot == INVSLOT_MAINHAND or slot == INVSLOT_OFFHAND)
  then
    pendingUpdate = C_Timer.NewTimer(0, FlushUpdate)
  end
end)

function WeaponWarnings.Apply(db)
  profile = db
  UpdateEvents()
end
