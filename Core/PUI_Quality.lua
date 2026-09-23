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

local function GetGuildRepairRemaining()
  local remaining = tonumber(GetGuildBankWithdrawMoney())
  if not remaining then
    return nil
  end

  return remaining
end

local function PlayRepairCoinSound()
  C_Timer.After(0, function()
    PlaySound(SOUNDKIT.ITEM_REPAIR, "Master")
  end)
end

local function CVarSetSafe(name, value)
  local v = value and "1" or "0"
  C_CVar.SetCVar(name, v)
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

  if q.enableMPlusJournalTeleports == nil then q.enableMPlusJournalTeleports = true end

  q.autoRepair = NormalizeBool(q.autoRepair, true)
  q.guildRepairFirst = NormalizeBool(q.guildRepairFirst, true)
  q.autoRepairShowSummary = NormalizeBool(q.autoRepairShowSummary, true)

  q.autoSellJunk = NormalizeBool(q.autoSellJunk, true)
  if q.autoKeystone == nil then q.autoKeystone = true end

  if q.autoAcceptInvites == nil then q.autoAcceptInvites = true end
  q.autoAcceptInvites = NormalizeBool(q.autoAcceptInvites, true)

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

  if q.easyItemDestroy == nil then q.easyItemDestroy = false end
  if q.fasterMovieSkip == nil then q.fasterMovieSkip = false end

  if q.hideTalkingHead == nil then q.hideTalkingHead = false end
  if q.hideRestedZzz == nil then q.hideRestedZzz = true end

  if q.maxCameraZoom == nil then q.maxCameraZoom = true end
  if q.suppressGuildAchievementToasts == nil then q.suppressGuildAchievementToasts = false end
  if q.showAuraSpellIDs == nil then q.showAuraSpellIDs = false end

  if q.petWarningsEnabled == nil then q.petWarningsEnabled = true end
  if q.missingPetWarning == nil then q.missingPetWarning = true end
  if q.hidePetWarningWhileDragonriding == nil then q.hidePetWarningWhileDragonriding = true end
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

  local raidUtilityModule = ns.RaidUtilityModule
  raidUtilityModule.NormalizeDB(q)

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

  q.combatTimerFontSize = Clamp(q.combatTimerFontSize or 14, 10, 28)
  q.combatMessageFontSize = Clamp(q.combatMessageFontSize or 18, 10, 40)
  q.combatWarningFontSize = Clamp(q.combatWarningFontSize or 32, 16, 60)

  return q
end

ns.QualityAPI = ns.QualityAPI or {}
ns.QualityAPI.NormalizeDB = NormalizeDB
ns.QualityAPI.Clamp = Clamp
ns.QualityAPI.SeedAnchorDefaults = SeedAnchorDefaults

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

local function SaveMoverPosition(frame, anchorKey)
  local q = NormalizeDB()
  q[anchorKey] = q[anchorKey] or {}
  local x, y = ns.FrameUtil.GetMoverOffsets(frame)

  q[anchorKey].x = math.floor((x or 0) + 0.5)
  q[anchorKey].y = math.floor((y or 0) + 0.5)
end

local CombatMsgFrame
local CombatMsgText
local CombatMsgAnimIn
local CombatMsgAnimOut

local function EnsureCombatMsgFrame()
  local d = QUALITY_POSITION_DEFAULTS.combatMessage

  if CombatMsgFrame then
    CombatMsgFrame:__puiApplyAnchor()
    return CombatMsgFrame
  end

  local q = GetQ()
  q.combatMessageAnchor = SeedAnchorDefaults(q.combatMessageAnchor, d)

  local f = CreateFrame("Frame", "PleebUI_QualityCombatMsg", UIParent)
  CombatMsgFrame = f
  f:SetSize(360, 44)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:EnableMouse(false)
  f:SetAlpha(0)
  f:Show()

  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  CombatMsgText = fs
  fs:SetPoint("CENTER", f, "CENTER", 0, 0)
  ns.Theme.ApplyFont(fs, "header", q.combatMessageFontSize, nil, "qualityOfLife")
  fs:SetJustifyH("CENTER")
  fs:SetJustifyV("MIDDLE")
  fs:SetText("")

  local function ApplyAnchor()
    local qq = GetQ()
    local a = qq.combatMessageAnchor or d
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x or d.x, a.y or d.y)
  end

  f.__puiApplyAnchor = ApplyAnchor
  ApplyAnchor()

  local agIn = f:CreateAnimationGroup()
  CombatMsgAnimIn = agIn
  local aIn = agIn:CreateAnimation("Alpha")
  aIn:SetFromAlpha(0)
  aIn:SetToAlpha(1)
  aIn:SetDuration(1.0)
  aIn:SetSmoothing("IN_OUT")

  local agOut = f:CreateAnimationGroup()
  CombatMsgAnimOut = agOut
  local aOut = agOut:CreateAnimation("Alpha")
  aOut:SetFromAlpha(1)
  aOut:SetToAlpha(0)
  aOut:SetDuration(2.0)
  aOut:SetSmoothing("IN_OUT")

  agOut:SetScript("OnFinished", function()
    f:SetAlpha(0)
  end)

  agIn:SetScript("OnFinished", function()
    CombatMsgAnimOut:Play()
  end)

  local function ShowMessage(text)
    local qq = GetQ()
    if not qq.combatMessage then
      f:SetAlpha(0)
      return
    end

    ApplyAnchor()
    CombatMsgText:SetText(tostring(text or ""))

    if CombatMsgAnimOut:IsPlaying() then
      CombatMsgAnimOut:Stop()
    end
    if CombatMsgAnimIn:IsPlaying() then
      CombatMsgAnimIn:Stop()
    end

    f:SetAlpha(0)
    CombatMsgAnimIn:Play()
  end

  ns.FrameUtil:RegisterMover("quality_combat_message", f, {
    label = "Combat Message",
    optionsString = "Quality,qualityTab",
    savePosition = function()
      SaveMoverPosition(f, "combatMessageAnchor")
    end,
    resetPosition = function()
      local qq = GetQ()
      qq.combatMessageAnchor = SeedAnchorDefaults(nil, d)
      ApplyAnchor()
    end,
    quickSettings = function()
      local qq = GetQ()
      return {
        ownerKey = "quality_combat_message",
        title = "Combat Message",
        description = "Live combat message settings.",
        controls = {
          {
            type = "slider",
            label = "Font size",
            min = 10,
            max = 40,
            step = 1,
            get = function() return qq.combatMessageFontSize end,
            set = function(value)
              qq.combatMessageFontSize = Clamp(value, 10, 40)
              ns.Theme.ApplyFont(fs, "header", qq.combatMessageFontSize, nil, "qualityOfLife")
            end,
          },
        },
      }
    end,
  })

  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      ShowMessage("Entering Combat")
    elseif event == "PLAYER_REGEN_ENABLED" then
      ShowMessage("Leaving Combat")
    end
  end)

  function f:RefreshState()
    local qq = GetQ()
    self:UnregisterAllEvents()

    if qq.combatMessage then
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
      if CombatMsgAnimIn:IsPlaying() then
        CombatMsgAnimIn:Stop()
      end
      if CombatMsgAnimOut:IsPlaying() then
        CombatMsgAnimOut:Stop()
      end
      self:SetAlpha(0)
    end
  end

  return f
end

local CombatTimerFrame
local CombatTimerText
local CombatTimerStart
local CombatTimerTicker

local function StopCombatTimerTicker()
  if CombatTimerTicker then
    CombatTimerTicker:Cancel()
    CombatTimerTicker = nil
  end
end

local function EnsureCombatTimer()
  if CombatTimerFrame then return CombatTimerFrame end

  local q = GetQ()
  local d = QUALITY_POSITION_DEFAULTS.combatTimer
  q.combatTimerAnchor = SeedAnchorDefaults(q.combatTimerAnchor, d)

  local f = CreateFrame("Frame", "PleebUI_CombatTimer", UIParent, "BackdropTemplate")
  CombatTimerFrame = f
  f:SetSize(120, 22)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:EnableMouse(false)
  f:SetAlpha(0)
  f:Show()

  ns.Theme.WidgetSkins.Frame(f)

  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("CENTER", f, "CENTER", 0, 0)
  fs:SetText("00:00")
  CombatTimerText = fs
  ns.Theme.ApplyFont(fs, "body", q.combatTimerFontSize, nil, "qualityOfLife")

  local function ApplyAnchor()
    local qq = GetQ()
    local a = qq.combatTimerAnchor or d
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x or d.x, a.y or d.y)
  end

  f.__puiApplyAnchor = ApplyAnchor
  ApplyAnchor()

  ns.FrameUtil:RegisterMover("quality_combat_timer", f, {
    label = "Combat Timer",
    optionsString = "Quality,qualityTab",
    smartSnap = {
      family = "positionOnly",
    },
    savePosition = function()
      SaveMoverPosition(f, "combatTimerAnchor")
    end,
    resetPosition = function()
      local qq = GetQ()
      qq.combatTimerAnchor = SeedAnchorDefaults(nil, d)
      ApplyAnchor()
    end,
    quickSettings = function()
      local qq = GetQ()
      return {
        ownerKey = "quality_combat_timer",
        title = "Combat Timer",
        description = "Live combat timer settings.",
        controls = {
          {
            type = "slider",
            label = "Font size",
            min = 10,
            max = 28,
            step = 1,
            get = function() return qq.combatTimerFontSize end,
            set = function(value)
              qq.combatTimerFontSize = Clamp(value, 10, 28)
              ns.Theme.ApplyFont(fs, "body", qq.combatTimerFontSize, nil, "qualityOfLife")
            end,
          },
        },
      }
    end,
  })

  local function CombatTimer_Update()
    if not CombatTimerStart then return end

    local elapsed = GetTime() - CombatTimerStart
    if elapsed < 0 then elapsed = 0 end

    local total = math.floor(elapsed)
    if total == (f.__puiCombatTimerLastSecond or -1) then
      return
    end
    f.__puiCombatTimerLastSecond = total

    local m = math.floor(total / 60)
    local s = total - (m * 60)
    local mm = (m < 10) and ("0" .. m) or tostring(m)
    local ss = (s < 10) and ("0" .. s) or tostring(s)
    CombatTimerText:SetText(mm .. ":" .. ss)
  end

  f.__puiCombatTimerUpdate = CombatTimer_Update

  return f
end

local CombatTimerEventFrame

local function EnsureCombatTimerEvents()
  if CombatTimerEventFrame then return CombatTimerEventFrame end
  local f = CreateFrame("Frame", "PleebUI_QualityCombatTimerEvents")
  CombatTimerEventFrame = f
  f:SetScript("OnEvent", function(_, event)
    local q = GetQ()
    local ct = EnsureCombatTimer()

    if not q.combatTimer then
      CombatTimerStart = nil
      StopCombatTimerTicker()
      ct:SetAlpha(0)
      return
    end

    if event == "PLAYER_REGEN_DISABLED" then
      CombatTimerStart = GetTime()
      ct.__puiCombatTimerLastSecond = -1
      StopCombatTimerTicker()

      if q.combatTimerAnchor then
        local d = QUALITY_POSITION_DEFAULTS.combatTimer
        ct:ClearAllPoints()
        ct:SetPoint("CENTER", UIParent, "CENTER", q.combatTimerAnchor.x or d.x, q.combatTimerAnchor.y or d.y)
      end

      local fontPath, _, flags = CombatTimerText:GetFont()
      CombatTimerText:SetFont(
        fontPath,
        ns.Theme.ResolveFontSize(q.combatTimerFontSize or 14, "qualityOfLife"),
        flags or "OUTLINE"
      )
      ct:SetAlpha(1)
      ct.__puiCombatTimerUpdate()
      CombatTimerTicker = C_Timer.NewTicker(1, ct.__puiCombatTimerUpdate)
    elseif event == "PLAYER_REGEN_ENABLED" then
      CombatTimerStart = nil
      StopCombatTimerTicker()
      ct:SetAlpha(0)
    end
  end)

  function f:RefreshState()
    local q = GetQ()
    local ct = EnsureCombatTimer()

    self:UnregisterAllEvents()

    if q.combatTimer then
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
      CombatTimerStart = nil
      StopCombatTimerTicker()
      ct:SetAlpha(0)
    end
  end

  return f
end

local COMBAT_WARNING_MELEE_RANGE_ITEM = 8149
local COMBAT_WARNING_RANGE_INTERVAL = 0.15

local CombatWarningFrame
local CombatWarningNoTargetText
local CombatWarningNotAttackingFrame
local CombatWarningNotAttackingText
local CombatWarningEventFrame
local CombatWarningRangeTicker
local CombatWarningPlayerInCombat = false
local CombatWarningRelevantContent = false
local CombatWarningMeleeSpec = false

local function CombatWarning_RefreshMeleeSpec()
  local _, classFile = UnitClass("player")

  if classFile == "DEATHKNIGHT" or classFile == "ROGUE" or classFile == "WARRIOR" then
    CombatWarningMeleeSpec = true
    return
  end

  local specIndex = GetSpecialization()
  local specID = specIndex and GetSpecializationInfo(specIndex)
  if not specID then
    CombatWarningMeleeSpec = false
    return
  end

  if classFile == "DRUID" then
    CombatWarningMeleeSpec = specID ~= 102 and specID ~= 105
  elseif classFile == "DEMONHUNTER" then
    CombatWarningMeleeSpec = specID == 577 or specID == 581
  elseif classFile == "HUNTER" then
    CombatWarningMeleeSpec = specID ~= 253 and specID ~= 254
  elseif classFile == "PALADIN" then
    CombatWarningMeleeSpec = specID ~= 65
  elseif classFile == "SHAMAN" then
    CombatWarningMeleeSpec = specID == 263
  elseif classFile == "MONK" then
    CombatWarningMeleeSpec = specID ~= 270
  else
    CombatWarningMeleeSpec = false
  end
end

local function CombatWarning_RefreshContent()
  local _, instanceType = IsInInstance()
  CombatWarningRelevantContent = instanceType == "raid" or C_ChallengeMode.IsChallengeModeActive()
end

local function CombatWarning_StopRangeTicker()
  if CombatWarningRangeTicker then
    CombatWarningRangeTicker:Cancel()
    CombatWarningRangeTicker = nil
  end
end

local function EnsureCombatWarningFrame()
  if CombatWarningFrame then
    return CombatWarningFrame
  end

  local d = QUALITY_POSITION_DEFAULTS.combatWarning
  local q = GetQ()
  q.combatWarningAnchor = SeedAnchorDefaults(q.combatWarningAnchor, d)

  local f = CreateFrame("Frame", "PleebUI_CombatWarning", UIParent)
  CombatWarningFrame = f
  f:SetSize(600, 80)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:EnableMouse(false)
  f:Show()

  local noTargetText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  CombatWarningNoTargetText = noTargetText
  noTargetText:SetPoint("CENTER", f, "CENTER", 0, 0)
  noTargetText:SetJustifyH("CENTER")
  noTargetText:SetJustifyV("MIDDLE")
  noTargetText:SetTextColor(1, 0, 0, 1)
  noTargetText:SetText("NO TARGET")
  noTargetText:Hide()

  local notAttackingFrame = CreateFrame("Frame", nil, f)
  CombatWarningNotAttackingFrame = notAttackingFrame
  notAttackingFrame:SetAllPoints(f)
  notAttackingFrame:EnableMouse(false)
  notAttackingFrame:Hide()

  local notAttackingText = notAttackingFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  CombatWarningNotAttackingText = notAttackingText
  notAttackingText:SetPoint("CENTER", notAttackingFrame, "CENTER", 0, 0)
  notAttackingText:SetJustifyH("CENTER")
  notAttackingText:SetJustifyV("MIDDLE")
  notAttackingText:SetTextColor(1, 0, 0, 1)
  notAttackingText:SetText("NOT ATTACKING")
  notAttackingText:Show()

  local function ApplyAnchor()
    local qq = GetQ()
    local a = qq.combatWarningAnchor or d
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x or d.x, a.y or d.y)
  end

  function f:RefreshVisuals()
    local qq = GetQ()
    ApplyAnchor()
    ns.Theme.ApplyFont(noTargetText, "header", qq.combatWarningFontSize, nil, "qualityOfLife")
    ns.Theme.ApplyFont(notAttackingText, "header", qq.combatWarningFontSize, nil, "qualityOfLife")
  end

  f:RefreshVisuals()

  ns.FrameUtil:RegisterMover("quality_combat_warning", f, {
    label = "Combat Warning",
    optionsString = "Quality,qualityTab",
    smartSnap = {
      family = "positionOnly",
    },
    savePosition = function()
      SaveMoverPosition(f, "combatWarningAnchor")
    end,
    resetPosition = function()
      local qq = GetQ()
      qq.combatWarningAnchor = SeedAnchorDefaults(nil, d)
      ApplyAnchor()
    end,
    quickSettings = function()
      local qq = GetQ()
      return {
        ownerKey = "quality_combat_warning",
        title = "Combat Warning",
        description = "No target and melee range warnings.",
        controls = {
          {
            type = "slider",
            label = "Font size",
            min = 16,
            max = 60,
            step = 1,
            get = function() return qq.combatWarningFontSize end,
            set = function(value)
              qq.combatWarningFontSize = Clamp(value, 16, 60)
              ns.Theme.ApplyFont(noTargetText, "header", qq.combatWarningFontSize, nil, "qualityOfLife")
              ns.Theme.ApplyFont(notAttackingText, "header", qq.combatWarningFontSize, nil, "qualityOfLife")
            end,
          },
        },
      }
    end,
  })

  return f
end

local function CombatWarning_UpdateRange()
  -- The range result may be secret in combat, so it must go directly into a render API.
  CombatWarningNotAttackingText:SetAlphaFromBoolean(C_Item.IsItemInRange(COMBAT_WARNING_MELEE_RANGE_ITEM, "target"), 0, 1)
end

local function CombatWarning_Update()
  local q = GetQ()

  if not CombatWarningPlayerInCombat or not CombatWarningRelevantContent then
    CombatWarning_StopRangeTicker()
    CombatWarningNoTargetText:Hide()
    CombatWarningNotAttackingFrame:Hide()
    return
  end

  if not UnitExists("target") then
    CombatWarning_StopRangeTicker()
    CombatWarningNotAttackingFrame:Hide()

    if q.noTargetWarning then
      CombatWarningNoTargetText:Show()
    else
      CombatWarningNoTargetText:Hide()
    end
    return
  end

  CombatWarningNoTargetText:Hide()

  if not q.notAttackingWarning
    or not CombatWarningMeleeSpec
    or not UnitCanAttack("player", "target") then
    CombatWarning_StopRangeTicker()
    CombatWarningNotAttackingFrame:Hide()
    return
  end

  if not CombatWarningRangeTicker then
    CombatWarningRangeTicker = C_Timer.NewTicker(COMBAT_WARNING_RANGE_INTERVAL, CombatWarning_UpdateRange)
  end

  CombatWarningNotAttackingFrame:Show()
  CombatWarning_UpdateRange()
end

local function EnsureCombatWarningEvents()
  if CombatWarningEventFrame then
    return CombatWarningEventFrame
  end

  local f = CreateFrame("Frame", "PleebUI_QualityCombatWarningEvents")
  CombatWarningEventFrame = f
  f:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
      CombatWarningPlayerInCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
      CombatWarningPlayerInCombat = false
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
      if unit and unit ~= "player" then
        return
      end
      CombatWarning_RefreshMeleeSpec()
    elseif event == "CHALLENGE_MODE_START" then
      CombatWarningRelevantContent = true
    elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
      CombatWarningRelevantContent = false
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
      CombatWarningPlayerInCombat = UnitAffectingCombat("player")
      CombatWarning_RefreshContent()
    end

    CombatWarning_Update()
  end)

  function f:RefreshState()
    local q = GetQ()
    local warningFrame = EnsureCombatWarningFrame()
    warningFrame:RefreshVisuals()

    self:UnregisterAllEvents()
    CombatWarning_StopRangeTicker()
    CombatWarningPlayerInCombat = UnitAffectingCombat("player")
    CombatWarning_RefreshContent()
    CombatWarning_RefreshMeleeSpec()

    if q.noTargetWarning or q.notAttackingWarning then
      self:RegisterEvent("PLAYER_ENTERING_WORLD")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_TARGET_CHANGED")
      if q.notAttackingWarning then
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterUnitEvent("UNIT_FACTION", "target")
        self:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", "target")
      end
      self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
      self:RegisterEvent("CHALLENGE_MODE_START")
      self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
      self:RegisterEvent("CHALLENGE_MODE_RESET")
      CombatWarning_Update()
    else
      CombatWarningNoTargetText:Hide()
      CombatWarningNotAttackingFrame:Hide()
    end
  end

  return f
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
local MerchantActionToken = 0

local function Merchant_ShouldSkipAutomation()
  return IsShiftKeyDown()
end

local function Merchant_ProcessAutoRepair(q, token)
  if token ~= MerchantActionToken then
    return
  end

  if q.autoRepair ~= true then
    return
  end

  if Merchant_ShouldSkipAutomation() then
    return
  end

  if not CanMerchantRepair() then
    return
  end

  local repairCost, canRepair = GetRepairAllCost()
  repairCost = tonumber(repairCost) or 0

  if not canRepair or repairCost <= 0 then
    return
  end

  local guildRepairAllowed = q.guildRepairFirst == true and IsInGuild() and CanGuildBankRepair()
  local playerMoneyBefore = tonumber(GetMoney())
  local guildRemainingBefore = guildRepairAllowed and GetGuildRepairRemaining() or nil

  if guildRepairAllowed then
    RepairAllItems(1)
    RepairAllItems()
  else
    RepairAllItems()
  end

  local playerMoneyAfter = tonumber(GetMoney())
  local playerSpent = 0

  if playerMoneyBefore and playerMoneyAfter and playerMoneyBefore > playerMoneyAfter then
    playerSpent = playerMoneyBefore - playerMoneyAfter
  end

  if q.autoRepairShowSummary == true then
    C_Timer.After(0, function()
      local source = "personal funds"
      local guildRemainingAfter = guildRepairAllowed and GetGuildRepairRemaining() or nil

      if guildRepairAllowed then
        local guildSpent = 0

        if guildRemainingBefore and guildRemainingAfter and guildRemainingBefore >= 0 and guildRemainingAfter >= 0 and guildRemainingBefore > guildRemainingAfter then
          guildSpent = guildRemainingBefore - guildRemainingAfter
        elseif playerSpent > 0 and playerSpent < repairCost then
          guildSpent = repairCost - playerSpent
        elseif playerSpent <= 0 then
          guildSpent = repairCost
        end

        if guildSpent > 0 and playerSpent > 0 then
          source = "guild funds and personal funds"
        elseif guildSpent > 0 then
          source = "guild funds"
        end
      end

      local msg = "Repaired from " .. source .. " for " .. FormatCoinText(repairCost) .. "."

      if guildRepairAllowed and guildRemainingAfter ~= nil then
        if guildRemainingAfter < 0 then
          msg = msg .. " Guild repair funds left: unlimited."
        else
          msg = msg .. " Guild repair funds left: " .. FormatCoinText(guildRemainingAfter) .. "."
        end
      end

      Addon:Print(msg)
    end)
  end

  PlayRepairCoinSound()
end

local function Merchant_ProcessAutoSell(q, token)
  if token ~= MerchantActionToken then
    return
  end

  if not q.autoSellJunk then
    return
  end

  if not MerchantFrame or not MerchantFrame:IsVisible() then
    return
  end

  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
        local _, _, _, _, _, itemClassID = C_Item.GetItemInfoInstant(info.itemID)
        if itemClassID and itemClassID ~= Enum.ItemClass.Weapon and itemClassID ~= Enum.ItemClass.Armor then
          C_Container.UseContainerItem(bag, slot)
        end
      end
    end
  end
end

local function EnsureMerchantDriver()
  if MerchantFrameDriver then return MerchantFrameDriver end

  local f = CreateFrame("Frame", "PleebUI_QualityMerchant")
  MerchantFrameDriver = f
  f:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_CLOSED" then
      MerchantActionToken = MerchantActionToken + 1
      return
    end

    if Merchant_ShouldSkipAutomation() then
      return
    end

    MerchantActionToken = MerchantActionToken + 1
    local token = MerchantActionToken
    local q = GetQ()

    Merchant_ProcessAutoRepair(q, token)
    Merchant_ProcessAutoSell(q, token)
  end)

  function f:RefreshState()
    local q = GetQ()
    self:UnregisterAllEvents()

    if q.autoRepair or q.autoSellJunk then
      self:RegisterEvent("MERCHANT_SHOW")
      self:RegisterEvent("MERCHANT_CLOSED")
    else
      MerchantActionToken = MerchantActionToken + 1
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

    for bag = 0, 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local id = C_Container.GetContainerItemID(bag, slot)
        if id and C_Item.IsItemKeystoneByID(id) then
          C_Container.UseContainerItem(bag, slot)
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

    if not TrustedUnits_IsTrusted(
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
  f:SetScript("OnEvent", function()
    local q = GetQ()
    if not q.easyItemDestroy then return end

    StaticPopup1EditBox:Hide()
    StaticPopup1Button1:Enable()
  end)

  function f:RefreshState()
    local q = GetQ()
    self:UnregisterAllEvents()

    if q.easyItemDestroy then
      self:RegisterEvent("DELETE_ITEM_CONFIRM")
    end
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

local CursorRing
local CursorRingScale = UIParent:GetEffectiveScale()
local CursorRingClicking = false
local CursorRingCachedShowOutline = true

local function CursorRing_SyncScale()
  CursorRingScale = UIParent:GetEffectiveScale()

  if CursorRing then
    CursorRing.__puiLastCursorX = nil
    CursorRing.__puiLastCursorY = nil
  end
end

local function CursorRing_UpdateClickOutline()
  local f = CursorRing
  if not f then return end

  CursorRingClicking = CursorRingCachedShowOutline
    and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
    or false

  if f.__puiCursorRingOutlineShown ~= CursorRingClicking then
    f.__puiCursorRingOutlineShown = CursorRingClicking
    f.Outline:SetShown(CursorRingClicking)
  end
end

local function EnsureCursorRing()
  if CursorRing then return CursorRing end

  local f = CreateFrame("Frame", "PleebUI_CursorRing", UIParent)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:SetSize(1, 1)
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)

  -- Never participate in input.
  if f.EnableMouse then f:EnableMouse(false) end
  if f.EnableMouseWheel then f:EnableMouseWheel(false) end
  if f.SetMouseClickEnabled then f:SetMouseClickEnabled(false) end
  if f.SetMouseMotionEnabled then f:SetMouseMotionEnabled(false) end
  if f.EnableKeyboard then f:EnableKeyboard(false) end
  if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end

  local texPath = [[Interface\AddOns\PleebUI\Media\Textures\Pleebring.tga]]

  f.Outline = f:CreateTexture(nil, "BACKGROUND")
  f.Outline:SetPoint("CENTER")
  f.Outline:SetTexture(texPath)
  f.Outline:Hide()

  f.Ring = f:CreateTexture(nil, "OVERLAY")
  f.Ring:SetPoint("CENTER")
  f.Ring:SetTexture(texPath)

  f:SetScript("OnEvent", function(_, event)
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
      CursorRing_SyncScale()
    else
      CursorRing_UpdateClickOutline()
    end
  end)

  CursorRing = f
  return f
end

local function CursorRing_Apply()
  local q = NormalizeDB()
  local f = EnsureCursorRing()

  q.cursorRingSize = Clamp(q.cursorRingSize or 26, 8, 128)
  q.cursorRingOutlineSize = Clamp(q.cursorRingOutlineSize or 10, 0, 128)

  q.cursorRingColor = q.cursorRingColor or { r = 1, g = 1, b = 1, a = 0.55 }
  q.cursorRingOutlineColor = q.cursorRingOutlineColor or { r = 1, g = 1, b = 1, a = 0.35 }
  if q.cursorRingShowOutline == nil then q.cursorRingShowOutline = true end
  if q.cursorRingShowInner == nil then q.cursorRingShowInner = true end

  local ringSize = Round(q.cursorRingSize)
  f:SetSize(ringSize, ringSize)
  f.Ring:SetSize(ringSize, ringSize)
  f.Ring:SetVertexColor(q.cursorRingColor.r, q.cursorRingColor.g, q.cursorRingColor.b, q.cursorRingColor.a)
  f.Ring:SetShown(not not q.cursorRingShowInner)

  local outSz = Round(q.cursorRingSize + q.cursorRingOutlineSize)
  f.Outline:SetSize(outSz, outSz)
  f.Outline:SetVertexColor(q.cursorRingOutlineColor.r, q.cursorRingOutlineColor.g, q.cursorRingOutlineColor.b, q.cursorRingOutlineColor.a)

  CursorRingCachedShowOutline = not not q.cursorRingShowOutline
end

local function CursorRing_OnUpdate()
  local f = CursorRing
  local x, y = GetCursorPosition()

  if x == f.__puiLastCursorX and y == f.__puiLastCursorY then
    return
  end

  f.__puiLastCursorX = x
  f.__puiLastCursorY = y
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / CursorRingScale, y / CursorRingScale)
end

local function ApplyCursorRing(enabled)
  local f = EnsureCursorRing()

  f:UnregisterAllEvents()

  if enabled then
    CursorRing_Apply()
    CursorRing_SyncScale()

    f.__puiCursorRingOutlineShown = nil
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:RegisterEvent("GLOBAL_MOUSE_UP")
    f:RegisterEvent("UI_SCALE_CHANGED")
    f:RegisterEvent("DISPLAY_SIZE_CHANGED")
    f:SetScript("OnUpdate", CursorRing_OnUpdate)
    f:Show()

    CursorRing_OnUpdate()
    CursorRing_UpdateClickOutline()
  else
    f:SetScript("OnUpdate", nil)
    f.Outline:Hide()
    f.__puiCursorRingOutlineShown = nil
    f:Hide()
    CursorRingClicking = false
  end
end

----
-- Crosshair (screen center)
----
local Crosshair

local function EnsureCrosshair()
  if Crosshair then return Crosshair end

  local f = CreateFrame("Frame", "PleebUI_Crosshair", UIParent)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:SetAllPoints(UIParent)

  -- Fullscreen visual only, never capture mouse.
  if f.EnableMouse then f:EnableMouse(false) end
  if f.EnableMouseWheel then f:EnableMouseWheel(false) end
  if f.SetMouseClickEnabled then f:SetMouseClickEnabled(false) end
  if f.SetMouseMotionEnabled then f:SetMouseMotionEnabled(false) end

  local function MakeLine(layer)
    local t = f:CreateTexture(nil, layer)
    t:SetTexture([[Interface\Buttons\WHITE8x8]])
    t:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    return t
  end

  f.H = MakeLine("OVERLAY")
  f.V = MakeLine("OVERLAY")

  Crosshair = f
  return f
end

local function Crosshair_Apply()
  local q = NormalizeDB()
  local f = EnsureCrosshair()

  q.crosshairLength = Clamp(q.crosshairLength or 10, 2, 100)
  q.crosshairThickness = Clamp(q.crosshairThickness or 1, 1, 10)
  q.crosshairColor = q.crosshairColor or { r = 1, g = 1, b = 1, a = 0.35 }

  local lineLength = Round(q.crosshairLength * 2)
  local lineThickness = Round(q.crosshairThickness)

  f.H:ClearAllPoints()
  f.H:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f.H:SetSize(lineLength, lineThickness)

  f.V:ClearAllPoints()
  f.V:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f.V:SetSize(lineThickness, lineLength)

  f.H:SetVertexColor(q.crosshairColor.r, q.crosshairColor.g, q.crosshairColor.b, q.crosshairColor.a)
  f.V:SetVertexColor(q.crosshairColor.r, q.crosshairColor.g, q.crosshairColor.b, q.crosshairColor.a)
end

local function ApplyCrosshair(enabled)
  local f = EnsureCrosshair()
  if enabled then
    Crosshair_Apply()
    f:Show()
  else
    f:Hide()
  end
end

----
-- Pet warning helpers
----
local PET_HEAL_WARN_HUNTER_SPELL_ID = 136
local PET_HEAL_WARN_WARLOCK_SPELL_ID = 755
local PET_HEAL_WARN_THROTTLE = 0.20

local PetHealWarnCurve
local PetHealWarnCurveThreshold
local PetHealWarnNextUpdate = 0

local function IsHealPetClass()
  local _, class = UnitClass("player")
  return class == "HUNTER" or class == "WARLOCK", class
end

local function GetHealPetSpellID()
  local ok, class = IsHealPetClass()
  if not ok then
    return nil
  end

  if class == "HUNTER" then
    return PET_HEAL_WARN_HUNTER_SPELL_ID
  end

  return PET_HEAL_WARN_WARLOCK_SPELL_ID
end

local function BuildPetHealWarnCurve()
  local q = GetQ()
  local threshold = Clamp(q.petHealWarningThreshold or 50, 10, 50) / 100
  if PetHealWarnCurve and PetHealWarnCurveThreshold == threshold then
    return
  end

  local epsilon = 0.0001

  PetHealWarnCurve = C_CurveUtil.CreateColorCurve()
  PetHealWarnCurveThreshold = threshold
  PetHealWarnCurve:SetType(Enum.LuaCurveType.Step)
  PetHealWarnCurve:AddPoint(0.00, CreateColor(1, 1, 1, 1))
  PetHealWarnCurve:AddPoint(threshold, CreateColor(1, 1, 1, 1))
  PetHealWarnCurve:AddPoint(math.min(1.00, threshold + epsilon), CreateColor(1, 1, 1, 0))
  PetHealWarnCurve:AddPoint(1.00, CreateColor(1, 1, 1, 0))
end

----
-- Missing Pet warning (pet dead / missing + pet not attacking)
----
local PetWarnFrame
local PetWarnText
local PetWarnReadyCheckActive = false

local PetWarnClasses = {
  HUNTER = true,
  WARLOCK = true,
  DEATHKNIGHT = true,
  MAGE = true,
}

local function IsPetClass()
  local _, class = UnitClass("player")
  if not (class and PetWarnClasses[class]) then
    return false
  end

  -- Mage: only warn if the player actually knows Summon Water Elemental.
  if class == "MAGE" then
    return IsPlayerSpell(31687)
  end

  -- Marksmanship Hunter should not be warned (Lone Wolf playstyle).
  if class == "HUNTER" then
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)

    if specID == 254 then
      return false
    end
  end

  return true
end

function Quality:IsPetWarningAvailable()
  return IsPetClass() or IsHealPetClass()
end

function Quality:GetQuickSetupValue(key)
  local q = GetQ()
  return not not q[key]
end

function Quality:SetQuickSetupValue(key, value, deferApply)
  local q = GetQ()
  q[key] = not not value

  if not deferApply then
    Addon:ApplyOptionsChange("Quality", {})
  end

  return q
end


local function EnsurePetWarnFrame()
  if PetWarnFrame then return PetWarnFrame end

  local f = CreateFrame("Frame", "PleebUI_PetWarning", UIParent)
  PetWarnFrame = f
  f:SetSize(350, 50)
  f:SetFrameStrata("LOW")
  f:SetFrameLevel(1)
  f:EnableMouse(false)
  f:Hide()

  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  PetWarnText = fs
  fs:SetPoint("CENTER", f, "CENTER", 0, 0)
  fs:SetJustifyH("CENTER")
  fs:SetText("")

  local q = NormalizeDB()
  local d = QUALITY_POSITION_DEFAULTS.petWarning
  q.petWarningAnchor = SeedAnchorDefaults(q.petWarningAnchor, d)
  f:SetPoint("CENTER", UIParent, "CENTER", q.petWarningAnchor.x or d.x, q.petWarningAnchor.y or d.y)

  ns.FrameUtil:RegisterMover("quality_pet_warning", f, {
    label = "Pet Warning",
    optionsString = "Quality,qualityTab",
    savePosition = function()
      SaveMoverPosition(f, "petWarningAnchor")
    end,
    resetPosition = function()
      local qq = NormalizeDB()
      local d = QUALITY_POSITION_DEFAULTS.petWarning
      qq.petWarningAnchor = SeedAnchorDefaults(nil, d)
      f:ClearAllPoints()
      f:SetPoint("CENTER", UIParent, "CENTER", d.x, d.y)
    end,
    quickSettings = function()
      local qq = NormalizeDB()
      return {
        ownerKey = "quality_pet_warning",
        title = "Pet Warning",
        description = "Live pet warning settings.",
        controls = {
          {
            type = "slider",
            label = "Font size",
            min = 5,
            max = 100,
            step = 1,
            get = function() return qq.petHealWarningFontSize end,
            set = function(value)
              qq.petHealWarningFontSize = Clamp(value, 5, 100)

              if PetWarnFrame then
                PetWarnFrame.__puiPetWarnBaseFontSize = qq.petHealWarningFontSize
              end

              PetWarnText:SetFont(
                STANDARD_TEXT_FONT,
                ns.Theme.ResolveFontSize(qq.petHealWarningFontSize, "qualityOfLife"),
                "OUTLINE"
              )
            end,
          },
        },
      }
    end,
  })

  return f
end

local function PetWarn_Hide()
  if PetWarnFrame and PetWarnFrame:IsShown() then
    PetWarnFrame:SetAlpha(0)
    PetWarnFrame:Hide()
  end
end

local function PetWarn_Show(msg, opts)
  local f = EnsurePetWarnFrame()
  local size = 20

  if opts and opts.fontSize then
    size = Clamp(opts.fontSize, 5, 100)
  end

  local color = opts and opts.color or nil
  local r = color and tonumber(color.r or color[1]) or 1
  local g = color and tonumber(color.g or color[2]) or 1
  local b = color and tonumber(color.b or color[3]) or 1
  local a = color and tonumber(color.a or color[4]) or 1
  local iconOnly = opts and opts.iconOnly == true or false
  local showIcon = opts and opts.showIcon == true or false
  local icon = opts and opts.icon or nil
  local message = tostring(msg or "")

  if f:IsShown()
    and f.__puiPetWarnMessage == message
    and f.__puiPetWarnFontSize == size
    and f.__puiPetWarnColorR == r
    and f.__puiPetWarnColorG == g
    and f.__puiPetWarnColorB == b
    and f.__puiPetWarnColorA == a
    and f.__puiPetWarnIconOnly == iconOnly
    and f.__puiPetWarnShowIcon == showIcon
    and f.__puiPetWarnIcon == icon
  then
    return
  end

  f.__puiPetWarnMessage = message
  f.__puiPetWarnFontSize = size
  f.__puiPetWarnBaseFontSize = size
  f.__puiPetWarnColorR = r
  f.__puiPetWarnColorG = g
  f.__puiPetWarnColorB = b
  f.__puiPetWarnColorA = a
  f.__puiPetWarnIconOnly = iconOnly
  f.__puiPetWarnShowIcon = showIcon
  f.__puiPetWarnIcon = icon

  PetWarnText:SetFont(
    STANDARD_TEXT_FONT,
    ns.Theme.ResolveFontSize(size, "qualityOfLife"),
    "OUTLINE"
  )
  PetWarnText:SetTextColor(r, g, b, a)

  if iconOnly and icon then
    message = string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(icon), size, size)
  elseif showIcon and icon then
    message = string.format("%s |T%s:%d:%d:0:0:64:64:5:59:5:59|t", message, tostring(icon), size, size)
  end

  PetWarnText:SetText(message)

  f:SetSize((PetWarnText:GetStringWidth() or 300) + 40, (PetWarnText:GetStringHeight() or 30) + 20)

  local q = GetQ()
  if q.petWarningAnchor then
    local d = QUALITY_POSITION_DEFAULTS.petWarning
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", q.petWarningAnchor.x or d.x, q.petWarningAnchor.y or d.y)
  end

  f:SetAlpha(1)
  f:Show()
end

local function IsDragonridingActive()
  return IsMounted() and IsFlying() and IsAdvancedFlyableArea()
end

local function PetWarn_ShouldHideForDragonriding(q)
  return q.hidePetWarningWhileDragonriding and IsDragonridingActive()
end

local function PetWarn_GetPetState()
  local hasPet = UnitExists("pet")
  local petDead = hasPet and UnitIsDead("pet")
  return hasPet, petDead
end

local function PetWarn_CheckMissingPet(q, hasPet, petDead)
  if not q.missingPetWarning then
    return false
  end

  if not IsPetClass() then
    return false
  end

  local _, class = UnitClass("player")
  if class ~= "HUNTER" then
    if not hasPet or petDead then
      PetWarn_Show(petDead and "***DEAD PET***" or "***SUMMON PET***")
      return true
    end
    return false
  end

  if petDead then
    if UnitAffectingCombat("player") then
      PetWarn_Show("PET DIED", {
        fontSize = q.petDeadWarningFontSize or 52,
        color = q.petDeadWarningColor,
      })
    else
      PetWarn_Show("DEAD PET", {
        fontSize = q.petMissingWarningFontSize or 34,
        color = q.petMissingWarningColor,
      })
    end
    return true
  end

  if not hasPet then
    PetWarn_Show(PetWarnReadyCheckActive and "NO PET" or "SUMMON PET", {
      fontSize = q.petMissingWarningFontSize or 34,
      color = q.petMissingWarningColor,
    })
    return true
  end

  return false
end

local function PetWarn_CheckPetNotAttacking(q, hasPet, petDead)
  if not q.missingPetWarning then
    return false
  end

  if IsHealPetClass() then
    return false
  end

  if not IsPetClass() then
    return false
  end

  if not hasPet or petDead then
    return false
  end

  if not InCombatLockdown() or not UnitAffectingCombat("player") then
    return false
  end

  if not UnitExists("pettarget") and not UnitAffectingCombat("pet") then
    PetWarn_Show("***PET NOT ATTACKING***")
    return true
  end

  return false
end

local function PetWarn_CheckHealPet(q, hasPet, petDead)
  if not hasPet or petDead then
    return false
  end

  local healClassOK, class = IsHealPetClass()
  if not healClassOK then
    return false
  end

  local hpColor = UnitHealthPercent("pet", true, PetHealWarnCurve)
  local _, _, _, hpAlpha = hpColor:GetRGBA()
  local spellID = GetHealPetSpellID()
  local icon = spellID and C_Spell.GetSpellTexture(spellID) or nil

  PetWarn_Show(q.petHealWarningText or "Heal Pet", {
    fontSize = q.petHealWarningFontSize or 20,
    color = class == "HUNTER" and q.petLowHealthWarningColor or nil,
    showIcon = not not q.petHealWarningShowIcon,
    iconOnly = not not q.petHealWarningIconOnly,
    icon = icon,
  })

  if PetWarnFrame then
    PetWarnFrame:SetAlpha(hpAlpha or 0)
  end

  return true
end

local function PetWarn_Check()
  local q = GetQ()

  if not q.petWarningsEnabled then
    PetWarn_Hide()
    return
  end

  if PetWarn_ShouldHideForDragonriding(q) then
    PetWarn_Hide()
    return
  end

  local hasPet, petDead = PetWarn_GetPetState()

  if PetWarn_CheckMissingPet(q, hasPet, petDead) then
    return
  end

  if PetWarn_CheckPetNotAttacking(q, hasPet, petDead) then
    return
  end

  if PetWarn_CheckHealPet(q, hasPet, petDead) then
    return
  end

  PetWarn_Hide()
end

local PetWarnEvents
local function EnsurePetWarnEvents()
  if PetWarnEvents then return PetWarnEvents end

  local f = CreateFrame("Frame", "PleebUI_QualityPetWarnEvents")
  PetWarnEvents = f

  f:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET"
      and unit
      and unit ~= "player"
    then
      return
    end

    if (
      event == "UNIT_FLAGS"
      or event == "UNIT_TARGET"
      or event == "UNIT_HEALTH"
    ) and unit ~= "pet"
    then
      return
    end

    if event == "READY_CHECK" then
      PetWarnReadyCheckActive = true
    elseif event == "READY_CHECK_FINISHED" then
      PetWarnReadyCheckActive = false
    elseif event == "PLAYER_ENTERING_WORLD" then
      PetWarnReadyCheckActive = false
    end

    if event == "UNIT_HEALTH" then
      local now = GetTime()

      if now < PetHealWarnNextUpdate then
        return
      end

      PetHealWarnNextUpdate =
        now + PET_HEAL_WARN_THROTTLE
    end

    if event == "PLAYER_TALENT_UPDATE"
      or event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "TRAIT_CONFIG_UPDATED"
      or event == "TRAIT_CONFIG_LIST_UPDATED"
    then
      C_Timer.After(0, PetWarn_Check)
      return
    end

    PetWarn_Check()
  end)

  function f:RefreshState()
    local q = GetQ()

    self:UnregisterAllEvents()

    if q.petWarningsEnabled
      and (
        q.missingPetWarning
        or IsPetClass()
        or IsHealPetClass()
      )
    then
      self:RegisterEvent("PLAYER_ENTERING_WORLD")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
      self:RegisterEvent("PLAYER_TALENT_UPDATE")
      self:RegisterEvent("TRAIT_CONFIG_UPDATED")
      self:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
      self:RegisterEvent("UNIT_PET")
      self:RegisterEvent("PET_BAR_UPDATE")
      self:RegisterEvent("READY_CHECK")
      self:RegisterEvent("READY_CHECK_FINISHED")

      self:RegisterUnitEvent("UNIT_FLAGS", "pet")
      self:RegisterUnitEvent("UNIT_TARGET", "pet")
      self:RegisterUnitEvent("UNIT_HEALTH", "pet")
    else
      PetWarnReadyCheckActive = false
      PetHealWarnNextUpdate = 0
    end
  end

  return f
end

local function ApplyPetWarnings()
  BuildPetHealWarnCurve()

  local f = EnsurePetWarnEvents()
  f:RefreshState()

  PetWarn_Check()
end

local AuctionHouseQoLFrame

local function AuctionHouse_ApplyCurrentExpansionOnly()
  local defaultFilters = _G.AUCTION_HOUSE_DEFAULT_FILTERS
  if not defaultFilters then
    return false
  end

  local filter = Enum.AuctionHouseFilter.CurrentExpansionOnly
  local enabled = GetQ().auctionHouseCurrentExpansionOnly == true
  defaultFilters[filter] = enabled

  local searchBar = _G.AuctionHouseFrame and _G.AuctionHouseFrame.SearchBar
  local filterButton = searchBar and searchBar.FilterButton
  if filterButton and filterButton.filters then
    filterButton.filters[filter] = enabled

    if searchBar.UpdateClearFiltersButton then
      searchBar:UpdateClearFiltersButton()
    end
  end

  return true
end

local function EnsureAuctionHouseCurrentExpansionOnly()
  if AuctionHouseQoLFrame then
    return AuctionHouseQoLFrame
  end

  local f = CreateFrame("Frame", "PleebUI_QualityAuctionHouseCurrentExpansionOnly")
  AuctionHouseQoLFrame = f
  f:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Blizzard_AuctionHouseUI" then
      return
    end

    if AuctionHouse_ApplyCurrentExpansionOnly() then
      self:UnregisterEvent("ADDON_LOADED")
    end
  end)

  function f:RefreshState()
    self:UnregisterAllEvents()

    if not AuctionHouse_ApplyCurrentExpansionOnly() then
      self:RegisterEvent("ADDON_LOADED")
    end
  end

  return f
end

local function ApplyAuctionHouseCurrentExpansionOnly()
  EnsureAuctionHouseCurrentExpansionOnly():RefreshState()
end

function Quality:RefreshFonts()
  if not PetWarnText then
    return
  end

  local q = GetQ()
  local baseSize = PetWarnFrame and PetWarnFrame.__puiPetWarnBaseFontSize or q.petHealWarningFontSize or 20

  PetWarnText:SetFont(
    STANDARD_TEXT_FONT,
    ns.Theme.ResolveFontSize(baseSize, "qualityOfLife"),
    "OUTLINE"
  )
end


function Quality:ApplyAll()
  local q = RefreshQ()

  EnsureCombatMsgFrame():RefreshState()
  EnsureCombatTimerEvents():RefreshState()
  EnsureCombatWarningEvents():RefreshState()
  EnsureLootFrame():RefreshState()
  EnsureMerchantDriver():RefreshState()
  EnsureKeystoneDriver():RefreshState()
  EnsureInviteDriver():RefreshState()
  EnsureRoleCheckDriver():RefreshState()
  EnsureDestroyDriver():RefreshState()

  ApplyMovieSkip(not not q.fasterMovieSkip)
  ApplyHideTalkingHead(not not q.hideTalkingHead)
  ApplyHideRestedZzz(not not q.hideRestedZzz)
  ApplyMaxCameraZoom(not not q.maxCameraZoom)
  ApplySuppressGuildAchievementToasts(not not q.suppressGuildAchievementToasts)

  ns.UFAuraFilters.ApplyAuraSpellIDTooltipPreference(q.showAuraSpellIDs == true)

  ApplyHideElements()

  ApplyPetWarnings()
  ApplyAuctionHouseCurrentExpansionOnly()

  local raidUtilityModule = ns.RaidUtilityModule
  raidUtilityModule.ApplyAll()

  ApplyCrosshair(not not q.crosshair)
  ApplyCursorRing((not not q.cursorRingShowInner) or (not not q.cursorRingShowOutline))

  CVarSetSafe("autoLootDefault", q.autoLoot == true)
end

local function QualityProvider(AddonObj)
  local provider = {}

  function provider:GetOptions()
    local raidUtilityModule = ns.RaidUtilityModule
    local function GetQ()
      return NormalizeDB()
    end

    local function RequestApply(flags)
      AddonObj:ApplyOptionsChange("Quality", flags or {})
    end

    local function RefreshQualityOptions()
      C_Timer.After(0, function()
        AddonObj:NotifyOptionsTreeChanged("Quality", { "Quality", "qualityTab" })
      end)
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

    local function RangeOption(label, key, minV, maxV, step, order, disabledFunc)
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
          RequestApply()
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

    local function ColorOption(label, key, order, disabledFunc)
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

      return opt
    end

    return {
      type = "group",
      name = "Quality of Life",
      order = 15,
      childGroups = "tab",
      args = {
        qualityTab = {
          type = "group",
          name = "Visual helpers",
          order = 1,
          args = {
            combatWarnings = {
              type = "group",
              name = "Combat warnings",
              order = 5,
              inline = true,
              args = {
                combatWarningsHelp = DescriptionOption("Only shown during combat in a raid instance or active Mythic+ key.", 1),
                noTargetWarning = ToggleOption("No target", "noTargetWarning", 2),
                notAttackingWarning = ToggleOption("Not attacking (melee)", "notAttackingWarning", 3),
                combatWarningFontSize = RangeOption("Warning size", "combatWarningFontSize", 16, 60, 1, 4),
              },
            },
            petWarnings = {
              type = "group",
              name = "Pet warnings",
              order = 10,
              inline = true,
              args = {
                petWarningsEnabled = ToggleOption("Enable pet warnings", "petWarningsEnabled", 1),
                missingPetWarning = ToggleOption("Missing or idle pet", "missingPetWarning", 2, nil, DisabledWhenOff("petWarningsEnabled")),
                hidePetWarningWhileDragonriding = ToggleOption("Hide while skyriding", "hidePetWarningWhileDragonriding", 3, nil, DisabledWhenOff("petWarningsEnabled")),
                petHealWarningThreshold = RangeOption("Low health threshold", "petHealWarningThreshold", 10, 50, 1, 4, DisabledWhenOff("petWarningsEnabled")),
                petHealWarningFontSize = RangeOption("Low health size", "petHealWarningFontSize", 5, 100, 1, 5, DisabledWhenOff("petWarningsEnabled")),
                petLowHealthWarningColor = ColorOption("Low health color", "petLowHealthWarningColor", 6, DisabledWhenOff("petWarningsEnabled")),
                petHealWarningShowIcon = ToggleOption("Show heal icon", "petHealWarningShowIcon", 7, nil, DisabledWhenOff("petWarningsEnabled")),
                petHealWarningIconOnly = ToggleOption("Icon only", "petHealWarningIconOnly", 8, nil, DisabledWhenOff("petWarningsEnabled")),
                petHealWarningText = InputOption("Low health text", "petHealWarningText", 9, DisabledWhenOff("petWarningsEnabled")),
                petMissingWarningFontSize = RangeOption("Missing pet size", "petMissingWarningFontSize", 10, 100, 1, 10, DisabledWhenOff("petWarningsEnabled")),
                petMissingWarningColor = ColorOption("Missing pet color", "petMissingWarningColor", 11, DisabledWhenOff("petWarningsEnabled")),
                petDeadWarningFontSize = RangeOption("Pet died size", "petDeadWarningFontSize", 10, 100, 1, 12, DisabledWhenOff("petWarningsEnabled")),
                petDeadWarningColor = ColorOption("Pet died color", "petDeadWarningColor", 13, DisabledWhenOff("petWarningsEnabled")),
              },
            },
            cursorRing = {
              type = "group",
              name = "Cursor ring",
              order = 20,
              inline = true,
              args = {
                cursorRingShowInner = ToggleOption("Show inner ring", "cursorRingShowInner", 1),
                cursorRingSize = RangeOption("Inner ring size", "cursorRingSize", 8, 128, 1, 2),
                cursorRingColor = ColorOption("Inner ring color", "cursorRingColor", 3),
                cursorRingShowOutline = ToggleOption("Show click ring", "cursorRingShowOutline", 4),
                cursorRingOutlineSize = RangeOption("Click ring size", "cursorRingOutlineSize", 0, 128, 1, 5),
                cursorRingOutlineColor = ColorOption("Click ring color", "cursorRingOutlineColor", 6),
              },
            },
            crosshairSettings = {
              type = "group",
              name = "Crosshair",
              order = 30,
              inline = true,
              args = {
                crosshairLength = RangeOption("Length", "crosshairLength", 2, 100, 1, 1),
                crosshairThickness = RangeOption("Thickness", "crosshairThickness", 1, 10, 1, 2),
                crosshairColor = ColorOption("Color", "crosshairColor", 3),
              },
            },
            battleResLust = raidUtilityModule.BuildBresLustOptions({
              ToggleOption = ToggleOption,
              RangeOption = RangeOption,
            }),
            raidUtility = raidUtilityModule.BuildRaidUtilityOptions({
              GetQ = GetQ,
              RequestApply = RequestApply,
              Clamp = Clamp,
            }),
          },
        },
        automationTab = {
          type = "group",
          name = "Automation",
          order = 2,
          args = {
            combat = {
              type = "group",
              name = "Combat",
              order = 10,
              inline = true,
              args = {
                combatMessage = ToggleOption("Combat status messages", "combatMessage", 1),
                combatTimer = ToggleOption("Combat timer", "combatTimer", 2),
              },
            },
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
                enableMPlusJournalTeleports = ToggleOption("Show teleports in the Mythic+ journal", "enableMPlusJournalTeleports", 2),
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
                autoAcceptRoleCheck = ToggleOption("Auto accept role checks", "autoAcceptRoleCheck", 1, RefreshQualityOptions),
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
                autoAcceptInvites = ToggleOption("Auto accept invites", "autoAcceptInvites", 1, RefreshQualityOptions),
                invitesHelp = DescriptionOption("Accept invites from:", 2, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteFriends = ToggleOption("Friends", "acceptInviteFriends", 3, nil, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteBattleNetFriends = ToggleOption("Battle.net friends", "acceptInviteBattleNetFriends", 4, nil, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteGuildMembers = ToggleOption("Guild members", "acceptInviteGuildMembers", 5, nil, DisabledWhenOff("autoAcceptInvites")),
                acceptInviteCommunityMembers = ToggleOption("Community members", "acceptInviteCommunityMembers", 6, nil, DisabledWhenOff("autoAcceptInvites")),
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
                crosshair = ToggleOption("Crosshair (screen center)", "crosshair", 5),
                showAuraSpellIDs = ToggleOption(
                  "Show aura spell IDs outside /pui",
                  "showAuraSpellIDs",
                  6,
                  function(_, value)
                    ns.UFAuraFilters.ApplyAuraSpellIDTooltipPreference(value == true)
                  end
                ),
              },
            },
          },
        },
      },
    }
  end

  return provider
end


Addon:RegisterOptionsSection("Quality", QualityProvider, 80, "Quality of Life", nil, {
  preview = false,
})



-- Fire once on login.
local Boot = CreateFrame("Frame", "PleebUI_QualityBoot")
Boot:RegisterEvent("PLAYER_ENTERING_WORLD")
Boot:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  Quality:ApplyAll()
end)
