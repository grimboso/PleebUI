local ADDON_NAME, ns = ...

local Core = ns.ActionBarsCore
local KeyBound = Core.LibKeyBound

local InCombatLockdown = InCombatLockdown
local ClearOverrideBindings = ClearOverrideBindings
local SetOverrideBindingClick = SetOverrideBindingClick
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local SetBinding = SetBinding
local GetPetActionInfo = GetPetActionInfo
local GetPetActionCooldown = GetPetActionCooldown
local GetPetActionsUsable = GetPetActionsUsable
local PickupPetAction = PickupPetAction
local IsPetAttackAction = IsPetAttackAction
local CooldownFrame_Set = CooldownFrame_Set
local ipairs = ipairs
local select = select
local type = type
local tonumber = tonumber
local math_max = math.max
local math_min = math.min
local format = string.format

local MAX_PET_BUTTONS = 10

local PetBar = {
  transientGrid = 0,
  buttonCount = 10,
  showEmptyButtons = true,
  lockActionBars = true,
}
local P = select(1, ns.Pleebug:DropIn(PetBar))

local function GetDefaultPoint()
  return { "BOTTOM", UIParent, "BOTTOM", 0, 20 }
end

local function GetPetBinding(index)
  return format("BONUSACTIONBUTTON%d", index)
end

local function GetShortKey(binding)
  local key = GetBindingKey(binding)
  if key and KeyBound then
    return KeyBound:ToShortKey(key)
  end
  return key
end

local function UpdateHotkey(button)
  local hotkey = button.HotKey
  if not hotkey then return end

  local key = GetShortKey(GetPetBinding(button:GetID()))
    or GetShortKey("CLICK " .. button:GetName() .. ":LeftButton")

  if key and key ~= "" then
    hotkey:SetText(key)
    hotkey:Show()
  else
    hotkey:SetText("")
    hotkey:Hide()
  end
end


local function ApplyPetActionContent(button, name, texture, isToken)
  if isToken then
    button.icon:SetTexture(texture and _G[texture] or nil)
    button.tooltipName = name and _G[name] or nil
  else
    button.icon:SetTexture(texture)
    button.tooltipName = name
  end

  button.isToken = isToken
  button.__puiHasPetAction = texture and true or false
end

local function ApplyPetActionState(button, isActive, autoCastAllowed, autoCastEnabled)
  local id = button:GetID()
  local isAttack = isActive and IsPetAttackAction(id) or false

  if button.__puiPetActive ~= isActive or button.__puiPetAttack ~= isAttack then
    button.__puiPetActive = isActive
    button.__puiPetAttack = isAttack

    if isActive then
      if isAttack then
        if button.StartFlash then button:StartFlash() end
        if button:GetCheckedTexture() then
          button:GetCheckedTexture():SetAlpha(0.5)
        end
      else
        if button.StopFlash then button:StopFlash() end
        if button:GetCheckedTexture() then
          button:GetCheckedTexture():SetAlpha(1)
        end
      end
      button:SetChecked(true)
    else
      if button.StopFlash then button:StopFlash() end
      button:SetChecked(false)
    end
  end

  if button.__puiAutoCastAllowed ~= autoCastAllowed
    or button.__puiAutoCastEnabled ~= autoCastEnabled
  then
    button.__puiAutoCastAllowed = autoCastAllowed
    button.__puiAutoCastEnabled = autoCastEnabled

    local autoCastOverlay = button.AutoCastOverlay
    autoCastOverlay:SetShown(autoCastAllowed and true or false)
    autoCastOverlay:ShowAutoCastEnabled(autoCastEnabled and true or false)
  end
end

local function ApplyPetActionUsability(button, petActionsUsable)
  if not button.__puiHasPetAction then
    local alpha = (PetBar.showEmptyButtons or PetBar.transientGrid > 0) and 1 or 0
    if button.__puiEmptyPetAlpha ~= alpha then
      button.__puiEmptyPetAlpha = alpha
      button.icon:Hide()
      button:SetAlpha(alpha)
    end
    return
  end

  button.__puiEmptyPetAlpha = nil
  button.icon:Show()
  button:SetAlpha(1)

  local desaturated = not petActionsUsable
  if button.__puiPetDesaturated ~= desaturated then
    button.__puiPetDesaturated = desaturated
    button.icon:SetDesaturated(desaturated)
  end
end

local function UpdatePetAction(button, petActionsUsable)
  local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(button:GetID())
  ApplyPetActionContent(button, name, texture, isToken)
  ApplyPetActionState(button, isActive, autoCastAllowed, autoCastEnabled)
  ApplyPetActionUsability(button, petActionsUsable)
end

local function UpdatePetActionState(button, petActionsUsable)
  local _, texture, _, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(button:GetID())
  button.__puiHasPetAction = texture and true or false
  ApplyPetActionState(button, isActive, autoCastAllowed, autoCastEnabled)
  ApplyPetActionUsability(button, petActionsUsable)
end

local function UpdatePetButtonFromTemplate(button)
  UpdatePetAction(button, GetPetActionsUsable())
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
  if KeyBound then
    KeyBound:Set(button)
  end
end

local function OnDragStart(button)
  if InCombatLockdown() then return end
  if PetBar.lockActionBars and not IsModifiedClick("PICKUPACTION") then
    return
  end
  button:SetChecked(false)
  PickupPetAction(button:GetID())
  UpdatePetAction(button, GetPetActionsUsable())
end

local function OnReceiveDrag(button)
  if InCombatLockdown() then return end
  local cursorType = GetCursorInfo()
  if cursorType == "petaction" then
    button:SetChecked(false)
    PickupPetAction(button:GetID())
    UpdatePetAction(button, GetPetActionsUsable())
  end
end

local function GetHotkey(button)
  return GetShortKey(GetPetBinding(button:GetID()))
    or GetShortKey("CLICK " .. button:GetName() .. ":LeftButton")
end

local function GetBindings(button)
  local output = ""
  local bindings = {
    GetPetBinding(button:GetID()),
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
  SetBinding(key, GetPetBinding(button:GetID()))
end

local function ClearBindings(button)
  local bindings = {
    GetPetBinding(button:GetID()),
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
  local name, _, isToken = GetPetActionInfo(button:GetID())
  if isToken and name then
    name = _G[name]
  end
  return format("Pet Button %d (%s)", button:GetID(), name or "empty")
end

local function CreateButton(bar, index)
  local name = "PUI_PetActionButton" .. index
  local button = CreateFrame("CheckButton", name, bar.frame, "PetActionButtonTemplate")
  button:SetID(index)
  button.id = index
  button.parent = bar.frame
  button.showgrid = 0
  button.__puiActionBarTooltip = true

  button:UnregisterAllEvents()
  button:SetScript("OnEvent", nil)
  button:RegisterForDrag("LeftButton", "RightButton")

  button.__puiOriginalOnEnter = button:GetScript("OnEnter")
  button:SetScript("OnEnter", OnEnter)
  button:SetScript("OnDragStart", OnDragStart)
  button:SetScript("OnReceiveDrag", OnReceiveDrag)

  Core:NormalizeButtonRegions(button)

  button.Update = UpdatePetButtonFromTemplate
  button.UpdateHotkeys = UpdateHotkey
  button.SetHotkeys = UpdateHotkey
  button.GetHotkey = GetHotkey
  button.GetBindings = GetBindings
  button.SetKey = SetKey
  button.ClearBindings = ClearBindings
  button.GetActionName = GetActionName

  bar.buttons[index] = button
  return button
end

function PetBar:EnsureEventFrame()
  if not self.eventFrame then
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
      PetBar:OnEvent(event)
    end)
  end

  if not self.visibleEventFrame then
    self.visibleEventFrame = CreateFrame("Frame")
    self.visibleEventFrame:SetScript("OnEvent", function(_, event)
      if event == "PET_BAR_UPDATE_COOLDOWN" then
        PetBar:QueueRuntimeUpdate("cooldown")
      elseif event == "UPDATE_VEHICLE_ACTIONBAR" then
        PetBar:QueueRuntimeUpdate("full")
      elseif event == "PET_BAR_UPDATE_USABLE" then
        PetBar:QueueRuntimeUpdate("usability")
      else
        PetBar:QueueRuntimeUpdate("state")
      end
    end)
  end

  if not self.runtimeUpdateFrame then
    self.runtimeUpdateFrame = CreateFrame("Frame")
    self.runtimeUpdateFrame:Hide()
    self.runtimeUpdateFrame:SetScript("OnUpdate", function(frame)
      frame:Hide()
      PetBar:FlushRuntimeUpdate()
    end)
  end

  if self.eventsRegistered then
    return
  end

  local frame = self.eventFrame
  frame:RegisterEvent("PET_BAR_UPDATE")
  frame:RegisterEvent("PET_UI_UPDATE")
  frame:RegisterUnitEvent("UNIT_PET", "player")
  frame:RegisterUnitEvent("UNIT_FLAGS", "pet")
  frame:RegisterEvent("PLAYER_CONTROL_LOST")
  frame:RegisterEvent("PLAYER_CONTROL_GAINED")
  frame:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED")
  frame:RegisterEvent("PET_BAR_SHOWGRID")
  frame:RegisterEvent("PET_BAR_HIDEGRID")
  self.eventsRegistered = true
end

function PetBar:LoadRuntimeConfig()
  local db = Core:GetDB()
  local petDB = db.bars.pet

  self.buttonCount = math_max(1, math_min(MAX_PET_BUTTONS, tonumber(petDB.buttonCount) or 10))
  self.showCooldowns = petDB.showCooldowns ~= false
  self.showEmptyButtons = Core.alwaysShowGrid ~= false
  self.lockActionBars = Core.lockActionBars ~= false
end

function PetBar:ClearCooldowns()
  if not self.bar then return end

  for index = 1, self.buttonCount do
    local cooldown = self.bar.buttons[index].cooldown
    cooldown:Clear()
    cooldown:Hide()
  end
end

function PetBar:SetVisibleEventsEnabled(enabled, reconcile)
  local frame = self.visibleEventFrame
  if not frame then return end

  enabled = enabled == true
  local visibilityChanged = self.runtimeVisible ~= enabled
  self.runtimeVisible = enabled

  if enabled then
    if not self.visibleEventsRegistered then
      frame:RegisterEvent("PET_BAR_UPDATE_USABLE")
      frame:RegisterEvent("PLAYER_TARGET_CHANGED")
      frame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
      frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
      frame:RegisterUnitEvent("UNIT_AURA", "pet")
      self.visibleEventsRegistered = true
    end

    if self.showCooldowns then
      if not self.cooldownEventRegistered then
        frame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
        self.cooldownEventRegistered = true
      end
    else
      if self.cooldownEventRegistered then
        frame:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN")
        self.cooldownEventRegistered = nil
      end
      self:ClearCooldowns()
    end

    if reconcile ~= false and (visibilityChanged or self.runtimeReconcilePending) then
      self:QueueRuntimeUpdate("full")
    end
    return
  end

  if self.visibleEventsRegistered then
    frame:UnregisterEvent("PET_BAR_UPDATE_USABLE")
    frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    frame:UnregisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    frame:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    frame:UnregisterEvent("UNIT_AURA")
    self.visibleEventsRegistered = nil
  end
  if self.cooldownEventRegistered then
    frame:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN")
    self.cooldownEventRegistered = nil
  end

  self.runtimeReconcilePending = true
  self.pendingFullUpdate = nil
  self.pendingStateUpdate = nil
  self.pendingUsabilityUpdate = nil
  self.pendingCooldownUpdate = nil
  if self.runtimeUpdateFrame then
    self.runtimeUpdateFrame:Hide()
  end
end

function PetBar:QueueRuntimeUpdate(kind)
  local bar = self.bar
  if not bar or not bar.frame:IsVisible() then
    self.runtimeReconcilePending = true
    return
  end

  if kind == "full" then
    self.pendingFullUpdate = true
  elseif kind == "state" then
    self.pendingStateUpdate = true
  elseif kind == "usability" then
    self.pendingUsabilityUpdate = true
  elseif kind == "cooldown" then
    self.pendingCooldownUpdate = true
  end

  if self.runtimeUpdateFrame and not self.runtimeUpdateFrame:IsShown() then
    self.runtimeUpdateFrame:Show()
  end
end

function PetBar:FlushRuntimeUpdate()
  local bar = self.bar
  if not bar or not bar.frame:IsVisible() then
    self.runtimeReconcilePending = true
    self.pendingFullUpdate = nil
    self.pendingStateUpdate = nil
    self.pendingUsabilityUpdate = nil
    self.pendingCooldownUpdate = nil
    return
  end

  local fullUpdate = self.pendingFullUpdate or self.runtimeReconcilePending
  local stateUpdate = self.pendingStateUpdate
  local usabilityUpdate = self.pendingUsabilityUpdate
  local cooldownUpdate = self.pendingCooldownUpdate

  self.runtimeReconcilePending = nil
  self.pendingFullUpdate = nil
  self.pendingStateUpdate = nil
  self.pendingUsabilityUpdate = nil
  self.pendingCooldownUpdate = nil

  if fullUpdate then
    self:UpdateActions()
    if self.showCooldowns then
      self:UpdateCooldowns()
    end
    return
  end

  if stateUpdate then
    self:UpdateStates()
  elseif usabilityUpdate then
    self:UpdateUsability()
  end
  if cooldownUpdate and self.showCooldowns then
    self:UpdateCooldowns()
  end
end

function PetBar:EnsureCreated()
  self:EnsureEventFrame()

  if self.bar then
    return self.bar
  end

  local bar = Core:CreateBar(
    "pet",
    "PUI_PetBar",
    "ACTIONBAR_PET",
    "Pet Action Bar",
    GetDefaultPoint,
    "pet"
  )
  bar.defaultSize = 17
  bar.enabled = true

  bar.frame:HookScript("OnShow", function()
    PetBar:SetVisibleEventsEnabled(true, not PetBar.refreshingFull)
  end)
  bar.frame:HookScript("OnHide", function()
    PetBar:SetVisibleEventsEnabled(false)
  end)

  self.bar = bar
  return bar
end

function PetBar:EnsureButtons()
  local bar = self.bar
  if not bar then return end

  for index = #bar.buttons + 1, self.buttonCount do
    CreateButton(bar, index)
  end

  Core:AttachAlphaHandlers(bar)
end

function PetBar:LayoutButtonDecorations(skin)
  local bar = self.bar
  if not bar then return end

  local size = skin.iconSize
  for _, button in ipairs(bar.buttons) do
    if button.Flash then
      button.Flash:ClearAllPoints()
      button.Flash:SetAllPoints(button)
      button.Flash:SetTexCoord(0, 1, 0, 1)
    end

    local autoCast = button.AutoCastOverlay
    autoCast:ClearAllPoints()
    autoCast:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.__puiAutoCastBaseWidth = button.__puiAutoCastBaseWidth or autoCast:GetWidth()
    local baseWidth = button.__puiAutoCastBaseWidth
    if baseWidth and baseWidth > 0 then
      autoCast:SetScale(size / baseWidth)
    end
  end
end

function PetBar:UpdateActions()
  if not self.bar then return end
  local petActionsUsable = GetPetActionsUsable()
  for index = 1, self.buttonCount do
    UpdatePetAction(self.bar.buttons[index], petActionsUsable)
  end
end

function PetBar:UpdateStates()
  if not self.bar then return end
  local petActionsUsable = GetPetActionsUsable()
  for index = 1, self.buttonCount do
    UpdatePetActionState(self.bar.buttons[index], petActionsUsable)
  end
end

function PetBar:UpdateUsability()
  if not self.bar then return end
  local petActionsUsable = GetPetActionsUsable()
  for index = 1, self.buttonCount do
    ApplyPetActionUsability(self.bar.buttons[index], petActionsUsable)
  end
end

function PetBar:UpdateEmptyButtons()
  if not self.bar then return end
  local petActionsUsable = GetPetActionsUsable()
  for index = 1, self.buttonCount do
    ApplyPetActionUsability(self.bar.buttons[index], petActionsUsable)
  end
end

function PetBar:UpdateCooldowns()
  if not self.bar or not self.showCooldowns then return end

  for index = 1, self.buttonCount do
    local button = self.bar.buttons[index]
    local start, duration, enable = GetPetActionCooldown(index)
    CooldownFrame_Set(button.cooldown, start, duration, enable)
  end
end

function PetBar:UpdateHotkeys()
  if not self.bar then return end
  for index = 1, self.buttonCount do
    UpdateHotkey(self.bar.buttons[index])
  end
end

function PetBar:RefreshFonts()
  if not self.bar then return end
  local skin = Core:GetSpecialSkin("pet", 17)
  for _, button in ipairs(self.bar.buttons) do
    Core:ApplyAuxiliaryFonts(button, skin)
    Core:ApplyButtonCooldownAppearance(button, skin)
  end
end

function PetBar:RefreshSkin()
  if not self.bar then return end
  local skin = Core:GetSpecialSkin("pet", 17)
  for _, button in ipairs(self.bar.buttons) do
    Core:ApplyButtonAppearance(button, skin)
  end
  Core:ApplyBackdrop(self.bar, skin)
end

function PetBar:RefreshLayout()
  if not self.bar then return end
  local skin = Core:GetSpecialSkin("pet", 17)
  Core:LayoutButtons(self.bar, skin, self.buttonCount, skin.iconsPerRow)
  self:LayoutButtonDecorations(skin)
end

function PetBar:RefreshVisibility()
  if not self.bar then return end

  Core:SetBarVisibilityDriver(self.bar, "[petbattle]hide;[pet,novehicleui,nooverridebar,nopossessbar,noshapeshift]show;hide")
  self:SetVisibleEventsEnabled(self.bar.frame:IsVisible(), false)
end

function PetBar:RefreshAlpha()
  if self.bar then
    Core:RefreshBarAlpha(self.bar, false)
  end
end

function PetBar:RefreshFull()
  self:LoadRuntimeConfig()

  local bar = self:EnsureCreated()
  self:EnsureButtons()

  local skin = Core:GetSpecialSkin("pet", 17)
  local petActionsUsable = GetPetActionsUsable()

  for index = 1, self.buttonCount do
    local button = bar.buttons[index]
    Core:ApplyButtonAppearance(button, skin)
    UpdatePetAction(button, petActionsUsable)
    UpdateHotkey(button)
  end

  if self.showCooldowns then
    self:UpdateCooldowns()
  else
    self:ClearCooldowns()
  end
  self.runtimeReconcilePending = nil
  self.pendingFullUpdate = nil
  self.pendingStateUpdate = nil
  self.pendingUsabilityUpdate = nil
  self.pendingCooldownUpdate = nil

  Core:LayoutButtons(bar, skin, self.buttonCount, skin.iconsPerRow)
  self:LayoutButtonDecorations(skin)
  Core:ApplyBackdrop(bar, skin)
  self.refreshingFull = true
  self:RefreshVisibility()
  self.refreshingFull = nil
  Core:RegisterMover(bar)
  Core:RefreshBarAlpha(bar, false)
  self:UpdateBindings()
end

function PetBar:Refresh(flags)
  flags = type(flags) == "table" and flags or { full = true }
  if InCombatLockdown() then
    Core:QueueRefresh(flags)
    return
  end

  if flags.full then
    self:RefreshFull()
    return
  end

  if flags.cvars then
    self:LoadRuntimeConfig()
    self:UpdateEmptyButtons()
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

function PetBar:ReconcileWorldState()
  self:EnsureEventFrame()
  if not self.bar then return end

  self:SetVisibleEventsEnabled(self.bar.frame:IsVisible(), false)
  self:QueueRuntimeUpdate("full")
end

function PetBar:UpdateBindings()
  local bar = self.bar
  if not bar or InCombatLockdown() then return end

  ClearOverrideBindings(bar.frame)
  for index = 1, self.buttonCount do
    local button = bar.buttons[index]
    local binding = GetPetBinding(index)
    for keyIndex = 1, select("#", GetBindingKey(binding)) do
      local key = select(keyIndex, GetBindingKey(binding))
      if key and key ~= "" then
        SetOverrideBindingClick(bar.frame, false, key, button:GetName(), "LeftButton")
      end
    end
  end
  self:UpdateHotkeys()
end

function PetBar:OnEvent(event)
  if event == "PET_BAR_SHOWGRID" then
    self.transientGrid = self.transientGrid + 1
    self:QueueRuntimeUpdate("usability")
  elseif event == "PET_BAR_HIDEGRID" then
    self.transientGrid = math_max(0, self.transientGrid - 1)
    self:QueueRuntimeUpdate("usability")
  elseif event == "PET_BAR_UPDATE"
    or event == "PET_UI_UPDATE"
    or event == "UNIT_PET"
  then
    self:QueueRuntimeUpdate("full")
  else
    self:QueueRuntimeUpdate("state")
  end
end

function PetBar:Disable()
  self.transientGrid = 0
  self:SetVisibleEventsEnabled(false)
  self.runtimeVisible = nil
  self.runtimeReconcilePending = nil
  self.pendingFullUpdate = nil
  self.pendingStateUpdate = nil
  self.pendingUsabilityUpdate = nil
  self.pendingCooldownUpdate = nil
  if self.runtimeUpdateFrame then
    self.runtimeUpdateFrame:Hide()
  end

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    self.eventsRegistered = nil
  end
  if not self.bar then return end
  ClearOverrideBindings(self.bar.frame)
  UnregisterStateDriver(self.bar.frame, "visibility")
  self.bar.visibilityDriver = nil
  self.bar.frame:Hide()
end

PetBar.EnsureEventFrame = P:Def("PetBar:EnsureEventFrame", PetBar.EnsureEventFrame)
PetBar.LoadRuntimeConfig = P:Def("PetBar:LoadRuntimeConfig", PetBar.LoadRuntimeConfig)
PetBar.ClearCooldowns = P:Def("PetBar:ClearCooldowns", PetBar.ClearCooldowns)
PetBar.SetVisibleEventsEnabled = P:Def("PetBar:SetVisibleEventsEnabled", PetBar.SetVisibleEventsEnabled)
PetBar.QueueRuntimeUpdate = P:Def("PetBar:QueueRuntimeUpdate", PetBar.QueueRuntimeUpdate)
PetBar.FlushRuntimeUpdate = P:Def("PetBar:FlushRuntimeUpdate", PetBar.FlushRuntimeUpdate)
PetBar.EnsureCreated = P:Def("PetBar:EnsureCreated", PetBar.EnsureCreated)
PetBar.EnsureButtons = P:Def("PetBar:EnsureButtons", PetBar.EnsureButtons)
PetBar.LayoutButtonDecorations = P:Def("PetBar:LayoutButtonDecorations", PetBar.LayoutButtonDecorations)
PetBar.UpdateActions = P:Def("PetBar:UpdateActions", PetBar.UpdateActions)
PetBar.UpdateStates = P:Def("PetBar:UpdateStates", PetBar.UpdateStates)
PetBar.UpdateUsability = P:Def("PetBar:UpdateUsability", PetBar.UpdateUsability)
PetBar.UpdateEmptyButtons = P:Def("PetBar:UpdateEmptyButtons", PetBar.UpdateEmptyButtons)
PetBar.UpdateCooldowns = P:Def("PetBar:UpdateCooldowns", PetBar.UpdateCooldowns)
PetBar.UpdateHotkeys = P:Def("PetBar:UpdateHotkeys", PetBar.UpdateHotkeys)
PetBar.RefreshFonts = P:Def("PetBar:RefreshFonts", PetBar.RefreshFonts)
PetBar.RefreshSkin = P:Def("PetBar:RefreshSkin", PetBar.RefreshSkin)
PetBar.RefreshLayout = P:Def("PetBar:RefreshLayout", PetBar.RefreshLayout)
PetBar.RefreshVisibility = P:Def("PetBar:RefreshVisibility", PetBar.RefreshVisibility)
PetBar.RefreshAlpha = P:Def("PetBar:RefreshAlpha", PetBar.RefreshAlpha)
PetBar.RefreshFull = P:Def("PetBar:RefreshFull", PetBar.RefreshFull)
PetBar.Refresh = P:Def("PetBar:Refresh", PetBar.Refresh)
PetBar.ReconcileWorldState = P:Def("PetBar:ReconcileWorldState", PetBar.ReconcileWorldState)
PetBar.UpdateBindings = P:Def("PetBar:UpdateBindings", PetBar.UpdateBindings)
PetBar.OnEvent = P:Def("PetBar:OnEvent", PetBar.OnEvent)
PetBar.Disable = P:Def("PetBar:Disable", PetBar.Disable)
GetDefaultPoint = P:Def("GetDefaultPoint", GetDefaultPoint)
GetPetBinding = P:Def("GetPetBinding", GetPetBinding)
GetShortKey = P:Def("GetShortKey", GetShortKey)
UpdateHotkey = P:Def("UpdateHotkey", UpdateHotkey)
ApplyPetActionContent = P:Def("ApplyPetActionContent", ApplyPetActionContent)
ApplyPetActionState = P:Def("ApplyPetActionState", ApplyPetActionState)
ApplyPetActionUsability = P:Def("ApplyPetActionUsability", ApplyPetActionUsability)
UpdatePetAction = P:Def("UpdatePetAction", UpdatePetAction)
UpdatePetActionState = P:Def("UpdatePetActionState", UpdatePetActionState)
UpdatePetButtonFromTemplate = P:Def("UpdatePetButtonFromTemplate", UpdatePetButtonFromTemplate)
OnEnter = P:Def("OnEnter", OnEnter)
OnDragStart = P:Def("OnDragStart", OnDragStart)
OnReceiveDrag = P:Def("OnReceiveDrag", OnReceiveDrag)
GetHotkey = P:Def("GetHotkey", GetHotkey)
GetBindings = P:Def("GetBindings", GetBindings)
SetKey = P:Def("SetKey", SetKey)
ClearBindings = P:Def("ClearBindings", ClearBindings)
GetActionName = P:Def("GetActionName", GetActionName)
CreateButton = P:Def("CreateButton", CreateButton)

Core:RegisterSubsystem("pet", PetBar)
