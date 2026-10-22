-- File: PUI_Quality.lua

local ADDON_NAME, ns = ...


local Addon = ns.Addon
local AceGUI = LibStub("AceGUI-3.0")
local Round = ns.Pixel.Round

local Quality = {}
ns.Modules.Quality = Quality

local function GetProfile()
  return Addon.db.profile
end

local function Clamp(v, lo, hi)
  v = tonumber(v)
  if not v then
    error("Clamp(): expected number", 2)
  end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function NormalizeBool(value, default)
  if value == nil then
    return default
  end

  if type(value) == "boolean" then
    return value
  end

  if type(value) == "number" then
    return value ~= 0
  end

  if type(value) == "string" then
    local lowered = string.lower(value)
    if lowered == "1" or lowered == "true" or lowered == "on" or lowered == "yes" then
      return true
    end
    if lowered == "0" or lowered == "false" or lowered == "off" or lowered == "no" then
      return false
    end
  end

  return not not value
end

local function FormatThousands(value)
  value = math.floor(tonumber(value) or 0)

  local sign = ""
  if value < 0 then
    sign = "-"
    value = -value
  end

  local text = tostring(value)
  local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

  return sign .. formatted
end

local function FormatCoinText(amount)
  amount = math.floor(tonumber(amount) or 0)
  if amount < 0 then
    amount = 0
  end

  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  local copper = amount % 100

  local parts = {}

  if gold > 0 then
    parts[#parts + 1] = FormatThousands(gold) .. " Gold"
  end

  if silver > 0 or gold > 0 then
    parts[#parts + 1] = tostring(silver) .. " Silver"
  end

  parts[#parts + 1] = tostring(copper) .. " Copper"

  return table.concat(parts, ", ")
end

local function TrustedUnits_NormalizeName(name)
  if not canaccessvalue(name) or name == nil then
    return nil
  end

  name = tostring(name or "")
  if name == "" then
    return nil
  end

  name = strsplit("-", name, 2)
  if not name or name == "" then
    return nil
  end

  return name
end

local function TrustedUnits_IsFriend(name, guid)
  if canaccessvalue(guid) and guid and guid ~= "" and C_FriendList.IsFriend(guid) then
    return true
  end

  name = TrustedUnits_NormalizeName(name)
  if not name then
    return false
  end

  C_FriendList.ShowFriends()

  for i = 1, C_FriendList.GetNumFriends() do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    local friendName = info and TrustedUnits_NormalizeName(info.name) or nil
    local friendGUID = info and info.guid or nil

    if friendName == name then
      if canaccessvalue(guid) and guid and guid ~= "" and canaccessvalue(friendGUID) and friendGUID and friendGUID ~= "" then
        if guid == friendGUID then
          return true
        end
      else
        return true
      end
    end
  end

  return C_FriendList.IsFriend(name) or false
end

local function TrustedUnits_IsBattleNetFriend(name, guid)
  if canaccessvalue(guid) and guid and guid ~= "" and C_BattleNet.GetGameAccountInfoByGUID(guid) then
    return true
  end

  name = TrustedUnits_NormalizeName(name)
  if not name then
    return false
  end

  for i = 1, BNGetNumFriends() do
    local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i) or 0
    for j = 1, numGameAccounts do
      local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
      local characterName = gameAccountInfo and TrustedUnits_NormalizeName(gameAccountInfo.characterName) or nil
      local clientProgram = gameAccountInfo and gameAccountInfo.clientProgram or nil

      if clientProgram == "WoW" and characterName == name then
        return true
      end
    end
  end

  return false
end

local function TrustedUnits_IsGuildMember(name, guid)
  if canaccessvalue(guid) and guid and guid ~= "" and IsGuildMember(guid) then
    return true
  end

  name = TrustedUnits_NormalizeName(name)
  if not name or not IsInGuild() then
    return false
  end

  local n = GetNumGuildMembers()
  for i = 1, n do
    local memberName, _, _, _, _, _, _, _, memberOnline, _, _, _, _, memberMobile, _, _, memberGUID = GetGuildRosterInfo(i)
    memberName = TrustedUnits_NormalizeName(memberName)

    if memberOnline and not memberMobile and memberName == name then
      if canaccessvalue(guid) and guid and guid ~= "" and canaccessvalue(memberGUID) and memberGUID and memberGUID ~= "" then
        if guid == memberGUID then
          return true
        end
      else
        return true
      end
    end
  end

  return false
end

local function TrustedUnits_IsCommunityMember(name, guid)
  name = TrustedUnits_NormalizeName(name)
  if not name and not (canaccessvalue(guid) and guid and guid ~= "") then
    return false
  end

  if not CommunitiesUtil or not CommunitiesUtil.GetMemberIdsSortedByName or not CommunitiesUtil.GetMemberInfo then
    return false
  end

  local characterClubType = Enum and Enum.ClubType and Enum.ClubType.Character or nil
  local offlinePresence = Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline or nil
  local mobilePresence = Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.OnlineMobile or nil

  for _, community in pairs(C_Club.GetSubscribedClubs() or {}) do
    if community and community.clubId and community.clubType == characterClubType then
      local memberIDs = CommunitiesUtil.GetMemberIdsSortedByName(community.clubId)
      local members = CommunitiesUtil.GetMemberInfo(community.clubId, memberIDs)

      for _, member in pairs(members or {}) do
        local memberName = member and TrustedUnits_NormalizeName(member.name) or nil
        local memberGUID = member and member.guid or nil
        local presence = member and member.presence or nil

        if memberName == name and presence and presence ~= offlinePresence and presence ~= mobilePresence then
          if canaccessvalue(guid) and guid and guid ~= "" and canaccessvalue(memberGUID) and memberGUID and memberGUID ~= "" then
            if guid == memberGUID then
              return true
            end
          else
            return true
          end
        end
      end
    end
  end

  return false
end

local function TrustedUnits_IsTrusted(name, guid, allowFriends, allowBattleNetFriends, allowGuildMembers, allowCommunityMembers)
  if allowFriends and TrustedUnits_IsFriend(name, guid) then
    return true
  end

  if allowBattleNetFriends and TrustedUnits_IsBattleNetFriend(name, guid) then
    return true
  end

  if allowGuildMembers and TrustedUnits_IsGuildMember(name, guid) then
    return true
  end

  if allowCommunityMembers and TrustedUnits_IsCommunityMember(name, guid) then
    return true
  end

  return false
end

local function TrustedUnits_GetPartyLeader()
  local numMembers = tonumber(GetNumSubgroupMembers()) or 0

  for i = 1, numMembers do
    local unit = "party" .. i
    if UnitExists(unit) and UnitIsGroupLeader(unit) then
      local leaderName = UnitName(unit)
      if not canaccessvalue(leaderName) then
        return nil, nil
      end

      local leaderGUID = UnitGUID(unit)
      if not canaccessvalue(leaderGUID) then
        return nil, nil
      end

      return leaderName, leaderGUID
    end
  end

  return nil, nil
end

local function IsQueueStatusActive()
  local queueButton = _G.QueueStatusButton
  if not queueButton then
    return false
  end

  return queueButton:IsShown()
end



local QUALITY_POSITION_DEFAULTS = {
  combatMessage = { x = 0, y = 300 },
  combatTimer = { x = -440, y = -350 },
  combatWarning = { x = 0, y = 120 },
  petWarning = { x = 0, y = 180 },
}

local function SeedAnchorDefaults(anchor, defaults)
  anchor = anchor or {}
  if anchor.x == nil then anchor.x = defaults.x end
  if anchor.y == nil then anchor.y = defaults.y end
  return anchor
end

local POSITION_DEFAULTS = {
  bresLustWidget = {
    x = -300,
    y = -300,
  },
  raidUtilityButtons = {
    enabled = false,
    x = 300,
    y = -244,
  },
  raidUtilityRaidMarkers = {
    enabled = false,
    x = 300,
    y = -300,
  },
  raidUtilityWorldMarkers = {
    enabled = false,
    x = 300,
    y = -356,
  },
}

local function NormalizeRaidUtilityDB(q)
  if q.bresWidgetEnable == nil then q.bresWidgetEnable = true end
  if q.lustWidgetEnable == nil then q.lustWidgetEnable = false end
  if q.bresLustWidgetShowOnlyInGroup == nil then q.bresLustWidgetShowOnlyInGroup = true end
  q.bresLustWidgetIconSize = Clamp(q.bresLustWidgetIconSize or 32, 16, 64)
  q.bresLustWidgetAnchor = SeedAnchorDefaults(q.bresLustWidgetAnchor, POSITION_DEFAULTS.bresLustWidget)

  if q.raidUtilityButtonsEnable == nil then
    q.raidUtilityButtonsEnable = POSITION_DEFAULTS.raidUtilityButtons.enabled
  end
  if q.raidUtilityRaidMarkersEnable == nil then
    q.raidUtilityRaidMarkersEnable = POSITION_DEFAULTS.raidUtilityRaidMarkers.enabled
  end
  if q.raidUtilityWorldMarkersEnable == nil then
    q.raidUtilityWorldMarkersEnable = POSITION_DEFAULTS.raidUtilityWorldMarkers.enabled
  end

  if q.raidUtilityShowOnlyInGroup == nil then q.raidUtilityShowOnlyInGroup = true end
  q.raidUtilityPullTimerSeconds = Clamp(q.raidUtilityPullTimerSeconds or 10, 1, 60)
  q.raidUtilityExtraPullTimers = q.raidUtilityExtraPullTimers or {}
  if type(q.raidUtilityExtraPullTimers) ~= "table" then
    q.raidUtilityExtraPullTimers = {}
  end

  do
    local cleaned = {}
    for i, v in ipairs(q.raidUtilityExtraPullTimers) do
      local n = tonumber(v)
      if n then
        cleaned[#cleaned + 1] = Clamp(n, 1, 60)
      end
    end
    q.raidUtilityExtraPullTimers = cleaned
  end

  if q.raidUtilityButtonsHideInCombat == nil then q.raidUtilityButtonsHideInCombat = true end
  if q.raidUtilityButtonsMouseover == nil then q.raidUtilityButtonsMouseover = false end
  if q.raidUtilityButtonsFreeMove == nil then q.raidUtilityButtonsFreeMove = false end
  q.raidUtilityButtonsAlpha = Clamp(q.raidUtilityButtonsAlpha or 1, 0, 1)
  q.raidUtilityButtonsFadeOutAlpha = Clamp(q.raidUtilityButtonsFadeOutAlpha or 0, 0, 1)
  q.raidUtilityButtonsFadeOutDuration = Clamp(q.raidUtilityButtonsFadeOutDuration or 0, 0, 10)

  if q.raidUtilityRaidMarkersHideInCombat == nil then q.raidUtilityRaidMarkersHideInCombat = false end
  if q.raidUtilityRaidMarkersMouseover == nil then q.raidUtilityRaidMarkersMouseover = false end
  if q.raidUtilityRaidMarkersFreeMove == nil then q.raidUtilityRaidMarkersFreeMove = false end
  q.raidUtilityRaidMarkersAlpha = Clamp(q.raidUtilityRaidMarkersAlpha or 1, 0, 1)
  q.raidUtilityRaidMarkersFadeOutAlpha = Clamp(q.raidUtilityRaidMarkersFadeOutAlpha or 0, 0, 1)
  q.raidUtilityRaidMarkersFadeOutDuration = Clamp(q.raidUtilityRaidMarkersFadeOutDuration or 0, 0, 10)
  q.raidUtilityRaidMarkerButtonSize = Clamp(q.raidUtilityRaidMarkerButtonSize or 22, 18, 40)

  if q.raidUtilityWorldMarkersHideInCombat == nil then q.raidUtilityWorldMarkersHideInCombat = false end
  if q.raidUtilityWorldMarkersMouseover == nil then q.raidUtilityWorldMarkersMouseover = false end
  if q.raidUtilityWorldMarkersFreeMove == nil then q.raidUtilityWorldMarkersFreeMove = false end
  q.raidUtilityWorldMarkersAlpha = Clamp(q.raidUtilityWorldMarkersAlpha or 1, 0, 1)
  q.raidUtilityWorldMarkersFadeOutAlpha = Clamp(q.raidUtilityWorldMarkersFadeOutAlpha or 0, 0, 1)
  q.raidUtilityWorldMarkersFadeOutDuration = Clamp(q.raidUtilityWorldMarkersFadeOutDuration or 0, 0, 10)
  q.raidUtilityWorldMarkerButtonSize = Clamp(q.raidUtilityWorldMarkerButtonSize or 22, 18, 40)

  q.raidUtilityButtonsAnchor = SeedAnchorDefaults(q.raidUtilityButtonsAnchor, POSITION_DEFAULTS.raidUtilityButtons)
  q.raidUtilityRaidMarkersAnchor = SeedAnchorDefaults(q.raidUtilityRaidMarkersAnchor, POSITION_DEFAULTS.raidUtilityRaidMarkers)
  q.raidUtilityWorldMarkersAnchor = SeedAnchorDefaults(q.raidUtilityWorldMarkersAnchor, POSITION_DEFAULTS.raidUtilityWorldMarkers)
end

local function NormalizeDB()
  local db = GetProfile()

  db.quality = db.quality or {}
  local q = db.quality

  if q.combatMessage == nil then q.combatMessage = true end
  if q.combatTimer == nil then q.combatTimer = true end
  q.noTargetWarning = NormalizeBool(q.noTargetWarning, true)
  q.notAttackingWarning = NormalizeBool(q.notAttackingWarning, false)

  if q.autoLoot == nil then q.autoLoot = true end
  if q.fasterLooting == nil then q.fasterLooting = true end

  q.autoRepair = NormalizeBool(q.autoRepair, true)
  q.guildRepairFirst = NormalizeBool(q.guildRepairFirst, true)
  q.autoRepairShowSummary = NormalizeBool(q.autoRepairShowSummary, true)

  q.autoSellJunk = NormalizeBool(q.autoSellJunk, true)
  if q.autoKeystone == nil then q.autoKeystone = true end

  if q.autoAcceptInvites == nil then q.autoAcceptInvites = true end
  q.autoAcceptInvites = NormalizeBool(q.autoAcceptInvites, true)
  q.acceptInviteEveryone = NormalizeBool(q.acceptInviteEveryone, false)

  if q.acceptInviteFriends == nil then
    if q.acceptFriendsInvites ~= nil then
      q.acceptInviteFriends = NormalizeBool(q.acceptFriendsInvites, true)
    else
      q.acceptInviteFriends = true
    end
  end
  q.acceptInviteFriends = NormalizeBool(q.acceptInviteFriends, true)

  if q.acceptInviteBattleNetFriends == nil then
    if q.acceptBNInvites ~= nil then
      q.acceptInviteBattleNetFriends = NormalizeBool(q.acceptBNInvites, true)
    else
      q.acceptInviteBattleNetFriends = true
    end
  end
  q.acceptInviteBattleNetFriends = NormalizeBool(q.acceptInviteBattleNetFriends, true)

  if q.acceptInviteGuildMembers == nil then
    if q.acceptGuildInvites ~= nil then
      q.acceptInviteGuildMembers = NormalizeBool(q.acceptGuildInvites, true)
    else
      q.acceptInviteGuildMembers = true
    end
  end
  q.acceptInviteGuildMembers = NormalizeBool(q.acceptInviteGuildMembers, true)

  if q.acceptInviteCommunityMembers == nil then q.acceptInviteCommunityMembers = false end
  q.acceptInviteCommunityMembers = NormalizeBool(q.acceptInviteCommunityMembers, false)

  q.autoAcceptRoleCheck = NormalizeBool(q.autoAcceptRoleCheck, false)
  if q.acceptRoleCheckFriends == nil then q.acceptRoleCheckFriends = true end
  if q.acceptRoleCheckBattleNetFriends == nil then q.acceptRoleCheckBattleNetFriends = true end
  if q.acceptRoleCheckGuildMembers == nil then q.acceptRoleCheckGuildMembers = true end
  if q.acceptRoleCheckCommunityMembers == nil then q.acceptRoleCheckCommunityMembers = false end
  q.acceptRoleCheckFriends = NormalizeBool(q.acceptRoleCheckFriends, true)
  q.acceptRoleCheckBattleNetFriends = NormalizeBool(q.acceptRoleCheckBattleNetFriends, true)
  q.acceptRoleCheckGuildMembers = NormalizeBool(q.acceptRoleCheckGuildMembers, true)
  q.acceptRoleCheckCommunityMembers = NormalizeBool(q.acceptRoleCheckCommunityMembers, false)

  q.entryCountdown = NormalizeBool(q.entryCountdown, false)
  q.disableScreenGlow = NormalizeBool(q.disableScreenGlow, false)
  q.disableScreenEffects = NormalizeBool(q.disableScreenEffects, false)
  q.customWeatherDensity = NormalizeBool(q.customWeatherDensity, false)
  q.weatherDensity = Clamp(q.weatherDensity or 0, 0, 3)
  q.accessibilityOriginalCVars = q.accessibilityOriginalCVars or {}
  q.autoAcceptSummons = NormalizeBool(q.autoAcceptSummons, false)
  q.autoAcceptResurrection = NormalizeBool(q.autoAcceptResurrection, false)
  q.whisperInvites = NormalizeBool(q.whisperInvites, false)
  q.whisperInviteKeyword = strtrim(tostring(q.whisperInviteKeyword or "invite"))
  q.whisperInviteFriends = NormalizeBool(q.whisperInviteFriends, true)
  q.whisperInviteBattleNetFriends = NormalizeBool(q.whisperInviteBattleNetFriends, true)
  q.whisperInviteGuildMembers = NormalizeBool(q.whisperInviteGuildMembers, true)

  if q.easyItemDestroy == nil then q.easyItemDestroy = false end
  if q.fasterMovieSkip == nil then q.fasterMovieSkip = false end

  if q.hideTalkingHead == nil then q.hideTalkingHead = false end
  if q.hideRestedZzz == nil then q.hideRestedZzz = true end

  if q.maxCameraZoom == nil then q.maxCameraZoom = true end
  if q.suppressGuildAchievementToasts == nil then q.suppressGuildAchievementToasts = false end
  if q.showAuraSpellIDs == nil then q.showAuraSpellIDs = false end

  if q.petWarningsEnabled == nil then q.petWarningsEnabled = true end
  if q.missingPetWarning == nil then q.missingPetWarning = true end
  if q.idlePetWarning == nil then q.idlePetWarning = q.missingPetWarning end
  if q.lowHealthPetWarning == nil then q.lowHealthPetWarning = true end
  if q.hidePetWarningWhileDragonriding == nil then q.hidePetWarningWhileDragonriding = true end

  q.petIdleWarningFontSize = Clamp(q.petIdleWarningFontSize or 20, 5, 100)
  q.petIdleWarningColor = q.petIdleWarningColor or { r = 1, g = 1, b = 1, a = 1 }
  q.petHealWarningThreshold = Clamp(q.petHealWarningThreshold or 50, 10, 50)
  if q.petHealWarningText == nil then q.petHealWarningText = "Heal Pet" end
  if q.petHealWarningShowIcon == nil then q.petHealWarningShowIcon = true end
  q.petHealWarningFontSize = Clamp(q.petHealWarningFontSize or 20, 5, 100)
  if q.petHealWarningIconOnly == nil then q.petHealWarningIconOnly = false end
  q.petLowHealthWarningColor = q.petLowHealthWarningColor or { r = 1, g = 0.55, b = 0, a = 1 }
  q.petMissingWarningFontSize = Clamp(q.petMissingWarningFontSize or 34, 10, 100)
  q.petMissingWarningColor = q.petMissingWarningColor or { r = 1, g = 0.82, b = 0, a = 1 }
  q.petDeadWarningFontSize = Clamp(q.petDeadWarningFontSize or 52, 10, 100)
  q.petDeadWarningColor = q.petDeadWarningColor or { r = 1, g = 0.10, b = 0.10, a = 1 }
  if q.auctionHouseCurrentExpansionOnly == nil then q.auctionHouseCurrentExpansionOnly = false end
  if q.crosshair == nil then q.crosshair = true end

  NormalizeRaidUtilityDB(q)

  -- Move Core hide toggles here (same keys)
  q.hideElements = q.hideElements or {}
  local h = q.hideElements
  if h.objectiveTracker == nil then h.objectiveTracker = false end
  if h.zoneAbility == nil then h.zoneAbility = false end
  if h.minimapBorderTop == nil then h.minimapBorderTop = false end
  if h.minimapClock == nil then h.minimapClock = false end
  if h.minimapCalendar == nil then h.minimapCalendar = false end
  if h.minimapDifficulty == nil then h.minimapDifficulty = false end
  if h.minimapTracking == nil then h.minimapTracking = false end
  if h.minimapZoneText == nil then h.minimapZoneText = false end

  q.combatMessageAnchor = SeedAnchorDefaults(q.combatMessageAnchor, QUALITY_POSITION_DEFAULTS.combatMessage)
  q.combatTimerAnchor = SeedAnchorDefaults(q.combatTimerAnchor, QUALITY_POSITION_DEFAULTS.combatTimer)
  q.combatWarningAnchor = SeedAnchorDefaults(q.combatWarningAnchor, QUALITY_POSITION_DEFAULTS.combatWarning)
  q.petWarningAnchor = SeedAnchorDefaults(q.petWarningAnchor, QUALITY_POSITION_DEFAULTS.petWarning)

  q.combatTimerFontSize = Clamp(q.combatTimerFontSize or 14, 10, 72)
  if q.combatTimerBackground == nil then q.combatTimerBackground = true end
  q.combatTimerWidth = Clamp(q.combatTimerWidth or math.max(120, q.combatTimerFontSize * 4 + 16), 20, 600)
  q.combatTimerHeight = Clamp(q.combatTimerHeight or math.max(22, q.combatTimerFontSize + 8), 10, 200)
  if q.combatTimerBorder == nil then q.combatTimerBorder = true end
  q.combatTimerBorderSize = Clamp(q.combatTimerBorderSize or ns.Theme.GetEdgeSize(), 1, 8)
  if not q.combatTimerBackgroundColor or not q.combatTimerBorderColor then
    local colors = ns.Theme.GetColors()
    q.combatTimerBackgroundColor = q.combatTimerBackgroundColor
      or { r = colors.background[1], g = colors.background[2], b = colors.background[3], a = colors.background[4] }
    q.combatTimerBorderColor = q.combatTimerBorderColor
      or { r = colors.border[1], g = colors.border[2], b = colors.border[3], a = colors.border[4] }
  end
  q.combatMessageFontSize = Clamp(q.combatMessageFontSize or 18, 10, 40)
  q.combatWarningFontSize = Clamp(q.combatWarningFontSize or 32, 16, 60)

  return q
end

ns.QualityAPI = ns.QualityAPI or {}
ns.QualityAPI.NormalizeDB = NormalizeDB
ns.QualityAPI.Clamp = Clamp
ns.QualityAPI.SeedAnchorDefaults = SeedAnchorDefaults
ns.QualityAPI.PositionDefaults = QUALITY_POSITION_DEFAULTS
ns.QualityAPI.RaidPositionDefaults = POSITION_DEFAULTS

local QualityQ

local function RefreshQ()
  QualityQ = NormalizeDB()
  return QualityQ
end

local function GetQ()
  if not QualityQ then
    QualityQ = NormalizeDB()
  end

  return QualityQ
end

local LootFrame
local LastLootT = 0

local function EnsureLootFrame()
  if LootFrame then return LootFrame end
  local f = CreateFrame("Frame", "PleebUI_QualityLoot")
  LootFrame = f
  f:SetScript("OnEvent", function(_, event, lootSlot)
    local q = GetQ()
    if not q.fasterLooting then
      return
    end

    if event == "LOOT_BIND_CONFIRM" then
      ConfirmLootSlot(lootSlot)
      StaticPopup_Hide("LOOT_BIND")
      return
    end

    local now = GetTime()
    if (now - (LastLootT or 0)) < 0.30 then
      return
    end

    local n = GetNumLootItems()
    if n <= 0 then
      return
    end

    LastLootT = now
    for i = n, 1, -1 do
      LootSlot(i)
    end
  end)

  function f:RefreshState()
    local q = GetQ()
    self:UnregisterAllEvents()

    if q.fasterLooting then
      self:RegisterEvent("LOOT_READY")
      self:RegisterEvent("LOOT_BIND_CONFIRM")
    else
      LastLootT = 0
    end
  end

  return f
end

local MerchantFrameDriver

local function Merchant_ProcessAutoRepair(q)
  if not CanMerchantRepair() then
    return
  end

  local repairCost, canRepair = GetRepairAllCost()
  repairCost = tonumber(repairCost) or 0

  if not canRepair or repairCost <= 0 then
    return
  end

  local guildRepairAllowed = q.guildRepairFirst == true and IsInGuild() and CanGuildBankRepair()

  if guildRepairAllowed then
    RepairAllItems(true)
  end
  RepairAllItems()
  PlaySound(SOUNDKIT.ITEM_REPAIR, "Master")

  if q.autoRepairShowSummary == true then
    Addon:Print("Repaired for " .. FormatCoinText(repairCost) .. ".")
  end
end

local function EnsureMerchantDriver()
  if MerchantFrameDriver then return MerchantFrameDriver end

  local f = CreateFrame("Frame", "PleebUI_QualityMerchant")
  MerchantFrameDriver = f
  f:SetScript("OnEvent", function()
    if IsShiftKeyDown() then
      return
    end

    local q = GetQ()

    if q.autoRepair then
      Merchant_ProcessAutoRepair(q)
    end
    if q.autoSellJunk then
      C_MerchantFrame.SellAllJunkItems()
    end
  end)

  function f:RefreshState()
    local q = GetQ()

    self:UnregisterAllEvents()

    if q.autoRepair or q.autoSellJunk then
      self:RegisterEvent("MERCHANT_SHOW")
    end
  end

  return f
end

local KeystoneFrame

local function EnsureKeystoneDriver()
  if KeystoneFrame then return KeystoneFrame end
  local f = CreateFrame("Frame", "PleebUI_QualityKeystone")
  KeystoneFrame = f
  f:SetScript("OnEvent", function()
    local q = GetQ()
    if not q.autoKeystone then return end
    if C_ChallengeMode.HasSlottedKeystone() then return end

    for bag = 0, 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local id = C_Container.GetContainerItemID(bag, slot)
        if id and C_Item.IsItemKeystoneByID(id) then
          C_Container.PickupContainerItem(bag, slot)
          if CursorHasItem() then
            C_ChallengeMode.SlotKeystone()
          end
          return
        end
      end
    end
  end)

  function f:RefreshState()
    local q = GetQ()
    self:UnregisterAllEvents()

    if q.autoKeystone then
      self:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    end
  end

  return f
end

local InviteFrame
local InviteHideStatic = false

local function EnsureInviteDriver()
  if InviteFrame then return InviteFrame end
  local f = CreateFrame("Frame", "PleebUI_QualityInvites")
  InviteFrame = f
  f:SetScript("OnEvent", function(_, event, inviter, _, _, _, _, _, inviterGUID)
    if event == "GROUP_ROSTER_UPDATE" then
      if InviteHideStatic then
        if _G.LFGInvitePopup then
          StaticPopupSpecial_Hide(_G.LFGInvitePopup)
        end
        StaticPopup_Hide("PARTY_INVITE")
        InviteHideStatic = false
      end
      return
    end

    local q = GetQ()
    if not q.autoAcceptInvites then return end
    if IsInGroup() then return end
    if IsPartyLFG() then return end
    if IsQueueStatusActive() then return end

    if not q.acceptInviteEveryone and not TrustedUnits_IsTrusted(
      inviter,
      inviterGUID,
      q.acceptInviteFriends,
      q.acceptInviteBattleNetFriends,
      q.acceptInviteGuildMembers,
      q.acceptInviteCommunityMembers
    ) then
      return
    end

    InviteHideStatic = true
    AcceptGroup()
  end)

  function f:RefreshState()
    local q = GetQ()
    self:UnregisterAllEvents()

    if q.autoAcceptInvites then
      self:RegisterEvent("PARTY_INVITE_REQUEST")
      self:RegisterEvent("GROUP_ROSTER_UPDATE")
    else
      if InviteHideStatic then
        if _G.LFGInvitePopup then
          StaticPopupSpecial_Hide(_G.LFGInvitePopup)
        end
        StaticPopup_Hide("PARTY_INVITE")
        InviteHideStatic = false
      end
    end
  end

  return f
end

local WhisperInviteFrame

local function EnsureWhisperInviteDriver()
  if WhisperInviteFrame then return WhisperInviteFrame end
  local f = CreateFrame("Frame", "PleebUI_QualityWhisperInvites")
  WhisperInviteFrame = f
  f:SetScript("OnEvent", function(self, event, message, sender, ...)
    if C_ChatInfo.InChatMessagingLockdown() or InCombatLockdown() then return end
    if not canaccessvalue(message) or not canaccessvalue(sender) then return end
    if not self.keywords[strtrim(message):lower()] then return end
    if IsPartyLFG() or IsQueueStatusActive() then return end
    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then return end
    if GetNumGroupMembers() >= (IsInRaid() and 40 or 5) then return end

    local q = GetQ()
    local guid, accountID = select(10, ...)
    if event == "CHAT_MSG_BN_WHISPER" then
      if not q.whisperInviteBattleNetFriends or not canaccessvalue(accountID) or not accountID then return end
      local account = C_BattleNet.GetAccountInfoByID(accountID)
      if not account or not account.isFriend then return end
      local game = account.gameAccountInfo
      if game.clientProgram ~= "WoW" or not game.isOnline or game.wowProjectID ~= WOW_PROJECT_ID then return end
      C_BattleNet.InviteFriend(game.gameAccountID)
    else
      if not canaccessvalue(guid) or not guid or guid == "" then return end
      -- GUID-only trust avoids treating a same-name character on another realm as a friend.
      if TrustedUnits_IsTrusted(nil, guid, q.whisperInviteFriends,
        q.whisperInviteBattleNetFriends, q.whisperInviteGuildMembers, false) then
        C_PartyInfo.InviteUnit(sender)
      end
    end
  end)
  function f:RefreshState()
    self:UnregisterAllEvents()
    local q = GetQ()
    self.keywords = {}
    for keyword in q.whisperInviteKeyword:gmatch("[^,]+") do
      keyword = strtrim(keyword):lower()
      if keyword ~= "" then self.keywords[keyword] = true end
    end
    if q.whisperInvites and next(self.keywords) then
      self:RegisterEvent("CHAT_MSG_WHISPER")
      if q.whisperInviteBattleNetFriends then self:RegisterEvent("CHAT_MSG_BN_WHISPER") end
    end
  end
  return f
end

local AccessibilityProfile

local function ApplyAccessibility()
  local q = GetQ()
  if AccessibilityProfile and AccessibilityProfile ~= q then
    for name, value in pairs(AccessibilityProfile.accessibilityOriginalCVars) do
      C_CVar.SetCVar(name, value)
      AccessibilityProfile.accessibilityOriginalCVars[name] = nil
    end
  end
  AccessibilityProfile = q
  local originals = q.accessibilityOriginalCVars
  local function ApplyCVar(name, enabled, value)
    local current = C_CVar.GetCVar(name)
    if current == nil then return end
    if enabled then
      if originals[name] == nil then originals[name] = current end
      if current ~= value then C_CVar.SetCVar(name, value) end
    elseif originals[name] ~= nil then
      C_CVar.SetCVar(name, originals[name])
      originals[name] = nil
    end
  end
  ApplyCVar("ffxGlow", q.disableScreenGlow, "0")
  ApplyCVar("ffxDeath", q.disableScreenEffects, "0")
  ApplyCVar("ffxNether", q.disableScreenEffects, "0")
  ApplyCVar("ffxVenari", q.disableScreenEffects, "0")
  ApplyCVar("ffxLingeringVenari", q.disableScreenEffects, "0")
  local density = tostring(q.weatherDensity)
  ApplyCVar("weatherDensity", q.customWeatherDensity, density)
  ApplyCVar("RAIDweatherDensity", q.customWeatherDensity, density)
end

local ConfirmationHooksInstalled = false

local function AcceptAutomaticConfirmation(popup)
  if InCombatLockdown() then return end
  local q = GetQ()
  if popup.which == "CONFIRM_SUMMON" and q.autoAcceptSummons and PlayerCanTeleport() then
    C_SummonInfo.ConfirmSummon()
    StaticPopup_Hide("CONFIRM_SUMMON")
  elseif popup.which == "RESURRECT_NO_TIMER" and q.autoAcceptResurrection then
    AcceptResurrect()
    StaticPopup_Hide("RESURRECT_NO_TIMER")
  end
end

local function ApplyAutomaticConfirmations()
  local q = GetQ()
  if not q.autoAcceptSummons and not q.autoAcceptResurrection then return end
  if not ConfirmationHooksInstalled then
    hooksecurefunc("StaticPopup_Show", function(which)
      if which ~= "CONFIRM_SUMMON" and which ~= "RESURRECT_NO_TIMER" then return end
      local popup = StaticPopup_FindVisible(which)
      if popup then AcceptAutomaticConfirmation(popup) end
    end)
    ConfirmationHooksInstalled = true
  end
  local summon = StaticPopup_FindVisible("CONFIRM_SUMMON")
  if summon then AcceptAutomaticConfirmation(summon) end
  local resurrection = StaticPopup_FindVisible("RESURRECT_NO_TIMER")
  if resurrection then AcceptAutomaticConfirmation(resurrection) end
end

local EntryCountdownDriver

local function EnsureEntryCountdownDriver()
  if EntryCountdownDriver then return EntryCountdownDriver end
  local driver = CreateFrame("Frame", "PleebUI_QualityEntryCountdown")
  EntryCountdownDriver = driver
  driver.displays = {}

  local function StopDisplay(display)
    if display.ticker then display.ticker:Cancel(); display.ticker = nil end
    display.lastSecond = nil
    display:Hide()
  end

  local function StartDisplay(display)
    StopDisplay(display)
    if not GetQ().entryCountdown or not display:GetParent():IsShown() then return end
    if display.kind == "dungeon" and not driver.dungeonDeadline then return end
    local function Update()
      local remaining
      if display.kind == "dungeon" then
        remaining = driver.dungeonDeadline - GetTime()
      else
        local index = display:GetParent().activeIndex
        if not index then StopDisplay(display); return end
        remaining = GetBattlefieldPortExpiration(index)
        if not canaccessvalue(remaining) then StopDisplay(display); return end
      end
      if remaining <= 0 then StopDisplay(display); return end
      if not display.duration then
        display.duration = display.kind == "dungeon" and 40 or remaining
        display:SetMinMaxValues(0, display.duration)
      end
      display:SetValue(remaining)
      local second = math.ceil(remaining)
      if display.lastSecond ~= second then
        display.lastSecond = second
        display.text:SetText((display.kind == "dungeon" and "~" or "") .. second .. "s")
      end
      display:Show()
    end
    Update()
    if display:IsShown() then display.ticker = C_Timer.NewTicker(0.05, Update) end
  end

  local function AttachDisplay(parent, kind)
    if not parent or driver.displays[kind] then return end
    local display = CreateFrame("StatusBar", nil, parent)
    display.kind = kind
    display:SetSize(260, 22)
    display:SetPoint("TOP", parent, "BOTTOM", 0, -6)
    display:EnableMouse(false)
    display.bg = display:CreateTexture(nil, "BACKGROUND")
    display.bg:SetAllPoints(display)
    ns.Theme.SkinStatusBar(display)
    display:SetStatusBarColor(0.85, 0.62, 0.16)
    display.label = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    display.label:SetPoint("LEFT", display, "LEFT", 8, 0)
    display.label:SetText("Time to accept")
    display.text = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    display.text:SetPoint("RIGHT", display, "RIGHT", -8, 0)
    ns.Theme.ApplyFont(display.label, "body", nil, nil, "qualityOfLife")
    ns.Theme.ApplyFont(display.text, "body", nil, nil, "qualityOfLife")
    display:Hide()
    driver.displays[kind] = display
    parent:HookScript("OnShow", function() StartDisplay(display) end)
    parent:HookScript("OnHide", function()
      StopDisplay(display)
      display.duration = nil
    end)
  end

  function driver:RefreshState()
    self:UnregisterAllEvents()
    if GetQ().entryCountdown then
      AttachDisplay(_G.LFGDungeonReadyDialog, "dungeon")
      AttachDisplay(_G.PVPReadyDialog, "pvp")
      self:RegisterEvent("LFG_PROPOSAL_SHOW")
      self:RegisterEvent("LFG_PROPOSAL_DONE")
      self:RegisterEvent("LFG_PROPOSAL_FAILED")
      self:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
      if not self.displays.dungeon or not self.displays.pvp then self:RegisterEvent("ADDON_LOADED") end
      for _, display in pairs(self.displays) do StartDisplay(display) end
    else
      self.dungeonDeadline = nil
      for _, display in pairs(self.displays) do StopDisplay(display) end
    end
  end

  driver:SetScript("OnEvent", function(self, event)
    if event == "ADDON_LOADED" then self:RefreshState(); return end
    -- The proposal API has no expiry; this is the conventional 40-second estimate.
    self.dungeonDeadline = event == "LFG_PROPOSAL_SHOW" and GetTime() + 40 or nil
    if self.displays.dungeon then
      if self.dungeonDeadline then StartDisplay(self.displays.dungeon) else StopDisplay(self.displays.dungeon) end
    end
  end)
  return driver
end

local RoleCheckFrame

local function TrustedUnits_HookRoleCheckButton()
  local button = _G.LFDRoleCheckPopupAcceptButton
  if not button then
    return false
  end

  if not button.__puiRoleCheckHooked then
    button.__puiRoleCheckHooked = true
    button:HookScript("OnShow", function(self)
      local q = GetQ()
      if not q.autoAcceptRoleCheck then
        return
      end

      local leaderName, leaderGUID = TrustedUnits_GetPartyLeader()
      if not leaderName then
        return
      end

      if TrustedUnits_IsTrusted(
        leaderName,
        leaderGUID,
        q.acceptRoleCheckFriends,
        q.acceptRoleCheckBattleNetFriends,
        q.acceptRoleCheckGuildMembers,
        q.acceptRoleCheckCommunityMembers
      ) then
        self:Click()
      end
    end)
  end

  return true
end

local function EnsureRoleCheckDriver()
  if RoleCheckFrame then
    TrustedUnits_HookRoleCheckButton()
    return RoleCheckFrame
  end

  local f = CreateFrame("Frame", "PleebUI_QualityRoleCheck")
  RoleCheckFrame = f
  f:SetScript("OnEvent", function(self)
    if TrustedUnits_HookRoleCheckButton() then
      self:UnregisterAllEvents()
    end
  end)

  function f:RefreshState()
    local q = GetQ()

    TrustedUnits_HookRoleCheckButton()
    self:UnregisterAllEvents()

    if q.autoAcceptRoleCheck and not TrustedUnits_HookRoleCheckButton() then
      self:RegisterEvent("PLAYER_LOGIN")
      self:RegisterEvent("ADDON_LOADED")
    end
  end

  TrustedUnits_HookRoleCheckButton()
  return f
end

local DestroyFrame

local function EnsureDestroyDriver()
  if DestroyFrame then return DestroyFrame end

  local f = CreateFrame("Frame", "PleebUI_QualityDestroy")
  DestroyFrame = f

  for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup and not popup.__puiEasyDestroyHooked then
      popup.__puiEasyDestroyHooked = true
      popup:HookScript("OnShow", function(self)
        local q = GetQ()
        if not q.easyItemDestroy then
          return
        end

        if self.which ~= "DELETE_GOOD_ITEM" and self.which ~= "DELETE_GOOD_QUEST_ITEM" then
          return
        end

        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        if not editBox then
          return
        end

        editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
        editBox:SetFocus()
      end)
    end
  end

  function f:RefreshState()
  end

  return f
end

local function ApplyMovieSkip(enabled)
  if not enabled then
    return
  end

  local function HookKeyUp(frame, btn)
    if not frame or not btn or frame._puiMovieSkipHooked then
      return
    end

    frame._puiMovieSkipHooked = true
    frame:HookScript("OnKeyUp", function(_, key)
      if not GetQ().fasterMovieSkip then
        return
      end

      if key == "ESCAPE" or key == "SPACE" or key == "ENTER" then
        btn:Click()
      end
    end)
  end

  HookKeyUp(CinematicFrame, _G.CinematicFrameCloseDialogConfirmButton)
  HookKeyUp(MovieFrame, MovieFrame and MovieFrame.CloseDialog and MovieFrame.CloseDialog.ConfirmButton)
end


local function ApplyHideTalkingHead(enabled)
  local f = TalkingHeadFrame
  if not f then return end

  ns.FrameUtil.SetFrameGhosted(f, enabled, {
    reapplyOnShow = true,
  })
end


local RestedLoopHooked = false

local function GetRestedLoop()
  return PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop
end

local function ApplyHideRestedZzz(enabled)
  local restLoop = GetRestedLoop()

  if not RestedLoopHooked then
    hooksecurefunc("PlayerFrame_UpdatePlayerRestLoop", function()
      if not GetQ().hideRestedZzz then
        return
      end

      restLoop:Hide()
      restLoop.PlayerRestLoopAnim:Stop()
    end)
    RestedLoopHooked = true
  end

  if enabled then
    restLoop:Hide()
    restLoop.PlayerRestLoopAnim:Stop()
  else
    PlayerFrame_UpdatePlayerRestLoop(IsResting())
  end
end

local function ApplyMaxCameraZoom(enabled)
  local val = enabled and 2.6 or 1.9
  C_CVar.SetCVar("cameraDistanceMaxZoomFactor", tostring(val))
end

local function ApplySuppressGuildAchievementToasts(enabled)
  local af = _G.AlertFrame
  if not af then return end

  af._puiNoGuildAchievementToasts = enabled and true or false

  if not af._puiNoGuildAchievementToastsHooked then
    af._puiNoGuildAchievementToastsHooked = true
    hooksecurefunc(af, "RegisterEvent", function(self, event)
      if self._puiNoGuildAchievementToasts and event == "ACHIEVEMENT_EARNED" then
        self:UnregisterEvent(event)
      end
    end)
  end

  if enabled then
    af:UnregisterEvent("ACHIEVEMENT_EARNED")
  else
    af:RegisterEvent("ACHIEVEMENT_EARNED")
  end
end


local function GhostManagedFrame(frame, hide)
  ns.FrameUtil.SetFrameGhosted(frame, hide, {
    reapplyOnShow = true,
  })
end


local function ApplyHideElements()
  local q = NormalizeDB()
  local h = q.hideElements or {}

  -- IMPORTANT:
  -- ObjectiveTrackerFrame and ZoneAbilityFrame are UIParent managed.
  -- Never Show/Hide them (taints UIParentPanelManager). Ghost instead.
  GhostManagedFrame(ObjectiveTrackerFrame, not not h.objectiveTracker)
  GhostManagedFrame(ZoneAbilityFrame, not not h.zoneAbility)
end

function Quality:GetQuickSetupValue(key)
  local q = GetQ()
  return not not q[key]
end

function Quality:SetQuickSetupValue(key, value, deferApply)
  local q = GetQ()
  q[key] = not not value

  if not deferApply then
    if key == "auctionHouseCurrentExpansionOnly" then
      Quality:RefreshAuctionHousePreference()
      ns.OptionsLifecycle.RefreshModel({ "Quality" })
    else
      Addon:ApplyOptionsChange("Quality", {})
    end
  end

  return q
end


local AuctionHouseQoLFrame

local function AuctionHouse_ApplyCurrentExpansionOnly()
  local searchBar = _G.AuctionHouseFrame and _G.AuctionHouseFrame.SearchBar
  local filterButton = searchBar and searchBar.FilterButton
  if not filterButton or not filterButton.GetFilters or not filterButton.ToggleFilter then
    return false
  end

  local filter = Enum.AuctionHouseFilter.CurrentExpansionOnly
  local filters = filterButton:GetFilters()
  if not filters then
    return false
  end

  local enabled = GetQ().auctionHouseCurrentExpansionOnly == true
  local active = filters[filter] == true

  if active ~= enabled then
    filterButton:ToggleFilter(filter)
  end

  return true
end

local function EnsureAuctionHouseCurrentExpansionOnly()
  if AuctionHouseQoLFrame then
    return AuctionHouseQoLFrame
  end

  local f = CreateFrame("Frame", "PleebUI_QualityAuctionHouseCurrentExpansionOnly")
  AuctionHouseQoLFrame = f
  f:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Blizzard_AuctionHouseUI" then
      return
    end
    Quality:RefreshAuctionHousePreference()
  end)
  return f
end

function Quality:RefreshAuctionHousePreference()
  local driver = EnsureAuctionHouseCurrentExpansionOnly()
  driver:UnregisterAllEvents()
  if AuctionHouse_ApplyCurrentExpansionOnly() then
    if GetQ().auctionHouseCurrentExpansionOnly then
      driver:RegisterEvent("AUCTION_HOUSE_SHOW")
    end
  else
    driver:RegisterEvent("ADDON_LOADED")
  end
end

function Quality:ApplyAll()
  local q = RefreshQ()

  EnsureLootFrame():RefreshState()
  EnsureMerchantDriver():RefreshState()
  EnsureKeystoneDriver():RefreshState()
  EnsureInviteDriver():RefreshState()
  EnsureWhisperInviteDriver():RefreshState()
  EnsureEntryCountdownDriver():RefreshState()
  ApplyAccessibility()
  ApplyAutomaticConfirmations()
  EnsureRoleCheckDriver():RefreshState()
  EnsureDestroyDriver():RefreshState()

  ApplyMovieSkip(not not q.fasterMovieSkip)
  ApplyHideTalkingHead(not not q.hideTalkingHead)
  ApplyHideRestedZzz(not not q.hideRestedZzz)
  ApplyMaxCameraZoom(not not q.maxCameraZoom)
  ApplySuppressGuildAchievementToasts(not not q.suppressGuildAchievementToasts)

  ns.AuraTooltipSettings.ApplyPreference(q.showAuraSpellIDs == true)

  ApplyHideElements()

  self:RefreshAuctionHousePreference()

  if ns.CombatQuality then
    ns.CombatToolsRuntime:Request(ns.CombatQuality, "ApplyRuntimeSettings")
  end

  C_CVar.SetCVar("autoLootDefault", q.autoLoot and "1" or "0")
end

function ns.QualityAPI.BuildOptionsContext(AddonObj)
    local function GetQ()
      return NormalizeDB()
    end

    local function RequestApply(flags)
      AddonObj:ApplyOptionsChange("Quality", flags or {})
      if ns.CombatQuality then ns.CombatQuality.RefreshPreview() end
    end

    local q = GetQ()
    q.cursorRingSize = tonumber(q.cursorRingSize) or 26
    q.cursorRingOutlineSize = tonumber(q.cursorRingOutlineSize) or 10
    q.cursorRingColor = q.cursorRingColor or { r = 1, g = 1, b = 1, a = 0.55 }
    q.cursorRingOutlineColor = q.cursorRingOutlineColor or { r = 1, g = 1, b = 1, a = 0.35 }
    if q.cursorRingShowOutline == nil then q.cursorRingShowOutline = true end
    if q.cursorRingShowInner == nil then q.cursorRingShowInner = true end
    q.crosshairLength = tonumber(q.crosshairLength) or 10
    q.crosshairThickness = tonumber(q.crosshairThickness) or 1
    q.crosshairColor = q.crosshairColor or { r = 1, g = 1, b = 1, a = 0.35 }

    local function ToggleOption(label, key, order, onChanged, disabledFunc)
      local opt = {
        type = "toggle",
        name = label,
        order = order,
        get = function()
          return Quality:GetQuickSetupValue(key)
        end,
        set = function(_, val)
          local qq = Quality:SetQuickSetupValue(key, val, true)
          if onChanged then onChanged(qq, val) end
          RequestApply()
        end,
      }

      if disabledFunc ~= nil then
        opt.disabled = disabledFunc
      end

      return opt
    end

    local function DisabledWhenOff(key)
      return function()
        local qq = GetQ()
        return not qq[key]
      end
    end

    local function DisabledInviteFilters()
      local qq = GetQ()
      return not qq.autoAcceptInvites or qq.acceptInviteEveryone == true
    end

    local function DisabledWhenPetFeatureOff(key)
      return function()
        local qq = GetQ()
        return not qq.petWarningsEnabled or not qq[key]
      end
    end

    local function RefreshMerchantDriverOption()
      RefreshQ()
      EnsureMerchantDriver():RefreshState()
    end

    local function DescriptionOption(text, order, disabledFunc)
      local opt = {
        type = "description",
        name = text,
        order = order,
        
      }

      if disabledFunc ~= nil then
        opt.disabled = disabledFunc
      end

      return opt
    end

    local function RangeOption(label, key, minV, maxV, step, order, disabledFunc, onChanged)
      local opt = {
        type = "range",
        name = label,
        order = order,
        min = minV,
        max = maxV,
        step = step,
        get = function()
          local qq = GetQ()
          return tonumber(qq[key]) or minV
        end,
        set = function(_, val)
          local qq = GetQ()
          qq[key] = Clamp(val, minV, maxV)

          if onChanged then
            onChanged(qq)
          else
            RequestApply()
          end
        end,
      }

      if disabledFunc ~= nil then
        opt.disabled = disabledFunc
      end

      return opt
    end

    local function InputOption(label, key, order, disabledFunc)
      local opt = {
        type = "input",
        name = label,
        order = order,
        get = function()
          local qq = GetQ()
          return tostring(qq[key] or "")
        end,
        set = function(_, value)
          local qq = GetQ()
          qq[key] = tostring(value or "")
          RequestApply()
        end,
      }

      if disabledFunc ~= nil then
        opt.disabled = disabledFunc
      end

      return opt
    end

    local function ColorOption(label, key, order, disabledFunc, hiddenFunc)
      local opt = {
        type = "color",
        name = label,
        order = order,
        hasAlpha = true,
        get = function()
          local qq = GetQ()
          qq[key] = qq[key] or { r = 1, g = 1, b = 1, a = 1 }
          local c = qq[key]
          return c.r or 1, c.g or 1, c.b or 1, c.a or 1
        end,
        set = function(_, r, g, b, a)
          local qq = GetQ()
          qq[key] = qq[key] or {}
          qq[key].r = tonumber(r) or 1
          qq[key].g = tonumber(g) or 1
          qq[key].b = tonumber(b) or 1
          qq[key].a = tonumber(a)
          if qq[key].a == nil then qq[key].a = 1 end
          RequestApply()
        end,
      }

      if disabledFunc ~= nil then
        opt.disabled = disabledFunc
      end

      if hiddenFunc ~= nil then
        opt.hidden = hiddenFunc
      end

      return opt
    end

    return { GetQ = GetQ, RequestApply = RequestApply, ToggleOption = ToggleOption, DisabledWhenOff = DisabledWhenOff, DisabledWhenPetFeatureOff = DisabledWhenPetFeatureOff, DescriptionOption = DescriptionOption, RangeOption = RangeOption, InputOption = InputOption, ColorOption = ColorOption, DisabledInviteFilters = DisabledInviteFilters, RefreshMerchantDriverOption = RefreshMerchantDriverOption }
end

local function QualityProvider(AddonObj)
  local provider = {}
  function provider:GetOptions()
    local context = ns.QualityAPI.BuildOptionsContext(AddonObj)
    local DisabledInviteFilters = context.DisabledInviteFilters
    local RefreshMerchantDriverOption = context.RefreshMerchantDriverOption
    local GetQ = context.GetQ
    local RequestApply = context.RequestApply
    local ToggleOption = context.ToggleOption
    local DisabledWhenOff = context.DisabledWhenOff
    local DisabledWhenPetFeatureOff = context.DisabledWhenPetFeatureOff
    local DescriptionOption = context.DescriptionOption
    local RangeOption = context.RangeOption
    local InputOption = context.InputOption
    local ColorOption = context.ColorOption
    local options = {
      type = "group",
      name = "Quality of Life",
      order = 15,
      childGroups = "tab",
      args = {
        automationTab = {
          type = "group",
          name = "Automation",
          order = 2,
          args = {
            loot = {
              type = "group",
              name = "Loot",
              order = 15,
              inline = true,
              args = {
                autoLoot = ToggleOption("Auto loot", "autoLoot", 1),
                fasterLooting = ToggleOption("Faster looting", "fasterLooting", 2),
              },
            },
            merchant = {
              type = "group",
              name = "Merchant",
              order = 20,
              inline = true,
              args = {
                autoRepair = ToggleOption("Auto repair", "autoRepair", 1, RefreshMerchantDriverOption),
                guildRepairFirst = ToggleOption("Use guild funds first", "guildRepairFirst", 2, nil, DisabledWhenOff("autoRepair")),
                autoRepairShowSummary = ToggleOption("Show repair cost in chat", "autoRepairShowSummary", 3, nil, DisabledWhenOff("autoRepair")),
                autoSellJunk = ToggleOption("Auto sell junk", "autoSellJunk", 4, RefreshMerchantDriverOption),
              },
            },
            mythicPlus = {
              type = "group",
              name = "Mythic+",
              order = 25,
              inline = true,
              args = {
                autoKeystone = ToggleOption("Auto insert keystone", "autoKeystone", 1),
              },
            },
            auctionHouse = {
              type = "group",
              name = "Auction house",
              order = 30,
              inline = true,
              args = {
                auctionHouseCurrentExpansionOnly = ToggleOption("Current expansion only", "auctionHouseCurrentExpansionOnly", 1),
              },
            },
            roleCheck = {
              type = "group",
              name = "Role checks",
              order = 32,
              inline = true,
              args = {
                autoAcceptRoleCheck = ToggleOption("Auto accept role checks", "autoAcceptRoleCheck", 1),
                roleCheckHelp = DescriptionOption("Accept role checks from:", 2, DisabledWhenOff("autoAcceptRoleCheck")),
                acceptRoleCheckFriends = ToggleOption("Friends", "acceptRoleCheckFriends", 3, nil, DisabledWhenOff("autoAcceptRoleCheck")),
                acceptRoleCheckBattleNetFriends = ToggleOption("Battle.net friends", "acceptRoleCheckBattleNetFriends", 4, nil, DisabledWhenOff("autoAcceptRoleCheck")),
                acceptRoleCheckGuildMembers = ToggleOption("Guild members", "acceptRoleCheckGuildMembers", 5, nil, DisabledWhenOff("autoAcceptRoleCheck")),
                acceptRoleCheckCommunityMembers = ToggleOption("Community members", "acceptRoleCheckCommunityMembers", 6, nil, DisabledWhenOff("autoAcceptRoleCheck")),
              },
            },
            invites = {
              type = "group",
              name = "Invites",
              order = 34,
              inline = true,
              args = {
                autoAcceptInvites = ToggleOption("Auto accept invites", "autoAcceptInvites", 1),
                invitesHelp = DescriptionOption("Accept invites from:", 2, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteEveryone = ToggleOption("Everyone", "acceptInviteEveryone", 3, nil, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteFriends = ToggleOption("Friends", "acceptInviteFriends", 4, nil, DisabledInviteFilters),
                acceptInviteBattleNetFriends = ToggleOption("Battle.net friends", "acceptInviteBattleNetFriends", 5, nil, DisabledInviteFilters),
                acceptInviteGuildMembers = ToggleOption("Guild members", "acceptInviteGuildMembers", 6, nil, DisabledInviteFilters),
                acceptInviteCommunityMembers = ToggleOption("Community members", "acceptInviteCommunityMembers", 7, nil, DisabledInviteFilters),
              },
            },
            dialogs = {
              type = "group",
              name = "Dialogs",
              order = 36,
              inline = true,
              args = {
                easyItemDestroy = ToggleOption("Easy item deletion", "easyItemDestroy", 1),
                fasterMovieSkip = ToggleOption("Skip movies faster", "fasterMovieSkip", 2),
              },
            },
            uiAndCamera = {
              type = "group",
              name = "UI and camera",
              order = 40,
              inline = true,
              args = {
                hideTalkingHead = ToggleOption("Hide talking head", "hideTalkingHead", 1),
                hideRestedZzz = ToggleOption("Hide rested Zzz", "hideRestedZzz", 2),
                maxCameraZoom = ToggleOption("Max camera zoom", "maxCameraZoom", 3),
                suppressGuildAchievementToasts = ToggleOption("Suppress guild achievement toasts", "suppressGuildAchievementToasts", 4),
                showAuraSpellIDs = ToggleOption(
                  "Show aura spell IDs outside /pui",
                  "showAuraSpellIDs",
                  6,
                  function(_, value)
                    ns.AuraTooltipSettings.ApplyPreference(value == true)
                  end
                ),
              },
            },
          },
        },
      },
    }

    local automation = options.args.automationTab.args
    automation.loot.args.fasterLooting.desc =
      "Takes items as soon as loot is ready and confirms loot-binding prompts. Auto loot is configured separately."
    automation.merchant.args.autoRepair.desc =
      "Automatically repairs at merchants. Hold Shift when opening a merchant to skip automatic repair and junk selling."
    automation.merchant.args.autoSellJunk.desc =
      "Automatically sells poor-quality items. Hold Shift when opening a merchant to skip both merchant automations."
    automation.dialogs.args.easyItemDestroy.desc =
      "Automatically fills the required confirmation text when deleting an item. You still confirm the deletion."

    local interfaceSettings = automation.uiAndCamera
    automation.loot.name = "Everyday conveniences"
    automation.loot.args.autoKeystone = automation.mythicPlus.args.autoKeystone
    automation.loot.args.autoKeystone.order = 3
    automation.loot.args.fasterMovieSkip = automation.dialogs.args.fasterMovieSkip
    automation.loot.args.fasterMovieSkip.order = 4
    automation.merchant.name = "Items and merchants"
    automation.merchant.args.auctionHouseCurrentExpansionOnly = automation.auctionHouse.args.auctionHouseCurrentExpansionOnly
    automation.merchant.args.auctionHouseCurrentExpansionOnly.name = "Auction house: current expansion only"
    automation.merchant.args.auctionHouseCurrentExpansionOnly.desc = "Applies the current-expansion filter when opening the auction house."
    automation.merchant.args.auctionHouseCurrentExpansionOnly.order = 5
    automation.merchant.args.easyItemDestroy = automation.dialogs.args.easyItemDestroy
    automation.merchant.args.easyItemDestroy.order = 6
    interfaceSettings.name = "Interface and camera"
    automation.loot.args.entryCountdown = ToggleOption("Show entry countdown bar", "entryCountdown", 5)
    automation.loot.args.entryCountdown.desc = "Shows a draining bar with time to accept dungeon and PvP queue prompts. Dungeon time is a 40-second estimate."
    local confirmations = {
      type = "group", name = "Summons and resurrection", inline = true, order = 35,
      args = {
        summons = ToggleOption("Auto accept summons", "autoAcceptSummons", 1),
        resurrection = ToggleOption("Auto accept resurrection", "autoAcceptResurrection", 2),
        help = DescriptionOption("Opt in to accept ordinary summons and resurrection outside combat. Special summon warnings, resurrection sickness and recovery timers still require confirmation.", 3),
      },
    }
    local whisperInvites = {
      type = "group", name = "Whisper invites", inline = true, order = 36,
      args = {
        enabled = ToggleOption("Invite by whisper keyword", "whisperInvites", 1),
        keyword = InputOption("Keywords", "whisperInviteKeyword", 2, DisabledWhenOff("whisperInvites")),
        help = DescriptionOption("Separate keywords with commas, for example: invite, inv, +. Each matches the whole message, ignoring case and surrounding spaces. Invites trusted senders while solo or able to invite to your group. Unavailable during combat or restricted chat.", 3),
        friends = ToggleOption("Friends", "whisperInviteFriends", 4, nil, DisabledWhenOff("whisperInvites")),
        battleNet = ToggleOption("Battle.net friends", "whisperInviteBattleNetFriends", 5, nil, DisabledWhenOff("whisperInvites")),
        guild = ToggleOption("Guild members", "whisperInviteGuildMembers", 6, nil, DisabledWhenOff("whisperInvites")),
      },
    }
    local accessibility = {
      type = "group", name = "Accessibility", inline = true, order = 45,
      args = {
        glow = ToggleOption("Disable screen glow", "disableScreenGlow", 1),
        effects = ToggleOption("Disable screen effects", "disableScreenEffects", 2),
        effectsHelp = DescriptionOption("Disables death desaturation, nether and Ven'ari screen effects.", 3),
        weather = ToggleOption("Adjust weather density", "customWeatherDensity", 4),
        density = RangeOption("Weather density", "weatherDensity", 0, 3, 1, 5, DisabledWhenOff("customWeatherDensity")),
        help = DescriptionOption("Weather density: 0 hides weather, 3 shows full density. Applies to regular and raid graphics. Disabling a control restores its previous setting.", 6),
      },
    }
    options.args.automationTab.args = {
      loot = automation.loot, merchant = automation.merchant,
      roleCheck = automation.roleCheck, invites = automation.invites,
      uiAndCamera = interfaceSettings,
      confirmations = confirmations, whisperInvites = whisperInvites,
      accessibility = accessibility,
    }
    options.args.automationTab.name = "Convenience"
    options.args.automationTab.order = 4


    local tabs
    if ns.CombatQuality then
      tabs = ns.CombatQuality.BuildOptions(context)
    else
      tabs = {}
      for _, spec in ipairs({ { "combatTab", "Combat", 1 }, { "cursorTab", "Position indicators", 2 }, { "groupTab", "Group tools", 3 } }) do
        tabs[spec[1]] = { type = "group", name = spec[2], order = spec[3], args = ns.CombatToolsDisabledOptions:GetOptions().args }
      end
    end
    for key, tab in pairs(tabs) do options.args[key] = tab end
    for _, tab in pairs(options.args) do tab.arg = { puiExplicit = true } end
    return options
  end
  return provider
end

Addon:RegisterOptionsSection("Quality", QualityProvider, 80, "Quality of Life", nil, {
  allowPreview = true,
  page = {
    previewAlwaysShown = true,
    tabsBeforeHeader = true,
    previewWidth = 340,
    previewHeight = 190,
    previewPathMatches = function(path)
      return ns.CombatQuality ~= nil and (path[2] == "combatTab" or path[2] == "cursorTab" or path[2] == "groupTab" or path[2] == "automationTab")
    end,
    buildPreview = function(...)
      if ns.CombatQuality then return ns.CombatQuality.BuildPreview(...) end
    end,
  },
})



-- Fire once on login.
local Boot = CreateFrame("Frame", "PleebUI_QualityBoot")
Boot:RegisterEvent("PLAYER_ENTERING_WORLD")
Boot:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  Quality:ApplyAll()
end)
