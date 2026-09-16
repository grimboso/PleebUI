local _, ns = ...

local Inspector = {}
ns.UFTestInspector = Inspector

local Addon = ns.Addon
local AuraFilters = ns.UFAuraFilters
local OptionsUtil = ns.OptionsUtil
local PartyFrames = ns.Modules.PartyFrames
local PRD = ns.Modules.PRD
local RaidFrames = ns.Modules.RaidFrames
local TestMode = ns.TestMode
local Theme = ns.Theme
local UF = ns.Modules.UnitFrames

local C_Timer = _G.C_Timer
local InCombatLockdown = _G.InCombatLockdown
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local pairs = _G.pairs
local sort = _G.table.sort
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local OWNER_KEY = "unitframes-test"
local TEXT_MODE_VALUES = {
  CUR = "Current",
  CUR_MAX = "Current / max",
  PERCENT = "Percent",
  CUR_PERCENT = "Current + percent",
  HIDE = "Hide",
}

Inspector.active = false
Inspector.groupRefreshQueued = Inspector.groupRefreshQueued or {}
Inspector.auraRefreshQueued = Inspector.auraRefreshQueued or {}

local function IsBossUnit(unit)
  return type(unit) == "string" and unit:match("^boss%d$") ~= nil
end

local function CopyTable(source)
  local output = {}

  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      output[key] = CopyTable(value)
    else
      output[key] = value
    end
  end

  return output
end

local function CopyColor(color, fallback)
  fallback = fallback or { 1, 1, 1, 1 }

  return {
    color and (color[1] or color.r) or fallback[1],
    color and (color[2] or color.g) or fallback[2],
    color and (color[3] or color.b) or fallback[3],
    color and (color[4] or color.a) or fallback[4] or 1,
  }
end

local function ResolveContext(frame)
  local sample = frame and frame.__puiTestSample
  if not sample then
    return nil
  end

  if sample.groupKind == "party" then
    local db = PartyFrames.db.profile
    db.text = db.text or {}
    db.colors = db.colors or {}
    db.partyPets = db.partyPets or {}
    db.auras = db.auras or {}

    return {
      frame = frame,
      family = "party",
      title = sample.isPet and "Party pet" or "Party frame",
      geometry = sample.isPet and db.partyPets or db,
      visual = db,
      text = db.text,
      colors = db.colors,
      profile = db,
      auraDB = db.auras,
      unit = sample.unit,
      isPet = sample.isPet == true,
    }
  elseif sample.groupKind == "raid" then
    local db = RaidFrames.db.profile
    db.text = db.text or {}
    db.colors = db.colors or {}
    db.auras = db.auras or {}

    return {
      frame = frame,
      family = "raid",
      title = "Raid frame",
      geometry = db,
      visual = db,
      text = db.text,
      colors = db.colors,
      profile = db,
      auraDB = db.auras,
      unit = sample.unit,
    }
  end

  local profile = UF.db.profile
  local unit = sample.unit
  local visualKey = IsBossUnit(unit) and "boss" or unit
  local visual = profile.units[visualKey]
  if not visual then
    return nil
  end

  visual.text = visual.text or {}
  visual.media = visual.media or {}
  visual.auras = visual.auras or {}
  profile.colors = profile.colors or {}
  profile.media = profile.media or {}

  return {
    frame = frame,
    family = "single",
    title = sample.name or unit,
    geometry = visual,
    visual = visual,
    text = visual.text,
    colors = profile.colors,
    profile = profile,
    auraDB = visual.auras,
    unit = unit,
    visualKey = visualKey,
  }
end

local function RequestGroupedRefresh(family)
  if Inspector.groupRefreshQueued[family] then
    return
  end

  Inspector.groupRefreshQueued[family] = true
  C_Timer.After(0, function()
    Inspector.groupRefreshQueued[family] = nil

    if InCombatLockdown() then
      return
    end

    local module = family == "party" and PartyFrames or RaidFrames
    module:Refresh()

    if TestMode:IsActive() and TestMode:GetValue("uf." .. family) == true then
      TestMode:Refresh("unitframes", "quick-settings", "uf." .. family .. "Settings")
    end
  end)
end

local function RequestFrameRefresh(context)
  if InCombatLockdown() then
    return false
  end

  if context.family == "single" then
    Addon:ApplyOptionsChange("UnitFrames", {
      mode = "resize",
      unit = context.visualKey,
    })
  else
    RequestGroupedRefresh(context.family)
  end

  return true
end

local function SupportsPortrait(context)
  if context.family == "party" then
    return context.isPet ~= true
  end

  if context.family ~= "single" then
    return false
  end

  return context.visualKey == "player"
    or context.visualKey == "target"
    or context.visualKey == "focus"
    or context.visualKey == "boss"
end

local function RequestPortraitRefresh(context)
  if InCombatLockdown() then
    return false
  end

  if context.family == "single" then
    Addon:ApplyOptionsChange("UnitFrames", {
      mode = "resize",
      unit = context.visualKey,
    })
  elseif context.family == "party" then
    PartyFrames:SafeRefresh("resize")

    if TestMode:IsActive() and TestMode:GetValue("uf.party") == true then
      TestMode:Refresh("unitframes", "quick-settings", "uf.partySettings")
    end
  end

  return true
end

local function RequestAuraRefresh(context)
  if InCombatLockdown() then
    return false
  end

  local ownerKey = context.family == "single" and context.visualKey or context.family
  local queued = Inspector.auraRefreshQueued[ownerKey]

  if queued then
    queued.context = context
    return true
  end

  Inspector.auraRefreshQueued[ownerKey] = {
    context = context,
  }

  C_Timer.After(0, function()
    local request = Inspector.auraRefreshQueued[ownerKey]
    Inspector.auraRefreshQueued[ownerKey] = nil

    if not request or InCombatLockdown() then
      return
    end

    local refreshContext = request.context
    if refreshContext.family == "single" then
      UF:RefreshAuraDisplay({ unit = refreshContext.visualKey })
    else
      local module = refreshContext.family == "party" and PartyFrames or RaidFrames
      module:RefreshAuraDisplay({ rebuildDB = true })
    end

    if TestMode:IsActive() then
      TestMode:Refresh("unitframes", "quick-settings", "uf.auraSettings")
    end
  end)

  return true
end

local function GetEditableAuraDisplay(context, auraInfo)
  local auraDB = context.auraDB
  auraDB.customDisplays = type(auraDB.customDisplays) == "table"
    and auraDB.customDisplays
    or {}

  local displayID = tonumber(auraInfo.displayID)
  local display = displayID and auraDB.customDisplays[displayID] or nil

  if not display and displayID and type(auraInfo.display) == "table" then
    display = CopyTable(auraInfo.display)
    display.id = displayID
    auraDB.customDisplays[displayID] = display
  end

  if not display then
    return nil
  end

  return AuraFilters.NormalizeDisplay(display, displayID)
end

local function GetHealthTexture(context)
  if context.family == "single" then
    local media = context.visual.media
    if media.useCustomTexture == true and media.healthTexture then
      return media.healthTexture
    end

    return context.profile.media.healthTexture or "Pleebar"
  end

  return context.visual.healthTexture or "Pleebar"
end

local function SetHealthTexture(context, value)
  if context.family == "single" then
    local media = context.visual.media
    media.useCustomTexture = true
    media.healthTexture = value
    Addon:ApplyOptionsChange("UnitFrames", { textures = true })
  else
    context.visual.healthTexture = value
    RequestGroupedRefresh(context.family)
  end
end

local function GetPowerTexture(context)
  if context.family == "single" then
    local media = context.visual.media
    if media.useCustomTexture == true and media.powerTexture then
      return media.powerTexture
    end

    return context.profile.media.powerTexture
      or context.profile.media.healthTexture
      or "Pleebar"
  end

  return context.visual.powerTexture
    or context.visual.healthTexture
    or "Pleebar"
end

local function SetPowerTexture(context, value)
  if context.family == "single" then
    local media = context.visual.media
    media.useCustomTexture = true
    media.powerTexture = value
    Addon:ApplyOptionsChange("UnitFrames", { textures = true })
  else
    context.visual.powerTexture = value
    RequestGroupedRefresh(context.family)
  end
end

local function GetTypographyOverrideKey(role)
  if role == "name" then
    return "nameUseCustomTypography"
  elseif role == "health" then
    return "healthUseCustomTypography"
  end

  return "powerUseCustomTypography"
end

local function GetFontValue(context, role)
  local key = role .. "Font"
  local globalKey = role .. "UseGlobalFont"

  if context.family == "single" then
    if context.text[GetTypographyOverrideKey(role)] ~= true then
      return ""
    end

    return context.text[key] or ""
  end

  if context.text[globalKey] == true then
    return ""
  end

  return context.text[key] or context.text.font or ""
end

local function SetFontValue(context, role, value)
  value = type(value) == "string" and value or ""

  local key = role .. "Font"
  local globalKey = role .. "UseGlobalFont"

  if context.family == "single" then
    context.text[GetTypographyOverrideKey(role)] = true
    context.text[key] = value
    Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
    return
  end

  context.text[key] = value
  context.text[globalKey] = value == ""
  RequestGroupedRefresh(context.family)
end

local function GetOutlineValue(context, role)
  local key = role .. "Outline"

  if context.family == "single" then
    if context.text[GetTypographyOverrideKey(role)] ~= true then
      return context.profile.text and context.profile.text.outline or "OUTLINE"
    end

    return context.text[key]
      or (context.profile.text and context.profile.text.outline)
      or "OUTLINE"
  end

  return context.text[key] or context.text.outline or "OUTLINE"
end

local function SetOutlineValue(context, role, value)
  if context.family == "single" then
    context.text[GetTypographyOverrideKey(role)] = true
    context.text[role .. "Outline"] = value
    Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
    return
  end

  context.text[role .. "Outline"] = value
  RequestGroupedRefresh(context.family)
end

local function GetTextSize(context, role)
  local key = role == "name" and "sizeName"
    or role == "health" and "sizeHealth"
    or "sizePower"
  local value = context.text[key]

  if context.family == "single" and context.text[GetTypographyOverrideKey(role)] ~= true then
    value = context.profile.text and context.profile.text[key]
  elseif value == nil and context.family == "single" then
    value = context.profile.text and context.profile.text[key]
  end

  return tonumber(value) or 12, key
end

local function SetTextSize(context, role, value)
  local _, key = GetTextSize(context, role)
  context.text[key] = math_max(6, math_min(32, tonumber(value) or 12))

  if context.family == "single" then
    context.text[GetTypographyOverrideKey(role)] = true
    Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
  else
    RequestGroupedRefresh(context.family)
  end
end

local function GetTextMode(context, role)
  local key = role == "health" and "healthMode" or "powerMode"
  local value = context.text[key]

  if value == nil and context.family == "single" then
    value = context.profile.text and context.profile.text[key]
  end

  return TEXT_MODE_VALUES[value] and value
    or (role == "health" and "PERCENT" or "CUR"), key
end

local function SetTextMode(context, role, value)
  local _, key = GetTextMode(context, role)
  context.text[key] = TEXT_MODE_VALUES[value] and value or "HIDE"

  if context.family == "single" then
    Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
  else
    RequestGroupedRefresh(context.family)
  end
end

local function GetTextColor(context, role)
  local key = role == "name" and "nameText"
    or role == "health" and "healthText"
    or "powerText"

  return CopyColor(context.colors[key], { 1, 1, 1, 1 }), key
end

local function SetTextColor(context, role, r, g, b, a)
  local _, key = GetTextColor(context, role)
  context.colors[key] = { r, g, b, a or 1 }

  if context.family == "single" then
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
  else
    RequestGroupedRefresh(context.family)
  end
end

local function GetBorderSize(context)
  if context.family == "single" then
    return tonumber(context.profile.borderEdgeSize) or 1
  end

  return tonumber(context.visual.borderSize) or 1
end

local function SetBorderSize(context, value)
  value = math_max(0, math_min(6, tonumber(value) or 1))

  if context.family == "single" then
    context.profile.borderEdgeSize = value
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
  else
    context.visual.borderSize = value
    RequestGroupedRefresh(context.family)
  end
end

local function GetBorderColor(context)
  return CopyColor(
    context.colors.borderColor or context.colors.border,
    { 0.1, 0.1, 0.1, 1 }
  )
end

local function SetBorderColor(context, r, g, b, a)
  context.colors.borderColor = { r, g, b, a or 1 }

  if context.family == "single" then
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
  else
    RequestGroupedRefresh(context.family)
  end
end

local function RoundValue(value)
  return math_floor((tonumber(value) or 0) + 0.5)
end

local function GetDetailedOptionsRoute(context)
  if context.family == "party" then
    return "party"
  elseif context.family == "raid" then
    return "raid"
  elseif context.visualKey == "player" then
    return "player"
  elseif context.visualKey == "target" then
    return "target"
  elseif context.visualKey == "targettarget" then
    return "targettarget"
  elseif context.visualKey == "focus" then
    return "focus"
  elseif context.visualKey == "focustarget" then
    return "focustarget"
  elseif context.visualKey == "boss" then
    return "boss"
  elseif context.visualKey == "pet" then
    return "special"
  end

  return "general"
end

local function AddSlider(controls, label, minimum, maximum, step, get, set, commitOnRelease)
  controls[#controls + 1] = {
    type = "slider",
    label = label,
    min = minimum,
    max = maximum,
    step = step,
    get = get,
    set = set,
    commitOnRelease = commitOnRelease == true,
  }
end

local function AddToggle(controls, label, get, set)
  controls[#controls + 1] = {
    type = "toggle",
    label = label,
    get = get,
    set = set,
  }
end

local function AddSelect(controls, controlType, label, values, get, set)
  controls[#controls + 1] = {
    type = controlType,
    label = label,
    values = values,
    get = get,
    set = set,
  }
end

local function AddColor(controls, label, get, set)
  controls[#controls + 1] = {
    type = "color",
    label = label,
    get = get,
    set = set,
  }
end

local function AddFrameSizeControls(controls, context)
  local geometry = context.geometry
  local isPlayer = context.family == "single" and context.visualKey == "player"
  local minWidth = isPlayer and 120 or 30
  local maxWidth = isPlayer and 600 or (context.family == "raid" and 300 or 500)

  AddSlider(
    controls,
    "Frame width",
    minWidth,
    maxWidth,
    1,
    function()
      return tonumber(geometry.width) or 100
    end,
    function(value)
      geometry.width = RoundValue(value)
      RequestFrameRefresh(context)
    end,
    true
  )

  AddSlider(
    controls,
    "Frame height",
    10,
    150,
    1,
    function()
      return tonumber(geometry.height) or 30
    end,
    function(value)
      geometry.height = RoundValue(value)
      RequestFrameRefresh(context)
    end
  )
end

local function AddFontControls(controls, context, role, labelPrefix)
  AddSelect(
    controls,
    "font",
    labelPrefix .. " font",
    OptionsUtil.BuildFontValues(true, "Use global font", ""),
    function()
      return GetFontValue(context, role)
    end,
    function(value)
      SetFontValue(context, role, value)
    end
  )

  AddSlider(
    controls,
    labelPrefix .. " font size",
    6,
    32,
    1,
    function()
      return GetTextSize(context, role)
    end,
    function(value)
      SetTextSize(context, role, value)
    end
  )

  AddSelect(
    controls,
    "select",
    labelPrefix .. " outline",
    Theme.GetOutlineList(),
    function()
      return GetOutlineValue(context, role)
    end,
    function(value)
      SetOutlineValue(context, role, value)
    end
  )

  AddColor(
    controls,
    labelPrefix .. " color",
    function()
      return GetTextColor(context, role)
    end,
    function(r, g, b, a)
      SetTextColor(context, role, r, g, b, a)
    end
  )
end

local function AddShowPortraitControl(controls, context)
  if not SupportsPortrait(context) then
    return
  end

  AddToggle(
    controls,
    "Show portrait",
    function()
      return context.visual.portrait.enabled == true
    end,
    function(value)
      if InCombatLockdown() then return end
      context.visual.portrait.enabled = value == true
      RequestPortraitRefresh(context)
    end
  )
end

local function AddShowPowerControl(controls, context)
  local geometry = context.geometry

  AddToggle(
    controls,
    "Show power",
    function()
      return geometry.showPower ~= false
    end,
    function(value)
      geometry.showPower = value
      if value and (tonumber(geometry.powerHeight) or 0) <= 0 then
        geometry.powerHeight = 5
      end
      RequestFrameRefresh(context)
    end
  )
end

local function AddPowerHeightControl(controls, context)
  local geometry = context.geometry

  AddSlider(
    controls,
    "Power height",
    0,
    30,
    1,
    function()
      return tonumber(geometry.powerHeight) or 0
    end,
    function(value)
      value = RoundValue(value)
      geometry.powerHeight = value
      geometry.showPower = value > 0
      RequestFrameRefresh(context)
    end
  )
end

local function AddTextureControls(controls, context)
  AddSelect(
    controls,
    "statusbar",
    "Health texture",
    OptionsUtil.BuildStatusbarValues(false),
    function()
      return GetHealthTexture(context)
    end,
    function(value)
      SetHealthTexture(context, value)
    end
  )

  AddSelect(
    controls,
    "statusbar",
    "Power texture",
    OptionsUtil.BuildStatusbarValues(false),
    function()
      return GetPowerTexture(context)
    end,
    function(value)
      SetPowerTexture(context, value)
    end
  )
end

local function AddBorderControls(controls, context)
  AddSlider(
    controls,
    "Border size",
    0,
    6,
    1,
    function()
      return GetBorderSize(context)
    end,
    function(value)
      SetBorderSize(context, value)
    end
  )

  AddColor(
    controls,
    "Border color",
    function()
      return GetBorderColor(context)
    end,
    function(r, g, b, a)
      SetBorderColor(context, r, g, b, a)
    end
  )

  if context.family == "single" then
    AddSelect(
      controls,
      "select",
      "Border placement",
      {
        inside = "Inside frame",
        outside = "Outside frame",
      },
      function()
        return context.profile.borderPlacement == "inside" and "inside" or "outside"
      end,
      function(value)
        context.profile.borderPlacement = value == "inside" and "inside" or "outside"
        Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
      end
    )
  end
end

local function GetEffectiveAuraDisplays(context)
  local auraDB

  if context.family == "single" then
    auraDB = AuraFilters.BuildFrameAuraDB(context.frame, context.unit)
  else
    auraDB = AuraFilters.BuildGroupedAuraDB(context.family, context.profile, context.unit)
  end

  if type(auraDB) ~= "table" or auraDB.enabled == false then
    return {}
  end

  local displays = {}
  for _, display in pairs(AuraFilters.NormalizeDisplays(auraDB) or {}) do
    if display.enabled ~= false then
      displays[#displays + 1] = display
    end
  end

  sort(displays, function(left, right)
    local leftOrder = tonumber(left.order) or 0
    local rightOrder = tonumber(right.order) or 0

    if leftOrder == rightOrder then
      return (tonumber(left.id) or 0) < (tonumber(right.id) or 0)
    end

    return leftOrder < rightOrder
  end)

  return displays
end

local function GetLocalAuraDisplay(context, display)
  local displays = type(context.auraDB.customDisplays) == "table"
    and context.auraDB.customDisplays
    or nil
  local displayID = tonumber(display and display.id)

  return displays and displayID and displays[displayID] or nil
end

local function AddAuraControls(controls, context)
  for _, display in ipairs(GetEffectiveAuraDisplays(context)) do
    local displayInfo = {
      displayID = display.id,
      display = display,
    }
    local displayName = display.name or ("Aura " .. tostring(display.id or ""))

    AddSlider(
      controls,
      displayName .. " size",
      8,
      64,
      1,
      function()
        local localDisplay = GetLocalAuraDisplay(context, displayInfo.display)
        return tonumber(localDisplay and localDisplay.iconSize)
          or tonumber(displayInfo.display.iconSize)
          or 20
      end,
      function(value)
        local editable = GetEditableAuraDisplay(context, displayInfo)
        if not editable then
          return
        end

        editable.autoIconSize = false
        editable.iconSize = RoundValue(value)
        RequestAuraRefresh(context)
      end
    )

    if display.displayType ~= "slot"
      and display.specialType ~= "DEFENSIVES_EXTERNALS"
    then
      AddSlider(
        controls,
        displayName .. " count",
        1,
        40,
        1,
        function()
          local localDisplay = GetLocalAuraDisplay(context, displayInfo.display)
          return tonumber(localDisplay and localDisplay.maxIcons)
            or tonumber(displayInfo.display.maxIcons)
            or 4
        end,
        function(value)
          local editable = GetEditableAuraDisplay(context, displayInfo)
          if not editable then
            return
          end

          editable.maxIcons = RoundValue(value)
          RequestAuraRefresh(context)
        end
      )
    end
  end
end

local function AddUnifiedFrameControls(controls, context)
  AddFrameSizeControls(controls, context)
  AddShowPortraitControl(controls, context)
  AddShowPowerControl(controls, context)
  AddPowerHeightControl(controls, context)
  AddTextureControls(controls, context)
  AddBorderControls(controls, context)

  AddSelect(
    controls,
    "select",
    "Health display",
    TEXT_MODE_VALUES,
    function()
      return GetTextMode(context, "health")
    end,
    function(value)
      SetTextMode(context, "health", value)
    end
  )
  AddFontControls(controls, context, "health", "Health")

  AddSelect(
    controls,
    "select",
    "Power display",
    TEXT_MODE_VALUES,
    function()
      return GetTextMode(context, "power")
    end,
    function(value)
      SetTextMode(context, "power", value)
    end
  )
  AddFontControls(controls, context, "power", "Power")
  AddFontControls(controls, context, "name", "Name")
  AddAuraControls(controls, context)
end

function Inspector:BuildFrameSpec(frame)
  if not self.active or InCombatLockdown() then
    return nil
  end

  local context = ResolveContext(frame)
  if not context then
    return nil
  end

  local controls = {}

  if context.family == "single" and context.visualKey == "player" then
    controls[#controls + 1] = {
      type = "toggle",
      label = "Use Player Unit Frame in the Resource Display",
      disabled = function()
        return InCombatLockdown()
      end,
      get = function()
        return PRD.db.profile.usePlayerHealth == true
      end,
      set = function(value)
        PRD:SetUsePlayerHealth(value)
      end,
    }
    controls[#controls + 1] = {
      type = "description",
      text = "Player Unit Frame can display more information, such as shields or absorbs. ",
    }
  end

  AddUnifiedFrameControls(controls, context)

  return {
    ownerKey = OWNER_KEY,
    title = context.title,
    description = "Quick settings. Right-click the mover for all options.",
    controls = controls,
  }
end

local function GetMoverKey(context)
  if context.family == "party" then
    return "PartyFrames"
  elseif context.family == "raid" then
    return "RaidFrames"
  elseif context.visualKey == "boss" then
    return "UF_boss1"
  end

  if context.visualKey then
    return "UF_" .. context.visualKey
  end
end

function Inspector:AttachAura(icon, ownerFrame, auraInfo)
  auraInfo.ownerFrame = ownerFrame
  icon.__puiTestAuraInfo = auraInfo
  icon:SetFrameLevel(ownerFrame:GetFrameLevel() + 130)
  icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  if icon.__puiTestAuraInspectorReady then
    return
  end

  icon:SetScript("OnClick", function(self, button)
    if not ns.Flags.IsEditing or not Inspector.active or InCombatLockdown() then
      return
    end

    local info = self.__puiTestAuraInfo
    local context = ResolveContext(info and info.ownerFrame)
    if not context then
      return
    end

    if button == "RightButton" then
      Addon:OpenOptionsSection("unitframes", GetDetailedOptionsRoute(context))
      return
    end

    local moverKey = GetMoverKey(context)
    local entry = moverKey and ns.FrameUtil.GetMoverEntry(moverKey) or nil
    local spec = moverKey and ns.FrameUtil.GetMoverQuickSettingsSpec(moverKey, info.ownerFrame) or nil
    if not entry or type(spec) ~= "table" then
      return
    end

    local anchor = entry.overlay or entry.frame
    local panel = ns.EditModeQuickSettings.panel
    if panel
      and panel:IsShown()
      and panel.anchor == anchor
      and panel.ownerKey == spec.ownerKey
    then
      ns.EditModeQuickSettings:Hide()
      return
    end

    ns.EditModeQuickSettings:Hide()
    ns.EditModeQuickSettings:Open(anchor, spec)
  end)
  icon:SetScript("OnEnter", function(self)
    local info = self.__puiTestAuraInfo
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:SetText(info and info.name or "Auras")
    GameTooltip:AddLine("Left-click for frame quick settings.", 1, 1, 1)
    GameTooltip:AddLine("Right-click for all Unit Frame settings.", 1, 1, 1)
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  icon.__puiTestAuraInspectorReady = true
end

function Inspector:OnFrameHidden()
  local panel = ns.EditModeQuickSettings.panel
  if panel and panel.ownerKey == OWNER_KEY then
    ns.EditModeQuickSettings:Hide()
  end
end

function Inspector:SetActive(active)
  self.active = active == true

  if not self.active then
    self:OnFrameHidden()
  end
end

local P = select(1, ns.Pleebug:DropIn(Inspector, { name = "UnitFrames.TestMode.Inspector" }))
ResolveContext = P:Def("ResolveContext", ResolveContext)
RequestFrameRefresh = P:Def("RequestFrameRefresh", RequestFrameRefresh)
SupportsPortrait = P:Def("SupportsPortrait", SupportsPortrait)
RequestPortraitRefresh = P:Def("RequestPortraitRefresh", RequestPortraitRefresh)
RequestAuraRefresh = P:Def("RequestAuraRefresh", RequestAuraRefresh)
GetEditableAuraDisplay = P:Def("GetEditableAuraDisplay", GetEditableAuraDisplay)
Inspector.BuildFrameSpec = P:Def("Inspector:BuildFrameSpec", Inspector.BuildFrameSpec)
Inspector.AttachAura = P:Def("Inspector:AttachAura", Inspector.AttachAura)
Inspector.OnFrameHidden = P:Def("Inspector:OnFrameHidden", Inspector.OnFrameHidden)
Inspector.SetActive = P:Def("Inspector:SetActive", Inspector.SetActive)
