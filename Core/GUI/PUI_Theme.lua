
local ADDON_NAME, ns = ...

local Addon = ns.Addon
local LSM = ns.LSM
local Pixel = ns.Pixel
local Theme = {
  WidgetSkins = {},
}
ns.Theme = Theme

do
  local function RegisterPleebUIFontAssets()

    local base = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\"

    local fonts = {
      ["Accidental Presidency"]       = base .. "Accidental Presidency.ttf",
      ["ActionMan"]                   = base .. "ActionMan.ttf",
      ["Arheiuhk Bd"]                 = base .. "arheiuhk_bd.ttf",
      ["Carlito Regular"]             = base .. "Carlito-Regular.ttf",
      ["ContinuumMedium"]             = base .. "ContinuumMedium.ttf",
      ["DieDieDie"]                   = base .. "DieDieDie.ttf",
      ["ElMessiri Variable"]          = base .. "ElMessiri-VariableFont_wght.ttf",
      ["Expressway"]                  = base .. "Expressway.ttf",
      ["FiraMono Medium"]             = base .. "FiraMono-Medium.ttf",
      ["FiraSans Heavy"]              = base .. "FiraSans-Heavy.ttf",
      ["FiraSans Medium"]             = base .. "FiraSans-Medium.ttf",
      ["FiraSansCond Heavy"]          = base .. "FiraSansCondensed-Heavy.ttf",
      ["FiraSansCond Medium"]         = base .. "FiraSansCondensed-Medium.ttf",
      ["PleebUI"]                     = base .. "FiraSans-Heavy.ttf",
      ["FORCED SQUARE"]               = base .. "FORCED SQUARE.ttf",
      ["FRIZQT"]                      = base .. "FRIZQT__.TTF",
      ["Gotham Narrow Ultra"]         = base .. "gotham_narrow_ultra.ttf",
      ["HARRYP"]                      = base .. "HARRYP__.TTF",
      ["Homespun"]                    = base .. "Homespun.ttf",
      ["Invisible"]                   = base .. "Invisible.ttf",
      ["Lexend Black"]                = base .. "Lexend-Black.ttf",
      ["Lexend Bold"]                 = base .. "Lexend-Bold.ttf",
      ["Lexend ExtraBold"]            = base .. "Lexend-ExtraBold.ttf",
      ["Lexend ExtraLight"]           = base .. "Lexend-ExtraLight.ttf",
      ["Lexend Light"]                = base .. "Lexend-Light.ttf",
      ["Lexend Medium"]               = base .. "Lexend-Medium.ttf",
      ["Lexend Regular"]              = base .. "Lexend-Regular.ttf",
      ["Lexend SemiBold"]             = base .. "Lexend-SemiBold.ttf",
      ["Lexend Thin"]                 = base .. "Lexend-Thin.ttf",
      ["NotoNaskhArabic Regular"]     = base .. "NotoNaskhArabic-Regular.ttf",
      ["NotoSans Medium"]             = base .. "NotoSans-Medium.otf",
      ["NotoSans Regular"]            = base .. "NotoSans-Regular.otf",
      ["NotoSans SemiCondensed"]      = base .. "NotoSans-SemiCondensed.otf",
      ["Nueva Std Cond"]              = base .. "Nueva Std Cond.ttf",
      ["OpenDyslexic3 Bold"]          = base .. "OpenDyslexic3-Bold.ttf",
      ["OpenDyslexic3 Regular"]       = base .. "OpenDyslexic3-Regular.ttf",
      ["Oswald Regular"]              = base .. "Oswald-Regular.ttf",
      ["PTSansNarrow"]                = base .. "PTSansNarrow.ttf",
      ["PTSansNarrow Bold"]           = base .. "PTSansNarrow-Bold.ttf",
      ["PTSansNarrow Regular"]        = base .. "PTSansNarrow-Regular.ttf",
      ["TrashHand"]                   = base .. "TrashHand.TTF",
      ["Ubuntu Arabic Regular"]       = base .. "Ubuntu Arabic Regular.otf",
      ["Woweucn"]                     = base .. "woweucn.ttf",
    }

    for name, path in pairs(fonts) do
      LSM:Register(LSM.MediaType.FONT, name, path)
    end
  end

  RegisterPleebUIFontAssets()
end

Theme.STANDARD_OUTLINE_KEY = "__PUI_STANDARD_OUTLINE__"

Theme.outlineList = {
  [""] = "None",
  OUTLINE = "Outline",
  THICKOUTLINE = "Thick Outline",
  SHADOWOUTLINE = "Shadow + Outline",
  SHADOWTHICKOUTLINE = "Shadow + Thick Outline",
}

function Theme.GetOutlineList()
  return Theme.outlineList
end

function Theme.NormalizeOutlineFlags(flags)
  if flags == nil then
    return nil
  end

  if flags == "NONE" or flags == "" then
    return ""
  end

  if Theme.outlineList[flags] then
    return flags
  end

  local value = tostring(flags):upper()
  local wantShadow = value:find("^SHADOW") ~= nil
  local base = value:find("THICKOUTLINE") and "THICKOUTLINE" or "OUTLINE"

  if wantShadow then
    return base == "THICKOUTLINE" and "SHADOWTHICKOUTLINE" or "SHADOWOUTLINE"
  end

  return base
end

do
  local function RegisterPleebUIStatusbarAssets()
    local baseStatusbars = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Statusbars\\"

    local bars = {
      ["PUI: Arcane Power"] = baseStatusbars .. "PUI_ArcanePower.tga",
      ["PUI: Chi"] = baseStatusbars .. "PUI_Chi.tga",
      ["PUI: Combo Points"] = baseStatusbars .. "PUI_ComboPoint.tga",
      ["PUI: Runes Blood"] = baseStatusbars .. "PUI_RunesBlood.tga",
      ["PUI: Runes Frost"] = baseStatusbars .. "PUI_RunesFrost.tga",
      ["PUI: Runes Unholy"] = baseStatusbars .. "PUI_RunesUnholy.tga",
      ["PUI: Mana"] = baseStatusbars .. "PUI_Mana.tga",
      ["PUI: Runic"] = baseStatusbars .. "PUI_Runic.tga",
      ["PUI: Focus"] = baseStatusbars .. "PUI_Focus.tga",
      ["Pleebar"] = baseStatusbars .. "Pleebar.tga",
      ["PUI Stripes"] = baseStatusbars .. "Stripes.png",
      ["PUI Thin Stripes"] = baseStatusbars .. "ThinStripes.png",
    }

    for name, path in pairs(bars) do
      LSM:Register(LSM.MediaType.STATUSBAR, name, path)
    end
  end

  RegisterPleebUIStatusbarAssets()
end

Theme.FontRoles = {
  title = {
    size    = 16,
    outline = "OUTLINE",
  },
  nav = {
    size    = 12,
    outline = "OUTLINE",
  },
  header = {
    size    = 14,
    outline = "OUTLINE",
  },
  section = {
    size    = 13,
    outline = "OUTLINE",
  },
  body = {
    size    = 12,
    outline = nil,
  },
  button = {
    size    = 12,
    outline = "OUTLINE",
  },
  checkbox = {
    size    = 12,
    outline = nil,
  },
  tab = {
    size    = 12,
    outline = "OUTLINE",
  },
  cooldown = {
    size    = 12,
    outline = "OUTLINE",
  },
  tiny = {
    size    = 10,
    outline = nil,
  },
}

function Theme.GetFont()
  return Addon:GetMediaDB().iconTextGlobalFont
end

function Theme.GetFontRoleInfo(role)
  return Theme.FontRoles[role]
end

Theme.DefaultColors = Theme.DefaultColors or {
  background = { 0.12, 0.12, 0.16, 0.92 },
  control    = { 0.070, 0.070, 0.090, 0.96 },
  accent     = { 0.20, 0.65, 1.00, 1.00 },
  border     = { 0.20, 0.20, 0.24, 1.00 },
  text       = { 0.96, 0.96, 0.96, 1.00 },

  borderSize = 3,
}

local function _PUI_CopyColor(src)
  return { src[1], src[2], src[3], src[4] }
end

local function _PUI_CopyColorWithAlpha(src, alphaMultiplier)
  return {
    src[1],
    src[2],
    src[3],
    (src[4] or 1) * (alphaMultiplier or 1),
  }
end

local function _PUI_CopyColors(src)
  local out = {}
  for k, v in pairs(src) do
    out[k] = type(v) == "table" and _PUI_CopyColor(v) or v
  end
  return out
end

-- Direct skin settings only.
local _PUI_ThemeColorsCache
local _PUI_ThemeColorsCacheSignature

function Theme.GetColors()
  local sdb = Addon:GetOptionsDB().skin
  local signature = tostring(sdb)
    .. "|" .. tostring(sdb.backgroundColor)
    .. "|" .. tostring(sdb.controlBgColor)
    .. "|" .. tostring(sdb.accentColor)
    .. "|" .. tostring(sdb.borderColor)
    .. "|" .. tostring(sdb.textColor)

  if _PUI_ThemeColorsCache and _PUI_ThemeColorsCacheSignature == signature then
    return _PUI_ThemeColorsCache
  end

  local colors = _PUI_CopyColors(Theme.DefaultColors)

  local function ApplyColorOverride(dstKey, srcKey)
    local src = sdb[srcKey]
    if type(src) == "table" then
      colors[dstKey] = _PUI_CopyColor(src)
    end
  end

  ApplyColorOverride("background", "backgroundColor")
  ApplyColorOverride("control", "controlBgColor")
  ApplyColorOverride("accent", "accentColor")
  ApplyColorOverride("border", "borderColor")
  ApplyColorOverride("text", "textColor")

  colors.mutedText = _PUI_CopyColorWithAlpha(colors.text, 0.72)
  colors.disabledText = _PUI_CopyColorWithAlpha(colors.text, 0.52)
  colors.disabledControl = _PUI_CopyColorWithAlpha(colors.control, 0.45)
  colors.disabledBorder = _PUI_CopyColorWithAlpha(colors.border, 0.45)
  colors.selection = _PUI_CopyColor(colors.accent)

  colors.borderSize = 3

  _PUI_ThemeColorsCache = colors
  _PUI_ThemeColorsCacheSignature = signature

  return colors
end

function Theme.GetBarTexture()
  return LSM:Fetch("statusbar", "Pleebar", true)
end


Theme.FontSizeOffsetRange = {
  min = -5,
  max = 10,
  step = 1,
}

Theme.FontSizeScopes = {
  { key = "general", label = "General UI" },
  { key = "options", label = "Options" },
  { key = "unitFrames", label = "Unit Frames" },
  { key = "actionBars", label = "Action Bars" },
  { key = "cooldownManager", label = "Cooldown Manager" },
  { key = "resourceDisplay", label = "Resource Display" },
  { key = "playerBuffs", label = "Player Buffs" },
  { key = "minimap", label = "Minimap" },
  { key = "qualityOfLife", label = "Quality of Life" },
}

local _PUI_FontSizeOffset = 0
local _PUI_FontSizeScopeEnabled = {
  general = true,
  options = true,
  unitFrames = true,
  actionBars = true,
  cooldownManager = true,
  resourceDisplay = true,
  playerBuffs = true,
  minimap = true,
  qualityOfLife = true,
}

function Theme.RefreshFontSizeOffsetCache()
  local media = Addon:GetMediaDB()
  local range = Theme.FontSizeOffsetRange
  local offset = tonumber(media.fontSizeOffset) or 0

  if offset < range.min then offset = range.min end
  if offset > range.max then offset = range.max end

  _PUI_FontSizeOffset = offset

  local scopes = media.fontSizeScopes
  for index = 1, #Theme.FontSizeScopes do
    local key = Theme.FontSizeScopes[index].key
    _PUI_FontSizeScopeEnabled[key] = scopes[key] ~= false
  end
end

function Theme.ResolveFontSize(baseSize, scope)
  local size = tonumber(baseSize) or 12
  if _PUI_FontSizeScopeEnabled[scope or "general"] ~= false then
    size = size + _PUI_FontSizeOffset
  end

  if size < 1 then size = 1 end
  return size
end

Theme._AppliedFonts = setmetatable({}, { __mode = "k" })

local PUI_CREATED_WIDGET_ROOT_FIELDS = {
  "frame",
  "content",
  "button",
  "button_cover",
  "dropdown",
  "slider",
  "scrollbar",
  "scrollBar",
  "treeframe",
  "border",
  "editbox",
  "editBox",
  "scrollBG",
  "colorSwatch",
  "check",
  "checkbg",
  "highlight",
  "text",
  "label",
  "titletext",
  "lowtext",
  "hightext",
  "bar",
  "soundbutton",
  "msgframe",
  "closebutton",
}

local function _PUI_CopyBackdrop(backdrop)
  if not backdrop then
    return nil
  end

  local copy = {}
  for key, value in pairs(backdrop) do
    if type(value) == "table" then
      local nested = {}
      for nestedKey, nestedValue in pairs(value) do
        nested[nestedKey] = nestedValue
      end
      copy[key] = nested
    else
      copy[key] = value
    end
  end
  return copy
end

local function _PUI_CaptureCreatedWidgetObject(lease, object)
  if not object
    or not object.GetObjectType
    or object.__puiCreatedWidgetChrome == true
    or lease.states[object]
  then
    return
  end

  local state = {
    parent = object:GetParent(),
    width = object:GetWidth(),
    height = object:GetHeight(),
    alpha = object:GetAlpha(),
    shown = object:IsShown(),
    points = {},
  }

  for i = 1, object:GetNumPoints() do
    state.points[i] = { object:GetPoint(i) }
  end

  if object.GetDrawLayer then
    state.drawLayer, state.drawSubLevel = object:GetDrawLayer()
  end

  if object:IsObjectType("Frame") then
    state.frameStrata = object:GetFrameStrata()
    state.frameLevel = object:GetFrameLevel()
    state.mouseEnabled = object:IsMouseEnabled()
    state.hitRectInsets = { object:GetHitRectInsets() }

    if object.IsClampedToScreen then
      state.clampedToScreen = object:IsClampedToScreen()
    end

    if object.IsToplevel then
      state.toplevel = object:IsToplevel()
    end

    if object.GetBackdrop and object.SetBackdrop then
      state.backdrop = _PUI_CopyBackdrop(object:GetBackdrop())
      state.backdropColor = { object:GetBackdropColor() }
      state.backdropBorderColor = { object:GetBackdropBorderColor() }
    end
  end

  if object:IsObjectType("Texture") then
    state.atlas = object:GetAtlas()
    state.texture = object:GetTexture()
    state.texCoord = { object:GetTexCoord() }
    state.vertexColor = { object:GetVertexColor() }
    state.blendMode = object:GetBlendMode()
    state.horizTile = object:GetHorizTile()
    state.vertTile = object:GetVertTile()
  end

  if object.GetFont and object.SetFont then
    state.font = { object:GetFont() }
  end

  if object.GetTextColor and object.SetTextColor then
    state.textColor = { object:GetTextColor() }
  end

  if object.GetJustifyH and object.SetJustifyH then
    state.justifyH = object:GetJustifyH()
  end

  if object.GetJustifyV and object.SetJustifyV then
    state.justifyV = object:GetJustifyV()
  end

  if object.CanWordWrap and object.SetWordWrap then
    state.wordWrap = object:CanWordWrap()
  end

  if object.CanNonSpaceWrap and object.SetNonSpaceWrap then
    state.nonSpaceWrap = object:CanNonSpaceWrap()
  end

  if object.GetShadowColor and object.SetShadowColor then
    state.shadowColor = { object:GetShadowColor() }
  end

  if object.GetShadowOffset and object.SetShadowOffset then
    state.shadowOffset = { object:GetShadowOffset() }
  end

  if object.GetTextInsets and object.SetTextInsets then
    state.textInsets = { object:GetTextInsets() }
  end

  if object:IsObjectType("FontString") then
    state.isFontString = true
    state.text = object:GetText()
  end

  lease.states[object] = state
  lease.objects[#lease.objects + 1] = object
end

local function _PUI_IsOtherAceGUIWidgetFrame(widget, object)
  if not object:IsObjectType("Frame") then
    return false
  end

  local owner = object.obj
  return owner
    and owner ~= widget
    and owner.AceGUIWidgetVersion ~= nil
end

local function _PUI_CaptureCreatedWidgetTree(lease, object)
  if not object
    or not object.GetObjectType
    or object.__puiCreatedWidgetChrome == true
    or lease.treeSeen[object]
    or _PUI_IsOtherAceGUIWidgetFrame(lease.widget, object)
  then
    return
  end

  lease.treeSeen[object] = true
  _PUI_CaptureCreatedWidgetObject(lease, object)

  if not object:IsObjectType("Frame") then
    return
  end

  for _, region in ipairs({ object:GetRegions() }) do
    _PUI_CaptureCreatedWidgetTree(lease, region)
  end

  for _, child in ipairs({ object:GetChildren() }) do
    _PUI_CaptureCreatedWidgetTree(lease, child)
  end
end

function Theme.MarkCreatedWidgetChrome(object)
  object.__puiCreatedWidgetChrome = true
  return object
end

function Theme.CaptureCreatedWidgetFrameTree(widget, object)
  local lease = widget and widget.__puiCreatedWidgetLease
  if not lease or not object or not object.GetObjectType then
    return
  end

  if not lease.rootSeen[object] then
    lease.rootSeen[object] = true
    lease.roots[#lease.roots + 1] = object
  end

  _PUI_CaptureCreatedWidgetTree(lease, object)
end

function Theme.BeginCreatedWidgetLease(widget)
  if widget.__puiCreatedWidgetLease then
    return
  end

  local lease = {
    widget = widget,
    objects = {},
    states = {},
    treeSeen = {},
    roots = {},
    rootSeen = {},
    widgetFields = {
      alignoffset = widget.alignoffset,
      height = widget.height,
      width = widget.width,
    },
  }
  widget.__puiCreatedWidgetLease = lease

  for i = 1, #PUI_CREATED_WIDGET_ROOT_FIELDS do
    Theme.CaptureCreatedWidgetFrameTree(widget, widget[PUI_CREATED_WIDGET_ROOT_FIELDS[i]])
  end
end

local function _PUI_HideCreatedWidgetChrome(widget, object, seen)
  if not object
    or not object.GetObjectType
    or seen[object]
    or _PUI_IsOtherAceGUIWidgetFrame(widget, object)
  then
    return
  end

  seen[object] = true

  if object.__puiCreatedWidgetChrome == true then
    object:Hide()
    return
  end

  if not object:IsObjectType("Frame") then
    return
  end

  for _, region in ipairs({ object:GetRegions() }) do
    _PUI_HideCreatedWidgetChrome(widget, region, seen)
  end

  for _, child in ipairs({ object:GetChildren() }) do
    _PUI_HideCreatedWidgetChrome(widget, child, seen)
  end
end

local function _PUI_RestoreCreatedWidgetObject(object, state)
  object:SetParent(state.parent)
  object:ClearAllPoints()

  for i = 1, #state.points do
    local point = state.points[i]
    Pixel.Point(object, point[1], point[2], point[3], point[4], point[5])
  end

  Pixel.Width(object, state.width)
  Pixel.Height(object, state.height)
  object:SetAlpha(state.alpha)

  if state.drawLayer then
    object:SetDrawLayer(state.drawLayer, state.drawSubLevel)
  end

  if object:IsObjectType("Frame") then
    object:SetFrameStrata(state.frameStrata)
    object:SetFrameLevel(state.frameLevel)
    object:EnableMouse(state.mouseEnabled)
    object:SetHitRectInsets(
      state.hitRectInsets[1],
      state.hitRectInsets[2],
      state.hitRectInsets[3],
      state.hitRectInsets[4]
    )

    if state.clampedToScreen ~= nil then
      object:SetClampedToScreen(state.clampedToScreen)
    end

    if state.toplevel ~= nil then
      object:SetToplevel(state.toplevel)
    end

    if object.GetBackdrop and object.SetBackdrop then
      object:SetBackdrop(_PUI_CopyBackdrop(state.backdrop))

      if state.backdrop then
        object:SetBackdropColor(
          state.backdropColor[1],
          state.backdropColor[2],
          state.backdropColor[3],
          state.backdropColor[4]
        )
        object:SetBackdropBorderColor(
          state.backdropBorderColor[1],
          state.backdropBorderColor[2],
          state.backdropBorderColor[3],
          state.backdropBorderColor[4]
        )
      end
    end
  end

  if object:IsObjectType("Texture") then
    if state.atlas then
      object:SetAtlas(state.atlas)
      Pixel.DisableSnap(object)
    else
      Pixel.SetTexture(object, state.texture)
    end

    Pixel.SetTexCoord(object, unpack(state.texCoord))
    if state.vertexColor[1] ~= nil then
      Pixel.SetVertexColor(object, unpack(state.vertexColor))
    end
    object:SetBlendMode(state.blendMode)
    object:SetHorizTile(state.horizTile)
    object:SetVertTile(state.vertTile)
  end

  if state.font and state.font[1] then
    object:SetFont(state.font[1], state.font[2], state.font[3])
  end

  if state.textColor then
    object:SetTextColor(unpack(state.textColor))
  end

  if state.justifyH then
    object:SetJustifyH(state.justifyH)
  end

  if state.justifyV then
    object:SetJustifyV(state.justifyV)
  end

  if state.wordWrap ~= nil then
    object:SetWordWrap(state.wordWrap)
  end

  if state.nonSpaceWrap ~= nil then
    object:SetNonSpaceWrap(state.nonSpaceWrap)
  end

  if state.shadowColor then
    object:SetShadowColor(unpack(state.shadowColor))
  end

  if state.shadowOffset then
    object:SetShadowOffset(unpack(state.shadowOffset))
  end

  if state.textInsets then
    object:SetTextInsets(unpack(state.textInsets))
  end

  if state.isFontString then
    object:SetText(state.text)
  end

  object:SetShown(state.shown)
end

function Theme.ReleaseCreatedWidget(widget)
  local lease = widget and widget.__puiCreatedWidgetLease
  if not lease then
    return
  end

  if widget.type == "TabGroup" then
    local host = widget.__puiCustomTabHost
    if host then
      host:Hide()

      for i = 1, #host.__puiButtons do
        local button = host.__puiButtons[i]
        button:Hide()
        button:ClearAllPoints()
        button.__puiNativeTab = nil
        button.__puiValue = nil
        button.__puiWidget = nil
        button.__puiDisabled = nil
      end
    end

    widget.__puiTabChromeHooked = nil
    widget.__puiTabLayoutInProgress = nil
    widget.__puiTabRefreshQueued = nil
  end

  local chromeSeen = {}
  for i = 1, #PUI_CREATED_WIDGET_ROOT_FIELDS do
    _PUI_HideCreatedWidgetChrome(widget, widget[PUI_CREATED_WIDGET_ROOT_FIELDS[i]], chromeSeen)
  end

  for i = 1, #lease.roots do
    _PUI_HideCreatedWidgetChrome(widget, lease.roots[i], chromeSeen)
  end

  for i = 1, #lease.objects do
    local object = lease.objects[i]
    object:SetParent(lease.states[object].parent)
  end

  for i = 1, #lease.objects do
    local object = lease.objects[i]
    _PUI_RestoreCreatedWidgetObject(object, lease.states[object])
    Theme._AppliedFonts[object] = nil
    object.__puiOptionsFontOwned = nil
    object.__puiSkipOptionsGlobalFont = nil
    object.__puiUseTextureBackdrop = nil
    object.__puiUseTreeCards = nil
    object.__puiTreeCardFontApplied = nil
    object.__puiTreeCardShadowApplied = nil
    object.__puiTreeCardHitRectSet = nil
    object.__puiTreeCardLayoutKey = nil
    object.__puiTreeButtonLayoutKey = nil
    object.__puiNativeTabHidden = nil
  end

  widget.alignoffset = lease.widgetFields.alignoffset
  widget.height = lease.widgetFields.height
  widget.width = lease.widgetFields.width
  widget.__puiCreatedWidgetLease = nil
end

local function _PUI_GetOptionsFontSizeDelta()
  return (tonumber(Addon:GetOptionsDB().puiOptionsFontSize) or 12) - 12
end

local function _PUI_GetOptionsOwnedFontSize(size)
  local finalSize = (tonumber(size) or 12) + _PUI_GetOptionsFontSizeDelta()

  if finalSize < 6 then finalSize = 6 end
  if finalSize > 72 then finalSize = 72 end

  return finalSize
end

local function _PUI_ApplyOwnedWidgetFontString(fs, role)
  if not fs or fs.__puiSkipOptionsGlobalFont == true then
    return
  end

  fs.__puiOptionsFontOwned = true

  local meta = Theme._AppliedFonts[fs]
  Theme.ApplyFont(fs, meta and meta.role or role or "body", meta and meta.size, meta and meta.outline)
end

local function _PUI_ApplyCreatedWidgetFonts(widget)
  local widgetType = widget.type
  local frame = widget.frame
  local defaultRole = "body"

  if widgetType == "Button" or widgetType == "Keybinding" then
    defaultRole = "button"
  elseif widgetType == "CheckBox" then
    defaultRole = "checkbox"
  elseif widgetType == "Heading" then
    defaultRole = "header"
  end

  if widgetType == "CheckBox" then
    _PUI_ApplyOwnedWidgetFontString(widget.text or widget.label, "checkbox")
  elseif widgetType == "Heading" then
    _PUI_ApplyOwnedWidgetFontString(widget.label or widget.text, "header")
  else
    _PUI_ApplyOwnedWidgetFontString(widget.label, defaultRole)
    _PUI_ApplyOwnedWidgetFontString(widget.text, defaultRole)
  end

  _PUI_ApplyOwnedWidgetFontString(frame.label, defaultRole)
  _PUI_ApplyOwnedWidgetFontString(frame.text, defaultRole)
  _PUI_ApplyOwnedWidgetFontString(widget.editbox, "body")

  if widget.button then
    _PUI_ApplyOwnedWidgetFontString(widget.button:GetFontString(), "button")
  end

  _PUI_ApplyOwnedWidgetFontString(widget.lowtext, "body")
  _PUI_ApplyOwnedWidgetFontString(widget.hightext, "body")
  _PUI_ApplyOwnedWidgetFontString(widget.__puiDropdownValueText, "body")
end

Theme.ApplyCreatedWidgetFonts = _PUI_ApplyCreatedWidgetFonts

function Theme.ApplyFont(fs, role, size, outline, scope)
  local meta = Theme._AppliedFonts[fs]
  if not meta then
    meta = {}
    Theme._AppliedFonts[fs] = meta
  end

  meta.role = role
  meta.size = size
  meta.outline = outline
  meta.scope = scope

  local roleMeta = role == "label" and Theme.FontRoles.body or Theme.FontRoles[role]
  local optionsOutline

  if fs.__puiOptionsFontOwned == true and outline == nil then
    optionsOutline = Theme.GetGlobalUIOutline()
  end

  size = size or roleMeta.size or 12
  outline = outline or optionsOutline or roleMeta.outline or "OUTLINE"

  if fs.__puiOptionsFontOwned == true and fs.__puiSkipOptionsGlobalFont ~= true then
    size = _PUI_GetOptionsOwnedFontSize(size)
    scope = "options"
  end

  size = Theme.ResolveFontSize(size, scope or "general")
  if size < 6 then size = 6 end
  if size > 72 then size = 72 end

  local style = outline:upper()
  local wantShadow = false

  if style == "NONE" then
    style = ""
  elseif style:find("^SHADOW") then
    wantShadow = true
    style = style:gsub("^SHADOW", "")
    if style == "NONE" then
      style = ""
    end
  end

  if style ~= "" then
    style = style:gsub("MONOCHROME", "")
    style = style:gsub(",,", ",")
    style = style:gsub("^,", "")
    style = style:gsub(",$", "")
  end

  fs:SetFont(LSM:Fetch("font", Theme.GetFont(role), true), size, style)

  if fs:GetObjectType() == "FontString" then
    if wantShadow then
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1, -1)
    else
      fs:SetShadowColor(0, 0, 0, 0)
      fs:SetShadowOffset(0, 0)
    end
  end
end

function Theme.RefreshAppliedFonts()
  for fs, meta in pairs(Theme._AppliedFonts) do
    Theme.ApplyFont(fs, meta.role, meta.size, meta.outline, meta.scope)
  end
end

Theme.iconText = {
  cooldown = {
    size = 16,
    color = { 0.95, 0.95, 0.95, 1.0 },
    shadow = { 0, 0, 0, 0.9, 1, -1 },
    justifyH = "CENTER",
    justifyV = "MIDDLE",
  },
  charge = {
    size = 14,
    color = { 1.0, 1.0, 1.0, 1.0 },
    shadow = { 0, 0, 0, 0.9, 1, -1 },
    justifyH = "CENTER",
    justifyV = "MIDDLE",
  },
  stack = {
    size = 14,
    color = { 1.0, 0.95, 0.6, 1.0 },
    shadow = { 0, 0, 0, 0.9, 1, -1 },
    justifyH = "CENTER",
    justifyV = "MIDDLE",
  },
}

Theme.iconTextGlobal = {
  font = "FiraSans Heavy",
  flags = "OUTLINE",
}

function Theme.GetIconTextGlobal()
  return Theme.iconTextGlobal.font, Theme.iconTextGlobal.flags
end

function Theme.SetIconTextGlobalFont(fontKey)
  Theme.iconTextGlobal.font = fontKey ~= nil and fontKey ~= "" and fontKey or "FiraSans Heavy"
end

function Theme.SetIconTextGlobalFlags(flags)
  Theme.iconTextGlobal.flags = Theme.NormalizeOutlineFlags(flags) or "OUTLINE"
end


function Theme.ResolveIconTextRole(role)
  if not role then return nil end

  local roleDef = Theme.iconText and Theme.iconText[role]
  if not roleDef then return nil end

  local gFont, gFlags = Theme.GetIconTextGlobal()

  local out = {}
  out.font     = (roleDef.font   ~= nil) and roleDef.font   or gFont
  out.size     = roleDef.size
  out.flags    = (roleDef.flags  ~= nil) and roleDef.flags  or gFlags
  out.color    = roleDef.color
  out.shadow   = roleDef.shadow
  out.justifyH = roleDef.justifyH
  out.justifyV = roleDef.justifyV

  return out
end

local function SyncBackdropFrame(target, bg)
  if not target or not bg then
    return
  end

  if bg:GetParent() ~= target then
    bg:SetParent(target)
    bg:ClearAllPoints()
    Pixel.AllPoints(bg, target)
  end

  bg.__puiIsBackdropFrame = true
  bg:EnableMouse(false)
  bg:SetFrameStrata(target:GetFrameStrata())

  local targetLevel = target:GetFrameLevel() - 1
  if targetLevel < 0 then
    targetLevel = 0
  end

  bg:SetFrameLevel(targetLevel)
  bg:Lower()
  bg:Show()
end

local function EnsureBackdropFrame(target)
  local bg = target._puiBg

  if not bg then
    bg = CreateFrame("Frame", nil, target, "BackdropTemplate")
    Pixel.AllPoints(bg, target)
    bg.__puiIsBackdropFrame = true
    Theme.MarkCreatedWidgetChrome(bg)
    target._puiBg = bg
  end

  if target.__puiBackdropLayerHooked ~= true then
    target.__puiBackdropLayerHooked = true
    target:HookScript("OnShow", function(self)
      SyncBackdropFrame(self, self._puiBg)
    end)
  end

  SyncBackdropFrame(target, bg)
  return bg
end

Theme.SyncBackdropFrame = SyncBackdropFrame
ns.Theme.EnsureBackdropFrame = EnsureBackdropFrame

function ns.Theme.GetEdgeSize()
  return 3
end

function Theme.UnpackColor(color)
  return color[1], color[2], color[3], color[4] or 1
end

ns.FontDropdown = {
  STANDARD_FONT_KEY = "__PUI_STANDARD_FONT__",
}
Theme.STANDARD_FONT_KEY = ns.FontDropdown.STANDARD_FONT_KEY

local STANDARD_FONT_KEY = ns.FontDropdown.STANDARD_FONT_KEY
local _cache = {}

function Theme.BuildGlobalFontList()
  if _cache.fontsGlobal then
    return _cache.fontsGlobal
  end

  local list = {}
  for _, name in ipairs(LSM:List(LSM.MediaType.FONT)) do
    list[name] = name
  end

  _cache.fontsGlobal = list
  return list
end

local PUI_WIDGET_ROW_TYPES = {
  Button = true,
  CheckBox = true,
  PUI_Button = true,
  PUI_Checkbox = true,
  PUI_Dropdown = true,
  PUI_EditBox = true,
  PUI_MultiLineEditBox = true,
  PUI_Slider = true,
  EditBox = true,
  MultiLineEditBox = true,
  ColorPicker = true,
  Dropdown = true,
  LQDropdown = true,
  LSM30_Font = true,
  LSM30_Sound = true,
  LSM30_Border = true,
  LSM30_Background = true,
  LSM30_Statusbar = true,
  Keybinding = true,
}

Theme._WidgetRowWidgets = Theme._WidgetRowWidgets or setmetatable({}, { __mode = "k" })


function Theme.GetWidgetRowBackgroundsEnabled()
  return Addon:GetOptionsDB().skin.widgetRowBackgrounds ~= false
end

function Theme.ResetWidgetRowBackgrounds()
  Theme.__puiWidgetRowSerial = 0
  Theme.__puiWidgetRowStamp = (Theme.__puiWidgetRowStamp or 0) + 1
end

function Theme.SetWidgetRowBackgroundIndex(widget, index)
  if PUI_WIDGET_ROW_TYPES[widget.type] ~= true then
    return
  end

  local frame = widget.frame
  index = tonumber(index) or 1

  Theme._WidgetRowWidgets[widget] = true
  widget.__puiWidgetRowIndex = index
  widget.__puiWidgetRowStamp = Theme.__puiWidgetRowStamp

  local bg = frame.__puiWidgetRowBackground

  if not Theme.GetWidgetRowBackgroundsEnabled() then
    if bg then
      bg:Hide()
    end
    return
  end

  local colors = Theme.GetColors()
  local color = colors.control
  local alpha = color[4] * (index % 2 == 0 and 0.20 or 0.10)

  if not bg then
    bg = frame:CreateTexture(nil, "BACKGROUND")
    Pixel.SetTexture(bg, "Interface\\Buttons\\WHITE8x8")
    bg:SetIgnoreParentAlpha(true)
    Theme.MarkCreatedWidgetChrome(bg)
    frame.__puiWidgetRowBackground = bg
  end

  bg:ClearAllPoints()
  Pixel.AllPoints(bg, frame)
  Pixel.SetColorTexture(bg, color[1], color[2], color[3], alpha)
  bg:Show()
end

function Theme.ReleaseWidgetRowBackground(widget)
  Theme._WidgetRowWidgets[widget] = nil

  local frame = widget and widget.frame
  local bg = frame and frame.__puiWidgetRowBackground

  if bg then
    bg:Hide()
  end
end

function Theme.ApplyWidgetRowBackground(widget)
  local index = widget.__puiWidgetRowIndex

  if widget.__puiWidgetRowStamp ~= Theme.__puiWidgetRowStamp then
    Theme.__puiWidgetRowSerial = (Theme.__puiWidgetRowSerial or 0) + 1
    index = Theme.__puiWidgetRowSerial
  end

  Theme.SetWidgetRowBackgroundIndex(widget, index or 1)
end

function Theme.RefreshWidgetRowBackgrounds()
  for widget in pairs(Theme._WidgetRowWidgets) do
    Theme.SetWidgetRowBackgroundIndex(widget, widget.__puiWidgetRowIndex or 1)
  end
end

function Theme.SetWidgetRowBackgroundsEnabled(enabled)
  Addon:GetOptionsDB().skin.widgetRowBackgrounds = enabled == true
  Theme.RefreshWidgetRowBackgrounds()
end

local function _PUI_ApplyCreatedWidgetSizing(widget, opts)
  if PUI_WIDGET_ROW_TYPES[widget.type] ~= true then
    return
  end

  local metrics = Theme.GetControlMetrics(widget)
  local height = tonumber(opts and opts.height) or metrics.widgetBoxHeight

  if widget.type == "MultiLineEditBox" or widget.type == "PUI_MultiLineEditBox" then
    local currentHeight = tonumber(widget.frame:GetHeight()) or 0
    height = math.max(height, currentHeight, 140)
  end

  widget.alignoffset = 0
  widget.__puiWidgetBoxHeight = height
  widget.height = height
  widget.frame.__puiWidgetBoxHeight = height
  widget.frame.height = height

  widget:SetHeight(height)
  Pixel.Height(widget.frame, height)
end


local _PUI_BlizzBaseSize = setmetatable({}, { __mode = "k" })

local function _PUI_GetBaseSize(obj, curSize)
  local base = _PUI_BlizzBaseSize[obj]
  if base == nil then
    base = tonumber(curSize) or 14
    _PUI_BlizzBaseSize[obj] = base
  end
  return base
end


local function _PUI_ApplyToFontObjectKeepSize(fontObject, fontPath, sizeDelta, forcedFlags)
  local _, curSize, curFlags = fontObject:GetFont()
  local base = _PUI_GetBaseSize(fontObject, curSize)

  local delta = tonumber(sizeDelta) or 0
  local size = base + delta
  if size < 6 then size = 6 end
  if size > 72 then size = 72 end

  local flags = (forcedFlags == nil) and (curFlags or "") or forcedFlags
  fontObject:SetFont(fontPath, size, flags)
end

local function _PUI_ApplyToFontStringKeepSize(fs, fontPath, sizeDelta, forcedFlags)
  local _, curSize, curFlags = fs:GetFont()
  local base = _PUI_GetBaseSize(fs, curSize)

  local delta = tonumber(sizeDelta) or 0
  local size = base + delta
  if size < 6 then size = 6 end
  if size > 72 then size = 72 end

  local flags = (forcedFlags == nil) and (curFlags or "") or forcedFlags
  fs:SetFont(fontPath, size, flags)
end

local function _PUI_ForEachFontString(root, fn)
  local regions = { root:GetRegions() }
  for i = 1, #regions do
    local r = regions[i]
    if r:GetObjectType() == "FontString" then
      fn(r)
    end
  end
end

local function _PUI_ApplyFrameFontsKeepSize(frame, fontPath, sizeDelta, forcedFlags)
  local function ApplyFS(fs)
    _PUI_ApplyToFontStringKeepSize(fs, fontPath, sizeDelta, forcedFlags)
  end

  _PUI_ForEachFontString(frame, ApplyFS)

  local n = frame:GetNumChildren()
  for i = 1, n do
    _PUI_ForEachFontString(select(i, frame:GetChildren()), ApplyFS)
  end
end

function Theme.SeedBlizzardFontsDB(db)
  if not db then
    return
  end

  db.blizzardFonts = db.blizzardFonts or {}
  local bf = db.blizzardFonts

  local function Seed(areaKey, defaultSize)
    bf[areaKey] = bf[areaKey] or {}
    local a = bf[areaKey]
    if a.enabled == nil then a.enabled = false end
    if a.font == STANDARD_FONT_KEY then
      a.font = nil
      a.useGlobalFont = true
    end
    if a.useGlobalFont == nil then
      a.useGlobalFont = not (type(a.font) == "string" and a.font ~= "")
    end
    if a.flags == nil then a.flags = "" end

    if a.sizeOffset == nil then
      a.sizeOffset = 0
    end
  end

  Seed("tooltips",         14)
  Seed("friendsList",      14)
  Seed("chat",             14)
  Seed("chatBubbles",      14)
  Seed("raidWarnings",     28)
  Seed("questText",        16)
  Seed("objectives",       14)
  Seed("adventureGuide",   14)

  Seed("characterPanel",   14)
  Seed("reputation",       14)
  Seed("spellbook",        14)
  Seed("achievements",     14)

  Seed("talentTree",       14)

  -- Accessibility / system-wide font objects
  Seed("systemFont",           14)
  Seed("gameFont",             14)
  Seed("combatTextFont",       18)
  Seed("gameNormalNumberFont", 14)
end

local function _PUI_GetAreaDelta(db, area)
  local areaOff = tonumber(area and area.sizeOffset) or 0
  return areaOff
end

local function ApplyTooltips(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyToFontObjectKeepSize(GameTooltipHeaderText, fontPath, delta + 2, flags)
  _PUI_ApplyToFontObjectKeepSize(GameTooltipText,       fontPath, delta,     flags)
  _PUI_ApplyToFontObjectKeepSize(GameTooltipTextSmall,  fontPath, delta - 1, flags)

  if Tooltip_Small then
    _PUI_ApplyToFontObjectKeepSize(Tooltip_Small, fontPath, delta - 1, flags)
  end
  if Tooltip_Med then
    _PUI_ApplyToFontObjectKeepSize(Tooltip_Med, fontPath, delta, flags)
  end
end

local function ApplyFriendsList(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  if FriendsFontNormal then _PUI_ApplyToFontObjectKeepSize(FriendsFontNormal, fontPath, delta,     flags) end
  if FriendsFontSmall  then _PUI_ApplyToFontObjectKeepSize(FriendsFontSmall,  fontPath, delta - 1, flags) end
  if FriendsFontLarge  then _PUI_ApplyToFontObjectKeepSize(FriendsFontLarge,  fontPath, delta + 1, flags) end

  if FriendsFrameStatusText then
    _PUI_ApplyToFontObjectKeepSize(FriendsFrameStatusText, fontPath, delta - 1, flags)
  end

  if FriendsFrame then
    _PUI_ApplyFrameFontsKeepSize(FriendsFrame, fontPath, delta, flags)
  end
end

local function ApplyChat(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)

  local function NormalizeFlags(f)
    if f == "NONE" then
      return nil -- nil = keep current flags
    end
    if f == nil or f == "" then
      return nil
    end
    return f
  end

  local forcedFlags = NormalizeFlags(area.flags)

  local n = _G.NUM_CHAT_WINDOWS or 0
  for i = 1, n do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.GetFont and cf.SetFont then
      local curFont, curSize, curFlags = cf:GetFont()
      local base = _PUI_GetBaseSize(cf, curSize)

      local size = base + delta
      if size < 6 then size = 6 end
      if size > 72 then size = 72 end

      local flags = forcedFlags or curFlags or ""
      cf:SetFont(fontPath, size, flags)

    end
  end

  if _G.GMChatFrame and GMChatFrame.GetFont and GMChatFrame.SetFont then
    local curFont, curSize, curFlags = GMChatFrame:GetFont()
    local base = _PUI_GetBaseSize(GMChatFrame, curSize)

    local size = base + delta
    if size < 6 then size = 6 end
    if size > 72 then size = 72 end

    local flags = forcedFlags or curFlags or ""
    GMChatFrame:SetFont(fontPath, size, flags)

  end
end

local function ApplyChatBubbles(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  if ChatBubbleFont then
    _PUI_ApplyToFontObjectKeepSize(ChatBubbleFont, fontPath, delta, flags)
  end
end

local function ApplyRaidWarnings(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags -- allow forcing, nil keeps current

  if _G.RaidWarningFrameSlot1 then _PUI_ApplyToFontStringKeepSize(_G.RaidWarningFrameSlot1, fontPath, delta, flags) end
  if _G.RaidWarningFrameSlot2 then _PUI_ApplyToFontStringKeepSize(_G.RaidWarningFrameSlot2, fontPath, delta, flags) end
end

local function ApplyQuestText(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyToFontObjectKeepSize(QuestTitleFont,       fontPath, delta + 2, flags)
  _PUI_ApplyToFontObjectKeepSize(QuestFont,            fontPath, delta,     flags)
  _PUI_ApplyToFontObjectKeepSize(QuestFontNormalSmall, fontPath, delta - 3, flags)
end

local function ApplyObjectiveTracker(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  for s = 12, 22 do
    local obj = _G["ObjectiveTrackerFont" .. s]
    if obj then
      _PUI_ApplyToFontObjectKeepSize(obj, fontPath, delta, flags)
    end
  end
end

local function ApplyAdventureGuide(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.EncounterJournal then
      _PUI_ApplyFrameFontsKeepSize(_G.EncounterJournal, fontPath, delta, flags)
    end
  end

  ApplyNow()

  if _G.EncounterJournal and _G.EncounterJournal.HookScript and not _G.EncounterJournal.__puiFontHooked then
    _G.EncounterJournal.__puiFontHooked = true
    _G.EncounterJournal:HookScript("OnShow", ApplyNow)
  end
end

local function ApplyCharacterPanel(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.CharacterFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.CharacterFrame, fontPath, delta, flags)
    end
  end

  ApplyNow()

  if _G.CharacterFrame and _G.CharacterFrame.HookScript and not _G.CharacterFrame.__puiFontHooked then
    _G.CharacterFrame.__puiFontHooked = true
    _G.CharacterFrame:HookScript("OnShow", ApplyNow)
  end
end

local function ApplyReputation(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.ReputationFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.ReputationFrame, fontPath, delta, flags)
    elseif _G.CharacterFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.CharacterFrame, fontPath, delta, flags)
    end
  end

  ApplyNow()
end

local function ApplySpellbook(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.SpellBookFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.SpellBookFrame, fontPath, delta, flags)
    end
  end

  ApplyNow()

  if _G.SpellBookFrame and _G.SpellBookFrame.HookScript and not _G.SpellBookFrame.__puiFontHooked then
    _G.SpellBookFrame.__puiFontHooked = true
    _G.SpellBookFrame:HookScript("OnShow", ApplyNow)
  end
end



local function ApplyAchievements(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.AchievementFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.AchievementFrame, fontPath, delta, flags)
    end
  end

  ApplyNow()

  if _G.AchievementFrame and _G.AchievementFrame.HookScript and not _G.AchievementFrame.__puiFontHooked then
    _G.AchievementFrame.__puiFontHooked = true
    _G.AchievementFrame:HookScript("OnShow", ApplyNow)
  end
end

local function ApplyTalentTree(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  local function ApplyNow()
    if _G.PlayerSpellsFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.PlayerSpellsFrame, fontPath, delta, flags)
    end
    if _G.ClassTalentFrame then
      _PUI_ApplyFrameFontsKeepSize(_G.ClassTalentFrame, fontPath, delta, flags)
    end
  end

  ApplyNow()

  if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.HookScript and not _G.PlayerSpellsFrame.__puiFontHooked then
    _G.PlayerSpellsFrame.__puiFontHooked = true
    _G.PlayerSpellsFrame:HookScript("OnShow", ApplyNow)
  end
  if _G.ClassTalentFrame and _G.ClassTalentFrame.HookScript and not _G.ClassTalentFrame.__puiFontHooked then
    _G.ClassTalentFrame.__puiFontHooked = true
    _G.ClassTalentFrame:HookScript("OnShow", ApplyNow)
  end
end

local function _PUI_ApplyFontObjectsByPrefixKeepSize(prefix, fontPath, sizeDelta, forcedFlags)
  if not prefix or prefix == "" then return end
  for k, v in pairs(_G) do
    if type(k) == "string" and k:sub(1, #prefix) == prefix then
      if v and type(v) == "table" and v.SetFont and v.GetFont then
        _PUI_ApplyToFontObjectKeepSize(v, fontPath, sizeDelta, forcedFlags)
      end
    end
  end
end

local function ApplySystemFont(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyFontObjectsByPrefixKeepSize("SystemFont_", fontPath, delta, flags)
end

local function ApplyGameFont(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyFontObjectsByPrefixKeepSize("GameFont", fontPath, delta, flags)
end

local function ApplyCombatTextFont(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyToFontObjectKeepSize(_G.CombatTextFont, fontPath, delta, flags)
  _PUI_ApplyToFontObjectKeepSize(_G.CombatTextFontOutline, fontPath, delta, flags)
end

local function ApplyGameNormalNumberFont(db, area)
  local fontKey  = ns.OptionsUtil.ResolveFontKey(area.font, area.useGlobalFont)
  local fontPath = ns.OptionsUtil.FetchFontPath(fontKey, false)

  local delta = _PUI_GetAreaDelta(db, area)
  local flags = area.flags

  _PUI_ApplyToFontObjectKeepSize(_G.GameNormalNumberFont, fontPath, delta, flags)
end

function Theme.ApplyBlizzardFonts(db)
  if InCombatLockdown() then
    return
  end

  db = db or Addon.db.profile

  Theme.SeedBlizzardFontsDB(db)

  local bf = db.blizzardFonts

  if bf.tooltips.enabled then ApplyTooltips(db, bf.tooltips) end
  if bf.friendsList.enabled then ApplyFriendsList(db, bf.friendsList) end
  if bf.chat.enabled then ApplyChat(db, bf.chat) end
  if bf.chatBubbles.enabled then ApplyChatBubbles(db, bf.chatBubbles) end
  if bf.raidWarnings.enabled then ApplyRaidWarnings(db, bf.raidWarnings) end
  if bf.questText.enabled then ApplyQuestText(db, bf.questText) end
  if bf.objectives.enabled then ApplyObjectiveTracker(db, bf.objectives) end
  if bf.adventureGuide.enabled then ApplyAdventureGuide(db, bf.adventureGuide) end

  if bf.characterPanel.enabled then ApplyCharacterPanel(db, bf.characterPanel) end
  if bf.reputation.enabled then ApplyReputation(db, bf.reputation) end
  if bf.spellbook.enabled then ApplySpellbook(db, bf.spellbook) end
  if bf.achievements.enabled then ApplyAchievements(db, bf.achievements) end
  if bf.talentTree.enabled then ApplyTalentTree(db, bf.talentTree) end

  if bf.systemFont.enabled then ApplySystemFont(db, bf.systemFont) end
  if bf.gameFont.enabled then ApplyGameFont(db, bf.gameFont) end
  if bf.combatTextFont.enabled then ApplyCombatTextFont(db, bf.combatTextFont) end
  if bf.gameNormalNumberFont.enabled then ApplyGameNormalNumberFont(db, bf.gameNormalNumberFont) end
end

do
  if not Theme.__puiBlizzFontsEventFrame then
    local f = CreateFrame("Frame")
    Theme.__puiBlizzFontsEventFrame = f

    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ADDON_LOADED")

    f:SetScript("OnEvent", function(_, event, arg1)
      if event == "PLAYER_ENTERING_WORLD" then
        Theme.ApplyBlizzardFonts()
        return
      end

      if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_EncounterJournal"
          or arg1 == "Blizzard_UIPanels_Game"
          or arg1 == "Blizzard_AchievementUI"
          or arg1 == "Blizzard_PlayerSpells"
          or arg1 == "Blizzard_FriendsFrame"
        then
          Theme.ApplyBlizzardFonts()
        end
      end
    end)
  end
end


function Theme:ApplyButton(button, kind)
  if not button then return end
  button.__puiKind = kind or button.__puiKind or "primary"
  return ns.Theme.WidgetSkins.UIButton(button)
end

local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local PUI_CONTROL_METRICS = {
  controlHeight = 20,
  sliderInputWidth = 74,
  checkboxBoxSize = 18,
  widgetBoxHeight = 56,
  treeGroupWidth = 190,
  inlineGroupPaddingX = 8,
  inlineGroupPaddingY = 8,
  treeButtonGap = 8,
  treeGroupTopInset = 10,
}

local PUI_COMPACT_CONTROL_METRICS = {
  controlHeight = 18,
  sliderInputWidth = 58,
  checkboxBoxSize = 14,
  widgetBoxHeight = 38,
  treeGroupWidth = 190,
  inlineGroupPaddingX = 8,
  inlineGroupPaddingY = 8,
  treeButtonGap = 8,
  treeGroupTopInset = 10,
}

local PUI_COMPACT_INLINE_CONTROL_METRICS = {
  controlHeight = 14,
  sliderInputWidth = 58,
  checkboxBoxSize = 14,
  widgetBoxHeight = 24,
  treeGroupWidth = 190,
  inlineGroupPaddingX = 8,
  inlineGroupPaddingY = 8,
  treeButtonGap = 8,
  treeGroupTopInset = 10,
}

local function IsCompactWidget(widget)
  return widget
    and widget.GetUserData
    and widget:GetUserData("puiDensity") == "compact"
end

local function IsCompactInlineWidget(widget)
  local widgetType = widget and widget.type
  return widgetType == "CheckBox"
    or widgetType == "PUI_Checkbox"
    or widgetType == "ColorPicker"
end

function Theme.GetControlMetrics(widget)
  if IsCompactWidget(widget) then
    if IsCompactInlineWidget(widget) then
      return PUI_COMPACT_INLINE_CONTROL_METRICS
    end
    return PUI_COMPACT_CONTROL_METRICS
  end

  return PUI_CONTROL_METRICS
end

local PUI_WIDGET_ROW_GEOMETRY = {
  rowHeight = PUI_CONTROL_METRICS.widgetBoxHeight,
  labelLeft = 8,
  labelRight = 8,
  labelTop = 4,
  labelHeight = 16,
  controlLeft = 12,
  controlRight = 12,
  controlTop = 24,
  controlBottom = 12,
  controlHeight = PUI_CONTROL_METRICS.controlHeight,
  controlYOffset = 0,
  valueWidth = PUI_CONTROL_METRICS.sliderInputWidth,
  valueGap = 8,
  controlGap = 4,
  buttonWidth = 40,
}

local PUI_COMPACT_WIDGET_ROW_GEOMETRY = {
  rowHeight = PUI_COMPACT_CONTROL_METRICS.widgetBoxHeight,
  labelLeft = 4,
  labelRight = 4,
  labelTop = 1,
  labelHeight = 14,
  controlLeft = 6,
  controlRight = 6,
  controlTop = 18,
  controlBottom = 2,
  controlHeight = PUI_COMPACT_CONTROL_METRICS.controlHeight,
  controlYOffset = 0,
  valueWidth = PUI_COMPACT_CONTROL_METRICS.sliderInputWidth,
  valueGap = 4,
  controlGap = 4,
  buttonWidth = 32,
}

local PUI_COMPACT_INLINE_WIDGET_ROW_GEOMETRY = {
  rowHeight = PUI_COMPACT_INLINE_CONTROL_METRICS.widgetBoxHeight,
  labelLeft = 4,
  labelRight = 4,
  labelTop = 0,
  labelHeight = 14,
  controlLeft = 6,
  controlRight = 6,
  controlTop = 5,
  controlBottom = 5,
  controlHeight = PUI_COMPACT_INLINE_CONTROL_METRICS.controlHeight,
  controlYOffset = 0,
  valueWidth = PUI_COMPACT_INLINE_CONTROL_METRICS.sliderInputWidth,
  valueGap = 4,
  controlGap = 4,
  buttonWidth = 32,
}

function Theme.GetWidgetRowGeometry(widget)
  if IsCompactWidget(widget) then
    if IsCompactInlineWidget(widget) then
      return PUI_COMPACT_INLINE_WIDGET_ROW_GEOMETRY
    end
    return PUI_COMPACT_WIDGET_ROW_GEOMETRY
  end

  return PUI_WIDGET_ROW_GEOMETRY
end

function Theme.GetOptionsWidgetColumns()
  local optionsDB = Addon:GetOptionsDB()
  local columns = tonumber(optionsDB.optionsWidgetColumns) or 4

  if columns < 2 then
    return 2
  end

  if columns > 5 then
    return 5
  end

  return columns
end

function Theme.SetOptionsWidgetColumns(columns)
  local optionsDB = Addon:GetOptionsDB()
  columns = tonumber(columns) or 4

  if columns < 2 then
    columns = 2
  elseif columns > 5 then
    columns = 5
  end

  optionsDB.optionsWidgetColumns = columns
end

local function StripIconFrameArt(frame)
  if not frame then return end

  local texFields = {
    "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture",
    "Border", "IconBorder", "Shine", "SlotArt", "SlotBackground",
  }

  for _, key in ipairs(texFields) do
    local getter = frame["Get" .. key]
    local setter = frame["Set" .. key]
    if getter and setter then
      local tex = getter(frame)
      if tex and tex.SetTexture then
        tex:SetTexture(nil)
      end
      setter(frame, "")
    end
  end

  if frame.Border     and frame.Border.SetTexture     then frame.Border:SetTexture(nil)     end
  if frame.IconBorder and frame.IconBorder.SetTexture then frame.IconBorder:SetTexture(nil) end
  if frame.Shine      and frame.Shine.SetTexture      then frame.Shine:SetTexture(nil)      end
end

local function StripStatusBarMasks(bar)
  if not bar or bar:IsForbidden() then return end

  if bar.SetMask then
    bar:SetMask(nil)
  end

  if bar.Mask then
    bar.Mask:Hide()
  end

  if bar.GetNumRegions then
    for i = 1, bar:GetNumRegions() do
      local r = select(i, bar:GetRegions())
      if r and r.GetObjectType and r:GetObjectType() == "MaskTexture" then
        r:Hide()
      end
    end
  end
end

Theme.statusBarRoles = Theme.statusBarRoles or {
  health = {
    border = { enabled = true, thickness = 1, color = {0, 0, 0, 1} },
  },
  primary = {
    border = { enabled = true, thickness = 1, color = {0, 0, 0, 1} },
  },
  secondary = {
    border = { enabled = true, thickness = 1, color = {0, 0, 0, 1} },
  },
  secondaryRune = {
    border = { enabled = true, thickness = 1, color = {0, 0, 0, 1} },
  },
  class = {
    border = { enabled = true, thickness = 1, color = {0, 0, 0, 1} },
  },
}

local function EnsureStatusBarBorder(bar)
  if not bar or not bar.CreateTexture then return nil end
  if bar._puiStatusBorder and bar._puiStatusBorder.top then
    return bar._puiStatusBorder
  end

  local function NewEdge()
    local t = bar:CreateTexture(nil, "OVERLAY")
    Pixel.SetTexture(t, WHITE8)
    t:Hide()
    return t
  end

  bar._puiStatusBorder = {
    top    = NewEdge(),
    bottom = NewEdge(),
    left   = NewEdge(),
    right  = NewEdge(),
  }
  return bar._puiStatusBorder
end

function Theme.ApplyStatusBarBorder(bar, opts)
  if not bar then return end
  opts = opts or {}

  local enabled   = (opts.enabled ~= false)
  local thickness = tonumber(opts.thickness) or 1
  if thickness < 0 then thickness = 0 end
  if thickness > 12 then thickness = 12 end

  local col = opts.color or {1, 1, 1, 1}
  local r, g, b, a = col[1] or 1, col[2] or 1, col[3] or 1, col[4] or 1

  local border = EnsureStatusBarBorder(bar)
  if not border then return end

  if not enabled or thickness == 0 then
    border.top:Hide()
    border.bottom:Hide()
    border.left:Hide()
    border.right:Hide()
    return
  end

  -- Top
  border.top:ClearAllPoints()
  Pixel.Point(border.top, "TOPLEFT", bar, "TOPLEFT", -thickness, thickness)
  Pixel.Point(border.top, "TOPRIGHT", bar, "TOPRIGHT", thickness, thickness)
  Pixel.Height(border.top, thickness)

  -- Bottom
  border.bottom:ClearAllPoints()
  Pixel.Point(border.bottom, "BOTTOMLEFT", bar, "BOTTOMLEFT", -thickness, -thickness)
  Pixel.Point(border.bottom, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", thickness, -thickness)
  Pixel.Height(border.bottom, thickness)

  -- Left
  border.left:ClearAllPoints()
  Pixel.Point(border.left, "TOPLEFT", bar, "TOPLEFT", -thickness, thickness)
  Pixel.Point(border.left, "BOTTOMLEFT", bar, "BOTTOMLEFT", -thickness, -thickness)
  Pixel.Width(border.left, thickness)

  -- Right
  border.right:ClearAllPoints()
  Pixel.Point(border.right, "TOPRIGHT", bar, "TOPRIGHT", thickness, thickness)
  Pixel.Point(border.right, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", thickness, -thickness)
  Pixel.Width(border.right, thickness)

  Pixel.SetVertexColor(border.top, r, g, b, a)
  Pixel.SetVertexColor(border.bottom, r, g, b, a)
  Pixel.SetVertexColor(border.left, r, g, b, a)
  Pixel.SetVertexColor(border.right, r, g, b, a)

  border.top:Show()
  border.bottom:Show()
  border.left:Show()
  border.right:Show()
end

function Theme.SkinStatusBar(bar, opts)
  if not bar then return end
  opts = opts or {}
  local role = opts.role or "primary"

  local theme = ns.Theme.GetColors()

  local texPath = ns.Theme.GetBarTexture()

  StripStatusBarMasks(bar)

  if bar.SetStatusBarTexture then
    Pixel.SetStatusBarTexture(bar, texPath)
  end

  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if tex and tex.SetHorizTile then
    tex:SetHorizTile(false)
  end

  if bar.bg then
    Pixel.SetTexture(bar.bg, texPath)
    Pixel.SetVertexColor(bar.bg, 0, 0, 0, 0.6)
  end

  local roleDef = Theme.statusBarRoles[role]
  if roleDef and roleDef.border then
    Theme.ApplyStatusBarBorder(bar, roleDef.border)
  else
    Theme.ApplyStatusBarBorder(bar, { enabled = false })
  end
end

Theme.StripIcon = StripIconFrameArt

local function _PUI_EnsureTextureBackdrop(frame)
  local backdrop = frame.__puiTextureBackdrop
  if backdrop then
    return backdrop
  end

  local function CreateTexture(subLevel)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, subLevel)
    Pixel.SetTexture(texture, "Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(texture)
    return texture
  end

  backdrop = {
    background = CreateTexture(-8),
    top = CreateTexture(-7),
    bottom = CreateTexture(-7),
    left = CreateTexture(-7),
    right = CreateTexture(-7),
  }
  frame.__puiTextureBackdrop = backdrop
  return backdrop
end

local function _PUI_SetTextureBackdrop(frame, preset, edgeSize)
  local backdrop = _PUI_EnsureTextureBackdrop(frame)

  if frame.__puiTextureBackdropEdgeSize ~= edgeSize then
    frame.__puiTextureBackdropEdgeSize = edgeSize

    backdrop.background:ClearAllPoints()
    Pixel.Point(backdrop.background, "TOPLEFT", frame, "TOPLEFT", 1, -1)
    Pixel.Point(backdrop.background, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    backdrop.top:ClearAllPoints()
    Pixel.Point(backdrop.top, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    Pixel.Point(backdrop.top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    Pixel.Height(backdrop.top, edgeSize)

    backdrop.bottom:ClearAllPoints()
    Pixel.Point(backdrop.bottom, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    Pixel.Point(backdrop.bottom, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    Pixel.Height(backdrop.bottom, edgeSize)

    backdrop.left:ClearAllPoints()
    Pixel.Point(backdrop.left, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    Pixel.Point(backdrop.left, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    Pixel.Width(backdrop.left, edgeSize)

    backdrop.right:ClearAllPoints()
    Pixel.Point(backdrop.right, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    Pixel.Point(backdrop.right, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    Pixel.Width(backdrop.right, edgeSize)

    local showBorder = edgeSize > 0
    backdrop.top:SetShown(showBorder)
    backdrop.bottom:SetShown(showBorder)
    backdrop.left:SetShown(showBorder)
    backdrop.right:SetShown(showBorder)
  end

  local bg = preset.bg
  local border = preset.border

  backdrop.background:Show()
  local showBorder = edgeSize > 0
  backdrop.top:SetShown(showBorder)
  backdrop.bottom:SetShown(showBorder)
  backdrop.left:SetShown(showBorder)
  backdrop.right:SetShown(showBorder)
  Pixel.SetVertexColor(backdrop.background, bg[1], bg[2], bg[3], bg[4])
  Pixel.SetVertexColor(backdrop.top, border[1], border[2], border[3], border[4])
  Pixel.SetVertexColor(backdrop.bottom, border[1], border[2], border[3], border[4])
  Pixel.SetVertexColor(backdrop.left, border[1], border[2], border[3], border[4])
  Pixel.SetVertexColor(backdrop.right, border[1], border[2], border[3], border[4])
end

function Theme.SetSquareBackdrop(frame, preset, edgeSize)
  if not frame then return end

  if not preset then
    local colors = Theme.GetColors()
    preset = {
      bg = colors.background,
      border = colors.border,
    }
  end

  edgeSize = edgeSize or Theme.GetEdgeSize() or 1
  local showBorder = edgeSize > 0

  if frame.__puiUseTextureBackdrop == true then
    _PUI_SetTextureBackdrop(frame, preset, edgeSize)
    return
  end

  local bgFrame
  if frame.__puiIsBackdropFrame and frame.SetBackdrop then
    bgFrame = frame
  else
    bgFrame = Theme.EnsureBackdropFrame(frame) or frame
  end

  if not bgFrame or not bgFrame.SetBackdrop then
    return
  end

  if bgFrame.__puiSquareBackdropEdgeSize ~= edgeSize or not bgFrame:GetBackdrop() then
    bgFrame.__puiSquareBackdropEdgeSize = edgeSize

    local inset = showBorder and 1 or 0
    bgFrame:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = showBorder and "Interface\\Buttons\\WHITE8x8" or nil,
      tile     = false,
      edgeSize = showBorder and edgeSize or nil,
      insets   = { left = inset, right = inset, top = inset, bottom = inset },
    })
  end

  local bg = preset.bg
  local border = preset.border

  bgFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])

  if showBorder then
    bgFrame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
  end
end

function Theme.SetAceTooltipSolidBackground(tooltip, enabled)
  if not tooltip then
    return
  end

  local background = tooltip.__puiAceTooltipSolidBackground

  if enabled ~= true then
    if background then
      background:Hide()
    end
    return
  end

  if not background then
    background = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8)
    Pixel.Point(background, "TOPLEFT", tooltip, "TOPLEFT", 2, -2)
    Pixel.Point(background, "BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -2, 2)
    tooltip.__puiAceTooltipSolidBackground = background
  end

  local colors = Theme.GetColors()
  local color = colors.background
  Pixel.SetColorTexture(background, color[1], color[2], color[3], 1)
  background:Show()
end


local PUI_SELF_SKINNING_WIDGET_TYPES = {
  PUI_Button = true,
  PUI_Dropdown = true,
  PUI_EditBox = true,
  PUI_MultiLineEditBox = true,
  PUI_Slider = true,
}

local PUI_ACE3_SKIN_METHODS = {
  Button = "Button",
  CheckBox = "Checkbox",
  EditBox = "EditBox",
  MultiLineEditBox = "EditBox",
  ColorPicker = "ColorPicker",
  Dropdown = "Dropdown",
  LQDropdown = "Dropdown",
  LSM30_Font = "Dropdown",
  LSM30_Sound = "Dropdown",
  LSM30_Border = "Dropdown",
  LSM30_Background = "Dropdown",
  LSM30_Statusbar = "Dropdown",
  Keybinding = "Keybinding",
  ["Dropdown-Pullout"] = "DropdownPullout",
  ["Dropdown-Item-Toggle"] = "DropdownItem",
  ["Dropdown-Item-Execute"] = "DropdownItem",
  Label = "Label",
  InteractiveLabel = "Label",
  Heading = "Heading",
  InlineGroup = "InlineGroup",
  TreeGroup = "TreeGroup",
  TabGroup = "TabGroup",
}

local function _PUI_ApplyAce3Skin(widget)
  if PUI_SELF_SKINNING_WIDGET_TYPES[widget.type] then
    widget:RefreshTheme()
    return
  end

  local skins = Theme.WidgetSkins
  local skinMethod = PUI_ACE3_SKIN_METHODS[widget.type]

  if skinMethod then
    return skins[skinMethod](widget)
  end

  if widget.type == "ScrollFrame" then
    skins.Scrollbar(widget.scrollbar or widget)
    return
  end

  if widget.type == "Window" then
    skins.Frame(widget.content:GetParent())
    skins.CloseButton(widget.closebutton)

    if widget.scrollbar then
      skins.Scrollbar(widget.scrollbar)
    end
    return
  end

  if widget.type == "DropdownGroup" then
    skins.Frame(widget.content:GetParent())

    if widget.dropdown then
      ns.AceHooks.TakeOwnership(widget.dropdown)
    end

    return
  end

  if widget.type == "Frame" then
    skins.Frame(widget.content:GetParent())

    if widget.scrollbar then
      skins.Scrollbar(widget.scrollbar)
    end
  end
end


  Theme.ApplyCreatedWidgetSizing = _PUI_ApplyCreatedWidgetSizing
  Theme.ApplyAce3Skin = _PUI_ApplyAce3Skin

  local function _PUI_InitializeCreatedWidget(widget)
    if not widget then
      return
    end

    Theme.ApplyCreatedWidgetSizing(widget)
    widget.__puiCreatedWidgetInitialized = true
    Theme.ApplyAce3Skin(widget)
    Theme.ApplyCreatedWidgetFonts(widget)
    Theme.ApplyWidgetRowBackground(widget)
  end

Theme.InitializeCreatedWidget = _PUI_InitializeCreatedWidget


local function _PUI_ThemeRegistry_NotifyChange(refreshPlayerBuffs, refreshFonts)
  if refreshFonts ~= false then
    Theme.ApplyBlizzardFonts(Addon.db.profile)
    Theme.RefreshAppliedFonts()
  end

  Addon:RefreshOptionsTheme()

  if refreshFonts == false then
    Addon:RequestThemeUpdates()
  elseif refreshPlayerBuffs then
    ns.Modules.PlayerBuffs:ApplySettings({ playerBuffsStyle = true })
  end
end

function Theme.GetFontSizeOffset()
  return tonumber(Addon:GetMediaDB().fontSizeOffset) or 0
end

function Theme.SetFontSizeOffset(value)
  local range = Theme.FontSizeOffsetRange
  value = tonumber(value) or 0
  if value < range.min then value = range.min end
  if value > range.max then value = range.max end

  Addon:GetMediaDB().fontSizeOffset = value
  Addon:RefreshIconFonts()
  Addon:RefreshOptionsTheme()
end

function Theme.GetFontSizeScope(scope)
  return Addon:GetMediaDB().fontSizeScopes[scope] ~= false
end

function Theme.SetFontSizeScope(scope, enabled)
  Addon:GetMediaDB().fontSizeScopes[scope] = enabled == true
  Addon:RefreshIconFonts()
  Addon:RefreshOptionsTheme()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

function Theme.GetAllFontSizeScopes()
  local scopes = Addon:GetMediaDB().fontSizeScopes
  for index = 1, #Theme.FontSizeScopes do
    if scopes[Theme.FontSizeScopes[index].key] == false then
      return false
    end
  end
  return true
end

function Theme.SetAllFontSizeScopes(enabled)
  local scopes = Addon:GetMediaDB().fontSizeScopes
  enabled = enabled == true

  for index = 1, #Theme.FontSizeScopes do
    scopes[Theme.FontSizeScopes[index].key] = enabled
  end

  Addon:RefreshIconFonts()
  Addon:RefreshOptionsTheme()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

Theme.OptionsFontSizeRange = Theme.OptionsFontSizeRange or {
  min = 10,
  max = 24,
  step = 1,
}

Theme.OptionsUIScaleRange = Theme.OptionsUIScaleRange or {
  min = 0.75,
  max = 2.00,
  step = 0.01,
}

function Theme.GetGlobalUIFont()
  return Addon:GetMediaDB().iconTextGlobalFont
end

function Theme.SetGlobalUIFont(value)
  local mediaDB = Addon:GetMediaDB()
  mediaDB.iconTextGlobalFont = value
  Theme.SetIconTextGlobalFont(value)
  Addon:RefreshIconFonts()
  _PUI_ThemeRegistry_NotifyChange(true)
end

function Theme.GetGlobalUIOutline()
  return Addon:GetMediaDB().iconTextGlobalFlags
end

function Theme.SetGlobalUIOutline(value)
  local mediaDB = Addon:GetMediaDB()
  value = Theme.NormalizeOutlineFlags(value)
  if value == nil then
    value = "OUTLINE"
  end

  mediaDB.iconTextGlobalFlags = value
  Theme.SetIconTextGlobalFlags(value)
  Addon:RefreshIconFonts()
  _PUI_ThemeRegistry_NotifyChange(true)
end

function Theme.GetOptionsFontSize()
  return tonumber(Addon:GetOptionsDB().puiOptionsFontSize) or 14
end

function Theme.SetOptionsFontSize(value)
  local range = Theme.OptionsFontSizeRange
  value = tonumber(value) or Theme.GetOptionsFontSize()

  if value < range.min then value = range.min end
  if value > range.max then value = range.max end

  Addon:GetOptionsDB().puiOptionsFontSize = value
  _PUI_ThemeRegistry_NotifyChange()
end

function Theme.GetOptionsUIScale()
  local range = Theme.OptionsUIScaleRange
  local value = tonumber(Addon:GetOptionsDB().optionsScale) or 1.0

  if value < range.min then
    return range.min
  end

  if value > range.max then
    return range.max
  end

  return value
end

function Theme.SetOptionsUIScale(value)
  local range = Theme.OptionsUIScaleRange
  value = tonumber(value) or Theme.GetOptionsUIScale()

  if value < range.min then
    value = range.min
  elseif value > range.max then
    value = range.max
  end

  Addon:GetOptionsDB().optionsScale = value
  Addon:ApplyOptionsUIScale()
end

Theme.ColorPresets = {
  default = {
    label = "Default",
    description = "PleebUI default",
  },
  highContrast = {
    label = "High Contrast - White",
    description = "White and cyan on black",
    colors = {
      backgroundColor = { 0.000000, 0.000000, 0.000000, 1.00 },
      controlBgColor = { 0.000000, 0.000000, 0.000000, 1.00 },
      accentColor = { 0.000000, 1.000000, 1.000000, 1.00 },
      borderColor = { 1.000000, 1.000000, 1.000000, 1.00 },
      textColor = { 1.000000, 1.000000, 1.000000, 1.00 },
    },
  },
  highContrastYellow = {
    label = "High Contrast - Yellow",
    description = "Yellow on black",
    colors = {
      backgroundColor = { 0.000000, 0.000000, 0.000000, 1.00 },
      controlBgColor = { 0.000000, 0.000000, 0.000000, 1.00 },
      accentColor = { 1.000000, 1.000000, 0.000000, 1.00 },
      borderColor = { 1.000000, 1.000000, 0.000000, 1.00 },
      textColor = { 1.000000, 1.000000, 0.000000, 1.00 },
    },
  },
  protanopia = {
    label = "Protanopia",
    description = "Blue and yellow contrast",
    colors = {
      backgroundColor = { 0.027451, 0.082353, 0.129412, 1.00 },
      controlBgColor = { 0.007843, 0.039216, 0.062745, 1.00 },
      accentColor = { 0.337255, 0.705882, 0.913725, 1.00 },
      borderColor = { 0.941176, 0.894118, 0.258824, 1.00 },
      textColor = { 1.000000, 1.000000, 1.000000, 1.00 },
    },
  },
  deuteranopia = {
    label = "Deuteranopia",
    description = "Orange and blue contrast",
    colors = {
      backgroundColor = { 0.086275, 0.062745, 0.023529, 1.00 },
      controlBgColor = { 0.031373, 0.023529, 0.000000, 1.00 },
      accentColor = { 0.901961, 0.623529, 0.000000, 1.00 },
      borderColor = { 0.337255, 0.705882, 0.913725, 1.00 },
      textColor = { 1.000000, 1.000000, 1.000000, 1.00 },
    },
  },
  tritanopia = {
    label = "Tritanopia",
    description = "Magenta and orange contrast",
    colors = {
      backgroundColor = { 0.101961, 0.039216, 0.086275, 1.00 },
      controlBgColor = { 0.035294, 0.011765, 0.027451, 1.00 },
      accentColor = { 0.800000, 0.474510, 0.654902, 1.00 },
      borderColor = { 0.835294, 0.368627, 0.000000, 1.00 },
      textColor = { 1.000000, 1.000000, 1.000000, 1.00 },
    },
  },
}

Theme.ColorPresetOrder = {
  "default",
  "highContrast",
  "highContrastYellow",
  "protanopia",
  "deuteranopia",
  "tritanopia",
}

local COLOR_PRESET_DB_KEYS = {
  "backgroundColor",
  "controlBgColor",
  "accentColor",
  "borderColor",
  "textColor",
}

function Theme.GetColorPresetLabel(key)
  local preset = Theme.ColorPresets[key]
  return preset and preset.label or nil
end

function Theme.GetColorPresetDefinition(key)
  return Theme.ColorPresets[key]
end

local COLOR_PRESET_PREVIEW_KEYS = {
  backgroundColor = "background",
  controlBgColor = "control",
  accentColor = "accent",
  borderColor = "border",
  textColor = "text",
}

function Theme.GetColorPresetPreviewColors(key)
  local preset = Theme.ColorPresets[key]
  if not preset then
    return nil
  end

  local source = preset.colors or {}
  local colors = {}

  for dbKey, runtimeKey in pairs(COLOR_PRESET_PREVIEW_KEYS) do
    colors[runtimeKey] = _PUI_CopyColor(source[dbKey] or Theme.DefaultColors[runtimeKey])
  end

  return colors
end

function Theme.ApplyColorPreset(key)
  local preset = Theme.ColorPresets[key]
  if not preset then
    return false
  end

  local skinDB = Addon:GetOptionsDB().skin

  for i = 1, #COLOR_PRESET_DB_KEYS do
    skinDB[COLOR_PRESET_DB_KEYS[i]] = nil
  end

  for dbKey, color in pairs(preset.colors or {}) do
    skinDB[dbKey] = _PUI_CopyColor(color)
  end

  _PUI_ThemeColorsCache = nil
  _PUI_ThemeColorsCacheSignature = nil
  _PUI_ThemeRegistry_NotifyChange(true, false)
  return true
end

local function _PUI_ThemeRegistry_GetColorFallback(key)
  local colors = Theme.GetColors()

  local map = {
    backgroundColor = "background",
    controlBgColor = "control",
    accentColor = "accent",
    borderColor = "border",
    textColor = "text",
  }

  local colorKey = map[key]
  local color = colorKey and colors[colorKey] or nil
  if type(color) ~= "table" then
    return 1, 1, 1, 1
  end

  return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

local function _PUI_ThemeRegistry_GetColorOverride(key)
  local color = Addon:GetOptionsDB().skin[key]
  if type(color) == "table" then
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
  end

  return _PUI_ThemeRegistry_GetColorFallback(key)
end

local function _PUI_ThemeRegistry_SetColorOverride(key, r, g, b, a)
  Addon:GetOptionsDB().skin[key] = { r, g, b, a }
  _PUI_ThemeColorsCache = nil
  _PUI_ThemeColorsCacheSignature = nil
  _PUI_ThemeRegistry_NotifyChange(true, false)
end

local _PUI_ThemeRegistry_ResolutionScalePresets = {
  { key = "1080p", value = Addon.FrameScale:GetResolutionScalePreset("1080p"), label = "1080p" },
  { key = "1440p", value = Addon.FrameScale:GetResolutionScalePreset("1440p"), label = "1440p" },
  { key = "4K", value = Addon.FrameScale:GetResolutionScalePreset("4K"), label = "4K" },
}

local function _PUI_ThemeRegistry_GetUIScaleValue()
  return tonumber(Addon.FrameScale:GetUIScale()) or 0.533333333333333
end

local function _PUI_ThemeRegistry_FindResolutionScalePresetKey(targetScale)
  targetScale = tonumber(targetScale)
  if not targetScale then
    return nil
  end

  for i = 1, #_PUI_ThemeRegistry_ResolutionScalePresets do
    local preset = _PUI_ThemeRegistry_ResolutionScalePresets[i]
    local diff = targetScale - preset.value
    if diff < 0 then
      diff = -diff
    end

    if diff < 0.001 then
      return preset.key, preset.label
    end
  end

  return nil, nil
end

local function _PUI_ThemeRegistry_GetUIScaleStatusText()
  local current = _PUI_ThemeRegistry_GetUIScaleValue()
  local recommended = Addon.FrameScale:PixelBestSize()
  local _, presetLabel = _PUI_ThemeRegistry_FindResolutionScalePresetKey(current)

  if presetLabel then
    return string.format("UI scale: %.3f (%s)\nRecommended: %.3f", current, presetLabel, recommended)
  end

  return string.format("UI scale: %.3f (custom)\nRecommended: %.3f", current, recommended)
end

local ThemeColorsProvider
local ThemeFontsProvider
local UIScaleProvider

local function _PUI_ThemeRegistry_CopyArgsWithoutHeader(args)
  local out = {}

  for key, value in pairs(args) do
    if key ~= "header" then
      out[key] = value
    end
  end

  return out
end

local function GeneralOptionsProvider()
  local provider = {}

  function provider:GetOptions()
    local scaleOptions = UIScaleProvider():GetOptions()

    return {
      type = "group",
      name = "UI Scale",
      order = 10,
      args = {
        uiScale = {
          type = "group",
          name = scaleOptions.name or "UI Scale",
          order = 1,
          inline = true,
          args = _PUI_ThemeRegistry_CopyArgsWithoutHeader(scaleOptions.args),
        },
        setup = {
          type = "group",
          name = "Getting started",
          order = 2,
          inline = true,
          args = {
            description = {
              type = "description",
              name = "Run the setup wizard again.",
              order = 1,
            },
            run = {
              type = "execute",
              name = "Run setup wizard",
              order = 2,
              func = function()
                Addon:ShowInstallWizard(true)
              end,
            },
          },
        },
      },
    }
  end

  return provider
end

local function UIThemeOptionsProvider()
  local provider = {}

  function provider:GetOptions()
    local colorOptions = ThemeColorsProvider():GetOptions()
    local fontOptions = ThemeFontsProvider():GetOptions()

    return {
      type = "group",
      name = "UI Theme",
      order = 15,
      args = {
        themeColors = {
          type = "group",
          name = colorOptions.name or "Colors",
          order = 1,
          inline = true,
          args = _PUI_ThemeRegistry_CopyArgsWithoutHeader(colorOptions.args),
        },
        fonts = {
          type = "group",
          name = fontOptions.name or "Fonts",
          order = 2,
          inline = true,
          args = _PUI_ThemeRegistry_CopyArgsWithoutHeader(fontOptions.args),
        },
        combatReadability = {
          type = "group",
          name = "Combat readability",
          order = 3,
          inline = true,
          args = {
            description = {
              type = "description",
              name = "Makes existing combat text and important visual cues easier to distinguish. This applies normal Unit Frame, PRD, and custom-bar settings once; it does not lock or override them afterward.",
              order = 1,
            },
            apply = {
              type = "execute",
              name = "Apply combat readability",
              order = 2,
              disabled = function()
                return _G.InCombatLockdown()
              end,
              func = function()
                Addon:ApplyCombatReadabilityPreset()
              end,
            },
          },
        },
        optionsLayout = {
          type = "group",
          name = "Options layout",
          order = 4,
          inline = true,
          args = {
            optionsUIScale = {
              type = "range",
              name = "Options UI scale",
              desc = "Scale the entire PleebUI options window.",
              order = 1,
              min = Theme.OptionsUIScaleRange.min,
              max = Theme.OptionsUIScaleRange.max,
              step = Theme.OptionsUIScaleRange.step,
              isPercent = true,
              arg = { puiRefreshOnRelease = true },
              get = function()
                return Theme.GetOptionsUIScale()
              end,
              set = function(_, value)
                Theme.SetOptionsUIScale(value)
              end,
            },
            optionsWidgetColumns = {
              type = "select",
              name = "Widget columns",
              order = 2,
              values = {
                [2] = "2 columns",
                [3] = "3 columns",
                [4] = "4 columns",
                [5] = "5 columns",
              },
              get = function()
                return Theme.GetOptionsWidgetColumns()
              end,
              set = function(_, value)
                Theme.SetOptionsWidgetColumns(value)

                local activePath = ns._PUIActiveOptionsPath
                local activeRoot = type(activePath) == "table" and activePath[1] or nil
                Addon:NotifyOptionsTreeChanged(activeRoot, activePath)
              end,
            },
            widgetRowBackgrounds = {
              type = "toggle",
              name = "Show widget backgrounds",
              desc = "Show alternating shaded boxes behind option controls.",
              order = 3,
              get = function()
                return Theme.GetWidgetRowBackgroundsEnabled()
              end,
              set = function(_, value)
                Theme.SetWidgetRowBackgroundsEnabled(value)
              end,
            },
          },
        },
      },
    }
  end

  return provider
end

local PUI_THEME_COLOR_OPTIONS = {
  {
    key = "backgroundColor",
    name = "Background",
    desc = "Main color for PleebUI windows, panels, cards, and preview surfaces.\n\nAffects: the /pui window, page sections and headers, preview areas, dialogs, onboarding, Test Mode panels, Character and Inspect panels, Unit Frame preview and quick-settings panels, Cooldown Manager previews, PRD themed backgrounds, and Damage Meter windows.",
  },
  {
    key = "controlBgColor",
    name = "Control background",
    desc = "Background for interactive controls.\n\nAffects: navigation buttons, tabs, tree entries, buttons, checkboxes, dropdowns, text boxes, sliders, scrollbars, chat input, preview controls, and similar clickable elements.",
  },
  {
    key = "accentColor",
    name = "Accent",
    desc = "Highlight for active and interactive states.\n\nAffects: selected and hovered navigation, tabs and tree entries, checked boxes, slider thumbs, dropdown arrows, drag and resize handles, preview selections, progress indicators, Character and Inspect highlights, Damage Meter selections, and other active-state highlights.",
  },
  {
    key = "borderColor",
    name = "Border",
    desc = "Outline color used throughout PleebUI.\n\nAffects: window and panel borders, widget borders, tabs and tree entries, dialogs, preview frames, Character and Inspect panels, Damage Meter frames, Unit Frame quick-settings, and Player Buff icon borders.",
  },
  {
    key = "textColor",
    name = "Text",
    desc = "Default color for PleebUI interface text.\n\nAffects: labels, navigation, tabs, trees, controls, descriptions, dialogs, Character and Inspect text, Test Mode, previews, Damage Meter text, Player Buff stack and duration text, and other themed UI text.",
  },
}

local function PUI_ThemeColorOption(key, name, description, order)
  return {
    type = "color",
    name = name,
    desc = description,
    descStyle = "tooltip",
    order = order,
    hasAlpha = true,
    get = function()
      return _PUI_ThemeRegistry_GetColorOverride(key)
    end,
    set = function(_, r, g, b, a)
      _PUI_ThemeRegistry_SetColorOverride(key, r, g, b, a)
    end,
  }
end

ThemeColorsProvider = function()
  local provider = {}

  function provider:GetOptions()
    local args = {
      header = {
        type = "header",
        name = "Colors",
        order = 1,
      },
    }

    for i = 1, #PUI_THEME_COLOR_OPTIONS do
      local definition = PUI_THEME_COLOR_OPTIONS[i]
      args[definition.key] = PUI_ThemeColorOption(
        definition.key,
        definition.name,
        definition.desc,
        i + 1
      )
    end

    args.resetAllColors = {
      type = "execute",
      name = "Reset colors",
      order = #PUI_THEME_COLOR_OPTIONS + 2,
      confirm = function()
        return "Reset all color overrides to default skin colors?"
      end,
      func = function()
        local skinDB = Addon:GetOptionsDB().skin

        for i = 1, #PUI_THEME_COLOR_OPTIONS do
          skinDB[PUI_THEME_COLOR_OPTIONS[i].key] = nil
        end

        _PUI_ThemeColorsCache = nil
        _PUI_ThemeColorsCacheSignature = nil
        _PUI_ThemeRegistry_NotifyChange(true, false)
      end,
    }

    return {
      type = "group",
      name = "Colors",
      order = 22,
      args = args,
    }
  end

  return provider
end

ThemeFontsProvider = function()
  local provider = {}

  function provider:GetOptions()
    return {
      type = "group",
      name = "Fonts",
      order = 23,
      args = {
        header = {
          type = "header",
          name = "Fonts",
          order = 1,
        },
        iconTextGlobalFont = {
          type = "select",
          dialogControl = "LSM30_Font",
          name = "Global font",
          order = 2,
          values = function()
            return Theme.BuildGlobalFontList()
          end,
          get = function()
            return Theme.GetGlobalUIFont()
          end,
          set = function(_, value)
            Theme.SetGlobalUIFont(value)
          end,
        },
        iconTextGlobalFlags = {
          type = "select",
          name = "Global outline",
          order = 3,
          values = function()
            return Theme.GetOutlineList()
          end,
          get = function()
            return Theme.GetGlobalUIOutline()
          end,
          set = function(_, value)
            Theme.SetGlobalUIOutline(value)
          end,
        },
        fontSizeOffset = {
          type = "range",
          name = "Font size offset",
          desc = "Adds or removes font size without changing individual font settings.",
          order = 4,
          min = Theme.FontSizeOffsetRange.min,
          max = Theme.FontSizeOffsetRange.max,
          step = Theme.FontSizeOffsetRange.step,
          arg = { puiRefreshOnRelease = true },
          get = function()
            return Theme.GetFontSizeOffset()
          end,
          set = function(_, value)
            Theme.SetFontSizeOffset(value)
          end,
        },
        fontSizeScopes = {
          type = "group",
          name = "Apply to",
          order = 5,
          inline = true,
          args = {
            all = {
              type = "toggle",
              name = "All PleebUI",
              order = 1,
              width = "full",
              get = function()
                return Theme.GetAllFontSizeScopes()
              end,
              set = function(_, value)
                Theme.SetAllFontSizeScopes(value)
              end,
            },
            general = {
              type = "toggle",
              name = "General UI",
              order = 2,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("general") end,
              set = function(_, value) Theme.SetFontSizeScope("general", value) end,
            },
            options = {
              type = "toggle",
              name = "Options",
              order = 3,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("options") end,
              set = function(_, value) Theme.SetFontSizeScope("options", value) end,
            },
            unitFrames = {
              type = "toggle",
              name = "Unit Frames",
              order = 4,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("unitFrames") end,
              set = function(_, value) Theme.SetFontSizeScope("unitFrames", value) end,
            },
            actionBars = {
              type = "toggle",
              name = "Action Bars",
              order = 5,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("actionBars") end,
              set = function(_, value) Theme.SetFontSizeScope("actionBars", value) end,
            },
            cooldownManager = {
              type = "toggle",
              name = "Cooldown Manager",
              order = 6,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("cooldownManager") end,
              set = function(_, value) Theme.SetFontSizeScope("cooldownManager", value) end,
            },
            resourceDisplay = {
              type = "toggle",
              name = "Resource Display",
              order = 7,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("resourceDisplay") end,
              set = function(_, value) Theme.SetFontSizeScope("resourceDisplay", value) end,
            },
            playerBuffs = {
              type = "toggle",
              name = "Player Buffs",
              order = 8,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("playerBuffs") end,
              set = function(_, value) Theme.SetFontSizeScope("playerBuffs", value) end,
            },
            minimap = {
              type = "toggle",
              name = "Minimap",
              order = 9,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("minimap") end,
              set = function(_, value) Theme.SetFontSizeScope("minimap", value) end,
            },
            qualityOfLife = {
              type = "toggle",
              name = "Quality of Life",
              order = 10,
              width = 0.5,
              get = function() return Theme.GetFontSizeScope("qualityOfLife") end,
              set = function(_, value) Theme.SetFontSizeScope("qualityOfLife", value) end,
            },
          },
        },
        puiOptionsFontSize = {
          type = "range",
          name = "Options font size",
          order = 6,
          min = Theme.OptionsFontSizeRange.min,
          max = Theme.OptionsFontSizeRange.max,
          step = Theme.OptionsFontSizeRange.step,
          get = function()
            return Theme.GetOptionsFontSize()
          end,
          set = function(_, value)
            Theme.SetOptionsFontSize(value)
          end,
        },
      },
    }
  end

  return provider
end

UIScaleProvider = function()
  local provider = {}

  function provider:GetOptions()
    return {
      type = "group",
      name = "UI Scale",
      order = 24,
      args = {
        header = {
          type = "header",
          name = "UI Scale",
          order = 1,
        },
        scaleInfo = {
          type = "description",
          name = function()
            return _PUI_ThemeRegistry_GetUIScaleStatusText()
          end,
          order = 2,
          fontSize = "medium",
        },
        UIScale = {
          type = "range",
          name = "UI scale",
          order = 3,
          min = 0.1,
          max = 1.25,
          softMin = 0.40,
          softMax = 1.15,
          bigStep = 0.01,
          step = 0.000000000000001,
          isPercent = false,
          arg = { puiRefreshOnRelease = true },
          get = function()
            return _PUI_ThemeRegistry_GetUIScaleValue()
          end,
          set = function(_, value)
            Addon.FrameScale:SetUIScale(value, false)
          end,
        },
        Scale1080p = {
          type = "execute",
          name = "1080p",
          order = 4,
          
          func = function()
            Addon.FrameScale:SetUIScale(Addon.FrameScale:GetResolutionScalePreset("1080p"), false)
          end,
        },
        Scale1440p = {
          type = "execute",
          name = "1440p",
          order = 5,
          
          func = function()
            Addon.FrameScale:SetUIScale(Addon.FrameScale:GetResolutionScalePreset("1440p"), false)
          end,
        },
        Scale4K = {
          type = "execute",
          name = "4K",
          order = 6,
          
          func = function()
            Addon.FrameScale:SetUIScale(Addon.FrameScale:GetResolutionScalePreset("4K"), false)
          end,
        },
        ScaleAuto = {
          type = "execute",
          name = "Automatic",
          order = 7,
          
          func = function()
            Addon.FrameScale:SetUIScale(Addon.FrameScale:PixelBestSize(), false)
          end,
        },
      },
    }
  end

  return provider
end

Addon:RegisterOptionsSection("GeneralOptions", GeneralOptionsProvider, 10, "UI Scale", nil, {
  preview = false,
})

Addon:RegisterOptionsSection("UITheme", UIThemeOptionsProvider, 15, "UI Theme", nil, {
  preview = false,
})

