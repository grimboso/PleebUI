local ADDON_NAME, ns = ...

local Addon = ns.Addon
local IconSkin = Addon:NewModule("IconSkin", "NumyAceEvent-3.0")
ns.IconSkin = IconSkin

local LSM   = ns.LSM
local Pixel = ns.Pixel
local Theme = ns.Theme

local IconObjectState = setmetatable({}, { __mode = "k" })

local function GetIconObjectState(object)
  local state = IconObjectState[object]
  if not state then
    state = {}
    IconObjectState[object] = state
  end

  return state
end

local function ResolveIconTarget(target)

  -- Direct texture
  if target.GetObjectType and target:GetObjectType() == "Texture" then
    return target, target:GetParent()
  end

  -- Frame.Icon
  if target.Icon and target.Icon.GetObjectType
     and target.Icon:GetObjectType() == "Texture" then
    return target.Icon, target
  end

  -- Frame.icon
  if target.icon and target.icon.GetObjectType
     and target.icon:GetObjectType() == "Texture" then
    return target.icon, target
  end

  return nil, target
end



local function HideTextureRegion(tex)
  if not tex then return end
  if tex.SetTexture then tex:SetTexture(nil) end
  if tex.Hide then tex:Hide() end
end

local function HideFrameRegion(frame)
  if not frame then return end
  if frame.Hide then frame:Hide() end
end


function IconSkin.StripIconMasks(target, parent)
  local tex = target
  if parent == nil then
    tex, parent = ResolveIconTarget(target)
    parent = parent or target
  end

  if not tex then
    return
  end

  parent = parent or (tex.GetParent and tex:GetParent()) or nil

  if tex.SetMask then
    tex:SetMask("")
  end

  if tex.GetMaskTexture and tex.RemoveMaskTexture then
    while true do
      local mt = tex:GetMaskTexture(1)
      if not mt then
        break
      end
      tex:RemoveMaskTexture(mt)
      if mt.Hide then
        mt:Hide()
      end
    end
  end

  -- Named IconMask handle (very common in Blizzard templates).
  if parent and parent.IconMask and tex.RemoveMaskTexture then
    tex:RemoveMaskTexture(parent.IconMask)
    if parent.IconMask.Hide then
      parent.IconMask:Hide()
    end
  end

  -- Any other MaskTexture regions on the parent.
  if parent and parent.GetRegions then
    local numRegions = parent.GetNumRegions and parent:GetNumRegions() or select("#", parent:GetRegions())
    for i = 1, numRegions do
      local r = select(i, parent:GetRegions())
      if r and r.IsObjectType and r:IsObjectType("MaskTexture") then
        if tex.RemoveMaskTexture then
          tex:RemoveMaskTexture(r)
        end
        if r.Hide then
          r:Hide()
        end
      elseif r and r.SetMask then
        r:SetMask("")
      end
    end
  end

  if parent and parent.SetMask then
    parent:SetMask("")
  end
end

function IconSkin.StripNineSliceAndBackdrop(frame, opts)
  opts = opts or {}

  if not frame then
    return
  end

  if not opts.keepBackdrop then
    -- Classic NineSlice container
    if frame.NineSlice then
      local nsFrame = frame.NineSlice
      if nsFrame.GetRegions then
        local numRegions = nsFrame:GetNumRegions() or 0
        for i = 1, numRegions do
          local r = select(i, nsFrame:GetRegions())
          if r and r.GetObjectType and r:GetObjectType() == "Texture" then
            HideTextureRegion(r)
          end
        end
      end
      HideFrameRegion(nsFrame)
    end

    if opts.skipBackdropFrame ~= true then
      local bg = Theme.EnsureBackdropFrame(frame)
      if bg and bg.SetBackdrop then
        bg:SetBackdrop(nil)
      end
    end
  end
end




function IconSkin.MakeIconSquare(target, opts)
  local tex, parent = ResolveIconTarget(target)

  opts = opts or {}

  -- 1) Strip Blizzard-style rounded masks
  IconSkin.StripIconMasks(tex, parent)

  -- 2) Apply crop (rounded-border removal) via texcoords
  local crop = opts.crop
  local left, right, top, bottom

  if type(crop) == "table" then
    left, right, top, bottom = crop[1], crop[2], crop[3], crop[4]
  else
    local c = (type(crop) == "number") and crop or 0.08
    left, right, top, bottom = c, 1 - c, c, 1 - c
  end

  tex:SetTexCoord(left, right, top, bottom)

  -- 3) Optional size control on the *frame* if possible
  local size = opts.size
  local frame = parent or target

  if size then
    if type(size) == "table" then
      local w = size[1] or size.w or 20
      local h = size[2] or size.h or 20

      w = Pixel.Round(w)
      h = Pixel.Round(h)

      frame:SetSize(w, h)
    elseif type(size) == "number" then
      local s = Pixel.Round(size)
      frame:SetSize(s, s)
    end
  end

end

local InCombatLockdown = InCombatLockdown

local DEFAULT_SWIPE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

function IconSkin.SquareCooldown(cd)
  if not cd or (cd.IsForbidden and cd:IsForbidden()) then
    return
  end

  if InCombatLockdown() then
    if cd.IsProtected and cd:IsProtected() then
      return
    end
    local p = cd.GetParent and cd:GetParent()
    if p and p.IsProtected and p:IsProtected() then
      return
    end
  end

  local parent = cd:GetParent() or cd

  cd:ClearAllPoints()
  cd:SetAllPoints(parent)
  cd:SetUseCircularEdge(false)
  cd:SetSwipeTexture(DEFAULT_SWIPE_TEXTURE)
  cd:SetHideCountdownNumbers(false)
end

local _iconBorders = setmetatable({}, { __mode = "k" })

local function EnsureBorderTextures(frame)

  local border = _iconBorders[frame]
  if border then
    return border
  end

  -- IMPORTANT:
  -- Use OVERLAY so borders are never buried behind icon/cooldown regions
  -- in Blizzard item templates (CooldownViewer, ActionButtons, etc).
  local function NewEdge()
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    t:Hide()
    return t
  end

  border = {
    top    = NewEdge(),
    bottom = NewEdge(),
    left   = NewEdge(),
    right  = NewEdge(),
  }

  _iconBorders[frame] = border
  return border
end

local function HideBorderForFrame(frame)
  local border = _iconBorders[frame]
  if not border then
    return
  end

  if border.top    then border.top:Hide()    end
  if border.bottom then border.bottom:Hide() end
  if border.left   then border.left:Hide()   end
  if border.right  then border.right:Hide()  end
end

function IconSkin.ApplySimpleBorder(target, thickness, color, placement)
  local tex, parent = ResolveIconTarget(target)
  local frame = parent or target


  thickness = tonumber(thickness) or 2
  if thickness <= 0 then
    HideBorderForFrame(frame)
    return
  end

  placement = (type(placement) == "string") and placement or "inside"
  placement = placement:lower()
  if placement ~= "outside" then
    placement = "inside"
  end

  local r, g, b, a = 1, 1, 1, 1
  if type(color) == "table" then
    -- Support both array-style {r,g,b,a} and keyed { r=, g=, b=, a= } tables.
    r = tonumber(color[1] or color.r) or 1
    g = tonumber(color[2] or color.g) or 1
    b = tonumber(color[3] or color.b) or 1
    a = tonumber(color[4] or color.a) or 1
  end

  local border = EnsureBorderTextures(frame)
  local anchor = tex or frame

 ----
  -- Position the 4 border lines: inside or outside.
 ----
  if placement == "outside" then
    -- Top (outside)
    border.top:ClearAllPoints()
    border.top:SetPoint("BOTTOMLEFT",  anchor, "TOPLEFT",  -thickness, 0)
    border.top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT",  thickness, 0)
    border.top:SetHeight(thickness)
    border.top:SetColorTexture(r, g, b, a)
    border.top:Show()

    -- Bottom (outside)
    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  -thickness, 0)
    border.bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT",  thickness, 0)
    border.bottom:SetHeight(thickness)
    border.bottom:SetColorTexture(r, g, b, a)
    border.bottom:Show()

    -- Left (outside)
    border.left:ClearAllPoints()
    border.left:SetPoint("TOPRIGHT",    anchor, "TOPLEFT",    0,  thickness)
    border.left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, -thickness)
    border.left:SetWidth(thickness)
    border.left:SetColorTexture(r, g, b, a)
    border.left:Show()

    -- Right (outside)
    border.right:ClearAllPoints()
    border.right:SetPoint("TOPLEFT",    anchor, "TOPRIGHT",    0,  thickness)
    border.right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, -thickness)
    border.right:SetWidth(thickness)
    border.right:SetColorTexture(r, g, b, a)
    border.right:Show()

    return
  end

  -- Inside (default)
  -- Top
  border.top:ClearAllPoints()
  border.top:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  border.top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
  border.top:SetHeight(thickness)
  border.top:SetColorTexture(r, g, b, a)
  border.top:Show()

  -- Bottom
  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
  border.bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
  border.bottom:SetHeight(thickness)
  border.bottom:SetColorTexture(r, g, b, a)
  border.bottom:Show()

  -- Left
  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  border.left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
  border.left:SetWidth(thickness)
  border.left:SetColorTexture(r, g, b, a)
  border.left:Show()

  -- Right
  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
  border.right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
  border.right:SetWidth(thickness)
  border.right:SetColorTexture(r, g, b, a)
  border.right:Show()
end

function IconSkin.HideCooldownViewerDebuffAndPandemic(frame, opts)
  opts = opts or {}

  if not frame or (frame.IsForbidden and frame:IsForbidden()) then
    return
  end

  if frame.DebuffBorder and opts.keepDebuffBorder ~= true then
    local db = frame.DebuffBorder

    if db.Texture then
      local tex = db.Texture
      if tex.SetAtlas then tex:SetAtlas(nil) end
      if tex.SetTexture then tex:SetTexture(nil) end
      if tex.SetAlpha then tex:SetAlpha(0) end
    end

    if db.SetAlpha then db:SetAlpha(0) end
  end

  if frame.PandemicIcon and opts.keepPandemicIcon ~= true then
    local pi = frame.PandemicIcon

    if pi.Texture then
      local tex = pi.Texture
      if tex.SetAtlas then tex:SetAtlas(nil) end
      if tex.SetTexture then tex:SetTexture(nil) end
      if tex.SetAlpha then tex:SetAlpha(0) end
    end

    if pi.SetAlpha then pi:SetAlpha(0) end
  end
end



function IconSkin.ApplyBorder(target, opts)
  opts = opts or {}

  if InCombatLockdown() and target.IsProtected and target:IsProtected() then
    IconSkin.QueueBorder(target, opts)
    return
  end

  local enabled = opts.enabled
  if enabled == nil then
    enabled = true
  end

  local thickness = tonumber(opts.thickness) or 1
  if thickness < 0 then
    thickness = 0

  elseif thickness > 8 then
    thickness = 8
  end


  -- Map logical thickness (0-6) to pixel-perfect UI units if FrameScale is available.
  -- This makes 1 = 1 physical pixel, 2 = 2px, etc, instead of raw UI units
  -- that can disappear at some UI scales.
  if thickness > 0 then
    local onePixel = ns.Pixel.GetOnePixel()
    if onePixel and onePixel > 0 then
      thickness = thickness * onePixel
    end
  end


  local color = opts.color or opts.colorOverride or opts.borderColor

  if not color then
    color = {
      opts.r or 0.20,
      opts.g or 0.20,
      opts.b or 0.24,
      opts.a or 1.00,
    }
  end


  local _, parent = ResolveIconTarget(target)
  local frame = parent or target


  IconSkin.HideCooldownViewerDebuffAndPandemic(frame, opts)


  if not enabled or thickness <= 0 then
    if frame then
      HideBorderForFrame(frame)
    end
    return
  end

  local placement = opts.placement or opts.borderPlacement
  IconSkin.ApplySimpleBorder(target, thickness, color, placement)
end


local _puiResolvedFontPathCache = {}

local function ResolveFontPath(fontKeyOrPath)
  if not fontKeyOrPath or type(fontKeyOrPath) ~= "string" then
    return nil
  end

  -- Looks like a literal path already.
  if fontKeyOrPath:find("\\") or fontKeyOrPath:find("/")
     or fontKeyOrPath:find("%.ttf") or fontKeyOrPath:find("%.otf") then
    return fontKeyOrPath
  end

  local cached = _puiResolvedFontPathCache[fontKeyOrPath]
  if cached then
    return cached
  end

  local fetched = LSM:Fetch("font", fontKeyOrPath, true)
  if fetched then
    _puiResolvedFontPathCache[fontKeyOrPath] = fetched
    return fetched
  end

  return fontKeyOrPath
end

local function ApplyFontStringStyle(fs, opts)
  if not fs or (fs.IsForbidden and fs:IsForbidden()) then return end
  opts = opts or {}
  local state = GetIconObjectState(fs)

  local roleDefaults = opts.role and Theme.ResolveIconTextRole(opts.role) or nil
  local use = roleDefaults or {}

  -- Manual overrides from opts win over Theme.
  local fontKey  = opts.font or use.font
  local fontPath = ResolveFontPath(fontKey)
  local size     = tonumber(opts.size or use.size) or nil
  local flags    = opts.flags or use.flags or ""
  local fontSize = Theme.ResolveFontSize(size or 12, opts.scope or "general")

  if fontPath then
    if state.fontPath ~= fontPath
      or state.fontSize ~= fontSize
      or state.fontFlags ~= flags
    then
      state.fontPath = fontPath
      state.fontSize = fontSize
      state.fontFlags = flags
      fs:SetFont(fontPath, fontSize, flags)
    end
  elseif size then
    local fallbackFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if state.fontPath ~= fallbackFont
      or state.fontSize ~= fontSize
      or state.fontFlags ~= flags
    then
      state.fontPath = fallbackFont
      state.fontSize = fontSize
      state.fontFlags = flags
      fs:SetFont(fallbackFont, fontSize, flags)
    end
  end

  local color = opts.color or use.color
  if color and fs.SetTextColor then
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1

    if state.textColorR ~= r
      or state.textColorG ~= g
      or state.textColorB ~= b
      or state.textColorA ~= a
    then
      state.textColorR = r
      state.textColorG = g
      state.textColorB = b
      state.textColorA = a
      fs:SetTextColor(r, g, b, a)
    end
  end

  local shadow = opts.shadow or use.shadow
  if shadow and fs.SetShadowColor and fs.SetShadowOffset then
    local sr = shadow[1] or 0
    local sg = shadow[2] or 0
    local sb = shadow[3] or 1
    local sa = shadow[4] or 1
    local sox = shadow[5] or 1
    local soy = shadow[6] or -1

    if state.shadowR ~= sr
      or state.shadowG ~= sg
      or state.shadowB ~= sb
      or state.shadowA ~= sa
      or state.shadowX ~= sox
      or state.shadowY ~= soy
    then
      state.shadowR = sr
      state.shadowG = sg
      state.shadowB = sb
      state.shadowA = sa
      state.shadowX = sox
      state.shadowY = soy
      fs:SetShadowColor(sr, sg, sb, sa)
      fs:SetShadowOffset(sox, soy)
    end
  end

  local justifyH = opts.justifyH or use.justifyH
  if justifyH and fs.SetJustifyH and state.justifyH ~= justifyH then
    state.justifyH = justifyH
    fs:SetJustifyH(justifyH)
  end

  local justifyV = opts.justifyV or use.justifyV
  if justifyV and fs.SetJustifyV and state.justifyV ~= justifyV then
    state.justifyV = justifyV
    fs:SetJustifyV(justifyV)
  end
end

local function ResolveCooldownText(cooldown)
  if cooldown:GetObjectType() == "FontString" then
    return cooldown
  end

  local state = GetIconObjectState(cooldown)
  local cached = state.resolvedCooldownText
  if cached and not cached:IsForbidden() then
    return cached
  end

  local fontString = cooldown:GetCountdownFontString()
  state.resolvedCooldownText = fontString
  return fontString
end


local PUI_ICON_TEXT_ANCHORS = {
  TOPLEFT = "Top left",
  TOP = "Top",
  TOPRIGHT = "Top right",
  LEFT = "Left",
  CENTER = "Center",
  RIGHT = "Right",
  BOTTOMLEFT = "Bottom left",
  BOTTOM = "Bottom center",
  BOTTOMRIGHT = "Bottom right",
}

local PUI_ICON_TEXT_ANCHOR_ORDER = {
  "TOPLEFT",
  "TOP",
  "TOPRIGHT",
  "LEFT",
  "CENTER",
  "RIGHT",
  "BOTTOMLEFT",
  "BOTTOM",
  "BOTTOMRIGHT",
}

local PUI_ICON_TEXT_DEFAULT_ANCHORS = {
  cooldown = "CENTER",
  charge = "BOTTOMRIGHT",
  keybind = "TOPLEFT",
}

local PUI_CHARGE_TEXT_INSETS = {
  TOPLEFT = { 2, -2 },
  TOP = { 0, -2 },
  TOPRIGHT = { -2, -2 },
  LEFT = { 2, 0 },
  CENTER = { 0, 0 },
  RIGHT = { -2, 0 },
  BOTTOMLEFT = { 2, 2 },
  BOTTOM = { 0, 2 },
  BOTTOMRIGHT = { -2, 2 },
}

IconSkin.TextAnchorValues = PUI_ICON_TEXT_ANCHORS
IconSkin.TextAnchorOrder = PUI_ICON_TEXT_ANCHOR_ORDER

function IconSkin.GetTextAnchor(role, point)
  if PUI_ICON_TEXT_ANCHORS[point] then
    return point
  end
  return PUI_ICON_TEXT_DEFAULT_ANCHORS[role] or "CENTER"
end

function IconSkin.ResolveTextAnchor(role, point, offsetX, offsetY)
  point = IconSkin.GetTextAnchor(role, point)

  local baseX, baseY = 0, 0
  if role == "charge" then
    local inset = PUI_CHARGE_TEXT_INSETS[point]
    baseX = inset[1]
    baseY = inset[2]
  end

  return point, baseX + (tonumber(offsetX) or 0), baseY + (tonumber(offsetY) or 0)
end

local _puiCooldownTextStyleScratch = {}

local function _PUI_GetCooldownTextStyleScratch()
  for k in pairs(_puiCooldownTextStyleScratch) do
    _puiCooldownTextStyleScratch[k] = nil
  end
  return _puiCooldownTextStyleScratch
end

function IconSkin.StyleCooldownText(cd, opts)
  if not cd or (cd.IsForbidden and cd:IsForbidden()) then return end
  opts = opts or {}
  opts.role = opts.role or "cooldown"
  local cooldownState = GetIconObjectState(cd)

  local roleDefaults = Theme.ResolveIconTextRole(opts.role) or {}
  local fontKey  = opts.font or roleDefaults.font
  local fontPath = ResolveFontPath(fontKey)
  local baseSize = tonumber(opts.size or roleDefaults.size)
  if not baseSize then
    baseSize = tonumber(IconSkin:GetGlobalCooldownFontSize())
  end
  baseSize = baseSize or 12
  local size = Theme.ResolveFontSize(baseSize, opts.scope or "general")
  local flags = opts.flags or roleDefaults.flags or ""

  local offsetX  = opts.offsetX
  local offsetY  = opts.offsetY
  local point, anchorX, anchorY = IconSkin.ResolveTextAnchor(
    opts.role,
    opts.point,
    offsetX,
    offsetY
  )
  local relativePoint = opts.relativePoint or point

  -- Preferred path: resolve the cooldown text once, then drive both
  -- SetCountdownFont and the FontString from PleebUI-owned settings.
  -- Do not inspect current FontString font data here; Midnight can return
  -- secret strings from frame APIs, and our own cached keys are enough.
  local fs = ResolveCooldownText(cd)

  if not fontPath then
    fontPath = "Fonts\\FRIZQT__.TTF"
  end

  size = size or 12

  if cd.SetCountdownFont
    and (
      cooldownState.countdownFontPath ~= fontPath
      or cooldownState.countdownFontSize ~= size
      or cooldownState.countdownFontFlags ~= flags
    )
  then
    cooldownState.countdownFontPath = fontPath
    cooldownState.countdownFontSize = size
    cooldownState.countdownFontFlags = flags
    cd:SetCountdownFont(fontPath, size, flags)
  end

  -- Always try to style the fontstring directly as well.
  if fs then
    local merged = _PUI_GetCooldownTextStyleScratch()
    for k, v in pairs(opts) do
      merged[k] = v
    end

    if fontPath and not merged.font then
      merged.font = fontPath
    end
    if baseSize and not merged.size then
      merged.size = baseSize
    end
    if flags and flags ~= "" and not merged.flags then
      merged.flags = flags
    end

    ApplyFontStringStyle(fs, merged)

    -- Optional anchor and XY offset on the icon.
    if offsetX ~= nil or offsetY ~= nil or opts.point ~= nil or opts.relativePoint ~= nil then
      local parent = cd:GetParent() or cd
      local x = anchorX
      local y = anchorY
      local fontState = GetIconObjectState(fs)
      if fontState.offsetAnchorParent ~= parent
        or fontState.offsetAnchorPoint ~= point
        or fontState.offsetAnchorRelativePoint ~= relativePoint
        or fontState.offsetAnchorX ~= x
        or fontState.offsetAnchorY ~= y
      then
        fontState.offsetAnchorParent = parent
        fontState.offsetAnchorPoint = point
        fontState.offsetAnchorRelativePoint = relativePoint
        fontState.offsetAnchorX = x
        fontState.offsetAnchorY = y
        fs:ClearAllPoints()
        fs:SetPoint(point, parent, relativePoint, x, y)
      end
    end

    _PUI_GetCooldownTextStyleScratch()
  end
end


-- Safe queued font engine

local _fontQueueCooldown = setmetatable({}, { __mode = "k" })

local _borderQueue = setmetatable({}, { __mode = "k" })

function IconSkin.QueueCooldownText(cd, opts)
  if not cd then
    return
  end
  _fontQueueCooldown[cd] = opts or _fontQueueCooldown[cd] or { role = "cooldown" }
end

function IconSkin.QueueBorder(target, opts)
  _borderQueue[target] = opts or _borderQueue[target] or {}
end

function IconSkin.ProcessFontQueue()
  if InCombatLockdown() then
    return
  end

  for cd, opts in pairs(_fontQueueCooldown) do
    _fontQueueCooldown[cd] = nil
    IconSkin.StyleCooldownText(cd, opts)
  end

end
function IconSkin.ProcessBorderQueue()
  if InCombatLockdown() then
    return
  end

  for target, opts in pairs(_borderQueue) do
    _borderQueue[target] = nil
    IconSkin.ApplyBorder(target, opts)
  end
end

-- CooldownFrame_Set is a secure refresh path and must not be hooked for fonts.

local COOLDOWN_FONT_DEFAULT_SIZE = 12

function IconSkin:GetGlobalCooldownFontSize()
  return self.db.profile.globalCooldownFontSize or COOLDOWN_FONT_DEFAULT_SIZE
end

function IconSkin:OnInitialize()
  self.db = Addon.db:RegisterNamespace("IconSkin", {
    profile = {
      globalCooldownFontSize = COOLDOWN_FONT_DEFAULT_SIZE,
    },
  })
end

function IconSkin:OnEnable()
  self:RegisterEvent("PLAYER_LOGIN",            "HandleSafeFontPulse")
  self:RegisterEvent("PLAYER_ENTERING_WORLD",   "HandleSafeFontPulse")
  self:RegisterEvent("PLAYER_REGEN_ENABLED",    "HandleSafeFontPulse")
end


function IconSkin:HandleSafeFontPulse()
  IconSkin.ProcessFontQueue()
  IconSkin.ProcessBorderQueue()
end



