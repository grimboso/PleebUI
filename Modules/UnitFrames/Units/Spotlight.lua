
-- File: PUI_UF_Spotlight.lua
-- Purpose: Raid spotlight frame creation, layout, placeholders, unit assignment, and mover handling.
-- Status: Under development; intentionally not loaded by UnitFrames.xml yet.


local ADDON_NAME, ns = ...


local Spotlight = ns.UFSpotlight or {}
ns.UFSpotlight = Spotlight

local _G = _G
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local IsInRaid = _G.IsInRaid
local UnitExists = _G.UnitExists
local GetUnitName = _G.GetUnitName
local UIParent = _G.UIParent
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local math_floor = _G.math.floor
local math_ceil = _G.math.ceil

local Theme = ns.Theme
local FrameUtil = ns.FrameUtil
local oUF = ns.oUF

Spotlight.MAX_SLOTS = 10
local Round = ns.Pixel.Round


function Spotlight.NormalizeConfig(spotlight, db)
  if db then
    db.spotlight = type(db.spotlight) == "table" and db.spotlight or {}
    spotlight = db.spotlight
  end

  if type(spotlight) ~= "table" then
    return nil
  end

  if type(spotlight.enabled) ~= "boolean" then spotlight.enabled = false end
  if type(spotlight.count) ~= "number" then spotlight.count = 5 end
  if spotlight.count < 1 then
    spotlight.count = 1
  elseif spotlight.count > Spotlight.MAX_SLOTS then
    spotlight.count = Spotlight.MAX_SLOTS
  end

  if type(spotlight.columns) ~= "number" then spotlight.columns = 5 end
  if spotlight.columns < 1 then
    spotlight.columns = 1
  elseif spotlight.columns > Spotlight.MAX_SLOTS then
    spotlight.columns = Spotlight.MAX_SLOTS
  end

  if type(spotlight.orientation) ~= "string" then spotlight.orientation = "VERTICAL" end
  if spotlight.orientation ~= "HORIZONTAL" then
    spotlight.orientation = "VERTICAL"
  end

  if type(spotlight.growthX) ~= "string" then spotlight.growthX = "RIGHT" end
  if spotlight.growthX ~= "LEFT" then
    spotlight.growthX = "RIGHT"
  end

  if type(spotlight.growthY) ~= "string" then spotlight.growthY = "DOWN" end
  if spotlight.growthY ~= "UP" then
    spotlight.growthY = "DOWN"
  end

  if type(spotlight.spacingX) ~= "number" then spotlight.spacingX = 3 end
  if type(spotlight.spacingY) ~= "number" then spotlight.spacingY = 3 end
  if type(spotlight.showPlaceholders) ~= "boolean" then spotlight.showPlaceholders = true end
  if type(spotlight.width) ~= "number" then spotlight.width = 85 end
  if type(spotlight.height) ~= "number" then spotlight.height = 54 end
  if type(spotlight.powerHeight) ~= "number" then spotlight.powerHeight = 0 end

  if type(spotlight.point) ~= "string" then spotlight.point = "CENTER" end
  if type(spotlight.relativeTo) ~= "string" or spotlight.relativeTo == "" then spotlight.relativeTo = "UIParent" end
  if type(spotlight.relativePoint) ~= "string" then spotlight.relativePoint = spotlight.point end
  if type(spotlight.x) ~= "number" then spotlight.x = 420 end
  if type(spotlight.y) ~= "number" then spotlight.y = 0 end

  spotlight.slots = type(spotlight.slots) == "table" and spotlight.slots or {}
  for i = 1, Spotlight.MAX_SLOTS do
    local slot = type(spotlight.slots[i]) == "table" and spotlight.slots[i] or {}
    spotlight.slots[i] = slot

    if type(slot.mode) ~= "string" or slot.mode == "" then
      slot.mode = "NONE"
    elseif slot.mode ~= "NONE" and slot.mode ~= "ROSTERMEMBER" and slot.mode ~= "UNITNAME" then
      slot.mode = "NONE"
    end

    if type(slot.unitToken) ~= "string" then
      slot.unitToken = ""
    end

    if type(slot.unitName) ~= "string" then
      slot.unitName = ""
    end

    if type(slot.rosterName) ~= "string" then
      slot.rosterName = ""
    end
  end

  return spotlight
end

function Spotlight.GetConfig(owner)
  return owner.db.profile.spotlight
end

function Spotlight.GetSizeConfig(owner)
  local db = owner.db.profile
  local spotlight = db.spotlight

  local width = Round(spotlight.width or db.width or 80)
  local healthHeight = Round(spotlight.height or db.height or 44)
  local powerHeight = Round(spotlight.powerHeight or 0)
  local showPower = powerHeight > 0

  return width, healthHeight, powerHeight, showPower
end

function Spotlight.GetFrameSize(owner)
  local width, totalHeight = Spotlight.GetSizeConfig(owner)
  return width, totalHeight
end

function Spotlight.GetGridDimensions(spotlightDB)
  local count = tonumber(spotlightDB and spotlightDB.count) or 1
  if count < 1 then
    count = 1
  elseif count > Spotlight.MAX_SLOTS then
    count = Spotlight.MAX_SLOTS
  end

  local columns = tonumber(spotlightDB and spotlightDB.columns) or count
  if columns < 1 then
    columns = 1
  elseif columns > Spotlight.MAX_SLOTS then
    columns = Spotlight.MAX_SLOTS
  end

  if columns > count then
    columns = count
  end

  local rows = math_ceil(count / columns)
  if rows < 1 then
    rows = 1
  end

  return count, columns, rows
end

function Spotlight.GetTotalSize(owner, spotlightDB)
  spotlightDB = spotlightDB or Spotlight.GetConfig(owner)

  local width, height = Spotlight.GetFrameSize(owner)
  local _, columns, rows = Spotlight.GetGridDimensions(spotlightDB)
  local spacingX = Round(spotlightDB and spotlightDB.spacingX or 0)
  local spacingY = Round(spotlightDB and spotlightDB.spacingY or 0)

  local totalWidth = (width * columns) + (spacingX * (columns - 1))
  local totalHeight = (height * rows) + (spacingY * (rows - 1))

  return totalWidth, totalHeight
end

function Spotlight.IterateGroupedUnits(callback)
  if not callback then
    return
  end

  if IsInRaid() then
    for i = 1, 40 do
      local unit = "raid" .. tostring(i)
      if UnitExists(unit) then
        callback(unit)
      end
    end
    return
  end

  if UnitExists("player") then
    callback("player")
  end

  for i = 1, 4 do
    local unit = "party" .. tostring(i)
    if UnitExists(unit) then
      callback(unit)
    end
  end
end

function Spotlight.BuildUnitNameLookup()
  local units = {}

  Spotlight.IterateGroupedUnits(function(unit)
    local fullName = GetUnitName(unit, true)
    if type(fullName) == "string" and fullName ~= "" then
      units[fullName:lower()] = unit
    end

    local shortName = GetUnitName(unit, false)
    if type(shortName) == "string" and shortName ~= "" then
      units[shortName:lower()] = unit
    end
  end)

  return units
end

function Spotlight.BuildResolveLookup(spotlightDB, count)
  count = tonumber(count) or tonumber(spotlightDB and spotlightDB.count) or 1
  if count < 1 then
    count = 1
  elseif count > Spotlight.MAX_SLOTS then
    count = Spotlight.MAX_SLOTS
  end

  local slots = spotlightDB and spotlightDB.slots
  for index = 1, count do
    local slot = slots and slots[index] or nil
    local mode = slot and slot.mode or "NONE"
    if (mode == "ROSTERMEMBER" and type(slot.rosterName) == "string" and slot.rosterName ~= "")
      or (mode == "UNITNAME" and type(slot.unitName) == "string" and slot.unitName ~= "")
    then
      return Spotlight.BuildUnitNameLookup()
    end
  end

  return nil
end

function Spotlight.ResolveUnit(slot, lookup)
  if type(slot) ~= "table" then
    return nil
  end

  local mode = slot.mode or "NONE"
  if mode == "ROSTERMEMBER" then
    if type(slot.rosterName) == "string" and slot.rosterName ~= "" then
      return lookup and lookup[slot.rosterName:lower()] or nil
    end
  elseif mode == "UNITNAME" then
    if type(slot.unitName) == "string" and slot.unitName ~= "" then
      return lookup and lookup[slot.unitName:lower()] or nil
    end
  end

  return nil
end


function Spotlight.GetSlotLabel(slot, index)
  if type(slot) ~= "table" then
    return "Spotlight " .. tostring(index)
  end

  local mode = slot.mode or "NONE"
  if mode == "ROSTERMEMBER" then
    if type(slot.rosterName) == "string" and slot.rosterName ~= "" then
      return slot.rosterName
    end
    return "Roster Member"
  elseif mode == "UNITNAME" then
    if type(slot.unitName) == "string" and slot.unitName ~= "" then
      return slot.unitName
    end
    return "Unit Name"
  end

  return "Spotlight " .. tostring(index)
end

function Spotlight.IterateFrames(owner, callback)
  if not owner or not callback or type(owner.spotlightFrames) ~= "table" then
    return
  end

  for index = 1, Spotlight.MAX_SLOTS do
    local frame = owner.spotlightFrames[index]
    if frame then
      callback(frame, index)
    end
  end
end

function Spotlight.EnsureAnchor(owner)
  local spotlightDB = Spotlight.GetConfig(owner)
  local anchor = owner.spotlightAnchor

  if not anchor then
    anchor = CreateFrame("Frame", "PleebUI_RaidSpotlightAnchor", UIParent)
    anchor:SetClampedToScreen(true)
    owner.spotlightAnchor = anchor
  end

  local width, height = Spotlight.GetTotalSize(owner, spotlightDB)
  anchor:SetSize(width, height)

  owner._spotlightMoverOwner = owner._spotlightMoverOwner or {}
  owner._spotlightMoverOwner.anchor = anchor

  local mover = FrameUtil.EnsureHeaderMover(
    owner._spotlightMoverOwner,
    "RaidSpotlightFrames",
    "PleebUI_RaidSpotlightMover",
    anchor,
    spotlightDB,
    {
      defaultPoint = "CENTER",
      defaultRelativePoint = "CENTER",
      label = "Spotlight",
      optionsString = "unitframes,raid",
      quickSettings = function()
        return {
          ownerKey = "RaidSpotlightFrames",
          title = "Spotlight",
          description = "Live Spotlight frame settings.",
          controls = {
            {
              type = "slider",
              label = "Width",
              min = 40,
              max = 300,
              step = 1,
              get = function() return spotlightDB.width end,
              set = function(value)
                spotlightDB.width = Round(value)
                Spotlight.Refresh(owner, true)
              end,
            },
            {
              type = "slider",
              label = "Height",
              min = 20,
              max = 160,
              step = 1,
              get = function() return spotlightDB.height end,
              set = function(value)
                spotlightDB.height = Round(value)
                Spotlight.Refresh(owner, true)
              end,
            },
            {
              type = "slider",
              label = "Frames",
              min = 1,
              max = Spotlight.MAX_SLOTS,
              step = 1,
              get = function() return spotlightDB.count end,
              set = function(value)
                spotlightDB.count = Round(value)
                if spotlightDB.columns > spotlightDB.count then
                  spotlightDB.columns = spotlightDB.count
                end
                Spotlight.Refresh(owner, true)
              end,
            },
            {
              type = "slider",
              label = "Frames per row",
              min = 1,
              max = Spotlight.MAX_SLOTS,
              step = 1,
              get = function() return spotlightDB.columns end,
              set = function(value)
                spotlightDB.columns = Round(value)
                Spotlight.Refresh(owner, true)
              end,
            },
          },
        }
      end,
    }
  )

  if mover then
    owner.spotlightMover = mover
  else
    anchor:ClearAllPoints()
    anchor:SetPoint(
      spotlightDB.point or "CENTER",
      _G[spotlightDB.relativeTo or "UIParent"] or UIParent,
      spotlightDB.relativePoint or spotlightDB.point or "CENTER",
      Round(spotlightDB.x or 0),
      Round(spotlightDB.y or 0)
    )
  end

  return anchor
end

function Spotlight.EnsurePlaceholders(owner, anchor)
  if not owner then
    return nil
  end

  anchor = anchor or Spotlight.EnsureAnchor(owner)
  if not anchor then
    return nil
  end

  owner.spotlightPlaceholders = owner.spotlightPlaceholders or {}

  for index = 1, Spotlight.MAX_SLOTS do
    local placeholder = owner.spotlightPlaceholders[index]
    if not placeholder then
      placeholder = CreateFrame("Frame", "PleebUI_RaidSpotlightPlaceholder" .. tostring(index), anchor, "BackdropTemplate")
      local edgeSize = ns.FrameScale:BestOnePixel()
      placeholder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })
      placeholder.__puiBackdropEdgeSize = edgeSize
      placeholder:SetBackdropColor(0, 0, 0, 0.25)
      placeholder:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.85)

      placeholder.Text = placeholder:CreateFontString(nil, "OVERLAY")
      placeholder.Text:SetPoint("TOPLEFT", placeholder, "TOPLEFT", Round(4), -Round(4))
      placeholder.Text:SetPoint("BOTTOMRIGHT", placeholder, "BOTTOMRIGHT", -Round(4), Round(4))
      placeholder.Text:SetJustifyH("CENTER")
      placeholder.Text:SetJustifyV("MIDDLE")
      placeholder.Text:SetWordWrap(true)

      Theme.ApplyFont(placeholder.Text, "body", 10, "OUTLINE")

      owner.spotlightPlaceholders[index] = placeholder
    end

    local edgeSize = ns.FrameScale:BestOnePixel()
    if placeholder.__puiBackdropEdgeSize ~= edgeSize then
      placeholder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })
      placeholder.__puiBackdropEdgeSize = edgeSize
    end

    placeholder.Text:ClearAllPoints()
    placeholder.Text:SetPoint(
      "TOPLEFT",
      placeholder,
      "TOPLEFT",
      Round(4),
      -Round(4)
    )
    placeholder.Text:SetPoint(
      "BOTTOMRIGHT",
      placeholder,
      "BOTTOMRIGHT",
      -Round(4),
      Round(4)
    )
  end

  return owner.spotlightPlaceholders
end

function Spotlight.EnsureFrames(owner, anchor)
  if not owner then
    return nil
  end

  if InCombatLockdown() then
    return owner.spotlightFrames
  end

  anchor = anchor or Spotlight.EnsureAnchor(owner)
  if not anchor then
    return nil
  end

  owner:RegisterStyle()
  owner.spotlightFrames = owner.spotlightFrames or {}

  for index = 1, Spotlight.MAX_SLOTS do
    local frame = owner.spotlightFrames[index]
    if not frame then
      local prev = oUF:GetActiveStyle()
      oUF:SetActiveStyle("PleebUI_RaidSpotlightFrames")
      frame = oUF:Spawn("raid1", "PleebUI_RaidSpotlightFrame" .. tostring(index))
      oUF:SetActiveStyle(prev)

      frame:SetParent(anchor)
      frame.__puiIsRaidSpotlight = true
      frame.__puiSpotlightIndex = index
      owner.spotlightFrames[index] = frame
    end
  end

  return owner.spotlightFrames
end

function Spotlight.LayoutFrames(owner, spotlightDB, placeholders, frames, anchor)
  if not owner then
    return
  end

  spotlightDB = spotlightDB or Spotlight.GetConfig(owner)
  anchor = anchor or Spotlight.EnsureAnchor(owner)
  placeholders = placeholders or Spotlight.EnsurePlaceholders(owner, anchor)
  frames = frames or owner.spotlightFrames

  if not spotlightDB or not placeholders or not anchor then
    return
  end

  local width, height = Spotlight.GetFrameSize(owner)
  local totalWidth, totalHeight = Spotlight.GetTotalSize(owner, spotlightDB)
  local count, columns = Spotlight.GetGridDimensions(spotlightDB)
  local spacingX = Round(spotlightDB.spacingX or 0)
  local spacingY = Round(spotlightDB.spacingY or 0)
  local growthX = spotlightDB.growthX or "RIGHT"
  local growthY = spotlightDB.growthY or "DOWN"

  anchor:SetSize(totalWidth, totalHeight)
  if owner.spotlightMover then
    owner.spotlightMover:SetSize(totalWidth, totalHeight)
  end

  local anchorPoint
  if growthY == "UP" then
    anchorPoint = (growthX == "LEFT") and "BOTTOMRIGHT" or "BOTTOMLEFT"
  else
    anchorPoint = (growthX == "LEFT") and "TOPRIGHT" or "TOPLEFT"
  end

  for index = 1, Spotlight.MAX_SLOTS do
    local placeholder = placeholders[index]
    local frame = frames and frames[index] or nil
    local isVisibleIndex = index <= count

    local column = (index - 1) % columns
    local row = math_floor((index - 1) / columns)
    local xOffset = column * (width + spacingX) * ((growthX == "LEFT") and -1 or 1)
    local yOffset = row * (height + spacingY) * ((growthY == "UP") and 1 or -1)

    placeholder:ClearAllPoints()
    placeholder:SetSize(width, height)
    placeholder:SetPoint(anchorPoint, anchor, anchorPoint, xOffset, yOffset)
    placeholder:SetShown(isVisibleIndex)

    if frame then
      frame:ClearAllPoints()
      frame:SetPoint(anchorPoint, anchor, anchorPoint, xOffset, yOffset)
    end
  end
end

function Spotlight.UpdatePlaceholders(owner, editing, spotlightDB)
  if not owner then
    return
  end

  editing = editing == true

  spotlightDB = spotlightDB or Spotlight.GetConfig(owner)
  local placeholders = owner.spotlightPlaceholders
  if not spotlightDB or type(placeholders) ~= "table" then
    return
  end

  local count = tonumber(spotlightDB.count) or 1
  if count < 1 then
    count = 1
  elseif count > Spotlight.MAX_SLOTS then
    count = Spotlight.MAX_SLOTS
  end

  local showPlaceholders = spotlightDB.showPlaceholders == true or editing == true

  for index = 1, Spotlight.MAX_SLOTS do
    local slot = spotlightDB.slots and spotlightDB.slots[index] or nil
    local frame = owner.spotlightFrames and owner.spotlightFrames[index] or nil
    local placeholder = placeholders[index]
    local hasAssignment = slot and slot.mode and slot.mode ~= "NONE"
    local showPlaceholder = false

    if placeholder then
      placeholder.Text:SetText(Spotlight.GetSlotLabel(slot, index))
    end

    if index > count then
      showPlaceholder = false
    elseif editing then
      showPlaceholder = true
    elseif hasAssignment and showPlaceholders then
      local unit = frame and frame:GetAttribute("unit") or nil
      showPlaceholder = not (frame and frame:IsShown() and type(unit) == "string" and unit ~= "" and UnitExists(unit))
    end

    if placeholder then
      placeholder:SetShown(showPlaceholder)
    end
  end
end

function Spotlight.HideAll(owner, clearUnits)
  if not owner then
    return
  end

  if owner.spotlightAnchor then owner.spotlightAnchor:Hide() end
  if owner.spotlightMover then owner.spotlightMover:Hide() end

  if owner.spotlightFrames then
    for index = 1, Spotlight.MAX_SLOTS do
      local frame = owner.spotlightFrames[index]
      if frame and clearUnits == true and not InCombatLockdown() then
        frame:SetAttribute("unit", nil)
      end
      if frame then
        frame:Hide()
      end
    end
  end

  if owner.spotlightPlaceholders then
    for index = 1, Spotlight.MAX_SLOTS do
      local placeholder = owner.spotlightPlaceholders[index]
      if placeholder then
        placeholder:Hide()
      end
    end
  end
end

function Spotlight.Refresh(owner, forceLayoutOnly)
  if not owner then
    return
  end

  if type(forceLayoutOnly) == "table" then
    forceLayoutOnly = forceLayoutOnly.forceLayoutOnly == true
  else
    forceLayoutOnly = forceLayoutOnly == true
  end

  local db = owner.db.profile
  local spotlightDB = db.spotlight
  local editing = ns.Flags.IsEditing == true

  if db.enabled == false or not spotlightDB or spotlightDB.enabled == false then
    Spotlight.HideAll(owner, true)

    return
  end

  local anchor = Spotlight.EnsureAnchor(owner)
  local placeholders = Spotlight.EnsurePlaceholders(owner, anchor)

  if InCombatLockdown() then
    owner._pendingSpotlightRefresh = true
    Spotlight.LayoutFrames(owner, spotlightDB, placeholders, owner.spotlightFrames, anchor)
    Spotlight.UpdatePlaceholders(owner, editing, spotlightDB)
    if anchor then
      anchor:SetShown(true)
    end
    return
  end

  owner._pendingSpotlightRefresh = nil

  local frames = Spotlight.EnsureFrames(owner, anchor)
  if not frames then
    return
  end

  Spotlight.LayoutFrames(owner, spotlightDB, placeholders, frames, anchor)
  anchor:SetShown(true)

  local count = tonumber(spotlightDB.count) or 1
  if count < 1 then
    count = 1
  elseif count > Spotlight.MAX_SLOTS then
    count = Spotlight.MAX_SLOTS
  end

  local lookup = Spotlight.BuildResolveLookup(spotlightDB, count)

  for index = 1, Spotlight.MAX_SLOTS do
    local frame = frames[index]
    local slot = spotlightDB.slots and spotlightDB.slots[index] or nil
    local liveVisible = index <= count and editing ~= true and slot and slot.mode and slot.mode ~= "NONE"
    local resolvedUnit = liveVisible and Spotlight.ResolveUnit(slot, lookup) or nil

    if frame then
      local currentUnit = frame:GetAttribute("unit")
      if currentUnit ~= resolvedUnit then
        frame:SetAttribute("unit", resolvedUnit)
      end

      if liveVisible and resolvedUnit then
        if forceLayoutOnly ~= true then
          owner:Update_SpotlightFrames(frame)
        end
        frame:Show()
      else
        frame:Hide()
      end
    end
  end

  Spotlight.UpdatePlaceholders(owner, editing, spotlightDB)
end

function Spotlight.SetMoversVisible(owner, show)
  if not owner then
    return
  end

  if owner.spotlightMover then
    FrameUtil.SetMoverFrameVisible(owner.spotlightMover, show == true)
  end

  if show then
    if owner.spotlightFrames then
      for index = 1, Spotlight.MAX_SLOTS do
        local frame = owner.spotlightFrames[index]
        if frame then
          frame:Hide()
        end
      end
    end

    Spotlight.UpdatePlaceholders(owner, true)
  end
end


local P = select(1, ns.Pleebug:DropIn(Spotlight, { name = "UnitFrames.Spotlight" }))



  Spotlight.NormalizeConfig = P:Def("Spotlight.NormalizeConfig", Spotlight.NormalizeConfig)
  Spotlight.GetConfig = P:Def("Spotlight.GetConfig", Spotlight.GetConfig)
  Spotlight.GetSizeConfig = P:Def("Spotlight.GetSizeConfig", Spotlight.GetSizeConfig)
  Spotlight.GetFrameSize = P:Def("Spotlight.GetFrameSize", Spotlight.GetFrameSize)
  Spotlight.GetGridDimensions = P:Def("Spotlight.GetGridDimensions", Spotlight.GetGridDimensions)
  Spotlight.GetTotalSize = P:Def("Spotlight.GetTotalSize", Spotlight.GetTotalSize)
  Spotlight.IterateGroupedUnits = P:Def("Spotlight.IterateGroupedUnits", Spotlight.IterateGroupedUnits)
  Spotlight.BuildUnitNameLookup = P:Def("Spotlight.BuildUnitNameLookup", Spotlight.BuildUnitNameLookup)
  Spotlight.BuildResolveLookup = P:Def("Spotlight.BuildResolveLookup", Spotlight.BuildResolveLookup)
  Spotlight.ResolveUnit = P:Def("Spotlight.ResolveUnit", Spotlight.ResolveUnit)
  Spotlight.GetSlotLabel = P:Def("Spotlight.GetSlotLabel", Spotlight.GetSlotLabel)
  Spotlight.IterateFrames = P:Def("Spotlight.IterateFrames", Spotlight.IterateFrames)
  Spotlight.EnsureAnchor = P:Def("Spotlight.EnsureAnchor", Spotlight.EnsureAnchor)
  Spotlight.EnsurePlaceholders = P:Def("Spotlight.EnsurePlaceholders", Spotlight.EnsurePlaceholders)
  Spotlight.EnsureFrames = P:Def("Spotlight.EnsureFrames", Spotlight.EnsureFrames)
  Spotlight.LayoutFrames = P:Def("Spotlight.LayoutFrames", Spotlight.LayoutFrames)
  Spotlight.UpdatePlaceholders = P:Def("Spotlight.UpdatePlaceholders", Spotlight.UpdatePlaceholders)
  Spotlight.HideAll = P:Def("Spotlight.HideAll", Spotlight.HideAll)
  Spotlight.Refresh = P:Def("Spotlight.Refresh", Spotlight.Refresh)
  Spotlight.SetMoversVisible = P:Def("Spotlight.SetMoversVisible", Spotlight.SetMoversVisible)


