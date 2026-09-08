local ADDON_NAME, ns = ...

local Core = ns.ActionBarsCore
local KeyBound = Core.LibKeyBound

local InCombatLockdown = InCombatLockdown
local ClearOverrideBindings = ClearOverrideBindings
local SetOverrideBindingClick = SetOverrideBindingClick
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local SetBinding = SetBinding
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local CooldownFrame_Set = CooldownFrame_Set
local ipairs = ipairs
local select = select
local type = type
local format = string.format
local math_max = math.max

local StanceBar = {}
local P = select(1, ns.Pleebug:DropIn(StanceBar))

local STANCE_RUNTIME_EVENTS = {
  "UPDATE_SHAPESHIFT_COOLDOWN",
  "UPDATE_SHAPESHIFT_FORM",
  "UPDATE_SHAPESHIFT_USABLE",
  "ACTIONBAR_PAGE_CHANGED",
}

local function GetDefaultPoint()
  local mainBar = _G.PUI_MainBar
  if mainBar then
    return { "RIGHT", mainBar, "LEFT", -10, 0 }
  end
  return { "BOTTOM", UIParent, "BOTTOM", -300, 80 }
end

local function GetStanceBinding(index)
  return format("SHAPESHIFTBUTTON%d", index)
end

local function GetShortKey(binding)
  local key = GetBindingKey(binding)
  if key then
    return KeyBound:ToShortKey(key)
  end
  return key
end

local function UpdateHotkey(button)
  local hotkey = button.HotKey
  if not hotkey then return end

  local key = GetShortKey(GetStanceBinding(button:GetID()))
    or GetShortKey("CLICK " .. button:GetName() .. ":LeftButton")

  if key and key ~= "" then
    hotkey:SetText(key)
    hotkey:Show()
  else
    hotkey:SetText("")
    hotkey:Hide()
  end
end

local function UpdateStanceState(button)
  if not button:IsShown() then return end

  local texture, isActive, isCastable = GetShapeshiftFormInfo(button:GetID())
  button.icon:SetTexture(texture)

  if texture then
    button.icon:Show()
    button.cooldown:Show()
  else
    button.icon:Hide()
    button.cooldown:Hide()
  end

  button:SetChecked(isActive and true or false)

  if isCastable then
    button.icon:SetVertexColor(1, 1, 1)
  else
    button.icon:SetVertexColor(0.4, 0.4, 0.4)
  end
end

local function UpdateStanceCooldown(button)
  if not button:IsShown() then return end

  local start, duration, enable = GetShapeshiftFormCooldown(button:GetID())
  CooldownFrame_Set(button.cooldown, start, duration, enable)
end

local function OnEnter(button, ...)
  if button.__puiOriginalOnEnter then
    button:__puiOriginalOnEnter(...)
  end
  if not Core:ShouldShowActionTooltip()
    and not GameTooltip:IsForbidden()
    and GameTooltip:GetOwner() == button
  then
    GameTooltip:Hide()
  end
  KeyBound:Set(button)
end

local function GetHotkey(button)
  return GetShortKey(GetStanceBinding(button:GetID()))
    or GetShortKey("CLICK " .. button:GetName() .. ":LeftButton")
end

local function GetBindings(button)
  local output = ""
  local bindings = {
    GetStanceBinding(button:GetID()),
    "CLICK " .. button:GetName() .. ":LeftButton",
  }

  for _, binding in ipairs(bindings) do
    for index = 1, select("#", GetBindingKey(binding)) do
      local key = select(index, GetBindingKey(binding))
      if key and key ~= "" then
        if output ~= "" then output = output .. ", " end
        output = output .. GetBindingText(key, "KEY_")
      end
    end
  end

  return output
end

local function SetKey(button, key)
  SetBinding(key, GetStanceBinding(button:GetID()))
end

local function ClearBindings(button)
  local bindings = {
    GetStanceBinding(button:GetID()),
    "CLICK " .. button:GetName() .. ":LeftButton",
  }

  for _, binding in ipairs(bindings) do
    local key = GetBindingKey(binding)
    while key do
      SetBinding(key, nil)
      key = GetBindingKey(binding)
    end
  end
end

local function GetActionName(button)
  local _, _, _, spellID = GetShapeshiftFormInfo(button:GetID())
  local spellName = spellID and C_Spell.GetSpellName(spellID)
  return format("Stance Button %d (%s)", button:GetID(), spellName or "empty")
end

local function CreateButton(bar, index)
  local name = "PUI_StanceActionButton" .. index
  local button = CreateFrame("CheckButton", name, bar.frame, "StanceButtonTemplate")
  button:SetID(index)
  button.parent = bar.frame
  button.__puiActionBarTooltip = true

  button:UnregisterAllEvents()
  button:SetScript("OnEvent", nil)

  button.__puiOriginalOnEnter = button:GetScript("OnEnter")
  button:SetScript("OnEnter", OnEnter)

  Core:NormalizeButtonRegions(button)

  button.Update = UpdateStanceState
  button.UpdateCooldown = UpdateStanceCooldown
  button.UpdateHotkeys = UpdateHotkey
  button.GetHotkey = GetHotkey
  button.GetBindings = GetBindings
  button.SetKey = SetKey
  button.ClearBindings = ClearBindings
  button.GetActionName = GetActionName

  bar.buttons[index] = button
  return button
end

function StanceBar:EnsureEventFrame()
  if not self.eventFrame then
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
      StanceBar:OnEvent(event)
    end)
  end

  if not self.runtimeUpdateFrame then
    self.runtimeUpdateFrame = CreateFrame("Frame")
    self.runtimeUpdateFrame:Hide()
    self.runtimeUpdateFrame:SetScript("OnUpdate", function(frame)
      frame:Hide()
      StanceBar:FlushRuntimeUpdate()
    end)
  end

  if self.formsEventRegistered then
    return
  end

  self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
  self.formsEventRegistered = true
end

function StanceBar:SetRuntimeEventsEnabled(enabled)
  self:EnsureEventFrame()
  enabled = enabled == true

  if not enabled then
    self.pendingStateUpdate = nil
    self.pendingCooldownUpdate = nil
    self.runtimeUpdateFrame:Hide()
  end

  if self.runtimeEventsRegistered == enabled then
    return
  end

  for _, event in ipairs(STANCE_RUNTIME_EVENTS) do
    if enabled then
      self.eventFrame:RegisterEvent(event)
    else
      self.eventFrame:UnregisterEvent(event)
    end
  end
  self.runtimeEventsRegistered = enabled
end

function StanceBar:QueueRuntimeUpdate(kind)
  if kind == "cooldown" then
    self.pendingCooldownUpdate = true
  else
    self.pendingStateUpdate = true
  end

  self.runtimeUpdateFrame:Show()
end

function StanceBar:FlushRuntimeUpdate()
  local stateUpdate = self.pendingStateUpdate
  local cooldownUpdate = self.pendingCooldownUpdate

  self.pendingStateUpdate = nil
  self.pendingCooldownUpdate = nil

  local bar = self.bar
  if not self.runtimeEventsRegistered or not bar or not bar.frame:IsVisible() then
    return
  end

  if stateUpdate then
    self:UpdateStates()
  end
  if cooldownUpdate then
    self:UpdateCooldowns()
  end
end

function StanceBar:EnsureCreated()
  self:EnsureEventFrame()

  if self.bar then
    return self.bar
  end

  local bar = Core:CreateBar(
    "stance",
    "PUI_StanceBar",
    "ACTIONBAR_STANCE",
    "Stance Bar",
    GetDefaultPoint,
    "stance"
  )
  bar.defaultSize = 23
  bar.enabled = function()
    return GetNumShapeshiftForms() > 0
  end

  for index = 1, 10 do
    CreateButton(bar, index)
  end

  if not bar.stanceRuntimeHookAttached then
    bar.stanceRuntimeHookAttached = true
    bar.frame:HookScript("OnShow", function()
      StanceBar:SetRuntimeEventsEnabled(GetNumShapeshiftForms() > 0)
      StanceBar:UpdateStates()
      StanceBar:UpdateCooldowns()
    end)
    bar.frame:HookScript("OnHide", function()
      StanceBar:SetRuntimeEventsEnabled(false)
    end)
  end

  Core:AttachAlphaHandlers(bar)
  self.bar = bar
  return bar
end

function StanceBar:UpdateStates()
  if not self.bar or not self.bar.frame:IsVisible() then return end
  for _, button in ipairs(self.bar.buttons) do
    if button:IsShown() then
      UpdateStanceState(button)
    end
  end
end

function StanceBar:UpdateCooldowns()
  if not self.bar or not self.bar.frame:IsVisible() then return end
  for _, button in ipairs(self.bar.buttons) do
    if button:IsShown() then
      UpdateStanceCooldown(button)
    end
  end
end

function StanceBar:UpdateHotkeys()
  if not self.bar then return end
  for _, button in ipairs(self.bar.buttons) do
    if button:IsShown() then
      UpdateHotkey(button)
    end
  end
end

function StanceBar:RefreshFonts()
  if not self.bar then return end
  local skin = Core:GetSpecialSkin("stance", 23)
  for _, button in ipairs(self.bar.buttons) do
    Core:ApplyAuxiliaryFonts(button, skin)
    Core:ApplyButtonCooldownAppearance(button, skin)
  end
end

function StanceBar:RefreshSkin()
  if not self.bar then return end
  local skin = Core:GetSpecialSkin("stance", 23)
  for _, button in ipairs(self.bar.buttons) do
    Core:ApplyButtonAppearance(button, skin)
  end
  Core:ApplyBackdrop(self.bar, skin)
end

function StanceBar:RefreshLayout()
  if not self.bar then return end

  local count = GetNumShapeshiftForms()
  local skin = Core:GetSpecialSkin("stance", 23)
  Core:LayoutButtons(self.bar, skin, math_max(1, count), math_max(1, count))

  for index, button in ipairs(self.bar.buttons) do
    button:SetShown(index <= count)
  end

  self.bar.formCount = count
  self:SetRuntimeEventsEnabled(count > 0 and self.bar.frame:IsVisible())
end

function StanceBar:RefreshVisibility()
  if not self.bar then return end

  local count = GetNumShapeshiftForms()
  Core:SetBarVisibilityDriver(
    self.bar,
    count > 0 and "[petbattle]hide;[vehicleui][overridebar][possessbar][shapeshift]hide;show" or "hide"
  )
  self:SetRuntimeEventsEnabled(count > 0 and self.bar.frame:IsVisible())
end

function StanceBar:RefreshAlpha()
  if self.bar then
    Core:RefreshBarAlpha(self.bar, false)
  end
end

function StanceBar:RefreshForms()
  self:EnsureEventFrame()
  self.pendingStateUpdate = nil
  self.pendingCooldownUpdate = nil
  self.runtimeUpdateFrame:Hide()
  local count = GetNumShapeshiftForms()

  if InCombatLockdown() then
    if count == 0 or not self.bar or not self.bar.frame:IsVisible() then
      self:SetRuntimeEventsEnabled(false)
    end
    Core:QueueSubsystemRefresh("stance", "forms")
    self:UpdateStates()
    return
  end

  if count == 0 and not self.bar then
    self:SetRuntimeEventsEnabled(false)
    return
  end

  if count > 0 and (not self.bar or self.fullRefreshPending) then
    self.fullRefreshPending = nil
    self:RefreshFull()
    return
  end

  local bar = self:EnsureCreated()

  if bar.formCount ~= count then
    self:RefreshLayout()
    self:RefreshVisibility()
    Core:RegisterMover(bar)
    self:UpdateBindings()
  end

  self:SetRuntimeEventsEnabled(count > 0 and bar.frame:IsVisible())
  self:UpdateStates()
  self:UpdateCooldowns()
end

function StanceBar:RefreshFull()
  self:EnsureEventFrame()
  local count = GetNumShapeshiftForms()

  if count == 0 then
    self.fullRefreshPending = true
    if self.bar then
      self:RefreshLayout()
      self:RefreshVisibility()
      self:UpdateBindings()
    end
    self:SetRuntimeEventsEnabled(false)
    return
  end

  self.fullRefreshPending = nil
  local bar = self:EnsureCreated()
  local skin = Core:GetSpecialSkin("stance", 23)

  for index, button in ipairs(bar.buttons) do
    Core:ApplyButtonAppearance(button, skin)
    button:SetShown(index <= count)
    if index <= count then
      UpdateStanceState(button)
      UpdateStanceCooldown(button)
      UpdateHotkey(button)
    end
  end

  Core:LayoutButtons(bar, skin, math_max(1, count), math_max(1, count))
  for index, button in ipairs(bar.buttons) do
    button:SetShown(index <= count)
  end
  bar.formCount = count

  Core:ApplyBackdrop(bar, skin)
  self:RefreshVisibility()
  Core:RegisterMover(bar)
  Core:RefreshBarAlpha(bar, false)
  self:UpdateBindings()
  self:SetRuntimeEventsEnabled(count > 0 and bar.frame:IsVisible())
end

function StanceBar:ReconcileWorldState()
  self:RefreshForms()
end

function StanceBar:Refresh(flags)
  flags = type(flags) == "table" and flags or { full = true }
  if InCombatLockdown() then
    Core:QueueRefresh(flags)
    return
  end

  if flags.full then
    self:RefreshFull()
    return
  end

  if flags.fonts then
    self:RefreshFonts()
  end
  if flags.skin then
    self:RefreshSkin()
  end
  if flags.layout then
    self:RefreshLayout()
  end
  if flags.visibility then
    self:RefreshVisibility()
  end
  if flags.alpha then
    self:RefreshAlpha()
  end
  if flags.bindings then
    self:UpdateBindings()
  end
end

function StanceBar:RefreshDeferred(pending)
  if pending.forms then
    self:RefreshForms()
  end
end

function StanceBar:UpdateBindings()
  local bar = self.bar
  if not bar then return end
  if InCombatLockdown() then
    Core:QueueBindings()
    return
  end

  ClearOverrideBindings(bar.frame)
  local count = GetNumShapeshiftForms()
  for index = 1, count do
    local button = bar.buttons[index]
    local binding = GetStanceBinding(index)
    for keyIndex = 1, select("#", GetBindingKey(binding)) do
      local key = select(keyIndex, GetBindingKey(binding))
      if key and key ~= "" then
        SetOverrideBindingClick(bar.frame, false, key, button:GetName(), "LeftButton")
      end
    end
  end
  self:UpdateHotkeys()
end

function StanceBar:OnEvent(event)
  if event == "UPDATE_SHAPESHIFT_COOLDOWN" then
    self:QueueRuntimeUpdate("cooldown")
    return
  end

  if event == "UPDATE_SHAPESHIFT_FORMS" then
    self:RefreshForms()
    return
  end

  self:QueueRuntimeUpdate("state")
end

function StanceBar:Disable()
  self.pendingStateUpdate = nil
  self.pendingCooldownUpdate = nil
  if self.runtimeUpdateFrame then
    self.runtimeUpdateFrame:Hide()
  end
  if self.bar then
    ClearOverrideBindings(self.bar.frame)
    UnregisterStateDriver(self.bar.frame, "visibility")
    self.bar.visibilityDriver = nil
    self.bar.frame:Hide()
  end
  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    self.formsEventRegistered = nil
    self.runtimeEventsRegistered = nil
  end
end

StanceBar.EnsureEventFrame = P:Def("StanceBar:EnsureEventFrame", StanceBar.EnsureEventFrame)
StanceBar.SetRuntimeEventsEnabled = P:Def("StanceBar:SetRuntimeEventsEnabled", StanceBar.SetRuntimeEventsEnabled)
StanceBar.QueueRuntimeUpdate = P:Def("StanceBar:QueueRuntimeUpdate", StanceBar.QueueRuntimeUpdate)
StanceBar.FlushRuntimeUpdate = P:Def("StanceBar:FlushRuntimeUpdate", StanceBar.FlushRuntimeUpdate)
StanceBar.EnsureCreated = P:Def("StanceBar:EnsureCreated", StanceBar.EnsureCreated)
StanceBar.UpdateStates = P:Def("StanceBar:UpdateStates", StanceBar.UpdateStates)
StanceBar.UpdateCooldowns = P:Def("StanceBar:UpdateCooldowns", StanceBar.UpdateCooldowns)
StanceBar.UpdateHotkeys = P:Def("StanceBar:UpdateHotkeys", StanceBar.UpdateHotkeys)
StanceBar.RefreshFonts = P:Def("StanceBar:RefreshFonts", StanceBar.RefreshFonts)
StanceBar.RefreshSkin = P:Def("StanceBar:RefreshSkin", StanceBar.RefreshSkin)
StanceBar.RefreshLayout = P:Def("StanceBar:RefreshLayout", StanceBar.RefreshLayout)
StanceBar.RefreshVisibility = P:Def("StanceBar:RefreshVisibility", StanceBar.RefreshVisibility)
StanceBar.RefreshAlpha = P:Def("StanceBar:RefreshAlpha", StanceBar.RefreshAlpha)
StanceBar.RefreshForms = P:Def("StanceBar:RefreshForms", StanceBar.RefreshForms)
StanceBar.RefreshFull = P:Def("StanceBar:RefreshFull", StanceBar.RefreshFull)
StanceBar.ReconcileWorldState = P:Def("StanceBar:ReconcileWorldState", StanceBar.ReconcileWorldState)
StanceBar.Refresh = P:Def("StanceBar:Refresh", StanceBar.Refresh)
StanceBar.RefreshDeferred = P:Def("StanceBar:RefreshDeferred", StanceBar.RefreshDeferred)
StanceBar.UpdateBindings = P:Def("StanceBar:UpdateBindings", StanceBar.UpdateBindings)
StanceBar.OnEvent = P:Def("StanceBar:OnEvent", StanceBar.OnEvent)
StanceBar.Disable = P:Def("StanceBar:Disable", StanceBar.Disable)
GetDefaultPoint = P:Def("GetDefaultPoint", GetDefaultPoint)
GetStanceBinding = P:Def("GetStanceBinding", GetStanceBinding)
GetShortKey = P:Def("GetShortKey", GetShortKey)
UpdateHotkey = P:Def("UpdateHotkey", UpdateHotkey)
UpdateStanceState = P:Def("UpdateStanceState", UpdateStanceState)
UpdateStanceCooldown = P:Def("UpdateStanceCooldown", UpdateStanceCooldown)
OnEnter = P:Def("OnEnter", OnEnter)
GetHotkey = P:Def("GetHotkey", GetHotkey)
GetBindings = P:Def("GetBindings", GetBindings)
SetKey = P:Def("SetKey", SetKey)
ClearBindings = P:Def("ClearBindings", ClearBindings)
GetActionName = P:Def("GetActionName", GetActionName)
CreateButton = P:Def("CreateButton", CreateButton)

Core:RegisterSubsystem("stance", StanceBar)
