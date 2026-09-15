-- File: PUI_PCM_Config.lua
local ADDON_NAME, ns = ...



local Addon = ns.Addon
local Cooldowns = ns.Modules.CooldownManager
local OptionsUtil = ns.OptionsUtil
local PCMPresentation = ns.PCMPresentation
local AuraWidget = ns.AuraWidget
local IconSettings = ns.PCMIconSettings
local DB = ns.PCM_DBExports
local P, TrackThis = ns.Pleebug:DropIn(Addon, { name = "PCM", bucket = "Config" })
local function _PCM_RefreshPreview()
  ns.PCMPreview.Refresh()
end

local function _PCM_ConfigRefreshViewers(viewerKey, opts, refreshMode)
  opts = type(opts) == "table" and opts or {}

  if opts.requireReload then
    if opts.markReload then
      opts.markReload()
    end
    if opts.previewRefresh then
      opts.previewRefresh()
    end
    return
  end

  if not ns.PCM_IsModuleEnabledFast() then
    return
  end

  Cooldowns._InvalidateViewerRuleSettingCache(viewerKey)
  Cooldowns._PrimeViewerCountCache()
  Cooldowns:InvalidateNativeIconViewerCache(viewerKey)

  if refreshMode == "layout" and viewerKey then
    Cooldowns:_RequestViewerRefresh("layout", viewerKey)
  elseif opts.borderOnly then
    Cooldowns._RefreshViewerBordersOnly(viewerKey)
  elseif opts.fontOnly and viewerKey then
    Cooldowns._RefreshViewerFontsOnly(viewerKey)
  elseif viewerKey then
    Cooldowns:_RequestViewerRefresh("all", viewerKey)
  else
    Cooldowns:_RequestViewerRefresh("all")
  end

  if viewerKey == "BuffIconCooldownViewer" then
    ns.Modules.PCM_Buffs:ApplySettings(
      opts.fontOnly and { fonts = true } or { layout = true }
    )
    ns.Modules.PCM_Buffs:ScheduleRecenter()
  end

  if opts.previewRefresh then
    opts.previewRefresh()
  end
end




local _PCM_ConfigCache = {
  pcmProfile = nil,
  buffsProfile = nil,
}

local function _PCM_ValidateRoot(cm)
  local style = cm.style or {}
  cm.style = style

  if style.iconSize ~= nil then
    style.iconSize = tonumber(style.iconSize) or 36
  end
  if style.iconSpacing ~= nil then
    style.iconSpacing = tonumber(style.iconSpacing) or 2
  end

  cm.glow.speed = tonumber(cm.glow.speed) or 100
  cm.glow.scale = tonumber(cm.glow.scale) or 1.0
  cm.glow.lines = tonumber(cm.glow.lines) or 8
  cm.glow.thickness = tonumber(cm.glow.thickness) or 2
end

local function _PCM_EnsureRootDefaults(cm)
  cm.style   = cm.style   or {}
  cm.borders = cm.borders or {}
  cm.flags   = cm.flags   or {}
  cm.viewerSwipes = cm.viewerSwipes or {}
  cm.iconSettings = cm.iconSettings or {}
  cm.effects = cm.effects or {}
  cm.glow    = cm.glow    or {}
  cm.count   = cm.count   or {}

  if cm.enabled == nil then
    cm.enabled = true
  end

  cm.borders.module  = cm.borders.module  or {}
  cm.borders.viewer  = cm.borders.viewer  or {}
  cm.borders.buffBar = cm.borders.buffBar or {}

  if cm.borders.enabled == nil then
    cm.borders.enabled = true
  end
  if cm.borders.module.enabled == nil then
    cm.borders.module.enabled = true
  end
  if cm.borders.viewer.enabled == nil then
    cm.borders.viewer.enabled = true
  end
  if cm.borders.buffBar.enabled == nil then
    cm.borders.buffBar.enabled = true
  end

  local style = cm.style
  if not style.bgColor then
    style.bgColor = { 0.12, 0.12, 0.12, 0.95 }
  end
  if not style.headerTextColor then
    style.headerTextColor = { 1, 1, 1, 1 }
  end
  if not style.moduleTitleColor then
    style.moduleTitleColor = { 1, 1, 1, 1 }
  end
  if not style.viewerTitleColor then
    style.viewerTitleColor = { 1, 1, 1, 1 }
  end
  if not style.iconBgColor then
    style.iconBgColor = { 0, 0, 0, 0.35 }
  end
  if not style.buffBarBgColor then
    style.buffBarBgColor = { 0.12, 0.12, 0.12, 0.95 }
  end

  if style.buffBarUseClassColor == nil then
    style.buffBarUseClassColor = true
  end
  if not style.buffBarTextColor then
    style.buffBarTextColor = { 1, 1, 1, 1 }
  end

  if style.iconSize == nil then
    style.iconSize = 36
  end
  if style.iconSpacing == nil then
    style.iconSpacing = 2
  end

  style.viewerSizes      = style.viewerSizes      or {}
  style.viewerSpacing    = style.viewerSpacing    or {}
  style.viewerColumns    = style.viewerColumns    or {}
  style.viewerRowGrowth  = style.viewerRowGrowth  or {}
  style.viewerWidthMode  = style.viewerWidthMode  or {}
  style.viewerFixedWidth = style.viewerFixedWidth or {}

  if cm.effects.hideEssential == nil then
    cm.effects.hideEssential = false
  end
  if cm.effects.hideUtility == nil then
    cm.effects.hideUtility = false
  end

  if cm.glow.enabled == nil then
    cm.glow.enabled = true
  end
  if not cm.glow.type then
    cm.glow.type = "pixel"
  end
  if not cm.glow.color then
    cm.glow.color = { 0.95, 0.95, 0.32, 1 }
  end
  if cm.glow.speed == nil then
    cm.glow.speed = 100
  end
  if cm.glow.scale == nil then
    cm.glow.scale = 1.0
  end
  if cm.glow.lines == nil then
    cm.glow.lines = 8
  end
  if cm.glow.thickness == nil then
    cm.glow.thickness = 2
  end
end

local function GetPCMRoot()
  local root = Addon.db
  local cm = root.profile.cooldownManager or {}
  root.profile.cooldownManager = cm

  if _PCM_ConfigCache.pcmProfile ~= cm then
    _PCM_EnsureRootDefaults(cm)
    _PCM_ValidateRoot(cm)
    _PCM_ConfigCache.pcmProfile = cm
  end

  return cm
end

local function _PCM_EnsureBuffRootDefaults(cm)
  cm.style   = cm.style   or {}
  cm.borders = cm.borders or {}

  local style = cm.style
  style.viewerSizes   = style.viewerSizes   or {}
  style.viewerSpacing = style.viewerSpacing or {}
  style.viewerColumns = style.viewerColumns or {}
  style.viewerGrowth  = style.viewerGrowth  or {}

  if style.iconSize == nil then style.iconSize = 36 end
  if style.iconSpacing == nil then style.iconSpacing = 1 end

end

local function GetPCMBuffsRoot()
  local cm = ns.PCM_DBExports.GetProfileBuffsDB()

  if _PCM_ConfigCache.buffsProfile ~= cm then
    _PCM_EnsureBuffRootDefaults(cm)
    _PCM_ConfigCache.buffsProfile = cm
  end

  return cm
end

local function GetViewerBorderDB(cm, viewerKey)
  local borders = cm.borders or {}
  borders.viewer = borders.viewer or {}
  borders.viewer.viewers = borders.viewer.viewers or {}
  cm.borders = borders

  local viewers = borders.viewer.viewers

  local viewerCfg = viewers[viewerKey]
  if type(viewerCfg) ~= "table" then
    viewerCfg = {
      enabled = true,
      thickness = 2,
      color = { 0.20, 0.20, 0.24, 1.00 },
    }
    viewers[viewerKey] = viewerCfg
  end

  if viewerCfg.thickness == nil then
    viewerCfg.thickness = 2
  end

  return borders, viewerCfg
end

local function _PCM_GetStyleMapNumber(cm, mapName, viewerKey, defaultValue, minV, maxV)
  if not cm then
    return defaultValue
  end

  local style = cm.style or {}
  cm.style = style

  local map = style[mapName]
  if type(map) ~= "table" then
    map = {}
    style[mapName] = map
  end

  local v = map[viewerKey]
  if v == nil then
    v = defaultValue
  end

  v = tonumber(v) or defaultValue
  if minV ~= nil and v < minV then
    v = minV
  end

  if maxV ~= nil and v > maxV then
    v = maxV
  end
  return v
end

local function _PCM_SetStyleMapNumber(cm, mapName, viewerKey, value, defaultValue, minV, maxV)
  if not cm then
    return
  end

  local style = cm.style or {}
  cm.style = style

  local map = style[mapName]
  if type(map) ~= "table" then
    map = {}
    style[mapName] = map
  end

  local v = tonumber(value)
  if v == nil then
    v = defaultValue
  end

  if minV ~= nil and v < minV then
    v = minV
  end

  if maxV ~= nil and v > maxV then
    v = maxV
  end

  map[viewerKey] = v
end

local function GetViewerIconSize(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  local fallback = style.iconSize or 36
  return _PCM_GetStyleMapNumber(cm, "viewerSizes", viewerKey, fallback, 12, 86)
end

local function SetViewerIconSize(cm, viewerKey, v)
  _PCM_SetStyleMapNumber(cm, "viewerSizes", viewerKey, v, 36, 12, 86)
end

local function GetViewerIconSpacing(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  local fallback = style.iconSpacing or 0
  return _PCM_GetStyleMapNumber(cm, "viewerSpacing", viewerKey, fallback, 0, 8)
end

local function SetViewerIconSpacing(cm, viewerKey, v)
  _PCM_SetStyleMapNumber(cm, "viewerSpacing", viewerKey, v, 4, 0, 8)
end

local function GetViewerWidthMode(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  style.viewerWidthMode = style.viewerWidthMode or {}

  local m = style.viewerWidthMode[viewerKey]

  -- Defaults:
  -- Essential + Utility should start in fixed width mode.
  if m == nil and (viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer") then
    style.viewerWidthMode[viewerKey] = "fixed"
    return "fixed"
  end

  if m ~= "fixed" then
    m = "icon"
  end
  return m
end

local function SetViewerWidthMode(cm, viewerKey, mode)
  local style = cm.style or {}
  cm.style = style
  style.viewerWidthMode = style.viewerWidthMode or {}

  if mode == "fixed" then
    style.viewerWidthMode[viewerKey] = "fixed"
  else
    style.viewerWidthMode[viewerKey] = "icon"
  end
end

local function GetViewerFixedWidth(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  style.viewerFixedWidth = style.viewerFixedWidth or {}

  local w = style.viewerFixedWidth[viewerKey]

  -- Defaults:
  -- Essential should start at 400.
  -- Utility should start at 300.
  if w == nil and viewerKey == "EssentialCooldownViewer" then
    w = 400
    style.viewerFixedWidth[viewerKey] = w
  elseif w == nil and viewerKey == "UtilityCooldownViewer" then
    w = 300
    style.viewerFixedWidth[viewerKey] = w
  elseif w == nil then
    w = 400
  end

  w = tonumber(w) or 300
  if w < 1 then w = 1 end
  if w > 1000 then w = 1000 end
  return w
end

local function SetViewerFixedWidth(cm, viewerKey, width)
  local style = cm.style or {}
  cm.style = style
  style.viewerFixedWidth = style.viewerFixedWidth or {}

  local w = tonumber(width) or 300
  if w < 1 then w = 1 end
  if w > 1000 then w = 1000 end
  style.viewerFixedWidth[viewerKey] = w
end

local function GetViewerIconsPerRow(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  style.viewerColumns = style.viewerColumns or {}

  local v = style.viewerColumns[viewerKey]
  v = tonumber(v) or 0
  if v < 0 then v = 0 end
  if v > 40 then v = 40 end
  return v
end

local function SetViewerIconsPerRow(cm, viewerKey, v)
  local style = cm.style or {}
  cm.style = style
  style.viewerColumns = style.viewerColumns or {}

  v = tonumber(v) or 0
  if v < 0 then v = 0 end
  if v > 40 then v = 40 end
  style.viewerColumns[viewerKey] = v
end

local function GetViewerRowGrowth(cm, viewerKey)
  local style = cm.style or {}
  cm.style = style
  style.viewerRowGrowth = style.viewerRowGrowth or {}

  if style.viewerRowGrowth[viewerKey] == "UP" then
    return "UP"
  end

  return "DOWN"
end

local function SetViewerRowGrowth(cm, viewerKey, growth)
  local style = cm.style or {}
  cm.style = style
  style.viewerRowGrowth = style.viewerRowGrowth or {}
  style.viewerRowGrowth[viewerKey] = growth == "UP" and "UP" or "DOWN"
end


local function GetViewerSwipeDB(cm, viewerKey)
  if not cm then
    return nil, nil
  end

  local entry = ns.PCM_DBExports.GetViewerSwipeDB(viewerKey)
  return cm.viewerSwipes, entry
end

local function GetViewerFontConfig(viewerKey)
  local fonts = Cooldowns._GetFontDB()
  fonts.viewers = fonts.viewers or {}
  local v = fonts.viewers[viewerKey]
  if not v then
    v = {}
    fonts.viewers[viewerKey] = v
  end

  v.cooldown = v.cooldown or {}
  v.charge   = v.charge   or {}

  return fonts, v
end

local function _PCM_GetFontColorValue(tbl)
  local c = tbl and tbl.color or nil
  local r, g, b, a = 1, 1, 1, 1
  if type(c) == "table" then
    r = c.r or c[1] or r
    g = c.g or c[2] or g
    b = c.b or c[3] or b
    a = c.a or c[4] or a
  end
  return r, g, b, a
end

local function _PCM_RefreshBuffIconViewer(viewerKey)
  _PCM_ConfigRefreshViewers(viewerKey, {
    splitFonts = true,
    fontLabelPrefix = "Buff/proc",
    depthRole = "child",
    showWidthMode = false,
    showViewerBorder = false,
    showIconBorder = true,
    requireReload = false,
    fontOnly = true,
  })
end

local function _PCM_BuildBuffIconFontArgs(cm, viewerKey, prefix, fontKey, orderBase)
  local args = {}

  local function GetFontTable()
    local viewerFonts = ns.PCM_DBExports.GetProfileBuffsViewerFontDB(viewerKey)
    viewerFonts[fontKey] = viewerFonts[fontKey] or {}
    return viewerFonts[fontKey]
  end

  args[prefix .. "Size"] = {
    type = "range",
    name = prefix .. " font size",
    desc = "Set to 0 to use the UI theme.",
    order = orderBase + 1,
    min = 0,
    max = 48,
    step = 1,

    get = function()
      local f = GetFontTable()
      local sz = tonumber(f.size) or 0
      if sz < 0 then sz = 0 end
      if sz > 48 then sz = 48 end
      return sz
    end,
    set = function(_, v)
      local f = GetFontTable()
      v = tonumber(v) or 0
      if v <= 0 then
        f.size = nil
      else
        f.size = v
      end
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args[prefix .. "Font"] = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = prefix .. " font",
    order = orderBase + 2,

    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local f = GetFontTable()
      return OptionsUtil.ResolveFontKey(f.font)
    end,
    set = function(_, key)
      local f = GetFontTable()
      f.font = (key ~= "") and key or nil
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args[prefix .. "Outline"] = {
    type = "select",
    name = prefix .. " font outline",
    order = orderBase + 3,

    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local f = GetFontTable()
      return f.flags or ""
    end,
    set = function(_, key)
      local f = GetFontTable()
      f.flags = (key ~= "") and key or nil
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args[prefix .. "OffsetX"] = {
    type = "range",
    name = prefix .. " X offset",
    order = orderBase + 4,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetFontTable()
      local off = tonumber(f.offsetX) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local f = GetFontTable()
      f.offsetX = tonumber(v) or 0
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args[prefix .. "OffsetY"] = {
    type = "range",
    name = prefix .. " Y offset",
    order = orderBase + 5,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetFontTable()
      local off = tonumber(f.offsetY) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local f = GetFontTable()
      f.offsetY = tonumber(v) or 0
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args[prefix .. "Color"] = {
    type = "color",
    name = prefix .. " font color",
    order = orderBase + 6,
    hasAlpha = true,

    get = function()
      return _PCM_GetFontColorValue(GetFontTable())
    end,
    set = function(_, r, g, b, a)
      local f = GetFontTable()
      f.color = { r, g, b, a or 1 }
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  return args
end

local _PCM_BuildIconOverrideArgs
local _PCM_BuildIconOverrideTreeArgs

local function _PCM_BuildBuffIconsTabArgs()
  local cm = GetPCMBuffsRoot()
  local viewerCM = GetPCMRoot()
  local args = {}
  local viewerKey = "BuffIconCooldownViewer"

  if not cm then
    args.__missing = {
      type = "description",
      name = "Buffs profile is not available.",
      order = 1,

    }
    return args
  end

  args.showTooltips = {
    type = "toggle",
    name = "Show tooltips",
    desc = "Saved in Blizzard Edit Mode for this character.",
    order = 7,
    disabled = function()
      return not Cooldowns:CanChangeViewerEditModeSettings()
    end,
    get = function()
      return Cooldowns:GetViewerTooltipsEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetViewerTooltipsEnabled(viewerKey, enabled == true)
    end,
  }

  args.hideWhenInactive = {
    type = "toggle",
    name = "Hide when inactive",
    desc = "Saved in Blizzard Edit Mode for this character.",
    order = 8,
    disabled = function()
      return not Cooldowns:CanChangeViewerEditModeSettings()
    end,
    get = function()
      return Cooldowns:GetViewerHideWhenInactive(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetViewerHideWhenInactive(viewerKey, enabled == true)
    end,
  }

  args.growth = {
    type = "select",
    name = "Growth direction",
    order = 9,
    values = {
      CENTER = "Centered",
      RIGHT = "Grow right",
      LEFT = "Grow left",
    },
    get = function()
      return cm.style.viewerGrowth[viewerKey] or "CENTER"
    end,
    set = function(_, value)
      cm.style.viewerGrowth[viewerKey] = value
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args.iconSize = {
    type = "range",
    name = "Icon size",
    order = 10,
    min = 12,
    max = 86,
    step = 1,

    get = function()
      return GetViewerIconSize(cm, viewerKey)
    end,
    set = function(_, v)
      SetViewerIconSize(cm, viewerKey, v)
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args.iconSpacing = {
    type = "range",
    name = "Icon spacing",
    order = 11,
    min = 0,
    max = 8,
    step = 1,

    get = function()
      return GetViewerIconSpacing(cm, viewerKey)
    end,
    set = function(_, v)
      SetViewerIconSpacing(cm, viewerKey, v)
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args.iconsPerRow = {
    type = "range",
    name = "Max icons per row",
    desc = "Set 0 to keep the Buff Icon viewer on one row.",
    order = 12,
    min = 0,
    max = 40,
    step = 1,

    get = function()
      return GetViewerIconsPerRow(cm, viewerKey)
    end,
    set = function(_, v)
      SetViewerIconsPerRow(cm, viewerKey, v)
      _PCM_RefreshBuffIconViewer(viewerKey)
    end,
  }

  args.viewerBorderColor = {
    type = "color",
    name = "Border color",
    order = 20,
    hasAlpha = true,

    get = function()
      local _, vb = GetViewerBorderDB(viewerCM, viewerKey)
      local c = vb.color or { 1, 1, 1, 1 }
      return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
    end,
    set = function(_, r, g, b, a)
      local _, vb = GetViewerBorderDB(viewerCM, viewerKey)
      vb.color = { r, g, b, a or 1 }
      vb.useModule = false
      Cooldowns.SetViewerBorderColor(viewerKey, r, g, b, a or 1)
      Cooldowns._RefreshViewerBordersOnly(viewerKey)
    end,
  }

  local countArgs = _PCM_BuildBuffIconFontArgs(cm, viewerKey, "Count", "cooldown", 30)
  for k, v in pairs(countArgs) do
    args[k] = v
  end

  local stackArgs = _PCM_BuildBuffIconFontArgs(cm, viewerKey, "Stack", "charge", 50)
  for k, v in pairs(stackArgs) do
    args[k] = v
  end

  return {
    general = {
      type = "group",
      name = "General",
      order = 5,
      args = {
        showTooltips = args.showTooltips,
        hideWhenInactive = args.hideWhenInactive,
      },
    },
    iconOverrides = {
      type = "group",
      name = "Icon overrides",
      order = 100,
      childGroups = "tree",
      args = _PCM_BuildIconOverrideTreeArgs(viewerKey),
    },
    layout = {
      type = "group",
      name = "Layout",
      order = 10,
      args = {
        growth = args.growth,
        iconSize = args.iconSize,
        iconSpacing = args.iconSpacing,
        iconsPerRow = args.iconsPerRow,
      },
    },
    borders = {
      type = "group",
      name = "Borders",
      order = 20,
      args = {
        viewerBorderColor = args.viewerBorderColor,
      },
    },
    countText = {
      type = "group",
      name = "Cooldown text",
      order = 30,
      args = {
        CountSize = args.CountSize,
        CountFont = args.CountFont,
        CountOutline = args.CountOutline,
        CountOffsetX = args.CountOffsetX,
        CountOffsetY = args.CountOffsetY,
        CountColor = args.CountColor,
      },
    },
    stackText = {
      type = "group",
      name = "Stack text",
      order = 40,
      args = {
        StackSize = args.StackSize,
        StackFont = args.StackFont,
        StackOutline = args.StackOutline,
        StackOffsetX = args.StackOffsetX,
        StackOffsetY = args.StackOffsetY,
        StackColor = args.StackColor,
      },
    },
  }
end

local function _PCM_GetMainBuffBarsRoot()
  local E = ns.PCM_DBExports
  local cm = E.GetPCMRoot()
  if not cm then
    return nil, nil
  end

  local style = E.GetStyleDB()
  cm.style = style
  style.buffBar = style.buffBar or {}

  return cm, style
end


local function _PCM_BuildCooldownViewerArgs(cm, viewerKey, opts)
  opts = opts or {}
  local args = {}


  local function GetViewerBorder()
    local _, viewerBorders = GetViewerBorderDB(cm, viewerKey)
    return viewerBorders
  end

  local function GetViewerFonts()
    local _, viewerFonts = GetViewerFontConfig(viewerKey)
    return viewerFonts
  end

  local function GetViewerBorderPad()
    local border = GetViewerBorder()
    local thickness = tonumber(border and border.thickness) or 0
    return ns.Pixel.Round(math.max(0, thickness) * 2)
  end

  local function GetViewerTotalWidth()
    if GetViewerWidthMode(cm, viewerKey) == "fixed" then
      return ns.Pixel.Round(GetViewerFixedWidth(cm, viewerKey) + GetViewerBorderPad())
    end

    local anchor = Cooldowns:GetViewerAnchorFrame(viewerKey)
    local width = anchor and anchor:GetWidth() or nil
    if width and width > 1 then
      return ns.Pixel.Round(width)
    end

    return ns.Pixel.Round(GetViewerFixedWidth(cm, viewerKey) + GetViewerBorderPad())
  end

  local function SetViewerTotalWidth(value)
    local totalWidth = math.max(120, math.min(1000, tonumber(value) or 120))
    SetViewerWidthMode(cm, viewerKey, "fixed")
    SetViewerFixedWidth(
      cm,
      viewerKey,
      math.max(1, ns.Pixel.Round(totalWidth - GetViewerBorderPad()))
    )
    _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
    ns.FrameUtil.RefreshSmartSnapState("PCM_" .. viewerKey)
  end

  args.widthMode = {
    type = "select",
    name = "Width mode",
    order = 10,

    values = {
      icon = "Icon size",
      fixed = "Fixed width",
    },
    get = function()
      return GetViewerWidthMode(cm, viewerKey)
    end,
    set = function(_, key)
      SetViewerWidthMode(cm, viewerKey, key)
      _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
      ns.FrameUtil.RefreshSmartSnapState("PCM_" .. viewerKey)
    end,
  }

  args.iconSize = {
    type = "range",
    name = "Icon size",
    order = 11,
    min = 12,
    max = 86,
    step = 1,

    hidden = function()
      return GetViewerWidthMode(cm, viewerKey) == "fixed"
    end,
    get = function()
      return GetViewerIconSize(cm, viewerKey)
    end,
    set = function(_, v)
      SetViewerIconSize(cm, viewerKey, v)
      _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
      ns.FrameUtil.RefreshSmartSnapState("PCM_" .. viewerKey)
    end,
  }

  args.fixedWidth = {
    type = "range",
    name = "Width",
    order = 12,
    min = 120,
    max = 1000,
    step = 1,

    get = function()
      return GetViewerTotalWidth()
    end,
    set = function(_, v)
      SetViewerTotalWidth(v)
    end,
  }

  args.iconSpacing = {
    type = "range",
    name = "Icon spacing",
    order = 13,
    min = 0,
    max = 8,
    step = 1,

    get = function()
      return GetViewerIconSpacing(cm, viewerKey)
    end,
    set = function(_, v)
      SetViewerIconSpacing(cm, viewerKey, v)
      _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
      ns.FrameUtil.RefreshSmartSnapState("PCM_" .. viewerKey)
    end,
  }

  if viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer" then
    args.iconsPerRow = {
      type = "range",
      name = "Max icons on first row",
      desc = "Set 0 to keep this cooldown viewer on one row.",
      order = 14,
      min = 0,
      max = 40,
      step = 1,

      get = function()
        return GetViewerIconsPerRow(cm, viewerKey)
      end,
      set = function(_, v)
        SetViewerIconsPerRow(cm, viewerKey, v)
        _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
      end,
    }

    args.growUp = {
      type = "toggle",
      name = "Grow up",
      desc = "Place overflow icons above the first row.",
      order = 15,
      get = function()
        return GetViewerRowGrowth(cm, viewerKey) == "UP"
      end,
      set = function(_, enabled)
        SetViewerRowGrowth(cm, viewerKey, enabled and "UP" or "DOWN")
        _PCM_ConfigRefreshViewers(viewerKey, opts, "layout")
      end,
    }
  end

  args.showTooltips = {
    type = "toggle",
    name = "Show tooltips",
    desc = "Saved in Blizzard Edit Mode for this character.",
    order = 16,
    disabled = function()
      return not Cooldowns:CanChangeViewerEditModeSettings()
    end,
    get = function()
      return Cooldowns:GetViewerTooltipsEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetViewerTooltipsEnabled(viewerKey, enabled == true)
    end,
  }

  args.borderThickness = {
    type = "range",
    name = "Border thickness",
    order = 30,
    min = 0,
    max = 6,
    step = 1,

    get = function()
      local t = GetViewerBorder().thickness or 2
      t = tonumber(t) or 2
      if t < 0 then t = 0 end
      if t > 6 then t = 6 end
      return t
    end,
    set = function(_, v)
      local vb = GetViewerBorder()
      vb.thickness = v
      vb.useModule = false

      Cooldowns.SetViewerBorderThickness(viewerKey, v)
      Cooldowns._RefreshViewerBordersOnly(viewerKey)
    end,
  }

  args.borderColor = {
    type = "color",
    name = "Border color",
    order = 31,
    hasAlpha = true,

    get = function()
      local c = GetViewerBorder().color or { 1, 1, 1, 1 }
      return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
    end,
    set = function(_, r, g, b, a)
      local vb = GetViewerBorder()
      vb.color = { r, g, b, a or 1 }
      vb.useModule = false

      Cooldowns.SetViewerBorderColor(viewerKey, r, g, b, a or 1)
      Cooldowns._RefreshViewerBordersOnly(viewerKey)
    end,
  }

  args.swipeGCD = {
    type = "toggle",
    name = "Show global cooldown swipe",
    order = 40,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      return v and v.gcd ~= false or false
    end,
    set = function(_, enabled)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.gcd = enabled == true
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.swipeCooldown = {
    type = "toggle",
    name = "Show cooldown swipe",
    order = 41,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      return v and v.cooldown ~= false or false
    end,
    set = function(_, enabled)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.cooldown = enabled == true
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.swipeDuration = {
    type = "toggle",
    name = "Show aura duration swipe",
    order = 42,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      return v and v.duration ~= false or false
    end,
    set = function(_, enabled)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.duration = enabled == true
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.swipeColor = {
    type = "color",
    name = "Swipe color",
    order = 42,
    hasAlpha = true,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      local c = v and v.swipeColor or { 0, 0, 0, 0.8 }
      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.8
    end,
    set = function(_, r, g, b, a)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.swipeColor = { r, g, b, a }
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.swipeEdge = {
    type = "toggle",
    name = "Show swipe edge",
    order = 43,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      return v and v.drawEdge ~= false or false
    end,
    set = function(_, enabled)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.drawEdge = enabled == true
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.countCooldown = {
    type = "toggle",
    name = "Show cooldown text",
    order = 44,

    get = function()
      cm.count = cm.count or {}
      cm.count[viewerKey] = cm.count[viewerKey] or {}
      return cm.count[viewerKey].cooldown ~= false
    end,
    set = function(_, enabled)
      Cooldowns:SetCooldownCountEnabled(viewerKey, enabled == true)
    end,
  }

  args.countDuration = {
    type = "toggle",
    name = "Show aura duration text",
    order = 45,

    get = function()
      return Cooldowns:GetDurationCountEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetDurationCountEnabled(viewerKey, enabled == true)
    end,
  }

  args.countCharge = {
    type = "toggle",
    name = "Show charge count",
    order = 45,

    get = function()
      return Cooldowns:GetChargeCountEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetChargeCountEnabled(viewerKey, enabled == true)
    end,
  }

  args.forceCooldown = {
    type = "toggle",
    name = "Prefer cooldown display",
    desc = "Use cooldown swipe and text when both displays are available.",
    order = 46,

    get = function()
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      return v and v.forceCooldownSwipe == true or false
    end,
    set = function(_, enabled)
      local _, v = GetViewerSwipeDB(cm, viewerKey)
      v.forceCooldownSwipe = enabled == true
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.countBuff = {
    type = "toggle",
    name = "Show buff stacks",
    order = 47,

    hidden = true,
    get = function()
      return Cooldowns:GetBuffCountEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetBuffCountEnabled(viewerKey, enabled == true)
    end,
  }

  args.keybindToggle = {
    type = "toggle",
    name = "Show keybinds",
    order = 50,

    get = function()
      return Cooldowns:GetKeybindTextEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetKeybindTextEnabled(viewerKey, not not enabled)
    end,
  }

  args.cooldownFontSize = {
    type = "range",
    name = "Cooldown font size",
    desc = "Set to 0 to use the UI theme.",
    order = 60,
    min = 0,
    max = 48,
    step = 1,

    get = function()
      local f = GetViewerFonts().cooldown or {}
      local sz = tonumber(f.size) or 0
      if sz < 0 then sz = 0 end
      if sz > 48 then sz = 48 end
      return sz
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      if tonumber(v) <= 0 then
        vf.cooldown.size = nil
      else
        vf.cooldown.size = tonumber(v)
      end
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.cooldownFont = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Cooldown font",
    order = 61,

    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().cooldown or {}
      return OptionsUtil.ResolveFontKey(f.font)
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      vf.cooldown.font = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.cooldownOutline = {
    type = "select",
    name = "Cooldown font outline",
    order = 62,

    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().cooldown or {}
      return f.flags or ""
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      vf.cooldown.flags = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.cooldownOffsetX = {
    type = "range",
    name = "Cooldown X offset",
    order = 63,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().cooldown or {}
      local off = tonumber(f.offsetX) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      vf.cooldown.offsetX = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.cooldownOffsetY = {
    type = "range",
    name = "Cooldown Y offset",
    order = 64,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().cooldown or {}
      local off = tonumber(f.offsetY) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      vf.cooldown.offsetY = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.cooldownColor = {
    type = "color",
    name = "Cooldown font color",
    order = 65,
    hasAlpha = true,

    get = function()
      local f = GetViewerFonts().cooldown or {}
      local c = f.color or { 1, 1, 1, 1 }
      return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
    end,
    set = function(_, r, g, b, a)
      local vf = GetViewerFonts()
      vf.cooldown = vf.cooldown or {}
      vf.cooldown.color = { r, g, b, a or 1 }
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindFontSize = {
    type = "range",
    name = "Keybind font size",
    desc = "Set to 0 to use the UI theme.",
    order = 70,
    min = 0,
    max = 32,
    step = 1,

    get = function()
      local f = GetViewerFonts().keybind or {}
      local sz = tonumber(f.size) or 0
      if sz < 0 then sz = 0 end
      if sz > 32 then sz = 32 end
      return sz
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      if tonumber(v) <= 0 then
        vf.keybind.size = nil
      else
        vf.keybind.size = tonumber(v)
      end
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindFont = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Keybind font",
    order = 71,

    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().keybind or {}
      return OptionsUtil.ResolveFontKey(f.font)
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      vf.keybind.font = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindOutline = {
    type = "select",
    name = "Keybind font outline",
    order = 72,

    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().keybind or {}
      return f.flags or ""
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      vf.keybind.flags = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindOffsetX = {
    type = "range",
    name = "Keybind X offset",
    order = 73,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().keybind or {}
      local off = tonumber(f.offsetX) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      vf.keybind.offsetX = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindOffsetY = {
    type = "range",
    name = "Keybind Y offset",
    order = 74,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().keybind or {}
      local off = tonumber(f.offsetY) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      vf.keybind.offsetY = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.keybindColor = {
    type = "color",
    name = "Keybind font color",
    order = 75,
    hasAlpha = true,

    get = function()
      local f = GetViewerFonts().keybind or {}
      local c = f.color or { 1, 1, 1, 1 }
      return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
    end,
    set = function(_, r, g, b, a)
      local vf = GetViewerFonts()
      vf.keybind = vf.keybind or {}
      vf.keybind.color = { r, g, b, a or 1 }
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeFontSize = {
    type = "range",
    name = "Charge font size",
    desc = "Set to 0 to use the UI theme.",
    order = 80,
    min = 0,
    max = 48,
    step = 1,

    get = function()
      local f = GetViewerFonts().charge or {}
      local sz = tonumber(f.size) or 0
      if sz < 0 then sz = 0 end
      if sz > 48 then sz = 48 end
      return sz
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      if tonumber(v) <= 0 then
        vf.charge.size = nil
      else
        vf.charge.size = tonumber(v)
      end
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeFont = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Charge font",
    order = 81,

    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().charge or {}
      return OptionsUtil.ResolveFontKey(f.font)
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      vf.charge.font = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeOutline = {
    type = "select",
    name = "Charge font outline",
    order = 82,

    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local f = GetViewerFonts().charge or {}
      return f.flags or ""
    end,
    set = function(_, key)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      vf.charge.flags = (key ~= "") and key or nil
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeOffsetX = {
    type = "range",
    name = "Charge X offset",
    order = 83,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().charge or {}
      local off = tonumber(f.offsetX) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      vf.charge.offsetX = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeOffsetY = {
    type = "range",
    name = "Charge Y offset",
    order = 84,
    min = -64,
    max = 64,
    step = 1,

    get = function()
      local f = GetViewerFonts().charge or {}
      local off = tonumber(f.offsetY) or 0
      if off < -64 then off = -64 end
      if off > 64 then off = 64 end
      return off
    end,
    set = function(_, v)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      vf.charge.offsetY = tonumber(v) or 0
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  args.chargeColor = {
    type = "color",
    name = "Charge font color",
    order = 85,
    hasAlpha = true,

    get = function()
      local f = GetViewerFonts().charge or {}
      local c = f.color or { 1, 1, 1, 1 }
      return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
    end,
    set = function(_, r, g, b, a)
      local vf = GetViewerFonts()
      vf.charge = vf.charge or {}
      vf.charge.color = { r, g, b, a or 1 }
      _PCM_ConfigRefreshViewers(viewerKey, opts)
    end,
  }

  return args
end


local function _PCM_BuildEssentialGlowArgs(cm)
  local args = {}
  local glow = cm.glow or {}
  cm.glow = glow


  local function CurrentGlowType()
    return tostring(glow.type or "pixel")
  end

  args.enabled = {
    type = "toggle",
    name = "Enable custom glow",
    order = 1,

    get = function()
      return glow.enabled ~= false
    end,
    set = function(_, v)
      glow.enabled = (v and true) or false
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.type = {
    type = "select",
    name = "Glow style",
    order = 2,

    values = {
      pixel = "Pixel glow",
      autocast = "Autocast glow",
      actionbutton = "Action Button glow",
      proc = "Proc glow",
    },
    get = function()
      return glow.type or "pixel"
    end,
    set = function(_, key)
      glow.type = key or "pixel"
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.color = {
    type = "color",
    name = "Glow color",
    order = 3,
    hasAlpha = true,

    get = function()
      local c = glow.color or { 0.95, 0.95, 0.32, 1 }
      return c[1] or 1, c[2] or 1, c[3] or 0.32, c[4] or 1
    end,
    set = function(_, r, g, b, a)
      glow.color = { r, g, b, a or 1 }
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.speed = {
    type = "range",
    name = "Glow speed",
    order = 4,
    min = 20,
    max = 200,
    step = 1,

    get = function()
      local v = tonumber(glow.speed)
      if not v then v = 100 end
      glow.speed = v
      return v
    end,
    set = function(_, v)
      glow.speed = tonumber(v) or 100
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.scale = {
    type = "range",
    name = "Glow scale",
    order = 5,
    min = 0.5,
    max = 2.0,
    step = 0.05,

    hidden = function()
      return CurrentGlowType() ~= "autocast"
    end,
    get = function()
      local v = tonumber(glow.scale)
      if not v then v = 1.0 end
      glow.scale = v
      return v
    end,
    set = function(_, v)
      glow.scale = tonumber(v) or 1.0
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.lines = {
    type = "range",
    name = "Glow lines",
    order = 6,
    min = 2,
    max = 16,
    step = 1,

    hidden = function()
      local glowType = CurrentGlowType()
      return glowType ~= "pixel" and glowType ~= "autocast"
    end,
    get = function()
      local v = tonumber(glow.lines)
      if not v then v = 8 end
      glow.lines = v
      return v
    end,
    set = function(_, v)
      glow.lines = tonumber(v) or 8
      Cooldowns:RefreshViewerGlows()
    end,
  }

  args.thickness = {
    type = "range",
    name = "Glow thickness",
    order = 7,
    min = 1,
    max = 6,
    step = 1,

    hidden = function()
      return CurrentGlowType() ~= "pixel"
    end,
    get = function()
      local v = tonumber(glow.thickness)
      if not v then v = 2 end
      glow.thickness = v
      return v
    end,
    set = function(_, v)
      glow.thickness = tonumber(v) or 2
      Cooldowns:RefreshViewerGlows()
    end,
  }

  return args
end

local ICON_INHERIT = "__INHERIT"

local function _PCM_GetIconFontValues()
  local values = OptionsUtil.BuildFontValues(false)
  values[ICON_INHERIT] = "Use viewer setting"
  return values
end

local function _PCM_GetIconOutlineValues()
  local values = OptionsUtil.BuildOutlineValues(false)
  values[ICON_INHERIT] = "Use viewer setting"
  return values
end

local function _PCM_GetIconTriState(value, trueKey, falseKey)
  if value == nil then
    return ICON_INHERIT
  end
  return value == true and trueKey or falseKey
end

local function _PCM_SetIconTriState(entry, section, field, value, trueKey)
  if value == ICON_INHERIT then
    IconSettings:SetField(entry, section, field, nil)
  else
    IconSettings:SetField(entry, section, field, value == trueKey)
  end
end

local function _PCM_GetColorComponents(color)
  color = type(color) == "table" and color or {}
  return color.r or color[1] or 1,
    color.g or color[2] or 1,
    color.b or color[3] or 1,
    color.a or color[4] or 1
end

local function _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, role, label, orderBase)
  local function Refresh()
    Cooldowns:RefreshIndividualIconSettings(viewerKey)
  end

  local function GetViewerFont()
    if viewerKey == "BuffIconCooldownViewer" then
      local viewerFonts = ns.PCM_DBExports.GetProfileBuffsViewerFontDB(viewerKey)
      return viewerFonts[role] or {}
    end

    return Cooldowns._ResolveFontOpts(role, viewerKey) or {}
  end

  local prefix = role
  args[prefix .. "Header"] = {
    type = "header",
    name = label,
    order = orderBase,
  }

  args[prefix .. "Show"] = {
    type = "select",
    name = "Visibility",
    order = orderBase + 1,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, role, "show"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, role, "show", value, "SHOW")
      Refresh()
    end,
  }

  args[prefix .. "Font"] = {
    type = "select",
    name = "Font",
    order = orderBase + 2,
    values = _PCM_GetIconFontValues,
    get = function()
      return IconSettings:GetField(entry, role, "font") or ICON_INHERIT
    end,
    set = function(_, value)
      IconSettings:SetField(
        entry,
        role,
        "font",
        value == ICON_INHERIT and nil or value
      )
      Refresh()
    end,
  }

  args[prefix .. "SizeOverride"] = {
    type = "toggle",
    name = "Custom font size",
    order = orderBase + 3,
    get = function()
      return IconSettings:GetField(entry, role, "size") ~= nil
    end,
    set = function(_, enabled)
      IconSettings:SetField(
        entry,
        role,
        "size",
        enabled and (GetViewerFont().size or 12) or nil
      )
      Refresh()
    end,
  }

  args[prefix .. "Size"] = {
    type = "range",
    name = "Font size",
    order = orderBase + 4,
    min = 6,
    max = 48,
    step = 1,
    disabled = function()
      return IconSettings:GetField(entry, role, "size") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, role, "size") or GetViewerFont().size or 12
    end,
    set = function(_, value)
      IconSettings:SetField(entry, role, "size", tonumber(value) or 12)
      Refresh()
    end,
  }

  args[prefix .. "Outline"] = {
    type = "select",
    name = "Outline",
    order = orderBase + 5,
    values = _PCM_GetIconOutlineValues,
    get = function()
      local value = IconSettings:GetField(entry, role, "flags")
      return value == nil and ICON_INHERIT or value
    end,
    set = function(_, value)
      IconSettings:SetField(
        entry,
        role,
        "flags",
        value == ICON_INHERIT and nil or value
      )
      Refresh()
    end,
  }

  args[prefix .. "PositionOverride"] = {
    type = "toggle",
    name = "Custom position",
    order = orderBase + 6,
    get = function()
      return IconSettings:GetField(entry, role, "offsetX") ~= nil
        or IconSettings:GetField(entry, role, "offsetY") ~= nil
    end,
    set = function(_, enabled)
      if enabled then
        local viewerFont = GetViewerFont()
        IconSettings:SetField(entry, role, "offsetX", viewerFont.offsetX or 0)
        IconSettings:SetField(entry, role, "offsetY", viewerFont.offsetY or 0)
      else
        IconSettings:SetField(entry, role, "offsetX", nil)
        IconSettings:SetField(entry, role, "offsetY", nil)
      end
      Refresh()
    end,
  }

  args[prefix .. "OffsetX"] = {
    type = "range",
    name = "X offset",
    order = orderBase + 7,
    min = -64,
    max = 64,
    step = 1,
    disabled = function()
      return IconSettings:GetField(entry, role, "offsetX") == nil
        and IconSettings:GetField(entry, role, "offsetY") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, role, "offsetX") or GetViewerFont().offsetX or 0
    end,
    set = function(_, value)
      IconSettings:SetField(entry, role, "offsetX", tonumber(value) or 0)
      Refresh()
    end,
  }

  args[prefix .. "OffsetY"] = {
    type = "range",
    name = "Y offset",
    order = orderBase + 8,
    min = -64,
    max = 64,
    step = 1,
    disabled = function()
      return IconSettings:GetField(entry, role, "offsetX") == nil
        and IconSettings:GetField(entry, role, "offsetY") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, role, "offsetY") or GetViewerFont().offsetY or 0
    end,
    set = function(_, value)
      IconSettings:SetField(entry, role, "offsetY", tonumber(value) or 0)
      Refresh()
    end,
  }

  args[prefix .. "ColorOverride"] = {
    type = "toggle",
    name = "Custom color",
    order = orderBase + 9,
    get = function()
      return IconSettings:GetField(entry, role, "color") ~= nil
    end,
    set = function(_, enabled)
      local color
      if enabled then
        local r, g, b, a = _PCM_GetColorComponents(GetViewerFont().color)
        color = { r, g, b, a }
      end
      IconSettings:SetField(entry, role, "color", color)
      Refresh()
    end,
  }

  args[prefix .. "Color"] = {
    type = "color",
    name = "Color",
    order = orderBase + 10,
    hasAlpha = true,
    disabled = function()
      return IconSettings:GetField(entry, role, "color") == nil
    end,
    get = function()
      return _PCM_GetColorComponents(
        IconSettings:GetField(entry, role, "color") or GetViewerFont().color
      )
    end,
    set = function(_, r, g, b, a)
      IconSettings:SetField(entry, role, "color", { r, g, b, a or 1 })
      Refresh()
    end,
  }
end

_PCM_BuildIconOverrideArgs = function(viewerKey, entry)
  local args = {}

  if not entry then
    return args
  end

  args.identity = {
    type = "description",
    name = "|T" .. tostring(entry.texture or 134400) .. ":20:20:0:0|t " .. entry.name,
    order = 2,
  }

  args.previewState = {
    type = "select",
    name = "Preview state",
    order = 3,
    values = function()
      local values = { AUTO = "Auto" }
      if entry.settingsFamily == "buff" then
        values.AURA = "Aura active"
      else
        values.READY = entry.hasCharges and "Maximum charges" or "Ready"
        values.COOLDOWN = entry.hasCharges and "Recharging" or "Cooldown"
      end
      return values
    end,
    get = function()
      return IconSettings:GetPreviewState(viewerKey) or "AUTO"
    end,
    set = function(_, value)
      IconSettings:SetPreviewState(viewerKey, value == "AUTO" and nil or value)
      if ns.PCMPreview and ns.PCMPreview.Refresh then
        ns.PCMPreview.Refresh()
      end
    end,
  }

  if entry.settingsFamily == "buff" then
    _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, "cooldown", "Duration text", 10)
    _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, "charge", "Stack text", 30)

    local function RefreshAuraPreview()
      IconSettings:SetPreviewState(viewerKey, "AURA", 3)
      Cooldowns:RefreshIndividualIconSettings(viewerKey)
      if ns.PCMPreview and ns.PCMPreview.Refresh then
        ns.PCMPreview.Refresh()
      end
    end

    args.swipeHeader = {
      type = "header",
      name = "Aura swipe",
      order = 50,
    }
    args.swipeShow = {
      type = "select",
      name = "Visibility",
      order = 51,
      values = {
        [ICON_INHERIT] = "Use viewer setting",
        SHOW = "Show",
        HIDE = "Hide",
      },
      get = function()
        return _PCM_GetIconTriState(
          IconSettings:GetField(entry, "swipe", "show"),
          "SHOW",
          "HIDE"
        )
      end,
      set = function(_, value)
        _PCM_SetIconTriState(entry, "swipe", "show", value, "SHOW")
        RefreshAuraPreview()
      end,
    }

    args.auraHeader = {
      type = "header",
      name = "Aura active",
      order = 60,
    }
    args.auraAlphaOverride = {
      type = "toggle",
      name = "Custom opacity",
      order = 61,
      get = function()
        return IconSettings:GetField(entry, "appearance", "auraAlpha") ~= nil
      end,
      set = function(_, enabled)
        IconSettings:SetField(entry, "appearance", "auraAlpha", enabled and 1 or nil)
        RefreshAuraPreview()
      end,
    }
    args.auraAlpha = {
      type = "range",
      name = "Opacity",
      order = 62,
      min = 0,
      max = 1,
      step = 0.05,
      isPercent = true,
      disabled = function()
        return IconSettings:GetField(entry, "appearance", "auraAlpha") == nil
      end,
      get = function()
        return IconSettings:GetField(entry, "appearance", "auraAlpha") or 1
      end,
      set = function(_, value)
        IconSettings:SetField(entry, "appearance", "auraAlpha", tonumber(value) or 1)
        RefreshAuraPreview()
      end,
    }
    args.auraSaturationOverride = {
      type = "toggle",
      name = "Custom saturation",
      order = 63,
      get = function()
        return IconSettings:GetField(entry, "appearance", "auraSaturation") ~= nil
      end,
      set = function(_, enabled)
        IconSettings:SetField(entry, "appearance", "auraSaturation", enabled and 1 or nil)
        RefreshAuraPreview()
      end,
    }
    args.auraSaturation = {
      type = "range",
      name = "Saturation",
      order = 64,
      min = 0,
      max = 1,
      step = 0.05,
      isPercent = true,
      disabled = function()
        return IconSettings:GetField(entry, "appearance", "auraSaturation") == nil
      end,
      get = function()
        return IconSettings:GetField(entry, "appearance", "auraSaturation") or 1
      end,
      set = function(_, value)
        IconSettings:SetField(entry, "appearance", "auraSaturation", tonumber(value) or 1)
        RefreshAuraPreview()
      end,
    }
    args.auraGlowStyle = {
      type = "select",
      name = "Glow",
      order = 65,
      values = {
        NONE = "None",
        PIXEL = "Pixel",
        AUTOCAST = "Autocast",
        PROC = "Proc",
      },
      get = function()
        return IconSettings:GetField(entry, "appearance", "auraGlowStyle") or "NONE"
      end,
      set = function(_, value)
        IconSettings:SetField(
          entry,
          "appearance",
          "auraGlowStyle",
          value == "NONE" and nil or value
        )
        RefreshAuraPreview()
      end,
    }
    args.auraGlowColor = {
      type = "color",
      name = "Glow color",
      order = 66,
      hasAlpha = true,
      disabled = function()
        return IconSettings:GetField(entry, "appearance", "auraGlowStyle") == nil
      end,
      get = function()
        return _PCM_GetColorComponents(
          IconSettings:GetField(entry, "appearance", "auraGlowColor") or { 1, 0.55, 0.1, 1 }
        )
      end,
      set = function(_, r, g, b, a)
        IconSettings:SetField(entry, "appearance", "auraGlowColor", { r, g, b, a or 1 })
        RefreshAuraPreview()
      end,
    }
    args.customTexture = {
      type = "input",
      name = "Custom texture",
      desc = "Leave empty to use the spell icon. Enter a texture path or file ID.",
      order = 67,
      get = function()
        local value = IconSettings:GetField(entry, "appearance", "texture")
        return value == nil and "" or tostring(value)
      end,
      set = function(_, value)
        value = type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
        local texture
        if value ~= "" then
          texture = tonumber(value) or value
        end
        IconSettings:SetField(entry, "appearance", "texture", texture)
        RefreshAuraPreview()
      end,
    }
    args.resetIcon = {
      type = "execute",
      name = "Reset icon settings",
      order = 80,
      func = function()
        IconSettings:ResetEntry(entry)
        RefreshAuraPreview()
      end,
    }
    return args
  end

  _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, "cooldown", "Cooldown text", 10)
  _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, "charge", "Charge text", 30)
  _PCM_BuildIconTextSettingsArgs(args, viewerKey, entry, "keybind", "Keybind text", 50)

  local function Refresh()
    Cooldowns:RefreshIndividualIconSettings(viewerKey)
  end

  args.swipeHeader = {
    type = "header",
    name = "Cooldown swipe",
    order = 70,
  }

  args.swipeShow = {
    type = "select",
    name = "Visibility",
    order = 71,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "swipe", "show"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "swipe", "show", value, "SHOW")
      Refresh()
    end,
  }

  args.swipeSource = {
    type = "select",
    name = "Swipe source",
    desc = "Automatic shows an applied buff before the spell cooldown. Cooldown only ignores the buff duration.",
    order = 72,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      AUTOMATIC = "Automatic",
      COOLDOWN = "Cooldown only",
    },
    get = function()
      return IconSettings:GetField(entry, "swipe", "source") or ICON_INHERIT
    end,
    set = function(_, value)
      IconSettings:SetField(
        entry,
        "swipe",
        "source",
        value == ICON_INHERIT and nil or value
      )
      Refresh()
    end,
  }

  args.swipeEdge = {
    type = "select",
    name = "Edge",
    order = 73,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "swipe", "drawEdge"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "swipe", "drawEdge", value, "SHOW")
      Refresh()
    end,
  }

  args.swipeReverse = {
    type = "select",
    name = "Direction",
    order = 74,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      NORMAL = "Normal",
      REVERSE = "Reverse",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "swipe", "reverse"),
        "REVERSE",
        "NORMAL"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "swipe", "reverse", value, "REVERSE")
      Refresh()
    end,
  }

  args.swipeColorOverride = {
    type = "toggle",
    name = "Custom swipe color",
    order = 75,
    get = function()
      return IconSettings:GetField(entry, "swipe", "color") ~= nil
    end,
    set = function(_, enabled)
      local color
      if enabled then
        local _, viewerSwipe = GetViewerSwipeDB(GetPCMRoot(), viewerKey)
        local r, g, b, a = _PCM_GetColorComponents(viewerSwipe.swipeColor)
        color = { r, g, b, a }
      end
      IconSettings:SetField(entry, "swipe", "color", color)
      Refresh()
    end,
  }

  args.swipeColor = {
    type = "color",
    name = "Swipe color",
    order = 76,
    hasAlpha = true,
    disabled = function()
      return IconSettings:GetField(entry, "swipe", "color") == nil
    end,
    get = function()
      local _, viewerSwipe = GetViewerSwipeDB(GetPCMRoot(), viewerKey)
      return _PCM_GetColorComponents(
        IconSettings:GetField(entry, "swipe", "color") or viewerSwipe.swipeColor
      )
    end,
    set = function(_, r, g, b, a)
      IconSettings:SetField(entry, "swipe", "color", { r, g, b, a or 1 })
      Refresh()
    end,
  }

  args.alphaHeader = {
    type = "header",
    name = "State opacity",
    order = 80,
  }

  args.readyAlphaOverride = {
    type = "toggle",
    name = "Custom ready opacity",
    order = 81,
    get = function()
      return IconSettings:GetField(entry, "appearance", "readyAlpha") ~= nil
    end,
    set = function(_, enabled)
      IconSettings:SetField(entry, "appearance", "readyAlpha", enabled and 1 or nil)
      Refresh()
    end,
  }

  args.readyAlpha = {
    type = "range",
    name = "Ready opacity",
    order = 82,
    min = 0,
    max = 1,
    step = 0.05,
    isPercent = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "readyAlpha") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, "appearance", "readyAlpha") or 1
    end,
    set = function(_, value)
      IconSettings:SetField(entry, "appearance", "readyAlpha", tonumber(value) or 1)
      Refresh()
    end,
  }

  args.cooldownAlphaOverride = {
    type = "toggle",
    name = "Custom cooldown opacity",
    order = 83,
    get = function()
      return IconSettings:GetField(entry, "appearance", "cooldownAlpha") ~= nil
    end,
    set = function(_, enabled)
      IconSettings:SetField(entry, "appearance", "cooldownAlpha", enabled and 1 or nil)
      Refresh()
    end,
  }

  args.cooldownAlpha = {
    type = "range",
    name = entry.hasCharges and "Recharging opacity" or "On cooldown opacity",
    desc = "Set this to 0% to hide the icon while it is cooling down or recharging.",
    order = 84,
    min = 0,
    max = 1,
    step = 0.05,
    isPercent = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "cooldownAlpha") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, "appearance", "cooldownAlpha") or 1
    end,
    set = function(_, value)
      IconSettings:SetField(entry, "appearance", "cooldownAlpha", tonumber(value) or 1)
      Refresh()
    end,
  }

  args.swipeGCD = {
    type = "select",
    name = "GCD swipe",
    order = 85,
    values = {
      [ICON_INHERIT] = "Use viewer setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "swipe", "showGCD"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "swipe", "showGCD", value, "SHOW")
      Refresh()
    end,
  }

  args.rechargeEdge = {
    type = "select",
    name = "Recharge edge",
    order = 86,
    hidden = function()
      return entry.hasCharges ~= true
    end,
    values = {
      [ICON_INHERIT] = "Use swipe setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "swipe", "rechargeEdge"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "swipe", "rechargeEdge", value, "SHOW")
      Refresh()
    end,
  }

  args.rechargeCountdown = {
    type = "select",
    name = "Recharge countdown",
    order = 87,
    hidden = function()
      return entry.hasCharges ~= true
    end,
    values = {
      [ICON_INHERIT] = "Use cooldown text setting",
      SHOW = "Show",
      HIDE = "Hide",
    },
    get = function()
      return _PCM_GetIconTriState(
        IconSettings:GetField(entry, "cooldown", "rechargeShow"),
        "SHOW",
        "HIDE"
      )
    end,
    set = function(_, value)
      _PCM_SetIconTriState(entry, "cooldown", "rechargeShow", value, "SHOW")
      Refresh()
    end,
  }

  args.stateHeader = {
    type = "header",
    name = "State appearance",
    order = 90,
  }

  args.readySaturationOverride = {
    type = "toggle",
    name = entry.hasCharges and "Custom maximum-charges saturation" or "Custom ready saturation",
    order = 91,
    get = function()
      return IconSettings:GetField(entry, "appearance", "readySaturation") ~= nil
    end,
    set = function(_, enabled)
      IconSettings:SetField(entry, "appearance", "readySaturation", enabled and 1 or nil)
      Refresh()
    end,
  }

  args.readySaturation = {
    type = "range",
    name = entry.hasCharges and "Maximum charges saturation" or "Ready saturation",
    order = 92,
    min = 0,
    max = 1,
    step = 0.05,
    isPercent = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "readySaturation") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, "appearance", "readySaturation") or 1
    end,
    set = function(_, value)
      IconSettings:SetField(entry, "appearance", "readySaturation", tonumber(value) or 1)
      Refresh()
    end,
  }

  args.cooldownSaturationOverride = {
    type = "toggle",
    name = entry.hasCharges and "Custom recharging saturation" or "Custom cooldown saturation",
    order = 93,
    get = function()
      return IconSettings:GetField(entry, "appearance", "cooldownSaturation") ~= nil
    end,
    set = function(_, enabled)
      IconSettings:SetField(entry, "appearance", "cooldownSaturation", enabled and 1 or nil)
      Refresh()
    end,
  }

  args.cooldownSaturation = {
    type = "range",
    name = entry.hasCharges and "Recharging saturation" or "On cooldown saturation",
    order = 94,
    min = 0,
    max = 1,
    step = 0.05,
    isPercent = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "cooldownSaturation") == nil
    end,
    get = function()
      return IconSettings:GetField(entry, "appearance", "cooldownSaturation") or 1
    end,
    set = function(_, value)
      IconSettings:SetField(entry, "appearance", "cooldownSaturation", tonumber(value) or 1)
      Refresh()
    end,
  }

  local glowStyles = {
    NONE = "None",
    PIXEL = "Pixel",
    AUTOCAST = "Autocast",
    PROC = "Proc",
  }

  args.readyGlowStyle = {
    type = "select",
    name = entry.hasCharges and "Maximum charges glow" or "Ready glow",
    order = 95,
    values = glowStyles,
    get = function()
      return IconSettings:GetField(entry, "appearance", "readyGlowStyle") or "NONE"
    end,
    set = function(_, value)
      IconSettings:SetField(
        entry,
        "appearance",
        "readyGlowStyle",
        value == "NONE" and nil or value
      )
      Refresh()
    end,
  }

  args.readyGlowColor = {
    type = "color",
    name = entry.hasCharges and "Maximum charges glow color" or "Ready glow color",
    order = 96,
    hasAlpha = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "readyGlowStyle") == nil
    end,
    get = function()
      return _PCM_GetColorComponents(
        IconSettings:GetField(entry, "appearance", "readyGlowColor") or { 1, 1, 1, 1 }
      )
    end,
    set = function(_, r, g, b, a)
      IconSettings:SetField(entry, "appearance", "readyGlowColor", { r, g, b, a or 1 })
      Refresh()
    end,
  }

  args.cooldownGlowStyle = {
    type = "select",
    name = entry.hasCharges and "Recharging glow" or "Cooldown glow",
    order = 97,
    values = glowStyles,
    get = function()
      return IconSettings:GetField(entry, "appearance", "cooldownGlowStyle") or "NONE"
    end,
    set = function(_, value)
      IconSettings:SetField(
        entry,
        "appearance",
        "cooldownGlowStyle",
        value == "NONE" and nil or value
      )
      Refresh()
    end,
  }

  args.cooldownGlowColor = {
    type = "color",
    name = entry.hasCharges and "Recharging glow color" or "Cooldown glow color",
    order = 98,
    hasAlpha = true,
    disabled = function()
      return IconSettings:GetField(entry, "appearance", "cooldownGlowStyle") == nil
    end,
    get = function()
      return _PCM_GetColorComponents(
        IconSettings:GetField(entry, "appearance", "cooldownGlowColor") or { 1, 1, 1, 1 }
      )
    end,
    set = function(_, r, g, b, a)
      IconSettings:SetField(entry, "appearance", "cooldownGlowColor", { r, g, b, a or 1 })
      Refresh()
    end,
  }

  args.customTexture = {
    type = "input",
    name = "Custom texture",
    desc = "Leave empty to use the spell icon. Enter a texture path or file ID.",
    order = 99,
    get = function()
      local value = IconSettings:GetField(entry, "appearance", "texture")
      return value == nil and "" or tostring(value)
    end,
    set = function(_, value)
      value = type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
      local texture
      if value ~= "" then
        texture = tonumber(value) or value
      end
      IconSettings:SetField(entry, "appearance", "texture", texture)
      Refresh()
    end,
  }

  args.resetIcon = {
    type = "execute",
    name = "Reset icon settings",
    order = 110,
    func = function()
      IconSettings:ResetEntry(entry)
      Refresh()
    end,
  }

  return args
end

_PCM_BuildIconOverrideTreeArgs = function(viewerKey)
  local args = {}
  local entries = IconSettings:GetViewerEntries(viewerKey)

  for index = 1, #entries do
    local entry = entries[index]
    local optionKey = IconSettings:GetOptionKey(entry)
    if optionKey then
      args[optionKey] = {
        type = "group",
        name = "|T" .. tostring(entry.texture or 134400) .. ":16:16:0:0|t " .. entry.name,
        order = index,
        args = _PCM_BuildIconOverrideArgs(viewerKey, entry),
      }
    end
  end

  if #entries == 0 then
    args.__empty = {
      type = "description",
      name = InCombatLockdown()
        and "Per-icon overrides become available after combat."
        or "Add a spell to this Cooldown Manager viewer to configure its overrides.",
      order = 1,
    }
  end

  return args
end

local function _PCM_BuildCooldownViewerTreeArgs(cm, viewerKey, viewerLabel, opts, extraGroups)
  local args = {}
  local baseArgs = _PCM_BuildCooldownViewerArgs(cm, viewerKey, opts or {})
  local order = 10

  local function CollectArgs(argKeys)
    local groupArgs = {}

    for _, argKey in ipairs(argKeys) do
      if baseArgs[argKey] then
        groupArgs[argKey] = baseArgs[argKey]
      end
    end

    return groupArgs
  end

  local function AddGroup(key, label, argKeys)
    local groupArgs = CollectArgs(argKeys)

    if next(groupArgs) ~= nil then
      args[key] = {
        type = "group",
        name = label,
        order = order,
        args = groupArgs,
      }
      order = order + 10
    end
  end

  AddGroup("general", "General", {
    "showTooltips",
  })

  AddGroup("layout", "Layout", {
    "widthMode",
    "iconSize",
    "fixedWidth",
    "iconSpacing",
    "iconsPerRow",
    "growUp",
    "borderThickness",
    "borderColor",
  })

  AddGroup("swipe", "Cooldown swipe", {
    "swipeGCD",
    "swipeCooldown",
    "swipeDuration",
    "forceCooldown",
    "swipeColor",
    "swipeEdge",
  })

  local textArgs = {
    cooldownFont = {
      type = "group",
      name = "Cooldown text",
      order = 10,
      inline = true,
      args = CollectArgs({
        "countCooldown",
        "countDuration",
        "cooldownFontSize",
        "cooldownFont",
        "cooldownOutline",
        "cooldownOffsetX",
        "cooldownOffsetY",
        "cooldownColor",
      }),
    },
    keybindFont = {
      type = "group",
      name = "Keybind text",
      order = 20,
      inline = true,
      args = CollectArgs({
        "keybindToggle",
        "keybindFontSize",
        "keybindFont",
        "keybindOutline",
        "keybindOffsetX",
        "keybindOffsetY",
        "keybindColor",
      }),
    },
    chargeFont = {
      type = "group",
      name = "Charge text",
      order = 30,
      inline = true,
      args = CollectArgs({
        "countCharge",
        "countBuff",
        "chargeFontSize",
        "chargeFont",
        "chargeOutline",
        "chargeOffsetX",
        "chargeOffsetY",
        "chargeColor",
      }),
    },
  }

  args.textsFonts = {
    type = "group",
    name = "Texts and fonts",
    order = order,
    args = textArgs,
  }
  order = order + 10

  if type(extraGroups) == "table" then
    for _, extra in ipairs(extraGroups) do
      if type(extra) == "table" and extra.key and extra.name and type(extra.args) == "table" and next(extra.args) ~= nil then
        args[extra.key] = {
          type = "group",
          name = extra.name,
          order = order,
          args = extra.args,
        }
        order = order + 10
      end
    end
  end

  args.iconOverrides = {
    type = "group",
    name = "Icon overrides",
    order = 1000,
    childGroups = "tree",
    args = _PCM_BuildIconOverrideTreeArgs(viewerKey),
  }

  return args
end

local function _PCM_BuildEssentialTabArgs()
  local cm = GetPCMRoot()

  if not cm then
    return {
      __missing = {
        type = "description",
        name = "Cooldown Manager settings are unavailable.",
        order = 1,
      },
    }
  end

  local viewerKey = "EssentialCooldownViewer"
  local args = _PCM_BuildCooldownViewerTreeArgs(cm, viewerKey, "Essential", {
    effectsKey = "essential",
    fontLabelPrefix = "Essential",
    splitFonts = true,
    showIconBorder = true,
  }, {
    {
      key = "glow",
      name = "Glow",
      args = _PCM_BuildEssentialGlowArgs(cm),
    },
  })

  args.general.args.enabled = {
    type = "toggle",
    name = "Enable Cooldown Manager",
    order = 1,
    disabled = function()
      return _G.InCombatLockdown()
    end,
    get = function()
      return cm.enabled ~= false
    end,
    set = function(_, v)
      if Cooldowns:SetModuleEnabled(v == true) then
        ns.PCMHooks.RefreshRuntimeState()
        LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
      end
    end,
  }

  args.general.args.reloadNote = {
    type = "description",
    name = "Changes apply immediately.",
    order = 2,
  }

  return args
end

local function _PCM_BuildBuffBarsTabArgs()
  local args = {}
  local viewerKey = "BuffBarCooldownViewer"

  args.help = {
    type = "description",
    name = "Buff bar (tracked buffs)",
    order = 1,

  }

  args.showTooltips = {
    type = "toggle",
    name = "Show tooltips",
    desc = "Saved in Blizzard Edit Mode for this character.",
    order = 8,
    disabled = function()
      return not Cooldowns:CanChangeViewerEditModeSettings()
    end,
    get = function()
      return Cooldowns:GetViewerTooltipsEnabled(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetViewerTooltipsEnabled(viewerKey, enabled == true)
    end,
  }

  args.hideWhenInactive = {
    type = "toggle",
    name = "Hide when inactive",
    desc = "Saved in Blizzard Edit Mode for this character.",
    order = 9,
    disabled = function()
      return not Cooldowns:CanChangeViewerEditModeSettings()
    end,
    get = function()
      return Cooldowns:GetViewerHideWhenInactive(viewerKey)
    end,
    set = function(_, enabled)
      Cooldowns:SetViewerHideWhenInactive(viewerKey, enabled == true)
    end,
  }

  args.orientation = {
    type = "select",
    name = "Orientation",
    order = 9,
    values = {
      HORIZONTAL = "Horizontal",
      VERTICAL = "Vertical",
    },
    sorting = { "HORIZONTAL", "VERTICAL" },
    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      return bb and bb.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
    end,
    set = function(_, value)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      style.buffBar.orientation = value == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
      ns.PCM_DBExports.GetStyleDB()
      ns.Modules.PCM_BuffBars:RefreshSettings()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
    end,
  }

  args.iconPlacement = {
    type = "select",
    name = "Icon",
    order = 10,
    values = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return {
          TOP = "Show on top",
          BOTTOM = "Show on bottom",
          HIDE = "Hide",
        }
      end
      return {
        LEFT = "Show on left",
        RIGHT = "Show on right",
        HIDE = "Hide",
      }
    end,
    sorting = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return { "TOP", "BOTTOM", "HIDE" }
      end
      return { "LEFT", "RIGHT", "HIDE" }
    end,
    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if not bb then
        return "LEFT"
      end
      return bb.iconPlacement
    end,
    set = function(_, value)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      if bb.orientation == "VERTICAL" then
        bb.iconPlacement = value == "BOTTOM" and "BOTTOM" or value == "HIDE" and "HIDE" or "TOP"
      else
        bb.iconPlacement = value == "RIGHT" and "RIGHT" or value == "HIDE" and "HIDE" or "LEFT"
      end
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.drainDirection = {
    type = "select",
    name = "Drain direction",
    order = 10,
    values = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return {
          BOTTOM_TO_TOP = "Bottom to top",
          TOP_TO_BOTTOM = "Top to bottom",
        }
      end
      return {
        RIGHT_TO_LEFT = "Right to left",
        LEFT_TO_RIGHT = "Left to right",
      }
    end,
    sorting = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return { "BOTTOM_TO_TOP", "TOP_TO_BOTTOM" }
      end
      return { "RIGHT_TO_LEFT", "LEFT_TO_RIGHT" }
    end,
    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if not bb then
        return "RIGHT_TO_LEFT"
      end
      return bb.drainDirection
    end,
    set = function(_, value)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      if bb.orientation == "VERTICAL" then
        bb.drainDirection = value == "TOP_TO_BOTTOM" and "TOP_TO_BOTTOM" or "BOTTOM_TO_TOP"
      else
        bb.drainDirection = value == "LEFT_TO_RIGHT" and "LEFT_TO_RIGHT" or "RIGHT_TO_LEFT"
      end
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.growthDirection = {
    type = "select",
    name = "Growth direction",
    desc = "Choose where additional bars are added.",
    order = 11,
    values = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return {
          RIGHT = "Right",
          LEFT = "Left",
        }
      end
      return {
        DOWN = "Down",
        UP = "Up",
      }
    end,
    sorting = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if bb and bb.orientation == "VERTICAL" then
        return { "RIGHT", "LEFT" }
      end
      return { "DOWN", "UP" }
    end,
    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      if not bb then
        return "DOWN"
      end
      return bb.growthDirection
    end,
    set = function(_, value)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      if bb.orientation == "VERTICAL" then
        bb.growthDirection = value == "LEFT" and "LEFT" or "RIGHT"
      else
        bb.growthDirection = value == "UP" and "UP" or "DOWN"
      end
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.height = {
    type = "range",
    name = "Bar thickness",
    order = 13,
    min = 8,
    max = 40,
    step = 1,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      local h = bb and bb.height or 12
      h = tonumber(h) or 12
      if h < 8 then h = 8 end
      if h > 40 then h = 40 end
      return h
    end,
    set = function(_, v)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      bb.height = tonumber(v) or 12
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.width = {
    type = "range",
    name = "Bar length",
    order = 12,
    min = 120,
    max = 400,
    step = 4,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      local w = bb and bb.width or 200
      w = tonumber(w) or 200
      if w < 120 then w = 120 end
      if w > 400 then w = 400 end
      return w
    end,
    set = function(_, v)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      bb.width = tonumber(v) or 200
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.borderThickness = {
    type = "range",
    name = "Border size",
    order = 13,
    min = 0,
    max = 6,
    step = 1,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      local t = bb and bb.borderThickness
      if t == nil then t = 2 end
      t = tonumber(t) or 2
      if t < 0 then t = 0 end
      if t > 6 then t = 6 end
      return t
    end,
    set = function(_, v)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      v = tonumber(v) or 2
      if v < 0 then v = 0 end
      if v > 6 then v = 6 end
      bb.borderThickness = v
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.borderColor = {
    type = "color",
    name = "Border color",
    order = 14,
    hasAlpha = true,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      local c = (bb and bb.borderColor) or { 1, 1, 1, 1 }
      local r = c.r or c[1] or 1
      local g = c.g or c[2] or 1
      local b = c.b or c[3] or 1
      local a = c.a or c[4] or 1
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      bb.borderColor = { r = r, g = g, b = b, a = a }
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.rowSpacing = {
    type = "range",
    name = "Bar spacing",
    order = 14,
    min = 0,
    max = 40,
    step = 1,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      local s = bb and bb.rowSpacing
      if s == nil then s = 4 end
      s = tonumber(s) or 4
      if s < 0 then s = 0 end
      if s > 40 then s = 40 end
      return s
    end,
    set = function(_, v)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      v = tonumber(v) or 4
      if v < 0 then v = 0 end
      if v > 40 then v = 40 end
      bb.rowSpacing = v
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.texture = {
    type = "select",
    name = "Bar texture",
    order = 16,

    values = function()
      return OptionsUtil.BuildStatusbarValues(false)
    end,
    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local bb = style and style.buffBar or nil
      return (bb and bb.texture) or "Pleebar"
    end,
    set = function(_, key)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      local bb = style.buffBar
      if key and OptionsUtil.BuildStatusbarValues(false)[key] then
        bb.texture = key
        ns.Modules.PCM_BuffBars:RefreshSettings()
      end
    end,
  }

  args.useClassColor = {
    type = "toggle",
    name = "Use class color",
    order = 17,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      return style and style.buffBarUseClassColor ~= false or false
    end,
    set = function(_, v)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      style.buffBarUseClassColor = v and true or false
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.buffBarColor = {
    type = "color",
    name = "Bar color",
    order = 18,
    hasAlpha = true,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local c = (style and style.buffBarColor) or { 1, 0.6, 0, 1 }
      local r = c.r or c[1] or 1
      local g = c.g or c[2] or 0.6
      local b = c.b or c[3] or 0
      local a = c.a or c[4] or 1
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      style.buffBarColor = { r = r, g = g, b = b, a = a }
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  args.buffBarBgColor = {
    type = "color",
    name = "Background color",
    order = 19,
    hasAlpha = true,

    get = function()
      local cm, style = _PCM_GetMainBuffBarsRoot()
      local c = (style and style.buffBarBgColor) or { 0, 0, 0, 0.5 }
      local r = c.r or c[1] or 0
      local g = c.g or c[2] or 0
      local b = c.b or c[3] or 0
      local a = c.a or c[4] or 0.5
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local cm, style = _PCM_GetMainBuffBarsRoot()
      if not style then return end
      style.buffBarBgColor = { r = r, g = g, b = b, a = a }
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end,
  }

  return {
    general = {
      type = "group",
      name = "General",
      order = 10,
      inline = true,
      args = {
        showTooltips = args.showTooltips,
        hideWhenInactive = args.hideWhenInactive,
        iconPlacement = args.iconPlacement,
        useClassColor = args.useClassColor,
      },
    },
    layout = {
      type = "group",
      name = "Layout",
      order = 20,
      inline = true,
      args = {
        orientation = args.orientation,
        drainDirection = args.drainDirection,
        growthDirection = args.growthDirection,
        width = args.width,
        height = args.height,
        rowSpacing = args.rowSpacing,
      },
    },
    appearance = {
      type = "group",
      name = "Appearance",
      order = 30,
      inline = true,
      args = {
        texture = args.texture,
        buffBarColor = args.buffBarColor,
        buffBarBgColor = args.buffBarBgColor,
        borderThickness = args.borderThickness,
        borderColor = args.borderColor,
      },
    },
  }
end

local function _PCM_GetNextCustomBarID(root)
  local nextId = 1
  for id in pairs(root) do
    if type(id) == "number" and id >= nextId then
      nextId = id + 1
    end
  end
  return nextId
end

local function _PCM_MakeUniqueCustomBarLabel(root, base)
  local used = {}
  for id, entry in pairs(root) do
    if type(id) == "number" and type(entry) == "table" then
      local label = entry.label
      if type(label) == "string" and label ~= "" then
        used[label] = true
      end
    end
  end

  if not used[base] then
    return base
  end

  local suffix = 2
  while used[base .. " " .. suffix] do
    suffix = suffix + 1
  end
  return base .. " " .. suffix
end

local function _PCM_GetPlayerClassColor()
  local cr, cg, cb = 1, 1, 1
  local class = select(2, UnitClass("player"))
  local color = C_ClassColor.GetClassColor(class)
  if color then
    cr = tonumber(color.r) or cr
    cg = tonumber(color.g) or cg
    cb = tonumber(color.b) or cb
  end
  return cr, cg, cb
end

local function _PCM_CreateNewSpellBar(draft)
  local CM = Cooldowns
  local root = CM:GetSpellBarsDB()
  local nextId = _PCM_GetNextCustomBarID(root)
  local cr, cg, cb = _PCM_GetPlayerClassColor()
  draft = draft or {}

  local cfg = CM.NormalizeSpellBarEntry({
    id = nextId,
    label = _PCM_MakeUniqueCustomBarLabel(
      root,
      (draft.presentation == "BUTTON" and "Cooldown Button " or "Cooldown Bar ") .. nextId
    ),
    enabled = true,
    presentation = draft.presentation == "BUTTON" and "BUTTON" or "BAR",
    icon = draft.presentation == "BUTTON" and draft.icon or nil,
    specAssignments = {
      [CM:GetCurrentSpecializationID()] = { enabled = true },
    },
    mode = "cooldown",
    direction = "fill",
    width = tonumber(draft.width) or 250,
    height = tonumber(draft.height) or 25,
    texture = "Pleebar",
    showIcon = draft.showBarIcon ~= false,
    useClassColor = true,
    barColor = { cr, cg, cb, 1 },
    fontSize = 14,
  }, nextId)

  root[nextId] = cfg

  CM:Enable()
  CM:SpellBars_Rebuild()

  return nextId, cfg
end

local function _PCM_CreateNewChargeCooldownBar(draft)
  local CM = Cooldowns
  local root = CM:GetCooldownStackBarsDB()
  local nextId = _PCM_GetNextCustomBarID(root)
  local cr, cg, cb = _PCM_GetPlayerClassColor()
  draft = draft or {}

  local cfg = CM.NormalizeCooldownStackBarEntry({
    id = nextId,
    label = _PCM_MakeUniqueCustomBarLabel(
      root,
      (draft.presentation == "BUTTON" and "Charge Button " or "Charge Bar ") .. nextId
    ),
    enabled = true,
    presentation = draft.presentation == "BUTTON" and "BUTTON" or "BAR",
    icon = draft.presentation == "BUTTON" and draft.icon or nil,
    specAssignments = {
      [CM:GetCurrentSpecializationID()] = { enabled = true },
    },
    width = tonumber(draft.width) or 250,
    height = tonumber(draft.height) or 25,
    texture = "Pleebar",
    showIcon = draft.showBarIcon ~= false,
    useClassColor = true,
    barColor = { cr, cg, cb, 1 },
    font = "PleebUI",
    showSlotBorder = true,
    slotBorderThickness = 2,
    slotBorderColor = { 0.20, 0.20, 0.24, 1.00 },
  }, nextId)

  root[nextId] = cfg

  CM:Enable()
  CM:CooldownStackBars_Rebuild()

  return nextId, cfg
end

local function _PCM_GetCustomBarsRootLists()
  local API = ns.Modules.PCM_BB
  return Cooldowns, API, Cooldowns:GetSpellBarsDB(), Cooldowns:GetCooldownStackBarsDB(), API.GetStackBarsDB()
end

local function _PCM_GetCustomBarNodeLabel(kind, id, cfg)
  local label = Cooldowns:GetCustomBarDisplayName(cfg)
  local previewKind
  if cfg and cfg.presentation == "BUTTON" then
    previewKind = "ICON"
  elseif kind == "chargeSpell" then
    previewKind = "CHARGE"
  elseif cfg and cfg.kind == "stack" then
    previewKind = "STACK"
  else
    previewKind = "DURATION"
  end

  Cooldowns:NormalizeSpecAssignments(cfg)

  local assignment = Cooldowns:GetCurrentSpecAssignment(cfg)
  if not (assignment and assignment.spellID) then
    local assignments = cfg.specAssignments

    for specIndex = 1, GetNumSpecializations() do
      local specID = GetSpecializationInfo(specIndex)
      local candidate = assignments[specID]
      if candidate and candidate.spellID then
        assignment = candidate
        break
      end
    end
  end

  local spellID = assignment and tonumber(assignment.spellID) or nil
  local icon = spellID and (C_Spell.GetSpellTexture(spellID) or assignment.spellIcon) or nil
  icon = icon or 134400
  if assignment and spellID then
    assignment.spellIcon = icon
  end

  return string.format(
    "|T%s:16:16:0:0|t |c00000000PUI_PCM_TRACKER:%s|r %s",
    tostring(icon),
    previewKind,
    tostring(label)
  )
end

local _PCM_RefreshCustomBarsOptionsTree
local _PCM_BuildCustomBarsTreeNodes

local function _PCM_GetCustomBarsTargetPath(targetKey)
  if type(targetKey) == "string" and targetKey ~= "" then
    local nodes = _PCM_BuildCustomBarsTreeNodes()
    if type(nodes) == "table" then
      if type(nodes[targetKey]) == "table" then
        return { "CooldownManager", "custom_bars", targetKey }
      end

      local unavailable = nodes.__disabledNotLoaded
      local unavailableArgs = unavailable and unavailable.args
      if type(unavailableArgs) == "table" and type(unavailableArgs[targetKey]) == "table" then
        return { "CooldownManager", "custom_bars", "__disabledNotLoaded", targetKey }
      end
    end
  end

  return { "CooldownManager", "custom_bars" }
end

local _PCMValueCache = {}

local function _PCM_ACD_NotifyPCM(targetKey)
  wipe(_PCMValueCache)

  local targetPath = _PCM_GetCustomBarsTargetPath(targetKey)
  Addon:NotifyOptionsTreeChanged("CooldownManager", targetPath)
end

local function _PCM_GetSpellBarById(id)
  local CM = Cooldowns
  local root = CM:GetSpellBarsDB()

  local cfg = root[id]
  if cfg == nil and tonumber(id) ~= nil then
    id = tonumber(id)
    cfg = root[id]
  end

  if cfg then
    cfg = CM.NormalizeSpellBarEntry(cfg, id)
    root[id] = cfg
  end

  return CM, root, cfg
end

local function _PCM_GetSpecializations()
  local specs = {}

  for specIndex = 1, GetNumSpecializations() do
    local specID, name, _, icon = GetSpecializationInfo(specIndex)
    specs[#specs + 1] = {
      index = specIndex,
      id = specID,
      name = name,
      icon = icon,
    }
  end

  return specs
end

local function _PCM_GetSpecAssignment(cfg, specID)
  local assignments = cfg and cfg.specAssignments
  return type(assignments) == "table" and assignments[specID] or nil
end

local function _PCM_SaveTrackedSpellIdentity(cfg, specID, spellID)
  Cooldowns:NormalizeSpecAssignments(cfg)

  local assignments = cfg.specAssignments
  local assignment = assignments[specID]

  if not assignment then
    assignment = { enabled = true }
    assignments[specID] = assignment
  end

  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 then
    assignment.spellID = nil
    assignment.spellName = nil
    assignment.spellIcon = nil
  else
    assignment.spellID = spellID
    assignment.spellName = C_Spell.GetSpellName(spellID)
    assignment.spellIcon = C_Spell.GetSpellTexture(spellID)
  end

  Cooldowns:NormalizeSpecAssignments(cfg)
end

function ns.PCM_ApplyInstallerDraft(cfg, draft)
  local icon = draft.icon
  icon.readyAlpha = draft.showReady and draft.readyAlpha or 0
  icon.onCooldownAlpha = draft.showCooldown and draft.cooldownAlpha or 0
  icon.desaturateReady = draft.desaturateReady == true
  icon.desaturateCooldown = draft.desaturateCooldown == true
  icon.readyGlowStyle = draft.readyGlowStyle
  icon.cooldownGlowStyle = draft.cooldownGlowStyle
  icon.activeAuraEnabled = (draft.kind == "cooldown" or draft.kind == "charge")
    and draft.showActive == true
  icon.activeAuraAlpha = draft.activeAlpha
  icon.activeAuraDesaturate = draft.desaturateActive == true
  icon.activeAuraGlowStyle = draft.customGlowEnabled == true
    and draft.activeGlowStyle or "NONE"
  icon.combatOnly = draft.combatOnly == true
  icon.visibility = (draft.kind == "duration" or draft.kind == "stack")
    and draft.showOnlyWhenActive == true and "ACTIVE" or "ALWAYS"
  icon.showCount = (draft.kind == "charge" or draft.kind == "stack")
    and icon.showCount ~= false
  icon.showStackStrip = draft.kind == "stack" and draft.addColorShift == true

  cfg.presentation = draft.presentation == "BUTTON" and "BUTTON" or "BAR"
  cfg.hideOutOfCombat = draft.combatOnly == true
  cfg.outOfCombatAlpha = 0
  cfg.showOnlyWhenActive = draft.showOnlyWhenActive == true
  cfg.readyAlpha = draft.showReady and draft.readyAlpha or 0
  cfg.onCooldownAlpha = draft.showCooldown and draft.cooldownAlpha or 0
  cfg.activeAlpha = draft.showActive and draft.activeAlpha or 0
  cfg.desaturateReady = draft.desaturateReady == true
  cfg.desaturateCooldown = draft.desaturateCooldown == true
  cfg.desaturateActive = draft.desaturateActive == true
  cfg.activeAuraEnabled = draft.showActive == true
  cfg.readyGlowStyle = draft.readyGlowStyle
  cfg.cooldownGlowStyle = draft.cooldownGlowStyle
  cfg.activeGlowStyle = draft.customGlowEnabled == true
    and draft.activeGlowStyle or "NONE"
  cfg.activeGlowColor = draft.icon.activeAuraGlowColor
  cfg.buffGlowColor = draft.icon.activeAuraGlowColor
  cfg.buffGlowEnabled = draft.customGlowEnabled == true
    and draft.showActive == true
    and draft.activeGlowStyle ~= nil and draft.activeGlowStyle ~= "NONE"
  cfg.buffGlowThickness = tonumber(draft.customGlowThickness) or cfg.buffGlowThickness
  cfg.buffGlowHideViewerIcon = draft.activeAuraHideViewerIcon == true

  if draft.kind == "cooldown" or draft.kind == "charge" then
    cfg.buffGlowSource = draft.activeAuraSource == "CUSTOM" and "CUSTOM" or "CDM"
    cfg.buffGlowSpellID = tonumber(draft.activeAuraSpellID)
  else
    cfg.buffGlowSource = "CDM"
    cfg.buffGlowSpellID = tonumber(draft.spellID)
  end

  if draft.kind == "duration" or draft.kind == "stack" then
    cfg.auraTrackMode = draft.auraTrackMode == "target_debuff"
      and "target_debuff" or "player_buff"
    cfg.hideViewerIcon = draft.kind == "stack" and draft.hideViewerIcon == true
    cfg.maxStacks = draft.kind == "stack" and (tonumber(draft.maximum) or 3) or 1
    if draft.kind == "stack" and draft.addColorShift == true then
      AuraWidget.AddStackColorThreshold(cfg, cfg.maxStacks)
    end
  end

  if cfg.presentation == "BUTTON" then
    cfg.icon = draft.icon
  else
    cfg.icon = nil
    cfg.width = tonumber(draft.width) or cfg.width
    cfg.height = tonumber(draft.height) or cfg.height
    cfg.orientation = draft.orientation == "vertical" and "vertical" or "horizontal"
    cfg.fillDirection = draft.fillDirection
    cfg.showText = draft.showText ~= false

    if draft.kind == "cooldown" then
      cfg.direction = draft.barMode == "drain" and "drain" or "fill"
      cfg.texture = draft.texture
      cfg.showIcon = draft.showBarIcon ~= false
    elseif draft.kind == "charge" then
      cfg.durationBarFillMode = draft.barMode == "drain" and "drain" or "fill"
      cfg.texture = draft.texture
      cfg.showIcon = draft.showBarIcon ~= false
    elseif draft.kind == "duration" then
      cfg.durationBarFillMode = draft.barMode == "drain" and "drain" or "fill"
      cfg.durationTexture = draft.texture
      cfg.durationHideIconFrame = draft.showBarIcon ~= true
    else
      cfg.durationBarFillMode = draft.barMode == "drain" and "drain" or "fill"
      cfg.stackTexture = draft.texture
      cfg.showSpellIconNextToBar = draft.showBarIcon ~= false
    end
  end

  local spellID = tonumber(draft.spellID)
  if spellID and spellID > 0 then
    _PCM_SaveTrackedSpellIdentity(cfg, Cooldowns:GetCurrentSpecializationID(), spellID)
  end
end

function ns.PCM_CreateCustomTrackerFromDraft(draft)
  local kind = draft and draft.kind
  if kind == "cooldown" then
    local id, cfg = _PCM_CreateNewSpellBar(draft)
    ns.PCM_ApplyInstallerDraft(cfg, draft)
    Cooldowns.NormalizeSpellBarEntry(cfg, id)
    Cooldowns:SpellBars_Rebuild()
    local key = "spell:" .. tostring(id)
    _PCM_ACD_NotifyPCM(key)
    return key
  end

  if kind == "charge" then
    local id, cfg = _PCM_CreateNewChargeCooldownBar(draft)
    ns.PCM_ApplyInstallerDraft(cfg, draft)
    Cooldowns.NormalizeCooldownStackBarEntry(cfg, id)
    Cooldowns:CooldownStackBars_Rebuild()
    local key = "chargeSpell:" .. tostring(id)
    _PCM_ACD_NotifyPCM(key)
    return key
  end

  local API = ns.Modules.PCM_BB
  local id, cfg
  if kind == "duration" then
    id, cfg = API.CreateNewDurationBar()
  elseif kind == "stack" then
    id, cfg = API.CreateNewStackBar()
  end
  if not id or not cfg then
    return nil
  end

  ns.PCM_ApplyInstallerDraft(cfg, draft)
  cfg.kind = kind
  local root = API.GetStackBarsDB()
  cfg.label = _PCM_MakeUniqueCustomBarLabel(
    root,
    (kind == "duration" and "Duration " or "Stack ")
      .. (draft.presentation == "BUTTON" and "Button " or "Bar ")
      .. tostring(id)
  )
  API.EnsureStackBarDefaults(cfg, id)
  API.RebuildCustomBars()
  local key = "bb:" .. tostring(id)
  _PCM_ACD_NotifyPCM(key)
  return key
end

local function _PCM_BuildTrackedSpellDropdown(list, sorting, assignment, editable)
  local out = { ["none"] = "-- Select --" }
  local outSorting = { "none" }

  if editable then
    for key, value in pairs(list or {}) do
      if key ~= "none" then
        out[key] = value
      end
    end

    for index = 1, #(sorting or {}) do
      local key = sorting[index]
      if key ~= "none" and out[key] then
        outSorting[#outSorting + 1] = key
      end
    end
  end

  local spellID = assignment and tonumber(assignment.spellID) or nil
  if not spellID or spellID <= 0 then
    return out, outSorting
  end

  local key = tostring(spellID)
  if out[key] then
    return out, outSorting
  end

  local resolvedName = C_Spell.GetSpellName(spellID)
  local resolvedIcon = C_Spell.GetSpellTexture(spellID)
  local name = resolvedName or assignment.spellName or ("Spell " .. key)
  local icon = resolvedIcon or assignment.spellIcon

  if resolvedName then
    assignment.spellName = resolvedName
  end
  if resolvedIcon then
    assignment.spellIcon = resolvedIcon
  end

  local label = name .. " (" .. key .. ")"
  if icon then
    label = string.format("|T%s:16:16:0:0|t %s", tostring(icon), label)
  end

  out[key] = "|cff808080" .. label .. "|r"
  outSorting[#outSorting + 1] = key
  return out, outSorting
end

local function _PCM_IsSpecializationEnabled(cfg, specID)
  local assignment = _PCM_GetSpecAssignment(cfg, specID)
  return assignment and assignment.enabled ~= false or false
end

local function _PCM_SetSpecializationEnabled(cfg, specID, enabled)
  Cooldowns:NormalizeSpecAssignments(cfg)

  local assignments = cfg.specAssignments
  local assignment = assignments[specID]
  local currentlyEnabled = assignment and assignment.enabled ~= false or false

  if enabled ~= true and currentlyEnabled then
    local enabledCount = 0
    for _, spec in ipairs(_PCM_GetSpecializations()) do
      local other = assignments[spec.id]
      if other and other.enabled ~= false then
        enabledCount = enabledCount + 1
      end
    end

    if enabledCount <= 1 then
      return false
    end
  end

  if not assignment then
    assignment = {}
    assignments[specID] = assignment
  end

  assignment.enabled = enabled == true
  Cooldowns:NormalizeSpecAssignments(cfg)
  return true
end

local function _PCM_BuildSpecializationSpellGroup(GetCfg, GetSpellList, OnChanged, order)
  local specs = _PCM_GetSpecializations()
  local rows = {
    help = {
      type = "description",
      name = "Choose which specializations use this bar, then select a spell for each.",
      order = 1,
    },
    enabled = {
      type = "group",
      name = "Specializations",
      inline = true,
      order = 10,
      args = {},
    },
    spells = {
      type = "group",
      name = "Spell assignments",
      inline = true,
      order = 20,
      args = {},
    },
  }

  local function BuildEnabledOption(spec)
    local specID = spec.id
    local specName = spec.name
    local specIcon = spec.icon
    local optionName = specName

    if specIcon then
      optionName = string.format("|T%s:16:16:0:0|t %s", tostring(specIcon), specName)
    end

    if Cooldowns:GetCurrentSpecializationID() == specID then
      optionName = optionName .. " |cffffff00(Current)|r"
    end

    return {
      type = "toggle",
      name = optionName,
      order = spec.index,
      get = function()
        local _, _, cfg = GetCfg()
        return cfg and _PCM_IsSpecializationEnabled(cfg, specID) or false
      end,
      set = function(_, value)
        local _, _, cfg = GetCfg()
        if not cfg then return end

        if _PCM_SetSpecializationEnabled(cfg, specID, value) then
          OnChanged()
        end
      end,
    }
  end

  local function BuildSpellOption(spec)
    local specID = spec.id
    local specName = spec.name

    local function GetDropdownData()
      local _, _, cfg = GetCfg()
      local assignment = cfg and _PCM_GetSpecAssignment(cfg, specID) or nil
      local editable = cfg and _PCM_IsSpecializationEnabled(cfg, specID)
      local list, sorting

      if editable then
        list, sorting = GetSpellList(cfg)
      end

      return _PCM_BuildTrackedSpellDropdown(list, sorting, assignment, editable)
    end

    return {
      type = "select",
      name = "Tracked spell",
      order = spec.index,
      disabled = function()
        local _, _, cfg = GetCfg()
        return not (cfg and _PCM_IsSpecializationEnabled(cfg, specID))
      end,
      desc = function()
        local _, _, cfg = GetCfg()
        if not (cfg and _PCM_IsSpecializationEnabled(cfg, specID)) then
          return "Enable " .. specName .. " to use this specialization."
        end

        return "You can select any available Cooldown Manager spell, even if it is not currently shown there. Shown spells are listed first; spells not currently shown are grey."
      end,
      values = function()
        local values = GetDropdownData()
        return values
      end,
      sorting = function()
        local _, sorting = GetDropdownData()
        return sorting
      end,
      get = function()
        local _, _, cfg = GetCfg()
        local assignment = cfg and _PCM_GetSpecAssignment(cfg, specID) or nil
        return assignment and assignment.spellID and tostring(assignment.spellID) or "none"
      end,
      set = function(_, key)
        local _, _, cfg = GetCfg()
        if not cfg then return end

        local spellID = nil
        key = tostring(key or "none")
        if key ~= "none" then
          spellID = tonumber(key)
        end

        _PCM_SaveTrackedSpellIdentity(cfg, specID, spellID)
        OnChanged()
      end,
    }
  end

  for _, spec in ipairs(specs) do
    rows.enabled.args["spec_" .. tostring(spec.id)] = BuildEnabledOption(spec)
    rows.spells.args["spec_" .. tostring(spec.id)] = BuildSpellOption(spec)
  end

  return {
    type = "group",
    name = "Spell picker",
    order = order,
    inline = true,
    args = rows,
  }
end

local function _PCM_GetCustomBarSpellList(kind)
  local cache = _PCMValueCache
  cache.customBarSpellLists = cache.customBarSpellLists or {}

  local cached = cache.customBarSpellLists[kind]
  if cached then
    return cached.values, cached.sorting
  end

  local values, sorting = Cooldowns:GetCustomBarSpellDropdown(kind)
  cached = {
    values = values,
    sorting = sorting,
  }
  cache.customBarSpellLists[kind] = cached
  return values, sorting
end

local _PCM_BuildCustomBarBuffGlowGroup

local function _PCM_BuildCustomIconGroup(GetCfg, RebuildRuntime, kind, order)
  local auraKind = kind == "stack" or kind == "duration"
  local chargeKind = kind == "charge"
  local stackKind = kind == "stack"
  local textAnchors = {
    CENTER = "Center",
    TOP = "Top",
    BOTTOM = "Bottom",
    LEFT = "Left",
    RIGHT = "Right",
    TOPLEFT = "Top left",
    TOPRIGHT = "Top right",
    BOTTOMLEFT = "Bottom left",
    BOTTOMRIGHT = "Bottom right",
  }
  local glowStyles = {
    NONE = "None",
    PIXEL = "Pixel",
    AUTOCAST = "Autocast",
    PROC = "Proc",
  }

  local function GetIcon()
    local _, _, cfg = GetCfg()
    return cfg, cfg and cfg.icon
  end

  local function SetIconValue(key, value)
    local cfg, icon = GetIcon()
    if not cfg or not icon then
      return
    end
    icon[key] = value
    RebuildRuntime()
  end

  local function HiddenWhenIconOff()
    local cfg = select(1, GetIcon())
    return not (cfg and cfg.presentation == "BUTTON")
  end

  local args = {
    size = {
      type = "range",
      name = "Button size",
      order = 10,
      min = 20,
      max = 96,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.size or 40
      end,
      set = function(_, value) SetIconValue("size", math.floor(value + 0.5)) end,
    },
    visibility = {
      type = "select",
      name = "Show icon",
      order = 11,
      hidden = HiddenWhenIconOff,
      values = auraKind and {
        ALWAYS = "Always",
        ACTIVE = "While aura is active",
      } or chargeKind and {
        ALWAYS = "Always",
        ACTIVE = "While recharging",
        INACTIVE = "At full charges",
      } or {
        ALWAYS = "Always",
        ACTIVE = "While cooling down",
        INACTIVE = "While ready",
      },
      get = function()
        local _, icon = GetIcon()
        return icon and icon.visibility or "ALWAYS"
      end,
      set = function(_, value) SetIconValue("visibility", value) end,
    },
    combatOnly = {
      type = "toggle",
      name = "Only show in combat",
      order = 12,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.combatOnly == true or false
      end,
      set = function(_, value) SetIconValue("combatOnly", value == true) end,
    },
    outOfCombatAlpha = {
      type = "range",
      name = "Out-of-combat opacity",
      order = 13,
      min = 0,
      max = 100,
      step = 1,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not (icon and icon.combatOnly == true)
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.outOfCombatAlpha or 0
      end,
      set = function(_, value) SetIconValue("outOfCombatAlpha", value) end,
    },
    readyAlpha = {
      type = "range",
      name = auraKind and "Inactive alpha" or "Ready alpha",
      desc = auraKind and "Opacity while the aura is inactive. Set this to 0 to hide the configured button until the aura appears."
        or chargeKind and "Opacity while all charges are available. Set this to 0 to hide the button while charges are full."
        or "Opacity while the cooldown is ready. Set this to 0 to hide the button while ready.",
      order = 14,
      min = 0,
      max = 100,
      step = 1,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not icon or icon.visibility == "ACTIVE"
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.readyAlpha or 35
      end,
      set = function(_, value) SetIconValue("readyAlpha", value) end,
    },
    onCooldownAlpha = {
      type = "range",
      name = "On cooldown alpha",
      desc = chargeKind and "Opacity while charges are recharging. Set this to 0 to hide the icon while recharging."
        or "Opacity while the spell is cooling down. Set this to 0 to hide the icon while on cooldown.",
      order = 15,
      min = 0,
      max = 100,
      step = 1,
      hidden = function()
        local _, icon = GetIcon()
        return auraKind or HiddenWhenIconOff() or not icon or icon.visibility == "INACTIVE"
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.onCooldownAlpha or 100
      end,
      set = function(_, value) SetIconValue("onCooldownAlpha", value) end,
    },
    desaturateReady = {
      type = "toggle",
      name = auraKind and "Desaturate while inactive" or "Desaturate while ready",
      order = 16,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not icon or icon.visibility == "ACTIVE"
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.desaturateReady == true or false
      end,
      set = function(_, value) SetIconValue("desaturateReady", value == true) end,
    },
    desaturateCooldown = {
      type = "toggle",
      name = chargeKind and "Desaturate while recharging" or "Desaturate while on cooldown",
      order = 17,
      hidden = function()
        local _, icon = GetIcon()
        return auraKind or HiddenWhenIconOff() or not icon or icon.visibility == "INACTIVE"
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.desaturateCooldown == true or false
      end,
      set = function(_, value) SetIconValue("desaturateCooldown", value == true) end,
    },
    showSwipe = {
      type = "toggle",
      name = "Show cooldown swipe",
      order = 20,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showSwipe == true or false
      end,
      set = function(_, value) SetIconValue("showSwipe", value == true) end,
    },
    showDuration = {
      type = "toggle",
      name = "Show countdown",
      order = 21,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showDuration == true or false
      end,
      set = function(_, value) SetIconValue("showDuration", value == true) end,
    },
    showCount = {
      type = "toggle",
      name = chargeKind and "Show charge count" or "Show stack count",
      order = 22,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showCount == true or false
      end,
      set = function(_, value) SetIconValue("showCount", value == true) end,
    },
    showPips = {
      type = "toggle",
      name = "Show charge pips",
      order = 23,
      hidden = function() return HiddenWhenIconOff() or not chargeKind end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showPips == true or false
      end,
      set = function(_, value) SetIconValue("showPips", value == true) end,
    },
    showStackStrip = {
      type = "toggle",
      name = "Show stack strip",
      order = 24,
      hidden = function() return HiddenWhenIconOff() or not stackKind end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showStackStrip == true or false
      end,
      set = function(_, value) SetIconValue("showStackStrip", value == true) end,
    },
    showTooltip = {
      type = "toggle",
      name = "Show tooltip",
      order = 25,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.showTooltip == true or false
      end,
      set = function(_, value) SetIconValue("showTooltip", value == true) end,
    },
    activeAuraEnabled = {
      type = "toggle",
      name = "Show while aura is active",
      desc = "Show the aura icon and its duration even when the cooldown state is hidden.",
      order = 25.1,
      hidden = function() return auraKind or HiddenWhenIconOff() end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.activeAuraEnabled == true or false
      end,
      set = function(_, value) SetIconValue("activeAuraEnabled", value == true) end,
    },
    activeAuraSource = {
      type = "select",
      name = "Active aura source",
      order = 25.11,
      values = {
        CDM = "Buff from CDM",
        CUSTOM = "Custom player buff",
      },
      hidden = function()
        local cfg, icon = GetIcon()
        return auraKind or HiddenWhenIconOff() or not (icon and icon.activeAuraEnabled == true)
      end,
      get = function()
        local cfg = select(1, GetIcon())
        return cfg and cfg.buffGlowSource == "CUSTOM" and "CUSTOM" or "CDM"
      end,
      set = function(_, value)
        local cfg = select(1, GetIcon())
        if not cfg then return end
        cfg.buffGlowSource = value == "CUSTOM" and "CUSTOM" or "CDM"
        cfg.buffGlowSpellID = nil
        RebuildRuntime()
      end,
    },
    activeAuraCDM = {
      type = "select",
      name = "Buff from CDM",
      order = 25.12,
      values = function()
        local values = _PCM_GetCustomBarSpellList("aura")
        return values
      end,
      sorting = function()
        local _, sorting = _PCM_GetCustomBarSpellList("aura")
        return sorting
      end,
      hidden = function()
        local cfg, icon = GetIcon()
        return auraKind
          or HiddenWhenIconOff()
          or not (icon and icon.activeAuraEnabled == true)
          or cfg.buffGlowSource == "CUSTOM"
      end,
      get = function()
        local cfg = select(1, GetIcon())
        local spellID = cfg and tonumber(cfg.buffGlowSpellID) or nil
        return spellID and tostring(spellID) or "none"
      end,
      set = function(_, value)
        local cfg = select(1, GetIcon())
        if not cfg then return end
        cfg.buffGlowSpellID = value ~= "none" and tonumber(value) or nil
        RebuildRuntime()
      end,
    },
    activeAuraCustom = {
      type = "input",
      name = "Custom player buff",
      order = 25.12,
      hidden = function()
        local cfg, icon = GetIcon()
        return auraKind
          or HiddenWhenIconOff()
          or not (icon and icon.activeAuraEnabled == true)
          or cfg.buffGlowSource ~= "CUSTOM"
      end,
      validate = function(_, value)
        if value == nil or value == "" then return true end
        local spellID = tonumber(value)
        if spellID and spellID > 0 and spellID == math.floor(spellID) then return true end
        return "Enter a whole spell ID."
      end,
      get = function()
        local cfg = select(1, GetIcon())
        return cfg and cfg.buffGlowSpellID and tostring(cfg.buffGlowSpellID) or ""
      end,
      set = function(_, value)
        local cfg = select(1, GetIcon())
        if not cfg then return end
        local spellID = tonumber(value)
        cfg.buffGlowSpellID = spellID and math.floor(spellID) or nil
        RebuildRuntime()
      end,
    },
    activeAuraAlpha = {
      type = "range",
      name = "Active aura alpha",
      order = 25.2,
      min = 0,
      max = 100,
      step = 1,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not auraKind and not (icon and icon.activeAuraEnabled == true)
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.activeAuraAlpha or 100
      end,
      set = function(_, value) SetIconValue("activeAuraAlpha", value) end,
    },
    activeAuraDesaturate = {
      type = "toggle",
      name = "Desaturate while aura is active",
      order = 25.3,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not auraKind and not (icon and icon.activeAuraEnabled == true)
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.activeAuraDesaturate == true or false
      end,
      set = function(_, value) SetIconValue("activeAuraDesaturate", value == true) end,
    },
    activeAuraGlowStyle = {
      type = "select",
      name = "Active aura glow",
      order = 25.4,
      values = glowStyles,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff() or not auraKind and not (icon and icon.activeAuraEnabled == true)
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.activeAuraGlowStyle or "NONE"
      end,
      set = function(_, value) SetIconValue("activeAuraGlowStyle", value) end,
    },
    activeAuraHideViewerIcon = {
      type = "toggle",
      name = "Hide from buff icon viewer",
      desc = "Hide the aura used for this glow from the Buff Icon Viewer.",
      order = 25.45,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff()
          or not icon
          or icon.activeAuraGlowStyle == "NONE"
          or (not auraKind and icon.activeAuraEnabled ~= true)
      end,
      get = function()
        local cfg = select(1, GetIcon())
        return cfg and cfg.buffGlowHideViewerIcon == true or false
      end,
      set = function(_, value)
        local cfg = select(1, GetIcon())
        if not cfg then return end
        cfg.buffGlowHideViewerIcon = value == true
        RebuildRuntime()
      end,
    },
    activeAuraGlowColor = {
      type = "color",
      name = "Active aura glow color",
      order = 25.5,
      hasAlpha = true,
      hidden = function()
        local _, icon = GetIcon()
        return HiddenWhenIconOff()
          or not icon
          or (not auraKind and icon.activeAuraEnabled ~= true)
          or icon.activeAuraGlowStyle == "NONE"
      end,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.activeAuraGlowColor or { 1, 0.55, 0.1, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("activeAuraGlowColor", { r, g, b, a }) end,
    },
    cooldownGlowStyle = {
      type = "select",
      name = chargeKind and "Recharging glow" or "Cooldown glow",
      order = 26,
      hidden = function() return auraKind or HiddenWhenIconOff() end,
      values = glowStyles,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.cooldownGlowStyle or "NONE"
      end,
      set = function(_, value) SetIconValue("cooldownGlowStyle", value) end,
    },
    cooldownGlowColor = {
      type = "color",
      name = chargeKind and "Recharging glow color" or "Cooldown glow color",
      order = 27,
      hasAlpha = true,
      hidden = function()
        local _, icon = GetIcon()
        return auraKind or HiddenWhenIconOff() or not icon or icon.cooldownGlowStyle == "NONE"
      end,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.cooldownGlowColor or { 1, 0.55, 0.1, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("cooldownGlowColor", { r, g, b, a }) end,
    },
    readyGlowStyle = {
      type = "select",
      name = chargeKind and "Full-charge glow" or "Ready glow",
      order = 28,
      hidden = function() return auraKind or HiddenWhenIconOff() end,
      values = glowStyles,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.readyGlowStyle or "NONE"
      end,
      set = function(_, value) SetIconValue("readyGlowStyle", value) end,
    },
    readyGlowColor = {
      type = "color",
      name = chargeKind and "Full-charge glow color" or "Ready glow color",
      order = 29,
      hasAlpha = true,
      hidden = function()
        local _, icon = GetIcon()
        return auraKind or HiddenWhenIconOff() or not icon or icon.readyGlowStyle == "NONE"
      end,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.readyGlowColor or { 0.25, 0.75, 1, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("readyGlowColor", { r, g, b, a }) end,
    },
    chromeStyle = {
      type = "select",
      name = "Icon style",
      order = 30,
      hidden = HiddenWhenIconOff,
      values = {
        PLEEBUI = "PleebUI",
        SQUARE = "Square",
        BLIZZARD = "Blizzard",
      },
      get = function()
        local _, icon = GetIcon()
        return icon and icon.chromeStyle or "PLEEBUI"
      end,
      set = function(_, value) SetIconValue("chromeStyle", value) end,
    },
    borderSize = {
      type = "range",
      name = "Border size",
      order = 31,
      min = 0,
      max = 8,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.borderSize or 2
      end,
      set = function(_, value) SetIconValue("borderSize", math.floor(value + 0.5)) end,
    },
    borderColor = {
      type = "color",
      name = "Border color",
      order = 32,
      hasAlpha = true,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.borderColor or { 0.1, 0.1, 0.12, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("borderColor", { r, g, b, a }) end,
    },
    backgroundColor = {
      type = "color",
      name = "Background color",
      order = 33,
      hasAlpha = true,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.backgroundColor or { 0.03, 0.03, 0.04, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("backgroundColor", { r, g, b, a }) end,
    },
    fontSize = {
      type = "range",
      name = "Countdown font size",
      order = 40,
      min = 8,
      max = 28,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.fontSize or 14
      end,
      set = function(_, value) SetIconValue("fontSize", math.floor(value + 0.5)) end,
    },
    durationTextScale = {
      type = "range",
      name = "Countdown scale",
      order = 41,
      min = 50,
      max = 200,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.durationTextScale or 100
      end,
      set = function(_, value) SetIconValue("durationTextScale", math.floor(value + 0.5)) end,
    },
    durationTextAnchor = {
      type = "select",
      name = "Countdown anchor",
      order = 42,
      hidden = HiddenWhenIconOff,
      values = textAnchors,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.durationTextAnchor or "CENTER"
      end,
      set = function(_, value) SetIconValue("durationTextAnchor", value) end,
    },
    durationTextX = {
      type = "range",
      name = "Countdown X",
      order = 43,
      min = -50,
      max = 50,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.durationTextX or 0
      end,
      set = function(_, value) SetIconValue("durationTextX", math.floor(value + 0.5)) end,
    },
    durationTextY = {
      type = "range",
      name = "Countdown Y",
      order = 44,
      min = -50,
      max = 50,
      step = 1,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.durationTextY or 0
      end,
      set = function(_, value) SetIconValue("durationTextY", math.floor(value + 0.5)) end,
    },
    durationTextColor = {
      type = "color",
      name = "Countdown color",
      order = 45,
      hasAlpha = true,
      hidden = HiddenWhenIconOff,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.durationTextColor or { 1, 1, 1, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("durationTextColor", { r, g, b, a }) end,
    },
    countFontSize = {
      type = "range",
      name = "Count font size",
      order = 50,
      min = 8,
      max = 28,
      step = 1,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.countFontSize or 13
      end,
      set = function(_, value) SetIconValue("countFontSize", math.floor(value + 0.5)) end,
    },
    countTextScale = {
      type = "range",
      name = "Count scale",
      order = 51,
      min = 50,
      max = 200,
      step = 1,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.countTextScale or 100
      end,
      set = function(_, value) SetIconValue("countTextScale", math.floor(value + 0.5)) end,
    },
    countTextAnchor = {
      type = "select",
      name = "Count anchor",
      order = 52,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      values = textAnchors,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.countTextAnchor or "BOTTOMRIGHT"
      end,
      set = function(_, value) SetIconValue("countTextAnchor", value) end,
    },
    countTextX = {
      type = "range",
      name = "Count X",
      order = 53,
      min = -50,
      max = 50,
      step = 1,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.countTextX or -2
      end,
      set = function(_, value) SetIconValue("countTextX", math.floor(value + 0.5)) end,
    },
    countTextY = {
      type = "range",
      name = "Count Y",
      order = 54,
      min = -50,
      max = 50,
      step = 1,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.countTextY or 2
      end,
      set = function(_, value) SetIconValue("countTextY", math.floor(value + 0.5)) end,
    },
    countTextColor = {
      type = "color",
      name = "Count color",
      order = 55,
      hasAlpha = true,
      hidden = function() return HiddenWhenIconOff() or not (chargeKind or stackKind) end,
      get = function()
        local _, icon = GetIcon()
        local color = icon and icon.countTextColor or { 1, 1, 1, 1 }
        return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
      end,
      set = function(_, r, g, b, a) SetIconValue("countTextColor", { r, g, b, a }) end,
    },
    font = {
      type = "select",
      dialogControl = "LSM30_Font",
      name = "Font",
      order = 60,
      hidden = HiddenWhenIconOff,
      values = function()
        return OptionsUtil.BuildFontValues(false, "Use theme default", "")
      end,
      get = function()
        local _, icon = GetIcon()
        return OptionsUtil.ResolveFontKey(icon and icon.font)
      end,
      set = function(_, value) SetIconValue("font", value ~= "" and value or nil) end,
    },
    outline = {
      type = "select",
      name = "Font outline",
      order = 61,
      hidden = HiddenWhenIconOff,
      values = function()
        return OptionsUtil.BuildOutlineValues(false)
      end,
      get = function()
        local _, icon = GetIcon()
        return icon and icon.outline or "OUTLINE"
      end,
      set = function(_, value) SetIconValue("outline", value) end,
    },
  }

  local readyArgs = {
    readyAlpha = args.readyAlpha,
    desaturateReady = args.desaturateReady,
    readyGlowStyle = args.readyGlowStyle,
    readyGlowColor = args.readyGlowColor,
  }

  local cooldownArgs = {}
  local activeArgs = {
    activeAuraEnabled = args.activeAuraEnabled,
    activeAuraSource = args.activeAuraSource,
    activeAuraCDM = args.activeAuraCDM,
    activeAuraCustom = args.activeAuraCustom,
    activeAuraAlpha = args.activeAuraAlpha,
    activeAuraDesaturate = args.activeAuraDesaturate,
    activeAuraGlowStyle = args.activeAuraGlowStyle,
    activeAuraHideViewerIcon = args.activeAuraHideViewerIcon,
    activeAuraGlowColor = args.activeAuraGlowColor,
  }

  if auraKind then
    activeArgs.showSwipe = args.showSwipe
    activeArgs.showDuration = args.showDuration
    activeArgs.showCount = args.showCount
    activeArgs.showStackStrip = args.showStackStrip
  else
    cooldownArgs.onCooldownAlpha = args.onCooldownAlpha
    cooldownArgs.desaturateCooldown = args.desaturateCooldown
    cooldownArgs.cooldownGlowStyle = args.cooldownGlowStyle
    cooldownArgs.cooldownGlowColor = args.cooldownGlowColor
    cooldownArgs.showSwipe = args.showSwipe
    cooldownArgs.showDuration = args.showDuration
    cooldownArgs.showCount = args.showCount
    cooldownArgs.showPips = args.showPips
  end

  return {
    type = "group",
    name = "Button settings",
    order = order,
    inline = true,
    hidden = HiddenWhenIconOff,
    args = {
      design = {
        type = "group",
        name = "Button Size & Design",
        order = 10,
        inline = true,
        args = {
          size = args.size,
          visibility = args.visibility,
          combatOnly = args.combatOnly,
          outOfCombatAlpha = args.outOfCombatAlpha,
          chromeStyle = args.chromeStyle,
          borderSize = args.borderSize,
          borderColor = args.borderColor,
          backgroundColor = args.backgroundColor,
          showTooltip = args.showTooltip,
        },
      },
      ready = {
        type = "group",
        name = auraKind and "When inactive" or chargeKind and "At full charges" or "When ready",
        order = 20,
        inline = true,
        args = readyArgs,
      },
      cooldown = {
        type = "group",
        name = chargeKind and "When recharging" or "When on CD",
        order = 30,
        inline = true,
        hidden = auraKind,
        args = cooldownArgs,
      },
      active = {
        type = "group",
        name = "When Active",
        order = 40,
        inline = true,
        args = activeArgs,
      },
      fonts = {
        type = "group",
        name = "Font Settings",
        order = 50,
        inline = true,
        args = {
          font = args.font,
          outline = args.outline,
          fontSize = args.fontSize,
          durationTextScale = args.durationTextScale,
          durationTextAnchor = args.durationTextAnchor,
          durationTextX = args.durationTextX,
          durationTextY = args.durationTextY,
          durationTextColor = args.durationTextColor,
          countFontSize = args.countFontSize,
          countTextScale = args.countTextScale,
          countTextAnchor = args.countTextAnchor,
          countTextX = args.countTextX,
          countTextY = args.countTextY,
          countTextColor = args.countTextColor,
        },
      },
    },
  }
end

local function _PCM_BuildCustomBarStateGroups(GetCfg, RebuildRuntime, chargeKind, order)
  local glowStyles = {
    NONE = "None",
    PIXEL = "Pixel",
    AUTOCAST = "Autocast",
    PROC = "Proc",
  }

  local function GetValue(key, fallback)
    local _, _, cfg = GetCfg()
    local value = cfg and cfg[key]
    if value == nil then return fallback end
    return value
  end

  local function SetValue(key, value)
    local _, _, cfg = GetCfg()
    if not cfg then return end
    cfg[key] = value
    RebuildRuntime()
  end

  local function Hidden()
    local _, _, cfg = GetCfg()
    return not cfg or cfg.presentation ~= "BAR"
  end

  local readyAlpha = {
    type = "range",
    name = chargeKind and "Full-charge opacity" or "Ready opacity",
    order = 1,
    min = 0,
    max = 100,
    step = 1,
    get = function() return GetValue("readyAlpha", 100) end,
    set = function(_, value) SetValue("readyAlpha", value) end,
  }
  local desaturateReady = {
    type = "toggle",
    name = chargeKind and "Desaturate at full charges" or "Desaturate while ready",
    order = 2,
    get = function() return GetValue("desaturateReady", false) == true end,
    set = function(_, value) SetValue("desaturateReady", value == true) end,
  }
  local readyGlow = {
    type = "select",
    name = chargeKind and "Full-charge glow" or "Ready glow",
    order = 3,
    values = glowStyles,
    get = function() return GetValue("readyGlowStyle", "NONE") end,
    set = function(_, value) SetValue("readyGlowStyle", value) end,
  }
  local readyGlowColor = {
    type = "color",
    name = chargeKind and "Full-charge glow color" or "Ready glow color",
    order = 4,
    hasAlpha = true,
    disabled = function() return GetValue("readyGlowStyle", "NONE") == "NONE" end,
    get = function()
      local color = GetValue("readyGlowColor", { 0.25, 0.75, 1, 1 })
      return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
    end,
    set = function(_, r, g, b, a)
      SetValue("readyGlowColor", { r, g, b, a or 1 })
    end,
  }

  local cooldownAlpha = {
    type = "range",
    name = chargeKind and "Recharging opacity" or "On cooldown opacity",
    order = 1,
    min = 0,
    max = 100,
    step = 1,
    get = function() return GetValue("onCooldownAlpha", 100) end,
    set = function(_, value) SetValue("onCooldownAlpha", value) end,
  }
  local desaturateCooldown = {
    type = "toggle",
    name = chargeKind and "Desaturate while recharging" or "Desaturate while on cooldown",
    order = 2,
    get = function() return GetValue("desaturateCooldown", false) == true end,
    set = function(_, value) SetValue("desaturateCooldown", value == true) end,
  }
  local cooldownGlow = {
    type = "select",
    name = chargeKind and "Recharging glow" or "Cooldown glow",
    order = 3,
    values = glowStyles,
    get = function() return GetValue("cooldownGlowStyle", "NONE") end,
    set = function(_, value) SetValue("cooldownGlowStyle", value) end,
  }
  local cooldownGlowColor = {
    type = "color",
    name = chargeKind and "Recharging glow color" or "Cooldown glow color",
    order = 4,
    hasAlpha = true,
    disabled = function() return GetValue("cooldownGlowStyle", "NONE") == "NONE" end,
    get = function()
      local color = GetValue("cooldownGlowColor", { 1, 0.55, 0.1, 1 })
      return color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a
    end,
    set = function(_, r, g, b, a)
      SetValue("cooldownGlowColor", { r, g, b, a or 1 })
    end,
  }

  return {
    ready = {
      type = "group",
      name = chargeKind and "At full charges" or "When ready",
      order = order or 45,
      inline = true,
      hidden = Hidden,
      args = {
        alpha = readyAlpha,
        desaturate = desaturateReady,
        glow = readyGlow,
        glowColor = readyGlowColor,
      },
    },
    cooldown = {
      type = "group",
      name = chargeKind and "When recharging" or "When on CD",
      order = (order or 45) + 1,
      inline = true,
      hidden = Hidden,
      args = {
        alpha = cooldownAlpha,
        desaturate = desaturateCooldown,
        glow = cooldownGlow,
        glowColor = cooldownGlowColor,
      },
    },
  }
end

local function _PCM_BuildSpellBarLeafArgs(id)
  local flat = {}

  local function GetCfg()
    local CM, root, cfg = _PCM_GetSpellBarById(id)
    return CM, root, cfg
  end

  local function RebuildRuntime()
    Cooldowns:SpellBars_Rebuild()
  end

  local function IsButtonTracker()
    local _, _, cfg = GetCfg()
    return cfg and cfg.presentation == "BUTTON" or false
  end

  local function RefreshRuntime(flags)
    Cooldowns:SpellBars_RefreshBar(id, flags)
    ns.FrameUtil.RefreshSmartSnapState("PCM_SpellBar_" .. tostring(id))
  end

  local function RefreshNodeName()
    RebuildRuntime()
    _PCM_ACD_NotifyPCM("spell:" .. tostring(id))
  end

  flat.enabled = {
    type = "toggle",
    name = "Enable tracker",
    order = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.enabled ~= false or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.enabled = not not v
      RefreshNodeName()
    end,
  }

  flat.deleteBar = {
    type = "execute",
    name = "Delete tracker",
    order = 3,

    confirm = true,
    confirmText = "Delete this cooldown tracker?",
    func = function()
      local CM, root, cfg = GetCfg()

      wipe(_PCMValueCache)

      CM:Enable()
      CM:SpellBars_DeleteBar(id)

      _PCM_ACD_NotifyPCM(nil)
    end,
  }

  flat.specializationSpells = _PCM_BuildSpecializationSpellGroup(
    GetCfg,
    function()
      return _PCM_GetCustomBarSpellList("cooldown")
    end,
    RefreshNodeName,
    15
  )

  flat.showIcon = {
    type = "toggle",
    name = "Show icon beside bar",
    order = 21,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.showIcon == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showIcon = not not v
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.hideOutOfCombat = {
    type = "toggle",
    name = "Hide out of combat",
    order = 22,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.hideOutOfCombat == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.hideOutOfCombat = not not v
      if cfg.outOfCombatAlpha == nil then
        cfg.outOfCombatAlpha = 0
      end
      RefreshRuntime({ visibility = true })
    end,
  }

  flat.outOfCombatAlpha = {
    type = "range",
    name = "Out-of-combat opacity",
    order = 23,
    min = 0,
    max = 100,
    step = 1,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.hideOutOfCombat == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.outOfCombatAlpha) or 0) or 0
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      v = tonumber(v) or 0
      if v < 0 then v = 0 end
      if v > 100 then v = 100 end
      cfg.outOfCombatAlpha = v
      RefreshRuntime({ visibility = true })
    end,
  }

  flat.width = {
    type = "range",
    name = "Total width",
    order = 30,
    min = 80,
    max = 600,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.width) or 250
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.width = tonumber(v) or 250
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.height = {
    type = "range",
    name = "Bar height",
    order = 31,
    min = 6,
    max = 40,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.height) or 25
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.height = tonumber(v) or 25
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.orientation = {
    type = "select",
    name = "Orientation",
    order = 32,
    values = {
      horizontal = "Horizontal",
      vertical = "Vertical",
    },
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.orientation == "vertical" and "vertical" or "horizontal"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.orientation = value == "vertical" and "vertical" or "horizontal"
      cfg.fillDirection = cfg.orientation == "vertical" and "UP" or "RIGHT"
      cfg.iconAnchor = cfg.orientation == "vertical" and "top" or "left"
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.barMode = {
    type = "select",
    name = "Bar mode",
    order = 33,
    values = {
      fill = "Fill",
      drain = "Drain",
    },
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.direction == "drain" and "drain" or "fill"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.direction = value == "drain" and "drain" or "fill"
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fillDirection = {
    type = "select",
    name = "Direction",
    order = 34,
    values = function()
      local CM, root, cfg = GetCfg()
      if cfg and cfg.orientation == "vertical" then
        return { UP = "Up", DOWN = "Down" }
      end
      return { LEFT = "Left", RIGHT = "Right" }
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      if not cfg then return "RIGHT" end
      if cfg.orientation == "vertical" then
        return cfg.fillDirection == "DOWN" and "DOWN" or "UP"
      end
      return cfg.fillDirection == "LEFT" and "LEFT" or "RIGHT"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      if cfg.orientation == "vertical" then
        cfg.fillDirection = value == "DOWN" and "DOWN" or "UP"
      else
        cfg.fillDirection = value == "LEFT" and "LEFT" or "RIGHT"
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.texture = {
    type = "select",
    name = "Bar texture",
    order = 35,

    values = function()
      return OptionsUtil.BuildStatusbarValues(false)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.texture) or "Pleebar"
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      if type(key) == "string" and key ~= "" then
        cfg.texture = key
      else
        cfg.texture = nil
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.useClassColor = {
    type = "toggle",
    name = "Use class color",
    order = 40,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.useClassColor == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useClassColor = not not v
      if cfg.useClassColor then
        local r, g, b = 1, 1, 1
        local class = select(2, UnitClass("player"))
        local c = C_ClassColor.GetClassColor(class)
        if c then
          r = tonumber(c.r) or r
          g = tonumber(c.g) or g
          b = tonumber(c.b) or b
        end
        cfg.barColor = { r, g, b, 1 }
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.barColor = {
    type = "color",
    name = "Bar color",
    order = 41,
    hasAlpha = true,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.useClassColor == true or false
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      local c = cfg and cfg.barColor or nil
      local r, g, b, a = 1, 1, 1, 1
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useClassColor = false
      cfg.barColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.borderColor = {
    type = "color",
    name = "Border color",
    order = 42,
    hasAlpha = true,

    get = function()
      local CM, root, cfg = GetCfg()
      local c = cfg and cfg.borderColor or nil
      local r, g, b, a = 0.12, 0.12, 0.12, 0.955
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.borderColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.borderSize = {
    type = "range",
    name = "Border thickness",
    order = 43,
    min = 0,
    max = 6,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.borderSize) or 2) or 2
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.borderSize = tonumber(value) or 2
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.backgroundColor = {
    type = "color",
    name = "Background color",
    order = 44,
    hasAlpha = true,

    get = function()
      local CM, root, cfg = GetCfg()
      local c = cfg and cfg.backgroundColor or nil
      local r, g, b, a = 0.12, 0.12, 0.12, 0.955
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.backgroundColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.showText = {
    type = "toggle",
    name = "Show text",
    order = 59,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.showText ~= false or false
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showText = value == true
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontSize = {
    type = "range",
    name = "Font size",
    order = 60,
    min = 8,
    max = 28,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.fontSize) or 14
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontSize = tonumber(v) or 14
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.font = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Timer font",
    order = 61,
    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.font or "PleebUI"
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.font = type(key) == "string" and key ~= "" and key or nil
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontOutline = {
    type = "select",
    name = "Font outline",
    order = 62,
    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.fontOutline or ""
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontOutline = type(key) == "string" and key ~= "" and key or nil
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontColor = {
    type = "color",
    name = "Font color",
    order = 63,
    hasAlpha = true,
    get = function()
      local CM, root, cfg = GetCfg()
      return _PCM_GetColorComponents(cfg and cfg.fontColor, { 1, 1, 1, 1 })
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.iconAnchor = {
    type = "select",
    name = "Icon position",
    order = 35,
    values = function()
      local CM, root, cfg = GetCfg()
      if cfg and cfg.orientation == "vertical" then
        return { top = "Top", bottom = "Bottom" }
      end
      return { left = "Left", right = "Right" }
    end,
    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.showIcon == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.iconAnchor or "left"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.iconAnchor = value
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  local stateGroups = _PCM_BuildCustomBarStateGroups(GetCfg, RebuildRuntime, false, 45)

  return {
    general = {
      type = "group",
      name = "General",
      order = 10,
      inline = true,
      args = {
        enabled = flat.enabled,
        deleteBar = flat.deleteBar,
      },
    },
    specializationSpells = flat.specializationSpells,
    icon = _PCM_BuildCustomIconGroup(GetCfg, RebuildRuntime, "cooldown", 15),
    visibility = {
      type = "group",
      name = "Visibility",
      order = 20,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showIcon = flat.showIcon,
        hideOutOfCombat = flat.hideOutOfCombat,
        outOfCombatAlpha = flat.outOfCombatAlpha,
      },
    },
    barLayout = {
      type = "group",
      name = "Bar Size & Layout",
      order = 30,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        width = flat.width,
        height = flat.height,
        orientation = flat.orientation,
        barMode = flat.barMode,
        fillDirection = flat.fillDirection,
        texture = flat.texture,
        iconAnchor = flat.iconAnchor,
      },
    },
    barDesign = {
      type = "group",
      name = "Bar Design",
      order = 40,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        useClassColor = flat.useClassColor,
        barColor = flat.barColor,
        borderSize = flat.borderSize,
        borderColor = flat.borderColor,
        backgroundColor = flat.backgroundColor,
      },
    },
    whenReady = stateGroups.ready,
    whenCooldown = stateGroups.cooldown,
    whenActive = _PCM_BuildCustomBarBuffGlowGroup(
      GetCfg,
      RebuildRuntime,
      "cooldown:" .. tostring(id),
      47
    ),
    fontSettings = {
      type = "group",
      name = "Font Settings",
      order = 60,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showText = flat.showText,
        fontSize = flat.fontSize,
        font = flat.font,
        fontOutline = flat.fontOutline,
        fontColor = flat.fontColor,
      },
    },
  }
end

local function _PCM_GetChargeCooldownBarById(id)
  local CM = Cooldowns
  local root = CM:GetCooldownStackBarsDB()

  local cfg = root[id]
  if cfg == nil and tonumber(id) ~= nil then
    id = tonumber(id)
    cfg = root[id]
  end

  if cfg then
    cfg = CM.NormalizeCooldownStackBarEntry(cfg, id)
    root[id] = cfg
  end

  return CM, root, cfg
end

local function _PCM_BuildChargeCooldownBarLeafArgs(id)
  local flat = {}

  local function GetCfg()
    local CM, root, cfg = _PCM_GetChargeCooldownBarById(id)
    return CM, root, cfg
  end

  local function RebuildRuntime()
    Cooldowns:CooldownStackBars_Rebuild()
  end

  local function IsButtonTracker()
    local _, _, cfg = GetCfg()
    return cfg and cfg.presentation == "BUTTON" or false
  end

  local function RefreshRuntime(flags)
    Cooldowns:CooldownStackBars_RefreshBar(id, flags)
    ns.FrameUtil.RefreshSmartSnapState("PCMChargeCooldownBar:" .. tostring(id))
  end

  local function RefreshNodeName()
    RebuildRuntime()
    _PCM_ACD_NotifyPCM("chargeSpell:" .. tostring(id))
  end

  local function GetLiveMaxCharges()
    local CM, root, cfg = GetCfg()
    local spellID = cfg and CM:GetTrackedSpellIDForCurrentSpec(cfg) or nil
    local chargeInfo = spellID and C_Spell.GetSpellCharges(spellID) or nil
    if _G.issecretvalue(chargeInfo) or type(chargeInfo) ~= "table" then
      return 2
    end

    local maxCharges = chargeInfo.maxCharges
    if _G.issecretvalue(maxCharges) then
      return 2
    end

    maxCharges = math.floor((tonumber(maxCharges) or 2) + 0.5)
    if maxCharges < 1 then maxCharges = 1 end
    if maxCharges > 60 then maxCharges = 60 end
    return maxCharges
  end

  flat.enabled = {
    type = "toggle",
    name = "Enable tracker",
    order = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.enabled ~= false or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.enabled = not not v
      RefreshNodeName()
    end,
  }

  flat.deleteBar = {
    type = "execute",
    name = "Delete tracker",
    order = 3,

    confirm = true,
    confirmText = "Delete this charge cooldown tracker?",
    func = function()
      local CM, root, cfg = GetCfg()

      wipe(_PCMValueCache)

      CM:Enable()
      CM:CooldownStackBars_DeleteBar(id)

      _PCM_ACD_NotifyPCM(nil)
    end,
  }

  flat.specializationSpells = _PCM_BuildSpecializationSpellGroup(
    GetCfg,
    function()
      return _PCM_GetCustomBarSpellList("cooldown")
    end,
    RefreshNodeName,
    15
  )

  flat.showIcon = {
    type = "toggle",
    name = "Show icon beside bar",
    order = 21,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.showIcon == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showIcon = not not v
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.hideOutOfCombat = {
    type = "toggle",
    name = "Hide out of combat",
    order = 22,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.hideOutOfCombat == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.hideOutOfCombat = not not v
      if cfg.outOfCombatAlpha == nil then
        cfg.outOfCombatAlpha = 0
      end
      RefreshRuntime({ visibility = true })
    end,
  }

  flat.outOfCombatAlpha = {
    type = "range",
    name = "Out-of-combat opacity",
    order = 23,
    min = 0,
    max = 100,
    step = 1,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.hideOutOfCombat == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.outOfCombatAlpha) or 0) or 0
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      v = tonumber(v) or 0
      if v < 0 then v = 0 end
      if v > 100 then v = 100 end
      cfg.outOfCombatAlpha = v
      RefreshRuntime({ visibility = true })
    end,
  }

  flat.width = {
    type = "range",
    name = "Total width",
    order = 30,
    min = 80,
    max = 600,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.width) or 250
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.width = tonumber(v) or 250
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.height = {
    type = "range",
    name = "Bar height",
    order = 31,
    min = 6,
    max = 40,
    step = 1,

    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.height) or 25
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.height = tonumber(v) or 25
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.orientation = {
    type = "select",
    name = "Orientation",
    order = 32,
    values = {
      horizontal = "Horizontal",
      vertical = "Vertical",
    },
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.orientation == "vertical" and "vertical" or "horizontal"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.orientation = value == "vertical" and "vertical" or "horizontal"
      cfg.fillDirection = cfg.orientation == "vertical" and "UP" or "RIGHT"
      RefreshRuntime({ presentation = true, layout = true })
    end,
  }

  flat.barMode = {
    type = "select",
    name = "Bar mode",
    order = 33,
    values = {
      fill = "Fill",
      drain = "Drain",
    },
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.durationBarFillMode == "drain" and "drain" or "fill"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationBarFillMode = value == "drain" and "drain" or "fill"
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fillDirection = {
    type = "select",
    name = "Direction",
    order = 34,
    values = function()
      local CM, root, cfg = GetCfg()
      if cfg and cfg.orientation == "vertical" then
        return { UP = "Up", DOWN = "Down" }
      end
      return { LEFT = "Left", RIGHT = "Right" }
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      if not cfg then return "RIGHT" end
      if cfg.orientation == "vertical" then
        return cfg.fillDirection == "DOWN" and "DOWN" or "UP"
      end
      return cfg.fillDirection == "LEFT" and "LEFT" or "RIGHT"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      if cfg.orientation == "vertical" then
        cfg.fillDirection = value == "DOWN" and "DOWN" or "UP"
      else
        cfg.fillDirection = value == "LEFT" and "LEFT" or "RIGHT"
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.texture = {
    type = "select",
    name = "Bar texture",
    order = 35,

    values = function()
      return OptionsUtil.BuildStatusbarValues(false)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return (cfg and cfg.texture) or "Pleebar"
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      if type(key) == "string" and key ~= "" then
        cfg.texture = key
      else
        cfg.texture = nil
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.showText = {
    type = "toggle",
    name = "Show text",
    order = 32,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.showText ~= false or false
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showText = value == true
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.font = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Timer font",
    order = 33,

    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      local v = cfg and cfg.font
      if v == nil or v == "" then
        return "PleebUI"
      end
      return v
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      if type(key) == "string" and key ~= "" then
        cfg.font = key
      else
        cfg.font = nil
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontSize = {
    type = "range",
    name = "Font size",
    order = 34,
    min = 8,
    max = 28,
    step = 1,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.fontSize) or 14) or 14
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontSize = tonumber(value) or 14
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontOutline = {
    type = "select",
    name = "Font outline",
    order = 35,
    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.fontOutline or ""
    end,
    set = function(_, key)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontOutline = type(key) == "string" and key ~= "" and key or nil
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fontColor = {
    type = "color",
    name = "Font color",
    order = 36,
    hasAlpha = true,
    get = function()
      local CM, root, cfg = GetCfg()
      return _PCM_GetColorComponents(cfg and cfg.fontColor, { 1, 1, 1, 1 })
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.useClassColor = {
    type = "toggle",
    name = "Use class color",
    order = 40,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.useClassColor == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useClassColor = not not v
      if cfg.useClassColor then
        local r, g, b = 1, 1, 1
        local class = select(2, UnitClass("player"))
        local c = C_ClassColor.GetClassColor(class)
        if c then
          r = tonumber(c.r) or r
          g = tonumber(c.g) or g
          b = tonumber(c.b) or b
        end
        cfg.barColor = { r, g, b, 1 }
      end
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.barColor = {
    type = "color",
    name = "Bar color",
    order = 41,
    hasAlpha = true,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.useClassColor == true or false
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      local c = cfg and cfg.barColor or nil
      local r, g, b, a = 1, 1, 1, 1
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useClassColor = false
      cfg.barColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.showSlotBorder = {
    type = "toggle",
    name = "Show slot borders",
    order = 43,

    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.showSlotBorder == true or false
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showSlotBorder = not not v
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.slotBorderThickness = {
    type = "range",
    name = "Slot border thickness",
    order = 44,
    min = 0,
    max = 5,
    step = 1,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.showSlotBorder == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      local v = cfg and tonumber(cfg.slotBorderThickness) or 1
      if v < 0 then v = 0 end
      if v > 5 then v = 5 end
      return v
    end,
    set = function(_, v)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      v = tonumber(v) or 1
      if v < 0 then v = 0 end
      if v > 5 then v = 5 end
      cfg.slotBorderThickness = v
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.slotBorderColor = {
    type = "color",
    name = "Slot border color",
    order = 45,
    hasAlpha = true,

    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.showSlotBorder == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      local c = cfg and cfg.slotBorderColor or nil
      local r, g, b, a = 0, 0, 0, 1
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.slotBorderColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.slotSpacing = {
    type = "range",
    name = "Slot spacing",
    order = 46,
    min = 0,
    max = 20,
    step = 1,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.slotSpacing) or 0) or 0
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.slotSpacing = tonumber(value) or 0
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.slotBackgroundColor = {
    type = "color",
    name = "Slot background color",
    order = 47,
    hasAlpha = true,
    get = function()
      local CM, root, cfg = GetCfg()
      return _PCM_GetColorComponents(cfg and cfg.slotBackgroundColor, { 0.12, 0.12, 0.12, 0.95 })
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.slotBackgroundColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.opacity = {
    type = "range",
    name = "Bar opacity",
    order = 48,
    min = 0,
    max = 100,
    step = 1,
    get = function()
      local CM, root, cfg = GetCfg()
      return math.floor(((cfg and tonumber(cfg.opacity)) or 1) * 100 + 0.5)
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.opacity = (tonumber(value) or 100) / 100
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.useDifferentFullColor = {
    type = "toggle",
    name = "Use a different full-charge color",
    order = 49,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.useDifferentFullColor == true or false
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useDifferentFullColor = value == true
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.fullChargeColor = {
    type = "color",
    name = "Full-charge color",
    order = 50,
    hasAlpha = true,
    disabled = function()
      local CM, root, cfg = GetCfg()
      return not (cfg and cfg.useDifferentFullColor == true)
    end,
    get = function()
      local CM, root, cfg = GetCfg()
      return _PCM_GetColorComponents(cfg and cfg.fullChargeColor, cfg and cfg.barColor or { 1, 1, 1, 1 })
    end,
    set = function(_, r, g, b, a)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fullChargeColor = { r, g, b, a or 1 }
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.rotateTexture = {
    type = "select",
    name = "Texture rotation",
    order = 51,
    values = {
      AUTO = "Automatic",
      ON = "Always rotate",
      OFF = "Never rotate",
    },
    get = function()
      local CM, root, cfg = GetCfg()
      if cfg and cfg.rotateTexture == true then return "ON" end
      if cfg and cfg.rotateTexture == false then return "OFF" end
      return "AUTO"
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.rotateTexture = value == "ON" and true or value == "OFF" and false or nil
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.dynamicTextOnSlot = {
    type = "toggle",
    name = "Follow the recharging slot",
    order = 52,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.dynamicTextOnSlot ~= false or false
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.dynamicTextOnSlot = value == true
      RefreshRuntime({ presentation = true })
    end,
  }

  flat.usePerSlotColors = {
    type = "toggle",
    name = "Use per-slot colors",
    order = 53,
    get = function()
      local CM, root, cfg = GetCfg()
      return cfg and cfg.usePerSlotColors == true or false
    end,
    set = function(_, value)
      local CM, root, cfg = GetCfg()
      if not cfg then return end
      cfg.usePerSlotColors = value == true
      RefreshRuntime({ presentation = true })
    end,
  }

  local slotColorArgs = {}
  local defaultSlotColors = {
    { 0.8, 0.2, 0.2, 1 },
    { 0.8, 0.8, 0.2, 1 },
    { 0.2, 0.8, 0.2, 1 },
    { 0.2, 0.6, 0.8, 1 },
    { 0.6, 0.2, 0.8, 1 },
  }

  for index = 1, GetLiveMaxCharges() do
    local slotIndex = index
    local field = "chargeSlot" .. slotIndex .. "Color"
    slotColorArgs[field] = {
      type = "color",
      name = "Slot " .. slotIndex .. " color",
      order = slotIndex,
      hasAlpha = true,
      get = function()
        local CM, root, cfg = GetCfg()
        return _PCM_GetColorComponents(
          cfg and cfg[field],
          defaultSlotColors[slotIndex] or cfg and cfg.barColor or { 1, 1, 1, 1 }
        )
      end,
      set = function(_, r, g, b, a)
        local CM, root, cfg = GetCfg()
        if not cfg then return end
        cfg[field] = { r, g, b, a or 1 }
        RefreshRuntime({ presentation = true })
      end,
    }
  end

  local stateGroups = _PCM_BuildCustomBarStateGroups(GetCfg, RebuildRuntime, true, 45)

  return {
    general = {
      type = "group",
      name = "General",
      order = 10,
      inline = true,
      args = {
        enabled = flat.enabled,
        deleteBar = flat.deleteBar,
      },
    },
    specializationSpells = flat.specializationSpells,
    icon = _PCM_BuildCustomIconGroup(GetCfg, RebuildRuntime, "charge", 15),
    visibility = {
      type = "group",
      name = "Visibility",
      order = 20,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showIcon = flat.showIcon,
        hideOutOfCombat = flat.hideOutOfCombat,
        outOfCombatAlpha = flat.outOfCombatAlpha,
      },
    },
    barLayout = {
      type = "group",
      name = "Bar Size & Layout",
      order = 30,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        width = flat.width,
        height = flat.height,
        orientation = flat.orientation,
        barMode = flat.barMode,
        fillDirection = flat.fillDirection,
        texture = flat.texture,
      },
    },
    barDesign = {
      type = "group",
      name = "Bar Design",
      order = 40,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        useClassColor = flat.useClassColor,
        barColor = flat.barColor,
        showSlotBorder = flat.showSlotBorder,
        slotBorderThickness = flat.slotBorderThickness,
        slotBorderColor = flat.slotBorderColor,
        slotSpacing = flat.slotSpacing,
        slotBackgroundColor = flat.slotBackgroundColor,
        opacity = flat.opacity,
        useDifferentFullColor = flat.useDifferentFullColor,
        fullChargeColor = flat.fullChargeColor,
        rotateTexture = flat.rotateTexture,
        dynamicTextOnSlot = flat.dynamicTextOnSlot,
        usePerSlotColors = flat.usePerSlotColors,
      },
    },
    slotColors = {
      type = "group",
      name = "Slot Colors",
      order = 45,
      inline = true,
      hidden = function()
        local CM, root, cfg = GetCfg()
        return IsButtonTracker() or not (cfg and cfg.usePerSlotColors == true)
      end,
      args = slotColorArgs,
    },
    whenReady = stateGroups.ready,
    whenCooldown = stateGroups.cooldown,
    whenActive = _PCM_BuildCustomBarBuffGlowGroup(
      GetCfg,
      RebuildRuntime,
      "charge:" .. tostring(id),
      47
    ),
    fontSettings = {
      type = "group",
      name = "Font Settings",
      order = 60,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showText = flat.showText,
        font = flat.font,
        fontSize = flat.fontSize,
        fontOutline = flat.fontOutline,
        fontColor = flat.fontColor,
      },
    },
  }
end

local function _PCM_GetBuffBarById(id)
  local API = ns.Modules.PCM_BB
  local root = API.GetStackBarsDB()

  local actualId = id
  local cfg = root[actualId]

  if cfg == nil and tonumber(actualId) ~= nil then
    actualId = tonumber(actualId)
    cfg = root[actualId]
  end

  if cfg then
    cfg = API.EnsureStackBarDefaults(cfg, actualId)
    root[actualId] = cfg
  end

  return API, root, cfg, actualId
end

local function _PCM_RebuildBuffBarsRuntime()
  ns.Modules.PCM_BB:Enable()
  ns.Modules.PCM_BB.RebuildCustomBars()
end


_PCM_BuildCustomBarBuffGlowGroup = function(GetCfg, RebuildRuntime, trackKey, order)
  local function GetGlowConfig()
    local _, _, cfg = GetCfg()
    return cfg
  end

  local function IsAuraTracker(cfg)
    return cfg and (cfg.kind == "duration" or cfg.kind == "stack") or false
  end

  local function IsGlowEnabled()
    local cfg = GetGlowConfig()
    if not cfg then
      return false
    end
    if IsAuraTracker(cfg) then
      return cfg.buffGlowEnabled == true
    end
    return cfg.activeAuraEnabled == true and cfg.activeGlowStyle ~= "NONE"
  end

  local function IsActiveAuraEnabled()
    local cfg = GetGlowConfig()
    return cfg and (IsAuraTracker(cfg) or cfg.activeAuraEnabled == true) or false
  end

  local glowStyles = {
    NONE = "None",
    PIXEL = "Pixel",
    AUTOCAST = "Autocast",
    PROC = "Proc",
  }

  local function GetGlowSource()
    local cfg = GetGlowConfig()
    return cfg and cfg.buffGlowSource == "CUSTOM" and "CUSTOM" or "CDM"
  end

  local function RefreshGlowStyle()
    local cfg = GetGlowConfig()
    if not cfg then
      return
    end
    PCMPresentation.RefreshCustomBarBuffGlowStyle(trackKey, cfg)
  end

  return {
    type = "group",
    name = "When active",
    order = order or 55,
    inline = true,
    hidden = function()
      local cfg = GetGlowConfig()
      return cfg and cfg.presentation == "BUTTON" or false
    end,
    args = {
      showActive = {
        type = "toggle",
        name = "Show while aura is active",
        order = 1,
        hidden = function()
          local cfg = GetGlowConfig()
          return cfg and (cfg.kind == "duration" or cfg.kind == "stack") or false
        end,
        get = function() return IsActiveAuraEnabled() end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.activeAuraEnabled = value == true
          cfg.buffGlowEnabled = cfg.activeAuraEnabled and cfg.activeGlowStyle ~= "NONE"
          RebuildRuntime()
        end,
      },
      activeAlpha = {
        type = "range",
        name = "Active alpha",
        order = 2,
        min = 0,
        max = 100,
        step = 1,
        hidden = function() return not IsActiveAuraEnabled() end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and cfg.activeAlpha or 100
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.activeAlpha = value
          RebuildRuntime()
        end,
      },
      desaturateActive = {
        type = "toggle",
        name = "Desaturate while active",
        order = 3,
        hidden = function() return not IsActiveAuraEnabled() end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and cfg.desaturateActive == true or false
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.desaturateActive = value == true
          RebuildRuntime()
        end,
      },
      activeGlowStyle = {
        type = "select",
        name = "Active glow",
        order = 4,
        values = glowStyles,
        hidden = function() return not IsActiveAuraEnabled() end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and cfg.activeGlowStyle or "NONE"
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.activeGlowStyle = value
          cfg.buffGlowEnabled = value ~= "NONE"
            and (IsAuraTracker(cfg) or cfg.activeAuraEnabled == true)
          RebuildRuntime()
        end,
      },
      source = {
        type = "select",
        name = "Buff source",
        order = 10,
        values = {
          CDM = "Buff from CDM",
          CUSTOM = "Custom buff",
        },
        hidden = function()
          return not IsActiveAuraEnabled()
        end,
        get = function()
          return GetGlowSource()
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.buffGlowSource = value == "CUSTOM" and "CUSTOM" or "CDM"
          cfg.buffGlowSpellID = nil
          RebuildRuntime()
        end,
      },
      cdmBuff = {
        type = "select",
        name = "Buff from CDM",
        desc = "You can select any available Cooldown Manager buff, even if it is not currently shown there. Shown buffs are listed first; buffs not currently shown are grey.",
        order = 11,
        values = function()
          local values = _PCM_GetCustomBarSpellList("aura")
          return values
        end,
        sorting = function()
          local _, sorting = _PCM_GetCustomBarSpellList("aura")
          return sorting
        end,
        hidden = function()
          return not IsActiveAuraEnabled() or GetGlowSource() ~= "CDM"
        end,
        get = function()
          local cfg = GetGlowConfig()
          local spellID = cfg and tonumber(cfg.buffGlowSpellID) or nil
          return spellID and tostring(spellID) or "none"
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.buffGlowSpellID = value ~= "none" and tonumber(value) or nil
          RebuildRuntime()
        end,
      },
      customBuff = {
        type = "input",
        name = "Custom buff",
        desc = "Enter a player buff spell ID.",
        order = 11,
        hidden = function()
          return not IsActiveAuraEnabled() or GetGlowSource() ~= "CUSTOM"
        end,
        validate = function(_, value)
          if value == nil or value == "" then
            return true
          end

          local spellID = tonumber(value)
          if spellID and spellID > 0 and spellID == math.floor(spellID) then
            return true
          end

          return "Enter a whole spell ID."
        end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and cfg.buffGlowSpellID and tostring(cfg.buffGlowSpellID) or ""
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          local spellID = tonumber(value)
          cfg.buffGlowSpellID = spellID and math.floor(spellID) or nil
          RebuildRuntime()
        end,
      },
      hideViewerIcon = {
        type = "toggle",
        name = "Hide from buff icon viewer",
        desc = "Hide the aura used for this glow from the Buff Icon Viewer.",
        order = 12,
        hidden = function()
          return not IsGlowEnabled()
        end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and cfg.buffGlowHideViewerIcon == true or false
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.buffGlowHideViewerIcon = value == true
          RebuildRuntime()
        end,
      },
      thickness = {
        type = "range",
        name = "Glow thickness",
        order = 13,
        min = 1,
        max = 8,
        step = 1,
        hidden = function()
          return not IsGlowEnabled()
        end,
        get = function()
          local cfg = GetGlowConfig()
          return cfg and tonumber(cfg.buffGlowThickness) or 2
        end,
        set = function(_, value)
          local cfg = GetGlowConfig()
          if not cfg then return end
          cfg.buffGlowThickness = math.floor((tonumber(value) or 2) + 0.5)
          RefreshGlowStyle()
        end,
      },
      color = {
        type = "color",
        name = "Glow color",
        order = 14,
        hasAlpha = true,
        hidden = function()
          return not IsGlowEnabled()
        end,
        get = function()
          local cfg = GetGlowConfig()
          local color = cfg and (cfg.activeGlowColor or cfg.buffGlowColor) or nil
          local r, g, b, a = 0.25, 0.75, 1, 1
          if type(color) == "table" then
            r = tonumber(color[1] or color.r) or r
            g = tonumber(color[2] or color.g) or g
            b = tonumber(color[3] or color.b) or b
            a = tonumber(color[4] or color.a) or a
          end
          return r, g, b, a
        end,
        set = function(_, r, g, b, a)
          local cfg = GetGlowConfig()
          if not cfg then return end
          local color = { r, g, b, a or 1 }
          cfg.activeGlowColor = color
          cfg.buffGlowColor = color
          RefreshGlowStyle()
        end,
      },
    },
  }
end

local STACK_THRESHOLD_COLOR_VALUES = {
  CLASS = "Class color",
  CUSTOM = "Custom color",
}

local function _PCM_BuildBuffBarLeafArgs(id)
  local args = {}

  local function GetCfg()
    local API, root, cfg, actualId = _PCM_GetBuffBarById(id)
    return API, root, cfg, actualId
  end

  local function NotifyAndRebuildName()
    _PCM_RebuildBuffBarsRuntime()
    _PCM_ACD_NotifyPCM("bb:" .. tostring(id))
  end

  local function IsDuration()
    local API, root, cfg = GetCfg()
    return cfg and cfg.kind == "duration"
  end

  local function IsButtonTracker()
    local _, _, cfg = GetCfg()
    return cfg and cfg.presentation == "BUTTON" or false
  end

  local function GetStackColorThresholds()
    local _, _, cfg = GetCfg()
    if not cfg or cfg.kind == "duration" then
      return nil, cfg
    end

    return AuraWidget.EnsureStackColorThresholds(cfg), cfg
  end

  local function GetStackColorThreshold(index)
    local thresholds, cfg = GetStackColorThresholds()
    return thresholds and thresholds[index], cfg
  end

  local function RefreshStackColors(rebuildOptions)
    local API, _, cfg, actualId = GetCfg()
    if cfg then
      API.RefreshCustomBarStyle(actualId)
      ns.PCMCustomIcons:FlushAuraStyles()
    end
    _PCM_RefreshPreview()

    if rebuildOptions then
      _PCM_ACD_NotifyPCM("bb:" .. tostring(id))
    end
  end

  local function BuildStackColorThresholdGroup(index)
    local threshold = GetStackColorThreshold(index)

    return {
      type = "group",
      name = "Stack color shift " .. index,
      order = index,
      inline = true,
      hidden = IsDuration,
      args = {
        enabled = {
          type = "toggle",
          name = "Enable",
          order = 1,
          get = function()
            return threshold and threshold.enabled == true or false
          end,
          set = function(_, value)
            if not threshold then return end
            threshold.enabled = value and true or false
            RefreshStackColors(false)
          end,
        },
        value = {
          type = "range",
          name = "Start at stack",
          order = 2,
          min = 1,
          max = 30,
          step = 1,
          disabled = function()
            return not threshold or threshold.enabled ~= true
          end,
          get = function()
            return threshold and threshold.value or 1
          end,
          set = function(_, value)
            local _, cfg = GetStackColorThresholds()
            if not threshold or not cfg then return end
            threshold.value = value
            AuraWidget.EnsureStackColorThresholds(cfg)
            RefreshStackColors(true)
          end,
        },
        colorMode = {
          type = "select",
          name = "Color",
          order = 3,
          values = STACK_THRESHOLD_COLOR_VALUES,
          disabled = function()
            return not threshold or threshold.enabled ~= true
          end,
          get = function()
            return threshold and threshold.colorMode or "CUSTOM"
          end,
          set = function(_, value)
            if not threshold then return end
            threshold.colorMode = value == "CLASS" and "CLASS" or "CUSTOM"
            RefreshStackColors(false)
          end,
        },
        customColor = {
          type = "color",
          name = "Custom color",
          order = 4,
          hasAlpha = true,
          disabled = function()
            local threshold = GetStackColorThreshold(index)
            return not threshold
              or threshold.enabled ~= true
              or threshold.colorMode ~= "CUSTOM"
          end,
          get = function()
            local color = threshold and threshold.color or { 1, 1, 1, 1 }
            return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
          end,
          set = function(_, r, g, b, a)
            if not threshold then return end
            threshold.color = { r, g, b, a }
            threshold.colorMode = "CUSTOM"
            RefreshStackColors(false)
          end,
        },
        delete = {
          type = "execute",
          name = "Delete shift",
          order = 5,
          func = function()
            local _, cfg = GetStackColorThresholds()
            if cfg and AuraWidget.RemoveStackColorThreshold(cfg, index) then
              RefreshStackColors(true)
            end
          end,
        },
      },
    }
  end

  local function BuildStackColorThresholdArgs()
    local thresholds, cfg = GetStackColorThresholds()
    local thresholdArgs = {}
    if not thresholds or not cfg then
      return thresholdArgs
    end

    for index = 1, #thresholds do
      thresholdArgs["shift" .. index] = BuildStackColorThresholdGroup(index)
    end

    thresholdArgs.add = {
      type = "execute",
      name = "Add stack color shift",
      order = #thresholds + 1,
      disabled = #thresholds >= 30,
      func = function()
        if AuraWidget.AddStackColorThreshold(cfg, 30) then
          RefreshStackColors(true)
        end
      end,
    }

    return thresholdArgs
  end

  args.enabled = {
    type = "toggle",
    name = "Enable tracker",
    order = 1,

    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.enabled ~= false or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.enabled = not not v
      NotifyAndRebuildName()
    end,
  }

  args.deleteBar = {
    type = "execute",
    name = "Delete tracker",
    order = 3,

    confirm = true,
    confirmText = "Delete this aura tracker?",
    func = function()
      local API, root, cfg, actualId = GetCfg()
      wipe(_PCMValueCache)

      API.DeleteCustomBar(actualId)

      _PCM_ACD_NotifyPCM(nil)
    end,
  }

  args.specializationSpells = _PCM_BuildSpecializationSpellGroup(
    GetCfg,
    function()
      return _PCM_GetCustomBarSpellList("aura")
    end,
    NotifyAndRebuildName,
    15
  )

  args.auraTrackMode = {
    type = "select",
    name = "Aura type",
    order = 10.5,
    values = {
      player_buff = "Buff",
      target_debuff = "Debuff",
    },
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.auraTrackMode == "target_debuff" and "target_debuff" or "player_buff"
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end

      cfg.auraTrackMode = v == "target_debuff" and "target_debuff" or "player_buff"
      NotifyAndRebuildName()
    end,
  }

  args.maxStacks = {
    type = "range",
    name = "Max stacks (segments)",
    order = 11,
    min = 1,
    max = 30,
    step = 1,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and math.max(1, math.min(30, tonumber(cfg.maxStacks) or 3)) or 3
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.maxStacks = math.max(1, math.min(30, tonumber(v) or 3))
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.hideViewerIcon = {
    type = "toggle",
    name = "Hide buff icon",
    order = 12,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.hideViewerIcon == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.hideViewerIcon = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationHideIconFrame = {
    type = "toggle",
    name = "Show icon",
    order = 12,

    hidden = function()
      return not IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.durationHideIconFrame ~= true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationHideIconFrame = v ~= true
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.showOnlyWhenActive = {
    type = "toggle",
    name = "Show only when active",
    order = 13,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.showOnlyWhenActive == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showOnlyWhenActive = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.showSpellIconNextToBar = {
    type = "toggle",
    name = "Show icon beside bar",
    order = 13,
    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.showSpellIconNextToBar == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showSpellIconNextToBar = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.hideOutOfCombat = {
    type = "toggle",
    name = "Hide out of combat",
    order = 14,

    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.hideOutOfCombat == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.hideOutOfCombat = not not v
      if cfg.outOfCombatAlpha == nil then
        cfg.outOfCombatAlpha = 0
      end
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.outOfCombatAlpha = {
    type = "range",
    name = "Out-of-combat opacity",
    order = 15,
    min = 0,
    max = 100,
    step = 1,

    disabled = function()
      local API, root, cfg = GetCfg()
      return not (cfg and cfg.hideOutOfCombat == true)
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and (tonumber(cfg.outOfCombatAlpha) or 0) or 0
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      v = tonumber(v) or 0
      if v < 0 then v = 0 end
      if v > 100 then v = 100 end
      cfg.outOfCombatAlpha = v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.width = {
    type = "range",
    name = "Total width",
    order = 20,
    min = 50,
    max = 600,
    step = 1,

    get = function()
      local API, root, cfg = GetCfg()
      local fallback = IsDuration() and 200 or 180
      return cfg and (tonumber(cfg.width) or fallback) or fallback
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.width = tonumber(v) or cfg.width
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.height = {
    type = "range",
    name = "Bar height",
    order = 21,
    min = 5,
    max = 80,
    step = 1,

    get = function()
      local API, root, cfg = GetCfg()
      local fallback = IsDuration() and 20 or 10
      return cfg and (tonumber(cfg.height) or fallback) or fallback
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.height = tonumber(v) or cfg.height
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.barTexture = {
    type = "select",
    name = "Bar texture",
    order = 22,

    values = function()
      return OptionsUtil.BuildStatusbarValues(true, "Use theme default", "")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      if not cfg then return "" end
      if cfg.kind == "duration" then
        return cfg.durationTexture or ""
      end
      return cfg.stackTexture or ""
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      if cfg.kind == "duration" then
        cfg.durationTexture = (key ~= "") and key or nil
      else
        cfg.stackTexture = (key ~= "") and key or nil
      end
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.orientation = {
    type = "select",
    name = "Orientation",
    order = 30,

    values = {
      horizontal = "Horizontal",
      vertical = "Vertical",
    },
    get = function()
      local API, root, cfg = GetCfg()
      return (cfg and cfg.orientation == "vertical") and "vertical" or "horizontal"
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.orientation = (key == "vertical") and "vertical" or "horizontal"
      cfg.fillDirection = (cfg.orientation == "vertical") and "UP" or "RIGHT"
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.barMode = {
    type = "select",
    name = "Bar mode",
    order = 31,
    hidden = function()
      return not IsDuration()
    end,
    values = {
      fill = "Fill",
      drain = "Drain",
    },
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.durationBarFillMode == "fill" and "fill" or "drain"
    end,
    set = function(_, value)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationBarFillMode = value == "fill" and "fill" or "drain"
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.fillDirection = {
    type = "select",
    name = "Direction",
    order = 32,
    values = function()
      local API, root, cfg = GetCfg()
      if cfg and cfg.orientation == "vertical" then
        return { UP = "Up", DOWN = "Down" }
      end
      return { RIGHT = "Right", LEFT = "Left" }
    end,
    get = function()
      local API, root, cfg = GetCfg()
      if not cfg then return "RIGHT" end
      return tostring(cfg.fillDirection or ((cfg.orientation == "vertical") and "UP" or "RIGHT"))
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fillDirection = tostring(key or "")
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.useClassColor = {
    type = "toggle",
    name = "Use class color",
    order = 40,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.useClassColor ~= false or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.useClassColor = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.barColor = {
    type = "color",
    name = "Custom bar color",
    order = 41,
    hasAlpha = true,

    hidden = function()
      return IsDuration()
    end,
    disabled = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.useClassColor ~= false or false
    end,
    get = function()
      local API, root, cfg = GetCfg()
      local c = cfg and cfg.barColor or nil
      local r, g, b, a = 1, 1, 1, 1
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.barColor = { r, g, b, a or 1 }
      cfg.useClassColor = false
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.borderSize = {
    type = "range",
    name = "Border size",
    order = 50,
    min = 0,
    max = 12,
    step = 1,

    get = function()
      local API, root, cfg = GetCfg()
      local fallback = IsDuration() and 2 or 2
      return cfg and (tonumber(cfg.borderSize) or fallback) or fallback
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.borderSize = tonumber(v) or cfg.borderSize
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.borderColor = {
    type = "color",
    name = "Border color",
    order = 51,
    hasAlpha = true,

    get = function()
      local API, root, cfg = GetCfg()
      local c = cfg and cfg.borderColor or nil
      local r, g, b, a = 0.20, 0.20, 0.20, 1.00
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.borderColor = { r, g, b, a or 1 }
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.backgroundColor = {
    type = "color",
    name = "Background color",
    order = 52,
    hasAlpha = true,

    hidden = function()
      return not IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      local c = cfg and cfg.backgroundColor or nil
      local r, g, b, a = 0.12, 0.12, 0.12, 0.95
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.backgroundColor = { r, g, b, a or 1 }
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.showText = {
    type = "toggle",
    name = "Show text",
    order = 59,

    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.showText ~= false or false
    end,
    set = function(_, value)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showText = value == true
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.fontSize = {
    type = "range",
    name = "Font size",
    order = 60,
    min = 0,
    max = 32,
    step = 1,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.fontSize) or 14) or 14
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontSize = tonumber(v) or 14
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.fontOffsetX = {
    type = "range",
    name = "Charge font offset X",
    order = 61,
    min = -50,
    max = 50,
    step = 1,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.fontOffsetX) or 0) or 0
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontOffsetX = tonumber(v) or 0
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.fontOffsetY = {
    type = "range",
    name = "Charge font offset Y",
    order = 62,
    min = -50,
    max = 50,
    step = 1,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.fontOffsetY) or 0) or 0
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.fontOffsetY = tonumber(v) or 0
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.font = {
    type = "select",
    dialogControl = "LSM30_Font",
    name = "Font",
    order = 63,
    values = function()
      return OptionsUtil.BuildFontValues(false, "Use theme default", "")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      if not cfg then return "FiraSans Heavy" end
      if cfg.kind == "duration" then
        return OptionsUtil.ResolveFontKey(cfg.durationFont)
      end
      return OptionsUtil.ResolveFontKey(cfg.font)
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      if cfg.kind == "duration" then
        cfg.durationFont = (key ~= "") and key or nil
      else
        cfg.font = (key ~= "") and key or nil
      end
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.outline = {
    type = "select",
    name = "Font outline",
    order = 64,
    values = function()
      return OptionsUtil.BuildOutlineValues(true, "Use theme default", "")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      if not cfg then return "" end
      if cfg.kind == "duration" then
        return cfg.durationOutline or ""
      end
      return cfg.outline or ""
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      if cfg.kind == "duration" then
        cfg.durationOutline = (key ~= "") and key or nil
      else
        cfg.outline = (key ~= "") and key or nil
      end
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.showDuration = {
    type = "toggle",
    name = "Enable indicator",
    order = 70,

    hidden = function()
      return IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.showDuration == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.showDuration = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationAnchor = {
    type = "select",
    name = "Indicator position",
    order = 71,
    hidden = function()
      return IsDuration() or not (select(3, GetCfg()) and select(3, GetCfg()).showDuration == true)
    end,
    values = {
      ["TOP"] = "Bar above",
      ["BOTTOM"] = "Bar below",
      ["LEFT"] = "Icon left",
      ["RIGHT"] = "Icon right",
    },
    get = function()
      local API, root, cfg = GetCfg()
      return tostring((cfg and cfg.durationAnchor) or "BOTTOM"):upper()
    end,
    set = function(_, key)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationAnchor = tostring(key or "BOTTOM"):upper()
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationGap = {
    type = "range",
    name = "Gap",
    order = 72,
    min = 0,
    max = 20,
    step = 1,

    hidden = function()
      if IsDuration() then
        return false
      end
      local API, root, cfg = GetCfg()
      return not (cfg and cfg.showDuration == true)
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.durationGap) or 2) or 2
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationGap = tonumber(v) or 2
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.hideDurationWhenMissing = {
    type = "toggle",
    name = "Hide when inactive",
    order = 73,
    hidden = function()
      if IsDuration() then
        return false
      end
      local API, root, cfg = GetCfg()
      return not (cfg and cfg.showDuration == true)
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.hideDurationWhenMissing ~= false or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.hideDurationWhenMissing = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationHeight = {
    type = "range",
    name = "Bar height",
    order = 74,
    min = 2,
    max = 40,
    step = 1,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.durationHeight) or 10) or 10
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationHeight = tonumber(v) or 10
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationBarColor = {
    type = "color",
    name = "Bar color",
    order = 75,
    hasAlpha = true,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      local c = cfg and cfg.durationBarColor or nil
      local r, g, b, a = 1, 1, 1, 1
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationBarColor = { r, g, b, a or 1 }
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationIconSize = {
    type = "range",
    name = "Icon size",
    order = 76,
    min = 8,
    max = 86,
    step = 1,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return not (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return not (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      local fallback = cfg and (tonumber(cfg.height) or 10) or 10
      return tonumber((cfg and cfg.durationIconSize) or fallback) or fallback
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationIconSize = tonumber(v) or cfg.durationIconSize
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationIconBorderSize = {
    type = "range",
    name = "Icon border size",
    order = 77,
    min = 0,
    max = 12,
    step = 1,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return not (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return not (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.durationIconBorderSize) or 0) or 0
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationIconBorderSize = tonumber(v) or 0
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationIconBorderColor = {
    type = "color",
    name = "Icon border color",
    order = 78,
    hasAlpha = true,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return not (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return not (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      local c = cfg and cfg.durationIconBorderColor or nil
      local r, g, b, a = 0.20, 0.20, 0.20, 1.00
      if type(c) == "table" then
        r = tonumber(c[1]) or tonumber(c.r) or r
        g = tonumber(c[2]) or tonumber(c.g) or g
        b = tonumber(c[3]) or tonumber(c.b) or b
        a = tonumber(c[4]) or tonumber(c.a) or a
      end
      return r, g, b, a
    end,
    set = function(_, r, g, b, a)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationIconBorderColor = { r, g, b, a or 1 }
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationHideSpellIcon = {
    type = "toggle",
    name = "Hide spell icon",
    order = 79,

    hidden = function()
      local API, root, cfg = GetCfg()
      if not cfg then return true end

      if cfg.kind == "duration" then
        local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
        return not (anchor == "LEFT" or anchor == "RIGHT")
      end

      if cfg.showDuration ~= true then
        return true
      end

      local anchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
      return not (anchor == "LEFT" or anchor == "RIGHT")
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return cfg and cfg.durationHideSpellIcon == true or false
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationHideSpellIcon = not not v
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  args.durationCountFontSize = {
    type = "range",
    name = "Font size",
    order = 80,
    min = 0,
    max = 32,
    step = 1,

    hidden = function()
      return not IsDuration()
    end,
    get = function()
      local API, root, cfg = GetCfg()
      return tonumber((cfg and cfg.durationCountFontSize) or 0) or 0
    end,
    set = function(_, v)
      local API, root, cfg = GetCfg()
      if not cfg then return end
      cfg.durationCountFontSize = tonumber(v) or 0
      _PCM_RebuildBuffBarsRuntime()
    end,
  }

  return {
    general = {
      type = "group",
      name = "General",
      order = 10,
      inline = true,
      args = {
        enabled = args.enabled,
        auraTrackMode = args.auraTrackMode,
        maxStacks = args.maxStacks,
        hideViewerIcon = args.hideViewerIcon,
        deleteBar = args.deleteBar,
      },
    },
    specializationSpells = args.specializationSpells,
    icon = _PCM_BuildCustomIconGroup(GetCfg, _PCM_RebuildBuffBarsRuntime, select(3, GetCfg()).kind, 15),
    visibility = {
      type = "group",
      name = "Visibility",
      order = 20,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showOnlyWhenActive = args.showOnlyWhenActive,
        showSpellIconNextToBar = args.showSpellIconNextToBar,
        hideOutOfCombat = args.hideOutOfCombat,
        outOfCombatAlpha = args.outOfCombatAlpha,
      },
    },
    barLayout = {
      type = "group",
      name = "Bar Size & Layout",
      order = 30,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        width = args.width,
        height = args.height,
        barTexture = args.barTexture,
        orientation = args.orientation,
        barMode = args.barMode,
        fillDirection = args.fillDirection,
      },
    },
    barDesign = {
      type = "group",
      name = "Bar Design",
      order = 40,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        useClassColor = args.useClassColor,
        barColor = args.barColor,
        borderSize = args.borderSize,
        borderColor = args.borderColor,
        backgroundColor = args.backgroundColor,
      },
    },
    stackColors = {
      type = "group",
      name = "Stack color shifts",
      order = 45,
      inline = true,
      hidden = IsDuration,
      args = BuildStackColorThresholdArgs(),
    },
    whenActive = _PCM_BuildCustomBarBuffGlowGroup(
      GetCfg,
      _PCM_RebuildBuffBarsRuntime,
      "buff:" .. tostring(id),
      50
    ),
    fontSettings = {
      type = "group",
      name = "Font Settings",
      order = 60,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showText = args.showText,
        fontSize = args.fontSize,
        fontOffsetX = args.fontOffsetX,
        fontOffsetY = args.fontOffsetY,
        font = args.font,
        outline = args.outline,
      },
    },
    duration = {
      type = "group",
      name = "Duration indicator",
      order = 70,
      inline = true,
      hidden = IsButtonTracker,
      args = {
        showDuration = args.showDuration,
        durationHideIconFrame = args.durationHideIconFrame,
        durationAnchor = args.durationAnchor,
        durationGap = args.durationGap,
        hideDurationWhenMissing = args.hideDurationWhenMissing,
        durationHeight = args.durationHeight,
        durationBarColor = args.durationBarColor,
        durationIconSize = args.durationIconSize,
        durationIconBorderSize = args.durationIconBorderSize,
        durationIconBorderColor = args.durationIconBorderColor,
        durationHideSpellIcon = args.durationHideSpellIcon,
        durationCountFontSize = args.durationCountFontSize,
      },
    },
  }
end


local function _PCM_IsSpellBarLoaded(cfg)
  if type(cfg) ~= "table" or cfg.enabled == false then
    return false
  end

  Cooldowns:NormalizeSpecAssignments(cfg)

  local spellID = Cooldowns:GetTrackedSpellIDForCurrentSpec(cfg)
  if not spellID then
    return false
  end

  if cfg.forceShow == true then
    return true
  end

  return Cooldowns:DoesPlayerKnowSavedSpell(spellID) == true
end

local function _PCM_IsChargeCooldownBarLoaded(cfg)
  if type(cfg) ~= "table" or cfg.enabled == false then
    return false
  end

  Cooldowns:NormalizeSpecAssignments(cfg)

  local spellID = Cooldowns:GetTrackedSpellIDForCurrentSpec(cfg)
  if not spellID then
    return false
  end

  return Cooldowns:DoesPlayerKnowSavedSpell(spellID, true) == true
end

local function _PCM_IsBuffBarLoaded(cfg)
  if type(cfg) ~= "table" or cfg.enabled == false then
    return false
  end

  Cooldowns:NormalizeSpecAssignments(cfg)
  return ns.Modules.PCM_BB.IsTrackedSpellAvailable(cfg) == true
end

local function _PCM_SortedCustomBarIds(root)
  local ids = {}
  for id in pairs(root or {}) do
    if type(id) == "number" or type(id) == "string" then
      ids[#ids + 1] = id
    end
  end

  table.sort(ids, function(a, b)
    local ea = root[a]
    local eb = root[b]
    local la = Cooldowns:GetCustomBarDisplayName(ea)
    local lb = Cooldowns:GetCustomBarDisplayName(eb)
    if la == lb then
      return tostring(a) < tostring(b)
    end
    return la < lb
  end)

  return ids
end


_PCM_BuildCustomBarsTreeNodes = function()
  local out = {}
  local unavailableArgs = {
    help = {
      type = "description",
      name = "These trackers are disabled, unavailable in the current specialization, or not enabled for this specialization.",
      order = 1,
    },
  }

  local _, _, spellRoot, chargeRoot, stackRoot = _PCM_GetCustomBarsRootLists()

  local loadedOrder = 2
  local unavailableOrder = 2
  local unavailableCount = 0

  local function AddNode(kind, id, cfg, loaded, buildArgs)
    local key = kind .. ":" .. tostring(id)
    local name = _PCM_GetCustomBarNodeLabel(kind, id, cfg)

    if not loaded then
      name = "|cff808080" .. name .. "|r"
    end

    local nodeArgs = buildArgs(id)

    local node = {
      type = "group",
      name = name,
      args = nodeArgs,
    }

    if loaded then
      node.order = loadedOrder
      loadedOrder = loadedOrder + 1
      out[key] = node
    else
      node.order = unavailableOrder
      unavailableOrder = unavailableOrder + 1
      unavailableArgs[key] = node
      unavailableCount = unavailableCount + 1
    end
  end

  for _, id in ipairs(_PCM_SortedCustomBarIds(spellRoot)) do
    AddNode("spell", id, spellRoot[id], _PCM_IsSpellBarLoaded(spellRoot[id]), _PCM_BuildSpellBarLeafArgs)
  end

  for _, id in ipairs(_PCM_SortedCustomBarIds(chargeRoot)) do
    AddNode("chargeSpell", id, chargeRoot[id], _PCM_IsChargeCooldownBarLoaded(chargeRoot[id]), _PCM_BuildChargeCooldownBarLeafArgs)
  end

  for _, id in ipairs(_PCM_SortedCustomBarIds(stackRoot)) do
    AddNode("bb", id, stackRoot[id], _PCM_IsBuffBarLoaded(stackRoot[id]), _PCM_BuildBuffBarLeafArgs)
  end

  if unavailableCount > 0 then
    out.__disabledNotLoaded = {
      type = "group",
      name = "Unavailable trackers",
      order = loadedOrder,
      childGroups = "tree",
      args = unavailableArgs,
    }
  end

  if loadedOrder == 2 and unavailableCount == 0 then
    out.__empty = {
      type = "group",
      name = "No custom trackers yet",
      order = 1,
      args = {
        help = {
          type = "description",
          name = "Click Create custom tracker to begin.",
          order = 1,
        },
      },
    }
  end

  return out
end

_PCM_RefreshCustomBarsOptionsTree = function()
  wipe(_PCMValueCache)
  Addon:InvalidateOptionsRender("CooldownManager")
end

function ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange()
  local activePath = ns._PUIActiveOptionsPath
  if type(activePath) ~= "table"
    or activePath[1] ~= "CooldownManager"
    or activePath[2] ~= "custom_bars"
  then
    _PCM_RefreshCustomBarsOptionsTree()
    _PCM_RefreshPreview()
    return
  end

  local targetKey = activePath[#activePath]
  if targetKey == "custom_bars" or targetKey == "__disabledNotLoaded" then
    targetKey = nil
  end

  _PCM_ACD_NotifyPCM(targetKey)
  _PCM_RefreshPreview()
end

local function _PCM_BuildCustomBarsManagerArgs()
  local args = {}
  local _, API = _PCM_GetCustomBarsRootLists()


  args.create_controls = {
    type = "group",
    name = "Create custom tracker",
    inline = true,
    order = 1,
    args = {
      description = {
        type = "description",
        name = "Build a button or bar in a guided setup with a live state preview.",
        order = 1,
      },
      createButton = {
        type = "execute",
        name = function()
          return ns.PCMCustomTrackerInstaller:HasDraft()
            and "Resume custom tracker" or "Create custom tracker"
        end,
        desc = "Open the guided tracker installer.",
        order = 2,
        width = 1.5,
        func = function()
          ns.PCMCustomTrackerInstaller:Open()
        end,
      },
    },
  }

  local barArgs = _PCM_BuildCustomBarsTreeNodes()
  for key, value in pairs(barArgs) do
    args[key] = value
  end

  return args
end


local function _PCM_GetTabDefinitions()
  return {
    {
      key = "cooldowns_essential",
      label = "Essential cooldowns",
    },
    {
      key = "cooldowns_utility",
      label = "Utility cooldowns",
    },
    {
      key = "consumables",
      label = "Consumables",
    },
    {
      key = "buff_icons",
      label = "Buff icons",
    },
    {
      key = "buff_bars",
      label = "Buff bars",
    },
    {
      key = "custom_bars",
      label = "Custom trackers",
    },
  }
end

local function _PCM_BuildConsumablesTabArgs()
  local function GetCfg()
    return DB.GetConsumableTrackerDB()
  end

  local function Rebuild()
    Cooldowns:ConsumableTracker_Rebuild()
  end

  local function SetSlotOrder(slotKey, value)
    local cfg = GetCfg()
    local slot = cfg.slots[slotKey]
    local newOrder = math.floor(tonumber(value) or slot.order or 1)
    local oldOrder = slot.order

    for otherKey, otherSlot in pairs(cfg.slots) do
      if otherKey ~= slotKey and otherSlot.order == newOrder then
        otherSlot.order = oldOrder
        break
      end
    end

    slot.order = newOrder
    Rebuild()
  end

  local args = {
    general = {
      type = "group",
      name = "Tracker",
      order = 10,
      inline = true,
      args = {
        enabled = {
          type = "toggle",
          name = "Enable tracker",
          order = 1,
          get = function() return GetCfg().enabled == true end,
          set = function(_, value) Cooldowns:SetConsumableTrackerEnabled(value) end,
        },
        combatOnly = {
          type = "toggle",
          name = "Only show in combat",
          order = 2,
          get = function() return GetCfg().combatOnly == true end,
          set = function(_, value) GetCfg().combatOnly = value == true Rebuild() end,
        },
        countVisibility = {
          type = "select",
          name = "Show counts",
          order = 3,
          values = {
            ALWAYS = "Always",
            OOC = "Out of combat",
            NEVER = "Never",
          },
          get = function() return GetCfg().countVisibility end,
          set = function(_, value) GetCfg().countVisibility = value Rebuild() end,
        },
        showItemQuality = {
          type = "toggle",
          name = "Show item quality",
          desc = "Show the crafted quality rank on tracked potions.",
          order = 4,
          get = function() return GetCfg().showItemQuality == true end,
          set = function(_, value) GetCfg().showItemQuality = value == true Rebuild() end,
        },
        showKeybinds = {
          type = "toggle",
          name = "Show keybinds",
          order = 5,
          get = function() return GetCfg().showKeybinds == true end,
          set = function(_, value)
            GetCfg().showKeybinds = value == true
            Cooldowns:_Keybinds_Enable()
            Rebuild()
          end,
        },
        showTooltips = {
          type = "toggle",
          name = "Show tooltips",
          order = 6,
          get = function() return GetCfg().showTooltips == true end,
          set = function(_, value) GetCfg().showTooltips = value == true Rebuild() end,
        },
        showCooldownText = {
          type = "toggle",
          name = "Show cooldown countdown",
          order = 7,
          get = function() return GetCfg().showCooldownText == true end,
          set = function(_, value) GetCfg().showCooldownText = value == true Rebuild() end,
        },
      },
    },
    trinkets = {
      type = "group",
      name = "Trinkets and potions",
      order = 15,
      inline = true,
      args = {
        onlyOnUseTrinkets = {
          type = "toggle",
          name = "Only show on-use trinkets",
          desc = "Hide passive and proc trinkets.",
          order = 1,
          get = function() return GetCfg().onlyOnUseTrinkets == true end,
          set = function(_, value) GetCfg().onlyOnUseTrinkets = value == true Rebuild() end,
        },
        showDurationSwipe = {
          type = "toggle",
          name = "Show duration swipe",
          desc = "Show active trinket and potion effects over the normal cooldown.",
          order = 2,
          get = function() return GetCfg().showDurationSwipe == true end,
          set = function(_, value) GetCfg().showDurationSwipe = value == true Rebuild() end,
        },
        glowDuringDurationSwipe = {
          type = "toggle",
          name = "Glow during duration swipe",
          desc = "Glow while the duration swipe is active.",
          order = 3,
          disabled = function() return GetCfg().showDurationSwipe ~= true end,
          get = function() return GetCfg().glowDuringDurationSwipe == true end,
          set = function(_, value) GetCfg().glowDuringDurationSwipe = value == true Rebuild() end,
        },
      },
    },
    layout = {
      type = "group",
      name = "Layout",
      order = 20,
      inline = true,
      args = {
        iconSize = {
          type = "range",
          name = "Icon size",
          order = 1,
          min = 16,
          max = 86,
          step = 1,
          get = function() return GetCfg().iconSize end,
          set = function(_, value) GetCfg().iconSize = math.floor(value + 0.5) Rebuild() end,
        },
        spacing = {
          type = "range",
          name = "Spacing",
          order = 2,
          min = 0,
          max = 16,
          step = 1,
          get = function() return GetCfg().spacing end,
          set = function(_, value) GetCfg().spacing = math.floor(value + 0.5) Rebuild() end,
        },
        orientation = {
          type = "select",
          name = "Orientation",
          order = 3,
          values = { HORIZONTAL = "Horizontal", VERTICAL = "Vertical" },
          get = function() return GetCfg().orientation end,
          set = function(_, value)
            local cfg = GetCfg()
            cfg.orientation = value
            cfg.growth = value == "VERTICAL" and "DOWN" or "RIGHT"
            Rebuild()
          end,
        },
        growth = {
          type = "select",
          name = "Growth direction",
          order = 4,
          values = function()
            if GetCfg().orientation == "VERTICAL" then
              return { DOWN = "Down", UP = "Up" }
            end
            return { RIGHT = "Right", LEFT = "Left", CENTER = "Center" }
          end,
          get = function() return GetCfg().growth end,
          set = function(_, value) GetCfg().growth = value Rebuild() end,
        },
        wrap = {
          type = "range",
          name = "Icons per row or column",
          order = 5,
          min = 1,
          max = 8,
          step = 1,
          get = function() return GetCfg().wrap end,
          set = function(_, value) GetCfg().wrap = math.floor(value + 0.5) Rebuild() end,
        },
      },
    },
    appearance = {
      type = "group",
      name = "Appearance",
      order = 30,
      inline = true,
      args = {
        missingAlpha = {
          type = "range",
          name = "Unavailable opacity",
          order = 1,
          min = 0,
          max = 1,
          step = 0.05,
          isPercent = true,
          get = function() return GetCfg().missingAlpha end,
          set = function(_, value) GetCfg().missingAlpha = value Rebuild() end,
        },
        borderSize = {
          type = "range",
          name = "Border size",
          order = 2,
          min = 0,
          max = 8,
          step = 1,
          get = function() return GetCfg().borderSize end,
          set = function(_, value) GetCfg().borderSize = math.floor(value + 0.5) Rebuild() end,
        },
        backgroundColor = {
          type = "color",
          name = "Background color",
          order = 3,
          hasAlpha = true,
          get = function() return unpack(GetCfg().backgroundColor) end,
          set = function(_, r, g, b, a) GetCfg().backgroundColor = { r, g, b, a } Rebuild() end,
        },
        borderColor = {
          type = "color",
          name = "Border color",
          order = 4,
          hasAlpha = true,
          get = function() return unpack(GetCfg().borderColor) end,
          set = function(_, r, g, b, a) GetCfg().borderColor = { r, g, b, a } Rebuild() end,
        },
        font = {
          type = "select",
          dialogControl = "LSM30_Font",
          name = "Font",
          order = 5,
          values = function() return OptionsUtil.BuildFontValues(false) end,
          get = function() return GetCfg().font end,
          set = function(_, value) GetCfg().font = value Rebuild() end,
        },
        cooldownFontSize = {
          type = "range",
          name = "Cooldown font size",
          order = 6,
          min = 6,
          max = 24,
          step = 1,
          get = function() return GetCfg().cooldownFontSize end,
          set = function(_, value) GetCfg().cooldownFontSize = math.floor(value + 0.5) Rebuild() end,
        },
        countFontSize = {
          type = "range",
          name = "Count font size",
          order = 7,
          min = 6,
          max = 24,
          step = 1,
          get = function() return GetCfg().countFontSize end,
          set = function(_, value) GetCfg().countFontSize = math.floor(value + 0.5) Rebuild() end,
        },
        keybindFontSize = {
          type = "range",
          name = "Keybind font size",
          order = 8,
          min = 6,
          max = 24,
          step = 1,
          get = function() return GetCfg().keybindFontSize end,
          set = function(_, value) GetCfg().keybindFontSize = math.floor(value + 0.5) Rebuild() end,
        },
      },
    },
    slots = {
      type = "group",
      name = "Tracked abilities and items",
      order = 40,
      inline = true,
      args = {},
    },
  }

  local definitions = Cooldowns:GetConsumableTrackerDefinitions()
  local function BuildSlotArgs(definition, index)
    local slotKey = definition.key
    return {
      type = "group",
      name = definition.label,
      order = index,
      inline = true,
      args = {
        enabled = {
          type = "toggle",
          name = "Enabled",
          order = 1,
          get = function() return GetCfg().slots[slotKey].enabled ~= false end,
          set = function(_, value) GetCfg().slots[slotKey].enabled = value == true Rebuild() end,
        },
        missing = {
          type = "select",
          name = "When unavailable",
          order = 2,
          values = { GRAY = "Gray", HIDE = "Hide" },
          get = function() return GetCfg().slots[slotKey].missing end,
          set = function(_, value) GetCfg().slots[slotKey].missing = value Rebuild() end,
        },
        order = {
          type = "range",
          name = "Order",
          order = 3,
          min = 1,
          max = #definitions,
          step = 1,
          get = function() return GetCfg().slots[slotKey].order end,
          set = function(_, value) SetSlotOrder(slotKey, value) end,
        },
      },
    }
  end

  for index = 1, #definitions do
    local definition = definitions[index]
    args.slots.args[definition.key] = BuildSlotArgs(definition, index)
  end

  return args
end

local function _PCM_GetTopTabArgs(tabKey)
  if tabKey == "cooldowns_essential" then
    return _PCM_BuildEssentialTabArgs()
  elseif tabKey == "cooldowns_utility" then
    return _PCM_BuildCooldownViewerTreeArgs(GetPCMRoot(), "UtilityCooldownViewer", "Utility", {
      effectsKey = "utility",
      fontLabelPrefix = "Utility",
      splitFonts = true,
      showIconBorder = true,
    })
  elseif tabKey == "consumables" then
    return _PCM_BuildConsumablesTabArgs()
  elseif tabKey == "buff_icons" then
    return _PCM_BuildBuffIconsTabArgs()
  elseif tabKey == "buff_bars" then
    return _PCM_BuildBuffBarsTabArgs()
  end

  return {}
end

local function _PCM_WrapPreviewRefresh(option)
  if type(option) ~= "table" then
    return
  end

  if type(option.set) == "function" then
    local set = option.set
    option.set = function(...)
      set(...)
      _PCM_RefreshPreview()
    end
  end

  if type(option.func) == "function" then
    local func = option.func
    option.func = function(...)
      func(...)
      _PCM_RefreshPreview()
    end
  end

  if type(option.args) == "table" then
    for _, child in pairs(option.args) do
      _PCM_WrapPreviewRefresh(child)
    end
  end
end

local function PCMOptionsProvider(Addon)
  local provider = {}

  function provider:GetOptions()
    wipe(_PCMValueCache)

    ns.Flags.__puiPCM_OptionsOpen = true

    local activePath = ns._PUIActiveOptionsPath
    local activeTab = type(activePath) == "table" and activePath[1] == "CooldownManager" and activePath[2] or nil
    local lazyBuild = activeTab ~= nil

    local options = {
      type = "group",
      name = "Cooldown Manager",
      childGroups = "tab",
      args = {},
    }

    local order = 1
    for _, info in ipairs(_PCM_GetTabDefinitions()) do
      local buildTab = not lazyBuild or info.key == activeTab
      if info.key == "custom_bars" then
        options.args[info.key] = {
          type = "group",
          name = info.label,
          order = order,
          childGroups = "tree",
          args = buildTab and _PCM_BuildCustomBarsManagerArgs() or {},
        }
      elseif info.key == "cooldowns_essential"
        or info.key == "cooldowns_utility"
        or info.key == "buff_icons"
      then
        options.args[info.key] = {
          type = "group",
          name = info.label,
          order = order,
          childGroups = "tree",
          args = buildTab and _PCM_GetTopTabArgs(info.key) or {},
        }
      else
        options.args[info.key] = {
          type = "group",
          name = info.label,
          order = order,
          args = buildTab and _PCM_GetTopTabArgs(info.key) or {},
        }
      end

      order = order + 1
    end

    _PCM_WrapPreviewRefresh(options)
    return options
  end

  return provider
end

Addon:RegisterOptionsSection("CooldownManager", PCMOptionsProvider, 50, "Cooldown Manager", nil, {
  navDescription = "Cooldown viewers, consumables, buff displays, and custom trackers.",
  pageTitle = "Cooldown Manager",
  pageDescription = "Configure cooldowns, consumables, buff displays, and custom trackers.",
  pageHelp = "100% preview zoom matches the in-game widget size. Click an icon to open its settings.",
  page = {
    previewWidth = 380,
    previewHeight = 360,
    previewAlwaysShown = true,
    buildPreview = ns.PCMPreview.Build,
  },
})

ns.Registry.Options.CooldownManager.dynamicOptions = true



  _PCM_RefreshPreview = P:Def('_PCM_RefreshPreview', _PCM_RefreshPreview)
  _PCM_ConfigRefreshViewers = P:Def('_PCM_ConfigRefreshViewers', _PCM_ConfigRefreshViewers)
  _PCM_ValidateRoot = P:Def('_PCM_ValidateRoot', _PCM_ValidateRoot)
  _PCM_EnsureRootDefaults = P:Def('_PCM_EnsureRootDefaults', _PCM_EnsureRootDefaults)
  GetPCMRoot = P:Def('GetPCMRoot', GetPCMRoot)
  _PCM_EnsureBuffRootDefaults = P:Def('_PCM_EnsureBuffRootDefaults', _PCM_EnsureBuffRootDefaults)
  GetViewerBorderDB = P:Def('GetViewerBorderDB', GetViewerBorderDB)
  _PCM_GetStyleMapNumber = P:Def('_PCM_GetStyleMapNumber', _PCM_GetStyleMapNumber)
  _PCM_SetStyleMapNumber = P:Def('_PCM_SetStyleMapNumber', _PCM_SetStyleMapNumber)
  GetViewerIconSize = P:Def('GetViewerIconSize', GetViewerIconSize)
  SetViewerIconSize = P:Def('SetViewerIconSize', SetViewerIconSize)
  GetViewerIconSpacing = P:Def('GetViewerIconSpacing', GetViewerIconSpacing)
  SetViewerIconSpacing = P:Def('SetViewerIconSpacing', SetViewerIconSpacing)
  GetViewerWidthMode = P:Def('GetViewerWidthMode', GetViewerWidthMode)
  SetViewerWidthMode = P:Def('SetViewerWidthMode', SetViewerWidthMode)
  GetViewerFixedWidth = P:Def('GetViewerFixedWidth', GetViewerFixedWidth)
  SetViewerFixedWidth = P:Def('SetViewerFixedWidth', SetViewerFixedWidth)
  GetViewerIconsPerRow = P:Def('GetViewerIconsPerRow', GetViewerIconsPerRow)
  SetViewerIconsPerRow = P:Def('SetViewerIconsPerRow', SetViewerIconsPerRow)
  GetViewerSwipeDB = P:Def('GetViewerSwipeDB', GetViewerSwipeDB)
  GetViewerFontConfig = P:Def('GetViewerFontConfig', GetViewerFontConfig)
  _PCM_GetFontColorValue = P:Def('_PCM_GetFontColorValue', _PCM_GetFontColorValue)
  _PCM_RefreshBuffIconViewer = P:Def('_PCM_RefreshBuffIconViewer', _PCM_RefreshBuffIconViewer)
  _PCM_BuildBuffIconFontArgs = P:Def('_PCM_BuildBuffIconFontArgs', _PCM_BuildBuffIconFontArgs)
  _PCM_BuildBuffIconsTabArgs = P:Def('_PCM_BuildBuffIconsTabArgs', _PCM_BuildBuffIconsTabArgs)
  _PCM_GetMainBuffBarsRoot = P:Def('_PCM_GetMainBuffBarsRoot', _PCM_GetMainBuffBarsRoot)
  _PCM_BuildCooldownViewerArgs = P:Def('_PCM_BuildCooldownViewerArgs', _PCM_BuildCooldownViewerArgs)
  _PCM_BuildEssentialGlowArgs = P:Def('_PCM_BuildEssentialGlowArgs', _PCM_BuildEssentialGlowArgs)
  _PCM_GetIconFontValues = P:Def('_PCM_GetIconFontValues', _PCM_GetIconFontValues)
  _PCM_GetIconOutlineValues = P:Def('_PCM_GetIconOutlineValues', _PCM_GetIconOutlineValues)
  _PCM_GetIconTriState = P:Def('_PCM_GetIconTriState', _PCM_GetIconTriState)
  _PCM_SetIconTriState = P:Def('_PCM_SetIconTriState', _PCM_SetIconTriState)
  _PCM_GetColorComponents = P:Def('_PCM_GetColorComponents', _PCM_GetColorComponents)
  _PCM_BuildIconTextSettingsArgs = P:Def('_PCM_BuildIconTextSettingsArgs', _PCM_BuildIconTextSettingsArgs)
  _PCM_BuildIconOverrideArgs = P:Def('_PCM_BuildIconOverrideArgs', _PCM_BuildIconOverrideArgs)
  _PCM_BuildIconOverrideTreeArgs = P:Def('_PCM_BuildIconOverrideTreeArgs', _PCM_BuildIconOverrideTreeArgs)
  _PCM_BuildCooldownViewerTreeArgs = P:Def('_PCM_BuildCooldownViewerTreeArgs', _PCM_BuildCooldownViewerTreeArgs)
  _PCM_BuildEssentialTabArgs = P:Def('_PCM_BuildEssentialTabArgs', _PCM_BuildEssentialTabArgs)
  _PCM_BuildBuffBarsTabArgs = P:Def('_PCM_BuildBuffBarsTabArgs', _PCM_BuildBuffBarsTabArgs)
  _PCM_GetNextCustomBarID = P:Def('_PCM_GetNextCustomBarID', _PCM_GetNextCustomBarID)
  _PCM_MakeUniqueCustomBarLabel = P:Def('_PCM_MakeUniqueCustomBarLabel', _PCM_MakeUniqueCustomBarLabel)
  _PCM_GetPlayerClassColor = P:Def('_PCM_GetPlayerClassColor', _PCM_GetPlayerClassColor)
  _PCM_CreateNewSpellBar = P:Def('_PCM_CreateNewSpellBar', _PCM_CreateNewSpellBar)
  _PCM_CreateNewChargeCooldownBar = P:Def('_PCM_CreateNewChargeCooldownBar', _PCM_CreateNewChargeCooldownBar)
  _PCM_GetCustomBarsRootLists = P:Def('_PCM_GetCustomBarsRootLists', _PCM_GetCustomBarsRootLists)
  _PCM_GetCustomBarNodeLabel = P:Def('_PCM_GetCustomBarNodeLabel', _PCM_GetCustomBarNodeLabel)
  _PCM_GetCustomBarsTargetPath = P:Def('_PCM_GetCustomBarsTargetPath', _PCM_GetCustomBarsTargetPath)
  _PCM_ACD_NotifyPCM = P:Def('_PCM_ACD_NotifyPCM', _PCM_ACD_NotifyPCM)
  _PCM_GetSpellBarById = P:Def('_PCM_GetSpellBarById', _PCM_GetSpellBarById)
  _PCM_GetSpecializations = P:Def('_PCM_GetSpecializations', _PCM_GetSpecializations)
  _PCM_GetSpecAssignment = P:Def('_PCM_GetSpecAssignment', _PCM_GetSpecAssignment)
  _PCM_SaveTrackedSpellIdentity = P:Def('_PCM_SaveTrackedSpellIdentity', _PCM_SaveTrackedSpellIdentity)
  _PCM_BuildTrackedSpellDropdown = P:Def('_PCM_BuildTrackedSpellDropdown', _PCM_BuildTrackedSpellDropdown)
  _PCM_IsSpecializationEnabled = P:Def('_PCM_IsSpecializationEnabled', _PCM_IsSpecializationEnabled)
  _PCM_SetSpecializationEnabled = P:Def('_PCM_SetSpecializationEnabled', _PCM_SetSpecializationEnabled)
  _PCM_BuildSpecializationSpellGroup = P:Def('_PCM_BuildSpecializationSpellGroup', _PCM_BuildSpecializationSpellGroup)
  _PCM_GetCustomBarSpellList = P:Def('_PCM_GetCustomBarSpellList', _PCM_GetCustomBarSpellList)
  _PCM_BuildSpellBarLeafArgs = P:Def('_PCM_BuildSpellBarLeafArgs', _PCM_BuildSpellBarLeafArgs)
  _PCM_GetChargeCooldownBarById = P:Def('_PCM_GetChargeCooldownBarById', _PCM_GetChargeCooldownBarById)
  _PCM_BuildChargeCooldownBarLeafArgs = P:Def('_PCM_BuildChargeCooldownBarLeafArgs', _PCM_BuildChargeCooldownBarLeafArgs)
  _PCM_GetBuffBarById = P:Def('_PCM_GetBuffBarById', _PCM_GetBuffBarById)
  _PCM_RebuildBuffBarsRuntime = P:Def('_PCM_RebuildBuffBarsRuntime', _PCM_RebuildBuffBarsRuntime)
  _PCM_BuildCustomBarBuffGlowGroup = P:Def('_PCM_BuildCustomBarBuffGlowGroup', _PCM_BuildCustomBarBuffGlowGroup)
  _PCM_BuildBuffBarLeafArgs = P:Def('_PCM_BuildBuffBarLeafArgs', _PCM_BuildBuffBarLeafArgs)
  _PCM_IsSpellBarLoaded = P:Def('_PCM_IsSpellBarLoaded', _PCM_IsSpellBarLoaded)
  _PCM_IsChargeCooldownBarLoaded = P:Def('_PCM_IsChargeCooldownBarLoaded', _PCM_IsChargeCooldownBarLoaded)
  _PCM_IsBuffBarLoaded = P:Def('_PCM_IsBuffBarLoaded', _PCM_IsBuffBarLoaded)
  Cooldowns.IsSpellBarLoaded = _PCM_IsSpellBarLoaded
  Cooldowns.IsChargeCooldownBarLoaded = _PCM_IsChargeCooldownBarLoaded
  Cooldowns.IsBuffBarLoaded = _PCM_IsBuffBarLoaded
  _PCM_SortedCustomBarIds = P:Def('_PCM_SortedCustomBarIds', _PCM_SortedCustomBarIds)
  _PCM_BuildCustomBarsManagerArgs = P:Def('_PCM_BuildCustomBarsManagerArgs', _PCM_BuildCustomBarsManagerArgs)
  _PCM_GetTabDefinitions = P:Def('_PCM_GetTabDefinitions', _PCM_GetTabDefinitions)
  _PCM_GetTopTabArgs = P:Def('_PCM_GetTopTabArgs', _PCM_GetTopTabArgs)
  _PCM_WrapPreviewRefresh = P:Def('_PCM_WrapPreviewRefresh', _PCM_WrapPreviewRefresh)
  PCMOptionsProvider = P:Def('PCMOptionsProvider', PCMOptionsProvider)
  _PCM_BuildCustomBarsTreeNodes = P:Def('_PCM_BuildCustomBarsTreeNodes', _PCM_BuildCustomBarsTreeNodes)
  _PCM_RefreshCustomBarsOptionsTree = P:Def('_PCM_RefreshCustomBarsOptionsTree', _PCM_RefreshCustomBarsOptionsTree)
  ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange = P:Def('ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange', ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange)

