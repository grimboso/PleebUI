
-- File: PUI_UF_TankFrames.lua
-- Purpose: Raid main tank header spawning, layout, mover, and visibility handling.


local ADDON_NAME, ns = ...

ns.UFTankFrames = ns.UFTankFrames or {}

local TankFrames = ns.UFTankFrames

local _G = _G
local UIParent = _G.UIParent
local RegisterAttributeDriver = _G.RegisterAttributeDriver
local UnregisterAttributeDriver = _G.UnregisterAttributeDriver
local type = _G.type

local FrameUtil = ns.FrameUtil
local UFLayout = ns.UFLayout
local UF = ns.UnitFrames
local oUF = ns.oUF

local P = select(1, ns.Pleebug:DropIn(TankFrames, { name = "UnitFrames.TankFrames" }))

local MAIN_TANK_HEADER_SPACING = 6

local Round = ns.Pixel.Round


local function SetHeaderAttribute(header, name, value)
  if header:GetAttribute(name) ~= value then
    header:SetAttribute(name, value)
  end
end

local function SetSecureHeaderShown(header, shown)
  if shown then
    header:Hide()
    RegisterAttributeDriver(header, "state-visibility", "[@raid1,exists] show;hide")
  else
    UnregisterAttributeDriver(header, "state-visibility")
    header:Hide()
  end
end

function TankFrames.EnsureMoverDB(owner)
  local db = owner.db.profile

  db.mainTankMover = db.mainTankMover or {}

  if db.mainTankMover.point and db.mainTankMover.relativePoint then
    return db.mainTankMover
  end

  local point = FrameUtil.GetGroupedMoverAnchorPoint(db)
  local x, y = FrameUtil.GetPointOffsetsForFrame(owner.mainTankHeader, point)

  db.mainTankMover.point = point
  db.mainTankMover.relativeTo = "UIParent"
  db.mainTankMover.relativePoint = point
  db.mainTankMover.x = x
  db.mainTankMover.y = y

  return db.mainTankMover
end

function TankFrames.ReanchorMover(owner)
  local moverDB = owner.db.profile.mainTankMover

  owner.mainTankMover:ClearAllPoints()
  owner.mainTankMover:SetPoint(
    moverDB.point or "CENTER",
    _G[moverDB.relativeTo or "UIParent"] or UIParent,
    moverDB.relativePoint or moverDB.point or "CENTER",
    Round(moverDB.x or 0),
    Round(moverDB.y or 0)
  )
end

function TankFrames.EnsureMover(owner)
  local db = owner.db.profile
  local moverDB = TankFrames.EnsureMoverDB(owner)

  owner._mainTankMoverOwner = owner._mainTankMoverOwner or {}

  local point = FrameUtil.GetGroupedMoverAnchorPoint(db)
  local mover = FrameUtil.EnsureHeaderMover(
    owner._mainTankMoverOwner,
    "RaidMainTankFrames",
    "PleebUI_RaidMainTankMover",
    owner.mainTankHeader,
    moverDB,
    {
      defaultPoint = moverDB.point or point,
      defaultRelativePoint = moverDB.relativePoint or moverDB.point or point,
      anchorPoint = moverDB.point or point,
      anchorRelativePoint = moverDB.relativePoint or moverDB.point or point,
      label = "Main Tanks",
      optionsString = "unitframes,raid",
      getDB = function()
        return owner.db.profile.mainTankMover
      end,
      smartSnap = {
        family = "positionOnly",
        isRuntimeActive = function()
          local profile = owner.db.profile
          return owner:IsEnabled()
            and profile.enabled ~= false
            and profile.enableMainTankFrames == true
        end,
      },
      quickSettings = function()
        return ns.UnitFrameTest:OpenQuickSettings("RaidFrames")
      end,
      resetPosition = function()
        local existingMover = owner.mainTankMover
        owner.db.profile.mainTankMover = nil
        owner.mainTankMover = nil
        TankFrames.ApplyHeaderAnchor(owner)
        TankFrames.EnsureMoverDB(owner)
        owner.mainTankMover = existingMover
        TankFrames.EnsureMover(owner)
      end,
      onDragStop = function(_, mainTankDB)
        mainTankDB.relativeTo = "UIParent"
        TankFrames.ReanchorMover(owner)
      end,
    }
  )

  owner.mainTankMover = mover
  TankFrames.ReanchorMover(owner)

  return mover
end

function TankFrames.ApplyHeaderAnchor(owner)
  local db = owner.db.profile
  local moverDB = db.mainTankMover

  if owner.mainTankMover and type(moverDB) == "table" and moverDB.point and moverDB.relativePoint then
    owner.mainTankHeader:ClearAllPoints()
    owner.mainTankHeader:SetPoint(moverDB.point, owner.mainTankMover, moverDB.relativePoint, 0, 0)
    return
  end

  local xDir, yDir = FrameUtil.GetGroupedLayoutDirectionParts(db)
  local width = Round(db.width or 80)
  local point = (yDir == "UP") and "BOTTOM" or "TOP"
  local relativePoint
  local xOffset = Round((width / 2) + MAIN_TANK_HEADER_SPACING)

  if xDir == "LEFT" then
    relativePoint = (yDir == "UP") and "BOTTOMLEFT" or "TOPLEFT"
    xOffset = -xOffset
  else
    relativePoint = (yDir == "UP") and "BOTTOMRIGHT" or "TOPRIGHT"
  end

  owner.mainTankHeader:ClearAllPoints()
  owner.mainTankHeader:SetPoint(point, owner.anchor, relativePoint, xOffset, 0)
end

function TankFrames.EnsureHeader(owner)
  if owner.mainTankHeader then
    return owner.mainTankHeader
  end

  local db = owner.db.profile
  local yDir = select(2, FrameUtil.GetGroupedLayoutDirectionParts(db))
  local rowSpacing = Round(db.rowSpacing or 3)
  local pointAttr = (yDir == "UP") and "BOTTOM" or "TOP"
  local yOffsetAttr = (yDir == "UP") and rowSpacing or -rowSpacing

  owner:RegisterStyle()

  local prevStyle = oUF:GetActiveStyle()
  oUF:SetActiveStyle("PleebUI_RaidMainTankFrames")

  local header = oUF:SpawnHeader("PleebUI_RaidMainTankHeader", nil, {
    showParty = false,
    showRaid = true,
    showSolo = false,
    showPlayer = false,
    groupFilter = "MAINTANK",
    sortMethod = (db.sortOrder == "NAME") and "NAME" or "INDEX",
    sortDir = db.sortDir or "ASC",
    point = pointAttr,
    xOffset = 0,
    yOffset = yOffsetAttr,
    maxColumns = 1,
    unitsPerColumn = 40,
    columnSpacing = 0,
    columnAnchorPoint = "LEFT",
    ["oUF-initialConfigFunction"] = ("self:SetWidth(%d); self:SetHeight(%d);"):format(UFLayout.GetRaidMainFrameSize(db)),
  })

  oUF:SetActiveStyle(prevStyle)

  owner.mainTankHeader = header
  owner:EnsureAnchor()
  header:SetParent(UIParent)

  TankFrames.ApplyHeaderAnchor(owner)
  header:Show()
  TankFrames.EnsureMover(owner)

  return header
end

local function ConfigureTankChildren(owner)
  UF:IterateHeaderChildren(owner.mainTankHeader, function(frame)
    owner:Update_RaidFrames(frame)
  end)
end

function TankFrames.RefreshLayout(owner)
  local db = owner.db.profile

  if db.enableMainTankFrames ~= true then
    if owner.mainTankHeader then
      SetSecureHeaderShown(owner.mainTankHeader, false)
    end

    if owner.mainTankMover then
      owner.mainTankMover:Hide()
    end

    return
  end

  local header = TankFrames.EnsureHeader(owner)
  local _, yDir = FrameUtil.GetGroupedLayoutDirectionParts(db)
  local rowSpacing = Round(db.rowSpacing or 3)
  local width, height = UFLayout.GetRaidMainFrameSize(db)

  SetHeaderAttribute(header, "showParty", false)
  SetHeaderAttribute(header, "showRaid", true)
  SetHeaderAttribute(header, "showSolo", false)
  SetHeaderAttribute(header, "showPlayer", false)
  SetHeaderAttribute(header, "groupFilter", "MAINTANK")
  SetHeaderAttribute(header, "sortMethod", (db.sortOrder == "NAME") and "NAME" or "INDEX")
  SetHeaderAttribute(header, "sortDir", db.sortDir or "ASC")
  SetHeaderAttribute(header, "point", (yDir == "UP") and "BOTTOM" or "TOP")
  SetHeaderAttribute(header, "xOffset", 0)
  SetHeaderAttribute(header, "yOffset", (yDir == "UP") and rowSpacing or -rowSpacing)
  SetHeaderAttribute(header, "maxColumns", 1)
  SetHeaderAttribute(header, "unitsPerColumn", 40)
  SetHeaderAttribute(header, "columnSpacing", 0)
  SetHeaderAttribute(header, "columnAnchorPoint", "LEFT")
  SetHeaderAttribute(header, "oUF-initialConfigFunction", ("self:SetWidth(%d); self:SetHeight(%d);"):format(width, height))

  TankFrames.EnsureMover(owner)
  TankFrames.ApplyHeaderAnchor(owner)
  SetSecureHeaderShown(header, true)
end

function TankFrames.RefreshResizeGeometry(owner)
  local db = owner.db.profile

  if db.enableMainTankFrames ~= true or not owner.mainTankHeader then
    return
  end

  local width, height = UFLayout.GetRaidMainFrameSize(db)
  SetHeaderAttribute(
    owner.mainTankHeader,
    "oUF-initialConfigFunction",
    ("self:SetWidth(%d); self:SetHeight(%d);"):format(width, height)
  )

  TankFrames.EnsureMover(owner)
  TankFrames.ApplyHeaderAnchor(owner)
end

function TankFrames.Refresh(owner)
  TankFrames.RefreshLayout(owner)

  if owner.db.profile.enableMainTankFrames == true then
    ConfigureTankChildren(owner)
  end
end

function TankFrames.Hide(owner)
  if owner.mainTankHeader then
    SetSecureHeaderShown(owner.mainTankHeader, false)
  end

  if owner.mainTankMover then
    owner.mainTankMover:Hide()
  end
end

function TankFrames.SetMoverVisible(owner, show)
  if owner.mainTankMover then
    FrameUtil.SetMoverFrameVisible(
      owner.mainTankMover,
      show == true
        and owner:IsEnabled()
        and owner.db.profile.enabled ~= false
        and owner.db.profile.enableMainTankFrames == true
    )
  end
end

function TankFrames.IterateFrames(owner, callback)
  if owner.mainTankHeader then
    UF:IterateHeaderChildren(owner.mainTankHeader, callback)
  end
end


Round = P:Def("Round", Round)
SetHeaderAttribute = P:Def("SetHeaderAttribute", SetHeaderAttribute)
SetSecureHeaderShown = P:Def("SetSecureHeaderShown", SetSecureHeaderShown)
ConfigureTankChildren = P:Def("ConfigureTankChildren", ConfigureTankChildren)
TankFrames.EnsureMoverDB = P:Def("TankFrames.EnsureMoverDB", TankFrames.EnsureMoverDB)
TankFrames.ReanchorMover = P:Def("TankFrames.ReanchorMover", TankFrames.ReanchorMover)
TankFrames.EnsureMover = P:Def("TankFrames.EnsureMover", TankFrames.EnsureMover)
TankFrames.ApplyHeaderAnchor = P:Def("TankFrames.ApplyHeaderAnchor", TankFrames.ApplyHeaderAnchor)
TankFrames.EnsureHeader = P:Def("TankFrames.EnsureHeader", TankFrames.EnsureHeader)
TankFrames.RefreshLayout = P:Def("TankFrames.RefreshLayout", TankFrames.RefreshLayout)
TankFrames.RefreshResizeGeometry = P:Def("TankFrames.RefreshResizeGeometry", TankFrames.RefreshResizeGeometry)
TankFrames.Refresh = P:Def("TankFrames.Refresh", TankFrames.Refresh)
TankFrames.Hide = P:Def("TankFrames.Hide", TankFrames.Hide)
TankFrames.SetMoverVisible = P:Def("TankFrames.SetMoverVisible", TankFrames.SetMoverVisible)
TankFrames.IterateFrames = P:Def("TankFrames.IterateFrames", TankFrames.IterateFrames)
