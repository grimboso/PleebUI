-- File: PUI_UF_CastBar_Player_ChannelTicks.lua
-- Purpose: Retained player castbar channel tick markers.


local ADDON_NAME, ns = ...

local CastBar = ns.Modules.CastBar

local Module = {}
ns.PUICastBarPlayerChannelTicks = Module

local _G = _G
local AuraUtil = _G.AuraUtil
local issecretvalue = _G.issecretvalue
local pairs = _G.pairs
local math_max = _G.math.max
local Round = ns.Pixel.Round

local CB_CHANNEL_TICK_SPELLS = {
  [291944] = 6,
  [198590] = 4,
  [234153] = 5,
  [755] = 5,
  [15407] = 6,
  [47757] = 3,
  [47758] = 3,
  [373129] = 3,
  [400171] = 3,
  [64843] = 4,
  [64902] = 5,
  [5143] = 4,
  [12051] = 6,
  [205021] = 5,
  [740] = 4,
  [206931] = 3,
  [198013] = 10,
  [212084] = 10,
  [120360] = 15,
  [257044] = 7,
  [1261215] = 4,
  [113656] = 4,
}

local CB_CHANNEL_TICK_AURA_OVERRIDES = {
  [47757] = {
    spellID = 373183,
    tickCount = 6,
  },
  [47758] = {
    spellID = 373183,
    tickCount = 6,
  },
}

local CB_MAX_CHANNEL_TICK_MARKERS = 0

for _, tickCount in pairs(CB_CHANNEL_TICK_SPELLS) do
  CB_MAX_CHANNEL_TICK_MARKERS = math_max(CB_MAX_CHANNEL_TICK_MARKERS, tickCount - 1)
end

for _, aura in pairs(CB_CHANNEL_TICK_AURA_OVERRIDES) do
  CB_MAX_CHANNEL_TICK_MARKERS = math_max(CB_MAX_CHANNEL_TICK_MARKERS, aura.tickCount - 1)
end

local function CB_CreateTicks(bar, element)
  local ticks = {}

  for index = 1, CB_MAX_CHANNEL_TICK_MARKERS do
    local tick = element:CreateTexture(nil, "OVERLAY", nil, 6)
    tick:Hide()
    ticks[index] = tick
  end

  bar.__puiChannelTicks = ticks
  bar.__puiChannelTickState = {
    active = false,
    rendered = 0,
  }
end

local function CB_LayoutTicks(bar, element, cfg)
  local thickness = math_max(Round(1), Round(CastBar.Clamp(cfg.channelTickThickness, 1, 10)))
  local height = Round(element:GetHeight())

  bar.__puiChannelTickThickness = thickness

  for index = 1, #bar.__puiChannelTicks do
    local tick = bar.__puiChannelTicks[index]
    tick:SetColorTexture(0, 0, 0, 0.8)
    tick:SetWidth(thickness)
    tick:SetHeight(height)
  end

  local state = bar.__puiChannelTickState
  state.width = nil
end

local function CB_IsSameLayout(state, width, reverseFill, count, data)
  local disintegrate = data ~= nil

  if state.width ~= width
    or state.reverseFill ~= reverseFill
    or state.count ~= count
    or state.disintegrate ~= disintegrate
  then
    return false
  end

  if not disintegrate then
    return true
  end

  return state.duration == data.duration
    and state.firstTick == data.firstTick
    and state.interval == data.hastedTickInterval
    and state.chaining == data.chaining
end

local function CB_SaveLayout(state, width, reverseFill, count, data, rendered)
  state.active = true
  state.width = width
  state.reverseFill = reverseFill
  state.count = count
  state.disintegrate = data ~= nil
  state.rendered = rendered

  if data then
    state.duration = data.duration
    state.firstTick = data.firstTick
    state.interval = data.hastedTickInterval
    state.chaining = data.chaining
  else
    state.duration = nil
    state.firstTick = nil
    state.interval = nil
    state.chaining = nil
  end
end

local function CB_ShowTicks(bar, count)
  for index = 1, count do
    bar.__puiChannelTicks[index]:Show()
  end
end

local function CB_RenderStandardTicks(bar, element, width, count, reverseFill)
  local ticks = bar.__puiChannelTicks
  local rendered = count - 1
  local inverseCount = 1 / count

  for index = 1, rendered do
    local fraction = index * inverseCount
    local offset = reverseFill and fraction or 1 - fraction
    local tick = ticks[index]

    tick:ClearAllPoints()
    tick:SetPoint("CENTER", element, "LEFT", Round(width * offset), 0)
    tick:Show()
  end

  return rendered
end

local function CB_RenderDisintegrateTicks(bar, element, width, data)
  local ticks = bar.__puiChannelTicks
  local rendered = 0
  local duration = data.duration
  local inverseDuration = 1 / duration
  local maxTicks = data.maxTicks
  local firstTick = data.firstTick
  local hastedTickInterval = data.hastedTickInterval
  local chaining = data.chaining
  local lastVisibleTime = duration * 0.99
  local chainedTickInterval

  if chaining then
    chainedTickInterval = (duration - firstTick) / (maxTicks - 1)
  end

  for index = 1, maxTicks do
    local tickTime

    if chaining then
      tickTime = firstTick + ((index - 1) * chainedTickInterval)
    else
      tickTime = index * hastedTickInterval
    end

    if tickTime < lastVisibleTime then
      rendered = rendered + 1

      local tick = ticks[rendered]
      local offset = (duration - tickTime) * inverseDuration

      tick:ClearAllPoints()
      tick:SetPoint("CENTER", element, "LEFT", Round(width * offset), 0)
      tick:Show()
    end
  end

  return rendered
end

local function CB_HideTickRange(bar, firstIndex, lastIndex)
  for index = firstIndex, lastIndex do
    bar.__puiChannelTicks[index]:Hide()
  end
end

function Module:OnCreate(bar, element)
  CB_CreateTicks(bar, element)
end

function Module:OnLayout(bar, element, cfg)
  CB_LayoutTicks(bar, element, cfg)
end

function Module:Hide(bar)
  local state = bar.__puiChannelTickState
  if not state or state.active ~= true then
    return
  end

  local rendered = state.rendered or 0
  if rendered > 0 then
    CB_HideTickRange(bar, 1, rendered)
  end

  state.active = false
end

function Module:GetChannelTickCount(spellID)
  local ticks = CB_CHANNEL_TICK_SPELLS[spellID] or 0
  if ticks <= 0 then
    return 0
  end

  local aura = CB_CHANNEL_TICK_AURA_OVERRIDES[spellID]
  if aura and AuraUtil.FindAuraBySpellId(aura.spellID, "player", "HELPFUL") ~= nil then
    return aura.tickCount
  end

  return ticks
end

function Module:Update(bar, element, cfg, spellID)
  if cfg.showChannelTicks == false
    or not spellID
    or issecretvalue(spellID)
  then
    self:Hide(bar)
    return
  end

  local disintegrateData
  if CastBar.__puiUseDisintegrateLogic == true
    and spellID == ns.PUICastBarPlayerDisintegrate.DISINTEGRATE_SPELL_ID
  then
    disintegrateData = ns.PUICastBarPlayerDisintegrate:GetTickData(element, spellID)
  end

  local count = disintegrateData and disintegrateData.maxTicks or self:GetChannelTickCount(spellID)
  if count <= 1 then
    self:Hide(bar)
    return
  end

  local width = Round(element:GetWidth())
  if width <= 0 then
    self:Hide(bar)
    return
  end

  local reverseFill = element:GetReverseFill() == true
  local state = bar.__puiChannelTickState

  if CB_IsSameLayout(state, width, reverseFill, count, disintegrateData) then
    if state.active ~= true then
      state.active = true
      CB_ShowTicks(bar, state.rendered or 0)
    end
    return
  end

  local wasActive = state.active == true
  local previousRendered = state.rendered or 0
  local rendered

  if disintegrateData then
    rendered = CB_RenderDisintegrateTicks(bar, element, width, disintegrateData)
  else
    rendered = CB_RenderStandardTicks(bar, element, width, count, reverseFill)
  end

  if wasActive and previousRendered > rendered then
    CB_HideTickRange(bar, rendered + 1, previousRendered)
  end

  CB_SaveLayout(state, width, reverseFill, count, disintegrateData, rendered)
end

local P = select(1, ns.Pleebug:DropIn(Module, { name = "UnitFrames.CastBar.ChannelTicks" }))

CB_CreateTicks = P:Def("CB_CreateTicks", CB_CreateTicks)
CB_LayoutTicks = P:Def("CB_LayoutTicks", CB_LayoutTicks)
CB_IsSameLayout = P:Def("CB_IsSameLayout", CB_IsSameLayout)
CB_SaveLayout = P:Def("CB_SaveLayout", CB_SaveLayout)
CB_ShowTicks = P:Def("CB_ShowTicks", CB_ShowTicks)
CB_RenderStandardTicks = P:Def("CB_RenderStandardTicks", CB_RenderStandardTicks)
CB_RenderDisintegrateTicks = P:Def("CB_RenderDisintegrateTicks", CB_RenderDisintegrateTicks)
CB_HideTickRange = P:Def("CB_HideTickRange", CB_HideTickRange)
Module.OnCreate = P:Def("ChannelTicks.OnCreate", Module.OnCreate)
Module.OnLayout = P:Def("ChannelTicks.OnLayout", Module.OnLayout)
Module.Hide = P:Def("ChannelTicks.Hide", Module.Hide)
Module.GetChannelTickCount = P:Def("ChannelTicks.GetChannelTickCount", Module.GetChannelTickCount)
Module.Update = P:Def("ChannelTicks.Update", Module.Update)
