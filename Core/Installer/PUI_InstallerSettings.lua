local _, ns = ...

local Settings = {}
ns.InstallerSettings = Settings

local Addon = ns.Addon
local AceGUI = LibStub("AceGUI-3.0")
local Registry = LibStub("AceConfigRegistry-3.0")
local Dialog = LibStub("AceConfigDialog-3.0")
local APP = "PleebUIInstallerSettings"
local active
local callbacks
local queued
local rebuildSettings
local BindControls
local bindings = setmetatable({}, { __mode = "k" })
local CONTROL_EVENTS = { "OnValueChanged", "OnClick", "OnEnterPressed", "OnKeyChanged", "OnMouseUp", "OnValueConfirmed", "OnClosed" }

local function Sanitize(options)
  for key in pairs(options) do
    if type(key) == "string" and key:match("^__pui") then options[key] = nil end
  end
  if (options.type == "select" or options.type == "multiselect") and options.values == nil then options.values = {} end
  for _, child in pairs(options.args or {}) do Sanitize(child) end
end

local function SkinSettings()
  local values = {}
  for key, value in pairs(Addon.db.profile.pui.blizzardSkins) do values[#values + 1] = tostring(key) .. "=" .. tostring(value) end
  table.sort(values)
  return table.concat(values, ";")
end

local function QueueRefresh(rebuild)
  rebuildSettings = rebuildSettings or rebuild
  if queued then return end
  queued = true
  local panel = active
  C_Timer.After(0, function()
    queued = nil
    local rebuild = rebuildSettings
    rebuildSettings = nil
    if active ~= panel or not panel or not panel:IsVisible() or InCombatLockdown() then return end
    if panel.skinSettings ~= SkinSettings() then callbacks.requireReload(); panel.skinSettings = SkinSettings() end
    if rebuild then
      Settings.Show(panel, panel.path)
      ns.KeyboardNavigation.QueueRestore()
    else BindControls(panel.widget) end
    ns.InstallerPreview.SetSettingsPath(panel.path)
    callbacks.changed()
    ns.InstallerPreview.Refresh()
  end)
end

BindControls = function(widget)
  for _, child in ipairs(widget.children or {}) do
    local bound = bindings[child]
    if not bound then bound = {}; bindings[child] = bound end
    for _, event in ipairs(CONTROL_EVENTS) do
      local original = child.events and child.events[event]
      if original and original ~= bound[event] then
        local callback = function(control, name, ...)
          if InCombatLockdown() then return end
          original(control, name, ...)
          QueueRefresh(false)
        end
        bound[event] = callback
        child:SetCallback(event, callback)
      end
    end
    BindControls(child)
  end
end

local UNIT_CONTROLS = {
  { "layout/size/width", "Frame width" }, { "layout/size/height", "Frame height" },
  { "layout/power/hidePower", "Hide power" }, { "text/health/mode", "Health text" },
  { "layout/health/useClassColor", "Class colors", optional = true },
}
local AURA_CONTROLS = {
  { "overview/display/enabled", "Show this aura display" },
  { "overview/iconSize/iconSize", "Icon size", optional = true },
  { "overview/layout/maxIcons", "Maximum auras", optional = true },
  { "overview/display/showDefensives", "Show defensives", optional = true },
  { "overview/display/showExternals", "Show externals", optional = true },
}
local BAR_CONTROLS = {
  { "layout/arrangement/iconSize", "Button size" },
  { "layout/arrangement/iconSpacing", "Button spacing" },
  { "layout/arrangement/iconsPerRow", "Buttons per row", optional = true },
  { "text/hotkey/showText", "Show keybinds" },
}
local NATIVE_RESOURCE_CONTROLS = {
  { "feature/enabled", "Show this bar" }, { "layoutGroup/height", "Bar height" },
  { "textGroup/percentVisibility", "Show percent" }, { "textGroup/valueVisibility", "Show value" },
}
local RESOURCE_CONTROLS = {
  { "feature/enabled", "Enable this resource" }, { "feature/visibility", "Show bar" },
  { "layout/height", "Bar height" },
  { "textGroup/textMode", "Resource text", optional = true },
  { "display/showIconCount", "Show count on spell icons", optional = true },
}
local ROOT_CONTROLS = {
  Accessibility = {
    { "textSize/optionsWindow/textSize", "Options text size" },
    { "textSize/optionsWindow/scale", "Options window scale" },
    { "controls/keyboardNavigation", "Keyboard navigation" },
    { "controls/largerPointerTargets", "Larger pointer targets" },
    { "controls/animateOptions", "Animate options", optional = true },
  },
  UITheme = {
    { "text/global/font", "Global font" }, { "text/global/outline", "Global outline" },
    { "layout/uiScale/UIScale", "Game UI scale (all characters)" },
  },
  Chat = {
    { "general/features/enabled", "Enable chat styling" },
    { "general/features/timestamps", "Show timestamps" },
    { "appearance/message/fontSize", "Message text size", optional = true },
  },
  Minimap = {
    { "minimap/enabled", "Enable minimap styling" }, { "minimap/size", "Minimap size" },
    { "clock/hideClock", "Hide clock" }, { "coordinates/clockBoxShowCoords", "Show coordinates" },
  },
  PLAYER_BUFFS = {
    { "general/enabled", "Enable player buffs and debuffs" },
    { "buffs/iconSize", "Buff icon size" }, { "debuffs/iconSize", "Debuff icon size" },
  },
  BlizzardWindows = { { "enabled", "Skin Blizzard windows" }, { "Bags/ContainerFrameCombinedBags", "Skin bags", optional = true } },
  Dragonriding = {
    { "general/enabled", "Enable skyriding display" }, { "vigor/width", "Bar width" },
    { "vigor/height", "Bar height" }, { "general/showSpeedText", "Show speed" },
  },
  MovementWarning = { { "general/enabled", "Show movement reminders" } },
}

local function ResolveOption(source, path)
  local node = source
  for _, key in ipairs(path) do
    node = node.args[key]
    if not node then return end
  end
  return node
end

local function FindPCMControl(node, field, prefix)
  local keys = {}
  for key in pairs(node.args or {}) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local option = node.args[key]
    local path = CopyTable(prefix)
    path[#path + 1] = key
    if option.type ~= "group" and (key == field or key:sub(-#field - 1) == "_" .. field) then
      return path
    elseif option.type == "group" and key ~= "entries" and key ~= "slots" then
      local found = FindPCMControl(option, field, path)
      if found then return found end
    end
  end
end

local function LessonControls(path, node)
  if path[1] == "unitframes" then
    if path[4] == "customDisplays" then return AURA_CONTROLS end
    if path[2] == "party" or path[2] == "raid" then
      return {
        { "layout/core/enabled", "Enable group frames (reload required)" },
        { "layout/size/width", "Frame width" }, { "layout/size/height", "Frame height" },
        { path[2] == "party" and "layout/arrangement/spacing" or "layout/arrangement/rowSpacing", "Frame spacing" },
        { "layout/health/useClassColor", "Class colors" },
      }
    end
    return UNIT_CONTROLS
  elseif path[1] == "ACTIONBARS" then
    local definitions = CopyTable(BAR_CONTROLS)
    if path[2] == "general" then
      definitions[4][1] = "fonts/hotkey/showText"
    elseif path[2] == "special" then
      table.insert(definitions, 1, { "general/useCustom", "Customize this bar" })
    else
      table.insert(definitions, 1, { "general/group/useCustom", "Customize this bar" })
      table.insert(definitions, 1, { "general/group/enableBar", "Enable this bar" })
    end
    return definitions
  elseif path[1] == "PRD" then
    return path[2] == "resources" and RESOURCE_CONTROLS or NATIVE_RESOURCE_CONTROLS
  elseif path[1] == "CooldownManager" then
    local definitions = {}
    local fields = path[2] == "consumables"
      and { { "enabled", "Show items and racials" }, { "onlyOnUseTrinkets", "Only on-use trinkets" }, { "iconSize", "Icon size" }, { "showCountdown", "Show countdown" } }
      or { { "iconSize", "Icon size" }, { "iconSpacing", "Icon spacing" }, { "iconsPerRow", "Icons per row" },
        { "spacing", "Spacing" }, { "columns", "Icons per row" }, { "countCooldown", "Show cooldown countdown" },
        { "countDuration", "Show effect countdown" } }
    if path[2] == "groups" and ns.PCMGroupManager:GetGroups().byID[path[3]].kind == "BAR" then
      fields = { { "width", "Bar width" }, { "height", "Bar height" },
        { "showName", "Show spell name" }, { "hideWhenInactive", "Hide inactive effects" },
        { "countDuration", "Show countdown" } }
    end
    for _, definition in ipairs(fields) do
      local relative = FindPCMControl(node, definition[1], {})
      if relative and #definitions < 6 then definitions[#definitions + 1] = { table.concat(relative, "/"), definition[2] } end
    end
    return definitions
  elseif path[1] == "Quality" then
    if path[2] == "automationTab" then
      return { { "loot/fasterLooting", "Faster looting" }, { "loot/autoKeystone", "Insert keystone" },
        { "merchant/autoRepair", "Auto repair" }, { "merchant/autoSellJunk", "Sell junk" } }
    elseif path[2] == "cursorTab" then
      return { { "innerRing/shown", "Show cursor ring" }, { "innerRing/size", "Cursor ring size" },
        { "clickRing/shown", "Show click ring" }, { "crosshairSettings/crosshair", "Show crosshair" } }
    elseif path[2] == "groupTab" then
      return { { "battleResLust/bresWidgetEnable", "Show battle resurrection" },
        { "battleResLust/lustWidgetEnable", "Show bloodlust" }, { "battleResLust/bresLustWidgetIconSize", "Icon size" } }
    end
    return { { "combatStatus/message/showText", "Show combat messages" },
      { "combatStatus/timer/showText", "Show combat timer" }, { "petWarnings/missingPetWarning", "Warn about missing pet", optional = true } }
  elseif path[1] == "DamageMeters" then
    return path[2] == "general" and { { "feature/enabled", "Enable damage meters" },
      { "bar/height", "Row height" }, { "bar/fontSize", "Text size" } } or { { "shown", "Show this window" } }
  end
  return ROOT_CONTROLS[path[1]]
end

local function BindSourceCallback(callback, source, path, option, handler)
  return function(_, ...)
    local info = CopyTable(path)
    info[0], info.appName, info.options = "PleebUI", "PleebUI", source
    info.option, info.arg, info.handler = option, option.arg, handler
    info.type, info.uiType, info.uiName = option.type, "dialog", "AceConfigDialog-3.0"
    if type(callback) == "string" then return handler[callback](handler, info, ...) end
    return callback(info, ...)
  end
end

local function BuildOptions()
  local path = active.path
  local record = ns.Registry.Options[path[1]]
  local previousPath = ns._PUIActiveOptionsPath
  ns._PUIActiveOptionsPath = path
  local options = ns.GUI.CopyOptionsNode(record.factory(Addon):GetOptions())
  local current = options
  for index = 2, #path do
    local child = ns.Registry.Options[path[index]]
    if child and child.parentKey == path[index - 1] then
      current.args[path[index]] = ns.GUI.CopyOptionsNode(child.factory(Addon):GetOptions())
    end
    current = current.args[path[index]]
  end
  ns._PUIActiveOptionsPath = previousPath
  local source = { type = "group", name = "PleebUI", args = { [path[1]] = options } }
  local args = {}
  for index, definition in ipairs(LessonControls(path, current)) do
    local fullPath = CopyTable(path)
    for key in definition[1]:gmatch("[^/]+") do fullPath[#fullPath + 1] = key end
    local option = ResolveOption(source, fullPath)
    if option or not definition.optional then
      local shortcut = ns.OptionsSchema.BuildCommonSettings(source, { { path = fullPath, label = definition[2] } })
      local control = shortcut.args[fullPath[#fullPath]]
      for _, member in ipairs({ "get", "set", "func", "hidden", "disabled", "name", "desc", "values", "sorting", "min", "max", "step", "confirm", "validate" }) do
        local callback = control[member]
        if type(callback) == "function" or type(callback) == "string" and (member == "get" or member == "set" or member == "func") then
          control[member] = BindSourceCallback(callback, source, fullPath, option, control.handler)
        end
      end
      control.order, control.width, control.fullWidth, control.relWidth = index * 10, "full", true, nil
      local columns = active.columns
      if columns > 1 then
        control.width, control.fullWidth, control.relWidth = "relative", nil, 1 / columns - 0.02
      end
      args["essential" .. index] = control
    end
  end
  local result = { type = "group", name = "Starter settings", args = args }
  Sanitize(result)
  return result
end

Registry:RegisterOptionsTable(APP, BuildOptions)

function Settings.SetCallbacks(handlers)
  callbacks = handlers
end

function Settings.Show(panel, path)
  if InCombatLockdown() then return end
  if active and active ~= panel then Settings.Hide(active) end
  active = panel
  panel.path = path
  panel.columns = math.min(2, ns.Theme.GetOptionsWidgetColumns(panel:GetWidth()))
  panel.skinSettings = SkinSettings()
  if not panel.widget then
    local widget = AceGUI:Create("SimpleGroup")
    widget:SetLayout("Flow")
    widget:SetAutoAdjustHeight(false)
    widget:SetFullWidth(true)
    widget.frame:SetParent(panel)
    ns.AceHooks.TakeOwnership(widget)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", panel, "TOPLEFT")
    widget.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    function widget:LayoutFinished(_, height)
      self:SetHeight(height)
      panel:SetHeight(height)
      panel.onHeightChanged(height)
    end
    panel.widget = widget
  end
  panel.widget.frame:SetFrameStrata(panel:GetFrameStrata())
  panel.widget.frame:SetFrameLevel(panel:GetFrameLevel() + 1)
  panel.widget:SetWidth(panel:GetWidth())
  panel.widget:SetHeight(panel:GetHeight())
  Dialog:Open(APP, panel.widget)
  BindControls(panel.widget)
  ns.InstallerPreview.SetSettingsPath(path)
  panel.widget.frame:Show()
end

function Settings.Hide(panel)
  if panel.widget then
    panel.widget:ReleaseChildren()
    panel.widget.frame:Hide()
  end
  if active == panel then active = nil end
end

function Settings.Create(parent, y, onHeightChanged)
  local panel = CreateFrame("Frame", nil, parent)
  panel.onHeightChanged = onHeightChanged
  panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
  panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -y)
  panel:SetHeight(360)
  panel:HookScript("OnHide", Settings.Hide)
  panel:SetScript("OnSizeChanged", function(self, width, height)
    if self.widget then
      self.widget:SetWidth(width)
      self.widget:SetHeight(height)
      if active == self and self.columns ~= math.min(2, ns.Theme.GetOptionsWidgetColumns(width)) then QueueRefresh(true) end
    end
  end)
  return panel
end

function Settings:OnSettingsChanged(_, appName)
  if appName ~= "PleebUI" or not active or not active:IsVisible() then return end
  QueueRefresh(true)
end

Registry.RegisterCallback(Settings, "ConfigTableChange", "OnSettingsChanged")
