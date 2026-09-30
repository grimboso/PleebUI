local _, ns = ...

local Addon = ns.Addon
local Buffs = Addon:NewModule("PCM_Buffs")
ns.Modules.PCM_Buffs = Buffs

local VIEWER_KEY = "BuffIconCooldownViewer"
local Round = ns.Pixel.Round

local function GetStyle()
  local owner = ns.Modules.CooldownManager
  local profile = ns.PCM_DBExports.GetProfileBuffsDB()
  local style = profile.style
  local font = ns.PCM_DBExports.GetProfileBuffsViewerFontDB(VIEWER_KEY)
  local border = owner.GetBorderConfig(VIEWER_KEY) or {}
  local iconSize = tonumber(style.viewerSizes[VIEWER_KEY] or style.iconSize) or 36
  local spacing = tonumber(style.viewerSpacing[VIEWER_KEY] or style.iconSpacing) or 1
  local columns = tonumber(style.viewerColumns[VIEWER_KEY]) or 0
  local growth = style.viewerGrowth[VIEWER_KEY]
  if growth ~= "LEFT" and growth ~= "RIGHT" then
    growth = "CENTER"
  end

  return {
    iconSize = iconSize,
    spacing = spacing,
    columns = columns,
    growth = growth,
    backgroundColor = style.iconBgColor or { 0, 0, 0, 0.35 },
    borderThickness = border.enabled ~= false and border.thickness or 0,
    borderColor = border.color,
    cooldownFont = font.cooldown,
    chargeFont = font.charge,
    keybindFont = nil,
    swipe = ns.PCM_DBExports.GetViewerSwipeDB(VIEWER_KEY),
    counts = ns.PCM_DBExports.GetViewerCountDB(VIEWER_KEY),
    durationCount = owner:GetDurationCountEnabled(VIEWER_KEY),
    tooltips = owner:GetViewerTooltipsEnabled(VIEWER_KEY),
    hideWhenInactive = owner:GetViewerHideWhenInactive(VIEWER_KEY),
  }
end

local function ApplyAnchor(frame)
  local db = ns.PCM_DBExports.GetProfileBuffsAnchorDB()
  local pos = db[VIEWER_KEY]
  if type(pos) ~= "table" or not pos.point then
    pos = {
      point = "CENTER",
      rel = "UIParent",
      relPoint = "CENTER",
      x = 0,
      y = -180,
    }
    db[VIEWER_KEY] = pos
  end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", Round(tonumber(pos.x) or 0), Round(tonumber(pos.y) or 0))
end

local function SavePosition(frame)
  local x, y = ns.FrameUtil.GetPointOffsetsForFrame(frame, "CENTER")
  local db = ns.PCM_DBExports.GetProfileBuffsAnchorDB()
  db[VIEWER_KEY] = {
    point = "CENTER",
    rel = "UIParent",
    relPoint = "CENTER",
    x = Round(x or 0),
    y = Round(y or 0),
  }
  ApplyAnchor(frame)
end

local function RegisterMover(frame)
  ns.FrameUtil:RegisterMover(VIEWER_KEY, frame, {
    label = "Tracked Icons",
    optionsString = "CooldownManager,buff-icons",
    useOverlayDrag = true,
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
    },
    savePosition = function()
      SavePosition(frame)
    end,
    resetPosition = function()
      ns.PCM_DBExports.GetProfileBuffsAnchorDB()[VIEWER_KEY] = {
        point = "CENTER",
        rel = "UIParent",
        relPoint = "CENTER",
        x = 0,
        y = -180,
      }
      ApplyAnchor(frame)
    end,
  })
end

function Buffs:RefreshSettings()
  local runtime = ns.PCMAuraRuntime
  local frame = runtime:InitializeViewer(VIEWER_KEY, UIParent)
  ApplyAnchor(frame)
  RegisterMover(frame)
  runtime:SetViewerStyle(VIEWER_KEY, GetStyle())
end

function Buffs:ApplySettings(flags)
  if flags == nil
    or flags.profile == true
    or flags.layout == true
    or flags.movers == true
    or flags.fonts == true
    or flags.theme == true
  then
    self:RefreshSettings()
  end
end

function Buffs:SoftRebuild(flags)
  if flags and (flags.profile == true or flags.layout == true or flags.movers == true) then
    self:RefreshSettings()
  end
end

function Buffs:RefreshIndividualIconSettings()
  ns.PCMAuraRuntime:RefreshAppearance(VIEWER_KEY)
end

function Buffs:RefreshAfterTalentSwap()
  ns.PCMCatalog:Invalidate("buff-icons-talent")
end

function Buffs:OnInitialize()
  self:SetEnabledState(ns.PCM_DBExports.IsPCMEnabled() == true)
end

function Buffs:OnEnable()
  self:RefreshSettings()
end

function Buffs:OnDisable()
end

local P = select(1, ns.Pleebug:DropIn(Buffs, { name = "PCM", bucket = "BuffsIconViewer" }))
Buffs.RefreshSettings = P:Def("Buffs:RefreshSettings", Buffs.RefreshSettings)
Buffs.ApplySettings = P:Def("Buffs:ApplySettings", Buffs.ApplySettings)
Buffs.SoftRebuild = P:Def("Buffs:SoftRebuild", Buffs.SoftRebuild)
Buffs.RefreshIndividualIconSettings = P:Def("Buffs:RefreshIndividualIconSettings", Buffs.RefreshIndividualIconSettings)
Buffs.RefreshAfterTalentSwap = P:Def("Buffs:RefreshAfterTalentSwap", Buffs.RefreshAfterTalentSwap)
Buffs.OnInitialize = P:Def("Buffs:OnInitialize", Buffs.OnInitialize)
Buffs.OnEnable = P:Def("Buffs:OnEnable", Buffs.OnEnable)
Buffs.OnDisable = P:Def("Buffs:OnDisable", Buffs.OnDisable)
