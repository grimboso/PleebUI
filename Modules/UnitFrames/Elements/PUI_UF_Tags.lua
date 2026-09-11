
-- File: PUI_UF_Tags.lua
-- Purpose: Shared oUF tag registration and nickname tag runtime helpers.


local ADDON_NAME, ns = ...


ns.UFTags = ns.UFTags or {}
local Tags = ns.UFTags

local _G = _G
local pairs = _G.pairs
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type
local UnitExists = _G.UnitExists
local UnitName = _G.UnitName
local UnitHealth = _G.UnitHealth
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local issecretvalue = _G.issecretvalue
local AbbreviateLargeNumbers = _G.AbbreviateLargeNumbers
local math_floor = _G.math.floor
local string_format = _G.string.format
local UseNSRTNicknames = false
local NSRT_NICKNAME_EVENT = "NSRT_NICKNAME_UPDATED"
local P = select(1, ns.Pleebug:DropIn(Tags, { name = "UnitFrames.Tags" }))


local function RefreshNicknameSetting()
  local unitFrames = ns.UnitFrames
  local db = unitFrames and unitFrames.db and unitFrames.db.profile
  local textDB = db and db.text

  UseNSRTNicknames = textDB and textDB.useNSRTNicknames == true or false
  return UseNSRTNicknames
end

local function ClampColorByte(value, fallback)
  value = tonumber(value) or fallback or 1

  if value < 0 then
    value = 0
  elseif value > 1 then
    value = 1
  end

  return math_floor(value * 255 + 0.5)
end

function Tags.GetDeadStatusText(text)
  local unitFrames = ns.UnitFrames
  local db = unitFrames and unitFrames.db and unitFrames.db.profile
  local colors = db and db.colors or nil
  local c = colors and colors.deadText or { 0.7, 0.7, 0.7, 1 }

  return string_format(
    "|cff%02x%02x%02x%s|r",
    ClampColorByte(c[1], 0.7),
    ClampColorByte(c[2], 0.7),
    ClampColorByte(c[3], 0.7),
    tostring(text or "")
  )
end

function Tags.GetDisplayName(unit)
  local fallback = UnitName(unit)

  if UseNSRTNicknames ~= true then
    return fallback
  end

  local api = _G.NSAPI
  if not api or type(api.GetName) ~= "function" then
    return fallback
  end

  local displayName = api:GetName(unit)
  if issecretvalue(displayName) then
    return displayName
  end

  return displayName or fallback
end

local function RegisterTag(oUF, name, events, method)
  if oUF.Tags.Methods[name] then
    oUF.Tags.Methods[name] = nil
  end

  oUF.Tags.Methods[name] = method
  oUF.Tags.Events[name] = events
  oUF.Tags:RefreshEvents(name)
  oUF.Tags:RefreshMethods(name)
end

function Tags.RegisterOUFTags()
  RefreshNicknameSetting()

  local oUF = ns.oUF

  if Tags._puiTagsRegistered == true then
    return true
  end

  RegisterTag(oUF, "pui:name", "UNIT_NAME_UPDATE PLAYER_ENTERING_WORLD", function(u)
    if not u or not UnitExists(u) then
      return ""
    end

    return Tags.GetDisplayName(u)
  end)

  RegisterTag(oUF, "pui:curhp", "UNIT_HEALTH UNIT_MAXHEALTH", function(u)
    if not u or not UnitExists(u) then
      return ""
    end

    return AbbreviateLargeNumbers(UnitHealth(u))
  end)

  RegisterTag(oUF, "pui:curpp", "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER", function(u)
    if not u or not UnitExists(u) then
      return ""
    end

    return AbbreviateLargeNumbers(UnitPower(u))
  end)

  RegisterTag(oUF, "pui:maxpp", "UNIT_DISPLAYPOWER UNIT_MAXPOWER", function(u)
    if not u or not UnitExists(u) then
      return ""
    end

    return AbbreviateLargeNumbers(UnitPowerMax(u))
  end)

  oUF.Tags.SharedEvents.PLAYER_ENTERING_WORLD = true

  Tags._puiTagsRegistered = true
  return true
end


local function RefreshFrameTags(frame)
  if frame and frame.NameText and frame.NameText.UpdateTag then
    frame.NameText:UpdateTag()
  end
end

function Tags.RefreshNameTags(owner)
  if not owner then
    return
  end

  if owner.UpdateTags or owner.NameText then
    RefreshFrameTags(owner)
    return
  end

  if not owner.frames then
    return
  end

  for _, frame in pairs(owner.frames) do
    RefreshFrameTags(frame)
  end
end

function Tags.RefreshAllNicknameTags()
  local objects = ns.oUF.objects

  for i = 1, #objects do
    RefreshFrameTags(objects[i])
  end
end

function Tags.RefreshNicknames()
  RefreshNicknameSetting()
  Tags.RefreshAllNicknameTags()
  ns.PublicAPI:_NotifyUnitFrameDisplayNameChanged()
end

function Tags.RegisterNicknameCallback()
  local api = _G.NSAPI
  if Tags._nicknameCallbackRegistered == true
    or not api
    or type(api.RegisterCallback) ~= "function"
  then
    return
  end

  api.RegisterCallback(Tags, NSRT_NICKNAME_EVENT, Tags.RefreshNicknames)
  Tags._nicknameCallbackRegistered = true
end

function Tags.UnregisterNicknameCallback()
  if Tags._nicknameCallbackRegistered ~= true then
    return
  end

  local api = _G.NSAPI
  if api and type(api.UnregisterCallback) == "function" then
    api.UnregisterCallback(Tags, NSRT_NICKNAME_EVENT)
  end

  Tags._nicknameCallbackRegistered = nil
end



  RefreshNicknameSetting = P:Def("RefreshNicknameSetting", RefreshNicknameSetting)
  ClampColorByte = P:Def("ClampColorByte", ClampColorByte)
  Tags.GetDeadStatusText = P:Def("Tags.GetDeadStatusText", Tags.GetDeadStatusText)
  Tags.RegisterOUFTags = P:Def("Tags.RegisterOUFTags", Tags.RegisterOUFTags)
  RefreshFrameTags = P:Def("RefreshFrameTags", RefreshFrameTags)
  Tags.RefreshNameTags = P:Def("Tags.RefreshNameTags", Tags.RefreshNameTags)
  Tags.RefreshAllNicknameTags = P:Def("Tags.RefreshAllNicknameTags", Tags.RefreshAllNicknameTags)
  Tags.RefreshNicknames = P:Def("Tags.RefreshNicknames", Tags.RefreshNicknames)
  Tags.RegisterNicknameCallback = P:Def("Tags.RegisterNicknameCallback", Tags.RegisterNicknameCallback)
  Tags.UnregisterNicknameCallback = P:Def("Tags.UnregisterNicknameCallback", Tags.UnregisterNicknameCallback)
  Tags.GetDisplayName = P:Def("Tags.GetDisplayName", Tags.GetDisplayName)
  RegisterTag = P:Def("RegisterTag", RegisterTag)
