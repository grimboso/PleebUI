local ADDON_NAME, ns = ...

local Core = ns.ActionBarsCore

local Engine = {
  enabled = false,
  buttons = setmetatable({}, { __mode = "k" }),
  activeButtons = {},
  actionSlotButtons = {},
  rangeActionCounts = {},
  spellEventButtons = {},
  flyoutButtons = {},
  summonPetButtons = {},
  pendingButtonRefreshes = {},
  flushingButtonRefreshes = {},
  pendingIconButtons = {},
  flushingIconButtons = {},
  flashingButtons = setmetatable({}, { __mode = "k" }),
  flashingButtonCount = 0,
  flashTime = 0,
  runtimeFlushID = 0,
}
ns.ActionButtonEngine = Engine

local P = select(1, ns.Pleebug:DropIn(Engine))
local LibKeyBound = Core.LibKeyBound

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetActionInfo = GetActionInfo
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local SetBinding = SetBinding
local issecretvalue = issecretvalue
local C_ActionBar = C_ActionBar
local C_Spell = C_Spell
local EMPTY_COOLDOWN_DURATION = C_DurationUtil.CreateDuration()
local GetActionCooldownDuration = C_ActionBar.GetActionCooldownDuration
local GetActionCharges = C_ActionBar.GetActionCharges
local GetActionChargeDuration = C_ActionBar.GetActionChargeDuration
local GetActionLossOfControlCooldownInfo = C_ActionBar.GetActionLossOfControlCooldownInfo
local GetActionLossOfControlCooldownDuration = C_ActionBar.GetActionLossOfControlCooldownDuration
local ActionBarActionButtonMixin = ActionBarActionButtonMixin
local BaseActionButtonMixin = BaseActionButtonMixin
local ActionButtonSpellAlertManager = ActionButtonSpellAlertManager
local ActionButton_UpdateRangeIndicator = ActionButton_UpdateRangeIndicator
local ClearNewActionHighlight = ClearNewActionHighlight
local pairs = pairs
local select = select
local type = type
local tostring = tostring
local string_format = string.format
local wipe = wipe
local ACTION_FLASH_TIME = ATTACK_BUTTON_FLASH_TIME

local UpdateButtonCooldown

local ACTION_BUTTON_CAST_TYPE = {
  Cast = 1,
  Channel = 2,
  Empowered = 3,
}

local PUI_UPDATE_STATE_SNIPPET = [[
  local state = tostring(...)
  self:SetAttribute("state", state)

  local active = self:GetAttribute("pui-active")
  local page
  if self:GetAttribute("pui-paged") then
    page = tonumber(state) or 0
    if self:GetAttribute("pui-hide-zero") and page <= 0 then
      active = false
    end
    if self:GetAttribute("pui-normal-visible") ~= true then
      active = false
    end
  end

  local action
  if active then
    if page then
      if page > 0 then
        local buttonIndex = self:GetAttribute("pui-button-index")
        if buttonIndex then
          action = buttonIndex + ((page - 1) * 12)
        end
      end
    else
      action = self:GetAttribute(format("pui-action-%s", state))
    end
  end

  if action then
    self:SetAttribute("type", "action")
    self:SetAttribute("action", action)
    self:SetAttribute("typerelease", "actionrelease")
  else
    self:SetAttribute("type", "empty")
    self:SetAttribute("action", nil)
    self:SetAttribute("typerelease", nil)
  end

  local pressAndHold = false
  if action and IsPressHoldReleaseSpell then
    local actionType, id, subType = GetActionInfo(action)
    if actionType == "spell" then
      pressAndHold = IsPressHoldReleaseSpell(id)
    elseif actionType == "macro" and subType == "spell" then
      pressAndHold = IsPressHoldReleaseSpell(id)
    end
  end
  self:SetAttribute("pressAndHoldAction", pressAndHold)

  if active then
    self:SetAttribute("statehidden", nil)
    self:Show(true)
  else
    self:SetAttribute("statehidden", true)
    self:Hide(true)
  end
]]

local PUI_CHILD_UPDATE_STATE_SNIPPET = [[
  self:RunAttribute("PUI_UpdateState", message)
  self:CallMethod("UpdateAction")
]]

local function GetShortBindingKey(binding)
  local key = GetBindingKey(binding)
  if key then
    return LibKeyBound:ToShortKey(key)
  end
  return key
end

function Engine:UpdateButtonHotkey(button)
  local hotkey = button and button.HotKey
  if not hotkey then
    return
  end

  local bindingAction = button.__puiBindingAction
  local key = bindingAction and GetShortBindingKey(bindingAction)

  if key and key ~= "" then
    hotkey:SetText(key)
    hotkey:Show()
  else
    hotkey:SetText("")
    hotkey:Hide()
  end
end

local function GetHotkey(button)
  local bindingAction = button.__puiBindingAction
  return bindingAction and GetShortBindingKey(bindingAction)
end

local function GetBindings(button)
  local output = ""
  local bindingAction = button.__puiBindingAction

  if bindingAction then
    for index = 1, select("#", GetBindingKey(bindingAction)) do
      local key = select(index, GetBindingKey(bindingAction))
      if key and key ~= "" then
        if output ~= "" then output = output .. ", " end
        output = output .. GetBindingText(key, "KEY_")
      end
    end
  end

  return output
end

local function SetKey(button, key)
  if button.__puiBindingAction then
    SetBinding(key, button.__puiBindingAction)
  end
end

local function ClearBindings(button)
  local bindingAction = button.__puiBindingAction
  if not bindingAction then
    return
  end
  local key = GetBindingKey(bindingAction)
  while key do
    SetBinding(key, nil)
    key = GetBindingKey(bindingAction)
  end
end

local function GetActionName(button)
  return string_format(
    "%s Button %d",
    button.__puiBarLabel or "Action Bar",
    button.__puiButtonIndex or 0
  )
end

local function OnEnter(button)
  BaseActionButtonMixin.BaseActionButtonMixin_OnEnter(button)
  if button.action and Core:ShouldShowActionTooltip() then
    button:SetTooltip()
  end
  LibKeyBound:Set(button)
end

local function OnLeave(button)
  BaseActionButtonMixin.BaseActionButtonMixin_OnLeave(button)
  GameTooltip:Hide()
end

local function ApplyButtonCheckedState(button, isCurrent, isAutoRepeat, isAutoCastPet)
  button:SetChecked((isCurrent or isAutoRepeat) and not isAutoCastPet)
end

local function UpdateButtonState(button)
  local action = button.action
  if not action then
    button:SetChecked(false)
    return
  end

  local isCurrent = C_ActionBar.IsCurrentAction(action)
  local isAutoRepeat = C_ActionBar.IsAutoRepeatAction(action)
  local isAutoCastPet = C_ActionBar.IsAutoCastPetAction(action)
  if issecretvalue(isCurrent) or issecretvalue(isAutoRepeat) or issecretvalue(isAutoCastPet) then
    return
  end

  ApplyButtonCheckedState(button, isCurrent, isAutoRepeat, isAutoCastPet)
end

local function UpdateButtonUsable(button, action, isUsable, notEnoughMana)
  if issecretvalue(action) then
    return
  end
  if action ~= nil and action ~= button.action then
    return
  end

  if issecretvalue(isUsable) or issecretvalue(notEnoughMana) then
    return
  end
  if isUsable == nil or notEnoughMana == nil then
    isUsable, notEnoughMana = C_ActionBar.IsUsableAction(button.action)
    if issecretvalue(isUsable) or issecretvalue(notEnoughMana) then
      return
    end
  end

  if isUsable then
    button.icon:SetVertexColor(1, 1, 1)
  elseif notEnoughMana then
    button.icon:SetVertexColor(0.5, 0.5, 1)
  else
    button.icon:SetVertexColor(0.4, 0.4, 0.4)
  end

  local locked = C_LevelLink.IsActionLocked(button.action)
  if issecretvalue(locked) then
    return
  end

  button.icon:SetDesaturated(locked == true)
  if button.LevelLinkLockIcon then
    button.LevelLinkLockIcon:SetShown(locked == true)
  end
end

local function GetButtonSpellID(button)
  return button and button.__puiSpellEventID or nil
end

local function UpdateButtonSpellAlert(button)
  local spellID = GetButtonSpellID(button)
  if not spellID then
    ActionButtonSpellAlertManager:HideAlert(button)
    return
  end

  local shown = C_SpellActivationOverlay.IsSpellOverlayed(spellID)
  if issecretvalue(shown) then
    return
  end
  if shown then
    ActionButtonSpellAlertManager:ShowAlert(button)
  else
    ActionButtonSpellAlertManager:HideAlert(button)
  end
end

local function StartButtonFlash(button, skipStateRefresh)
  if button.flashing ~= 1 then
    button.flashing = 1
    Engine.flashingButtons[button] = true
    Engine.flashingButtonCount = Engine.flashingButtonCount + 1
  end

  Engine.flashTime = 0
  if not skipStateRefresh then
    button:UpdateState()
  end

  if Engine.flashDriver then
    Engine.flashDriver:Show()
  end
end

local function StopButtonFlash(button, skipStateRefresh)
  if button.flashing == 1 then
    button.flashing = 0
    if Engine.flashingButtons[button] then
      Engine.flashingButtons[button] = nil
      Engine.flashingButtonCount = Engine.flashingButtonCount - 1
    end
  end

  button.Flash:Hide()
  if not skipStateRefresh then
    button:UpdateState()
  end

  if Engine.flashingButtonCount == 0 and Engine.flashDriver then
    Engine.flashDriver:Hide()
  end
end

local function IsButtonFlashing(button)
  return button.flashing == 1
end

local function ClearButtonFlash(button)
  if button.AutoCastOverlay then
    button.AutoCastOverlay:ShowAutoCastEnabled(false)
    button.AutoCastOverlay:Hide()
  end
end

local function FlashDriverOnUpdate(_, elapsed)
  local flashTime = Engine.flashTime - elapsed
  if flashTime > 0 then
    Engine.flashTime = flashTime
    return
  end

  local overtime = -flashTime
  if overtime >= ACTION_FLASH_TIME then
    overtime = 0
  end
  Engine.flashTime = ACTION_FLASH_TIME - overtime

  for button in pairs(Engine.flashingButtons) do
    if button.Flash:IsShown() then
      button.Flash:Hide()
    else
      button.Flash:Show()
    end
  end
end

local function ApplyButtonFlashState(button, isAttack, isCurrent, isAutoRepeat, skipStateRefresh)
  if (isAttack and isCurrent) or isAutoRepeat then
    button:StartFlash(skipStateRefresh)
  else
    button:StopFlash(skipStateRefresh)
  end
end

local function UpdateButtonFlash(button, skipStateRefresh)
  local action = button.action
  if not action then
    button:StopFlash(skipStateRefresh)
    return
  end

  local isAttack = C_ActionBar.IsAttackAction(action)
  local isCurrent = C_ActionBar.IsCurrentAction(action)
  local isAutoRepeat = C_ActionBar.IsAutoRepeatAction(action)
  if issecretvalue(isAttack) or issecretvalue(isCurrent) or issecretvalue(isAutoRepeat) then
    return
  end

  ApplyButtonFlashState(button, isAttack, isCurrent, isAutoRepeat, skipStateRefresh)
end

local function UpdateButtonStateAndFlash(button)
  local action = button.action
  if not action then
    button:SetChecked(false)
    button:StopFlash(true)
    return
  end

  local isAttack = C_ActionBar.IsAttackAction(action)
  local isCurrent = C_ActionBar.IsCurrentAction(action)
  local isAutoRepeat = C_ActionBar.IsAutoRepeatAction(action)
  local isAutoCastPet = C_ActionBar.IsAutoCastPetAction(action)
  if issecretvalue(isAttack)
    or issecretvalue(isCurrent)
    or issecretvalue(isAutoRepeat)
    or issecretvalue(isAutoCastPet)
  then
    return
  end

  ApplyButtonCheckedState(button, isCurrent, isAutoRepeat, isAutoCastPet)
  ApplyButtonFlashState(button, isAttack, isCurrent, isAutoRepeat, true)
end

local function UpdateButtonProfessionQuality(button)
  local isItem = C_ActionBar.IsItemAction(button.action)
  if issecretvalue(isItem) then
    return
  end

  if isItem then
    local qualityInfo = C_ActionBar.GetProfessionQualityInfo(button.action)
    if not issecretvalue(qualityInfo) and qualityInfo ~= nil then
      local atlas = qualityInfo.iconInventory
      if not issecretvalue(atlas) and atlas ~= nil then
        if not button.ProfessionQualityOverlayFrame then
          button.ProfessionQualityOverlayFrame = button:CreateTextureOverlayFrame()
          button.ProfessionQualityOverlayFrame:SetPoint("TOPLEFT", 14, -14)
        end
        button.ProfessionQualityOverlayFrame:Show()
        button.ProfessionQualityOverlayFrame.Texture:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
        return
      end
    end
  end

  button:ClearProfessionQuality()
end

local function UpdateButtonEquipped(button)
  button:UpdateProfessionQuality()

  local isEquipped = C_ActionBar.IsEquippedAction(button.action)
  if not issecretvalue(isEquipped) then
    button.Border:SetShown(isEquipped == true)
  end
end

local function UpdateButtonAssistedCombat(button)
  local action = button.action
  if not action then
    if button.AssistedCombatRotationFrame then
      button.AssistedCombatRotationFrame:Hide()
    end
    return false
  end

  local shown = C_ActionBar.IsAssistedCombatAction(action)
  if issecretvalue(shown) then
    if button.AssistedCombatRotationFrame then
      button.AssistedCombatRotationFrame:Hide()
    end
    return false
  end

  local rotationFrame = button.AssistedCombatRotationFrame
  if shown and not rotationFrame then
    rotationFrame = CreateFrame("Frame", nil, button, "ActionBarButtonAssistedCombatRotationTemplate")
    button.AssistedCombatRotationFrame = rotationFrame
  end

  if rotationFrame then
    local isShown = rotationFrame:IsShown()
    if shown ~= isShown then
      rotationFrame:SetShown(shown == true)
      EventRegistry:TriggerEvent("ActionButton.OnAssistedCombatRotationFrameChanged", button, shown)
    end
  end
  return shown == true
end

local function OnShow(button)
  if button.__puiActionActive then
    Engine:RefreshButton(button)
  end
end

local function OnHide(button)
  Engine:UnregisterButtonRangeCheck(button)
  button:StopFlash(true)
  Engine:UnregisterButtonTopology(button)
end

local function OnEvent(button, event, ...)
  if event == "ACTION_RANGE_CHECK_UPDATE" then
    local _, inRange, checksRange = ...
    ActionButton_UpdateRangeIndicator(button, checksRange, inRange)
  end
end

local function PostClick(button)
  if button.__puiActionActive and button.action then
    button:UpdateState()
  end
end

local function ChargeCooldownShown(cooldown)
  local button = cooldown:GetParent()
  if button and button.__puiActionBarSkin then
    Core:ApplyButtonCooldownAppearance(button, button.__puiActionBarSkin)
  end
end

local function ChargeCooldownHidden(cooldown)
  local button = cooldown:GetParent()
  if button and button.__puiActionBarSkin then
    Core:ApplyButtonCooldownAppearance(button, button.__puiActionBarSkin)
  end
end

local function SetupSecureDragAndClick(button, header)
  button:SetAttribute("PUI_PickupButton", [[
    local action = ...
    if not action then
      return false
    end
    return "action", action
  ]])

  button:SetAttribute("PUI_OnDragStart", [[
    if self:GetAttribute("buttonlock") and not IsModifiedClick("PICKUPACTION") then
      return false
    end
    local action = self:GetAttribute("action")
    if not action then
      return false
    end
    return self:RunAttribute("PUI_PickupButton", action)
  ]])

  button:SetAttribute("PUI_OnReceiveDrag", [[
    local kind, value = ...
    if not kind or not value then
      return false
    end
    local action = self:GetAttribute("action")
    if not action then
      return false
    end
    return self:RunAttribute("PUI_PickupButton", action)
  ]])

  button:SetScript("OnDragStart", nil)
  header:WrapScript(button, "OnDragStart", [[
    return self:RunAttribute("PUI_OnDragStart")
  ]])
  header:WrapScript(button, "OnDragStart", [[
    return "message", "update"
  ]], [[
    self:RunAttribute("PUI_UpdateState", self:GetAttribute("state"))
    self:CallMethod("UpdateAction")
  ]])

  button:SetScript("OnReceiveDrag", nil)
  header:WrapScript(button, "OnReceiveDrag", [[
    return self:RunAttribute("PUI_OnReceiveDrag", kind, value, ...)
  ]])
  header:WrapScript(button, "OnReceiveDrag", [[
    return "message", "update"
  ]], [[
    self:RunAttribute("PUI_UpdateState", self:GetAttribute("state"))
    self:CallMethod("UpdateAction")
  ]])

  header:WrapScript(button, "OnClick", [[
    if button ~= "Keybind"
      and ((self:GetAttribute("unlockedpreventdrag") and not self:GetAttribute("buttonlock")) or IsModifiedClick("PICKUPACTION"))
    then
      local useOnKeyDown = self:GetAttribute("useOnKeyDown")
      if useOnKeyDown ~= false then
        self:SetAttribute("PUI_ToggledOnDown", true)
        self:SetAttribute("PUI_ToggledOnDownBackup", useOnKeyDown)
        self:SetAttribute("useOnKeyDown", false)
      end
    end
    if button == "Keybind" then
      return "LeftButton"
    end
  ]], [[
    if self:GetAttribute("PUI_ToggledOnDown") then
      self:SetAttribute("useOnKeyDown", self:GetAttribute("PUI_ToggledOnDownBackup"))
      self:SetAttribute("PUI_ToggledOnDown", nil)
      self:SetAttribute("PUI_ToggledOnDownBackup", nil)
    end
  ]])
end

local function SpellVFXCastingAnimOnHide(frame)
  local button = frame:GetParent()
  button:ClearReticle()
  button.cooldown:SetSwipeColor(0, 0, 0, 1)
  UpdateButtonCooldown(button, false, false)
end

local function SpellVFXCastingFinishAnimOnFinished(animation)
  animation:GetParent():GetParent():Hide()
  local button = animation:GetParent():GetParent():GetParent()
  button:StopSpellCastAnim(false, button.actionButtonCastType)
end

local function PlayTargettingReticleAnim(button)
  if not button.action or not button:SpellFXEnabled() then
    return
  end

  if button.InterruptDisplay:IsShown() then
    button.InterruptDisplay:Hide()
  end

  local assistedCombat = C_ActionBar.IsAssistedCombatAction(button.action)
  if issecretvalue(assistedCombat) or assistedCombat then
    return
  end

  button.TargetReticleAnimFrame:Setup()
end

local function AttachBlizzardRenderMethods(button)
  button.UpdateState = UpdateButtonState
  button.UpdateUsable = UpdateButtonUsable
  button.CreateTextureOverlayFrame = ActionBarActionButtonMixin.CreateTextureOverlayFrame
  button.UpdateProfessionQuality = UpdateButtonProfessionQuality
  button.ClearProfessionQuality = ActionBarActionButtonMixin.ClearProfessionQuality
  button.UpdateSpellAlert = UpdateButtonSpellAlert
  button.UpdateAssistedCombatRotationFrame = UpdateButtonAssistedCombat
  button.UpdateFlash = UpdateButtonFlash
  button.ClearFlash = ClearButtonFlash
  button.StartFlash = StartButtonFlash
  button.StopFlash = StopButtonFlash
  button.IsFlashing = IsButtonFlashing
  button.SpellFXEnabled = ActionBarActionButtonMixin.SpellFXEnabled
  button.ClearReticle = ActionBarActionButtonMixin.ClearReticle
  button.ClearInterruptDisplay = ActionBarActionButtonMixin.ClearInterruptDisplay
  button.PlaySpellCastAnim = ActionBarActionButtonMixin.PlaySpellCastAnim
  button.PlayTargettingReticleAnim = PlayTargettingReticleAnim
  button.StopTargettingReticleAnim = ActionBarActionButtonMixin.StopTargettingReticleAnim
  button.StopSpellCastAnim = ActionBarActionButtonMixin.StopSpellCastAnim
  button.PlaySpellInterruptedAnim = ActionBarActionButtonMixin.PlaySpellInterruptedAnim
  button.SetTooltip = ActionBarActionButtonMixin.SetTooltip
end

function Engine:CreateButton(name, header)
  local existing = _G[name]
  if existing then
    return existing
  end

  local button = CreateFrame("CheckButton", name, header, "ActionButtonTemplate, SecureActionButtonTemplate")
  AttachBlizzardRenderMethods(button)

  if button.SpellCastAnimFrame then
    button.SpellCastAnimFrame:SetScript("OnHide", SpellVFXCastingAnimOnHide)
    button.SpellCastAnimFrame.EndBurst.FinishCastAnim:SetScript("OnFinished", SpellVFXCastingFinishAnimOnFinished)
  end

  button.__puiActionBarManaged = true
  button.__puiActionBarTooltip = true
  button.__puiActionActive = false
  button.header = header
  button.flashing = 0
  button.enableLOCCooldown = true
  button.maxDisplayCount = 9999

  button:SetAttribute("PUI_UpdateState", PUI_UPDATE_STATE_SNIPPET)
  button:SetAttributeNoHandler("_childupdate-state", PUI_CHILD_UPDATE_STATE_SNIPPET)
  button:SetAttribute("checkselfcast", true)
  button:SetAttribute("checkfocuscast", true)
  button:SetAttribute("checkmouseovercast", true)
  button:SetAttribute("useparent-unit", true)
  button:SetAttribute("buttonlock", Core.lockActionBars ~= false)
  button:SetAttribute("unlockedpreventdrag", true)
  button:SetAttribute("useOnKeyDown", Core.castOnKeyDown ~= false)
  button:SetAttribute("state", "0")
  button:SetAttribute("pui-active", false)

  button:RegisterForDrag("LeftButton", "RightButton")
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetScript("OnAttributeChanged", nil)
  button:SetScript("OnEnter", OnEnter)
  button:SetScript("OnLeave", OnLeave)
  button:SetScript("OnShow", OnShow)
  button:SetScript("OnHide", OnHide)
  button:SetScript("PostClick", PostClick)
  button.OnEvent = OnEvent

  button.HasAction = function(self)
    return self.__puiHasAction == true
  end
  button.UpdateAction = function(self, force)
    local action = self:GetAttribute("action")
    if force or self.action ~= action then
      Engine:RefreshButton(self)
    end
  end
  button.OnActionBarSlotChanged = function(self)
    if self.action then
      ClearNewActionHighlight(self.action, true)
    end
    Engine:ApplyButtonSecureState(self)
    Engine:QueueButtonRefresh(self)
  end

  SetupSecureDragAndClick(button, header)

  if button.chargeCooldown and not button.__puiChargeVisibilityHooked then
    button.chargeCooldown:HookScript("OnShow", ChargeCooldownShown)
    button.chargeCooldown:HookScript("OnHide", ChargeCooldownHidden)
    button.__puiChargeVisibilityHooked = true
  end

  self.buttons[button] = true
  self:ApplyButtonSecureState(button)
  return button
end

function Engine:ConfigureButton(button, bindingAction, barLabel, buttonIndex)
  button.__puiBindingAction = bindingAction
  button.__puiBarLabel = barLabel
  button.__puiButtonIndex = buttonIndex
  button:SetAttribute("buttonlock", Core.lockActionBars ~= false)
  button:SetAttribute("useOnKeyDown", Core.castOnKeyDown ~= false)

  button.GetHotkey = GetHotkey
  button.GetBindings = GetBindings
  button.SetKey = SetKey
  button.ClearBindings = ClearBindings
  button.GetActionName = GetActionName
  button.OnEnter = function(self)
    LibKeyBound:Set(self)
  end

  self:UpdateButtonHotkey(button)
end

local function RemoveIndexedButton(buttons, button, indexField)
  local index = button[indexField]
  if not index then
    return
  end

  local lastIndex = #buttons
  local lastButton = buttons[lastIndex]

  if index ~= lastIndex then
    buttons[index] = lastButton
    lastButton[indexField] = index
  end

  buttons[lastIndex] = nil
  button[indexField] = nil
end

function Engine:UnregisterButtonContent(button)
  local spellID = button.__puiSpellEventID
  if spellID and button.__puiSpellEventIndex then
    local buttons = self.spellEventButtons[spellID]
    if buttons then
      RemoveIndexedButton(buttons, button, "__puiSpellEventIndex")
      if #buttons == 0 then
        self.spellEventButtons[spellID] = nil
      end
    else
      button.__puiSpellEventIndex = nil
    end
  end

  if button.__puiFlyoutIndex then
    RemoveIndexedButton(self.flyoutButtons, button, "__puiFlyoutIndex")
  end

  if button.__puiSummonPetIndex then
    RemoveIndexedButton(self.summonPetButtons, button, "__puiSummonPetIndex")
  end

  button.__puiSpellEventID = nil
  button.__puiFlyoutID = nil
  button.__puiContentActionType = nil
  button.__puiContentActionID = nil
  button.__puiContentActionSubType = nil
end

function Engine:RefreshButtonContent(button)
  if not button.__puiActiveButtonIndex or not button.action or not button.__puiHasAction then
    self:UnregisterButtonContent(button)
    return
  end

  local actionType, actionID, actionSubType = GetActionInfo(button.action)
  if issecretvalue(actionType) or issecretvalue(actionID) or issecretvalue(actionSubType) then
    self:UnregisterButtonContent(button)
    return
  end

  if button.__puiContentActionType == actionType
    and button.__puiContentActionID == actionID
    and button.__puiContentActionSubType == actionSubType
  then
    return
  end

  self:UnregisterButtonContent(button)
  button.__puiContentActionType = actionType
  button.__puiContentActionID = actionID
  button.__puiContentActionSubType = actionSubType

  if (actionType == "spell" or (actionType == "macro" and actionSubType == "spell"))
    and type(actionID) == "number"
    and actionID > 0
  then
    local buttons = self.spellEventButtons[actionID]
    if not buttons then
      buttons = {}
      self.spellEventButtons[actionID] = buttons
    end

    local index = #buttons + 1
    buttons[index] = button
    button.__puiSpellEventID = actionID
    button.__puiSpellEventIndex = index
  end

  if actionType == "flyout" and type(actionID) == "number" and actionID > 0 then
    local index = #self.flyoutButtons + 1
    self.flyoutButtons[index] = button
    button.__puiFlyoutID = actionID
    button.__puiFlyoutIndex = index
  elseif actionType == "summonpet" then
    local index = #self.summonPetButtons + 1
    self.summonPetButtons[index] = button
    button.__puiSummonPetIndex = index
  end
end

-- Blizzard override buttons share these action slots, so PleebUI keeps its range subscribers addon-owned.
function Engine:RegisterButtonRangeCheck(button)
  local action = button.action
  if not action or button.__puiRangeAction == action then
    return
  end

  if button.__puiRangeAction then
    self:UnregisterButtonRangeCheck(button)
  end

  local count = self.rangeActionCounts[action] or 0
  if count == 0 then
    C_ActionBar.EnableActionRangeCheck(action, true)
  end
  self.rangeActionCounts[action] = count + 1
  button.__puiRangeAction = action
end

function Engine:UnregisterButtonRangeCheck(button)
  local action = button.__puiRangeAction
  if not action then
    return
  end

  local count = self.rangeActionCounts[action]
  if count == 1 then
    self.rangeActionCounts[action] = nil
    C_ActionBar.EnableActionRangeCheck(action, false)
  else
    self.rangeActionCounts[action] = count - 1
  end
  button.__puiRangeAction = nil
end

function Engine:ClearButton(button)
  self:UnregisterButtonContent(button)
  button.__puiHasAction = false
  button.icon:Hide()
  button.icon:SetDesaturated(false)
  button.icon:SetVertexColor(1, 1, 1)
  button.Count:SetText("")
  button.Name:SetText("")
  button.Border:Hide()
  button.cooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
  button.chargeCooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
  button.lossOfControlCooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
  button.__puiHasChargeCooldown = nil
  button.__puiLossOfControlReplacesNormal = nil
  button:StopFlash(true)
  button:SetChecked(false)
  button:ClearFlash()
  button:ClearProfessionQuality()
  button:UpdateAssistedCombatRotationFrame()
  ActionButtonSpellAlertManager:HideAlert(button)
end

function Engine:UpdateCount(button)
  if button.action and button.__puiHasAction then
    button.Count:SetText(C_ActionBar.GetActionDisplayCount(button.action, button.maxDisplayCount, "*"))
  else
    button.Count:SetText("")
  end
end

local function RefreshButtonChargeCapability(button)
  local chargeInfo = GetActionCharges(button.action)
  local hasChargeCooldown = chargeInfo.maxCharges > 0
  button.__puiHasChargeCooldown = hasChargeCooldown
  return hasChargeCooldown
end

local function RefreshLossOfControlCooldown(button)
  local action = button.action
  local lossOfControlInfo = GetActionLossOfControlCooldownInfo(action)
  local replacesNormal = lossOfControlInfo.shouldReplaceNormalCooldown

  button.__puiLossOfControlReplacesNormal = replacesNormal
  button.lossOfControlCooldown:SetCooldownFromDurationObject(
    GetActionLossOfControlCooldownDuration(action),
    true
  )

  return replacesNormal
end

UpdateButtonCooldown = function(button, refreshCharge, refreshLossOfControl)
  local action = button.action
  if not action or not button.__puiHasAction then
    button.cooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
    button.chargeCooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
    button.lossOfControlCooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
    button.__puiHasChargeCooldown = nil
    button.__puiLossOfControlReplacesNormal = nil
    return
  end

  local replaceNormalCooldown = button.__puiLossOfControlReplacesNormal
  local lossOfControlInitialized = replaceNormalCooldown ~= nil
  if refreshLossOfControl or not lossOfControlInitialized then
    replaceNormalCooldown = RefreshLossOfControlCooldown(button)
  end

  local hasChargeCooldown = button.__puiHasChargeCooldown
  local chargeInitialized = hasChargeCooldown ~= nil
  if refreshCharge or not chargeInitialized then
    hasChargeCooldown = RefreshButtonChargeCapability(button)
  end

  if replaceNormalCooldown then
    if refreshLossOfControl or not lossOfControlInitialized then
      button.cooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
    end
  else
    button.cooldown:SetCooldownFromDurationObject(GetActionCooldownDuration(action), true)
  end

  if refreshCharge
    or refreshLossOfControl
    or not chargeInitialized
    or (hasChargeCooldown and not replaceNormalCooldown)
  then
    if replaceNormalCooldown or not hasChargeCooldown then
      button.chargeCooldown:SetCooldownFromDurationObject(EMPTY_COOLDOWN_DURATION, true)
    else
      button.chargeCooldown:SetCooldownFromDurationObject(
        GetActionChargeDuration(action) or EMPTY_COOLDOWN_DURATION,
        true
      )
    end
  end
end

function Engine:SyncActionUIButton(button, action)
  if action then
    if button.__puiActionUIButtonAction == action then
      return
    end

    C_ActionBar.RegisterActionUIButton(button, action, button.cooldown)
    button.__puiActionUIButtonAction = action
  elseif button.__puiActionUIButtonAction then
    C_ActionBar.UnregisterActionUIButton(button)
    button.__puiActionUIButtonAction = nil
  end
end

function Engine:RefreshButton(button)
  if not button or not button.__puiActionActive then
    return
  end

  local action = button:GetAttribute("action")
  if button.action ~= action then
    self:UnregisterButtonRangeCheck(button)
    self:UnregisterButtonTopology(button)
    button.action = action
  end
  self:RegisterButtonTopology(button)
  self:SyncActionUIButton(button, action)

  if not action then
    self:ClearButton(button)
    return
  end

  if button:IsVisible() then
    self:RegisterButtonRangeCheck(button)
  end

  local hasAction = C_ActionBar.HasAction(action)
  if issecretvalue(hasAction) then
    return
  end
  button.__puiHasAction = hasAction

  if not hasAction then
    self:ClearButton(button)
    button:SetAlpha((Core.alwaysShowGrid ~= false or Core.actionGridShown == true) and 1 or 0)
    button:UpdateFlyout()
    return
  end

  self:RefreshButtonContent(button)

  button:SetAlpha(1)
  button.icon:SetTexture(C_ActionBar.GetActionTexture(action))
  button.icon:Show()
  button.icon:SetDesaturated(false)

  UpdateButtonStateAndFlash(button)
  button:UpdateUsable()
  UpdateButtonEquipped(button)

  local usesActionText = C_ActionBar.UsesActionText(action)
  if not issecretvalue(usesActionText) then
    if usesActionText then
      button.Name:SetText(C_ActionBar.GetActionText(action))
    else
      button.Name:SetText("")
    end
  end

  self:UpdateCount(button)
  UpdateButtonCooldown(button, true, true)
  button:UpdateFlyout()
  button:UpdateSpellAlert()
  button:UpdateAssistedCombatRotationFrame()

  if GameTooltip:GetOwner() == button and Core:ShouldShowActionTooltip() then
    button:SetTooltip()
  end
end

function Engine:RefreshTooltipPolicy()
  if GameTooltip:IsForbidden() then
    return
  end

  local tooltipOwner = GameTooltip:GetOwner()
  if not tooltipOwner or not tooltipOwner.__puiActionBarTooltip then
    return
  end

  if not Core:ShouldShowActionTooltip() then
    GameTooltip:Hide()
  elseif self.buttons[tooltipOwner] and tooltipOwner.__puiActionActive and tooltipOwner.__puiHasAction then
    tooltipOwner:SetTooltip()
  end
end

function Engine:ApplyButtonSecureState(button)
  if InCombatLockdown() then
    return
  end

  local header = button.header
  header:SetFrameRef("puiStateButton", button)
  header:Execute([[
    local frame = self:GetFrameRef("puiStateButton")
    control:RunFor(frame, frame:GetAttribute("PUI_UpdateState"), frame:GetAttribute("state"))
  ]])
end

function Engine:SetButtonAction(button, action, active, subsystemKey)
  if InCombatLockdown() then
    Core:QueueSubsystemRefresh(subsystemKey, "actionButtons")
    return
  end

  if active ~= true then
    self:DeactivateButton(button)
    return
  end

  button.__puiSubsystemKey = subsystemKey
  button.__puiActionActive = true
  button:SetAttribute("pui-active", true)

  if not button:GetAttribute("pui-paged") then
    local state = tostring(button:GetAttribute("state") or "0")
    button:SetAttribute("pui-action-" .. state, action)
  end
  self:ApplyButtonSecureState(button)
  self:RefreshButton(button)
end

function Engine:DeactivateButton(button)
  if not button then
    return
  end

  self:UnregisterButtonRangeCheck(button)
  button.__puiActionActive = false
  button:SetAttribute("pui-active", false)

  if not button:GetAttribute("pui-paged") then
    local state = tostring(button:GetAttribute("state") or "0")
    button:SetAttribute("pui-action-" .. state, nil)
  end
  self:ApplyButtonSecureState(button)
  self:UnregisterButtonTopology(button)
  self:SyncActionUIButton(button, nil)
  button.action = nil
  self:ClearButton(button)
end

function Engine:UnregisterButtonTopology(button)
  if not button then
    return
  end

  self:UnregisterButtonContent(button)

  local activeIndex = button.__puiActiveButtonIndex
  if activeIndex then
    local lastIndex = #self.activeButtons
    local lastButton = self.activeButtons[lastIndex]

    if activeIndex ~= lastIndex then
      self.activeButtons[activeIndex] = lastButton
      lastButton.__puiActiveButtonIndex = activeIndex
    end

    self.activeButtons[lastIndex] = nil
    button.__puiActiveButtonIndex = nil
  end

  local indexedAction = button.__puiIndexedAction
  local actionSlotIndex = button.__puiActionSlotIndex
  if indexedAction and actionSlotIndex then
    local buttons = self.actionSlotButtons[indexedAction]
    if buttons then
      local lastIndex = #buttons
      local lastButton = buttons[lastIndex]

      if actionSlotIndex ~= lastIndex then
        buttons[actionSlotIndex] = lastButton
        lastButton.__puiActionSlotIndex = actionSlotIndex
      end

      buttons[lastIndex] = nil
      if #buttons == 0 then
        self.actionSlotButtons[indexedAction] = nil
      end
    end

    button.__puiIndexedAction = nil
    button.__puiActionSlotIndex = nil
  end
end

function Engine:RegisterButtonTopology(button)
  if not button
    or not button.__puiActionActive
    or not button.action
    or not button:IsVisible()
  then
    self:UnregisterButtonTopology(button)
    return
  end

  local action = button.action
  if button.__puiIndexedAction and button.__puiIndexedAction ~= action then
    self:UnregisterButtonTopology(button)
  end

  if not button.__puiActiveButtonIndex then
    local activeIndex = #self.activeButtons + 1
    self.activeButtons[activeIndex] = button
    button.__puiActiveButtonIndex = activeIndex
  end

  if button.__puiIndexedAction == action and button.__puiActionSlotIndex then
    return
  end

  local buttons = self.actionSlotButtons[action]
  if not buttons then
    buttons = {}
    self.actionSlotButtons[action] = buttons
  end

  local actionSlotIndex = #buttons + 1
  buttons[actionSlotIndex] = button
  button.__puiIndexedAction = action
  button.__puiActionSlotIndex = actionSlotIndex
end

function Engine:RefreshUsable(changes)
  for changeIndex = 1, #changes do
    local change = changes[changeIndex]
    local action = change.slot

    if not issecretvalue(action) then
      local buttons = self.actionSlotButtons[action]
      if buttons then
        for buttonIndex = 1, #buttons do
          buttons[buttonIndex]:UpdateUsable(action, change.usable, change.noMana)
        end
      end
    end
  end
end

function Engine:RefreshAllButtons()
  for button in pairs(self.buttons) do
    if button.__puiActionActive then
      self:RefreshButton(button)
    end
  end
end

function Engine:QueueButtonRefresh(button)
  if self.pendingFullRefresh
    or not button
    or not button.__puiActionActive
    or button.__puiRuntimeRefreshQueued
  then
    return
  end

  button.__puiRuntimeRefreshQueued = true
  local buttons = self.pendingButtonRefreshes
  buttons[#buttons + 1] = button
  self.runtimeUpdateFrame:Show()
end

function Engine:QueueButtonIcon(button)
  if self.pendingFullRefresh
    or not button
    or not button.__puiActionActive
    or button.__puiRuntimeIconQueued
  then
    return
  end

  button.__puiRuntimeIconQueued = true
  local buttons = self.pendingIconButtons
  buttons[#buttons + 1] = button
  self.runtimeUpdateFrame:Show()
end

function Engine:QueueAllButtonRefresh()
  self.pendingFullRefresh = true
  self.runtimeUpdateFrame:Show()
end

function Engine:QueueActionSlotRefresh(action)
  if action == 0 then
    for button in pairs(self.buttons) do
      if button.__puiActionActive then
        self:ApplyButtonSecureState(button)
      end
    end
    self:QueueAllButtonRefresh()
    return
  end

  local buttons = self.actionSlotButtons[action]
  if not buttons then
    return
  end

  for index = 1, #buttons do
    local button = buttons[index]
    self:ApplyButtonSecureState(button)
    self:QueueButtonRefresh(button)
  end
end

function Engine:QueueSpellActionRefresh(spellID)
  if issecretvalue(spellID) then
    return
  end
  if spellID == nil then
    self:QueueAllButtonRefresh()
    return
  end

  local actionSlots = C_ActionBar.FindSpellActionButtons(spellID)
  if not actionSlots then
    return
  end

  for slotIndex = 1, #actionSlots do
    local buttons = self.actionSlotButtons[actionSlots[slotIndex]]
    if buttons then
      for buttonIndex = 1, #buttons do
        self:QueueButtonRefresh(buttons[buttonIndex])
      end
    end
  end
end

function Engine:QueueSummonPetIcons()
  for index = 1, #self.summonPetButtons do
    self:QueueButtonIcon(self.summonPetButtons[index])
  end
end

function Engine:QueueRuntimeUpdate(kind, value)
  if self.pendingFullRefresh then
    return
  end

  if kind == "cooldown" then
    self.pendingCooldownRefresh = true
  elseif kind == "charges" then
    self.pendingChargeRefresh = true
  elseif kind == "lossOfControl" then
    self.pendingLossOfControlRefresh = true
  elseif kind == "icons" then
    self.pendingIconRefresh = true
  elseif kind == "equipped" then
    self.pendingEquippedRefresh = true
  elseif kind == "usable" then
    self.pendingUsableRefresh = true
  elseif kind == "state" then
    self.pendingStateRefresh = true
  elseif kind == "stateAndFlash" then
    self.pendingStateAndFlashRefresh = true
  elseif kind == "assisted" then
    self.pendingAssistedCombatRefresh = true
  elseif kind == "combatFlash" then
    self.pendingCombatFlash = value
  elseif kind == "autoRepeatFlash" then
    self.pendingAutoRepeatFlash = value
  end

  self.runtimeUpdateFrame:Show()
end

local function RefreshCooldownTooltip(flushID)
  if GameTooltip:IsForbidden() then
    return
  end

  local tooltipOwner = GameTooltip:GetOwner()
  if tooltipOwner
    and tooltipOwner.__puiRuntimeFlushID ~= flushID
    and Engine.buttons[tooltipOwner]
    and tooltipOwner.__puiActionActive
    and tooltipOwner.__puiHasAction
    and Core:ShouldShowActionTooltip()
  then
    tooltipOwner:SetTooltip()
  end
end

function Engine:FlushRuntimeUpdate()
  local refreshButtons = self.pendingButtonRefreshes
  self.pendingButtonRefreshes = self.flushingButtonRefreshes
  self.flushingButtonRefreshes = refreshButtons
  wipe(self.pendingButtonRefreshes)

  local iconButtons = self.pendingIconButtons
  self.pendingIconButtons = self.flushingIconButtons
  self.flushingIconButtons = iconButtons
  wipe(self.pendingIconButtons)

  local fullRefresh = self.pendingFullRefresh
  local cooldownRefresh = self.pendingCooldownRefresh
  local chargeRefresh = self.pendingChargeRefresh
  local lossOfControlRefresh = self.pendingLossOfControlRefresh
  local iconRefresh = self.pendingIconRefresh
  local equippedRefresh = self.pendingEquippedRefresh
  local usableRefresh = self.pendingUsableRefresh
  local stateRefresh = self.pendingStateRefresh
  local stateAndFlashRefresh = self.pendingStateAndFlashRefresh
  local assistedCombatRefresh = self.pendingAssistedCombatRefresh
  local combatFlash = self.pendingCombatFlash
  local autoRepeatFlash = self.pendingAutoRepeatFlash

  self.pendingFullRefresh = nil
  self.pendingCooldownRefresh = nil
  self.pendingChargeRefresh = nil
  self.pendingLossOfControlRefresh = nil
  self.pendingIconRefresh = nil
  self.pendingEquippedRefresh = nil
  self.pendingUsableRefresh = nil
  self.pendingStateRefresh = nil
  self.pendingStateAndFlashRefresh = nil
  self.pendingAssistedCombatRefresh = nil
  self.pendingCombatFlash = nil
  self.pendingAutoRepeatFlash = nil

  self.runtimeFlushID = self.runtimeFlushID + 1
  local flushID = self.runtimeFlushID

  if fullRefresh then
    for index = 1, #refreshButtons do
      refreshButtons[index].__puiRuntimeRefreshQueued = nil
    end
    for index = 1, #iconButtons do
      iconButtons[index].__puiRuntimeIconQueued = nil
    end
    wipe(refreshButtons)
    wipe(iconButtons)
    self:RefreshAllButtons()
    return
  end

  for index = 1, #refreshButtons do
    local button = refreshButtons[index]
    button.__puiRuntimeRefreshQueued = nil

    if button.__puiActionActive then
      self:RefreshButton(button)
      button.__puiRuntimeFlushID = flushID
    end
  end
  wipe(refreshButtons)

  if not iconRefresh then
    for index = 1, #iconButtons do
      local button = iconButtons[index]
      button.__puiRuntimeIconQueued = nil

      if button.__puiRuntimeFlushID ~= flushID and button.__puiHasAction then
        button.icon:SetTexture(C_ActionBar.GetActionTexture(button.action))
      end
    end
  else
    for index = 1, #iconButtons do
      iconButtons[index].__puiRuntimeIconQueued = nil
    end
  end
  wipe(iconButtons)

  local hasBroadRefresh = cooldownRefresh
    or chargeRefresh
    or lossOfControlRefresh
    or iconRefresh
    or equippedRefresh
    or usableRefresh
    or stateRefresh
    or stateAndFlashRefresh
    or assistedCombatRefresh
    or combatFlash ~= nil
    or autoRepeatFlash ~= nil

  if not hasBroadRefresh then
    return
  end

  for index = 1, #self.activeButtons do
    local button = self.activeButtons[index]
    if button.__puiRuntimeFlushID ~= flushID and button.__puiHasAction then
      if stateAndFlashRefresh then
        UpdateButtonStateAndFlash(button)
      elseif stateRefresh then
        button:UpdateState()
      end

      local refreshCheckedState = false
      local isAttack

      if combatFlash ~= nil then
        isAttack = C_ActionBar.IsAttackAction(button.action)
        if not issecretvalue(isAttack) and isAttack then
          if combatFlash then
            button:StartFlash(true)
          else
            button:StopFlash(true)
          end
          refreshCheckedState = true
        end
      end

      if autoRepeatFlash ~= nil then
        if autoRepeatFlash then
          local isAutoRepeat = C_ActionBar.IsAutoRepeatAction(button.action)
          if not issecretvalue(isAutoRepeat) and isAutoRepeat then
            button:StartFlash(true)
            refreshCheckedState = true
          end
        elseif button:IsFlashing() then
          if isAttack == nil then
            isAttack = C_ActionBar.IsAttackAction(button.action)
          end
          if not issecretvalue(isAttack) and not isAttack then
            button:StopFlash(true)
            refreshCheckedState = true
          end
        end
      end

      if refreshCheckedState and not stateAndFlashRefresh and not stateRefresh then
        button:UpdateState()
      end

      if usableRefresh then
        button:UpdateUsable()
      end

      if iconRefresh then
        button.icon:SetTexture(C_ActionBar.GetActionTexture(button.action))
      end

      if equippedRefresh then
        UpdateButtonEquipped(button)
      end

      if chargeRefresh then
        self:UpdateCount(button)
      end

      if cooldownRefresh or chargeRefresh or lossOfControlRefresh then
        UpdateButtonCooldown(button, chargeRefresh == true, lossOfControlRefresh == true)
      end

      if assistedCombatRefresh then
        button:UpdateAssistedCombatRotationFrame()
      end
    end
  end

  if cooldownRefresh or chargeRefresh or lossOfControlRefresh then
    RefreshCooldownTooltip(flushID)
  end
end

local function RuntimeUpdateOnUpdate(frame)
  frame:Hide()

  if Engine.enabled then
    Engine:FlushRuntimeUpdate()
  end
end

function Engine:UpdateProcGlow(spellID, shown)
  if issecretvalue(spellID) or spellID == nil then
    return
  end

  local buttons = self.spellEventButtons[spellID]
  if buttons then
    for buttonIndex = 1, #buttons do
      if shown then
        ActionButtonSpellAlertManager:ShowAlert(buttons[buttonIndex])
      else
        ActionButtonSpellAlertManager:HideAlert(buttons[buttonIndex])
      end
    end
  end

  for index = 1, #self.flyoutButtons do
    local button = self.flyoutButtons[index]
    local containsSpell = FlyoutHasSpell(button.__puiFlyoutID, spellID)
    if not issecretvalue(containsSpell) and containsSpell then
      if shown then
        ActionButtonSpellAlertManager:ShowAlert(button)
      else
        ActionButtonSpellAlertManager:HideAlert(button)
      end
    end
  end
end

function Engine:DispatchSpellCastVisual(event, ...)
  local spellID
  if event == "UNIT_SPELLCAST_SENT" then
    spellID = select(4, ...)
  else
    spellID = select(3, ...)
  end
  if issecretvalue(spellID) or spellID == nil then
    return
  end

  local actionSlots = C_ActionBar.FindSpellActionButtons(C_Spell.GetBaseSpell(spellID))
  if not actionSlots then
    return
  end

  for slotIndex = 1, #actionSlots do
    local buttons = self.actionSlotButtons[actionSlots[slotIndex]]
    if buttons then
      for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        if event == "UNIT_SPELLCAST_INTERRUPTED" then
          button:PlaySpellInterruptedAnim()
        elseif event == "UNIT_SPELLCAST_START" then
          button:PlaySpellCastAnim(ACTION_BUTTON_CAST_TYPE.Cast)
        elseif event == "UNIT_SPELLCAST_STOP" then
          button:StopSpellCastAnim(true, ACTION_BUTTON_CAST_TYPE.Cast)
          button:StopTargettingReticleAnim()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
          button:StopSpellCastAnim(false, ACTION_BUTTON_CAST_TYPE.Cast)
          button:StopTargettingReticleAnim()
        elseif event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_FAILED" then
          button:StopTargettingReticleAnim()
        elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
          button:PlaySpellCastAnim(ACTION_BUTTON_CAST_TYPE.Empowered)
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
          button:StopSpellCastAnim(false, ACTION_BUTTON_CAST_TYPE.Empowered)
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
          button:PlaySpellCastAnim(ACTION_BUTTON_CAST_TYPE.Channel)
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
          button:StopSpellCastAnim(false, ACTION_BUTTON_CAST_TYPE.Channel)
        elseif event == "UNIT_SPELLCAST_RETICLE_TARGET" then
          button:PlayTargettingReticleAnim()
        elseif event == "UNIT_SPELLCAST_RETICLE_CLEAR" then
          button:StopTargettingReticleAnim()
        end
      end
    end
  end
end

function Engine:OnEvent(event, arg1, arg2, ...)
  if event == "ACTIONBAR_SLOT_CHANGED" then
    self:QueueActionSlotRefresh(arg1)
  elseif event == "ACTION_RANGE_CHECK_UPDATE" then
    local buttons = self.actionSlotButtons[arg1]
    if buttons then
      for index = 1, #buttons do
        local button = buttons[index]
        if button.__puiRangeAction == arg1 then
          button:OnEvent(event, arg1, arg2, ...)
        end
      end
    end
  elseif event == "ACTION_USABLE_CHANGED" then
    self:RefreshUsable(arg1)
  elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
    self:QueueRuntimeUpdate("cooldown")
  elseif event == "SPELL_UPDATE_CHARGES" then
    self:QueueRuntimeUpdate("charges")
  elseif event == "SPELL_UPDATE_ICON" then
    self:QueueSpellActionRefresh(arg1)
  elseif event == "UPDATE_SHAPESHIFT_FORM" then
    self:QueueRuntimeUpdate("icons")
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    self:QueueRuntimeUpdate("equipped")
  elseif event == "START_AUTOREPEAT_SPELL" then
    self:QueueRuntimeUpdate("autoRepeatFlash", true)
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    self:QueueRuntimeUpdate("autoRepeatFlash", false)
  elseif event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
    self:QueueRuntimeUpdate("lossOfControl")
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    self:UpdateProcGlow(arg1, true)
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    self:UpdateProcGlow(arg1, false)
  elseif event == "UNIT_INVENTORY_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
    if Core:ShouldShowActionTooltip() and not GameTooltip:IsForbidden() then
      local tooltipOwner = GameTooltip:GetOwner()
      if tooltipOwner and self.buttons[tooltipOwner] then
        tooltipOwner:SetTooltip()
      end
    end
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    self:RefreshTooltipPolicy()
  elseif event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW" then
    self:QueueAllButtonRefresh()
  elseif event == "UPDATE_SUMMONPETS_ACTION" then
    self:QueueSummonPetIcons()
  elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    self:QueueRuntimeUpdate("usable")
  elseif event == "PET_BAR_UPDATE" or event == "UNIT_FLAGS" or event == "UNIT_AURA" then
    self:QueueRuntimeUpdate("stateAndFlash")
  elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
    self:QueueRuntimeUpdate("state")
  elseif event == "COMPANION_UPDATE" and arg1 == "MOUNT" then
    self:QueueRuntimeUpdate("state")
  elseif event == "PLAYER_ENTER_COMBAT" then
    self:QueueRuntimeUpdate("combatFlash", true)
  elseif event == "PLAYER_LEAVE_COMBAT" then
    self:QueueRuntimeUpdate("combatFlash", false)
  else
    self:DispatchSpellCastVisual(event, arg1, arg2, ...)
  end
end

function Engine:Enable()
  if self.enabled then
    return
  end
  self.enabled = true

  local frame = self.eventFrame
  if not frame then
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
      Engine:OnEvent(event, ...)
    end)
    self.eventFrame = frame
  end

  if not self.runtimeUpdateFrame then
    self.runtimeUpdateFrame = CreateFrame("Frame")
    self.runtimeUpdateFrame:SetScript("OnUpdate", RuntimeUpdateOnUpdate)
  end
  self.runtimeUpdateFrame:Hide()

  frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  frame:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
  frame:RegisterEvent("ACTION_USABLE_CHANGED")
  frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  frame:RegisterEvent("SPELL_UPDATE_CHARGES")
  frame:RegisterEvent("SPELL_UPDATE_ICON")
  frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  frame:RegisterEvent("START_AUTOREPEAT_SPELL")
  frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
  frame:RegisterUnitEvent("LOSS_OF_CONTROL_ADDED", "player")
  frame:RegisterUnitEvent("LOSS_OF_CONTROL_UPDATE", "player")
  frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  frame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
  frame:RegisterEvent("PET_STABLE_UPDATE")
  frame:RegisterEvent("PET_STABLE_SHOW")
  frame:RegisterEvent("UPDATE_SUMMONPETS_ACTION")
  frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  frame:RegisterEvent("PET_BAR_UPDATE")
  frame:RegisterUnitEvent("UNIT_FLAGS", "pet")
  frame:RegisterUnitEvent("UNIT_AURA", "pet")
  frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
  frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
  frame:RegisterEvent("COMPANION_UPDATE")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_ENTER_COMBAT")
  frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_RETICLE_TARGET", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_RETICLE_CLEAR", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")

  if not self.flashDriver then
    self.flashDriver = CreateFrame("Frame")
    self.flashDriver:SetScript("OnUpdate", FlashDriverOnUpdate)
  end
  self.flashDriver:Hide()

  EventRegistry:RegisterCallback("AssistedCombatManager.OnSetActionSpell", function()
    if Engine.enabled then
      Engine:QueueRuntimeUpdate("assisted")
    end
  end, self)
end

function Engine:Disable()
  if not self.enabled then
    return
  end

  self.enabled = false

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
  end

  EventRegistry:UnregisterCallback("AssistedCombatManager.OnSetActionSpell", self)

  for button in pairs(self.buttons) do
    self:UnregisterButtonRangeCheck(button)
    self:UnregisterButtonTopology(button)
    self:SyncActionUIButton(button, nil)
    button.__puiRuntimeRefreshQueued = nil
    button.__puiRuntimeIconQueued = nil
    button:StopFlash(true)
    ActionButtonSpellAlertManager:HideAlert(button)
  end

  if self.flashDriver then
    self.flashDriver:Hide()
  end

  if self.runtimeUpdateFrame then
    self.runtimeUpdateFrame:Hide()
  end

  wipe(self.flashingButtons)
  self.flashingButtonCount = 0
  self.flashTime = 0
  wipe(self.activeButtons)
  wipe(self.actionSlotButtons)
  wipe(self.rangeActionCounts)
  wipe(self.spellEventButtons)
  wipe(self.flyoutButtons)
  wipe(self.summonPetButtons)
  wipe(self.pendingButtonRefreshes)
  wipe(self.flushingButtonRefreshes)
  wipe(self.pendingIconButtons)
  wipe(self.flushingIconButtons)
  self.pendingFullRefresh = nil
  self.pendingCooldownRefresh = nil
  self.pendingChargeRefresh = nil
  self.pendingLossOfControlRefresh = nil
  self.pendingIconRefresh = nil
  self.pendingEquippedRefresh = nil
  self.pendingUsableRefresh = nil
  self.pendingStateRefresh = nil
  self.pendingStateAndFlashRefresh = nil
  self.pendingAssistedCombatRefresh = nil
  self.pendingCombatFlash = nil
  self.pendingAutoRepeatFlash = nil
end

Engine.CreateButton = P:Def("Engine:CreateButton", Engine.CreateButton)
Engine.ConfigureButton = P:Def("Engine:ConfigureButton", Engine.ConfigureButton)
Engine.UpdateButtonHotkey = P:Def("Engine:UpdateButtonHotkey", Engine.UpdateButtonHotkey)
Engine.SyncActionUIButton = P:Def("Engine:SyncActionUIButton", Engine.SyncActionUIButton)
Engine.RefreshButton = P:Def("Engine:RefreshButton", Engine.RefreshButton)
Engine.RefreshButtonContent = P:Def("Engine:RefreshButtonContent", Engine.RefreshButtonContent)
Engine.UnregisterButtonContent = P:Def("Engine:UnregisterButtonContent", Engine.UnregisterButtonContent)
Engine.RefreshTooltipPolicy = P:Def("Engine:RefreshTooltipPolicy", Engine.RefreshTooltipPolicy)
Engine.ApplyButtonSecureState = P:Def("Engine:ApplyButtonSecureState", Engine.ApplyButtonSecureState)
Engine.SetButtonAction = P:Def("Engine:SetButtonAction", Engine.SetButtonAction)
Engine.DeactivateButton = P:Def("Engine:DeactivateButton", Engine.DeactivateButton)
Engine.RegisterButtonTopology = P:Def("Engine:RegisterButtonTopology", Engine.RegisterButtonTopology)
Engine.UnregisterButtonTopology = P:Def("Engine:UnregisterButtonTopology", Engine.UnregisterButtonTopology)
Engine.RefreshUsable = P:Def("Engine:RefreshUsable", Engine.RefreshUsable)
Engine.RefreshAllButtons = P:Def("Engine:RefreshAllButtons", Engine.RefreshAllButtons)
Engine.QueueButtonRefresh = P:Def("Engine:QueueButtonRefresh", Engine.QueueButtonRefresh)
Engine.QueueButtonIcon = P:Def("Engine:QueueButtonIcon", Engine.QueueButtonIcon)
Engine.QueueAllButtonRefresh = P:Def("Engine:QueueAllButtonRefresh", Engine.QueueAllButtonRefresh)
Engine.QueueActionSlotRefresh = P:Def("Engine:QueueActionSlotRefresh", Engine.QueueActionSlotRefresh)
Engine.QueueSpellActionRefresh = P:Def("Engine:QueueSpellActionRefresh", Engine.QueueSpellActionRefresh)
Engine.QueueSummonPetIcons = P:Def("Engine:QueueSummonPetIcons", Engine.QueueSummonPetIcons)
Engine.QueueRuntimeUpdate = P:Def("Engine:QueueRuntimeUpdate", Engine.QueueRuntimeUpdate)
Engine.FlushRuntimeUpdate = P:Def("Engine:FlushRuntimeUpdate", Engine.FlushRuntimeUpdate)
Engine.UpdateProcGlow = P:Def("Engine:UpdateProcGlow", Engine.UpdateProcGlow)
Engine.DispatchSpellCastVisual = P:Def("Engine:DispatchSpellCastVisual", Engine.DispatchSpellCastVisual)
Engine.Enable = P:Def("Engine:Enable", Engine.Enable)
Engine.Disable = P:Def("Engine:Disable", Engine.Disable)

GetButtonSpellID = P:Def("ActionButton:GetButtonSpellID", GetButtonSpellID)
UpdateButtonState = P:Def("ActionButton:UpdateState", UpdateButtonState)
UpdateButtonStateAndFlash = P:Def("ActionButton:UpdateStateAndFlash", UpdateButtonStateAndFlash)
UpdateButtonUsable = P:Def("ActionButton:UpdateUsable", UpdateButtonUsable)
UpdateButtonSpellAlert = P:Def("ActionButton:UpdateSpellAlert", UpdateButtonSpellAlert)
UpdateButtonFlash = P:Def("ActionButton:UpdateFlash", UpdateButtonFlash)
UpdateButtonProfessionQuality = P:Def("ActionButton:UpdateProfessionQuality", UpdateButtonProfessionQuality)
UpdateButtonAssistedCombat = P:Def("ActionButton:UpdateAssistedCombat", UpdateButtonAssistedCombat)
UpdateButtonCooldown = P:Def("ActionButton:UpdateCooldown", UpdateButtonCooldown)
UpdateButtonEquipped = P:Def("ActionButton:UpdateEquipped", UpdateButtonEquipped)
OnEnter = P:Def("ActionButton:OnEnter", OnEnter)
OnLeave = P:Def("ActionButton:OnLeave", OnLeave)
OnShow = P:Def("ActionButton:OnShow", OnShow)
OnHide = P:Def("ActionButton:OnHide", OnHide)
OnEvent = P:Def("ActionButton:OnEvent", OnEvent)
PostClick = P:Def("ActionButton:PostClick", PostClick)
