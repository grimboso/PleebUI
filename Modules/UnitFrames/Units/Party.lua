local ADDON_NAME, ns = ...

local Addon = ns.Addon
local oUF = ns.oUF
local UF = ns.UnitFrames
local UFDefaults = ns.UFDefaults
local UFAuraContainers = ns.UFAuraContainers
local UFStyle = ns.UFStyle
local UFMouseover = ns.UFMouseover
local UFThreat = ns.UFThreat
local UFFrameGlow = ns.UFFrameGlow
local FrameUtil = ns.FrameUtil
local UFIndicators = ns.UFIndicators
local UFText = ns.UFText
local Range = ns.Range

local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local InCombatLockdown = _G.InCombatLockdown
local RegisterStateDriver = _G.RegisterStateDriver
local UnregisterStateDriver = _G.UnregisterStateDriver
local IsInRaid = _G.IsInRaid
local UnitName = _G.UnitName
local UnitGUID = _G.UnitGUID
local issecretvalue = _G.issecretvalue
local type = _G.type
local pairs = _G.pairs
local tonumber = _G.tonumber
local math_max = _G.math.max
local math_min = _G.math.min
local table_sort = _G.table.sort
local setmetatable = _G.setmetatable

local PartyFrames = Addon:NewModule("PartyFrames", "NumyAceEvent-3.0")
ns.Modules.PartyFrames = PartyFrames

local ROLE_NAME_BY_ENUM = {
  [Enum.LFGRole.Tank] = "TANK",
  [Enum.LFGRole.Healer] = "HEALER",
  [Enum.LFGRole.Damage] = "DAMAGER",
}

local Round = ns.Pixel.Round

local DISABLED_PET_AURAS = { enabled = false }
local DISABLED_PET_TRACKING = { enabled = false, tracks = {} }
local DISABLED_PET_PORTRAIT = { enabled = false }

local function ReadPartyProfile(_, key)
  return PartyFrames.db.profile[key]
end

local function ReadPartyPetProfile(_, key)
  local db = PartyFrames.db.profile
  local petDB = db.partyPets
  local value = petDB and petDB[key]

  if value ~= nil then
    return value
  end

  return db[key]
end

local PartyFrameConfig = setmetatable({}, { __index = ReadPartyProfile })
local PartyPetFrameConfig = setmetatable({}, { __index = ReadPartyPetProfile })

local VALID_ASSIGNED_ROLES = {
  TANK = true,
  HEALER = true,
  DAMAGER = true,
}

local function GetPartyGroupBy(db)
  local value = db and db.groupBy or nil
  if value ~= "NAME" and value ~= "ROLE" then
    value = "INDEX"
  end
  return value
end

local function GetPartySortOrder(db)
  local value = db and db.sortOrder or nil
  if value ~= "NAME" then
    value = "INDEX"
  end
  return value
end

local function GetPartySortDirection(db)
  return db and db.sortDir == "DESC" and "DESC" or "ASC"
end

local function GetPartyRoleRank(db, role)
  if not VALID_ASSIGNED_ROLES[role] then
    return 4
  end

  local role1 = VALID_ASSIGNED_ROLES[db.ROLE1] and db.ROLE1 or "TANK"
  local role2 = VALID_ASSIGNED_ROLES[db.ROLE2] and db.ROLE2 or "HEALER"
  local role3 = VALID_ASSIGNED_ROLES[db.ROLE3] and db.ROLE3 or "DAMAGER"

  if role == role1 then
    return 1
  elseif role == role2 then
    return 2
  elseif role == role3 then
    return 3
  end

  return 4
end

local function ComparePartyIndex(firstFrame, secondFrame, descending)
  local firstIndex = firstFrame.partyIndex or 0
  local secondIndex = secondFrame.partyIndex or 0

  if firstIndex == secondIndex then
    return false
  end

  if descending then
    return firstIndex > secondIndex
  end

  return firstIndex < secondIndex
end

local function ComparePartyNames(firstFrame, secondFrame, descending)
  local firstName = UnitName(firstFrame.__unit)
  local secondName = UnitName(secondFrame.__unit)

  if issecretvalue(firstName) or issecretvalue(secondName) then
    return ComparePartyIndex(firstFrame, secondFrame, descending)
  end

  firstName = firstName or firstFrame.__unit or ""
  secondName = secondName or secondFrame.__unit or ""

  if firstName == secondName then
    return ComparePartyIndex(firstFrame, secondFrame, descending)
  end

  if descending then
    return firstName > secondName
  end

  return firstName < secondName
end

local function ComparePartyFrames(db, firstFrame, secondFrame)
  local groupBy = GetPartyGroupBy(db)
  local descending = GetPartySortDirection(db) == "DESC"

  if groupBy == "NAME" then
    return ComparePartyNames(firstFrame, secondFrame, descending)
  elseif groupBy == "ROLE" then
    local firstRole = ROLE_NAME_BY_ENUM[firstFrame.__puiGroupRole] or "NONE"
    local secondRole = ROLE_NAME_BY_ENUM[secondFrame.__puiGroupRole] or "NONE"

    local firstRank = GetPartyRoleRank(db, firstRole)
    local secondRank = GetPartyRoleRank(db, secondRole)

    if firstRank ~= secondRank then
      return firstRank < secondRank
    end

    if GetPartySortOrder(db) == "NAME" then
      return ComparePartyNames(firstFrame, secondFrame, descending)
    end
  end

  return ComparePartyIndex(firstFrame, secondFrame, descending)
end

local function GetPartyVisibilityDriver(db)
  if db.hideInRaid == false then
    if db.showSolo == true then
      return "show"
    end

    return "[group:party] show; [group:raid] show; hide"
  elseif db.showSolo == true then
    return "[group:raid] hide; show"
  end

  return "[group:party,nogroup:raid] show; hide"
end

local function ShouldProcessPartyGroupEvents(db)
  return db.enabled ~= false
    and not (db.hideInRaid ~= false and IsInRaid())
end

local function ApplyAnchor(self)
  local db = PartyFrames.db.profile
  local anchor = self.anchor
  local point = db.point or "CENTER"
  local width, height = UFStyle.ResolveFrameSize(db)

  anchor:ClearAllPoints()
  anchor:SetPoint(point, _G[db.relativeTo or "UIParent"] or UIParent, db.relativePoint or point, Round(db.x or 0), Round(db.y or 0))

  FrameUtil.UpdateLinearHeaderAnchorSize(self, {
    count = self.partyFrames and (self.partyPlayerFrame and 5 or 4) or ((db.showPlayer == true) and 5 or 4),
    width = width,
    height = height,
    spacing = Round(db.spacing or 8),
    orientation = db.orientation,
  })

  FrameUtil.EnsureHeaderMover(self, "PartyFrames", "PleebUI_PartyFramesMover", anchor, db, {
    defaultPoint = point,
    defaultRelativePoint = db.relativePoint or point,
    anchorPoint = point,
    anchorRelativePoint = point,
    label = "Party Frames",
    optionsString = "unitframes,party",
    overlayBelowFrame = false,
    getDB = function()
      return PartyFrames.db.profile
    end,
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        return PartyFrames:IsEnabled() and PartyFrames.db.profile.enabled ~= false
      end,
    },
    quickSettings = function()
      return ns.UnitFrameTest:OpenQuickSettings("PartyFrames")
    end,
    resetPosition = function()
      local defaults = UFDefaults.GetPartyDefaults().profile
      local current = PartyFrames.db.profile
      current.point = defaults.point
      current.relativeTo = defaults.relativeTo
      current.relativePoint = defaults.relativePoint
      current.x = defaults.x
      current.y = defaults.y
      ApplyAnchor(self)
    end,
    onDragStop = function()
      if ns.TestMode:IsActive() then
        ns.TestMode:Refresh("unitframes", "mover", "uf.partySettings")
      end
    end,
  })
end

local function BuildPartyFrameConfig(db)
  PartyFrameConfig.width = Round(db.width or 170)
  PartyFrameConfig.height = Round(db.height or 36)
  PartyFrameConfig.powerHeight = Round(db.powerHeight or 5)
  PartyFrameConfig.showPower = db.showPower ~= false and PartyFrameConfig.powerHeight > 0

  return PartyFrameConfig
end

local function BuildPartyPetFrameConfig(db, petDB)
  PartyPetFrameConfig.enabled = petDB and petDB.enabled ~= false
  PartyPetFrameConfig.width = Round((petDB and petDB.width) or 90)
  PartyPetFrameConfig.height = Round((petDB and petDB.height) or 16)
  PartyPetFrameConfig.powerHeight = Round((petDB and petDB.powerHeight) or 0)
  PartyPetFrameConfig.showPower = petDB and petDB.showPower == true and PartyPetFrameConfig.powerHeight > 0
  PartyPetFrameConfig.auras = petDB and petDB.trackAuras and db.auras or DISABLED_PET_AURAS
  PartyPetFrameConfig.tracking = petDB and petDB.trackAuras and db.tracking or DISABLED_PET_TRACKING
  PartyPetFrameConfig.portrait = DISABLED_PET_PORTRAIT

  return PartyPetFrameConfig
end

function PartyFrames:GetTestFrameConfig(isPet)
  local db = PartyFrames.db.profile

  if isPet == true then
    local petDB = db.partyPets or {}
    return BuildPartyPetFrameConfig(db, petDB), db, petDB.showPower ~= true
  end

  return BuildPartyFrameConfig(db), db, false
end

function PartyFrames:LayoutTestFrames(memberFrames, petFrames, memberCount)
  if InCombatLockdown() then
    return false
  end

  local db = PartyFrames.db.profile
  local anchor = self:EnsureAnchor()
  local width, height = UFStyle.ResolveFrameSize(db)
  local spacing = Round(db.spacing or 8)
  local isHorizontal = db.orientation == "HORIZONTAL"
  local growsUp = not isHorizontal and (db.growthY or "DOWN") == "UP"

  memberCount = math_min(5, math_max(1, tonumber(memberCount) or 1))

  ApplyAnchor(self)
  FrameUtil.UpdateLinearHeaderAnchorSize(self, {
    count = memberCount,
    width = width,
    height = height,
    spacing = spacing,
    orientation = db.orientation,
  })

  for index, frame in pairs(memberFrames or {}) do
    frame:SetParent(UIParent)
    frame:ClearAllPoints()

    if index <= memberCount then
      local offset = index - 1

      if isHorizontal then
        frame:SetPoint("LEFT", anchor, "LEFT", offset * (width + spacing), 0)
      elseif growsUp then
        frame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, offset * (height + spacing))
      else
        frame:SetPoint("TOP", anchor, "TOP", 0, -offset * (height + spacing))
      end

      frame:Show()
    else
      frame:Hide()
    end
  end

  local petDB = db.partyPets or {}
  local showPets = petDB.enabled ~= false

  for index, frame in pairs(petFrames or {}) do
    local owner = memberFrames and memberFrames[index]

    frame:SetParent(UIParent)
    frame:ClearAllPoints()

    if showPets and index <= memberCount and owner then
      frame:SetPoint(
        petDB.anchorPoint or "TOP",
        owner,
        petDB.relativePoint or "BOTTOM",
        Round(petDB.x or 0),
        Round(petDB.y or -2)
      )
      frame:Show()
    else
      frame:Hide()
    end
  end

  return true
end

local function GetPartyProfile()
  return PartyFrames.db.profile
end

local function InvalidatePartyAuraDB()
  PartyFrames._auraDBCache = nil
end

local function BuildPartyAuraDB(unit)
  local cache = PartyFrames._auraDBCache
  if not cache then
    cache = {}
    PartyFrames._auraDBCache = cache
  end

  local key = type(unit) == "string" and unit:find("partypet", 1, true) and "pet" or "main"
  local aDB = cache[key]

  if not aDB then
    aDB = ns.UFAuraFilters.BuildGroupedAuraDB("party", GetPartyProfile(), unit)
    cache[key] = aDB
  end

  return aDB
end

local function RegisterPartyAuraAvailabilityEvents(frame)
  frame:RegisterEvent("UNIT_AREA_CHANGED", UFAuraContainers.RefreshAvailability)
  frame:RegisterEvent("UNIT_CONNECTION", UFAuraContainers.RefreshAvailability)
  frame:RegisterEvent("UNIT_PHASE", UFAuraContainers.RefreshAvailability)
end

local function UpdatePartyRosterIdentity(frame, refreshElements)
  local unit = frame and frame.__unit
  if not unit then
    return false
  end

  local guid = UnitGUID(unit)
  if issecretvalue(guid) then
    return false
  end

  local rosterGUID = guid or false
  if frame.__puiRosterGUID == rosterGUID then
    return false
  end

  frame.__puiRosterGUID = rosterGUID

  if refreshElements == true and frame.__puiUF_oUFInitialized == true then
    frame:UpdateAllElements("GROUP_ROSTER_UPDATE")
  end

  return true
end

function PartyFrames:Construct_PartyFrames(frame)
  local db = PartyFrames.db.profile
  local cfg = BuildPartyFrameConfig(db)

  frame.__puiGroupKind = "party"
  frame.__puiPartyPlayer = frame.__unit == "player" or nil
  frame.__puiUseClassColor = db.useClassColor ~= false

  local useRoleIndicators = frame.isChild ~= true

  UF:ConstructUnitFrame(frame, "party", cfg, {
    db = db,
    groupKind = "party",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    roleConfigProvider = useRoleIndicators and GetPartyProfile or nil,
    roleDefaults = useRoleIndicators and UFDefaults.PartyRoleIcon or nil,
    auraDBBuilder = BuildPartyAuraDB,
  })

  UpdatePartyRosterIdentity(frame, false)
  RegisterPartyAuraAvailabilityEvents(frame)
end

function PartyFrames:Update_PartyFrames(frame)
  local db = PartyFrames.db.profile
  local unit = frame.__unit
  if not unit then
    return
  end

  local configUnit = frame.__puiPartyPlayer == true and "party" or unit
  local cfg = BuildPartyFrameConfig(db)

  UF:RefreshUnitFrame(frame, configUnit, cfg, {
    db = db,
    groupKind = "party",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    auraDBBuilder = BuildPartyAuraDB,
    rangeOwner = self,
  }, "all")
end

function PartyFrames:Construct_PartyPetFrames(frame)
  local db = PartyFrames.db.profile
  local petDB = db.partyPets or {}
  local unit = frame.__unit
  local cfg = BuildPartyPetFrameConfig(db, petDB)

  frame.isChild = true
  frame.childType = "pet"
  frame.__puiGroupKind = "party"
  frame.__puiUseClassColor = db.useClassColor ~= false
  frame.__puiForceNoPower = petDB.showPower ~= true

  UF:ConstructUnitFrame(frame, unit, cfg, {
    db = db,
    groupKind = "party",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = petDB.showPower ~= true,
    auraDBBuilder = BuildPartyAuraDB,
  })

  UpdatePartyRosterIdentity(frame, false)
  RegisterPartyAuraAvailabilityEvents(frame)
end

function PartyFrames:Update_PartyPetFrames(frame, index)
  local db = PartyFrames.db.profile
  local petDB = db.partyPets or {}
  local unit = "partypet" .. tostring(index)
  local cfg = BuildPartyPetFrameConfig(db, petDB)

  frame.__puiForceNoPower = petDB.showPower ~= true

  UF:RefreshUnitFrame(frame, unit, cfg, {
    db = db,
    groupKind = "party",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = petDB.showPower ~= true,
    auraDBBuilder = BuildPartyAuraDB,
    rangeOwner = self,
  }, "all")
end

function PartyFrames:RegisterStyle()
  if self.styleRegistered then
    return
  end

  self.styleRegistered = true

  oUF:RegisterStyle("PleebUI_PartyFrames", function(frame)
    frame.isChild = nil
    frame.childType = nil

    PartyFrames:Construct_PartyFrames(frame)
  end)

  oUF:RegisterStyle("PleebUI_PartyPetFrames", function(frame)
    frame.isChild = true
    frame.childType = "pet"
    frame.__puiForceNoPower = true

    PartyFrames:Construct_PartyPetFrames(frame)
  end)
end

function PartyFrames:EnsureAnchor()
  if self.anchor then
    return self.anchor
  end

  self.anchor = CreateFrame("Frame", "PleebUI_PartyFramesAnchor", UIParent)
  self.anchor:SetSize(Round(1), Round(1))
  return self.anchor
end

function PartyFrames:EnsurePartyFrames()
  if self.partyFrames then
    return self.partyFrames
  end

  self:RegisterStyle()
  self:EnsureAnchor()

  local db = PartyFrames.db.profile
  local previousStyle = oUF:GetActiveStyle()

  self.partyFrames = {}
  oUF:SetActiveStyle("PleebUI_PartyFrames")

  for index = 1, 4 do
    local frame = oUF:Spawn("party" .. index, "PleebUI_PartyFrame" .. index)
    frame.partyIndex = index + 1
    frame:SetParent(self.anchor)
    self.partyFrames[index] = frame
  end

  if db.showPlayer == true then
    self.partyPlayerFrame = oUF:Spawn("player", "PleebUI_PartyPlayer")
    self.partyPlayerFrame.partyIndex = 1
    self.partyPlayerFrame:SetParent(self.anchor)
  end

  oUF:SetActiveStyle(previousStyle)
  return self.partyFrames
end

function PartyFrames:LayoutPartyFrames()
  local db = PartyFrames.db.profile
  if not self.anchor or not self.partyFrames then
    return
  end

  local width, height = UFStyle.ResolveFrameSize(db)
  local spacing = Round(db.spacing or 8)
  local isHorizontal = db.orientation == "HORIZONTAL"
  local growsUp = not isHorizontal and (db.growthY or "DOWN") == "UP"
  local frames = {}

  for index = 1, 4 do
    local frame = self.partyFrames[index]
    if frame then
      frames[#frames + 1] = frame
    end
  end

  if self.partyPlayerFrame then
    frames[#frames + 1] = self.partyPlayerFrame
  end

  table_sort(frames, function(firstFrame, secondFrame)
    return ComparePartyFrames(db, firstFrame, secondFrame)
  end)

  for index = 1, #frames do
    local frame = frames[index]
    local offset = index - 1

    frame:ClearAllPoints()
    frame:SetSize(width, height)

    if isHorizontal then
      frame:SetPoint("LEFT", self.anchor, "LEFT", offset * (width + spacing), 0)
    elseif growsUp then
      frame:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, offset * (height + spacing))
    else
      frame:SetPoint("TOP", self.anchor, "TOP", 0, -offset * (height + spacing))
    end
  end
end

function PartyFrames:EnsurePetFrames()
  local db = PartyFrames.db.profile
  local petDB = db.partyPets

  self.petFrames = self.petFrames or {}

  self:RegisterStyle()
  self:EnsureAnchor()

  local previousStyle = oUF:GetActiveStyle()
  oUF:SetActiveStyle("PleebUI_PartyPetFrames")

  for index = 1, 4 do
    local unit = "partypet" .. index
    local frame = self.petFrames[index]

    if not frame then
      frame = oUF:Spawn(unit, "PleebUI_PartyPet" .. index)
      frame:SetParent(self.anchor)
      frame.__puiForceNoPower = true
      self.petFrames[index] = frame
    end

    if not petDB or petDB.enabled == false then
      if frame:IsEnabled() then
        frame:Disable()
      end
      UF:DisableFrameRuntime(frame)
    elseif not frame:IsEnabled() then
      frame:Enable()
    end
  end

  oUF:SetActiveStyle(previousStyle)
end

function PartyFrames:LayoutPetFrames()
  local petDB = PartyFrames.db.profile.partyPets
  if not petDB or petDB.enabled == false then
    return
  end

  for index = 1, 4 do
    local pet = self.petFrames and self.petFrames[index]
    local owner = self.partyFrames and self.partyFrames[index]

    if pet and owner then
      pet:ClearAllPoints()
      pet:SetPoint(petDB.anchorPoint or "TOP", owner, petDB.relativePoint or "BOTTOM", Round(petDB.x or 0), Round(petDB.y or -2))
    end
  end
end

function PartyFrames:ConfigureChildren()
  for index = 1, 4 do
    local frame = self.partyFrames and self.partyFrames[index]
    if frame then
      self:Update_PartyFrames(frame)
    end
  end

  if self.partyPlayerFrame then
    self:Update_PartyFrames(self.partyPlayerFrame)
  end

  self:EnsurePetFrames()
  self:LayoutPartyFrames()
  self:LayoutPetFrames()

  local petDB = PartyFrames.db.profile.partyPets
  if petDB and petDB.enabled ~= false then
    for index = 1, 4 do
      local pet = self.petFrames and self.petFrames[index]
      if pet then
        self:Update_PartyPetFrames(pet, index)
      end
    end
  end
end

local function RefreshPartyFrameConfiguration(owner, frame, mode)
  local db = PartyFrames.db.profile
  local unit = frame.__unit
  if not unit then
    return
  end

  local isPet = frame.childType == "pet" or unit:find("partypet", 1, true) == 1
  local configUnit = frame.__puiPartyPlayer == true and "party" or unit
  local petDB = db.partyPets or {}
  local cfg = isPet and BuildPartyPetFrameConfig(db, petDB) or BuildPartyFrameConfig(db)

  frame.__puiForceNoPower = isPet and petDB.showPower ~= true or nil

  UF:RefreshUnitFrame(frame, configUnit, cfg, {
    db = db,
    groupKind = "party",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = isPet and petDB.showPower ~= true,
    auraDBBuilder = BuildPartyAuraDB,
    rangeOwner = owner,
  }, mode)
end

function PartyFrames:RefreshGroupLayout()
  if not ShouldProcessPartyGroupEvents(PartyFrames.db.profile) then
    return
  end

  if InCombatLockdown() then
    self.pendingGroupUpdate = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  self:LayoutPartyFrames()
end

function PartyFrames:RefreshVisibility()
  local db = PartyFrames.db.profile

  if db.enabled == false then
    if self.anchor then
      if self._visibilityDriver then
        UnregisterStateDriver(self.anchor, "visibility")
        self._visibilityDriver = nil
      end
      self.anchor:Hide()
    end

    if self.partyFrames then
      for index = 1, 4 do
        UF:DisableFrameRuntime(self.partyFrames[index])
      end
    end

    UF:DisableFrameRuntime(self.partyPlayerFrame)

    if self.petFrames then
      for _, frame in pairs(self.petFrames) do
        UF:DisableFrameRuntime(frame)
      end
    end

    return false
  end

  self:EnsureAnchor()
  self:EnsurePartyFrames()

  ApplyAnchor(self)

  local visibilityDriver = GetPartyVisibilityDriver(db)
  if self._visibilityDriver ~= visibilityDriver then
    if self._visibilityDriver then
      UnregisterStateDriver(self.anchor, "visibility")
    end

    RegisterStateDriver(self.anchor, "visibility", visibilityDriver)
    self._visibilityDriver = visibilityDriver
  end

  self.anchor:Show()
  return true
end

local function IteratePartyMemberFrames(owner, callback)
  if owner.partyFrames then
    for index = 1, 4 do
      local frame = owner.partyFrames[index]
      if frame then
        callback(frame)
      end
    end
  end

  if owner.partyPlayerFrame then
    callback(owner.partyPlayerFrame)
  end
end

local function IteratePartyFrames(owner, callback)
  IteratePartyMemberFrames(owner, callback)

  if owner.petFrames then
    for _, frame in pairs(owner.petFrames) do
      callback(frame)
    end
  end
end

function PartyFrames:RefreshText()
  self._fontRev = (self._fontRev or 0) + 1

  IteratePartyFrames(self, function(frame)
    UFText.RefreshTextForFrame(frame, self._fontRev)
  end)
end

local function RefreshPartyAuraFrame(frame, request)
  local fullRefresh = request.display or request.filters or request.highlight
  local highlightCovered = false

  if fullRefresh then
    UFAuraContainers.RefreshFrame(frame)
  elseif request.displayRequests then
    for _, displayRequest in pairs(request.displayRequests) do
      UFAuraContainers.RefreshFrame(frame, displayRequest)

      if displayRequest.displayID == ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF then
        highlightCovered = true
      end
    end
  end

  if (request.highlightState or request.highlightPresentation)
    and not fullRefresh
    and not highlightCovered
  then
    UFAuraContainers.RefreshHighlight(frame)
  end
end

function PartyFrames:RefreshAuraDisplay(flags)
  if not flags
    or (
      flags.highlight ~= true
      and flags.highlightState ~= true
      and flags.highlightPresentation ~= true
    )
  then
    InvalidatePartyAuraDB()
  end

  local request = self._pendingAuraRefresh
  if not request then
    request = {}
    self._pendingAuraRefresh = request
  end

  if flags and flags.highlight then
    request.highlight = true
  end

  if flags and flags.highlightState then
    request.highlightState = true
  end

  if flags and flags.highlightPresentation then
    request.highlightPresentation = true
  end

  if flags and tonumber(flags.displayID) and flags.auraChange ~= "topology" then
    request.displayRequests = request.displayRequests or {}
    local displayID = tonumber(flags.displayID)
    local previousRequest = request.displayRequests[displayID]
    local auraChange = flags.auraChange or "display"

    if previousRequest
      and (previousRequest.auraChange == "sharedAppearance" or auraChange == "sharedAppearance")
    then
      auraChange = "sharedAppearance"
    elseif previousRequest and previousRequest.auraChange ~= auraChange then
      auraChange = "display"
    end

    request.displayRequests[displayID] = {
      displayID = displayID,
      auraChange = auraChange,
      auraType = flags.auraType or (previousRequest and previousRequest.auraType),
    }
  elseif flags and flags.rebuildDB then
    request.filters = true
  elseif not flags
    or (
      flags.highlight ~= true
      and flags.highlightState ~= true
      and flags.highlightPresentation ~= true
    )
  then
    request.display = true
  end

  if self._auraRefreshScheduled then
    return
  end

  self._auraRefreshScheduled = true
  C_Timer.After(0, function()
    self._auraRefreshScheduled = nil

    if not self:IsEnabled() then
      self._pendingAuraRefresh = nil
      return
    end

    local pending = self._pendingAuraRefresh
    self._pendingAuraRefresh = nil
    if not pending then
      return
    end

    IteratePartyFrames(self, function(frame)
      RefreshPartyAuraFrame(frame, pending)
    end)
  end)
end

function PartyFrames:RefreshTextures()
  UFStyle.ResolveMedia(UF)

  IteratePartyFrames(self, function(frame)
    UFStyle.UpdateFrameStyleElement(frame)
  end)
end

function PartyFrames:RefreshMouseoverSettings()
  UFMouseover.InvalidateRuntimeConfigCache()

  IteratePartyFrames(self, function(frame)
    UFMouseover.RefreshFrame(frame)
  end)
end

function PartyFrames:RefreshTargetHighlight()
  IteratePartyFrames(self, function(frame)
    UFFrameGlow.UpdateSharedTargetHighlight(frame)
  end)
end

function PartyFrames:RefreshRoleIcons(flags)
  IteratePartyFrames(self, function(frame)
    if frame.isChild ~= true then
      UFIndicators.RefreshSharedUnitIndicators(frame, flags)
    end
  end)
end

function PartyFrames:RefreshThreat()
  IteratePartyFrames(self, function(frame)
    UFThreat.Refresh(frame)
  end)
end

function PartyFrames:RefreshColors(flags)
  local db = PartyFrames.db.profile

  IteratePartyFrames(self, function(frame)
    frame.__puiUseClassColor = db.useClassColor ~= false
    UF:RefreshFrameColors(frame, flags)
  end)
end

function PartyFrames:RefreshPowerLayout()
  local db = PartyFrames.db.profile

  IteratePartyMemberFrames(self, function(frame)
    frame.__puiUseClassColor = db.useClassColor ~= false

    UF:RefreshFramePowerLayout(frame, BuildPartyFrameConfig(db), {
      db = db,
      groupKind = "party",
    })
  end)
end

function PartyFrames:RefreshLayout()
  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "layout")
    return
  end

  if PartyFrames.db.profile.enabled == false then
    return
  end

  self:EnsureAnchor()
  self:EnsurePartyFrames()
  self:EnsurePetFrames()
  ApplyAnchor(self)
  self:LayoutPartyFrames()
  self:LayoutPetFrames()
end

function PartyFrames:RefreshResizeGeometry()
  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "resize")
    return
  end

  if PartyFrames.db.profile.enabled == false or not self.partyFrames then
    return
  end

  ApplyAnchor(self)
  self:LayoutPartyFrames()
  self:LayoutPetFrames()
end

function PartyFrames:RefreshFrames(mode)
  mode = mode or "all"

  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, mode)
    return
  end

  if PartyFrames.db.profile.enabled == false or not self.partyFrames then
    self:Refresh()
    return
  end

  IteratePartyFrames(self, function(frame)
    RefreshPartyFrameConfiguration(self, frame, mode)
  end)

  if mode == "resize" then
    self:RefreshResizeGeometry()
  end
end

function PartyFrames:SafeRefresh(mode)
  if mode == "text" then
    self:RefreshText()
    return
  elseif mode == "range" then
    Range.RefreshRangeOwnerConfig(self, PartyFrames.db.profile.range)
    return
  elseif mode == "layout" then
    self:RefreshLayout()
    return
  elseif mode == "resize" or mode == "appearance" or mode == "data" then
    self:RefreshFrames(mode)
    return
  end

  self:Refresh()
end

function PartyFrames:Refresh()
  InvalidatePartyAuraDB()

  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "all")
    return
  end

  if self:RefreshVisibility() then
    self:ConfigureChildren()
  end

  self._initialRefreshComplete = true
end

function PartyFrames:RefreshAuraAvailability()
  if not ShouldProcessPartyGroupEvents(self.db.profile) then
    return
  end

  IteratePartyFrames(self, function(frame)
    UFAuraContainers.RefreshAvailability(frame)
  end)
end

local function RefreshPartyRosterFrames(owner)
  if not owner:IsEnabled() or not ShouldProcessPartyGroupEvents(owner.db.profile) then
    return
  end

  IteratePartyFrames(owner, function(frame)
    UpdatePartyRosterIdentity(frame, true)
  end)

  owner:RefreshAuraAvailability()
  owner:RefreshGroupLayout()
end

function PartyFrames:GROUP_ROSTER_UPDATE()
  if not ShouldProcessPartyGroupEvents(self.db.profile) then
    return
  end

  if InCombatLockdown() then
    self.pendingGroupUpdate = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  RefreshPartyRosterFrames(self)
end

function PartyFrames:PLAYER_ENTERING_WORLD()
  if self._initialRefreshComplete ~= true then
    self.__puiDeferredRefresh = nil
    self.pendingGroupUpdate = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:Refresh()
    return
  end

  self:RefreshAuraAvailability()
  self:RefreshGroupLayout()
end

function PartyFrames:PLAYER_REGEN_ENABLED()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  local flushed = UF.FlushDeferredRefreshes(self, function(mode)
    self:SafeRefresh(mode)
  end)

  if flushed and not self:IsEnabled() then
    return
  end

  if self.pendingGroupUpdate then
    self.pendingGroupUpdate = nil
    RefreshPartyRosterFrames(self)
  end
end

function PartyFrames:OnInitialize()
  self.db = Addon.db:RegisterNamespace("PartyFrames", UFDefaults.GetPartyDefaults())
end

function PartyFrames:OnEnable()
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "RefreshGroupLayout")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PARTY_MEMBER_ENABLE", "RefreshAuraAvailability")
  self:RegisterEvent("PARTY_MEMBER_DISABLE", "RefreshAuraAvailability")

  oUF:Factory(function()
    self:Refresh()
  end)
end

function PartyFrames:SetMoversVisible(show)
  if show and not ns.TestMode:IsActive() then
    self:Refresh()
  end

  if self.mover then
    FrameUtil.SetMoverFrameVisible(
      self.mover,
      show == true and self:IsEnabled() and self.db.profile.enabled ~= false
    )
  end
end

function PartyFrames:OnDisable()
  self:UnregisterAllEvents()
  self.__puiDeferredRefresh = nil
  self.pendingGroupUpdate = nil
  self._pendingAuraRefresh = nil
  self._auraRefreshScheduled = nil

  IteratePartyFrames(self, function(frame)
    UF:DisableFrameRuntime(frame)
  end)

  if self.anchor then
    if not InCombatLockdown() and self._visibilityDriver then
      UnregisterStateDriver(self.anchor, "visibility")
      self._visibilityDriver = nil
    end

    self.anchor:Hide()
  end
end



local P = select(1, ns.Pleebug:DropIn(PartyFrames, { name = "UnitFrames.Party" }))


  PartyFrames.Construct_PartyFrames = P:Def("PartyFrames.Construct_PartyFrames", PartyFrames.Construct_PartyFrames)
  PartyFrames.Update_PartyFrames = P:Def("PartyFrames.Update_PartyFrames", PartyFrames.Update_PartyFrames)
  PartyFrames.Construct_PartyPetFrames = P:Def("PartyFrames.Construct_PartyPetFrames", PartyFrames.Construct_PartyPetFrames)
  PartyFrames.Update_PartyPetFrames = P:Def("PartyFrames.Update_PartyPetFrames", PartyFrames.Update_PartyPetFrames)
  PartyFrames.RegisterStyle = P:Def("PartyFrames.RegisterStyle", PartyFrames.RegisterStyle)
  PartyFrames.EnsureAnchor = P:Def("PartyFrames.EnsureAnchor", PartyFrames.EnsureAnchor)
  PartyFrames.EnsurePartyFrames = P:Def("PartyFrames.EnsurePartyFrames", PartyFrames.EnsurePartyFrames)
  PartyFrames.LayoutPartyFrames = P:Def("PartyFrames.LayoutPartyFrames", PartyFrames.LayoutPartyFrames)
  PartyFrames.EnsurePetFrames = P:Def("PartyFrames.EnsurePetFrames", PartyFrames.EnsurePetFrames)
  PartyFrames.LayoutPetFrames = P:Def("PartyFrames.LayoutPetFrames", PartyFrames.LayoutPetFrames)
  PartyFrames.GetTestFrameConfig = P:Def("PartyFrames.GetTestFrameConfig", PartyFrames.GetTestFrameConfig)
  PartyFrames.LayoutTestFrames = P:Def("PartyFrames.LayoutTestFrames", PartyFrames.LayoutTestFrames)
  PartyFrames.ConfigureChildren = P:Def("PartyFrames.ConfigureChildren", PartyFrames.ConfigureChildren)
  PartyFrames.RefreshGroupLayout = P:Def("PartyFrames.RefreshGroupLayout", PartyFrames.RefreshGroupLayout)
  PartyFrames.RefreshVisibility = P:Def("PartyFrames.RefreshVisibility", PartyFrames.RefreshVisibility)
  PartyFrames.RefreshText = P:Def("PartyFrames.RefreshText", PartyFrames.RefreshText)
  PartyFrames.RefreshAuraDisplay = P:Def("PartyFrames.RefreshAuraDisplay", PartyFrames.RefreshAuraDisplay)
  PartyFrames.RefreshTextures = P:Def("PartyFrames.RefreshTextures", PartyFrames.RefreshTextures)
  PartyFrames.RefreshMouseoverSettings = P:Def("PartyFrames.RefreshMouseoverSettings", PartyFrames.RefreshMouseoverSettings)
  PartyFrames.RefreshTargetHighlight = P:Def("PartyFrames.RefreshTargetHighlight", PartyFrames.RefreshTargetHighlight)
  PartyFrames.RefreshRoleIcons = P:Def("PartyFrames.RefreshRoleIcons", PartyFrames.RefreshRoleIcons)
  PartyFrames.RefreshThreat = P:Def("PartyFrames.RefreshThreat", PartyFrames.RefreshThreat)
  PartyFrames.RefreshColors = P:Def("PartyFrames.RefreshColors", PartyFrames.RefreshColors)
  PartyFrames.RefreshPowerLayout = P:Def("PartyFrames.RefreshPowerLayout", PartyFrames.RefreshPowerLayout)
  PartyFrames.RefreshLayout = P:Def("PartyFrames.RefreshLayout", PartyFrames.RefreshLayout)
  PartyFrames.RefreshResizeGeometry = P:Def("PartyFrames.RefreshResizeGeometry", PartyFrames.RefreshResizeGeometry)
  PartyFrames.RefreshFrames = P:Def("PartyFrames.RefreshFrames", PartyFrames.RefreshFrames)
  PartyFrames.SafeRefresh = P:Def("PartyFrames.SafeRefresh", PartyFrames.SafeRefresh)
  PartyFrames.Refresh = P:Def("PartyFrames.Refresh", PartyFrames.Refresh)
  PartyFrames.RefreshAuraAvailability = P:Def("PartyFrames.RefreshAuraAvailability", PartyFrames.RefreshAuraAvailability)
  RefreshPartyRosterFrames = P:Def("RefreshPartyRosterFrames", RefreshPartyRosterFrames)
  PartyFrames.GROUP_ROSTER_UPDATE = P:Def("PartyFrames.GROUP_ROSTER_UPDATE", PartyFrames.GROUP_ROSTER_UPDATE)
  PartyFrames.PLAYER_ENTERING_WORLD = P:Def("PartyFrames.PLAYER_ENTERING_WORLD", PartyFrames.PLAYER_ENTERING_WORLD)
  PartyFrames.PLAYER_REGEN_ENABLED = P:Def("PartyFrames.PLAYER_REGEN_ENABLED", PartyFrames.PLAYER_REGEN_ENABLED)
  PartyFrames.OnInitialize = P:Def("PartyFrames.OnInitialize", PartyFrames.OnInitialize)
  PartyFrames.OnEnable = P:Def("PartyFrames.OnEnable", PartyFrames.OnEnable)
  PartyFrames.SetMoversVisible = P:Def("PartyFrames.SetMoversVisible", PartyFrames.SetMoversVisible)
  PartyFrames.OnDisable = P:Def("PartyFrames.OnDisable", PartyFrames.OnDisable)
  ReadPartyProfile = P:Def("ReadPartyProfile", ReadPartyProfile)
  ReadPartyPetProfile = P:Def("ReadPartyPetProfile", ReadPartyPetProfile)
  GetPartyGroupBy = P:Def("GetPartyGroupBy", GetPartyGroupBy)
  GetPartySortOrder = P:Def("GetPartySortOrder", GetPartySortOrder)
  GetPartySortDirection = P:Def("GetPartySortDirection", GetPartySortDirection)
  GetPartyRoleRank = P:Def("GetPartyRoleRank", GetPartyRoleRank)
  ComparePartyIndex = P:Def("ComparePartyIndex", ComparePartyIndex)
  ComparePartyNames = P:Def("ComparePartyNames", ComparePartyNames)
  ComparePartyFrames = P:Def("ComparePartyFrames", ComparePartyFrames)
  GetPartyVisibilityDriver = P:Def("GetPartyVisibilityDriver", GetPartyVisibilityDriver)
  ShouldProcessPartyGroupEvents = P:Def("ShouldProcessPartyGroupEvents", ShouldProcessPartyGroupEvents)
  ApplyAnchor = P:Def("ApplyAnchor", ApplyAnchor)
  BuildPartyFrameConfig = P:Def("BuildPartyFrameConfig", BuildPartyFrameConfig)
  BuildPartyPetFrameConfig = P:Def("BuildPartyPetFrameConfig", BuildPartyPetFrameConfig)
  GetPartyProfile = P:Def("GetPartyProfile", GetPartyProfile)
  InvalidatePartyAuraDB = P:Def("InvalidatePartyAuraDB", InvalidatePartyAuraDB)
  BuildPartyAuraDB = P:Def("BuildPartyAuraDB", BuildPartyAuraDB)
  RegisterPartyAuraAvailabilityEvents = P:Def("RegisterPartyAuraAvailabilityEvents", RegisterPartyAuraAvailabilityEvents)
  UpdatePartyRosterIdentity = P:Def("UpdatePartyRosterIdentity", UpdatePartyRosterIdentity)
  RefreshPartyFrameConfiguration = P:Def("RefreshPartyFrameConfiguration", RefreshPartyFrameConfiguration)
  IteratePartyMemberFrames = P:Def("IteratePartyMemberFrames", IteratePartyMemberFrames)
  IteratePartyFrames = P:Def("IteratePartyFrames", IteratePartyFrames)
  RefreshPartyAuraFrame = P:Def("RefreshPartyAuraFrame", RefreshPartyAuraFrame)

_G.PleebUIAPI:RegisterPlugin("PleebUI_UnitFrames", {
  name = "Unit Frames",
}):RegisterEditModeParticipant("party", {
  order = 110,
  onChanged = function(enable)
    PartyFrames:SetMoversVisible(enable)
  end,
})
