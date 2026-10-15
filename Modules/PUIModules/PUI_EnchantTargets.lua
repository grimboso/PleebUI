
local _, ns = ...

local EnchantTargets = ns.Addon:NewModule("EnchantTargets", "NumyAceEvent-3.0")
ns.Modules.EnchantTargets = EnchantTargets

local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local ItemLocation = _G.ItemLocation
local InCombatLockdown = _G.InCombatLockdown
local issecretvalue = _G.issecretvalue
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local pairs = _G.pairs

local dimmedButtons = {}
local hookedPaperDoll = false
local hookedBags = false

local function ClearEnchantTargetDimming()
  for button in pairs(dimmedButtons) do
    button._puiEnchantTargetDim:Hide()
    dimmedButtons[button] = nil
  end
end

local function DimIncompatibleItem(button, location)
  local exists = C_Item.DoesItemExist(location)
  if issecretvalue(exists) or not exists then
    return
  end

  local matches = C_Item.DoesItemMatchTargetEnchantingSpell(location)
  if issecretvalue(matches) or matches then
    return
  end

  local dim = button._puiEnchantTargetDim
  if not dim then
    dim = button:CreateTexture(nil, "OVERLAY", nil, 7)
    dim:SetAllPoints(button)
    dim:SetColorTexture(0, 0, 0, 0.68)
    button._puiEnchantTargetDim = dim
  end

  dim:Show()
  dimmedButtons[button] = true
end

local function DimIncompatibleEquipment()
  local frame = _G.PaperDollItemsFrame
  if not (frame and frame:IsShown()) then
    return
  end

  for _, button in ipairs({ frame:GetChildren() }) do
    if button.GetID and button:IsShown() then
      local slot = button:GetID()
      if not issecretvalue(slot) and slot and slot >= INVSLOT_FIRST_EQUIPPED and slot <= INVSLOT_LAST_EQUIPPED then
        DimIncompatibleItem(button, ItemLocation:CreateFromEquipmentSlot(slot))
      end
    end
  end
end

local function DimIncompatibleBagFrame(frame)
  if not (frame and frame:IsShown() and frame.Items) then
    return
  end

  for _, button in ipairs(frame.Items) do
    if button:IsShown() then
      local bag = button:GetBagID()
      local slot = button:GetID()
      if not issecretvalue(bag) and not issecretvalue(slot) and bag and slot then
        DimIncompatibleItem(button, ItemLocation:CreateFromBagAndSlot(bag, slot))
      end
    end
  end
end

local function DimIncompatibleBags()
  DimIncompatibleBagFrame(_G.ContainerFrameCombinedBags)
  DimIncompatibleBagFrame(_G.ContainerFrame6)

  local container = _G.ContainerFrameContainer
  if container and container.ContainerFrames then
    for _, frame in ipairs(container.ContainerFrames) do
      if frame ~= _G.ContainerFrameCombinedBags and frame ~= _G.ContainerFrame6 then
        DimIncompatibleBagFrame(frame)
      end
    end
  end
end

function EnchantTargets:RefreshEnchantTargets()
  if InCombatLockdown() then
    self:SuspendEnchantTargets()
    return
  end

  local enchanting = C_Spell.TargetSpellIsEnchanting()
  if issecretvalue(enchanting) or not enchanting then
    self:SuspendEnchantTargets()
    return
  end

  if not self.enchantTargeting then
    self.enchantTargeting = true
    self:RegisterEvent("BAG_UPDATE_DELAYED", "RefreshEnchantTargets")
    self:RegisterEvent("BAG_OPEN", "RefreshEnchantTargets")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "RefreshEnchantTargets")
  end

  ClearEnchantTargetDimming()
  DimIncompatibleEquipment()
  DimIncompatibleBags()
end

function EnchantTargets:SuspendEnchantTargets()
  ClearEnchantTargetDimming()
  self.enchantTargeting = false
  self:UnregisterEvent("BAG_UPDATE_DELAYED")
  self:UnregisterEvent("BAG_OPEN")
  self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function EnchantTargets:InstallEnchantTargetHooks()
  if InCombatLockdown() then
    return
  end

  if not hookedPaperDoll and _G.PaperDollItemsFrame then
    hookedPaperDoll = true
    _G.PaperDollItemsFrame:HookScript("OnShow", function()
      if EnchantTargets:IsEnabled() then
        EnchantTargets:RefreshEnchantTargets()
      end
    end)
  end

  if not hookedBags and _G.ContainerFrame_OnShow then
    hookedBags = true
    hooksecurefunc("ContainerFrame_OnShow", function()
      if EnchantTargets:IsEnabled() then
        EnchantTargets:RefreshEnchantTargets()
      end
    end)
  end

  if hookedPaperDoll and hookedBags then
    self:UnregisterEvent("ADDON_LOADED")
  end
end

function EnchantTargets:OnCombatEnded()
  self:InstallEnchantTargetHooks()
  self:RefreshEnchantTargets()
end

function EnchantTargets:OnEnable()
  self:RegisterEvent("CURSOR_CHANGED", "RefreshEnchantTargets")
  self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED", "RefreshEnchantTargets")
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "SuspendEnchantTargets")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
  self:RegisterEvent("ADDON_LOADED", "InstallEnchantTargetHooks")
  self:InstallEnchantTargetHooks()
  self:RefreshEnchantTargets()
end

function EnchantTargets:OnDisable()
  self:UnregisterAllEvents()
  self:SuspendEnchantTargets()
end

local P = select(1, ns.Pleebug:DropIn(EnchantTargets, { name = "Modules.EnchantTargets" }))
ClearEnchantTargetDimming = P:Def("EnchantTargets.ClearEnchantTargetDimming", ClearEnchantTargetDimming)
DimIncompatibleItem = P:Def("EnchantTargets.DimIncompatibleItem", DimIncompatibleItem)
DimIncompatibleEquipment = P:Def("EnchantTargets.DimIncompatibleEquipment", DimIncompatibleEquipment)
DimIncompatibleBagFrame = P:Def("EnchantTargets.DimIncompatibleBagFrame", DimIncompatibleBagFrame)
DimIncompatibleBags = P:Def("EnchantTargets.DimIncompatibleBags", DimIncompatibleBags)
EnchantTargets.RefreshEnchantTargets = P:Def("EnchantTargets:RefreshEnchantTargets", EnchantTargets.RefreshEnchantTargets)
EnchantTargets.SuspendEnchantTargets = P:Def("EnchantTargets:SuspendEnchantTargets", EnchantTargets.SuspendEnchantTargets)
EnchantTargets.InstallEnchantTargetHooks = P:Def("EnchantTargets:InstallEnchantTargetHooks", EnchantTargets.InstallEnchantTargetHooks)
EnchantTargets.OnCombatEnded = P:Def("EnchantTargets:OnCombatEnded", EnchantTargets.OnCombatEnded)
EnchantTargets.OnEnable = P:Def("EnchantTargets:OnEnable", EnchantTargets.OnEnable)
EnchantTargets.OnDisable = P:Def("EnchantTargets:OnDisable", EnchantTargets.OnDisable)
