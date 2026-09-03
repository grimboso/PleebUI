local ADDON_NAME, ns = ...

local Core = ns.ActionBarsCore
local Engine = ns.ActionButtonEngine

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local ClearOverrideBindings = ClearOverrideBindings
local SetOverrideBindingClick = SetOverrideBindingClick
local GetBindingKey = GetBindingKey
local hooksecurefunc = hooksecurefunc
local C_ActionBar = C_ActionBar
local ipairs = ipairs
local pairs = pairs
local select = select
local type = type
local tostring = tostring
local tonumber = tonumber

local StandardBars = {
  enabled = false,
  enabledBars = {},
  disabledBlizzardBindingSinks = {},
}
local P = select(1, ns.Pleebug:DropIn(StandardBars))

_G.BINDING_HEADER_PUI_EXTRA_ACTION_BARS = "PleebUI extra action bars"
for barNumber = 9, 12 do
  for buttonIndex = 1, 12 do
    _G["BINDING_NAME_PUIACTIONBAR" .. barNumber .. "BUTTON" .. buttonIndex] =
      "Action Bar " .. barNumber .. " Button " .. buttonIndex
  end
end

local BAR_DEFS = {
  {
    uiKey = "1",
    key = "main",
    frameName = "PUI_MainBar",
    moverKey = "ACTIONBAR_MAIN",
    label = "Primary Action Bar",
    page = 1,
    binding = "ACTIONBUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 100 },
  },
  {
    uiKey = "2",
    key = "bottomLeft",
    frameName = "PUI_BottomLeftBar",
    moverKey = "ACTIONBAR_BOTTOMLEFT",
    label = "Bottom Left Action Bar",
    page = 6,
    binding = "MULTIACTIONBAR1BUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 55 },
  },
  {
    uiKey = "3",
    key = "bottomRight",
    frameName = "PUI_BottomRightBar",
    moverKey = "ACTIONBAR_BOTTOMRIGHT",
    label = "Bottom Right Action Bar",
    page = 5,
    binding = "MULTIACTIONBAR2BUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 10 },
  },
  {
    uiKey = "4",
    key = "right",
    frameName = "PUI_RightBar",
    moverKey = "ACTIONBAR_RIGHT",
    label = "Right Action Bar",
    page = 3,
    binding = "MULTIACTIONBAR3BUTTON%d",
    defaultPoint = { "RIGHT", "PUI_MainBar", "LEFT", -10, 0 },
  },
  {
    uiKey = "5",
    key = "bar5",
    frameName = "PUI_Bar5",
    moverKey = "ACTIONBAR_5",
    label = "Action Bar 5",
    page = 4,
    binding = "MULTIACTIONBAR4BUTTON%d",
    defaultPoint = { "LEFT", "PUI_MainBar", "RIGHT", 10, 0 },
  },
  {
    uiKey = "6",
    key = "bar6",
    frameName = "PUI_Bar6",
    moverKey = "ACTIONBAR_6",
    label = "Action Bar 6",
    page = 13,
    binding = "MULTIACTIONBAR5BUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 160 },
  },
  {
    uiKey = "7",
    key = "bar7",
    frameName = "PUI_Bar7",
    moverKey = "ACTIONBAR_7",
    label = "Action Bar 7",
    page = 14,
    binding = "MULTIACTIONBAR6BUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 200 },
  },
  {
    uiKey = "8",
    key = "bar8",
    frameName = "PUI_Bar8",
    moverKey = "ACTIONBAR_8",
    label = "Action Bar 8",
    page = 15,
    binding = "MULTIACTIONBAR7BUTTON%d",
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 240 },
  },
  {
    uiKey = "9",
    key = "bar9",
    frameName = "PUI_Bar9",
    moverKey = "ACTIONBAR_9",
    label = "Action Bar 9",
    page = 7,
    binding = "PUIACTIONBAR9BUTTON%d",
    usesPleebBinding = true,
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 280 },
  },
  {
    uiKey = "10",
    key = "bar10",
    frameName = "PUI_Bar10",
    moverKey = "ACTIONBAR_10",
    label = "Action Bar 10",
    page = 8,
    binding = "PUIACTIONBAR10BUTTON%d",
    usesPleebBinding = true,
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 320 },
  },
  {
    uiKey = "11",
    key = "bar11",
    frameName = "PUI_Bar11",
    moverKey = "ACTIONBAR_11",
    label = "Action Bar 11",
    page = 9,
    binding = "PUIACTIONBAR11BUTTON%d",
    usesPleebBinding = true,
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 360 },
  },
  {
    uiKey = "12",
    key = "bar12",
    frameName = "PUI_Bar12",
    moverKey = "ACTIONBAR_12",
    label = "Action Bar 12",
    page = 10,
    binding = "PUIACTIONBAR12BUTTON%d",
    usesPleebBinding = true,
    defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 400 },
  },
}

local CUSTOM_MAIN_PAGE_DRIVER = table.concat({
  "[vehicleui][possessbar]vehicle",
  "[overridebar]override",
  "[shapeshift]shapeshift",
  "[bar:2]2",
  "[bar:3]3",
  "[bar:4]4",
  "[bar:5]5",
  "[bar:6]6",
  "[bonusbar:5]dragon",
  "[bonusbar:1][bonusbar:2][bonusbar:3][bonusbar:4]bonus",
  "1",
}, ";")

local BLIZZARD_VEHICLE_MAIN_PAGE_DRIVER = table.concat({
  "[possessbar]vehicle",
  "[shapeshift]shapeshift",
  "[bar:2]2",
  "[bar:3]3",
  "[bar:4]4",
  "[bar:5]5",
  "[bar:6]6",
  "[bonusbar:5]dragon",
  "[bonusbar:1][bonusbar:2][bonusbar:3][bonusbar:4]bonus",
  "1",
}, ";")

local CUSTOM_MAIN_SPECIAL_BINDING_DRIVER = "[petbattle]normal;[overridebar][vehicleui][possessbar][shapeshift][bonusbar:5]special;normal"
local BLIZZARD_VEHICLE_MAIN_SPECIAL_BINDING_DRIVER = "[petbattle]normal;[overridebar][vehicleui]blizzard;[possessbar][shapeshift][bonusbar:5]special;normal"

local function GetMainPageDriver()
  return Core.useBlizzardVehicleUI
    and BLIZZARD_VEHICLE_MAIN_PAGE_DRIVER
    or CUSTOM_MAIN_PAGE_DRIVER
end

local function GetMainSpecialBindingDriver()
  return Core.useBlizzardVehicleUI
    and BLIZZARD_VEHICLE_MAIN_SPECIAL_BINDING_DRIVER
    or CUSTOM_MAIN_SPECIAL_BINDING_DRIVER
end

local MAIN_PAGE_SNIPPET = [[
  local special = newstate == "vehicle"
    or newstate == "override"
    or newstate == "shapeshift"
    or newstate == "dragon"
  if newstate == "vehicle" then
    newstate = self:GetAttribute("pui-vehicle-page")
  elseif newstate == "override" then
    newstate = self:GetAttribute("pui-override-page")
  elseif newstate == "shapeshift" then
    newstate = self:GetAttribute("pui-temp-shapeshift-page")
  elseif newstate == "dragon" then
    newstate = 11
  elseif newstate == "bonus" then
    if HasBonusActionBar() then
      newstate = GetBonusBarIndex()
    else
      newstate = 1
    end
  end

  self:SetAttribute("pui-special-state", special)
  local width = self:GetAttribute(special and "pui-special-width" or "pui-normal-width")
  local height = self:GetAttribute(special and "pui-special-height" or "pui-normal-height")
  if width and height then
    self:SetWidth(width)
    self:SetHeight(height)
  end

  self:ChildUpdate("specialstate", special and "1" or "0")
  self:SetAttribute("state", newstate)
  self:SetAttribute("actionpage", newstate)
  self:ChildUpdate("state", newstate)
]]

local MAIN_SPECIAL_BINDING_SNIPPET = [[
  self:ClearBindings()

  if newstate == "special" then
    for index = 1, 12 do
      local nativeBinding = ("ACTIONBUTTON%d"):format(index)
      local targetButton = ("PUI_ActionButton%d"):format(index)

      for keyIndex = 1, select("#", GetBindingKey(nativeBinding)) do
        local key = select(keyIndex, GetBindingKey(nativeBinding))
        if key then
          self:SetBindingClick(true, key, targetButton, "LeftButton")
        end
      end
    end
  elseif newstate == "blizzard" then
    for index = 1, 6 do
      local nativeBinding = ("ACTIONBUTTON%d"):format(index)
      local targetButton = ("OverrideActionBarButton%d"):format(index)

      for keyIndex = 1, select("#", GetBindingKey(nativeBinding)) do
        local key = select(keyIndex, GetBindingKey(nativeBinding))
        if key then
          self:SetBindingClick(true, key, targetButton, "LeftButton")
        end
      end
    end
  end
]]

local function LoadEnabledState(def)
  if def.uiKey == "1" then
    StandardBars.enabledBars[def.uiKey] = true
    return true
  end

  local barDB = Core:GetDB().bars[def.uiKey]
  local enabled = barDB and barDB.enabled ~= false or false
  StandardBars.enabledBars[def.uiKey] = enabled
  return enabled
end

local function IsEnabled(def)
  local enabled = StandardBars.enabledBars[def.uiKey]
  if enabled == nil then
    return def.uiKey == "1" or def.uiKey == "2" or def.uiKey == "3"
  end
  return enabled
end

local function GetCurrentMainPage(bar)
  return tonumber(bar.frame:GetAttribute("state")) or 1
end

local function UpdateBarActionStates(bar, def, visibleButtonCount)
  local barEnabled = IsEnabled(def)
  local activeButtonCount = barEnabled and visibleButtonCount or 0
  local page = def.uiKey == "1" and GetCurrentMainPage(bar) or def.page
  local buttonOffset = Core:GetDB().bars[def.uiKey].buttonOffset

  for buttonIndex, button in ipairs(bar.buttons) do
    local normalVisible = buttonIndex <= activeButtonCount
    local active = normalVisible
    local actionButtonIndex = ((buttonIndex + buttonOffset - 1) % 12) + 1
    if def.uiKey == "1" then
      button.__puiActionButtonIndex = actionButtonIndex
      button:SetAttribute("pui-button-index", actionButtonIndex)
      button:SetAttribute("pui-normal-visible", normalVisible)
      active = barEnabled
    end
    Engine:SetButtonAction(
      button,
      active and (((page - 1) * 12) + actionButtonIndex) or nil,
      active,
      "standard"
    )
  end
end

local function ApplyBarFlyoutDirection(bar, def)
  local direction = Core:GetDB().bars[def.uiKey].flyoutDirection
  for _, button in ipairs(bar.buttons) do
    button:SetAttribute("flyoutDirection", direction)
    button:UpdateFlyout()
  end
end

local function CreateButtons(bar, def, barIndex)
  if #bar.buttons > 0 then
    return
  end

  for buttonIndex = 1, 12 do
    local absoluteID = ((barIndex - 1) * 12) + buttonIndex
    local buttonName = "PUI_ActionButton" .. tostring(absoluteID)
    local button = Engine:CreateButton(buttonName, bar.frame)
    button.__puiStandardBarKey = def.uiKey
    button.__puiStandardButtonIndex = buttonIndex

    if def.uiKey == "1" then
      button:SetAttribute("pui-paged", true)
      button:SetAttribute("pui-button-index", buttonIndex)
      button:SetAttribute("pui-special-page-button", true)
      button:SetAttribute("pui-normal-visible", false)
    end

    bar.buttons[buttonIndex] = button
  end
end

local function DeactivateBarButtons(bar)
  if not bar then
    return
  end

  for _, button in ipairs(bar.buttons) do
    Engine:DeactivateButton(button)
  end
end

local function RefreshMainSpecialBindings(bar, def)
  if def.uiKey ~= "1" or not bar.specialBindingController then
    return
  end

  local controller = bar.specialBindingController
  UnregisterStateDriver(controller, "specialbindings")
  controller:Execute([[ self:ClearBindings() ]])
  bar.specialBindingDriverRegistered = nil

  if not StandardBars.inHousingEditor and IsEnabled(def) then
    local driver = GetMainSpecialBindingDriver()
    RegisterStateDriver(controller, "specialbindings", driver)
    bar.specialBindingDriver = driver
    bar.specialBindingDriverRegistered = true
  end
end

local function ConfigurePaging(bar, def)
  if def.uiKey ~= "1" then
    return
  end

  if not bar.pageSnippetConfigured then
    -- Resolve Midnight action pages before the restricted state transition.
    bar.frame:SetAttribute("pui-vehicle-page", C_ActionBar.GetVehicleBarIndex())
    bar.frame:SetAttribute("pui-override-page", C_ActionBar.GetOverrideBarIndex())
    bar.frame:SetAttribute("pui-temp-shapeshift-page", C_ActionBar.GetTempShapeshiftBarIndex())
    bar.frame:SetAttributeNoHandler("_onstate-page", MAIN_PAGE_SNIPPET)
    bar.pageSnippetConfigured = true
  end

  local driver = GetMainPageDriver()
  if bar.pageDriver ~= driver then
    UnregisterStateDriver(bar.frame, "page")
    RegisterStateDriver(bar.frame, "page", driver)
    bar.pageDriver = driver
    bar.pageDriverRegistered = true
  end

  if not bar.specialBindingController then
    local controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    controller:SetAttribute("_onstate-specialbindings", MAIN_SPECIAL_BINDING_SNIPPET)
    bar.specialBindingController = controller
  end

  if not bar.specialBindingDriverRegistered then
    RefreshMainSpecialBindings(bar, def)
  end
end

local function CreateBar(def, barIndex)
  local bar = Core:CreateBar(
    def.key,
    def.frameName,
    def.moverKey,
    def.label,
    def.defaultPoint,
    def.uiKey
  )

  bar.definition = def
  bar.enabled = function()
    return IsEnabled(def)
  end

  CreateButtons(bar, def, barIndex)
  Core:AttachAlphaHandlers(bar)
  return bar
end

function StandardBars:EnsurePetBattleController()
  if self.petBattleController then
    if not self.petBattleDriverRegistered then
      RegisterStateDriver(self.petBattleController, "petbattle", "[petbattle]petbattle;nopetbattle")
      self.petBattleDriverRegistered = true
    end
    return
  end

  local controller = CreateFrame("Frame", "PUI_ActionBarsPetBattleController", UIParent, "SecureHandlerStateTemplate")
  controller:SetAttribute("_onstate-petbattle", [[
    if newstate == "petbattle" then
      for index = 1, 6 do
        local nativeBinding = ("ACTIONBUTTON%d"):format(index)
        for keyIndex = 1, select("#", GetBindingKey(nativeBinding)) do
          local key = select(keyIndex, GetBindingKey(nativeBinding))
          if key then
            self:SetBinding(true, key, nativeBinding)
          end
        end
      end
    else
      self:ClearBindings()
    end
  ]])
  RegisterStateDriver(controller, "petbattle", "[petbattle]petbattle;nopetbattle")
  self.petBattleController = controller
  self.petBattleDriverRegistered = true
end

local function GetVisibilityDriver(def)
  if not IsEnabled(def) then
    return "hide"
  end

  local visibility = Core:GetDB().bars[def.uiKey].visibility
  if visibility.alwaysHidden then
    return "hide"
  end

  local driver = { "[petbattle]hide" }
  if Core.useBlizzardVehicleUI then
    driver[#driver + 1] = "[overridebar][vehicleui]hide"
  end
  if def.uiKey ~= "1" and visibility.hideWithPossess then
    driver[#driver + 1] = "[possessbar][shapeshift]hide"
  end
  if visibility.hideInCombat then
    driver[#driver + 1] = "[combat]hide"
  end
  if visibility.hideOutOfCombat then
    driver[#driver + 1] = "[nocombat]hide"
  end
  if visibility.hideWithPet then
    driver[#driver + 1] = "[pet]hide"
  end
  if visibility.hideWithoutPet then
    driver[#driver + 1] = "[nopet]hide"
  end
  if visibility.hideWithVehicle then
    driver[#driver + 1] = "[target=vehicle,exists]hide"
  end
  if visibility.hideWithVehicleUI then
    driver[#driver + 1] = "[vehicleui]hide"
  end
  if visibility.hideWithOverride then
    driver[#driver + 1] = "[overridebar]hide"
  end
  driver[#driver + 1] = "show"
  return table.concat(driver, ";")
end

local function MatchesBar(def, barKey)
  return not barKey or def.uiKey == barKey
end

local function UpdateDisabledBlizzardBindings(def)
  if def.usesPleebBinding then
    return
  end

  local sink = StandardBars.disabledBlizzardBindingSinks[def.uiKey]
  if sink then
    ClearOverrideBindings(sink)
  end

  if not StandardBars.enabled or StandardBars.inHousingEditor or IsEnabled(def) then
    return
  end

  for buttonIndex = 1, 12 do
    local bindingAction = def.binding:format(buttonIndex)
    local keyCount = select("#", GetBindingKey(bindingAction))
    for keyIndex = 1, keyCount do
      local key = select(keyIndex, GetBindingKey(bindingAction))
      if key and key ~= "" then
        if not sink then
          sink = CreateFrame(
            "Button",
            "PUI_DisabledActionBar" .. def.uiKey .. "BindingSink",
            UIParent,
            "SecureActionButtonTemplate"
          )
          sink:SetAttribute("type", "empty")
          sink:Hide()
          StandardBars.disabledBlizzardBindingSinks[def.uiKey] = sink
        end
        SetOverrideBindingClick(sink, false, key, sink:GetName(), "LeftButton")
      end
    end
  end
end

local function UpdateBarBindings(def)
  UpdateDisabledBlizzardBindings(def)

  local bar = Core.bars[def.key]
  if not bar then
    return
  end

  if StandardBars.inHousingEditor or not IsEnabled(def) then
    ClearOverrideBindings(bar.frame)
  else
    Core:ReassignBarBindings(bar, def.binding)
  end

  RefreshMainSpecialBindings(bar, def)

  for _, button in ipairs(bar.buttons) do
    Engine:UpdateButtonHotkey(button)
  end
end


function StandardBars:RefreshButtonConfiguration(flags, barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      local skin = Core:GetEffectiveSkin(def.uiKey, 35)
      for buttonIndex, button in ipairs(bar.buttons) do
        if flags.cvars then
          Engine:ConfigureButton(button, def.binding:format(buttonIndex), def.label, buttonIndex)
          Engine:RefreshButton(button)
        end
        if flags.fonts then
          Core:ApplyButtonAppearance(button, skin)
        end
      end
    end
  end
end

function StandardBars:RefreshSkin(barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      local skin = Core:GetEffectiveSkin(def.uiKey, 35)
      for _, button in ipairs(bar.buttons) do
        Core:ApplyButtonAppearance(button, skin)
      end
      Core:ApplyBackdrop(bar, skin)
    end
  end
end

function StandardBars:RefreshLayout(barKey)
  local actionMappingChanged = false

  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      local previousButtonCount = bar.visibleButtonCount
      local skin = Core:GetEffectiveSkin(def.uiKey, 35)
      Core:LayoutButtons(
        bar,
        skin,
        skin.iconsPerBar,
        skin.iconsPerRow,
        def.uiKey == "1" and #bar.buttons or nil
      )
      UpdateBarActionStates(bar, def, bar.visibleButtonCount)
      if bar.visibleButtonCount ~= previousButtonCount then
        actionMappingChanged = true
      end
    end
  end

  if actionMappingChanged then
    ns.Modules.CooldownManager.RefreshKeybinds(nil)
  end
end

function StandardBars:RefreshActions(barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      UpdateBarActionStates(bar, def, bar.visibleButtonCount or #bar.buttons)
    end
  end
  ns.Modules.CooldownManager.RefreshKeybinds(nil)
end

function StandardBars:RefreshFlyouts(barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      ApplyBarFlyoutDirection(bar, def)
    end
  end
end

function StandardBars:RefreshVisibilityDriver(barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      Core:SetBarVisibilityDriver(bar, GetVisibilityDriver(def))
    end
  end
end

function StandardBars:RefreshVisibility(barKey)
  self:RefreshActions(barKey)
  self:RefreshVisibilityDriver(barKey)
end

function StandardBars:RefreshAlpha(barKey)
  for _, def in ipairs(BAR_DEFS) do
    local bar = MatchesBar(def, barKey) and Core.bars[def.key]
    if bar then
      Core:RefreshBarAlpha(bar, false)
    end
  end
end

function StandardBars:RefreshFull(barKey)
  self.enabled = true
  self:EnsurePetBattleController()
  self:RegisterHousingCallback()
  self:InstallFlyoutHook()

  for _, def in ipairs(BAR_DEFS) do
    if MatchesBar(def, barKey) then
      LoadEnabledState(def)
    end
  end

  for barIndex, def in ipairs(BAR_DEFS) do
    if MatchesBar(def, barKey) then
      local bar = Core.bars[def.key]
      if bar or IsEnabled(def) then
        bar = CreateBar(def, barIndex)
        local skin = Core:GetEffectiveSkin(def.uiKey, 35)

        for buttonIndex, button in ipairs(bar.buttons) do
          Engine:ConfigureButton(button, def.binding:format(buttonIndex), def.label, buttonIndex)
          Core:ApplyButtonAppearance(button, skin)
        end

        ApplyBarFlyoutDirection(bar, def)
        ConfigurePaging(bar, def)
        Core:LayoutButtons(
          bar,
          skin,
          skin.iconsPerBar,
          skin.iconsPerRow,
          def.uiKey == "1" and #bar.buttons or nil
        )
        UpdateBarActionStates(bar, def, bar.visibleButtonCount)
        Core:ApplyBackdrop(bar, skin)
        Core:SetBarVisibilityDriver(bar, GetVisibilityDriver(def))
        Core:RegisterMover(bar)
        Core:RefreshBarAlpha(bar, false)
      end
    end
  end

  if barKey then
    for _, def in ipairs(BAR_DEFS) do
      if def.uiKey == barKey then
        UpdateBarBindings(def)
        break
      end
    end
    if barKey == "1" then
      self:SkinFlyoutButtons()
    end
  else
    self:UpdateBindings()
    self:SkinFlyoutButtons()
  end

  ns.Modules.CooldownManager.RefreshKeybinds(nil)
end

function StandardBars:RefreshBar(barKey, flags)
  flags = type(flags) == "table" and flags or { full = true }
  if InCombatLockdown() then
    Core:QueueRefresh({ bars = { [barKey] = flags } })
    return
  end

  local def
  for _, candidate in ipairs(BAR_DEFS) do
    if candidate.uiKey == barKey then
      def = candidate
      break
    end
  end
  if not def then return end

  LoadEnabledState(def)
  local bar = Core.bars[def.key]
  if not bar then
    if IsEnabled(def) then self:RefreshFull(barKey) end
    return
  end

  if flags.full then self:RefreshFull(barKey); return end
  if flags.cvars or flags.fonts then self:RefreshButtonConfiguration(flags, barKey) end
  if flags.skin then self:RefreshSkin(barKey) end
  if flags.layout then self:RefreshLayout(barKey) end
  if flags.actions then self:RefreshActions(barKey) end
  if flags.flyouts then self:RefreshFlyouts(barKey) end
  if flags.visibilityDriver then self:RefreshVisibilityDriver(barKey) end
  if flags.visibility then self:RefreshVisibility(barKey) end
  if flags.alpha then self:RefreshAlpha(barKey) end
  if flags.bindings or flags.visibility then UpdateBarBindings(def) end
  if barKey == "1" and (flags.skin or flags.fonts) then self:SkinFlyoutButtons() end
end

function StandardBars:Refresh(flags)
  flags = type(flags) == "table" and flags or { full = true }
  if InCombatLockdown() then
    Core:QueueRefresh(flags)
    return
  end

  if flags.full then self:RefreshFull(); return end
  if flags.cvars or flags.fonts then self:RefreshButtonConfiguration(flags) end
  if flags.skin then self:RefreshSkin() end
  if flags.layout then self:RefreshLayout() end
  if flags.actions then self:RefreshActions() end
  if flags.flyouts then self:RefreshFlyouts() end
  if flags.visibilityDriver then self:RefreshVisibilityDriver() end
  if flags.visibility then self:RefreshVisibility() end
  if flags.alpha then self:RefreshAlpha() end
  if flags.bindings then self:UpdateBindings() end
  if flags.skin or flags.fonts then self:SkinFlyoutButtons() end
end

function StandardBars:RefreshDeferred(pending)
  if not self.enabled or not pending.actionButtons then
    return
  end

  for _, def in ipairs(BAR_DEFS) do
    local bar = Core.bars[def.key]
    if bar then
      for _, button in ipairs(bar.buttons) do
        Engine:RefreshButton(button)
      end
    end
  end
end

function StandardBars:ReconcileWorldState()
  if not self.enabled then
    return
  end
  Engine:RefreshAllButtons()
  self:UpdateBindings()
end

function StandardBars:InstallFlyoutHook()
  if self.flyoutHookInstalled then return end
  local flyout = _G.SpellFlyout
  if not flyout or not flyout.Toggle then return end

  hooksecurefunc(flyout, "Toggle", function()
    if StandardBars.enabled then StandardBars:SkinFlyoutButtons() end
  end)
  self.flyoutHookInstalled = true
end

function StandardBars:SkinFlyoutButtons()
  local skin = Core:GetEffectiveSkin("1", 35)
  local index = 1
  while true do
    local button = _G["SpellFlyoutPopupButton" .. index]
    if not button then break end
    Core:ApplyButtonAppearance(button, skin)
    index = index + 1
  end
end

function StandardBars:RegisterHousingCallback()
  if self.housingCallbackRegistered then return end
  EventRegistry:RegisterCallback("HouseEditor.StateUpdated", function(_, state)
    StandardBars:HandleHousingState(state)
  end, self)
  self.housingCallbackRegistered = true
end

function StandardBars:HandleHousingState(state)
  self.inHousingEditor = state and true or false
  if self.inHousingEditor then
    if self.petBattleController then self.petBattleController:Execute([[ self:ClearBindings() ]]) end
    for _, def in ipairs(BAR_DEFS) do
      UpdateDisabledBlizzardBindings(def)
      local bar = Core.bars[def.key]
      if bar then
        RefreshMainSpecialBindings(bar, def)
        ClearOverrideBindings(bar.frame)
      end
    end
  else
    self:UpdateBindings()
  end
end

function StandardBars:UpdateBindings()
  if not self.enabled or self.inHousingEditor or InCombatLockdown() then return end

  for _, def in ipairs(BAR_DEFS) do
    UpdateBarBindings(def)
  end
end

function StandardBars:Disable()
  self.enabled = false

  if self.housingCallbackRegistered then
    EventRegistry:UnregisterCallback("HouseEditor.StateUpdated", self)
    self.housingCallbackRegistered = nil
    self.inHousingEditor = nil
  end

  if self.petBattleController then
    UnregisterStateDriver(self.petBattleController, "petbattle")
    self.petBattleDriverRegistered = nil
    self.petBattleController:Execute([[ self:ClearBindings() ]])
  end

  for _, sink in pairs(self.disabledBlizzardBindingSinks) do
    ClearOverrideBindings(sink)
  end

  for _, def in ipairs(BAR_DEFS) do
    local bar = Core.bars[def.key]
    if bar then
      DeactivateBarButtons(bar)
      ClearOverrideBindings(bar.frame)
      UnregisterStateDriver(bar.frame, "visibility")
      bar.visibilityDriver = nil
      if def.uiKey == "1" then
        UnregisterStateDriver(bar.frame, "page")
        bar.pageDriverRegistered = nil
        bar.pageDriver = nil
        if bar.specialBindingController then
          UnregisterStateDriver(bar.specialBindingController, "specialbindings")
          bar.specialBindingController:Execute([[ self:ClearBindings() ]])
          bar.specialBindingDriverRegistered = nil
          bar.specialBindingDriver = nil
        end
      end
      bar.frame:Hide()
    end
  end

  ns.Modules.CooldownManager.RefreshKeybinds(nil)
end

StandardBars.EnsurePetBattleController = P:Def("StandardBars:EnsurePetBattleController", StandardBars.EnsurePetBattleController)
StandardBars.RefreshButtonConfiguration = P:Def("StandardBars:RefreshButtonConfiguration", StandardBars.RefreshButtonConfiguration)
StandardBars.RefreshBar = P:Def("StandardBars:RefreshBar", StandardBars.RefreshBar)
StandardBars.RefreshSkin = P:Def("StandardBars:RefreshSkin", StandardBars.RefreshSkin)
StandardBars.RefreshLayout = P:Def("StandardBars:RefreshLayout", StandardBars.RefreshLayout)
StandardBars.RefreshActions = P:Def("StandardBars:RefreshActions", StandardBars.RefreshActions)
StandardBars.RefreshFlyouts = P:Def("StandardBars:RefreshFlyouts", StandardBars.RefreshFlyouts)
StandardBars.RefreshVisibilityDriver = P:Def("StandardBars:RefreshVisibilityDriver", StandardBars.RefreshVisibilityDriver)
StandardBars.RefreshVisibility = P:Def("StandardBars:RefreshVisibility", StandardBars.RefreshVisibility)
StandardBars.RefreshAlpha = P:Def("StandardBars:RefreshAlpha", StandardBars.RefreshAlpha)
StandardBars.RefreshFull = P:Def("StandardBars:RefreshFull", StandardBars.RefreshFull)
StandardBars.Refresh = P:Def("StandardBars:Refresh", StandardBars.Refresh)
StandardBars.RefreshDeferred = P:Def("StandardBars:RefreshDeferred", StandardBars.RefreshDeferred)
StandardBars.ReconcileWorldState = P:Def("StandardBars:ReconcileWorldState", StandardBars.ReconcileWorldState)
StandardBars.InstallFlyoutHook = P:Def("StandardBars:InstallFlyoutHook", StandardBars.InstallFlyoutHook)
StandardBars.SkinFlyoutButtons = P:Def("StandardBars:SkinFlyoutButtons", StandardBars.SkinFlyoutButtons)
StandardBars.RegisterHousingCallback = P:Def("StandardBars:RegisterHousingCallback", StandardBars.RegisterHousingCallback)
StandardBars.HandleHousingState = P:Def("StandardBars:HandleHousingState", StandardBars.HandleHousingState)
StandardBars.UpdateBindings = P:Def("StandardBars:UpdateBindings", StandardBars.UpdateBindings)
StandardBars.Disable = P:Def("StandardBars:Disable", StandardBars.Disable)
GetVisibilityDriver = P:Def("GetVisibilityDriver", GetVisibilityDriver)
LoadEnabledState = P:Def("LoadEnabledState", LoadEnabledState)
IsEnabled = P:Def("IsEnabled", IsEnabled)
GetCurrentMainPage = P:Def("GetCurrentMainPage", GetCurrentMainPage)
GetMainPageDriver = P:Def("GetMainPageDriver", GetMainPageDriver)
GetMainSpecialBindingDriver = P:Def("GetMainSpecialBindingDriver", GetMainSpecialBindingDriver)
UpdateBarActionStates = P:Def("UpdateBarActionStates", UpdateBarActionStates)
ApplyBarFlyoutDirection = P:Def("ApplyBarFlyoutDirection", ApplyBarFlyoutDirection)
CreateButtons = P:Def("CreateButtons", CreateButtons)
DeactivateBarButtons = P:Def("DeactivateBarButtons", DeactivateBarButtons)
RefreshMainSpecialBindings = P:Def("RefreshMainSpecialBindings", RefreshMainSpecialBindings)
ConfigurePaging = P:Def("ConfigurePaging", ConfigurePaging)
CreateBar = P:Def("CreateBar", CreateBar)
MatchesBar = P:Def("MatchesBar", MatchesBar)
UpdateDisabledBlizzardBindings = P:Def("UpdateDisabledBlizzardBindings", UpdateDisabledBlizzardBindings)
UpdateBarBindings = P:Def("UpdateBarBindings", UpdateBarBindings)
Core:RegisterSubsystem("standard", StandardBars)
