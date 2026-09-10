local _, ns = ...

local Addon = ns.Addon
local FrameUtil = ns.FrameUtil

local API = {
  VERSION = 1,
  MINOR_VERSION = 0,
}

local PluginMixin = {}
local plugins = ns.Registry.Plugins

local MOVER_OPTION_KEYS = {
  "label",
  "ghost",
  "useOverlayDrag",
  "savePosition",
  "onDragStop",
  "resetPosition",
  "quickSettings",
  "smartSnap",
  "overlayInsets",
  "onDragUpdate",
  "onDrop",
  "overlayBelowFrame",
}

local GHOST_MOVER_OPTION_KEYS = {
  "frameName",
  "label",
  "ghost",
  "useOverlayDrag",
  "savePosition",
  "onDragStop",
  "resetPosition",
  "quickSettings",
  "smartSnap",
  "overlayInsets",
  "onDragUpdate",
  "onDrop",
  "overlayBelowFrame",
  "liveFrame",
  "getSize",
  "getPoint",
  "shouldShow",
  "show",
  "fallbackAnchor",
}

local function CopyTable(source, seen)
  if type(source) == "table" and source.GetObjectType then
    return source
  end

  local copy = {}

  if type(source) ~= "table" then
    return copy
  end

  seen = seen or {}
  if seen[source] then
    return seen[source]
  end
  seen[source] = copy

  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = CopyTable(value, seen)
    else
      copy[key] = value
    end
  end

  return copy
end

local function CopyMoverOptions(source, keys)
  local copy = {}

  for index = 1, #keys do
    local key = keys[index]
    local value = source[key]
    if type(value) == "table" then
      copy[key] = CopyTable(value)
    elseif value ~= nil then
      copy[key] = value
    end
  end

  return copy
end

local function IsValidKey(key)
  return type(key) == "string" and key ~= ""
end

local function BuildOwnedKey(plugin, kind, key)
  return "Plugin:" .. plugin.key .. ":" .. kind .. ":" .. key
end

local function BuildOptionsPath(plugin, pageKey, relativePath)
  local page = pageKey and plugin.optionsPages[pageKey] or nil
  if not page then
    return nil
  end

  local path = { plugin.optionsRootKey, page.registryKey }
  if type(relativePath) == "table" then
    for index = 1, #relativePath do
      path[#path + 1] = tostring(relativePath[index])
    end
  end

  return path
end

local function RefreshOptionsRegistry()
  Addon:NotifyOptionsTreeChanged()

  local frame = Addon._OptionsWindow
  if frame and frame:IsShown() then
    Addon:RefreshOpenOptions()
  end
end

local function BuildOptionsMeta(plugin, source, isRoot)
  local meta = CopyTable(source and source.meta)

  if isRoot then
    meta.navSection = "Plugins"
    meta.navDescription = source.navDescription or plugin.metadata.navDescription or meta.navDescription
    meta.navIcon = source.navIcon or plugin.metadata.navIcon or meta.navIcon
    meta.navAtlas = source.navAtlas or plugin.metadata.navAtlas or meta.navAtlas
    meta.navGlyph = source.navGlyph or plugin.metadata.navGlyph or meta.navGlyph
    meta.navBadge = source.navBadge or plugin.metadata.navBadge or meta.navBadge
    meta.pageTitle = source.pageTitle or meta.pageTitle or plugin.name
    meta.pageDescription = source.pageDescription or plugin.metadata.pageDescription or meta.pageDescription
    meta.pageHelp = source.pageHelp or plugin.metadata.pageHelp or meta.pageHelp
  else
    meta.pageTitle = source.pageTitle or meta.pageTitle or source.name
    meta.pageDescription = source.pageDescription or meta.pageDescription
    meta.pageHelp = source.pageHelp or meta.pageHelp
  end

  if type(source.page) == "table" then
    meta.page = CopyTable(source.page)
  end

  if source.allowPreview == true then
    meta.allowPreview = true
  end

  meta.pluginKey = plugin.key
  return meta
end

function API:GetVersion()
  return self.VERSION, self.MINOR_VERSION
end

function API:GetPlugin(key)
  return IsValidKey(key) and plugins[key] or nil
end

function API:RegisterPlugin(key, metadata)
  if not IsValidKey(key) then
    return nil, "Plugin key must be a non-empty string."
  end

  local existing = plugins[key]
  if existing then
    return existing
  end

  metadata = CopyTable(metadata)

  local plugin = {
    key = key,
    name = metadata.name or key,
    metadata = metadata,
    movers = {},
    optionsPages = {},
    editModeParticipants = {},
    optionsRootKey = "Plugin:" .. key .. ":Options",
  }

  setmetatable(plugin, { __index = PluginMixin })
  plugins[key] = plugin
  return plugin
end

function API:UnregisterPlugin(key)
  local plugin = self:GetPlugin(key)
  if not plugin then
    return false
  end

  plugin:Unregister()
  plugins[key] = nil
  return true
end

function PluginMixin:_EnsureOptionsRoot()
  if self.optionsRootRegistered then
    return
  end

  local plugin = self
  local rootSpec = self.metadata
  local rootProvider = {
    GetOptions = function()
      return {
        type = "group",
        name = plugin.name,
        childGroups = "tab",
        args = {},
      }
    end,
  }

  local record = Addon:RegisterOptionsSection(
    self.optionsRootKey,
    function()
      return rootProvider
    end,
    tonumber(rootSpec.order) or 50,
    self.name,
    nil,
    BuildOptionsMeta(self, rootSpec, true)
  )

  record.ownerKey = self.key
  record.pluginRoot = true
  self.optionsRootRegistered = true
end

function PluginMixin:_RefreshOptionsRootCacheMode()
  local root = ns.Registry.Options[self.optionsRootKey]
  if not root then
    return
  end

  root.dynamicOptions = nil
  for _, page in pairs(self.optionsPages) do
    if page.dynamicOptions then
      root.dynamicOptions = true
      return
    end
  end
end

function PluginMixin:RegisterOptionsPage(pageKey, spec)
  if not IsValidKey(pageKey) or type(spec) ~= "table" or type(spec.getOptions) ~= "function" then
    return false, "Options pages require a key and getOptions function."
  end

  self:_EnsureOptionsRoot()

  local plugin = self
  local page = {
    key = pageKey,
    registryKey = BuildOwnedKey(self, "Options", pageKey),
    name = spec.name or pageKey,
    spec = spec,
    dynamicOptions = spec.dynamicOptions == true,
  }

  local provider = {
    GetOptions = function()
      return page.spec.getOptions(plugin, page.key)
    end,
  }

  local record = Addon:RegisterOptionsSection(
    page.registryKey,
    function()
      return provider
    end,
    tonumber(spec.order) or 50,
    page.name,
    self.optionsRootKey,
    BuildOptionsMeta(self, spec, false)
  )

  record.ownerKey = self.key
  record.pluginPageKey = pageKey
  record.dynamicOptions = page.dynamicOptions or nil
  record.disableProviderCache = spec.disableProviderCache == true or nil

  self.optionsPages[pageKey] = page
  self:_RefreshOptionsRootCacheMode()
  RefreshOptionsRegistry()
  return true
end

function PluginMixin:UnregisterOptionsPage(pageKey)
  local page = pageKey and self.optionsPages[pageKey] or nil
  if not page then
    return false
  end

  Addon:UnregisterOptionsSection(page.registryKey)
  self.optionsPages[pageKey] = nil
  self:_RefreshOptionsRootCacheMode()

  if not next(self.optionsPages) then
    Addon:UnregisterOptionsSection(self.optionsRootKey)
    self.optionsRootRegistered = nil
  end

  RefreshOptionsRegistry()
  return true
end

function PluginMixin:NotifyOptionsChanged(pageKey, relativePath)
  local page = pageKey and self.optionsPages[pageKey] or nil
  if not page then
    return false
  end

  Addon:NotifyOptionsTreeChanged(
    page.registryKey,
    BuildOptionsPath(self, pageKey, relativePath)
  )
  return true
end

function PluginMixin:OpenOptions(pageKey, relativePath)
  local path = BuildOptionsPath(self, pageKey, relativePath)
  if not path then
    return false
  end

  Addon:OpenOptions(path, false, true)
  return true
end

local function ApplyMoverOptionsRoute(plugin, source, target)
  if type(source.openOptions) == "function" then
    target.openOptions = source.openOptions
    return
  end

  if IsValidKey(source.optionsPage) then
    local relativePath = type(source.optionsPath) == "table" and CopyTable(source.optionsPath) or nil
    target.openOptions = function()
      plugin:OpenOptions(source.optionsPage, relativePath)
    end
  end
end

function PluginMixin:RegisterMover(moverKey, frame, options)
  if not IsValidKey(moverKey)
    or not frame
    or not frame.GetObjectType
    or not frame:IsObjectType("Frame")
  then
    return false, "Movers require a key and frame."
  end

  options = type(options) == "table" and options or {}

  local ownedKey = BuildOwnedKey(self, "Mover", moverKey)
  local moverOptions = CopyMoverOptions(options, MOVER_OPTION_KEYS)
  ApplyMoverOptionsRoute(self, options, moverOptions)

  local existing = self.movers[moverKey]
  if existing and existing.ghost then
    FrameUtil:ReleaseGhostMover(existing.ownedKey)
  end

  FrameUtil:RegisterMover(ownedKey, frame, moverOptions)
  self.movers[moverKey] = {
    ownedKey = ownedKey,
    ghost = false,
  }
  return true, ownedKey
end

function PluginMixin:RegisterGhostMover(moverKey, options)
  if not IsValidKey(moverKey) or type(options) ~= "table" then
    return false, "Ghost movers require a key and options table."
  end

  local ownedKey = BuildOwnedKey(self, "Mover", moverKey)
  local moverOptions = CopyMoverOptions(options, GHOST_MOVER_OPTION_KEYS)
  ApplyMoverOptionsRoute(self, options, moverOptions)

  local existing = self.movers[moverKey]
  if existing and not existing.ghost then
    FrameUtil:UnregisterMover(existing.ownedKey)
  end

  local frame = FrameUtil:EnsureGhostMover(ownedKey, moverOptions)
  if not frame then
    return false, "Ghost mover could not be created."
  end

  self.movers[moverKey] = {
    ownedKey = ownedKey,
    ghost = true,
  }
  return true, ownedKey, frame
end

function PluginMixin:RefreshMover(moverKey)
  local mover = moverKey and self.movers[moverKey] or nil
  if not mover then
    return false
  end

  if mover.ghost then
    FrameUtil:RefreshGhostMover(mover.ownedKey)
  else
    FrameUtil:RefreshMoverOverlay(mover.ownedKey)
  end
  return true
end

function PluginMixin:UnregisterMover(moverKey)
  local mover = moverKey and self.movers[moverKey] or nil
  if not mover then
    return false
  end

  if mover.ghost then
    FrameUtil:ReleaseGhostMover(mover.ownedKey)
  else
    FrameUtil:UnregisterMover(mover.ownedKey)
  end

  self.movers[moverKey] = nil
  return true
end

function PluginMixin:RegisterEditModeParticipant(participantKey, callbacks)
  if not IsValidKey(participantKey)
    or type(callbacks) ~= "table"
    or type(callbacks.onChanged) ~= "function"
  then
    return false, "Edit Mode participants require a key and onChanged function."
  end

  local ownedKey = BuildOwnedKey(self, "EditMode", participantKey)
  if self.editModeParticipants[participantKey] then
    FrameUtil.UnregisterEditModeParticipant(ownedKey)
  end

  local participant = {
    OnEditModeChanged = function(_, enabled)
      callbacks.onChanged(enabled)
    end,
  }

  if not FrameUtil.RegisterEditModeParticipant(ownedKey, participant, callbacks.order) then
    return false, "Edit Mode participant could not be registered."
  end

  self.editModeParticipants[participantKey] = ownedKey
  return true
end

function PluginMixin:UnregisterEditModeParticipant(participantKey)
  local ownedKey = participantKey and self.editModeParticipants[participantKey] or nil
  if not ownedKey then
    return false
  end

  FrameUtil.UnregisterEditModeParticipant(ownedKey)
  self.editModeParticipants[participantKey] = nil
  return true
end

function PluginMixin:IsEditModeActive()
  return Addon:IsEditMode()
end

function PluginMixin:Unregister()
  local keys = {}

  for key in pairs(self.editModeParticipants) do
    keys[#keys + 1] = key
  end
  for index = 1, #keys do
    self:UnregisterEditModeParticipant(keys[index])
  end

  keys = {}
  for key in pairs(self.movers) do
    keys[#keys + 1] = key
  end
  for index = 1, #keys do
    self:UnregisterMover(keys[index])
  end

  keys = {}
  for key in pairs(self.optionsPages) do
    keys[#keys + 1] = key
  end
  for index = 1, #keys do
    self:UnregisterOptionsPage(keys[index])
  end
end

ns.PublicAPI = API
_G.PleebUIAPI = API
