
local ADDON_NAME, ns = ...

local Addon = ns.Addon
local Hooks = ns.PCMHooks
local P = select(1, ns.Pleebug:DropIn(ns, { name = "PCM", bucket = "DB" }))



local _G = _G
local InCombatLockdown = _G.InCombatLockdown
local math_floor = _G.math.floor
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local _, PLAYER_CLASS = UnitClass("player")

local function _PCM_DB_Attach(Cooldowns)
  local Theme = ns.Theme
  local Round = ns.Pixel.Round

  local function _GetWidthModeForViewer(viewerKey)
    if not viewerKey then
      return "icon"
    end

    local style = ns.PCM_DBExports.GetStyleDB()
    if not style then
      if viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer" then
        return "fixed"
      end
      return "icon"
    end

    style.viewerWidthMode = style.viewerWidthMode or {}
    local m = style.viewerWidthMode[viewerKey]

    -- Defaults:
    -- Essential + Utility should start in fixed width mode.
    if m == nil and (viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer") then
      style.viewerWidthMode[viewerKey] = "fixed"
      return "fixed"
    end

    -- Explicit mode from options
    if m == "fixed" then
      return "fixed"
    end

    return "icon"
  end

  local function _GetFixedWidthForViewer(viewerKey)
    local style = ns.PCM_DBExports.GetStyleDB()
    if not style or not viewerKey then
      return 300
    end

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


  -- Per-viewer icon size resolution:
  --   1) style.viewerSizes[viewerKey]
  --   2) style.iconSize
  --   3) hard fallback
  local _PUI_PCM_ICON_SIZE_CACHE = {}
  local _PUI_PCM_OVERRIDE_FREEZE_UNTIL = 0

  local function _GetIconSizeForViewer(viewerKey)
    local style = ns.PCM_DBExports.GetStyleDB()
    local sz = 36

    -- cache last known good size per viewerKey to avoid resizing flicker during override relayouts
    if viewerKey and _PUI_PCM_ICON_SIZE_CACHE[viewerKey] then
      sz = _PUI_PCM_ICON_SIZE_CACHE[viewerKey]
    end

    if style then
      if style.iconSize == nil then
        style.iconSize = 36
      end

      style.viewerSizes = style.viewerSizes or {}
      local v = style.viewerSizes[viewerKey]
      if v ~= nil then
        local n = tonumber(v)
        if n then
          sz = n
        end
      elseif style.iconSize ~= nil then
        local n = tonumber(style.iconSize)
        if n then
          sz = n
        end
      end
    end

    sz = tonumber(sz) or 36
    if sz < 8 then sz = 8 end
    if sz > 96 then sz = 96 end

    -- Keep a stable last-good size, especially around spell override swaps.
    if viewerKey then
      _PUI_PCM_ICON_SIZE_CACHE[viewerKey] = sz
    end

    return sz
  end

  local function _GetIconSpacingForViewer(viewerKey)
    local style = ns.PCM_DBExports.GetStyleDB()
    local sp = 2

    if style then
      if style.iconSpacing == nil then
        style.iconSpacing = 2
      end

      style.viewerSpacing = style.viewerSpacing or {}
      local v = style.viewerSpacing[viewerKey]
      if v ~= nil then
        local n = tonumber(v)
        if n then
          sp = n
        end
      elseif style.iconSpacing ~= nil then
        local n = tonumber(style.iconSpacing)
        if n then
          sp = n
        end
      end
    end

    sp = tonumber(sp) or 2
    if sp < -20 then sp = -20 end
    if sp > 40 then sp = 40 end
    return sp
  end


  local function _EnsureFontOffsets(entry)
    if not entry then return end
    if entry.offsetX == nil then entry.offsetX = 0 end
    if entry.offsetY == nil then entry.offsetY = 0 end
  end

  local _PUI_PCM_FontDBProfile
  local _PUI_PCM_FontDB
  local _PUI_PCM_FontOptsCache = {}

  local function _GetFontDB()
    local root = Addon.db
    if not (root and root.profile) then
      return nil
    end

    if _PUI_PCM_FontDBProfile == root.profile and _PUI_PCM_FontDB then
      return _PUI_PCM_FontDB
    end

    root.profile.cooldownManager = root.profile.cooldownManager or {}
    root.profile.cooldownManager.fonts = root.profile.cooldownManager.fonts or {}

    local fonts = root.profile.cooldownManager.fonts

    fonts.global = fonts.global or {}
    if fonts.global.cooldown == nil and type(fonts.cooldown) == "table" then
      fonts.global.cooldown = fonts.cooldown
    end
    if fonts.global.charge == nil and type(fonts.charge) == "table" then
      fonts.global.charge = fonts.charge
    end
    if fonts.global.keybind == nil and type(fonts.keybind) == "table" then
      fonts.global.keybind = fonts.keybind
    end
    fonts.cooldown = nil
    fonts.charge = nil
    fonts.keybind = nil

    fonts.global.cooldown = fonts.global.cooldown or {}
    fonts.global.charge   = fonts.global.charge   or {}
    fonts.global.keybind  = fonts.global.keybind  or {}

    fonts.viewers = fonts.viewers or {}

    _EnsureFontOffsets(fonts.global.cooldown)
    _EnsureFontOffsets(fonts.global.charge)
    _EnsureFontOffsets(fonts.global.keybind)

    for _, v in pairs(fonts.viewers) do
      if type(v) == "table" then
        if type(v.cooldown) == "table" then _EnsureFontOffsets(v.cooldown) end
        if type(v.charge) == "table" then _EnsureFontOffsets(v.charge) end
        if type(v.keybind) == "table" then _EnsureFontOffsets(v.keybind) end
      end
    end

    _PUI_PCM_FontDBProfile = root.profile
    _PUI_PCM_FontDB = fonts
    wipe(_PUI_PCM_FontOptsCache)
    return fonts
  end

  local function _HasAnyFontField(cfg)
    if not cfg then
      return false
    end

    if cfg.font or cfg.size or cfg.flags or cfg.color or cfg.point then
      return true
    end
    if cfg.offsetX ~= nil or cfg.offsetY ~= nil then
      return true
    end

    return false
  end

  local _PUI_PCM_FontOptsEmpty = {
    cooldown = { role = "cooldown", scope = "cooldownManager" },
    charge = { role = "charge", scope = "cooldownManager" },
    keybind = { role = "keybind", scope = "cooldownManager" },
  }

  local function _ResolveFontOpts(kind, viewerKey)
    local fonts = _GetFontDB()
    if not fonts then
      return nil
    end

    local role = (kind == "charge") and "charge" or (kind == "keybind") and "keybind" or "cooldown"

    local viewerCfg
    if viewerKey and fonts.viewers and fonts.viewers[viewerKey] then
      local v = fonts.viewers[viewerKey]
      viewerCfg = v and v[role] or nil
    end

    local cfg
    if _HasAnyFontField(viewerCfg) then
      cfg = viewerCfg
    else
      local global = (fonts.global and fonts.global[role]) or nil
      if _HasAnyFontField(global) then
        cfg = global
      end
    end

    if not cfg then
      return _PUI_PCM_FontOptsEmpty[role]
    end

    local viewerCacheKey = viewerKey or "__global"
    local bucket = _PUI_PCM_FontOptsCache[viewerCacheKey]
    if not bucket then
      bucket = {}
      _PUI_PCM_FontOptsCache[viewerCacheKey] = bucket
    end

    local font = (cfg.font and cfg.font ~= "") and cfg.font or nil

    local size = nil
    if cfg.size then
      local sz = tonumber(cfg.size)
      if sz and sz > 0 then
        size = sz
      end
    end

    local flags = (cfg.flags and cfg.flags ~= "") and cfg.flags or nil

    local color1, color2, color3, color4 = nil, nil, nil, nil
    if cfg.color and type(cfg.color) == "table" then
      local c = cfg.color
      color1 = tonumber(c.r or c[1]) or 1
      color2 = tonumber(c.g or c[2]) or 1
      color3 = tonumber(c.b or c[3]) or 1
      color4 = tonumber(c.a or c[4]) or 1
    end

    local offsetX = nil
    if cfg.offsetX ~= nil then
      offsetX = tonumber(cfg.offsetX) or 0
    end

    local offsetY = nil
    if cfg.offsetY ~= nil then
      offsetY = tonumber(cfg.offsetY) or 0
    end

    local point = type(cfg.point) == "string" and cfg.point or nil

    local cached = bucket[role]
    if cached
      and cached.source == cfg
      and cached.font == font
      and cached.size == size
      and cached.flags == flags
      and cached.color1 == color1
      and cached.color2 == color2
      and cached.color3 == color3
      and cached.color4 == color4
      and cached.offsetX == offsetX
      and cached.offsetY == offsetY
      and cached.point == point
    then
      return cached.opts
    end

    cached = cached or {}
    local opts = cached.opts or { role = role }

    opts.role = role
    opts.scope = "cooldownManager"
    opts.font = font
    opts.size = size
    opts.flags = flags
    opts.offsetX = offsetX
    opts.offsetY = offsetY
    opts.point = point

    if color1 ~= nil then
      local c = opts.color
      if type(c) ~= "table" then
        c = {}
        opts.color = c
      end
      c[1], c[2], c[3], c[4] = color1, color2, color3, color4
    else
      opts.color = nil
    end

    cached.source = cfg
    cached.font = font
    cached.size = size
    cached.flags = flags
    cached.color1 = color1
    cached.color2 = color2
    cached.color3 = color3
    cached.color4 = color4
    cached.offsetX = offsetX
    cached.offsetY = offsetY
    cached.point = point
    cached.opts = opts
    bucket[role] = cached

    return opts
  end

  local function _GetModuleDB()
    local root = Addon.db and Addon.db.profile
    if not root then
      return nil
    end

    root.cooldownManager = root.cooldownManager or {}
    local cm = root.cooldownManager

    if cm.enabled == nil then
      cm.enabled = true
    end

    return cm
  end

  local function _ClampBorderThickness(v)
    v = tonumber(v) or 0
    if v < 0 then v = 0 end
    if v > 8 then v = 8 end
    return v
  end

  local function _GetBorderDB()
    local db = _GetModuleDB()
    if not db then
      return nil
    end

    db.borders = db.borders or {}
    local b = db.borders

    -- Schema:
    b.module = b.module or {}
    b.viewer = b.viewer or {}
    b.viewer.viewers = b.viewer.viewers or {}

    local m = b.module

    if m.thickness == nil then
      m.thickness = 2
    end
    if m.color == nil then
      m.color = { 0.20, 0.20, 0.24, 1.00 }
    end

    return b
  end

  -- Runtime helper: resolve the effective border config for a viewer.
  -- This matches the config schema (borders.module + borders.viewer.viewers[viewerKey]).
  local _PUI_PCM_BorderCfgCache = {}

  local function GetBorderConfig(viewerKey)
    local b = _GetBorderDB()
    if not b or not viewerKey then
      return nil
    end

    local m = b.module
    local v = b.viewer.viewers[viewerKey]

    -- 1) Module-level defaults
    local enabled = true
    if m.enabled ~= nil then
      enabled = (m.enabled == true)
    end

    local thickness = m.thickness
    local color = m.color

    -- 2) Per-viewer overrides (no useModule, always override when set)
    if type(v) == "table" then
      if v.enabled ~= nil then
        enabled = (v.enabled == true)
      end

      if v.thickness ~= nil then
        thickness = v.thickness
      end

      if v.color ~= nil then
        color = v.color
      end
    end

    thickness = _ClampBorderThickness(thickness)

    local color1, color2, color3, color4 = nil, nil, nil, nil
    if type(color) == "table" then
      color1 = tonumber(color.r or color[1]) or 1
      color2 = tonumber(color.g or color[2]) or 1
      color3 = tonumber(color.b or color[3]) or 1
      color4 = tonumber(color.a or color[4]) or 1
    end

    local cached = _PUI_PCM_BorderCfgCache[viewerKey]
    if cached
      and cached.enabled == enabled
      and cached.thickness == thickness
      and cached.colorSource == color
      and cached.color1 == color1
      and cached.color2 == color2
      and cached.color3 == color3
      and cached.color4 == color4
    then
      return cached.value
    end

    cached = cached or {}
    local out = cached.value or {}

    out.enabled = enabled
    out.thickness = thickness

    if color1 ~= nil then
      local c = out.color
      if type(c) ~= "table" then
        c = {}
        out.color = c
      end
      c[1], c[2], c[3], c[4] = color1, color2, color3, color4
      c.r, c.g, c.b, c.a = color1, color2, color3, color4
    else
      out.color = nil
    end

    cached.enabled = enabled
    cached.thickness = thickness
    cached.colorSource = color
    cached.color1 = color1
    cached.color2 = color2
    cached.color3 = color3
    cached.color4 = color4
    cached.value = out
    _PUI_PCM_BorderCfgCache[viewerKey] = cached

    return out
  end
  local function SetViewerBorderThickness(viewerKey, v)
    local b = _GetBorderDB()
    if not b or not viewerKey then
      return
    end

    b.viewer = b.viewer or {}
    b.viewer.viewers = b.viewer.viewers or {}

    b.viewer.viewers[viewerKey] = b.viewer.viewers[viewerKey] or {}

    local n = _ClampBorderThickness(v)
    b.viewer.viewers[viewerKey].thickness = n
  end

  local function SetViewerBorderColor(viewerKey, r, g, b, a)
    local bd = _GetBorderDB()
    if not bd or not viewerKey then
      return
    end

    bd.viewer = bd.viewer or {}
    bd.viewer.viewers = bd.viewer.viewers or {}

    bd.viewer.viewers[viewerKey] = bd.viewer.viewers[viewerKey] or {}

    local c = {
      r = tonumber(r) or 1,
      g = tonumber(g) or 1,
      b = tonumber(b) or 1,
      a = tonumber(a) or 1,
    }

    bd.viewer.viewers[viewerKey].color = c
  end

  local function _GetEffectsDB()
    local db = Addon.db and Addon.db.profile and Addon.db.profile.cooldownManager
    if not db then
      return nil
    end

    db.effects = db.effects or {}
    return db.effects
  end

  local function _GetGlowDB()
    local db = Addon.db and Addon.db.profile and Addon.db.profile.cooldownManager
    if not db then
      return nil
    end

    db.glow = db.glow or {
      enabled   = true,
      type      = "pixel",
      color     = { 0.95, 0.95, 0.32, 1 },
      speed     = 100,
      scale     = 1.0,
      lines     = 8,
      thickness = 2,
    }

    local g = db.glow

    if g.color == nil then
      g.color = { 0.95, 0.95, 0.32, 1 }
    end
    if g.speed == nil then
      g.speed = 100
    end
    if g.scale == nil then
      g.scale = 1.0
    end
    if g.lines == nil then
      g.lines = 8
    end
    if g.thickness == nil then
      g.thickness = 2
    end
    if g.type == nil then
      g.type = "pixel"
    end
    if g.enabled == nil then
      g.enabled = true
    end

    return g
  end

  local function _GetViewerEffects(viewerKey)
    local db = _GetEffectsDB()
    if not db or not viewerKey then
      return nil
    end

    db.viewer = db.viewer or {}
    db.viewer[viewerKey] = db.viewer[viewerKey] or {}

    return db.viewer[viewerKey]
  end

  local function _ResolveEffectFlag(v, default)
    if v == nil then
      return default == true
    end
    return v == true
  end

  local function _HideSpecialEffectFrame(button, viewerKey, effectName, defaultEnabled)
    if not button or not viewerKey then
      return
    end

    local cfg = _GetViewerEffects(viewerKey)
    if not cfg then
      return
    end

    local function flag(name)
      return _ResolveEffectFlag(cfg[name], defaultEnabled)
    end

    local shouldHide = flag(effectName)

    local fx = button[effectName]
    if fx and fx.Hide then
      if shouldHide then
        fx:Hide()
      end
    end
  end

  local function _GetViewerKeyFromButton(button)
    if not button then
      return nil
    end

    local viewer = button.viewer or button.Viewer or button:GetParent()
    if not viewer then
      return nil
    end

    if viewer.GetName then
      return viewer:GetName()
    end

    return nil
  end

  local function _HideBlizzardEffects(button)
    if not button then
      return
    end

    local viewerKey = _GetViewerKeyFromButton(button)
    if not viewerKey then
      return
    end

    _HideSpecialEffectFrame(button, viewerKey, "PandemicIcon", true)
    _HideSpecialEffectFrame(button, viewerKey, "ProcStartFlipbook", true)
    _HideSpecialEffectFrame(button, viewerKey, "ProcFinish", true)
  end

  local function _InstallEffectsHooks(itemFrame)
    if not itemFrame then
      return
    end

    local fd = Hooks.GetFrameData(itemFrame)
    if fd.effectsHooked then
      return
    end
    fd.effectsHooked = true

    if itemFrame.PandemicIcon then
      Hooks.HookMethod(itemFrame.PandemicIcon, "Show", "DB_Effects_PandemicIcon_Show", function()
        _HideBlizzardEffects(itemFrame)
      end)
    end
    if itemFrame.ProcStartFlipbook then
      Hooks.HookMethod(itemFrame.ProcStartFlipbook, "Show", "DB_Effects_ProcStartFlipbook_Show", function()
        _HideBlizzardEffects(itemFrame)
      end)
    end
    if itemFrame.ProcFinish then
      Hooks.HookMethod(itemFrame.ProcFinish, "Show", "DB_Effects_ProcFinish_Show", function()
        _HideBlizzardEffects(itemFrame)
      end)
    end
  end

  local function _SetViewerSwipeFlag(viewerKey, field, value)
    local db = ns.PCM_DBExports.GetViewerSwipeDB(viewerKey)
    if not db then return end
    db[field] = value == true
  end

  local function _GetViewerDB()
    local root = Addon.db
    if not (root and root.profile) then
      return nil
    end

    root.profile.cooldownManager = root.profile.cooldownManager or {}
    root.profile.cooldownManager.viewers = root.profile.cooldownManager.viewers or {}

    return root.profile.cooldownManager.viewers
  end

  local _PUI_PCM_DEFAULT_VIEWER_POS = {}

  local function _SavePosition(frame, key)
    if not frame or not key then return end
    local db = _GetViewerDB()
    if not db then return end

    local point, relTo, relPoint, x, y = frame:GetPoint(1)
    if not point then return end

    local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
    if not relName or relName == "" then
      relName = "UIParent"
    end

    db[key] = {
      point    = point,
      rel      = relName,
      relPoint = relPoint or point,
      x        = Round(x or 0),
      y        = Round(y or 0),
    }
  end

  local function _CaptureDefaultPosition(frame, key)
    if not frame or not key then return end
    if _PUI_PCM_DEFAULT_VIEWER_POS[key] then
      return
    end

    local point, relTo, relPoint, x, y = frame:GetPoint(1)
    if not point then
      return
    end

    local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
    if not relName or relName == "" then
      relName = "UIParent"
    end

    _PUI_PCM_DEFAULT_VIEWER_POS[key] = {
      point    = point,
      rel      = relName,
      relPoint = relPoint or point,
      x        = Round(x or 0),
      y        = Round(y or 0),
    }
  end

  local function _ClearSavedPosition(key)
    if not key then return end
    local db = _GetViewerDB()
    if not db then return end
    db[key] = nil
  end

  -- Applies saved position when present, otherwise restores the session-captured default.
  -- NOTE: Call _CaptureDefaultPosition(frame, key) once right after you create/anchor the viewer initially.
  local function _ApplySavedOrDefaultPosition(frame, key)
    if not frame or not key then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end

    _CaptureDefaultPosition(frame, key)

    local db = _GetViewerDB()
    local pos = db and db[key] or nil
    local use = pos or _PUI_PCM_DEFAULT_VIEWER_POS[key]
    if not use then
      return false
    end

    local rel = UIParent
    if use.rel and use.rel ~= "" and use.rel ~= "UIParent" then
      local r = _G[use.rel]
      if r then
        rel = r
      end
    end

    if frame.ClearAllPoints and frame.SetPoint then
      frame:ClearAllPoints()
      frame:SetPoint(use.point or "CENTER", rel, use.relPoint or use.point or "CENTER", use.x or 0, use.y or 0)
      return true
    end

    return false
  end

  
  -- Spell Cooldown Bars DB (supports Shared + per-character Enable)
  

  local function _SpellBars_GetProfileRoot()
    local root = Addon.db and Addon.db.profile
    if not root then
      return nil
    end
    root.cooldownManager = root.cooldownManager or {}
    return root.cooldownManager
  end

  local function _SpellBars_GetProfileBars()
    local cm = _SpellBars_GetProfileRoot()
    if not cm then
      return nil
    end
    cm.spellBars = cm.spellBars or {}
    return cm.spellBars
  end


  local _PCM_SavedSpellKnownCache = {}

  local function _PCM_ClearSavedSpellKnownCache()
    for key in pairs(_PCM_SavedSpellKnownCache) do
      _PCM_SavedSpellKnownCache[key] = nil
    end
  end

  local function _PCM_GetCurrentSpecializationID()
    local specIndex = GetSpecialization()
    if not specIndex then
      return nil
    end

    return GetSpecializationInfo(specIndex)
  end

  local function _PCM_EnsureSpecAssignments(selfOrEntry, maybeEntry)
    local entry = maybeEntry or selfOrEntry
    if type(entry) ~= "table" then
      return nil
    end

    local assignments = {}

    if type(entry.specAssignments) == "table" then
      for rawSpecID, rawAssignment in pairs(entry.specAssignments) do
        local specID = tonumber(rawSpecID)
        if specID and specID > 0 and type(rawAssignment) == "table" then
          local spellID = tonumber(rawAssignment.spellID)
          if spellID and spellID <= 0 then
            spellID = nil
          end

          assignments[specID] = {
            enabled = rawAssignment.enabled ~= false,
            spellID = spellID,
            spellName = type(rawAssignment.spellName) == "string" and rawAssignment.spellName or nil,
            spellIcon = rawAssignment.spellIcon,
          }
        end
      end
    end

    entry.specAssignments = assignments

    local currentSpecID = _PCM_GetCurrentSpecializationID()
    local current = currentSpecID and assignments[currentSpecID] or nil

    if current and current.enabled ~= false and current.spellID then
      entry.trackedSpellID = current.spellID
      entry.trackedSpellName = current.spellName
      entry.trackedSpellIcon = current.spellIcon
    else
      entry.trackedSpellID = nil
      entry.trackedSpellName = nil
      entry.trackedSpellIcon = nil
    end

    return assignments
  end

  local function _PCM_GetCurrentSpecAssignment(selfOrEntry, maybeEntry)
    local entry = maybeEntry or selfOrEntry
    if type(entry) ~= "table" or type(entry.specAssignments) ~= "table" then
      return nil
    end

    local specID = _PCM_GetCurrentSpecializationID()
    if not specID then
      return nil
    end

    return entry.specAssignments[specID]
  end

  local function _PCM_GetTrackedSpellIDForCurrentSpec(selfOrEntry, maybeEntry)
    local entry = maybeEntry or selfOrEntry
    local assignment = _PCM_GetCurrentSpecAssignment(selfOrEntry, maybeEntry)
    local spellID = assignment and assignment.enabled ~= false and tonumber(assignment.spellID) or nil

    if not spellID or spellID <= 0 then
      if type(entry) == "table" then
        entry.trackedSpellID = nil
        entry.trackedSpellName = nil
        entry.trackedSpellIcon = nil
      end
      return nil
    end

    entry.trackedSpellID = spellID
    entry.trackedSpellName = assignment.spellName
    entry.trackedSpellIcon = assignment.spellIcon
    return spellID
  end

  local function _PCM_GetCustomBarDisplayName(selfOrEntry, maybeEntry)
    local entry = maybeEntry or selfOrEntry
    if type(entry) ~= "table" then
      return "Select a spell"
    end

    local assignments = _PCM_EnsureSpecAssignments(entry)
    local assignment = _PCM_GetCurrentSpecAssignment(entry)

    if not (assignment and assignment.spellID) then
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
    if not spellID or spellID <= 0 then
      return "Select a spell"
    end

    local spellName = C_Spell.GetSpellName(spellID) or assignment.spellName
    if type(spellName) ~= "string" or spellName == "" then
      return "Spell " .. tostring(spellID)
    end

    assignment.spellName = spellName
    return spellName
  end

  local function _PCM_AllowsCurrentSpec(selfOrEntry, maybeEntry)
    return _PCM_GetTrackedSpellIDForCurrentSpec(selfOrEntry, maybeEntry) ~= nil
  end

  local function _PCM_DoesPlayerKnowSavedSpell(selfOrSpellID, maybeSpellID, maybeRequireCharges)
    local spellID
    local requireCharges

    if type(selfOrSpellID) == "table" then
      spellID = tonumber(maybeSpellID)
      requireCharges = maybeRequireCharges == true
    else
      spellID = tonumber(selfOrSpellID)
      requireCharges = maybeSpellID == true
    end

    if not spellID or spellID <= 0 then
      return false
    end

    local currentSpecID = _PCM_GetCurrentSpecializationID() or 0
    local cacheKey = tostring(spellID) .. ":" .. tostring(currentSpecID) .. ":" .. (requireCharges and "charges" or "cooldown")
    local cached = _PCM_SavedSpellKnownCache[cacheKey]
    if cached ~= nil then
      return cached == true
    end

    if InCombatLockdown() then
      return false
    end

    local known = C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)

    _PCM_SavedSpellKnownCache[cacheKey] = known
    return known
  end

  local function SpellBars_GetEffectiveEnabled(key, entry)
    if type(entry) ~= "table" then
      return false
    end

    if entry.enabled == false then
      return false
    end

    return _PCM_AllowsCurrentSpec(entry) == true
  end

  local function SpellBars_SetEffectiveEnabled(key, enabled)
    local prof = _SpellBars_GetProfileBars()
    if prof and prof[key] and type(prof[key]) == "table" then
      prof[key].enabled = (enabled == true) and true or false
    end
  end

  local function SpellBars_DeleteEntry(key)
    local prof = _SpellBars_GetProfileBars()
    if prof and key ~= nil then
      prof[key] = nil
      return true
    end
    return false
  end

  local function _CooldownStackBars_GetProfileBars()
    local cm = _SpellBars_GetProfileRoot()
    if not cm then
      return nil
    end
    cm.cooldownStackBars = cm.cooldownStackBars or {}
    return cm.cooldownStackBars
  end



  local function CooldownStackBars_DeleteEntry(key)
    local prof = _CooldownStackBars_GetProfileBars()
    if prof and key ~= nil then
      prof[key] = nil
      return true
    end
    return false
  end

  local function NormalizeCustomBarBuffGlow(selfOrEntry, maybeEntry)
    local entry = maybeEntry or selfOrEntry
    if type(entry) ~= "table" then
      return entry
    end

    if entry.buffGlowEnabled == nil then
      entry.buffGlowEnabled = false
    else
      entry.buffGlowEnabled = entry.buffGlowEnabled == true
    end

    if entry.buffGlowSource ~= "CUSTOM" then
      entry.buffGlowSource = "CDM"
    end

    entry.buffGlowHideViewerIcon = entry.buffGlowHideViewerIcon == true

    local spellID = tonumber(entry.buffGlowSpellID)
    if spellID and spellID > 0 then
      entry.buffGlowSpellID = math_floor(spellID)
    else
      entry.buffGlowSpellID = nil
    end

    local thickness = tonumber(entry.buffGlowThickness)
    if thickness then
      thickness = math_floor(thickness + 0.5)
      if thickness < 1 then
        thickness = 1
      elseif thickness > 8 then
        thickness = 8
      end
      entry.buffGlowThickness = thickness
    else
      entry.buffGlowThickness = 2
    end

    local color = entry.buffGlowColor
    if type(color) == "table" then
      entry.buffGlowColor = {
        tonumber(color[1] or color.r) or 0.25,
        tonumber(color[2] or color.g) or 0.75,
        tonumber(color[3] or color.b) or 1,
        tonumber(color[4] or color.a) or 1,
      }
    else
      entry.buffGlowColor = { 0.25, 0.75, 1, 1 }
    end

    return entry
  end

  local function NormalizeCustomTrackerPresentation(selfOrEntry, maybeEntry, maybeKind)
    local entry = maybeKind ~= nil and maybeEntry or selfOrEntry
    local kind = maybeKind ~= nil and maybeKind or maybeEntry
    if type(entry) ~= "table" then
      return entry
    end

    entry.readyAlpha = tonumber(entry.readyAlpha) or 100
    entry.onCooldownAlpha = tonumber(entry.onCooldownAlpha) or 100
    entry.activeAlpha = tonumber(entry.activeAlpha) or 100
    if entry.readyAlpha < 0 then entry.readyAlpha = 0 end
    if entry.readyAlpha > 100 then entry.readyAlpha = 100 end
    if entry.onCooldownAlpha < 0 then entry.onCooldownAlpha = 0 end
    if entry.onCooldownAlpha > 100 then entry.onCooldownAlpha = 100 end
    if entry.activeAlpha < 0 then entry.activeAlpha = 0 end
    if entry.activeAlpha > 100 then entry.activeAlpha = 100 end
    -- direction: "fill" (ready = full) or "drain" (ready = empty)
    if entry.direction ~= "fill" and entry.direction ~= "drain" then
      entry.direction = "fill"
    end

    if entry.orientation ~= "horizontal" and entry.orientation ~= "vertical" then
      entry.orientation = "horizontal"
    end

    if entry.fillDirection ~= "LEFT"
      and entry.fillDirection ~= "RIGHT"
      and entry.fillDirection ~= "UP"
      and entry.fillDirection ~= "DOWN"
    then
      entry.fillDirection = entry.orientation == "vertical" and "UP" or "RIGHT"
    end

    entry.width  = tonumber(entry.width)  or 250
    local validStateGlowStyles = { NONE = true, PIXEL = true, AUTOCAST = true, PROC = true }
    if not validStateGlowStyles[entry.readyGlowStyle] then entry.readyGlowStyle = "NONE" end
    if not validStateGlowStyles[entry.cooldownGlowStyle] then entry.cooldownGlowStyle = "NONE" end
    if not validStateGlowStyles[entry.activeGlowStyle] then entry.activeGlowStyle = "NONE" end
    entry.readyGlowColor = type(entry.readyGlowColor) == "table"
      and entry.readyGlowColor or { 0.25, 0.75, 1, 1 }
    entry.cooldownGlowColor = type(entry.cooldownGlowColor) == "table"
      and entry.cooldownGlowColor or { 1, 0.55, 0.1, 1 }
    entry.activeGlowColor = type(entry.activeGlowColor) == "table"
      and entry.activeGlowColor or { 1, 0.55, 0.1, 1 }

    if entry.presentation ~= "BUTTON" then
      entry.presentation = "BAR"
      entry.icon = nil
      entry.views = nil
      return entry
    end
    entry.views = nil

    entry.icon = type(entry.icon) == "table" and entry.icon or {}
    local icon = entry.icon
    icon.size = tonumber(icon.size) or 40
    if icon.size < 20 then icon.size = 20 end
    if icon.size > 96 then icon.size = 96 end
    icon.pos = type(icon.pos) == "table" and icon.pos or {}

    local auraKind = kind == "stack" or kind == "duration"
    if icon.visibility ~= "ACTIVE" and (auraKind or icon.visibility ~= "INACTIVE") then
      icon.visibility = "ALWAYS"
    end
    icon.combatOnly = icon.combatOnly == true
    icon.outOfCombatAlpha = tonumber(icon.outOfCombatAlpha) or 0
    if icon.outOfCombatAlpha < 0 then icon.outOfCombatAlpha = 0 end
    if icon.outOfCombatAlpha > 100 then icon.outOfCombatAlpha = 100 end
    icon.readyAlpha = tonumber(icon.readyAlpha) or 35
    if icon.readyAlpha < 0 then icon.readyAlpha = 0 end
    if icon.readyAlpha > 100 then icon.readyAlpha = 100 end
    icon.onCooldownAlpha = tonumber(icon.onCooldownAlpha) or 100
    if icon.onCooldownAlpha < 0 then icon.onCooldownAlpha = 0 end
    if icon.onCooldownAlpha > 100 then icon.onCooldownAlpha = 100 end
    if icon.desaturateReady == nil then icon.desaturateReady = true end
    if icon.desaturateCooldown == nil then icon.desaturateCooldown = false end
    if icon.showSwipe == nil then icon.showSwipe = true end
    if icon.showDuration == nil then icon.showDuration = true end
    if icon.showCount == nil then icon.showCount = kind == "charge" or kind == "stack" end
    if icon.showPips == nil then icon.showPips = false end
    if icon.showStackStrip == nil then icon.showStackStrip = kind == "stack" end
    if icon.showTooltip == nil then icon.showTooltip = true end

    icon.desaturateReady = icon.desaturateReady == true
    icon.desaturateCooldown = icon.desaturateCooldown == true
    icon.showSwipe = icon.showSwipe == true
    icon.showDuration = icon.showDuration == true
    icon.showCount = icon.showCount == true
    icon.showPips = icon.showPips == true
    icon.showStackStrip = icon.showStackStrip == true
    icon.showTooltip = icon.showTooltip == true

    icon.borderSize = math_floor((tonumber(icon.borderSize) or 2) + 0.5)
    if icon.borderSize < 0 then icon.borderSize = 0 end
    if icon.borderSize > 8 then icon.borderSize = 8 end
    icon.borderColor = type(icon.borderColor) == "table" and icon.borderColor or { 0.10, 0.10, 0.12, 1 }
    icon.backgroundColor = type(icon.backgroundColor) == "table" and icon.backgroundColor or { 0.03, 0.03, 0.04, 1 }
    icon.fontSize = math_floor((tonumber(icon.fontSize) or 14) + 0.5)
    if icon.fontSize < 8 then icon.fontSize = 8 end
    if icon.fontSize > 28 then icon.fontSize = 28 end
    icon.countFontSize = math_floor((tonumber(icon.countFontSize) or 13) + 0.5)
    if icon.countFontSize < 8 then icon.countFontSize = 8 end
    if icon.countFontSize > 28 then icon.countFontSize = 28 end
    icon.font = type(icon.font) == "string" and icon.font ~= "" and icon.font or nil
    icon.outline = type(icon.outline) == "string" and icon.outline ~= "" and icon.outline or "OUTLINE"

    local validAnchors = {
      CENTER = true,
      TOP = true,
      BOTTOM = true,
      LEFT = true,
      RIGHT = true,
      TOPLEFT = true,
      TOPRIGHT = true,
      BOTTOMLEFT = true,
      BOTTOMRIGHT = true,
    }
    if not validAnchors[icon.durationTextAnchor] then icon.durationTextAnchor = "CENTER" end
    if not validAnchors[icon.countTextAnchor] then icon.countTextAnchor = "BOTTOMRIGHT" end
    icon.durationTextX = math_floor((tonumber(icon.durationTextX) or 0) + 0.5)
    icon.durationTextY = math_floor((tonumber(icon.durationTextY) or 0) + 0.5)
    icon.countTextX = math_floor((tonumber(icon.countTextX) or -2) + 0.5)
    icon.countTextY = math_floor((tonumber(icon.countTextY) or 2) + 0.5)
    if icon.durationTextX < -50 then icon.durationTextX = -50 end
    if icon.durationTextX > 50 then icon.durationTextX = 50 end
    if icon.durationTextY < -50 then icon.durationTextY = -50 end
    if icon.durationTextY > 50 then icon.durationTextY = 50 end
    if icon.countTextX < -50 then icon.countTextX = -50 end
    if icon.countTextX > 50 then icon.countTextX = 50 end
    if icon.countTextY < -50 then icon.countTextY = -50 end
    if icon.countTextY > 50 then icon.countTextY = 50 end
    icon.durationTextScale = math_floor((tonumber(icon.durationTextScale) or 100) + 0.5)
    icon.countTextScale = math_floor((tonumber(icon.countTextScale) or 100) + 0.5)
    if icon.durationTextScale < 50 then icon.durationTextScale = 50 end
    if icon.durationTextScale > 200 then icon.durationTextScale = 200 end
    if icon.countTextScale < 50 then icon.countTextScale = 50 end
    if icon.countTextScale > 200 then icon.countTextScale = 200 end
    icon.durationTextColor = type(icon.durationTextColor) == "table" and icon.durationTextColor or { 1, 1, 1, 1 }
    icon.countTextColor = type(icon.countTextColor) == "table" and icon.countTextColor or { 1, 1, 1, 1 }

    if icon.chromeStyle ~= "SQUARE" and icon.chromeStyle ~= "BLIZZARD" then
      icon.chromeStyle = "PLEEBUI"
    end
    local validGlowStyles = {
      NONE = true,
      PIXEL = true,
      AUTOCAST = true,
      PROC = true,
    }
    icon.cooldownGlowStyle = icon.cooldownGlowStyle or "NONE"
    icon.readyGlowStyle = icon.readyGlowStyle or "NONE"
    if not validGlowStyles[icon.cooldownGlowStyle] then icon.cooldownGlowStyle = "NONE" end
    if not validGlowStyles[icon.readyGlowStyle] then icon.readyGlowStyle = "NONE" end
    icon.cooldownGlowColor = type(icon.cooldownGlowColor) == "table" and icon.cooldownGlowColor or { 1, 0.55, 0.1, 1 }
    icon.readyGlowColor = type(icon.readyGlowColor) == "table" and icon.readyGlowColor or { 0.25, 0.75, 1, 1 }
    if icon.activeAuraEnabled == nil then icon.activeAuraEnabled = false end
    icon.activeAuraEnabled = icon.activeAuraEnabled == true
    icon.activeAuraAlpha = tonumber(icon.activeAuraAlpha) or 100
    if icon.activeAuraAlpha < 0 then icon.activeAuraAlpha = 0 end
    if icon.activeAuraAlpha > 100 then icon.activeAuraAlpha = 100 end
    icon.activeAuraDesaturate = icon.activeAuraDesaturate == true
    if not validGlowStyles[icon.activeAuraGlowStyle] then icon.activeAuraGlowStyle = "NONE" end
    icon.activeAuraGlowColor = type(icon.activeAuraGlowColor) == "table"
      and icon.activeAuraGlowColor or { 1, 0.55, 0.1, 1 }

    return entry
  end

  local function NormalizeCooldownStackBarEntry(entry, id)
    if type(entry) ~= "table" then
      entry = {}
    end

    if id and entry.id == nil then
      entry.id = id
    end

    NormalizeCustomBarBuffGlow(entry)
    NormalizeCustomTrackerPresentation(entry, "charge")

    if entry.enabled == nil then
      entry.enabled = true
    end
    if entry.hideOutOfCombat == nil then
      entry.hideOutOfCombat = false
    end
    if entry.outOfCombatAlpha == nil then
      entry.outOfCombatAlpha = 0
    end

    if type(entry.label) ~= "string" or entry.label == "" then
      entry.label = "Charge Cooldown Bar " .. tostring(entry.id or id or "")
    end

    _PCM_EnsureSpecAssignments(entry)

    entry.width = tonumber(entry.width) or 250
    entry.height = tonumber(entry.height) or 25
    if entry.width < 80 then entry.width = 80 end
    if entry.width > 600 then entry.width = 600 end
    if entry.height < 6 then entry.height = 6 end
    if entry.height > 80 then entry.height = 80 end

    entry.texture = (type(entry.texture) == "string" and entry.texture ~= "") and entry.texture or "Pleebar"

    if entry.showIcon == nil then
      entry.showIcon = true
    else
      entry.showIcon = not not entry.showIcon
    end

    if entry.useClassColor == nil then
      entry.useClassColor = true
    else
      entry.useClassColor = not not entry.useClassColor
    end

    if entry.orientation ~= "horizontal" and entry.orientation ~= "vertical" then
      entry.orientation = "horizontal"
    end

    if entry.fillDirection ~= "LEFT"
      and entry.fillDirection ~= "RIGHT"
      and entry.fillDirection ~= "UP"
      and entry.fillDirection ~= "DOWN"
    then
      entry.fillDirection = entry.orientation == "vertical" and "UP" or "RIGHT"
    end

    if entry.durationBarFillMode ~= "fill" and entry.durationBarFillMode ~= "drain" then
      entry.durationBarFillMode = "fill"
    end

    entry.maxCharges = tonumber(entry.maxCharges) or 2
    if entry.maxCharges < 2 then entry.maxCharges = 2 end
    if entry.maxCharges > 3 then entry.maxCharges = 3 end

    if entry.showText == nil then
      entry.showText = true
    else
      entry.showText = not not entry.showText
    end

    entry.fontSize = tonumber(entry.fontSize) or 14
    if entry.fontSize < 8 then entry.fontSize = 8 end
    if entry.fontSize > 28 then entry.fontSize = 28 end

    if type(entry.font) ~= "string" or entry.font == "" then
      entry.font = Theme.GetFont("cooldown")
    end

    if type(entry.fontOutline) ~= "string" or entry.fontOutline == "" then
      entry.fontOutline = Theme.GetFontRoleInfo("cooldown").outline or "OUTLINE"
    end

    if type(entry.fontColor) ~= "table" then
      local color = Theme.GetColors().text
      entry.fontColor = { color[1], color[2], color[3], color[4] }
    end

    if type(entry.barColor) ~= "table" then
      entry.barColor = nil
    end

    if type(entry.borderColor) ~= "table" then
      entry.borderColor = nil
    end

    if entry.showSlotBorder == nil then
      entry.showSlotBorder = true
    else
      entry.showSlotBorder = not not entry.showSlotBorder
    end

    if type(entry.slotBorderColor) ~= "table" then
      entry.slotBorderColor = { 0.20, 0.20, 0.24, 1.00 }
    end

    entry.slotBorderThickness = tonumber(entry.slotBorderThickness)
    if entry.slotBorderThickness == nil then entry.slotBorderThickness = 2 end
    if entry.slotBorderThickness < 0 then entry.slotBorderThickness = 0 end
    if entry.slotBorderThickness > 5 then entry.slotBorderThickness = 5 end

    entry.slotSpacing = tonumber(entry.slotSpacing) or 0
    if entry.slotSpacing < 0 then entry.slotSpacing = 0 end
    if entry.slotSpacing > 20 then entry.slotSpacing = 20 end

    if type(entry.slotBackgroundColor) ~= "table" then
      entry.slotBackgroundColor = { 0.12, 0.12, 0.12, 0.95 }
    end

    entry.opacity = tonumber(entry.opacity) or 1
    if entry.opacity < 0 then entry.opacity = 0 end
    if entry.opacity > 1 then entry.opacity = 1 end

    entry.useDifferentFullColor = entry.useDifferentFullColor == true
    if type(entry.fullChargeColor) ~= "table" then
      entry.fullChargeColor = { 1, 1, 1, 1 }
    end

    entry.usePerSlotColors = entry.usePerSlotColors == true
    for index = 1, 60 do
      local field = "chargeSlot" .. index .. "Color"
      if entry[field] ~= nil and type(entry[field]) ~= "table" then
        entry[field] = nil
      end
    end

    if entry.rotateTexture ~= true and entry.rotateTexture ~= false then
      entry.rotateTexture = nil
    end
    if entry.dynamicTextOnSlot == nil then
      entry.dynamicTextOnSlot = true
    else
      entry.dynamicTextOnSlot = not not entry.dynamicTextOnSlot
    end

    local root = _CooldownStackBars_GetProfileBars()
    if root and id ~= nil and root[id] ~= entry then
      root[id] = entry
    end

    return entry
  end



  local function NormalizeSpellBarEntry(entry, id)
    if type(entry) ~= "table" then
      entry = {}
    end

    if id and entry.id == nil then
      entry.id = id
    end

    NormalizeCustomBarBuffGlow(entry)
    NormalizeCustomTrackerPresentation(entry, "cooldown")

    if entry.enabled == nil then
      entry.enabled = true
    end
    if entry.hideOutOfCombat == nil then
      entry.hideOutOfCombat = false
    end
    if entry.outOfCombatAlpha == nil then
      entry.outOfCombatAlpha = 0
    end

    -- Visibility settings

    if type(entry.label) ~= "string" or entry.label == "" then
      entry.label = "Cooldown Bar " .. tostring(entry.id or id or "")
    end

    _PCM_EnsureSpecAssignments(entry)

    -- direction: "fill" (ready = full) or "drain" (ready = empty)
    if entry.direction ~= "fill" and entry.direction ~= "drain" then
      entry.direction = "fill"
    end

    if entry.orientation ~= "horizontal" and entry.orientation ~= "vertical" then
      entry.orientation = "horizontal"
    end

    if entry.fillDirection ~= "LEFT"
      and entry.fillDirection ~= "RIGHT"
      and entry.fillDirection ~= "UP"
      and entry.fillDirection ~= "DOWN"
    then
      entry.fillDirection = entry.orientation == "vertical" and "UP" or "RIGHT"
    end

    entry.width  = tonumber(entry.width)  or 250
    entry.height = tonumber(entry.height) or 25
    if entry.width < 80 then entry.width = 80 end
    if entry.width > 600 then entry.width = 600 end
    if entry.height < 6 then entry.height = 6 end
    if entry.height > 40 then entry.height = 40 end

    if entry.mode ~= "charge_cooldown" then
      entry.mode = "cooldown"
    end

    if entry.mode == "charge_cooldown" then
      local maxCharges = tonumber(entry.maxCharges) or 2
      if maxCharges < 2 then maxCharges = 2 end
      if maxCharges > 3 then maxCharges = 3 end
      entry.maxCharges = maxCharges
    else
      entry.maxCharges = nil
    end

    entry.texture = (type(entry.texture) == "string" and entry.texture ~= "") and entry.texture or "Pleebar"

    entry.fontSize = tonumber(entry.fontSize) or 14

    if entry.showText == nil then
      entry.showText = true
    else
      entry.showText = not not entry.showText
    end

    if entry.useClassColor == nil then
      entry.useClassColor = true
    else
      entry.useClassColor = not not entry.useClassColor
    end

    if type(entry.font) ~= "string" or entry.font == "" then
      entry.font = Theme.GetFont("cooldown")
    end

    if type(entry.fontOutline) ~= "string" or entry.fontOutline == "" then
      entry.fontOutline = Theme.GetFontRoleInfo("cooldown").outline or "OUTLINE"
    end

    if type(entry.fontColor) ~= "table" then
      local color = Theme.GetColors().text
      entry.fontColor = { color[1], color[2], color[3], color[4] }
    end

    -- Seed barColor to class color if requested and missing/invalid
    if entry.useClassColor and type(entry.barColor) ~= "table" then
      local cc = RAID_CLASS_COLORS[PLAYER_CLASS]
      entry.barColor = { cc.r, cc.g, cc.b, 1 }
    end
    if entry.fontSize < 8 then entry.fontSize = 8 end
    if entry.fontSize > 28 then entry.fontSize = 28 end

    if entry.showIcon == nil then
      entry.showIcon = true
    else
      entry.showIcon = not not entry.showIcon
    end

    if entry.useClassColor ~= nil then
      entry.useClassColor = not not entry.useClassColor
    end

    entry.font = (type(entry.font) == "string" and entry.font ~= "") and entry.font or nil
    entry.fontOutline = (type(entry.fontOutline) == "string" and entry.fontOutline ~= "") and entry.fontOutline or nil
    if type(entry.fontColor) ~= "table" then
      entry.fontColor = nil
    end

    if entry.orientation == "vertical" then
      if entry.iconAnchor ~= "top" and entry.iconAnchor ~= "bottom" then
        entry.iconAnchor = "top"
      end
    elseif entry.iconAnchor ~= "left" and entry.iconAnchor ~= "right" then
      entry.iconAnchor = "left"
    end

    if type(entry.barColor) ~= "table" then
      entry.barColor = nil
    end

    if type(entry.borderColor) ~= "table" then
      entry.borderColor = nil
    end

    entry.borderSize = tonumber(entry.borderSize) or 2
    if entry.borderSize < 0 then entry.borderSize = 0 end
    if entry.borderSize > 6 then entry.borderSize = 6 end

    if type(entry.backgroundColor) ~= "table" then
      local color = entry.borderColor or { 0.12, 0.12, 0.12, 0.955 }
      entry.backgroundColor = {
        color[1] or color.r or 0.12,
        color[2] or color.g or 0.12,
        color[3] or color.b or 0.12,
        color[4] or color.a or 0.955,
      }
    end

    -- Ensure the normalized entry is written back into the DB table.
    if id ~= nil then
      local root = _SpellBars_GetProfileBars()
      if root and root[id] ~= entry then
        root[id] = entry
      end
    end

    return entry
  end

  -- Export helpers onto the module table.
  Cooldowns.GetViewerSwipeDB = GetViewerSwipeDB
  Cooldowns.GetViewerSwipeEntry = GetViewerSwipeEntry
  Cooldowns.NormalizeSwipeEntry = NormalizeSwipeEntry
  Cooldowns._ResolveFontOpts = _ResolveFontOpts
  Cooldowns._GetBorderDB = _GetBorderDB
  Cooldowns.GetBorderConfig = GetBorderConfig
  Cooldowns.SetViewerBorderThickness = SetViewerBorderThickness
  Cooldowns.SetViewerBorderColor     = SetViewerBorderColor
  Cooldowns._ClampBorderThickness = _ClampBorderThickness
  Cooldowns._EnsureFontOffsets = _EnsureFontOffsets
  Cooldowns._GetEffectsDB = _GetEffectsDB
  Cooldowns._GetGlowDB = _GetGlowDB
  Cooldowns._GetFixedWidthForViewer = _GetFixedWidthForViewer
  Cooldowns._GetFontDB = _GetFontDB
  Cooldowns._GetIconSizeForViewer = _GetIconSizeForViewer
  Cooldowns._GetIconSpacingForViewer = _GetIconSpacingForViewer
  Cooldowns._GetModuleDB = _GetModuleDB
  Cooldowns._GetViewerDB = _GetViewerDB
  Cooldowns._GetViewerEffects = _GetViewerEffects

  -- Spell Bars DB
  Cooldowns.GetSpellBarsDB = _SpellBars_GetProfileBars
  Cooldowns.NormalizeCustomBarBuffGlow = NormalizeCustomBarBuffGlow
  Cooldowns.NormalizeCustomTrackerPresentation = NormalizeCustomTrackerPresentation
  Cooldowns.NormalizeSpellBarEntry = NormalizeSpellBarEntry
  Cooldowns.SpellBars_GetEffectiveEnabled = SpellBars_GetEffectiveEnabled
  Cooldowns.NormalizeSpecAssignments = _PCM_EnsureSpecAssignments
  Cooldowns.GetCurrentSpecializationID = _PCM_GetCurrentSpecializationID
  Cooldowns.GetCurrentSpecAssignment = _PCM_GetCurrentSpecAssignment
  Cooldowns.GetTrackedSpellIDForCurrentSpec = _PCM_GetTrackedSpellIDForCurrentSpec
  Cooldowns.GetCustomBarDisplayName = _PCM_GetCustomBarDisplayName
  Cooldowns.AllowsCurrentSpecialization = _PCM_AllowsCurrentSpec
  Cooldowns.ShouldShowSpellBarForCurrentSpec = _PCM_AllowsCurrentSpec
  Cooldowns.ShouldShowCooldownStackBarForCurrentSpec = _PCM_AllowsCurrentSpec
  Cooldowns.DoesPlayerKnowSavedSpell = _PCM_DoesPlayerKnowSavedSpell
  Cooldowns.ClearSavedSpellKnownCache = _PCM_ClearSavedSpellKnownCache
  Cooldowns.SpellBars_SetEffectiveEnabled = SpellBars_SetEffectiveEnabled
  Cooldowns.SpellBars_DeleteEntry = SpellBars_DeleteEntry
  Cooldowns.GetCooldownStackBarsDB = _CooldownStackBars_GetProfileBars
  Cooldowns.NormalizeCooldownStackBarEntry = NormalizeCooldownStackBarEntry
  Cooldowns.CooldownStackBars_DeleteEntry = CooldownStackBars_DeleteEntry
  Cooldowns._GetViewerKeyFromButton = _GetViewerKeyFromButton
  Cooldowns._GetWidthModeForViewer = _GetWidthModeForViewer
  Cooldowns._HasAnyFontField = _HasAnyFontField
  Cooldowns._HideBlizzardEffects = _HideBlizzardEffects
  Cooldowns._HideSpecialEffectFrame = _HideSpecialEffectFrame
  Cooldowns._InstallEffectsHooks = _InstallEffectsHooks
  Cooldowns._ResolveEffectFlag = _ResolveEffectFlag
  Cooldowns._SavePosition = _SavePosition
  Cooldowns._CaptureDefaultPosition = _CaptureDefaultPosition
  Cooldowns._ClearSavedPosition = _ClearSavedPosition
  Cooldowns._ApplySavedOrDefaultPosition = _ApplySavedOrDefaultPosition
  Cooldowns._SetViewerSwipeFlag = _SetViewerSwipeFlag


  -- Mark successful attach so runtime can detect missing DB wiring.
  Cooldowns.__pui_pcm_db_attached = true
end



-- Central shared DB exports (all PCM runtime files must use these)
ns.PCM_DBExports = {}
local E = ns.PCM_DBExports
E.Attach = _PCM_DB_Attach
local CMSubDBCache = {
  profile = nil,
  cm = nil,
  fields = {},
}
local ConsumableTrackerDBCache = {
  profile = nil,
  cfg = nil,
}
local VIEWER_COUNT_DEFAULTS = {
  cooldown = true,
  buff = true,
  charge = true,
  keybind = true,
}
do

  function E.GetDB()
    return Addon.db
  end

  function E.GetProfile()
    local db = Addon.db
    return db and db.profile or nil
  end

  function E.GetPCMRoot()
    local root = E.GetProfile()
    if not root then
      return nil
    end

    root.cooldownManager = root.cooldownManager or {}
    return root.cooldownManager
  end

  function E.GetViewerSwipeDB(viewerKey)
    if not viewerKey then
      return nil
    end

    local root = E.GetPCMRoot()
    if not root then
      return nil
    end

    root.viewerSwipes = root.viewerSwipes or {}
    root.viewerSwipes[viewerKey] = root.viewerSwipes[viewerKey] or {}
    local entry = root.viewerSwipes[viewerKey]

    if entry.gcd == nil then entry.gcd = true end
    if entry.cooldown == nil then entry.cooldown = true end
    if entry.duration == nil then entry.duration = true end
    if entry.drawEdge == nil then entry.drawEdge = true end
    if entry.swipeColor == nil then entry.swipeColor = { 0, 0, 0, 0.8 } end
    if entry.forceCooldownSwipe == nil then entry.forceCooldownSwipe = false end

    entry.__puiSeeded = nil
    entry.enabled = nil
    entry.showCount = nil
    entry.showSwipe = nil
    entry.mode = nil

    return entry
  end

  function E.GetProfileBuffsDB()
    local db = E.GetDB()
    if not (db and db.profile) then
      return nil
    end

    local root = db.profile
    local cm = root.pcmBuffs

    if type(cm) ~= "table" then
      cm = {}
      root.pcmBuffs = cm
    end

    cm.style   = cm.style   or {}
    cm.borders = cm.borders or {}

    local style = cm.style
    style.viewerSizes   = style.viewerSizes   or {}
    style.viewerSpacing = style.viewerSpacing or {}
    style.viewerColumns = style.viewerColumns or {}
    style.viewerGrowth  = style.viewerGrowth  or {}

    if style.iconSize == nil then style.iconSize = 36 end
    if style.iconSpacing == nil then style.iconSpacing = 1 end

    return cm
  end

  function E.GetProfileBuffsAnchorDB()
    local cm = E.GetProfileBuffsDB()
    if not cm then
      return nil
    end

    cm.anchor = cm.anchor or {}
    return cm.anchor
  end

  function E.GetProfileBuffsViewerFontDB(viewerKey)
    local cm = E.GetProfileBuffsDB()
    if not (cm and viewerKey) then
      return nil
    end

    cm.fonts = cm.fonts or {}
    cm.fonts.viewers = cm.fonts.viewers or {}
    cm.fonts.viewers[viewerKey] = cm.fonts.viewers[viewerKey] or {}

    local v = cm.fonts.viewers[viewerKey]
    v.cooldown = v.cooldown or {}
    v.charge   = v.charge   or {}

    return v
  end

  -- Profile style DB (db.profile.cooldownManager.style)
  function E.GetStyleDB()
    local root = E.GetPCMRoot()
    if not root then
      return {
        buffBar = {
          height = 20,
          width = 250,
          rowSpacing = 1,
          orientation = "HORIZONTAL",
          growthDirection = "DOWN",
          drainDirection = "RIGHT_TO_LEFT",
          texture = "Pleebar",
          iconPlacement = "LEFT",

          borderThickness = 2,
          borderColor = { 0.20, 0.20, 0.24, 1.00 },
        },

        buffBarUseClassColor = true,
        buffBarBgColor = { 0.12, 0.12, 0.12, 0.95 },

        iconSize = 36,
        iconSpacing = 2,

        viewerSizes      = {},
        viewerSpacing    = {},
        viewerColumns    = {},
        viewerRowGrowth  = {},
        viewerWidthMode  = {},
        viewerFixedWidth = {},
      }
    end

    root.style = root.style or {}
    local style = root.style

    -- Seed runtime defaults so layout reads correct values before config UI is opened.
    if style.iconSize == nil then style.iconSize = 36 end
    if style.iconSpacing == nil then style.iconSpacing = 2 end

    -- Keep tables stable for runtime helpers.
    style.viewerSizes      = style.viewerSizes      or {}
    style.viewerSpacing    = style.viewerSpacing    or {}
    style.viewerColumns    = style.viewerColumns    or {}
    style.viewerRowGrowth  = style.viewerRowGrowth  or {}
    style.viewerWidthMode  = style.viewerWidthMode  or {}
    style.viewerFixedWidth = style.viewerFixedWidth or {}

    -- BuffViewer defaults live here now too.
    style.buffBar = style.buffBar or {}
    local bb = style.buffBar

    if bb.height == nil then bb.height = 20 end
    if bb.width == nil then bb.width = 250 end
    if bb.rowSpacing == nil then bb.rowSpacing = 1 end
    if bb.orientation ~= "VERTICAL" then bb.orientation = "HORIZONTAL" end

    if bb.orientation == "VERTICAL" then
      if bb.growthDirection == "UP" then
        bb.growthDirection = "LEFT"
      elseif bb.growthDirection ~= "LEFT" and bb.growthDirection ~= "RIGHT" then
        bb.growthDirection = "RIGHT"
      end

      if bb.drainDirection == "LEFT_TO_RIGHT" then
        bb.drainDirection = "TOP_TO_BOTTOM"
      elseif bb.drainDirection ~= "TOP_TO_BOTTOM" and bb.drainDirection ~= "BOTTOM_TO_TOP" then
        bb.drainDirection = "BOTTOM_TO_TOP"
      end

      if bb.iconPlacement == "RIGHT" then
        bb.iconPlacement = "BOTTOM"
      elseif bb.iconPlacement == "LEFT" then
        bb.iconPlacement = "TOP"
      elseif bb.iconPlacement ~= "TOP" and bb.iconPlacement ~= "BOTTOM" and bb.iconPlacement ~= "HIDE" then
        bb.iconPlacement = bb.iconOnBar == false and "HIDE" or "TOP"
      end
    else
      if bb.growthDirection == "LEFT" then
        bb.growthDirection = "UP"
      elseif bb.growthDirection ~= "UP" and bb.growthDirection ~= "DOWN" then
        bb.growthDirection = "DOWN"
      end

      if bb.drainDirection == "TOP_TO_BOTTOM" then
        bb.drainDirection = "LEFT_TO_RIGHT"
      elseif bb.drainDirection ~= "LEFT_TO_RIGHT" and bb.drainDirection ~= "RIGHT_TO_LEFT" then
        bb.drainDirection = "RIGHT_TO_LEFT"
      end

      if bb.iconPlacement == "BOTTOM" then
        bb.iconPlacement = "RIGHT"
      elseif bb.iconPlacement == "TOP" then
        bb.iconPlacement = "LEFT"
      elseif bb.iconPlacement ~= "LEFT" and bb.iconPlacement ~= "RIGHT" and bb.iconPlacement ~= "HIDE" then
        bb.iconPlacement = bb.iconOnBar == false and "HIDE" or "LEFT"
      end
    end

    if bb.texture == nil then bb.texture = "Pleebar" end
    bb.iconOnBar = nil

    if bb.borderThickness == nil then bb.borderThickness = 2 end
    if not bb.borderColor then bb.borderColor = { 0.20, 0.20, 0.24, 1.00 } end

    if style.buffBarUseClassColor == nil then
      style.buffBarUseClassColor = true
    end
    if not style.buffBarBgColor then
      style.buffBarBgColor = { 0.12, 0.12, 0.12, 0.95 }
    end

    return style
  end

  function E.IsPCMEnabled()
    local db = Addon.db
    local profile = db and db.profile
    local root = profile and profile.cooldownManager or nil

    if not root then
      return true
    end

    return root.enabled ~= false
  end

  -- Hot path: cached sub-DBs under db.profile.cooldownManager[field]
  function E.GetCMSubDB(field)
    if not field then
      return nil
    end

    local profile = E.GetProfile()
    if not profile then
      return nil
    end

    local cache = CMSubDBCache

    if cache.profile ~= profile then
      cache.profile = profile
      cache.cm = nil
      wipe(cache.fields)
    end

    local sub = cache.fields[field]
    if sub then
      return sub
    end

    local cm = E.GetPCMRoot()
    if not cm then
      return nil
    end
    cache.cm = cm

    cm[field] = cm[field] or {}
    sub = cm[field]
    cache.fields[field] = sub
    return sub
  end

  function E.EnsureViewerSubDB(field, viewerKey, defaults)
    if not viewerKey then
      return nil
    end

    local db = E.GetCMSubDB(field)
    if not db then
      return nil
    end

    local cfg = db[viewerKey]
    if not cfg then
      cfg = {}
      db[viewerKey] = cfg
    end

    if defaults and not cfg.__puiSeeded then
      cfg.__puiSeeded = true
      for k, v in pairs(defaults) do
        if cfg[k] == nil then
          cfg[k] = v
        end
      end
    end

    return cfg
  end

  function E.GetViewerCountDB(viewerKey)
    return E.EnsureViewerSubDB("count", viewerKey, VIEWER_COUNT_DEFAULTS)
  end

  function E.GetConsumableTrackerDB()
    local db = Addon.db
    local profile = db and db.profile or nil
    if not profile then
      return nil
    end

    local cache = ConsumableTrackerDBCache
    local cm = profile.cooldownManager
    local current = cm and cm.consumableTracker or nil
    if cache.profile == profile and cache.cfg ~= nil and cache.cfg == current then
      return cache.cfg
    end

    CMSubDBCache.fields.consumableTracker = nil
    local cfg = E.GetCMSubDB("consumableTracker")
    if not cfg then
      return nil
    end

    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.iconSize == nil then cfg.iconSize = 36 end
    if cfg.spacing == nil then cfg.spacing = 4 end
    if cfg.orientation == nil then cfg.orientation = "HORIZONTAL" end
    if cfg.growth == nil then cfg.growth = "RIGHT" end
    if cfg.wrap == nil then cfg.wrap = 8 end
    if cfg.combatOnly == nil then cfg.combatOnly = false end
    if cfg.countVisibility == nil then
      cfg.countVisibility = cfg.showCounts == false and "NEVER" or "ALWAYS"
    end
    cfg.showCounts = nil
    if cfg.showItemQuality == nil then cfg.showItemQuality = false end
    if cfg.showKeybinds == nil then cfg.showKeybinds = true end
    if cfg.showTooltips == nil then cfg.showTooltips = true end
    if cfg.onlyOnUseTrinkets == nil then cfg.onlyOnUseTrinkets = true end
    if cfg.showDurationSwipe == nil then cfg.showDurationSwipe = true end
    if cfg.glowDuringDurationSwipe == nil then cfg.glowDuringDurationSwipe = false end
    if cfg.showCooldownText == nil then cfg.showCooldownText = true end
    if cfg.missingAlpha == nil then cfg.missingAlpha = 0.38 end
    if cfg.borderSize == nil then cfg.borderSize = 2 end
    if cfg.backgroundColor == nil then cfg.backgroundColor = { 0.03, 0.03, 0.04, 1 } end
    if cfg.borderColor == nil then cfg.borderColor = { 0.10, 0.10, 0.12, 1 } end
    if cfg.font == nil then cfg.font = "PleebUI" end
    if cfg.cooldownFontSize == nil then cfg.cooldownFontSize = 11 end
    if cfg.countFontSize == nil then cfg.countFontSize = 10 end
    if cfg.keybindFontSize == nil then cfg.keybindFontSize = 8 end

    cfg.pos = cfg.pos or {
      point = "CENTER",
      rel = "UIParent",
      relPoint = "CENTER",
      x = 0,
      y = -120,
    }
    cfg.slots = cfg.slots or {}

    if cfg.slots.liquidLuster == nil
      and cfg.slots.lightfusedMana == nil
      and cfg.slots.invisibilityPotion == nil
    then
      for _, slot in pairs(cfg.slots) do
        if type(slot) == "table" and type(slot.order) == "number" and slot.order >= 4 then
          slot.order = slot.order + 3
        end
      end
    end

    local defaults = {
      healthPotion = { enabled = true, missing = "HIDE", order = 1 },
      lightsPotential = { enabled = true, missing = "HIDE", order = 2 },
      recklessness = { enabled = true, missing = "HIDE", order = 3 },
      liquidLuster = { enabled = true, missing = "HIDE", order = 4 },
      lightfusedMana = { enabled = false, missing = "HIDE", order = 5 },
      invisibilityPotion = { enabled = false, missing = "HIDE", order = 6 },
      healthstone = { enabled = true, missing = "HIDE", order = 7 },
      demonicHealthstone = { enabled = true, missing = "HIDE", order = 8 },
      combatRes = { enabled = true, missing = "HIDE", order = 9 },
      trinket1 = { enabled = true, missing = "HIDE", order = 10 },
      trinket2 = { enabled = true, missing = "HIDE", order = 11 },
      racial = { enabled = true, missing = "HIDE", order = 12 },
    }

    for key, values in pairs(defaults) do
      local slot = cfg.slots[key]
      if type(slot) ~= "table" then
        slot = {}
        cfg.slots[key] = slot
      end
      for field, value in pairs(values) do
        if slot[field] == nil then
          slot[field] = value
        end
      end
    end

    cache.profile = profile
    cache.cfg = cfg
    return cfg
  end
end


  E.Attach = P:Def('E.Attach', E.Attach)
  E.GetDB = P:Def('E.GetDB', E.GetDB)
  E.GetProfile = P:Def('E.GetProfile', E.GetProfile)
  E.GetPCMRoot = P:Def('E.GetPCMRoot', E.GetPCMRoot)
  E.GetViewerSwipeDB = P:Def('E.GetViewerSwipeDB', E.GetViewerSwipeDB)
  E.GetProfileBuffsDB = P:Def('E.GetProfileBuffsDB', E.GetProfileBuffsDB)
  E.GetProfileBuffsAnchorDB = P:Def('E.GetProfileBuffsAnchorDB', E.GetProfileBuffsAnchorDB)
  E.GetProfileBuffsViewerFontDB = P:Def('E.GetProfileBuffsViewerFontDB', E.GetProfileBuffsViewerFontDB)
  E.EnsureViewerSubDB = P:Def('E.EnsureViewerSubDB', E.EnsureViewerSubDB)
  E.GetViewerCountDB = P:Def('E.GetViewerCountDB', E.GetViewerCountDB)
  E.GetConsumableTrackerDB = P:Def('E.GetConsumableTrackerDB', E.GetConsumableTrackerDB)

