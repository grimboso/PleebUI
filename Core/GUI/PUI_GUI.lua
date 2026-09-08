local ADDON_NAME, ns = ...

local Addon = ns.Addon
local AceGUI = LibStub("AceGUI-3.0")
local PUI_OPTIONS_APP = "PleebUI"

local GUI = {
  State = {
    dialogRegistered = false,
  },
}
ns.GUI = GUI

local State = GUI.State

local function _PUI_ApplyAuraSpellIDTooltipCVarForOptions(optionsOpen)
  local enabled = optionsOpen == true

  if not enabled then
    local profile = Addon.db and Addon.db.profile
    local quality = profile and profile.quality
    enabled = quality and quality.showAuraSpellIDs == true or false
  end

  ns.UFAuraFilters.ApplyAuraSpellIDTooltipCVar(enabled)
end


local function _PUI_RefreshConfirmDialogSkin(f)
  ns.Theme.WidgetSkins.Frame(f)
  ns.Theme.WidgetSkins.UIButton(f._btnYes)
  ns.Theme.WidgetSkins.UIButton(f._btnNo)

  local colors = ns.Theme.GetColors()
  local tr, tg, tb, ta = ns.Theme.UnpackColor(colors.text, { 1, 1, 1, 1 })

  ns.Theme.ApplyFont(f._title, "title", 18)
  f._title:SetTextColor(tr, tg, tb, ta)

  ns.Theme.ApplyFont(f._msg, "body", 12)
  f._msg:SetTextColor(tr, tg, tb, ta)
end

local function _PUI_CreateConfirmDialog()

  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetSize(420, 190)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(9999)
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)

  ns.Theme.WidgetSkins.Frame(f)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
  title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -16)
  title:SetJustifyH("LEFT")
  f._title = title

  local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  msg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  msg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -56)
  msg:SetJustifyH("LEFT")
  msg:SetJustifyV("TOP")
  msg:SetWordWrap(true)
  f._msg = msg

  local btnYes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnYes:SetSize(140, 24)
  btnYes:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
  f._btnYes = btnYes
  ns.Theme.WidgetSkins.UIButton(btnYes)

  local btnNo = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnNo:SetSize(140, 24)
  btnNo:SetPoint("RIGHT", btnYes, "LEFT", -10, 0)
  f._btnNo = btnNo
  ns.Theme.WidgetSkins.UIButton(btnNo)

  -- Wire clicks once (no re-SetScript each open)
  btnYes:SetScript("OnClick", function()
    f:Hide()
    local cb = f._onYes
    f._onYes = nil
    f._onNo  = nil
    if cb then cb() end
  end)

  btnNo:SetScript("OnClick", function()
    f:Hide()
    local cb = f._onNo
    f._onYes = nil
    f._onNo  = nil
    if cb then cb() end
  end)

  f:Hide()
  return f
end

local function _PUI_GetConfirmDialog()
  if not Addon._PUIConfirmDialog then
    Addon._PUIConfirmDialog = _PUI_CreateConfirmDialog()
  end
  return Addon._PUIConfirmDialog
end

function Addon:PUI_ConfirmAction(opts)
  opts = opts or {}

  local f = _PUI_GetConfirmDialog()

  f._onYes = opts.onYes
  f._onNo  = opts.onNo

  f._title:SetText(opts.title or "Confirm")
  f._msg:SetText(opts.text or "")

  f._btnYes:SetText(opts.yesText or YES)
  f._btnNo:SetText(opts.noText or CANCEL)

  _PUI_RefreshConfirmDialogSkin(f)

  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:Show()
end

function Addon:PUI_ConfirmResetAndReload(opts)
  local title = opts.title or "Reset"
  local text  = opts.text or "Reset settings to defaults?\n\nThis will reload the UI."

  self:PUI_ConfirmAction({
    title   = title,
    text    = text,
    yesText = opts.yesText or "Reset + Reload",
    noText  = opts.noText or CANCEL,
    onYes   = function()
      if InCombatLockdown() then
        Addon:Print("|cffff4444[PUI]|r Cannot reset + reload while in combat.")
        return
      end
      opts.resetFn()
      ReloadUI()
    end,
  })
end

local optionsRegistry = ns.Registry.Options
local _PUI_OptionsApplyState = { buckets = {} }

local function _PUI_MergeApplyFlags(dst, src)
  for key, value in pairs(src) do
    if type(value) == "table" then
      local child = dst[key]
      if type(child) ~= "table" then
        child = {}
        dst[key] = child
      end
      _PUI_MergeApplyFlags(child, value)
    else
      dst[key] = value
    end
  end
end

local function _PUI_FlushUFOptions(flags)
  local uf = ns.Modules.UnitFrames

  if flags.textures then
    ns.UFStyle.RefreshAllFrameTextures(uf)
  end

  if flags.mouseover then
    uf:RefreshMouseoverSettings()
  end

  if flags.auras then
    uf:RefreshAuraDisplay(flags)
  end

  local needsSafeRefresh = false
  for key, value in pairs(flags) do
    if value
      and key ~= "textures"
      and key ~= "mouseover"
      and key ~= "auras"
      and key ~= "unit"
      and key ~= "rebuildDB"
      and key ~= "displayID"
      and key ~= "auraChange"
      and key ~= "auraType"
      and key ~= "highlight"
      and key ~= "highlightState"
      and key ~= "highlightPresentation"
    then
      needsSafeRefresh = true
      break
    end
  end

  if needsSafeRefresh then
    uf:SafeRefresh(flags)
  end

  local testMode = ns.TestMode
  if testMode:IsActive() then
    testMode:Refresh("unitframes", "unit-frame-options", "uf.singleSettings")
  end
end

local function _PUI_FlushCastBarOptions()
  ns.Modules.CastBar:UpdateAllLayouts()

  local testMode = ns.TestMode
  if testMode:IsActive() then
    testMode:Refresh("unitframes", "castbar-options", "uf.castbars")
  end
end

local function _PUI_FlushOptionsApplyBucket(kind, flags)
  if kind == "ActionBars" then
    ns.ActionBarsCore:RefreshAll(flags)
  elseif kind == "PRD" then
    ns.Modules.PRD:ApplyRequestedFlags(flags)
  elseif kind == "UnitFrames" then
    _PUI_FlushUFOptions(flags)
  elseif kind == "CastBar" then
    _PUI_FlushCastBarOptions(flags)
  elseif kind == "Quality" then
    ns.Modules.Quality:ApplyAll()
  elseif kind == "Minimap" then
    ns.Registry.Minimap:RefreshFromOptions(flags)
  elseif kind == "Dragonriding" then
    ns.Modules.Dragonriding:Refresh()
  end
end

function Addon:ApplyOptionsChange(kind, flags)
  local buckets = _PUI_OptionsApplyState.buckets
  local bucket = buckets[kind]
  if not bucket then
    bucket = { flags = {}, queued = false }
    buckets[kind] = bucket
  end

  _PUI_MergeApplyFlags(bucket.flags, flags)

  if kind == "UnitFrames" then
    ns.UFPreview.RefreshAuraManagerPreview()
  end

  if bucket.queued then
    return
  end

  bucket.queued = true

  C_Timer.After(0, function()
    local pending = bucket.flags
    bucket.flags = {}
    bucket.queued = false
    _PUI_FlushOptionsApplyBucket(kind, pending)
  end)
end

local _PUI_CopyOptionsPath

local function _PUI_ClearOptionsProviderCache(rec)
  if not rec then
    return
  end

  rec.__puiOptions = nil
  rec.__puiOptionsByPathKey = nil
end

local function _PUI_InvalidateOptionsProviderCache(sectionKey)
  if sectionKey then
    _PUI_ClearOptionsProviderCache(optionsRegistry[sectionKey])
    return
  end

  for _, rec in pairs(optionsRegistry) do
    _PUI_ClearOptionsProviderCache(rec)
  end
end

function Addon:InvalidateOptionsRender(sectionKey)
  _PUI_InvalidateOptionsProviderCache(sectionKey)
  ns.__puiAceOptions = nil
  State.optionsRoot = nil
  State.optionsRootPathKey = nil

  local frame = Addon._OptionsWindow
  if frame then
    frame.__puiLastRenderedOptionsPathKey = nil
  end
end

function Addon:NotifyOptionsTreeChanged(sectionKey, targetPath, afterSelect)
  self:InvalidateOptionsRender(sectionKey)

  LibStub("AceConfigRegistry-3.0"):NotifyChange(PUI_OPTIONS_APP)

  local frame = Addon._OptionsWindow

  if not (frame and frame.__puiCustomOptionsWindow and frame:IsShown() and targetPath) then
    return
  end

  local pathGeneration = State.optionsPathGeneration or 0

  C_Timer.After(0, function()
    if not (frame and frame:IsShown())
      or (State.optionsPathGeneration or 0) ~= pathGeneration
    then
      return
    end

    Addon:OpenOptions(targetPath, false, true)

    if type(afterSelect) == "function" then
      local selectedGeneration = State.optionsPathGeneration or 0

      C_Timer.After(0, function()
        if frame:IsShown() and (State.optionsPathGeneration or 0) == selectedGeneration then
          afterSelect()
        end
      end)
    end
  end)
end

local function _PUI_SortRegistryNodes(a, b)
  if a.order == b.order then
    return tostring(a.name) < tostring(b.name)
  end
  return a.order < b.order
end

local function _PUI_GetSortedRegistryNodes()
  local nodes = {}

  for key, rec in pairs(optionsRegistry) do
    nodes[#nodes + 1] = {
      key = key,
      name = rec.name,
      label = rec.label,
      order = rec.order,
      parentKey = rec.parentKey,
      factory = rec.factory,
      meta = rec.meta,
      rec = rec,
    }
  end

  table.sort(nodes, _PUI_SortRegistryNodes)
  return nodes
end

local _PUI_GetSectionPath
local _PUI_GetValidatedOptionsPath
local _PUI_GetStoredOptionsPath
local _PUI_GetCurrentOptionsPath
local _PUI_GetFallbackOptionsPath
local _PUI_RefreshCustomPageShell

local function _PUI_GetFirstSelectableRegistryKey()
  local nodes = _PUI_GetSortedRegistryNodes()
  local childrenByParent = {}

  for i = 1, #nodes do
    local node = nodes[i]
    if node.parentKey and node.parentKey ~= "" then
      childrenByParent[node.parentKey] = true
    end
  end

  for i = 1, #nodes do
    local node = nodes[i]
    if node.parentKey and node.parentKey ~= "" then
      return node.key
    end

    if not childrenByParent[node.key] then
      return node.key
    end
  end

  return nodes[1] and nodes[1].key or nil
end

local PUI_DEFAULT_OPTIONS_CHILD = {
  unitframes = "general",
  ACTIONBARS = "general",
  CooldownManager = "cooldowns_essential",
  PRD = "general",
  Quality = "qualityTab",
}

local function _PUI_IsRootRegistryKey(sectionKey)
  local rec = optionsRegistry[sectionKey]
  return rec and (not rec.parentKey or rec.parentKey == "") or false
end

local function _PUI_GetFirstChildRegistryKey(parentKey)
  if PUI_DEFAULT_OPTIONS_CHILD[parentKey] then
    return PUI_DEFAULT_OPTIONS_CHILD[parentKey]
  end

  local nodes = _PUI_GetSortedRegistryNodes()
  for i = 1, #nodes do
    local node = nodes[i]
    if node.parentKey == parentKey then
      return node.key
    end
  end

  return nil
end

local function _PUI_GetRootHomeSelectionPath(sectionKey)
  local path = _PUI_GetSectionPath(sectionKey)
  if not path or #path == 0 then
    return nil
  end

  local firstChildKey = _PUI_GetFirstChildRegistryKey(sectionKey)
  if firstChildKey then
    path[#path + 1] = firstChildKey
  end

  return _PUI_GetValidatedOptionsPath(path)
end

local function _PUI_GetPreferredRootSelectionPath(sectionKey)
  local stateDB = Addon.db.global.pui.optionsState
  local rootPaths = stateDB and stateDB.lastOptionsPathByRoot
  local rememberedPath = rootPaths and _PUI_GetValidatedOptionsPath(rootPaths[sectionKey])
  if rememberedPath and rememberedPath[1] == sectionKey then
    return rememberedPath
  end

  return _PUI_GetRootHomeSelectionPath(sectionKey)
end

local function _PUI_ShouldCacheProviderOptions(node)
  return node.rec.disableProviderCache ~= true
end

local function _PUI_GetProviderOptionsCacheKey(rec, activePath)
  if rec.dynamicOptions ~= true then
    return "__root"
  end

  activePath = activePath or State.currentOptionsPath or ns._PUIActiveOptionsPath
  return tostring(type(activePath) == "table" and activePath[2] or "")
end

local function _PUI_SanitizeOptionsNode(opts)
  if type(opts) ~= "table" then
    return opts
  end

  for k in pairs(opts) do
    if type(k) == "string" and k:match("^__pui") then
      opts[k] = nil
    end
  end

  local optType = opts.type

  if optType ~= "group"
    and optType ~= "description"
    and optType ~= "header"
  then
    opts.width = nil
    opts.fullWidth = nil
    opts.fixedWidth = nil
  end

  if (optType == "select" or optType == "multiselect") and opts.values == nil then
    opts.values = {}
  end

  if type(opts.args) == "table" then
    for _, child in pairs(opts.args) do
      _PUI_SanitizeOptionsNode(child)
    end
  end

  return opts
end

local function _PUI_CreateProviderOption(node, activePath)
  local rec = node.rec
  local useCache = _PUI_ShouldCacheProviderOptions(node)
  local cacheKey = _PUI_GetProviderOptionsCacheKey(rec, activePath)
  local cachedOptions

  if useCache then
    if rec.dynamicOptions == true then
      local optionsByPathKey = rec.__puiOptionsByPathKey
      cachedOptions = optionsByPathKey and optionsByPathKey[cacheKey] or nil
    else
      cachedOptions = rec.__puiOptions
    end
  end

  if type(cachedOptions) == "table" then
    local opts = _PUI_SanitizeOptionsNode(cachedOptions)
    opts.type = opts.type or "group"
    opts.name = opts.name or node.name or node.key or "PleebUI"
    opts.order = node.order or opts.order or 50
    opts.args = opts.args or {}
    return opts
  end

  local provider = useCache and rec.__puiProvider or nil
  if not provider then
    provider = node.factory(Addon)

    if useCache then
      rec.__puiProvider = provider
    end
  end

  local opts = _PUI_SanitizeOptionsNode(provider:GetOptions())
  opts.type = opts.type or "group"
  opts.name = opts.name or node.name or node.key or "PleebUI"
  opts.order = node.order or opts.order or 50
  opts.args = opts.args or {}

  if useCache then
    if rec.dynamicOptions == true then
      rec.__puiOptionsByPathKey = rec.__puiOptionsByPathKey or {}
      rec.__puiOptionsByPathKey[cacheKey] = opts
    else
      rec.__puiOptions = opts
    end
  end

  return opts
end


_PUI_GetSectionPath = function(sectionKey)
  if not optionsRegistry[sectionKey] then
    return nil
  end

  local path = {}
  local key = sectionKey

  while key do
    path[#path + 1] = key
    key = optionsRegistry[key].parentKey
    if key == "" then
      key = nil
    end
  end

  local out = {}
  for i = #path, 1, -1 do
    out[#out + 1] = path[i]
  end

  return out
end

_PUI_CopyOptionsPath = function(path)
  if type(path) ~= "table" or #path == 0 then
    return nil
  end

  local out = {}
  for i = 1, #path do
    local segment = path[i]
    if type(segment) ~= "string" or segment == "" then
      return nil
    end
    out[#out + 1] = segment
  end

  return (#out > 0) and out or nil
end

local _PUI_GetOptionsStateDB


local function _PUI_BuildOptionsPath(sectionKey, inlineTabKey, key)
  local path = _PUI_GetSectionPath(sectionKey)
  if not path or #path == 0 then
    return nil
  end

  if type(inlineTabKey) == "string" and inlineTabKey ~= "" then
    path[#path + 1] = inlineTabKey
  end

  if type(key) == "string" and key ~= "" then
    path[#path + 1] = key
  end

  return path
end

local function _PUI_CopyOptionsNode(src, seen)
  if type(src) ~= "table" then
    return src
  end

  seen = seen or {}
  if seen[src] then
    return seen[src]
  end

  local out = {}
  seen[src] = out

  for k, v in pairs(src) do
    if k == "handler" then
      out[k] = v
    elseif type(v) == "table" then
      out[k] = _PUI_CopyOptionsNode(v, seen)
    else
      out[k] = v
    end
  end

  local control = out.dialogControl or out.control

  if out.type == "toggle" and (control == nil or control == "CheckBox") then
    out.dialogControl = "PUI_Checkbox"
    out.control = nil
  elseif out.type == "execute"
    and out.image == nil
    and (control == nil or control == "Button")
  then
    out.dialogControl = "PUI_Button"
    out.control = nil
  elseif out.type == "range" and (control == nil or control == "Slider") then
    out.dialogControl = "PUI_Slider"
    out.control = nil
  elseif (out.type == "select" and out.style ~= "radio" or out.type == "multiselect")
    and (control == nil or control == "Dropdown")
  then
    out.dialogControl = "PUI_Dropdown"
    out.control = nil
  elseif out.type == "input" then
    if out.multiline then
      if control == nil or control == "MultiLineEditBox" then
        out.dialogControl = "PUI_MultiLineEditBox"
        out.control = nil
      end
    elseif control == nil or control == "EditBox" then
      out.dialogControl = "PUI_EditBox"
      out.control = nil
    end
  elseif out.type == "description" and (control == nil or control == "Label") then
    out.dialogControl = "PUI_Label"
    out.control = nil
  elseif out.type == "header" and (control == nil or control == "Heading") then
    out.dialogControl = "PUI_Heading"
    out.control = nil
  end

  return out
end

local PUI_COLUMN_WIDTH_OPTION_TYPES = {
  toggle = true,
  range = true,
  select = true,
  multiselect = true,
  input = true,
  multiline = true,
  color = true,
  execute = true,
  keybinding = true,
}

local PUI_COLUMN_WIDTH_OWNED = setmetatable({}, { __mode = "k" })

local function _PUI_GetOptionsColumnRelWidth()
  return 1 / ns.Theme.GetOptionsWidgetColumns()
end

local function _PUI_ApplyColumnWidthMetadata(option, relWidth, seen)
  if type(option) ~= "table" then
    return
  end

  seen = seen or {}
  if seen[option] then
    return
  end
  seen[option] = true

  local optionArg = option.type == "group" and option.arg or nil
  local widgetColumns = type(optionArg) == "table" and tonumber(optionArg.puiWidgetColumns) or nil
  local childRelWidth = widgetColumns and widgetColumns > 0 and (1 / widgetColumns) or relWidth

  if option.hidden ~= true and PUI_COLUMN_WIDTH_OPTION_TYPES[option.type] == true then
    if option.width == nil or option.width == "normal" or PUI_COLUMN_WIDTH_OWNED[option] == true then
      option.width = "relative"
      option.relWidth = relWidth
      PUI_COLUMN_WIDTH_OWNED[option] = true
    end
  end

  local args = option.args
  if type(args) == "table" then
    for _, child in pairs(args) do
      _PUI_ApplyColumnWidthMetadata(child, childRelWidth, seen)
    end
  end
end

local function _PUI_ApplyOptionsColumnWidthMetadata(root, activePath)
  if type(root) ~= "table" then
    return
  end

  local activeRoot = type(activePath) == "table" and activePath[1] or nil
  local target = nil

  if activeRoot and root.args then
    target = root.args[activeRoot]
  else
    target = root
  end

  if type(target) ~= "table" then
    return
  end

  _PUI_ApplyColumnWidthMetadata(target, _PUI_GetOptionsColumnRelWidth())
end

local function _PUI_BuildActiveOptionsTree(activePath)
  local root = {
    type = "group",
    name = "PleebUI",
    childGroups = "tree",
    args = {},
  }

  local nodes = _PUI_GetSortedRegistryNodes()
  local activeRootKey = type(activePath) == "table" and activePath[1] or nil
  local activeChildKey = type(activePath) == "table" and activePath[2] or nil

  if not activeRootKey then
    activeRootKey = _PUI_GetFirstSelectableRegistryKey()
  end

  if not activeChildKey then
    activeChildKey = _PUI_GetFirstChildRegistryKey(activeRootKey)
  end

  local childrenByParent = {}
  for i = 1, #nodes do
    local node = nodes[i]
    if node.parentKey and node.parentKey ~= "" then
      childrenByParent[node.parentKey] = childrenByParent[node.parentKey] or {}
      childrenByParent[node.parentKey][#childrenByParent[node.parentKey] + 1] = node
    end
  end

  local built = {}

  local function BuildNode(node)
    if not node then
      return nil
    end

    if built[node.key] then
      return built[node.key]
    end

    local sourceOption = _PUI_CreateProviderOption(node, activePath)
    local option = _PUI_CopyOptionsNode(sourceOption)
    local kids = childrenByParent[node.key]

    if kids and #kids > 0 then
      option.type = option.type or "group"
      option.name = option.name or node.name or node.key
      option.childGroups = option.childGroups or "tree"
      option.args = option.args or {}

      for i = 1, #kids do
        local child = kids[i]
        option.args[child.key] = BuildNode(child)
      end
    end

    option.order = node.order or option.order or 50

    built[node.key] = option
    return option
  end

  for i = 1, #nodes do
    local node = nodes[i]
    if not node.parentKey or node.parentKey == "" then
      if node.key == activeRootKey then
        root.args[node.key] = BuildNode(node)
      else
        root.args[node.key] = {
          type = "group",
          name = node.name or node.label or node.key,
          order = node.order or 50,
          args = {},
        }
      end
    end
  end

  _PUI_ApplyOptionsColumnWidthMetadata(root, activePath)

  return root
end

local function _PUI_GetOptionsRootPathKey(path)
  local rootKey = type(path) == "table" and path[1] or nil
  if not rootKey then
    return "__root"
  end

  local rec = optionsRegistry[rootKey]
  if rec and rec.dynamicOptions == true then
    return rootKey .. "\031" .. tostring(path[2] or "")
  end

  return rootKey
end

local function _PUI_GetOptionsRoot()
  local activePath = _PUI_CopyOptionsPath(State.currentOptionsPath) or _PUI_GetStoredOptionsPath()
  local pathKey = _PUI_GetOptionsRootPathKey(activePath)

  if State.optionsRoot and State.optionsRootPathKey == pathKey then
    return State.optionsRoot
  end

  local root = _PUI_BuildActiveOptionsTree(activePath)
  State.optionsRoot = root
  State.optionsRootPathKey = pathKey
  ns.__puiAceOptions = root

  return root
end

local function _PUI_RebindOptionsGroup(widget)
  local user = widget and widget:GetUserDataTable()
  if not user
    or user.appName ~= PUI_OPTIONS_APP
    or type(user.path) ~= "table"
  then
    return false
  end

  local options = _PUI_GetOptionsRoot()
  local option = options

  for i = 1, #user.path do
    local args = option and option.args
    option = args and args[user.path[i]] or nil

    if type(option) ~= "table" then
      return false
    end
  end

  user.options = options
  user.option = option
  return true
end

local function _PUI_DoesOptionsPathExist(path)
  path = _PUI_CopyOptionsPath(path)
  if not path then
    return false
  end

  local registry = ns.Registry.Options
  local rootKey = path[1]
  local rootRec = rootKey and registry[rootKey] or nil

  if type(rootRec) ~= "table" then
    return false
  end

  if #path == 1 then
    return true
  end

  local knownLazyChildren = {
    unitframes = {
      general = true,
      player = true,
      target = true,
      focus = true,
      boss = true,
      party = true,
      raid = true,
    },
    PRD = {
      general = true,
      health = true,
      primary = true,
      secondary = true,
    },
    Quality = {
      qualityTab = true,
      automationTab = true,
    },
    ACTIONBARS = {
      general = true,
      ["1"] = true,
      ["2"] = true,
      ["3"] = true,
      ["4"] = true,
      ["5"] = true,
      ["6"] = true,
      ["7"] = true,
      ["8"] = true,
      special = true,
    },
    CooldownManager = {
      cooldowns_essential = true,
      cooldowns_utility = true,
      buff_icons = true,
      buff_bars = true,
      custom_bars = true,
    },
  }

  if knownLazyChildren[rootKey] and knownLazyChildren[rootKey][path[2]] and #path == 2 then
    return true
  end

  local node = {
    key = rootKey,
    name = rootRec.name or rootRec.label or rootKey,
    label = rootRec.label or rootRec.name or rootKey,
    order = rootRec.order or 50,
    parentKey = rootRec.parentKey,
    factory = rootRec.factory,
    meta = type(rootRec.meta) == "table" and rootRec.meta or {},
    rec = rootRec,
  }

  local previousActivePath = ns._PUIActiveOptionsPath
  if rootRec.dynamicOptions == true then
    ns._PUIActiveOptionsPath = path
  end

  local opts = _PUI_CreateProviderOption(node, path)

  if rootRec.dynamicOptions == true then
    ns._PUIActiveOptionsPath = previousActivePath
  end

  local current = opts

  for i = 2, #path do
    local segment = path[i]
    local childRec = registry[segment]

    if type(childRec) == "table" and childRec.parentKey == path[i - 1] then
      current = {
        type = "group",
        name = childRec.name or childRec.label or segment,
        args = {},
      }
    else
      local args = current and current.args
      if type(args) ~= "table" or type(args[segment]) ~= "table" then
        return false
      end
      current = args[segment]
    end
  end

  return true
end

local function _PUI_ConfigStringToPath(configString)
  if type(configString) ~= "string" or configString == "" then
    return nil
  end

  local path = {}
  for raw in string.gmatch(configString, "([^,]+)") do
    local segment = raw and raw:match("^%s*(.-)%s*$") or nil
    if type(segment) ~= "string" or segment == "" then
      return nil
    end
    path[#path + 1] = segment
  end

  return _PUI_CopyOptionsPath(path)
end

_PUI_GetValidatedOptionsPath = function(path)
  path = _PUI_CopyOptionsPath(path)
  if not path or not _PUI_DoesOptionsPathExist(path) then
    return nil
  end

  return path
end

local function _PUI_NormalizeRequestedOptionsPath(request)
  if type(request) == "table" then
    local path = _PUI_GetValidatedOptionsPath(request)
    if path and #path == 1 and _PUI_IsRootRegistryKey(path[1]) then
      return _PUI_GetPreferredRootSelectionPath(path[1]) or path
    end
    return path
  end

  if type(request) ~= "string" or request == "" then
    return nil
  end

  if string.find(request, ",", 1, true) then
    local path = _PUI_GetValidatedOptionsPath(_PUI_ConfigStringToPath(request))
    if path and #path == 1 and _PUI_IsRootRegistryKey(path[1]) then
      return _PUI_GetPreferredRootSelectionPath(path[1]) or path
    end
    return path
  end

  if _PUI_IsRootRegistryKey(request) then
    return _PUI_GetPreferredRootSelectionPath(request)
  end

  return _PUI_GetValidatedOptionsPath(_PUI_GetSectionPath(request))
end

_PUI_GetStoredOptionsPath = function()
  local path = _PUI_GetValidatedOptionsPath(_PUI_GetOptionsStateDB().lastOptionsPath)

  if path and #path == 1 and _PUI_IsRootRegistryKey(path[1]) then
    return _PUI_GetPreferredRootSelectionPath(path[1]) or path
  end

  return path
end

local function _PUI_OptionsPathsEqual(a, b)
  if not a or not b or #a ~= #b then
    return false
  end

  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end

  return true
end

local function _PUI_RecordOptionsHistory(path)
  path = _PUI_GetValidatedOptionsPath(path)
  if not path or State.optionsHistoryNavigating == true then
    return
  end

  local frame = Addon._OptionsWindow
  if not (frame and frame:IsShown()) or frame.__puiRenderingOptionsPath then
    return
  end

  local history = State.optionsHistory
  if type(history) ~= "table" then
    history = {}
    State.optionsHistory = history
    State.optionsHistoryIndex = 0
  end

  local index = tonumber(State.optionsHistoryIndex) or 0
  local current = history[index]

  if current and _PUI_OptionsPathsEqual(current, path) then
    return
  end

  for i = #history, index + 1, -1 do
    history[i] = nil
  end

  history[#history + 1] = _PUI_CopyOptionsPath(path)
  State.optionsHistoryIndex = #history
end

local function _PUI_NavigateOptionsHistory(direction)
  local history = State.optionsHistory
  local index = tonumber(State.optionsHistoryIndex) or 0

  if type(history) ~= "table" or index < 1 then
    return false
  end

  local targetIndex = index + direction

  while targetIndex >= 1 and targetIndex <= #history do
    local targetPath = _PUI_GetValidatedOptionsPath(history[targetIndex])

    if targetPath then
      State.optionsHistoryIndex = targetIndex
      State.optionsHistoryNavigating = true
      Addon:OpenOptions(targetPath, false, true)
      State.optionsHistoryNavigating = nil
      return true
    end

    targetIndex = targetIndex + direction
  end

  return false
end

_PUI_GetCurrentOptionsPath = function()
  return _PUI_GetValidatedOptionsPath(State.currentOptionsPath)
end

_PUI_GetFallbackOptionsPath = function()
  local fallbackKey = _PUI_GetFirstSelectableRegistryKey()
  if not fallbackKey then
    return nil
  end

  return _PUI_GetPreferredRootSelectionPath(fallbackKey) or _PUI_GetValidatedOptionsPath(_PUI_GetSectionPath(fallbackKey))
end

local function _PUI_GetToggleMode(frame, request)
  local requestedPath = _PUI_NormalizeRequestedOptionsPath(request)

  if requestedPath == nil and ((type(request) == "string" and request ~= "") or type(request) == "table") then
    requestedPath = _PUI_GetFallbackOptionsPath()
  end

  if not frame:IsShown() then
    return "Open", requestedPath
  end

  if not requestedPath then
    return "Close"
  end

  if _PUI_OptionsPathsEqual(_PUI_GetCurrentOptionsPath(), requestedPath) then
    return "Close", requestedPath
  end

  return "Open", requestedPath
end

local PUI_ROOT_NAV_SECTION_ORDER = {
  { key = "General", label = "General" },
  { key = "CombatFrames", label = "Combat UI" },
  { key = "Interface", label = "Interface" },
}

local PUI_ROOT_NAV_SECTION_BY_KEY = {
  GeneralOptions = "General",
  UITheme = "General",
  Quality = "General",

  unitframes = "CombatFrames",
  CooldownManager = "CombatFrames",
  PRD = "CombatFrames",
  ACTIONBARS = "CombatFrames",
  PLAYER_BUFFS = "CombatFrames",
  DamageMeters = "CombatFrames",

  Chat = "Interface",
  Minimap = "Interface",
  Dragonriding = "Interface",
  Profiles = "General",
}

local PUI_ROOT_NAV_ITEM_ORDER = {
  unitframes = 10,
  CooldownManager = 20,
  PRD = 30,
  ACTIONBARS = 40,
  PLAYER_BUFFS = 50,
  Profiles = 10000,
}

local PUI_ROOT_NAV_GLYPH_BY_KEY = {
  GeneralOptions = "Sc",
  UITheme = "Th",
  unitframes = "UF",
  PLAYER_BUFFS = "PB",
  PRD = "RD",
  ACTIONBARS = "AB",
  CooldownManager = "CD",
  DamageMeters = "DM",
  Chat = "CH",
  Minimap = "MM",
  Dragonriding = "SK",
  Quality = "QL",
  Profiles = "PR",
}

local function _PUI_InsertRootNavSections(nodes)
  if type(nodes) ~= "table" or #nodes == 0 then
    return nodes or {}
  end

  local grouped = {}
  local used = {}

  for i = 1, #nodes do
    local node = nodes[i]
    local sectionKey = PUI_ROOT_NAV_SECTION_BY_KEY[node and node.key] or "Other"

    grouped[sectionKey] = grouped[sectionKey] or {}
    grouped[sectionKey][#grouped[sectionKey] + 1] = node
  end

  for _, list in pairs(grouped) do
    table.sort(list, function(a, b)
      local aOrder = PUI_ROOT_NAV_ITEM_ORDER[a.key] or tonumber(a.order) or 50
      local bOrder = PUI_ROOT_NAV_ITEM_ORDER[b.key] or tonumber(b.order) or 50

      if aOrder == bOrder then
        return tostring(a.label or a.name or a.key) < tostring(b.label or b.name or b.key)
      end

      return aOrder < bOrder
    end)
  end

  local out = {}

  for i = 1, #PUI_ROOT_NAV_SECTION_ORDER do
    local section = PUI_ROOT_NAV_SECTION_ORDER[i]
    local list = grouped[section.key]

    if list and #list > 0 then
      out[#out + 1] = {
        key = "__pui_nav_header_" .. section.key,
        name = section.label,
        label = section.label,
        order = (tonumber(list[1] and list[1].order) or (i * 100)) - 0.5,
        parentKey = nil,
        factory = nil,
        meta = {
          navHeader = true,
          navHeight = 22,
          navGap = 8,
        },
        rec = nil,
      }

      for j = 1, #list do
        out[#out + 1] = list[j]
      end

      used[section.key] = true
    end
  end

  for sectionKey, list in pairs(grouped) do
    if not used[sectionKey] and list and #list > 0 then
      out[#out + 1] = {
        key = "__pui_nav_header_" .. sectionKey,
        name = sectionKey,
        label = sectionKey,
        order = (tonumber(list[1] and list[1].order) or 1000) - 0.5,
        parentKey = nil,
        factory = nil,
        meta = {
          navHeader = true,
          navHeight = 22,
          navGap = 8,
        },
        rec = nil,
      }

      for j = 1, #list do
        out[#out + 1] = list[j]
      end
    end
  end

  return out
end

local function _PUI_NormalizeRootNavSearch(text)
  text = type(text) == "string" and text or ""
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  if text == "" or string.len(text) < 2 then
    return ""
  end

  return string.lower(text)
end

local function _PUI_SearchValue(value)
  local valueType = type(value)
  if valueType == "string" or valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end
  return ""
end

local function _PUI_CopySearchPath(path)
  local out = {}
  if type(path) == "table" then
    for i = 1, #path do
      out[i] = path[i]
    end
  end
  return out
end

local function _PUI_CopySearchPathWith(path, key)
  local out = _PUI_CopySearchPath(path)
  out[#out + 1] = key
  return out
end

local function _PUI_GetOptionSearchName(key, opt)
  local name = opt and opt.name
  if type(name) == "string" and name ~= "" then
    return name
  end

  local label = opt and opt.label
  if type(label) == "string" and label ~= "" then
    return label
  end

  return tostring(key or "")
end

local function _PUI_GetRootNavNodeSearchText(node)
  local meta = node and node.meta
  if type(meta) ~= "table" then
    meta = node and node.rec and node.rec.meta or nil
  end
  if type(meta) ~= "table" then
    meta = {}
  end

  return string.lower(table.concat({
    _PUI_SearchValue(node and node.key),
    _PUI_SearchValue(node and node.name),
    _PUI_SearchValue(node and node.label),
    _PUI_SearchValue(node and PUI_ROOT_NAV_GLYPH_BY_KEY[node.key]),
    _PUI_SearchValue(meta.navDescription),
    _PUI_SearchValue(meta.pageDescription),
    _PUI_SearchValue(meta.description),
    _PUI_SearchValue(meta.pageHelp),
    _PUI_SearchValue(meta.helpText),
    _PUI_SearchValue(meta.help),
  }, " "))
end

local function _PUI_GetOptionNodeSearchText(key, opt, labelPath)
  return string.lower(table.concat({
    _PUI_SearchValue(key),
    _PUI_SearchValue(opt and opt.type),
    _PUI_SearchValue(_PUI_GetOptionSearchName(key, opt)),
    _PUI_SearchValue(opt and opt.desc),
    _PUI_SearchValue(opt and opt.description),
    _PUI_SearchValue(opt and opt.pageDescription),
    _PUI_SearchValue(opt and opt.helpText),
    _PUI_SearchValue(opt and opt.help),
    table.concat(labelPath or {}, " "),
  }, " "))
end

local function _PUI_SearchTextMatches(text, searchText)
  for token in string.gmatch(searchText, "%S+") do
    if not text:find(token, 1, true) then
      return false
    end
  end

  return true
end

local function _PUI_FilterRootRegistryNavNodes(nodes, searchText)
  searchText = _PUI_NormalizeRootNavSearch(searchText)

  if searchText == "" then
    return nodes
  end

  local out = {}

  for i = 1, #nodes do
    local node = nodes[i]
    if _PUI_SearchTextMatches(_PUI_GetRootNavNodeSearchText(node), searchText) then
      out[#out + 1] = node
    end
  end

  return out
end

local function _PUI_InsertRootNavSearchHeader(nodes)
  if type(nodes) ~= "table" or #nodes == 0 then
    return nodes or {}
  end

  local out = {
    {
      key = "__pui_nav_header_search",
      name = "Search Results",
      label = "Search Results",
      order = 0,
      parentKey = nil,
      factory = nil,
      meta = {
        navHeader = true,
        navHeight = 22,
        navGap = 8,
      },
      rec = nil,
    },
  }

  for i = 1, #nodes do
    out[#out + 1] = nodes[i]
  end

  return out
end

local function _PUI_GetSearchRenderPath(path)
  path = _PUI_CopySearchPath(path)

  if not path then
    return nil
  end

  if #path > 2 then
    return { path[1], path[2] }
  end

  return path
end

local function _PUI_AddDeepOptionsSearchResults(results, seen, rootNode, opt, key, path, labelPath, parentPath, parentLabels, searchText, depth)
  if type(opt) ~= "table" or depth > 12 or opt.hidden == true then
    return
  end

  local isGroup = opt.type == "group" or type(opt.args) == "table"
  local optionName = _PUI_GetOptionSearchName(key, opt)
  local optionPath = _PUI_CopySearchPathWith(path, key)
  local optionLabels = _PUI_CopySearchPath(parentLabels)
  optionLabels[#optionLabels + 1] = optionName
  local searchTextBlob = _PUI_GetOptionNodeSearchText(key, opt, optionLabels)
  local matchesSearch = _PUI_SearchTextMatches(searchTextBlob, searchText)

  if isGroup and matchesSearch then
    local targetKey = table.concat(optionPath, "\031")
    local resultKey = "__pui_search_group_" .. targetKey

    if not seen[resultKey] then
      local description = _PUI_SearchValue(opt.desc)
      if description == "" then
        description = _PUI_SearchValue(opt.description)
      end
      if description == "" then
        description = _PUI_SearchValue(opt.pageDescription)
      end
      if description == "" then
        description = "Open " .. table.concat(optionLabels, " / ")
      end

      results[#results + 1] = {
        key = resultKey,
        name = table.concat(optionLabels, " / "),
        label = table.concat(optionLabels, " / "),
        order = 1000 + #results,
        parentKey = nil,
        factory = nil,
        meta = {
          navDescription = description,
          pageDescription = description,
          pageHelp = "Open this settings group.",
          navHeight = 62,
          navGap = 5,
          searchResult = true,
        },
        rec = nil,
        __puiRenderPath = _PUI_GetSearchRenderPath(optionPath),
        __puiSelectPath = optionPath,
        __puiTargetPath = optionPath,
      }

      seen[resultKey] = true
    end
  elseif matchesSearch and PUI_COLUMN_WIDTH_OPTION_TYPES[opt.type] == true then
    local targetKey = table.concat(optionPath, "\031")
    local resultKey = "__pui_search_option_" .. targetKey

    if not seen[resultKey] then
      local breadcrumb = table.concat(optionLabels, " / ")
      local description = _PUI_SearchValue(opt.desc)
      if description == "" then
        description = _PUI_SearchValue(opt.description)
      end
      if description == "" then
        description = breadcrumb
      end

      results[#results + 1] = {
        key = resultKey,
        name = optionName,
        label = optionName,
        order = 2000 + #results,
        parentKey = nil,
        factory = nil,
        meta = {
          navDescription = breadcrumb,
          pageDescription = description,
          pageHelp = "Open and highlight this setting.",
          navHeight = 62,
          navGap = 5,
          searchResult = true,
        },
        rec = nil,
        __puiRenderPath = _PUI_GetSearchRenderPath(parentPath),
        __puiSelectPath = _PUI_CopySearchPath(parentPath),
        __puiFocusOptionKey = key,
      }

      seen[resultKey] = true
    end
  end

  if not isGroup or type(opt.args) ~= "table" then
    return
  end

  local childNodes = {}
  for childKey, childOpt in pairs(opt.args) do
    if type(childKey) == "string" and type(childOpt) == "table" then
      childNodes[#childNodes + 1] = {
        key = childKey,
        opt = childOpt,
        order = tonumber(childOpt.order) or 50,
        name = _PUI_GetOptionSearchName(childKey, childOpt),
      }
    end
  end

  table.sort(childNodes, function(a, b)
    if a.order == b.order then
      return tostring(a.name) < tostring(b.name)
    end
    return a.order < b.order
  end)

  for i = 1, #childNodes do
    local child = childNodes[i]
    _PUI_AddDeepOptionsSearchResults(results, seen, rootNode, child.opt, child.key, optionPath, optionLabels, optionPath, optionLabels, searchText, depth + 1)
  end
end

local function _PUI_GetRootRegistryNavNodes(searchText)
  searchText = _PUI_NormalizeRootNavSearch(searchText)

  local roots = {}
  for _, node in ipairs(_PUI_GetSortedRegistryNodes()) do
    if not node.parentKey or node.parentKey == "" then
      roots[#roots + 1] = node
    end
  end

  if searchText == "" then
    return _PUI_InsertRootNavSections(roots)
  end

  local results = {}
  local seen = {}

  for _, node in ipairs(_PUI_FilterRootRegistryNavNodes(roots, searchText)) do
    local resultKey = "__pui_search_root_" .. node.key
    local meta = node.meta

    results[#results + 1] = {
      key = resultKey,
      name = node.label,
      label = node.label,
      order = 100 + #results,
      parentKey = nil,
      factory = nil,
      meta = {
        navDescription = meta.navDescription or meta.pageDescription or meta.description or "",
        pageDescription = meta.pageDescription or meta.navDescription or meta.description or "",
        pageHelp = meta.pageHelp or meta.helpText or meta.help or "Open this page.",
        navHeight = 62,
        navGap = 5,
        searchResult = true,
      },
      rec = nil,
      __puiTargetPath = { node.key },
    }

    seen[resultKey] = true
  end

  for _, node in ipairs(roots) do
    local option = _PUI_CreateProviderOption(node)
    if type(option.args) == "table" then
      local rootName = node.label
      local rootPath = { node.key }
      local rootLabels = { rootName }

      for childKey, childOpt in pairs(option.args) do
        if type(childKey) == "string" and type(childOpt) == "table" then
          _PUI_AddDeepOptionsSearchResults(results, seen, node, childOpt, childKey, rootPath, rootLabels, rootPath, rootLabels, searchText, 1)
        end
      end
    end
  end

  table.sort(results, function(a, b)
    if a.order == b.order then
      return tostring(a.label) < tostring(b.label)
    end
    return a.order < b.order
  end)

  return _PUI_InsertRootNavSearchHeader(results)
end

local function _PUI_GetSelectedRootRegistryKeyFromPath(path)
  path = _PUI_CopyOptionsPath(path)
  return type(path) == "table" and path[1] or nil
end

local function _PUI_GetSelectedRootRegistryKey()
  local path = _PUI_GetCurrentOptionsPath() or _PUI_GetStoredOptionsPath() or _PUI_GetFallbackOptionsPath()
  return _PUI_GetSelectedRootRegistryKeyFromPath(path)
end

local function _PUI_GetRootNavMeta(node)
  return node.meta
end

local function _PUI_ClearForeignRootNavArt(btn)
  for _, region in ipairs({ btn:GetRegions() }) do
    if region:GetObjectType() == "Texture" and not region.__puiRootNavOwned then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end
end

local function _PUI_EnsureRootNavButton(btn)
  if btn.__puiRootNavReady then
    return
  end

  btn.__puiRootNavReady = true
  btn:SetText("")
  _PUI_ClearForeignRootNavArt(btn)

  btn.__puiRootNavHover = btn:CreateTexture(nil, "BORDER")
  btn.__puiRootNavHover.__puiRootNavOwned = true
  btn.__puiRootNavHover:SetAllPoints(btn)
  btn.__puiRootNavHover:SetTexture("Interface\\Buttons\\WHITE8x8")
  btn.__puiRootNavHover:SetAlpha(0)

  btn.__puiRootNavSelected = btn:CreateTexture(nil, "ARTWORK")
  btn.__puiRootNavSelected.__puiRootNavOwned = true
  btn.__puiRootNavSelected:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
  btn.__puiRootNavSelected:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
  btn.__puiRootNavSelected:SetWidth(3)
  btn.__puiRootNavSelected:SetTexture("Interface\\Buttons\\WHITE8x8")

  btn.__puiRootNavIconBack = btn:CreateTexture(nil, "ARTWORK")
  btn.__puiRootNavIconBack.__puiRootNavOwned = true
  btn.__puiRootNavIconBack:SetTexture("Interface\\Buttons\\WHITE8x8")
  btn.__puiRootNavIconBack:SetSize(24, 24)
  btn.__puiRootNavIconBack:SetPoint("LEFT", btn, "LEFT", 12, 0)

  btn.__puiRootNavIcon = btn:CreateTexture(nil, "OVERLAY")
  btn.__puiRootNavIcon.__puiRootNavOwned = true
  btn.__puiRootNavIcon:SetSize(18, 18)
  btn.__puiRootNavIcon:SetPoint("CENTER", btn.__puiRootNavIconBack, "CENTER", 0, 0)
  btn.__puiRootNavIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  btn.__puiRootNavGlyph = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.__puiRootNavGlyph.__puiOptionsFontOwned = true
  btn.__puiRootNavGlyph:SetPoint("CENTER", btn.__puiRootNavIconBack, "CENTER", 0, 0)
  btn.__puiRootNavGlyph:SetJustifyH("CENTER")
  btn.__puiRootNavGlyph:SetJustifyV("MIDDLE")

  btn.__puiRootNavLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.__puiRootNavLabel.__puiOptionsFontOwned = true
  btn.__puiRootNavLabel:SetJustifyH("LEFT")
  btn.__puiRootNavLabel:SetJustifyV("MIDDLE")
  btn.__puiRootNavLabel:SetWordWrap(false)
  if btn.__puiRootNavLabel.SetMaxLines then
    btn.__puiRootNavLabel:SetMaxLines(1)
  end

  btn.__puiRootNavDescription = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  btn.__puiRootNavDescription.__puiOptionsFontOwned = true
  btn.__puiRootNavDescription:SetJustifyH("LEFT")
  btn.__puiRootNavDescription:SetJustifyV("TOP")
  btn.__puiRootNavDescription:SetWordWrap(false)
  if btn.__puiRootNavDescription.SetMaxLines then
    btn.__puiRootNavDescription:SetMaxLines(1)
  end

  btn.__puiRootNavBadge = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  btn.__puiRootNavBadge.__puiOptionsFontOwned = true
  btn.__puiRootNavBadge:SetJustifyH("RIGHT")
  btn.__puiRootNavBadge:SetJustifyV("MIDDLE")

  ns.Theme.ApplyFont(btn.__puiRootNavGlyph, "nav", 11)
  ns.Theme.ApplyFont(btn.__puiRootNavLabel, "nav", 12)
  ns.Theme.ApplyFont(btn.__puiRootNavDescription, "tiny", 10)
  ns.Theme.ApplyFont(btn.__puiRootNavBadge, "tiny", 9)
end

local function _PUI_StyleRootNavButton(btn, node, isSelected)
  _PUI_EnsureRootNavButton(btn)

  local colors = ns.Theme.GetColors()
  local fill = colors.control
  local accent = colors.accent
  local border = colors.border
  local text = colors.text
  local meta = node.meta

  if meta.navHeader == true then
    ns.Theme.SetSquareBackdrop(btn, {
      bg = { 0, 0, 0, 0 },
      border = { 0, 0, 0, 0 },
    }, 1)

    btn.__puiDisabled = true
    btn:EnableMouse(false)
    btn:SetAlpha(1)

    btn.__puiRootNavSelected:Hide()
    btn.__puiRootNavHover:Hide()
    btn.__puiRootNavIconBack:Hide()
    btn.__puiRootNavIcon:Hide()
    btn.__puiRootNavGlyph:Hide()
    btn.__puiRootNavDescription:Hide()
    btn.__puiRootNavBadge:Hide()

    btn.__puiRootNavLabel:ClearAllPoints()
    btn.__puiRootNavLabel:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btn.__puiRootNavLabel:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.__puiRootNavLabel:SetText(string.upper(node.label))
    btn.__puiRootNavLabel:SetTextColor(accent[1], accent[2], accent[3], 0.78)
    return
  end

  local disabled = meta.disabled == true or meta.comingSoon == true
  local hovered = btn.__puiRootNavHovered == true
  local bgAlpha = isSelected and 0.92 or 0.58
  local borderAlpha = isSelected and 0.92 or 0.34
  local borderColor = (isSelected or (hovered and not disabled)) and accent or border

  if hovered and not disabled then
    bgAlpha = isSelected and 0.98 or 0.74
    borderAlpha = isSelected and 1.0 or 0.70
  end

  ns.Theme.SetSquareBackdrop(btn, {
    bg = { fill[1], fill[2], fill[3], bgAlpha },
    border = { borderColor[1], borderColor[2], borderColor[3], borderAlpha },
  }, ns.Theme.GetEdgeSize())

  btn.__puiDisabled = disabled
  btn:EnableMouse(true)
  btn:SetAlpha(disabled and 0.42 or 1)

  btn.__puiRootNavSelected:SetVertexColor(accent[1], accent[2], accent[3], isSelected and 1 or 0)
  btn.__puiRootNavSelected:SetShown(isSelected)

  btn.__puiRootNavHover:SetVertexColor(accent[1], accent[2], accent[3], hovered and 0.10 or 0)
  btn.__puiRootNavHover:SetShown(hovered and not disabled)

  btn.__puiRootNavIconBack:SetVertexColor(accent[1], accent[2], accent[3], isSelected and 0.26 or 0.11)

  local iconAtlas = meta.navAtlas or meta.iconAtlas
  local iconPath = meta.navIcon or meta.icon

  if iconAtlas then
    btn.__puiRootNavIcon:SetAtlas(iconAtlas, true)
    btn.__puiRootNavIcon:SetSize(18, 18)
    btn.__puiRootNavIcon:SetVertexColor(1, 1, 1, disabled and 0.45 or 0.95)
    btn.__puiRootNavIcon:Show()
    btn.__puiRootNavGlyph:Hide()
  elseif iconPath then
    btn.__puiRootNavIcon:SetTexture(iconPath)
    btn.__puiRootNavIcon:SetSize(18, 18)
    btn.__puiRootNavIcon:SetVertexColor(1, 1, 1, disabled and 0.45 or 0.95)
    btn.__puiRootNavIcon:Show()
    btn.__puiRootNavGlyph:Hide()
  else
    btn.__puiRootNavIcon:SetTexture(nil)
    btn.__puiRootNavIcon:Hide()
    btn.__puiRootNavGlyph:SetText(PUI_ROOT_NAV_GLYPH_BY_KEY[node.key] or string.sub(node.label, 1, 2))
    btn.__puiRootNavGlyph:SetTextColor(accent[1], accent[2], accent[3], disabled and 0.45 or 0.95)
    btn.__puiRootNavGlyph:Show()
  end

  local desc = meta.navDescription or meta.description or ""
  local badgeText = meta.comingSoon and "Soon" or (meta.navBadge or "")
  local badgeShown = badgeText ~= ""

  btn.__puiRootNavLabel:SetText(node.label)
  btn.__puiRootNavDescription:SetText(desc)
  btn.__puiRootNavDescription:SetShown(desc ~= "")

  btn.__puiRootNavLabel:SetTextColor(text[1], text[2], text[3], disabled and 0.45 or (isSelected and text[4] or text[4] * 0.84))
  btn.__puiRootNavDescription:SetTextColor(text[1], text[2], text[3], disabled and 0.32 or text[4] * 0.48)
  btn.__puiRootNavBadge:SetTextColor(accent[1], accent[2], accent[3], disabled and 0.40 or 0.78)
  btn.__puiRootNavBadge:SetText(badgeText)
  btn.__puiRootNavBadge:SetShown(badgeShown)

  btn.__puiRootNavLabel:ClearAllPoints()
  btn.__puiRootNavDescription:ClearAllPoints()
  btn.__puiRootNavBadge:ClearAllPoints()
  btn.__puiRootNavBadge:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
  btn.__puiRootNavBadge:SetWidth(40)

  local rightAnchor = badgeShown and btn.__puiRootNavBadge or btn
  local rightPoint = badgeShown and "LEFT" or "RIGHT"
  local rightOffset = badgeShown and -6 or -10

  if desc ~= "" then
    btn.__puiRootNavLabel:SetPoint("TOPLEFT", btn.__puiRootNavIconBack, "TOPRIGHT", 10, 4)
    btn.__puiRootNavLabel:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
    btn.__puiRootNavDescription:SetPoint("TOPLEFT", btn.__puiRootNavLabel, "BOTTOMLEFT", 0, -2)
    btn.__puiRootNavDescription:SetPoint("RIGHT", btn.__puiRootNavLabel, "RIGHT", 0, 0)
    btn.__puiRootNavDescription:SetHeight(26)
  else
    btn.__puiRootNavLabel:SetPoint("LEFT", btn.__puiRootNavIconBack, "RIGHT", 10, 0)
    btn.__puiRootNavLabel:SetPoint("RIGHT", rightAnchor, rightPoint, rightOffset, 0)
    btn.__puiRootNavDescription:Hide()
  end
end

local function _PUI_GetRootNavSignature(nodes)
  local parts = {}

  for i = 1, #nodes do
    local node = nodes[i]
    local meta = node.meta
    parts[#parts + 1] = table.concat({
      tostring(node.key),
      tostring(node.label),
      tostring(node.order),
      tostring(meta.navHeight or ""),
      tostring(meta.navGap or ""),
      tostring(meta.navBadge or ""),
      tostring(meta.navHeader == true),
      tostring(meta.disabled == true),
      tostring(meta.comingSoon == true),
    }, "\030")
  end

  return table.concat(parts, "\031")
end

local function _PUI_ScrollRootNavButtonIntoView(frame, button)
  local scroll = frame.__puiRootNavScroll
  local host = frame.__puiRootNavHost
  if not (scroll and host and button and button:IsShown()) then
    return
  end

  local hostTop = host:GetTop()
  local buttonTop = button:GetTop()
  local buttonBottom = button:GetBottom()
  local viewportHeight = scroll:GetHeight()
  if not hostTop or not buttonTop or not buttonBottom or viewportHeight <= 0 then
    return
  end

  local current = scroll:GetVerticalScroll()
  local topOffset = hostTop - buttonTop
  local bottomOffset = hostTop - buttonBottom
  local target

  if topOffset < current then
    target = topOffset
  elseif bottomOffset > current + viewportHeight then
    target = bottomOffset - viewportHeight
  end

  if target then
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), target)))
  end
end

local function _PUI_UpdateRootNavSelection(frame, selectedKey)
  frame.__puiRootNavSelectedKey = selectedKey

  local selectedButton
  for _, btn in ipairs(frame.__puiRootNavHost.__puiButtons) do
    if btn.__puiNode and btn:IsShown() then
      local isSelected = btn.__puiSectionKey == selectedKey
      _PUI_StyleRootNavButton(btn, btn.__puiNode, isSelected)
      if isSelected then
        selectedButton = btn
      end
    end
  end

  _PUI_ScrollRootNavButtonIntoView(frame, selectedButton)
end

local function _PUI_RefreshRootRegistryNav(frame)

  if not frame.__puiRootNavSearch then
    local search = CreateFrame("EditBox", nil, frame.__puiNavShell, "BackdropTemplate")
    search:SetAutoFocus(false)
    search:SetHeight(30)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(10, 10, 0, 0)
    search:SetMaxLetters(64)
    search.__puiOptionsFontOwned = true

    search.__puiPlaceholder = search:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    search.__puiPlaceholder.__puiOptionsFontOwned = true
    search.__puiPlaceholder:SetPoint("LEFT", search, "LEFT", 10, 0)
    search.__puiPlaceholder:SetPoint("RIGHT", search, "RIGHT", -10, 0)
    search.__puiPlaceholder:SetJustifyH("LEFT")
    search.__puiPlaceholder:SetText("Search settings... 2+ letters")

    ns.Theme.ApplyFont(search.__puiPlaceholder, "tiny", 10)

    search:SetScript("OnEditFocusGained", function(self)
      self.__puiPlaceholder:SetShown(self:GetText() == "")
    end)

    search:SetScript("OnEditFocusLost", function(self)
      self.__puiPlaceholder:SetShown(self:GetText() == "")
    end)

    search:SetScript("OnEscapePressed", function(self)
      if self:GetText() ~= "" then
        self:SetText("")
      else
        self:ClearFocus()
      end
    end)

    search:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()

      if _PUI_NormalizeRootNavSearch(self:GetText()) == "" then
        return
      end

      local host = frame.__puiRootNavHost
      if not host then
        return
      end

      for i = 1, #host.__puiButtons do
        local button = host.__puiButtons[i]
        local node = button and button.__puiNode
        local meta = node and _PUI_GetRootNavMeta(node)

        if button
          and button:IsShown()
          and button.__puiDisabled ~= true
          and (not meta or meta.navHeader ~= true)
        then
          button:Click()
          return
        end
      end
    end)

    search:SetScript("OnTextChanged", function(self)
      local text = self:GetText()
      local normalized = _PUI_NormalizeRootNavSearch(text)

      self.__puiPlaceholder:SetShown(text == "")

      if frame.__puiRootNavSearchText == text and frame.__puiRootNavSearchNormalized == normalized then
        return
      end

      frame.__puiRootNavSearchText = text

      if frame.__puiRootNavSearchNormalized == normalized then
        return
      end

      frame.__puiRootNavSearchNormalized = normalized
      frame.__puiRootNavSignature = nil

      if frame.__puiRootNavScroll then
        frame.__puiRootNavScroll:SetVerticalScroll(0)
      end

      _PUI_RefreshRootRegistryNav(frame)
    end)

    frame.__puiRootNavSearch = search
  end

  local search = frame.__puiRootNavSearch
  local searchColors = ns.Theme.GetColors()

  ns.Theme.SetSquareBackdrop(search, {
    bg = searchColors.control,
    border = searchColors.border,
  }, ns.Theme.GetEdgeSize())

  ns.Theme.ApplyFont(search, "body", 11)
  ns.Theme.ApplyFont(search.__puiPlaceholder, "tiny", 10)
  search:SetTextColor(searchColors.text[1], searchColors.text[2], searchColors.text[3], searchColors.text[4])
  search.__puiPlaceholder:SetTextColor(
    searchColors.text[1],
    searchColors.text[2],
    searchColors.text[3],
    searchColors.text[4] * 0.62
  )

  search:SetParent(frame.__puiNavShell)
  search:SetFrameStrata(frame:GetFrameStrata())
  search:SetFrameLevel(frame.__puiNavShell:GetFrameLevel() + 80)
  search:ClearAllPoints()
  search:SetPoint("TOPLEFT", frame.__puiNavShell, "TOPLEFT", 14, -16)
  search:SetPoint("TOPRIGHT", frame.__puiNavShell, "TOPRIGHT", -16, -16)
  search:Show()

  local searchText = frame.__puiRootNavSearchText or ""
  local nodes = _PUI_GetRootRegistryNavNodes(searchText)

  if #nodes == 0 then
    if frame.__puiRootNavHost then
      frame.__puiRootNavHost:Hide()
    end
    if frame.__puiRootNavScroll then
      frame.__puiRootNavScroll:Hide()
    end

    if not frame.__puiRootNavNoResults then
      frame.__puiRootNavNoResults = frame.__puiNavShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      frame.__puiRootNavNoResults.__puiOptionsFontOwned = true
      frame.__puiRootNavNoResults:SetJustifyH("CENTER")
      frame.__puiRootNavNoResults:SetJustifyV("TOP")
      frame.__puiRootNavNoResults:SetWordWrap(true)
    end

    ns.Theme.ApplyFont(frame.__puiRootNavNoResults, "tiny", 10)
    frame.__puiRootNavNoResults:SetTextColor(
      searchColors.text[1],
      searchColors.text[2],
      searchColors.text[3],
      searchColors.text[4] * 0.72
    )

    frame.__puiRootNavNoResults:SetParent(frame.__puiNavShell)
    frame.__puiRootNavNoResults:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 8, -18)
    frame.__puiRootNavNoResults:SetPoint("RIGHT", search, "RIGHT", -8, 0)
    frame.__puiRootNavNoResults:SetText("No settings match your search.")
    frame.__puiRootNavNoResults:Show()
    return
  end

  if frame.__puiRootNavNoResults then
    frame.__puiRootNavNoResults:Hide()
  end

  if not frame.__puiRootNavScroll then
    local scroll = CreateFrame("ScrollFrame", nil, frame.__puiNavShell, "UIPanelScrollFrameTemplate")
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local maxScroll = self:GetVerticalScrollRange()
      local target = self:GetVerticalScroll() - (delta * 42)
      self:SetVerticalScroll(math.max(0, math.min(maxScroll, target)))
    end)

    scroll:SetScript("OnSizeChanged", function(self, width, height)
      local child = self:GetScrollChild()
      width = math.max(120, width - 24)
      local rectKey = tostring(width) .. "\030" .. tostring(math.floor(height + 0.5))

      if child and child.__puiRootNavScrollWidth ~= width then
        child.__puiRootNavScrollWidth = width
        child:SetWidth(width)
      end

      if self.__puiRootNavScrollRectKey ~= rectKey then
        self.__puiRootNavScrollRectKey = rectKey
        self:UpdateScrollChildRect()
      end
    end)

    frame.__puiRootNavScroll = scroll
  end

  local scroll = frame.__puiRootNavScroll
  local navShell = frame.__puiNavShell
  local navShellWidth = math.floor(navShell:GetWidth() + 0.5)
  local navShellHeight = math.floor(navShell:GetHeight() + 0.5)
  local scrollFrameLevel = math.max(navShell:GetFrameLevel() + 40, frame:GetFrameLevel() + 90)
  local scrollChromeKey = table.concat({
    tostring(navShellWidth),
    tostring(navShellHeight),
    tostring(frame:GetFrameStrata() or ""),
    tostring(scrollFrameLevel),
  }, "\030")

  if scroll.__puiRootNavScrollChromeKey ~= scrollChromeKey or scroll:GetParent() ~= navShell then
    scroll.__puiRootNavScrollChromeKey = scrollChromeKey
    scroll:SetParent(navShell)
    scroll:SetFrameStrata(frame:GetFrameStrata())
    scroll:SetFrameLevel(scrollFrameLevel)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", navShell, "TOPLEFT", 14, -58)
    scroll:SetPoint("TOPRIGHT", navShell, "TOPRIGHT", -12, -58)
    scroll:SetPoint("BOTTOM", navShell, "BOTTOM", 0, 16)
    scroll:SetClipsChildren(true)
  end
  scroll:Show()

  if not frame.__puiRootNavHost then
    frame.__puiRootNavHost = CreateFrame("Frame", nil, scroll)
    frame.__puiRootNavHost.__puiButtons = {}
  end

  local host = frame.__puiRootNavHost
  local hostFrameLevel = scroll:GetFrameLevel() + 1
  local hostChromeKey = table.concat({
    scrollChromeKey,
    tostring(scroll:GetFrameStrata() or ""),
    tostring(hostFrameLevel),
  }, "\030")

  if host.__puiRootNavHostChromeKey ~= hostChromeKey or host:GetParent() ~= scroll then
    host.__puiRootNavHostChromeKey = hostChromeKey
    host:SetParent(scroll)
    host:SetFrameStrata(scroll:GetFrameStrata())
    host:SetFrameLevel(hostFrameLevel)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  end

  local hostWidth = math.max(120, scroll:GetWidth() - 24)
  local viewportHeight = scroll:GetHeight()
  local selectedKey = _PUI_GetSelectedRootRegistryKey()
  local navSignature = _PUI_GetRootNavSignature(nodes)

  if host.__puiRootNavWidth ~= hostWidth then
    host.__puiRootNavWidth = hostWidth
    host:SetWidth(hostWidth)
  end

  if scroll:GetScrollChild() ~= host then
    scroll:SetScrollChild(host)
  end

  ns.Theme.WidgetSkins.Scrollbar(scroll.ScrollBar)

  host:EnableMouse(false)
  host:Show()

  if frame.__puiRootNavSignature == navSignature
    and frame.__puiRootNavHostWidth == hostWidth
    and frame.__puiRootNavNodeCount == #nodes
    and host.__puiButtons
    and host.__puiButtons[#nodes]
  then
    host:SetHeight(math.max(viewportHeight, host.__puiRootNavContentHeight or viewportHeight))
    scroll:UpdateScrollChildRect()
    _PUI_UpdateRootNavSelection(frame, selectedKey)
    return
  end

  frame.__puiRootNavSignature = navSignature
  frame.__puiRootNavHostWidth = hostWidth
  frame.__puiRootNavNodeCount = #nodes

  local previous = nil
  local contentHeight = 0

  for i = 1, #nodes do
    local node = nodes[i]
    local meta = _PUI_GetRootNavMeta(node)
    local navHeight = tonumber(meta.navHeight) or 54
    local navGap = tonumber(meta.navGap) or 5
    local btn = host.__puiButtons[i]

    if not btn then
      btn = CreateFrame("Button", nil, host, "BackdropTemplate")
      host.__puiButtons[i] = btn
    end

    btn:SetParent(host)
    btn:SetFrameStrata(host:GetFrameStrata())
    btn:SetFrameLevel((host:GetFrameLevel() or 1) + 1)
    btn:SetHeight(navHeight)
    btn:SetAlpha(1)
    btn:EnableMouse(true)
    btn.__puiSectionKey = node.key
    btn.__puiNode = node

    btn:ClearAllPoints()
    if previous then
      btn:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -navGap)
      btn:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -navGap)
    else
      btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
      btn:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    end

    btn:SetScript("OnEnter", function(self)
      self.__puiRootNavHovered = true
      _PUI_StyleRootNavButton(self, self.__puiNode, self.__puiSectionKey == (frame.__puiRootNavSelectedKey or _PUI_GetSelectedRootRegistryKey()))

      local meta = _PUI_GetRootNavMeta(self.__puiNode)
      if meta.navHeader == true or self.__puiDisabled == true then
        return
      end

      local tooltip = _G.GameTooltip
      if not tooltip then
        return
      end

      local label = self.__puiNode and (self.__puiNode.label or self.__puiNode.name or self.__puiNode.key) or "PleebUI"
      local description = meta.pageDescription or meta.navDescription or meta.description or ""
      local help = meta.pageHelp or meta.helpText or meta.help or ""

      if description == "" and help == "" then
        return
      end

      tooltip:SetOwner(self, "ANCHOR_RIGHT")
      tooltip:SetText(label, 1, 1, 1, 1, true)

      if description ~= "" then
        tooltip:AddLine(description, 0.78, 0.78, 0.82, true)
      end

      if help ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine(help, 0.55, 0.68, 0.86, true)
      end

      tooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
      self.__puiRootNavHovered = false

      local tooltip = _G.GameTooltip
      if tooltip then
        tooltip:Hide()
      end

      _PUI_StyleRootNavButton(self, self.__puiNode, self.__puiSectionKey == (frame.__puiRootNavSelectedKey or _PUI_GetSelectedRootRegistryKey()))
    end)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function(self)
      if self.__puiDisabled then
        return
      end

      local node = self.__puiNode
      local meta = node and _PUI_GetRootNavMeta(node)

      if (not meta or meta.searchResult ~= true)
        and self.__puiSectionKey == _PUI_GetSelectedRootRegistryKey()
      then
        local homePath = _PUI_GetRootHomeSelectionPath(self.__puiSectionKey)
        if homePath and #homePath > 0 then
          Addon:OpenOptions(homePath, false, true)
        end
        return
      end

      if meta and meta.searchResult == true then
        local search = frame.__puiRootNavSearch
        if search then
          search:ClearFocus()
        end
      end

      if node and type(node.__puiRenderPath) == "table" and #node.__puiRenderPath > 0 then
        local renderPath = _PUI_CopyOptionsPath(node.__puiRenderPath)
        local selectPath = _PUI_CopyOptionsPath(node.__puiSelectPath or node.__puiRenderPath)
        local targetPath = selectPath or renderPath

        if node.__puiFocusOptionKey ~= nil then
          ns.PreviewBox.NavigateToOption(
            Addon,
            targetPath,
            nil,
            node.__puiFocusOptionKey
          )
        else
          Addon:OpenOptions(targetPath, false, true)
        end
        return
      end

      if node and type(node.__puiTargetPath) == "table" and #node.__puiTargetPath > 0 then
        Addon:OpenOptions(node.__puiTargetPath, false, true)
        return
      end

      local targetPath = _PUI_GetPreferredRootSelectionPath(self.__puiSectionKey)
      if targetPath and #targetPath > 0 then
        Addon:OpenOptions(targetPath, false, true)
      else
        Addon:OpenOptions(self.__puiSectionKey, false, true)
      end
    end)

    _PUI_StyleRootNavButton(btn, node, node.key == selectedKey)
    btn:Show()

    contentHeight = contentHeight + navHeight
    if i > 1 then
      contentHeight = contentHeight + navGap
    end

    previous = btn
  end

  for i = #nodes + 1, #host.__puiButtons do
    local btn = host.__puiButtons[i]
    btn:Hide()
    btn:ClearAllPoints()
  end

  local finalHeight = contentHeight + 4
  host.__puiRootNavContentHeight = finalHeight
  host:SetHeight(math.max(viewportHeight, finalHeight))
  frame.__puiRootNavSelectedKey = selectedKey

  scroll:UpdateScrollChildRect()

  for _, button in ipairs(host.__puiButtons) do
    if button:IsShown() and button.__puiSectionKey == selectedKey then
      _PUI_ScrollRootNavButtonIntoView(frame, button)
      break
    end
  end
end

local function _PUI_RememberLastSectionFromPath(path)
  path = _PUI_GetValidatedOptionsPath(path)
  if not path then
    return
  end

  local db = _PUI_GetOptionsStateDB()
  if db then
    db.lastOptionsPath = path
    db.lastOptionsPathByRoot = db.lastOptionsPathByRoot or {}
    db.lastOptionsPathByRoot[path[1]] = _PUI_CopyOptionsPath(path)
  end
end


_PUI_GetOptionsStateDB = function()
  local globalPUI = Addon.db.global.pui
  globalPUI.optionsState = globalPUI.optionsState or {}
  globalPUI.optionsState.lastOptionsSection = nil
  return globalPUI.optionsState
end

local PUI_OPTIONS_WINDOW_DEFAULT_WIDTH = 1024
local PUI_OPTIONS_WINDOW_DEFAULT_HEIGHT = 768
local PUI_OPTIONS_WINDOW_MIN_WIDTH = 800
local PUI_OPTIONS_WINDOW_MIN_HEIGHT = 600
local PUI_OPTIONS_WINDOW_SCREEN_MARGIN = 50

local function _PUI_GetOptionsWindowDB()
  local globalPUI = Addon.db.global.pui
  globalPUI.optionsWindow = globalPUI.optionsWindow or {}
  return globalPUI.optionsWindow
end

local function _PUI_GetOptionsWindowSize()
  local db = _PUI_GetOptionsWindowDB()
  return tonumber(db.optionsWindowWidth) or PUI_OPTIONS_WINDOW_DEFAULT_WIDTH,
    tonumber(db.optionsWindowHeight) or PUI_OPTIONS_WINDOW_DEFAULT_HEIGHT
end

local function _PUI_GetOptionsWindowResizeBounds(frame)
  local screenWidth, screenHeight = UIParent:GetSize()
  local scale = frame and frame:GetScale() or ns.Theme.GetOptionsUIScale()
  local maxWidth = math.max(1, (screenWidth - PUI_OPTIONS_WINDOW_SCREEN_MARGIN) / scale)
  local maxHeight = math.max(1, (screenHeight - PUI_OPTIONS_WINDOW_SCREEN_MARGIN) / scale)
  local minWidth = math.min(PUI_OPTIONS_WINDOW_MIN_WIDTH, maxWidth)
  local minHeight = math.min(PUI_OPTIONS_WINDOW_MIN_HEIGHT, maxHeight)

  return minWidth, minHeight, maxWidth, maxHeight
end

local function _PUI_GetDefaultOptionsWindowSize(frame)
  local width, height = _PUI_GetOptionsWindowSize()
  local minWidth, minHeight, maxWidth, maxHeight = _PUI_GetOptionsWindowResizeBounds(frame)

  width = math.max(minWidth, math.min(maxWidth, width))
  height = math.max(minHeight, math.min(maxHeight, height))

  return width, height
end

local function _PUI_ClampOptionsWindowBounds(width, height, frame)
  local defaultWidth, defaultHeight = _PUI_GetDefaultOptionsWindowSize(frame)
  local minWidth, minHeight, maxWidth, maxHeight = _PUI_GetOptionsWindowResizeBounds(frame)

  width = math.max(minWidth, math.min(maxWidth, tonumber(width) or defaultWidth))
  height = math.max(minHeight, math.min(maxHeight, tonumber(height) or defaultHeight))

  return width, height
end

local function _PUI_UpdateOptionsWindowSize(frame, appName)
  local minWidth, minHeight, maxWidth, maxHeight = _PUI_GetOptionsWindowResizeBounds(frame)

  if frame then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  end

  LibStub("AceConfigDialog-3.0"):SetDefaultSize(appName, _PUI_GetDefaultOptionsWindowSize(frame))
end

local function _PUI_SaveOptionsWindowState(frame)
  local db = _PUI_GetOptionsWindowDB()
  local width, height = _PUI_ClampOptionsWindowBounds(frame:GetWidth(), frame:GetHeight(), frame)

  db.optionsWindowPoint = nil
  db.optionsWindowRelativePoint = nil
  db.optionsWindowX = nil
  db.optionsWindowY = nil
  db.optionsWindowLeft = nil
  db.optionsWindowTop = nil
  db.optionsWindowWidth = width
  db.optionsWindowHeight = height
end

local function _PUI_RestoreOptionsWindowState(frame)
  local db = _PUI_GetOptionsWindowDB()
  local width, height = _PUI_ClampOptionsWindowBounds(db.optionsWindowWidth, db.optionsWindowHeight, frame)

  frame:SetSize(width, height)

  if not frame:GetPoint(1) then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

local function _PUI_FitOptionsWindowToScreen(frame)
  local _, _, maxWidth, maxHeight = _PUI_GetOptionsWindowResizeBounds(frame)
  local width = frame:GetWidth()
  local height = frame:GetHeight()

  if width <= maxWidth and height <= maxHeight then
    return false
  end

  frame:SetSize(math.min(width, maxWidth), math.min(height, maxHeight))
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  return true
end

local function _PUI_StopOptionsWindowDrag(frame)
  frame:StopMovingOrSizing()
  _PUI_SaveOptionsWindowState(frame)
end

local function _PUI_StyleHeaderActionButton(btn)
  ns.Theme.WidgetSkins.UIButton(btn)

  local fs = btn:GetFontString()
  fs.__puiOptionsFontOwned = true
  ns.Theme.ApplyFont(fs, "body", 10)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -1)
  fs:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, 1)
  fs:SetJustifyH("CENTER")
  fs:SetJustifyV("MIDDLE")
end

local function _PUI_CreateHeaderButton(parent, width, text, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 30)
  btn:SetText(text)
  btn.__puiHeaderAction = true

  if onClick then
    btn:SetScript("OnClick", onClick)
  end

  _PUI_StyleHeaderActionButton(btn)

  return btn
end

local function _PUI_ApplyShellBackdrop(target, bgColor, borderColor, edge)
  ns.Theme.SetSquareBackdrop(target, {
    bg = bgColor,
    border = borderColor,
  }, edge)
end


local function _PUI_EnsurePleebUIOptionsChrome(frame)
  local baseLevel = frame:GetFrameLevel()
  local colors = ns.Theme.GetColors()
  local edge = ns.Theme.GetEdgeSize()
  local chromeLevel = baseLevel + 40

  if not frame.__puiHeaderShell then
    frame.__puiHeaderShell = CreateFrame("Frame", nil, frame)
  end

  if not frame.__puiBodyShell then
    frame.__puiBodyShell = CreateFrame("Frame", nil, frame)
  end

  if not frame.__puiNavShell then
    frame.__puiNavShell = CreateFrame("Frame", nil, frame)
  end

  if not frame.__puiContentShell then
    frame.__puiContentShell = CreateFrame("Frame", nil, frame)
  end

  if not frame.__puiFooterShell then
    frame.__puiFooterShell = CreateFrame("Frame", nil, frame)
  end

  if not frame.__puiAccentLine then
    frame.__puiAccentLine = frame:CreateTexture(nil, "BORDER")
  end

  if not frame.__puiHeaderGlow then
    frame.__puiHeaderGlow = frame:CreateTexture(nil, "ARTWORK")
  end

  if not frame.__puiDragHeader then
    local drag = CreateFrame("Frame", nil, frame)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
      frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
      _PUI_StopOptionsWindowDrag(frame)
    end)
    drag:SetScript("OnMouseDown", function(_, button)
      if button == "LeftButton" then
        frame:StartMoving()
      end
    end)
    drag:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" then
        _PUI_StopOptionsWindowDrag(frame)
      end
    end)
    frame.__puiDragHeader = drag
  end

  if not frame.__puiResizeGrip then
    local grip = CreateFrame("Frame", nil, frame)

    grip:EnableMouse(true)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints(grip)
    grip.tex:SetTexture("Interface\\Buttons\\WHITE8x8")

    grip:SetScript("OnEnter", function(self)
      local accent = ns.Theme.GetColors().accent
      self.tex:SetVertexColor(accent[1], accent[2], accent[3], 0.75)
    end)

    grip:SetScript("OnLeave", function(self)
      local accent = ns.Theme.GetColors().accent
      self.tex:SetVertexColor(accent[1], accent[2], accent[3], 0.35)
    end)

    grip:SetScript("OnMouseDown", function(_, button)
      if button ~= "LeftButton" then
        return
      end

      frame:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
      frame:StopMovingOrSizing()
      _PUI_SaveOptionsWindowState(frame)
    end)

    frame.__puiResizeGrip = grip
  end

  if not frame.__puiSubtitle then
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle.__puiOptionsFontOwned = true
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("MIDDLE")
    frame.__puiSubtitle = subtitle
  end

  if not frame.__puiTopHeaderTitle then
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title.__puiOptionsFontOwned = true
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    frame.__puiTopHeaderTitle = title
  end

  if not frame.__puiTopHeaderSubtitle then
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle.__puiOptionsFontOwned = true
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("MIDDLE")
    frame.__puiTopHeaderSubtitle = subtitle
  end

  local headerBg = colors.background
  local navBg = colors.background
  local bodyBg = colors.background
  local borderColor = colors.border

  local outerPad = 8
  local topHeaderHeight = 78
  local footerHeight = 62
  local navWidth = 258
  local gutter = 12

  frame.__puiFooterShell:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiFooterShell:SetFrameLevel(baseLevel + 12)
  frame.__puiFooterShell:ClearAllPoints()
  frame.__puiFooterShell:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", outerPad, outerPad)
  frame.__puiFooterShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -outerPad, outerPad)
  frame.__puiFooterShell:SetHeight(footerHeight)
  _PUI_ApplyShellBackdrop(frame.__puiFooterShell, headerBg, borderColor, edge)
  frame.__puiFooterShell:Show()

  frame.__puiBodyShell:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiBodyShell:SetFrameLevel(baseLevel + 4)
  frame.__puiBodyShell:ClearAllPoints()
  frame.__puiBodyShell:SetPoint("TOPLEFT", frame, "TOPLEFT", outerPad, -outerPad)
  frame.__puiBodyShell:SetPoint("BOTTOMRIGHT", frame.__puiFooterShell, "TOPRIGHT", 0, gutter)
  _PUI_ApplyShellBackdrop(frame.__puiBodyShell, bodyBg, { 0, 0, 0, 0 }, edge)
  frame.__puiBodyShell:Show()

  frame.__puiHeaderShell:SetParent(frame)
  frame.__puiHeaderShell:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiHeaderShell:SetFrameLevel(baseLevel + 12)
  frame.__puiHeaderShell:ClearAllPoints()
  frame.__puiHeaderShell:SetPoint("TOPLEFT", frame.__puiBodyShell, "TOPLEFT", 0, 0)
  frame.__puiHeaderShell:SetSize(navWidth, topHeaderHeight)
  _PUI_ApplyShellBackdrop(frame.__puiHeaderShell, headerBg, borderColor, edge)
  frame.__puiHeaderShell:Show()

  frame.__puiTopHeaderTitle:SetParent(frame.__puiHeaderShell)
  frame.__puiTopHeaderTitle:ClearAllPoints()
  frame.__puiTopHeaderTitle:SetPoint("TOPLEFT", frame.__puiHeaderShell, "TOPLEFT", 18, -16)
  frame.__puiTopHeaderTitle:SetText("PleebUI")
  frame.__puiTopHeaderTitle:Show()

  frame.__puiTopHeaderSubtitle:SetParent(frame.__puiHeaderShell)
  frame.__puiTopHeaderSubtitle:ClearAllPoints()
  frame.__puiTopHeaderSubtitle:SetPoint("TOPLEFT", frame.__puiTopHeaderTitle, "BOTTOMLEFT", 0, -6)
  frame.__puiTopHeaderSubtitle:SetPoint("RIGHT", frame.__puiHeaderShell, "RIGHT", -14, 0)
  frame.__puiTopHeaderSubtitle:SetText("Set up PleebUI and its modules.")
  frame.__puiTopHeaderSubtitle:Show()

  ns.Theme.ApplyFont(frame.__puiTopHeaderTitle, "title", 20, "OUTLINE")
  ns.Theme.ApplyFont(frame.__puiTopHeaderSubtitle, "body", 11)
  frame.__puiTopHeaderTitle:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  frame.__puiTopHeaderSubtitle:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4] * 0.68)

  frame.__puiNavShell:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiNavShell:SetFrameLevel(baseLevel + 35)
  frame.__puiNavShell:ClearAllPoints()
  frame.__puiNavShell:SetPoint("TOPLEFT", frame.__puiHeaderShell, "BOTTOMLEFT", 0, -gutter)
  frame.__puiNavShell:SetPoint("BOTTOMLEFT", frame.__puiBodyShell, "BOTTOMLEFT", 0, 0)
  frame.__puiNavShell:SetWidth(navWidth)
  _PUI_ApplyShellBackdrop(frame.__puiNavShell, navBg, borderColor, edge)
  frame.__puiNavShell:Show()

  frame.__puiContentShell:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiContentShell:SetFrameLevel(baseLevel + 10)
  frame.__puiContentShell:ClearAllPoints()
  frame.__puiContentShell:SetPoint("TOPLEFT", frame.__puiHeaderShell, "TOPRIGHT", gutter, 0)
  frame.__puiContentShell:SetPoint("BOTTOMRIGHT", frame.__puiBodyShell, "BOTTOMRIGHT", 0, 0)
  _PUI_ApplyShellBackdrop(frame.__puiContentShell, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, edge)
  frame.__puiContentShell:Show()

  frame.__puiHeaderGlow:SetParent(frame)
  frame.__puiHeaderGlow:ClearAllPoints()
  frame.__puiHeaderGlow:Hide()

  frame.__puiAccentLine:SetParent(frame)
  frame.__puiAccentLine:ClearAllPoints()
  frame.__puiAccentLine:Hide()

  frame.__puiDragHeader:SetParent(frame)
  frame.__puiDragHeader:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiDragHeader:SetFrameLevel(frame.__puiHeaderShell:GetFrameLevel() + 20)
  frame.__puiDragHeader:ClearAllPoints()
  frame.__puiDragHeader:SetPoint("TOPLEFT", frame.__puiHeaderShell, "TOPLEFT", 0, 0)
  frame.__puiDragHeader:SetPoint("TOPRIGHT", frame.__puiBodyShell, "TOPRIGHT", 0, 0)
  frame.__puiDragHeader:SetHeight(topHeaderHeight)
  frame.__puiDragHeader:Show()
  frame.__puiDragHeader:EnableMouse(true)

  frame.__puiSubtitle:SetParent(frame)
  frame.__puiSubtitle:ClearAllPoints()
  frame.__puiSubtitle:Hide()

  if not frame.__puiHeaderButtons then
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(chromeLevel)
    frame.__puiHeaderButtons = holder
  end

  frame.__puiHeaderButtons:SetParent(frame.__puiFooterShell)
  frame.__puiHeaderButtons:ClearAllPoints()
  frame.__puiHeaderButtons:SetPoint("BOTTOMLEFT", frame.__puiFooterShell, "BOTTOMLEFT", 14, 14)
  frame.__puiHeaderButtons:SetPoint("BOTTOMRIGHT", frame.__puiFooterShell, "BOTTOMRIGHT", -14, 14)
  frame.__puiHeaderButtons:SetHeight(34)
  frame.__puiHeaderButtons:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiHeaderButtons:SetFrameLevel(chromeLevel)
  frame.__puiHeaderButtons:Show()

  local buttons = {
    {
      key = "__puiBtnDebug",
      width = 70,
      text = "Close",
      onClick = function()
        frame:Hide()
      end,
    },
    {
      key = "__puiBtnPCM",
      width = 108,
      text = "Cooldowns",
      onClick = function()
        _G.CooldownViewerSettings:ShowUIPanel(false)
      end,
    },
    {
      key = "__puiBtnTest",
      width = 62,
      text = "Test",
      onClick = function()
        Addon:SetEditMode(not Addon:IsEditMode())
      end,
    },
    {
      key = "__puiBtnMovers",
      width = 80,
      text = "Movers",
      onClick = function()
        Addon:SetEditMode(not Addon:IsEditMode())
      end,
    },
    {
      key = "__puiBtnSetup",
      width = 70,
      text = "Setup",
      onClick = function()
        Addon:ShowInstallWizard(true)
      end,
    },
    {
      key = "__puiBtnWhatsNew",
      width = 92,
      text = "What's new",
      onClick = function()
        Addon:ShowWhatsNew(true)
      end,
    },
  }

  local previous = nil

  for i = 1, #buttons do
    local info = buttons[i]
    local btn = frame[info.key]

    if not btn then
      btn = _PUI_CreateHeaderButton(frame.__puiHeaderButtons, info.width, info.text, info.onClick)
      frame[info.key] = btn
    end

    btn:SetParent(frame.__puiHeaderButtons)
    btn:SetFrameStrata(frame.__puiHeaderButtons:GetFrameStrata())
    btn:SetFrameLevel(frame.__puiHeaderButtons:GetFrameLevel() + 1)

    local buttonWidth = info.width
    local measured = math.ceil(btn:GetFontString():GetUnboundedStringWidth() + 22)
    if measured > buttonWidth then
      buttonWidth = measured
    end

    btn:SetSize(buttonWidth, 30)
    btn:ClearAllPoints()
    _PUI_StyleHeaderActionButton(btn)

    btn:SetScript("OnClick", info.onClick)
    if previous then
      btn:SetPoint("RIGHT", previous, "LEFT", -4, 0)
    else
      btn:SetPoint("RIGHT", frame.__puiHeaderButtons, "RIGHT", 0, 0)
    end
    btn:Show()
    previous = btn
  end

  _PUI_RefreshRootRegistryNav(frame)

  local resizeAccent = colors.accent
  local resizeAlpha = frame.__puiResizeGrip:IsMouseOver() and 0.75 or 0.35
  frame.__puiResizeGrip.tex:SetVertexColor(resizeAccent[1], resizeAccent[2], resizeAccent[3], resizeAlpha)

  frame.__puiResizeGrip:ClearAllPoints()
  frame.__puiResizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
  frame.__puiResizeGrip:SetSize(16, 16)
  frame.__puiResizeGrip:SetFrameStrata(frame:GetFrameStrata())
  frame.__puiResizeGrip:SetFrameLevel(baseLevel + 60)
  frame.__puiResizeGrip:Show()
  frame.__puiResizeGrip:EnableMouse(true)
end

function Addon:ApplyOptionsUIScale()
  local frame = self._OptionsWindow
  if not frame then
    return
  end

  frame:SetScale(ns.Theme.GetOptionsUIScale())

  local resized = _PUI_FitOptionsWindowToScreen(frame)
  _PUI_UpdateOptionsWindowSize(frame, PUI_OPTIONS_APP)

  if resized then
    _PUI_SaveOptionsWindowState(frame)
  end
end

function Addon:RefreshOptionsTheme()
  local frame = self._OptionsWindow
  if not frame then
    return
  end

  local colors = ns.Theme.GetColors()

  _PUI_ApplyShellBackdrop(frame, colors.background, colors.border, ns.Theme.GetEdgeSize())
  _PUI_EnsurePleebUIOptionsChrome(frame)

  local shell = frame.__puiPageShell
  if shell then
    shell:RefreshTheme()
  end

  local previewToggle = frame.__puiPreviewToggleButton
  if previewToggle then
    local bg = colors.control
    local border = colors.border

    ns.Theme.ApplyFont(previewToggle.text, "button", 11)
    previewToggle.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    ns.Theme.SetSquareBackdrop(previewToggle, {
      bg = { bg[1], bg[2], bg[3], 0.92 },
      border = { border[1], border[2], border[3], 0.72 },
    }, ns.Theme.GetEdgeSize())
  end

  ns.AceHooks.RefreshOwnedWidgets()

  frame.__puiRootNavSignature = nil
  _PUI_RefreshRootRegistryNav(frame)

  ns.PCMPreview.Refresh()
  ns.UFPreview.RefreshAuraManagerPreview()
end


local function _PUI_GetPageShellInfo(path)
  local registry = ns.Registry.Options
  local safePath = _PUI_CopyOptionsPath(path)
  local rootKey = safePath and safePath[1] or nil
  local leafKey = safePath and safePath[#safePath] or nil
  local rootRec = rootKey and registry[rootKey] or nil
  local leafRec = leafKey and registry[leafKey] or nil
  local activeRec = leafRec or rootRec

  if type(activeRec) ~= "table" then
    return nil
  end

  local rootMeta = type(rootRec and rootRec.meta) == "table" and rootRec.meta or {}
  local activeMeta = type(activeRec.meta) == "table" and activeRec.meta or {}
  local rootPage = type(rootMeta.page) == "table" and rootMeta.page or {}
  local activePage = type(activeMeta.page) == "table" and activeMeta.page or {}
  local page = {}

  for k, v in pairs(rootPage) do
    page[k] = v
  end
  for k, v in pairs(activePage) do
    page[k] = v
  end

  local function Pick(...)
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if v ~= nil and v ~= "" then
        return v
      end
    end
    return nil
  end

  local title = Pick(page.title, activeMeta.pageTitle, activeMeta.title, rootMeta.pageTitle, rootMeta.title, activeRec.label, activeRec.name, activeRec.key)
  local description = Pick(page.description, activeMeta.pageDescription, activeMeta.description, rootMeta.pageDescription, rootMeta.description)
  local helpText = Pick(page.helpText, page.help, activeMeta.pageHelp, activeMeta.helpText, rootMeta.pageHelp, rootMeta.helpText)
  local previewWidth = tonumber(Pick(page.previewWidth, activeMeta.previewWidth, rootMeta.previewWidth)) or 300
  local previewHeight = tonumber(Pick(page.previewHeight, activeMeta.previewHeight, rootMeta.previewHeight)) or 168
  local previewStateKey = tostring(Pick(
    page.previewStateKey,
    activeMeta.previewStateKey,
    rootMeta.previewStateKey,
    rootKey,
    "default"
  ))
  local previewAllowed = rootKey == "unitframes"
    or rootKey == "ACTIONBARS"
    or rootKey == "CooldownManager"
    or rootKey == "PRD"

  local previewPathMatches = type(page.previewPathMatches) ~= "function"
    or page.previewPathMatches(safePath) == true
  local pageSupportsPreview = previewAllowed
    and previewPathMatches
    and type(page.buildPreview) == "function"

  return {
    path = safePath,
    page = page,
    title = title,
    description = description,
    helpText = helpText,
    previewWidth = previewWidth,
    previewHeight = previewHeight,
    previewStateKey = previewStateKey,
    pageSupportsPreview = pageSupportsPreview,
  }
end

local function _PUI_BuildSelectedOptionsPath(widget, uniquevalue)
  local user = widget:GetUserDataTable()
  if user.appName ~= PUI_OPTIONS_APP or type(user.path) ~= "table" then
    return nil
  end

  local path = _PUI_CopyOptionsPath(user.path)

  for key in string.gmatch(tostring(uniquevalue or ""), "[^\001]+") do
    path[#path + 1] = key
  end

  return _PUI_GetValidatedOptionsPath(path)
end

local function _PUI_GetOptionsPagePathKey(path)
  if type(path) ~= "table" then
    return ""
  end

  return tostring(path[1] or "") .. "\031" .. tostring(path[2] or "")
end

local function _PUI_ApplySelectedOptionsPath(path)
  path = _PUI_GetValidatedOptionsPath(path)
  if not path then
    return false
  end

  _PUI_RecordOptionsHistory(path)

  local previousPagePathKey = _PUI_GetOptionsPagePathKey(State.currentOptionsPath)
  local nextPagePathKey = _PUI_GetOptionsPagePathKey(path)
  local pageChanged = previousPagePathKey ~= nextPagePathKey
  local previousOptionsRootPathKey = _PUI_GetOptionsRootPathKey(State.currentOptionsPath)
  local nextOptionsRootPathKey = _PUI_GetOptionsRootPathKey(path)
  local optionsModelChanged = previousOptionsRootPathKey ~= nextOptionsRootPathKey
  local nextInfo = _PUI_GetPageShellInfo(path)

  State.currentOptionsPath = _PUI_CopyOptionsPath(path)
  ns._PUIActiveOptionsPath = _PUI_CopyOptionsPath(path)

  if optionsModelChanged then
    State.optionsRoot = nil
    State.optionsRootPathKey = nil
  end

  State.optionsPathGeneration = (State.optionsPathGeneration or 0) + 1
  _PUI_RememberLastSectionFromPath(path)

  local frame = Addon._OptionsWindow
  if not (frame and frame:IsShown()) then
    return false
  end

  local callback = nextInfo and nextInfo.page and nextInfo.page.onOptionsPathChanged
  if type(callback) == "function" then
    callback(Addon, frame, frame.__puiPageShell, path)
  end

  if pageChanged then
    _PUI_RefreshCustomPageShell(frame, path)
  end
  return true, optionsModelChanged
end

function Addon:HandleOptionsGroupSelection(widget, uniquevalue)
  local path = _PUI_BuildSelectedOptionsPath(widget, uniquevalue)
  if not path then
    return false
  end

  local applied, optionsModelChanged = _PUI_ApplySelectedOptionsPath(path)
  if not applied then
    return false
  end

  if optionsModelChanged and not _PUI_RebindOptionsGroup(widget) then
    return false
  end

  return true
end

local function _PUI_OptionsPathStartsWith(path, prefix)
  if type(path) ~= "table" or type(prefix) ~= "table" or #prefix > #path then
    return false
  end

  for index = 1, #prefix do
    if path[index] ~= prefix[index] then
      return false
    end
  end

  return true
end

local function _PUI_FindRetainedOptionsGroup(root, path)
  local bestWidget
  local bestValue
  local bestDepth = -1

  local function Walk(widget)
    if not widget then
      return
    end

    if widget.GetUserDataTable then
      local user = widget:GetUserDataTable()
      local widgetPath = user and user.path
      local depth = type(widgetPath) == "table" and #widgetPath or 0

      if user
        and user.appName == PUI_OPTIONS_APP
        and depth < #path
        and depth > bestDepth
        and _PUI_OptionsPathStartsWith(path, widgetPath)
      then
        if widget.type == "TreeGroup" and widget.SelectByValue then
          local remainder = {}
          for index = depth + 1, #path do
            remainder[#remainder + 1] = path[index]
          end

          bestWidget = widget
          bestValue = table.concat(remainder, "\001")
          bestDepth = depth
        end
      end
    end

    for _, child in ipairs(widget.children or {}) do
      Walk(child)
    end
  end

  Walk(root)
  return bestWidget, bestValue
end

function Addon:NavigateOpenOptionsPath(targetPath)
  local path = _PUI_GetValidatedOptionsPath(targetPath)
  local frame = Addon._OptionsWindow
  local shell = frame and frame.__puiPageShell
  local container = shell and shell.acdContainer

  if not path
    or not (frame and frame:IsShown())
    or not container
    or _PUI_GetOptionsPagePathKey(State.currentOptionsPath) ~= _PUI_GetOptionsPagePathKey(path)
  then
    return false
  end

  local widget, value = _PUI_FindRetainedOptionsGroup(container, path)
  if not widget or not value then
    return false
  end

  local status = widget.status or widget.localstatus
  if status and status.selected == value then
    return _PUI_ApplySelectedOptionsPath(path) == true
  end

  if not self:HandleOptionsGroupSelection(widget, value) then
    return false
  end

  widget:SelectByValue(value)
  return true
end

function Addon:SelectOptionsPath(targetPath)
  local path = _PUI_GetValidatedOptionsPath(targetPath)
  if not path then
    return
  end

  _PUI_ApplySelectedOptionsPath(path)
  LibStub("AceConfigDialog-3.0"):SelectGroup(PUI_OPTIONS_APP, unpack(path))
end

local function _PUI_EnsureCustomOptionsFrame()
  local frame = Addon._OptionsWindow

  if not frame then
    frame = CreateFrame("Frame", "PleebUI_OptionsFrame", UIParent, "BackdropTemplate")
    frame.__puiCustomOptionsWindow = true
    frame.__puiOwnedApp = PUI_OPTIONS_APP
    table.insert(_G.UISpecialFrames, "PleebUI_OptionsFrame")

    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetResizable(true)
    frame:SetMovable(true)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(false)
    frame:EnableMouse(true)
    frame:SetUserPlaced(false)

    frame:SetScript("OnShow", function(self)
      self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)

    frame:SetScript("OnEvent", function(_, event, button)
      if event ~= "GLOBAL_MOUSE_DOWN" then
        return
      end

      if button == "Button4" then
        _PUI_NavigateOptionsHistory(-1)
      elseif button == "Button5" then
        _PUI_NavigateOptionsHistory(1)
      end
    end)

    frame:SetScript("OnHide", function(self)
      self:UnregisterEvent("GLOBAL_MOUSE_DOWN")

      _PUI_RememberLastSectionFromPath(_PUI_GetCurrentOptionsPath())
      _PUI_SaveOptionsWindowState(self)

      LibStub("AceGUI-3.0"):ClearFocus()

      local shell = self.__puiPageShell
      local container = shell and shell.acdContainer
      if container then
        container:ReleaseChildren()
      end

      self.__puiLastRenderedOptionsPathKey = nil
      ns.Theme.ResetWidgetRowBackgrounds()
      ns.Flags.__puiPCM_OptionsOpen = nil
      ns.Modules.CooldownManager:FlushPendingEditModeChanges()
      _PUI_ApplyAuraSpellIDTooltipCVarForOptions(false)
    end)

    Addon._OptionsWindow = frame

    Addon:ApplyOptionsUIScale()
    _PUI_RestoreOptionsWindowState(frame)
    _PUI_UpdateOptionsWindowSize(frame, PUI_OPTIONS_APP)
  end

  State.optionsFrame = frame

  local colors = ns.Theme.GetColors()
  _PUI_ApplyShellBackdrop(frame, colors.background, colors.border, ns.Theme.GetEdgeSize())
  _PUI_EnsurePleebUIOptionsChrome(frame)

  frame.__puiChromeReady = true

  return frame
end

local function _PUI_GetShellACDContainer(frame, shell)
  local container = shell:GetACDContainer()
  ns._OptionsContentHost = container.frame
  State.optionsContentHost = container.frame
  return container
end

local _PUI_RefreshShellNavigationContext

_PUI_RefreshCustomPageShell = function(frame, path)
  frame.__puiCustomBodyBuilt = nil

  local info = _PUI_GetPageShellInfo(path)
  local contentShell = frame.__puiContentShell
  local shell = ns.PageShell.Ensure(contentShell)
  frame.__puiPageShell = shell

  shell:SetParent(contentShell)
  shell:SetFrameStrata(frame:GetFrameStrata())
  shell:SetFrameLevel(contentShell:GetFrameLevel() + 20)
  shell:ClearAllPoints()
  shell:SetPoint("TOPLEFT", contentShell, "TOPLEFT", 0, 0)
  shell:SetPoint("BOTTOMRIGHT", contentShell, "BOTTOMRIGHT", 0, 0)
  shell:Show()
  shell:BeginLayoutBatch()

  local rootKey = info.path[1]
  local preserveShellChrome = rootKey and shell.__puiLastOptionsRootKey == rootKey

  if preserveShellChrome then
    shell:ResetPageContent()
  else
    shell:Reset()
  end

  shell.__puiLastOptionsRootKey = rootKey
  shell:SetTitle(info.title or "")
  shell:SetDescription(info.description or "")
  shell:SetHelpText(info.helpText or "")

  local stateDB = _PUI_GetOptionsStateDB()
  stateDB.previewStates = stateDB.previewStates or {}

  local previewState = stateDB.previewStates[info.previewStateKey]
  if type(previewState) ~= "table" then
    previewState = {}
    stateDB.previewStates[info.previewStateKey] = previewState
  end

  shell:SetPreviewState(previewState)

  local previewAlwaysShown = info.page.previewAlwaysShown == true
  local previewEnabled = previewAlwaysShown or stateDB.previewBoxEnabled == true
  local wantsPreview = info.pageSupportsPreview and previewEnabled

  if info.pageSupportsPreview and not previewAlwaysShown then
    local host = shell.headerActions
    local btn = frame.__puiPreviewToggleButton

    if not btn then
      btn = CreateFrame("Button", nil, host, "BackdropTemplate")
      btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      btn.text.__puiOptionsFontOwned = true
      btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
      btn.text:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
      btn.text:SetJustifyH("CENTER")
      btn.text:SetJustifyV("MIDDLE")
      ns.Theme.ApplyFont(btn.text, "button", 11)
      frame.__puiPreviewToggleButton = btn
    end

    btn:SetParent(host)
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    btn:SetSize(118, 22)
    btn.text:SetText(previewEnabled and "Hide Preview" or "Show Preview")

    do
      local colors = ns.Theme.GetColors()
      local bg = colors.control
      local border = colors.border
      ns.Theme.SetSquareBackdrop(btn, {
        bg = { bg[1], bg[2], bg[3], 0.92 },
        border = { border[1], border[2], border[3], 0.72 },
      }, ns.Theme.GetEdgeSize())
      btn.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    end

    btn:SetScript("OnClick", function()
      local db = _PUI_GetOptionsStateDB()
      db.previewBoxEnabled = not (db.previewBoxEnabled == true)
      _PUI_RefreshCustomPageShell(frame, info.path)
    end)

    btn:Show()
    shell:SetHeaderActionsShown(true)
  elseif frame.__puiPreviewToggleButton then
    frame.__puiPreviewToggleButton:Hide()
  end

  _PUI_RefreshShellNavigationContext(frame, shell, info.path)

  shell:SetPreviewShown(wantsPreview, info.previewWidth, info.previewHeight)
  frame.__puiCustomContentTopInset = 0
  shell:EndLayoutBatch()

  if wantsPreview then
    local previewBuilt = info.page.buildPreview(Addon, frame, shell, info.path) == true

    if not previewBuilt then
      local previewHost = shell.previewHost
      local box = ns.PreviewBox.Create(previewHost)
      box:SetPoint("TOPLEFT", previewHost, "TOPLEFT", 0, 0)
      box:SetPoint("TOPRIGHT", previewHost, "TOPRIGHT", 0, 0)
      box:SetPoint("BOTTOMRIGHT", previewHost, "BOTTOMRIGHT", 0, 0)
      box:SetTitle(info.page.previewTitle or "Preview")
      box:SetDescription(info.page.previewDescription or "Preview support is owned by the PleebUI shell.")
    end
  end

  return shell
end

local PUI_SHELL_TOP_TAB_UX = {
  unitframes = {
    general = { name = "Overview", desc = "Shared frame style, textures, text behavior, mouseover rules, and global unit-frame settings." },
    player = { name = "Player", desc = "Your own player frame, pet frame, castbar, auras, text, and frame layout." },
    target = { name = "Target", desc = "Target and target-of-target frame layout, text, castbar, and aura behavior." },
    focus = { name = "Focus", desc = "Focus and focus-target frame layout, text, castbar, and aura behavior." },
    boss = { name = "Boss", desc = "Boss frame layout, spacing, text, castbar, and shared boss-frame settings." },
    party = { name = "Party", desc = "Party frame layout, role indicators, aura display, test mode, and group behavior." },
    raid = { name = "Raid", desc = "Raid frame layout, role indicators, aura display, test mode, and group behavior." },
  },
  ACTIONBARS = {
    general = { name = "Overview", desc = "Shared layout, appearance, text, and visibility." },
    ["1"] = { name = "Bar 1", desc = "Layout, visibility, and text overrides for bar 1." },
    ["2"] = { name = "Bar 2", desc = "Layout, visibility, and text overrides for bar 2." },
    ["3"] = { name = "Bar 3", desc = "Layout, visibility, and text overrides for bar 3." },
    ["4"] = { name = "Bar 4", desc = "Layout, visibility, and text overrides for bar 4." },
    ["5"] = { name = "Bar 5", desc = "Layout, visibility, and text overrides for bar 5." },
    ["6"] = { name = "Bar 6", desc = "Layout, visibility, and text overrides for bar 6." },
    ["7"] = { name = "Bar 7", desc = "Layout, visibility, and text overrides for bar 7." },
    ["8"] = { name = "Bar 8", desc = "Layout, visibility, and text overrides for bar 8." },
    special = { name = "Special bars", desc = "Pet, stance, possess, and other special bars." },
  },
  PRD = {
    general = { name = "Overview", desc = "Enable, visibility, mover, Blizzard text integration, and shared PRD behavior." },
    health = { name = "Health", desc = "Health bar layout, color, text, texture, and frame style." },
    primary = { name = "Primary Power", desc = "Mana, energy, rage, focus, runic power, and primary resource display." },
    secondary = { name = "Secondary Power", desc = "Additional resource bars, class-specific secondary resources, and related text." },
  },
  CooldownManager = {
    cooldowns_essential = { name = "Cooldown icons", desc = "Tracked cooldown layout, text, charges, and glow." },
    cooldowns_utility = { name = "Utility icons", desc = "Utility cooldown layout, text, charges, and appearance." },
    buff_icons = { name = "Buff icons", desc = "Tracked buff icon layout, text, and appearance." },
    buff_bars = { name = "Buff bars", desc = "Tracked buff bar layout, text, and appearance." },
    custom_bars = { name = "Custom bars", desc = "Create and edit duration, cooldown, charge, and stack bars." },
  },
  Chat = {
    status = { name = "Status", desc = "Shows which addon currently controls chat." },
    features = { name = "Features", desc = "Enable chat links, copying, and PleebUI Chat." },
    copyStyle = { name = "Copy window", desc = "Copy window appearance and size." },
    chatStyle = { name = "Chat window", desc = "Chat frame appearance, padding, and dock style." },
    formatting = { name = "Formatting", desc = "Timestamps, channel names, brackets, and messages." },
    fade = { name = "Fade", desc = "Chat opacity, delay, and fade behavior." },
    tweaks = { name = "Tweaks", desc = "History, buttons, sticky channels, and edit box behavior." },
  },
  Quality = {
    qualityTab = { name = "Helpers", desc = "Cursor, pet, crosshair, and visual helpers." },
    automationTab = { name = "Automation", desc = "Loot, merchants, dialogs, invites, and camera." },
  },
}

local function _PUI_GetShellTopTabUX(rootKey, childKey)
  local root = PUI_SHELL_TOP_TAB_UX[rootKey]
  if root then
    return root[childKey]
  end
  return nil
end

_PUI_RefreshShellNavigationContext = function(_, shell, path)
  local rootKey = path[1]
  local activeChildKey = path[2]
  local rootOption = _PUI_GetOptionsRoot().args[rootKey]
  local args = rootOption and rootOption.args
  local registry = ns.Registry.Options

  if type(args) ~= "table" then
    shell:SetStickyShown(false)
    return false
  end

  local activeOption = activeChildKey and args[activeChildKey] or nil

  if type(activeOption) ~= "table" then
    local firstKey
    local firstOrder

    for key, opt in pairs(args) do
      if type(opt) == "table"
        and opt.hidden ~= true
        and opt.inline ~= true
        and (opt.type == "group" or type(opt.args) == "table")
      then
        local order = tonumber(opt.order) or 50

        if not firstKey
          or order < firstOrder
          or (order == firstOrder and tostring(key) < tostring(firstKey))
        then
          firstKey = key
          firstOrder = order
        end
      end
    end

    activeChildKey = firstKey
    activeOption = firstKey and args[firstKey] or nil
  end

  if type(activeOption) == "table" then
    local rootRec = registry[rootKey]
    local rootMeta = type(rootRec and rootRec.meta) == "table" and rootRec.meta or {}
    local childRec = registry[activeChildKey]
    local childMeta = type(childRec and childRec.meta) == "table" and childRec.meta or {}
    local childUX = _PUI_GetShellTopTabUX(rootKey, activeChildKey)
    local rootName = rootMeta.pageTitle
      or rootMeta.title
      or (rootRec and (rootRec.label or rootRec.name or rootRec.key))
      or rootOption.name
      or rootKey
    local childName = (childUX and childUX.name)
      or activeOption.name
      or activeOption.label
      or activeChildKey
    local childDescription = (childUX and childUX.desc)
      or activeOption.desc
      or activeOption.description
      or activeOption.pageDescription
      or activeOption.helpText
      or activeOption.help
      or childMeta.navDescription
      or childMeta.pageDescription
      or childMeta.description
      or childMeta.pageHelp
    local titleParts = { rootName }

    if type(childName) == "string"
      and childName ~= ""
      and childName ~= " "
      and childName ~= rootName
    then
      titleParts[#titleParts + 1] = childName
    end

    local option = activeOption
    for index = 3, #path do
      local childArgs = option and option.args
      local child = type(childArgs) == "table" and childArgs[path[index]] or nil
      if type(child) ~= "table" then
        break
      end

      local name = child.name
      if type(name) ~= "string" or name == "" or name == " " then
        name = child.label
      end

      if type(name) == "string"
        and name ~= ""
        and name ~= " "
        and name ~= titleParts[#titleParts]
      then
        titleParts[#titleParts + 1] = name
      end

      local description = child.desc
        or child.description
        or child.pageDescription
        or child.helpText
        or child.help
        or child.pageHelp

      if type(description) == "string" and description ~= "" then
        childDescription = description
      end

      option = child
    end

    shell:SetTitle(table.concat(titleParts, " / "))

    if type(childDescription) == "string" and childDescription ~= "" then
      shell:SetHelpText(childDescription)
    end
  end

  if #path > 2 then
    local parentPath = _PUI_CopyOptionsPath(path)
    parentPath[#parentPath] = nil

    local upButton = shell.__puiUpButton
    if not upButton then
      upButton = CreateFrame("Button", nil, shell.headerActions, "UIPanelButtonTemplate")
      upButton:SetText("Up")
      upButton.__puiHeaderAction = true
      upButton:SetScript("OnClick", function(self)
        local targetPath = self.__puiTargetPath
        if targetPath and #targetPath > 0 then
          Addon:OpenOptions(targetPath, false, true)
        end
      end)
      _PUI_StyleHeaderActionButton(upButton)
      shell.__puiUpButton = upButton
    end

    upButton:SetParent(shell.headerActions)
    upButton.__puiTargetPath = parentPath
    upButton:ClearAllPoints()
    upButton:SetPoint("TOPLEFT", shell.headerActions, "TOPLEFT", 0, 0)
    upButton:SetSize(36, 22)
    upButton:Show()
    shell:SetHeaderActionsShown(true)
  elseif shell.__puiUpButton then
    shell.__puiUpButton:Hide()
  end

  shell:SetStickyShown(false)
  return false
end

local function _PUI_GetRenderableOptionsPath(path)
  path = _PUI_CopyOptionsPath(path)
  if not path then
    return nil
  end

  local root = _PUI_GetOptionsRoot()
  local node = root
  local out = {}

  for i = 1, #path do
    local key = path[i]
    local args = node and node.args or nil
    local child = args and args[key] or nil

    if type(child) ~= "table" then
      break
    end

    out[#out + 1] = key
    node = child
  end

  if #out > 0 then
    return out
  end

  return path
end

local function _PUI_RenderCustomOptionsPath(frame, AceConfigDialog, APP, path)
  local requestedPath = _PUI_GetValidatedOptionsPath(path)
    or _PUI_GetStoredOptionsPath()
    or _PUI_GetFallbackOptionsPath()

  if frame.__puiRenderingOptionsPath then
    frame.__puiQueuedOptionsPath = _PUI_CopyOptionsPath(requestedPath)
    return
  end

  _PUI_RecordOptionsHistory(requestedPath)

  frame.__puiRenderingOptionsPath = true
  frame.__puiQueuedOptionsPath = nil

  local pathKey = table.concat(requestedPath, "\031")
  local previousOptionsRootPathKey = _PUI_GetOptionsRootPathKey(State.currentOptionsPath)
  local nextOptionsRootPathKey = _PUI_GetOptionsRootPathKey(requestedPath)

  State.currentOptionsPath = _PUI_CopyOptionsPath(requestedPath)
  ns._PUIActiveOptionsPath = _PUI_CopyOptionsPath(requestedPath)

  if previousOptionsRootPathKey ~= nextOptionsRootPathKey then
    State.optionsRoot = nil
    State.optionsRootPathKey = nil
  end

  local renderPath = _PUI_GetRenderableOptionsPath({ requestedPath[1] })
  State.optionsPathGeneration = (State.optionsPathGeneration or 0) + 1

  _PUI_RememberLastSectionFromPath(requestedPath)
  _PUI_RefreshRootRegistryNav(frame)

  local shell = _PUI_RefreshCustomPageShell(frame, requestedPath)
  local container = _PUI_GetShellACDContainer(frame, shell)

  if #requestedPath > 1 then
    AceConfigDialog:SelectGroup(APP, unpack(requestedPath))
  end

  ns.Theme.ResetWidgetRowBackgrounds()
  AceConfigDialog:Open(APP, container, unpack(renderPath))
  Addon:HandleOptionsPathOpened(requestedPath)

  frame.__puiLastRenderedOptionsPathKey = pathKey
  frame.__puiRenderingOptionsPath = nil

  local queuedPath = frame.__puiQueuedOptionsPath
  frame.__puiQueuedOptionsPath = nil

  if queuedPath and not _PUI_OptionsPathsEqual(queuedPath, requestedPath) then
    C_Timer.After(0, function()
      if frame:IsShown() then
        _PUI_RenderCustomOptionsPath(frame, AceConfigDialog, APP, queuedPath)
      end
    end)
  end
end

local function _PUI_EnsureOptionsDialog()
  local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
  local AceConfigDialog = LibStub("AceConfigDialog-3.0")
  local APP = PUI_OPTIONS_APP

  if not State.dialogRegistered then
    State.dialogRegistered = true
    AceConfigRegistry:RegisterOptionsTable(APP, function()
      return _PUI_GetOptionsRoot()
    end)
  end

  _PUI_UpdateOptionsWindowSize(nil, APP)
  return AceConfigDialog, APP
end

function Addon:RefreshOpenOptions()
  local frame = Addon._OptionsWindow

  self:InvalidateOptionsRender()

  if not (frame and frame.__puiCustomOptionsWindow and frame:IsShown()) then
    return
  end

  self:ApplyOptionsUIScale()
  self:RefreshOptionsTheme()

  local AceConfigDialog, APP = _PUI_EnsureOptionsDialog()
  local path = _PUI_GetCurrentOptionsPath()
    or _PUI_GetStoredOptionsPath()
    or _PUI_GetFallbackOptionsPath()

  _PUI_RenderCustomOptionsPath(frame, AceConfigDialog, APP, path)
end

function Addon:OpenOptions(request, preserveEditMode, forceOpen)
  local wasEditing = preserveEditMode and Addon:IsEditMode() or false
  local AceConfigDialog, APP = _PUI_EnsureOptionsDialog()
  local frame = _PUI_EnsureCustomOptionsFrame()
  local requestedPath
  local mode = "Open"

  if forceOpen then
    requestedPath = _PUI_NormalizeRequestedOptionsPath(request)
    if requestedPath == nil and ((type(request) == "string" and request ~= "") or type(request) == "table") then
      requestedPath = _PUI_GetFallbackOptionsPath()
    end
  else
    mode, requestedPath = _PUI_GetToggleMode(frame, request)
  end

  if mode == "Close" then
    _PUI_RememberLastSectionFromPath(_PUI_GetCurrentOptionsPath())
    frame:Hide()
  else
    ns.EditModeQuickSettings:Hide()

    local targetPath = requestedPath or _PUI_GetStoredOptionsPath() or _PUI_GetFallbackOptionsPath()
    _PUI_ApplyAuraSpellIDTooltipCVarForOptions(true)
    frame:Show()
    frame:Raise()
    _PUI_RenderCustomOptionsPath(frame, AceConfigDialog, APP, targetPath)
  end

  if wasEditing then
    Addon:SetEditMode(true)
  end
end


function Addon:OpenOptionsSection(sectionKey, inlineTabKey, key)
  local path = _PUI_GetValidatedOptionsPath(_PUI_BuildOptionsPath(sectionKey, inlineTabKey, key))

  if not path then
    Addon:OpenOptions(sectionKey, true, false)
    return
  end

  Addon:OpenOptions(path, true, #path > 2)
end

