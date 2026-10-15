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
local CONTROL_EVENTS = { "OnValueChanged", "OnClick", "OnGroupSelected", "OnEnterPressed", "OnKeyChanged", "OnMouseUp", "OnValueConfirmed", "OnClosed" }

local function Sanitize(options)
  for key in pairs(options) do
    if type(key) == "string" and key:match("^__pui") then options[key] = nil end
  end
  if options.type ~= "group" and options.type ~= "description" and options.type ~= "header" then
    options.width, options.fullWidth, options.fixedWidth = nil, nil, nil
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
    if rebuild then Settings.Show(panel, panel.path, true) else BindControls(panel.widget) end
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
          if name == "OnGroupSelected" then
            local user = control:GetUserDataTable()
            local path = CopyTable(user.path)
            for key in tostring((...)):gmatch("[^\001]+") do path[#path + 1] = key end
            active.optionsPath = path
          end
          original(control, name, ...)
          QueueRefresh(name == "OnGroupSelected")
        end
        bound[event] = callback
        child:SetCallback(event, callback)
      end
    end
    BindControls(child)
  end
end

local function BuildOptions()
  local path = active.path
  local record = ns.Registry.Options[path[1]]
  local previousPath = ns._PUIActiveOptionsPath
  ns._PUIActiveOptionsPath = active.optionsPath
  local options = record.factory(Addon):GetOptions()
  ns.OptionsSchema.Apply(options, path[1])
  local current = options
  for index = 2, #path do
    local child = ns.Registry.Options[path[index]]
    if child and child.parentKey == path[index - 1] then
      current.args[path[index]] = child.factory(Addon):GetOptions()
    end
    current = current.args[path[index]]
  end
  ns._PUIActiveOptionsPath = previousPath
  Sanitize(options)
  return { type = "group", name = "Setup settings", args = { [path[1]] = options } }
end

Registry:RegisterOptionsTable(APP, BuildOptions)

function Settings.SetCallbacks(handlers)
  callbacks = handlers
end

function Settings.Show(panel, path, refresh)
  if InCombatLockdown() then return end
  if active and active ~= panel then Settings.Hide(active) end
  active = panel
  panel.path = path
  if not refresh then panel.optionsPath = path end
  panel.skinSettings = SkinSettings()
  if not panel.widget then
    local widget = AceGUI:Create("SimpleGroup")
    widget:SetLayout("Fill")
    widget.frame:SetParent(panel)
    ns.AceHooks.TakeOwnership(widget)
    widget.frame:ClearAllPoints()
    widget.frame:SetAllPoints(panel)
    panel.widget = widget
  end
  panel.widget:SetWidth(panel:GetWidth())
  panel.widget:SetHeight(panel:GetHeight())
  Dialog:Open(APP, panel.widget, unpack(path))
  BindControls(panel.widget)
  panel.widget.frame:Show()
end

function Settings.Hide(panel)
  if panel.widget then
    panel.widget:ReleaseChildren()
    panel.widget.frame:Hide()
  end
  if active == panel then active = nil end
end

function Settings.Create(parent, y)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
  panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -y)
  panel:SetHeight(500)
  panel:HookScript("OnHide", Settings.Hide)
  panel:SetScript("OnSizeChanged", function(self, width, height)
    if self.widget then
      self.widget:SetWidth(width)
      self.widget:SetHeight(height)
    end
  end)
  return panel
end

function Settings:OnSettingsChanged(_, appName)
  if appName ~= "PleebUI" or not active or not active:IsVisible() then return end
  QueueRefresh(true)
end

Registry.RegisterCallback(Settings, "ConfigTableChange", "OnSettingsChanged")
