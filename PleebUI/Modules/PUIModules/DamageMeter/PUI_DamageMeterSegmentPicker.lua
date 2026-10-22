local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local DamageMeters = ns.Modules.DamageMeters
local SegmentPicker = ns.DamageMeterSegmentPicker
local Config = ns.DamageMeterConfig
local Sessions = ns.DamageMeterSessions
local Windows = ns.DamageMeterWindows
local History = ns.DamageMeterHistory
local Constants = ns.DamageMeterConstants
local P = ns.DamageMeterProfiler

local _G = _G
local UIParent = _G.UIParent
local C_DamageMeter = _G.C_DamageMeter
local CreateFrame = _G.CreateFrame
local DAMAGE_METER_COMBAT_NUMBER = _G.DAMAGE_METER_COMBAT_NUMBER
local GameTooltip = _G.GameTooltip
local Menu = _G.Menu
local MenuUtil = _G.MenuUtil
local math_max = _G.math.max
local math_min = _G.math.min
local string_format = _G.string.format
local table_concat = _G.table.concat
local table_sort = _G.table.sort
local FormatDuration = Sessions.FormatDuration

function SegmentPicker.BuildRunMetadata(saved, runType)
  local parts = { runType }
  if saved.practiceRun == true then
    parts[#parts + 1] = "Practice"
  elseif saved.onTime == true then
    parts[#parts + 1] = "Timed"
  elseif saved.onTime == false then
    parts[#parts + 1] = "Over time"
  end
  if type(saved.numDeaths) == "number" and saved.numDeaths > 0 then
    parts[#parts + 1] = saved.numDeaths .. " deaths"
  end
  if saved.isMapRecord == true or saved.isAffixRecord == true then
    parts[#parts + 1] = "Record"
  end
  local dateText = SegmentPicker.FormatDate(saved.completedAt)
  if dateText then
    parts[#parts + 1] = dateText
  end
  return table_concat(parts, " · ")
end

function SegmentPicker.BuildRunDetailMetadata(saved)
  local parts = {}
  if saved.practiceRun == true then
    parts[#parts + 1] = "Practice"
  elseif saved.onTime == true then
    if type(saved.keystoneUpgradeLevels) == "number"
      and saved.keystoneUpgradeLevels > 0
    then
      parts[#parts + 1] = "Timed +" .. saved.keystoneUpgradeLevels
    else
      parts[#parts + 1] = "Timed"
    end
  elseif saved.onTime == false then
    parts[#parts + 1] = "Over time"
  end

  if type(saved.numDeaths) == "number" then
    parts[#parts + 1] = saved.numDeaths == 1
      and "1 death"
      or saved.numDeaths .. " deaths"
  end

  return table_concat(parts, " · ")
end

local function FormatScore(value)
  if type(value) ~= "number" then
    return nil
  end

  local text = string_format("%.1f", value)
  text = text:gsub("%.0$", "")
  return text
end

function SegmentPicker.ShowRunSummaryTooltip(row, saved)
  if not row or not saved then
    return
  end

  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(saved.name or "Completed keystone")

  local resultText = SegmentPicker.BuildRunDetailMetadata(saved)
  if resultText ~= "" then
    GameTooltip:AddLine(resultText, 1, 1, 1)
  end

  local runTime = saved.runTime or saved.timeInCombat
  if type(runTime) == "number" and runTime > 0 then
    GameTooltip:AddDoubleLine(
      "Run time",
      FormatDuration(runTime),
      0.78,
      0.78,
      0.78,
      1,
      1,
      1
    )
  end

  if type(saved.numDeaths) == "number" then
    local deathText = saved.numDeaths == 1
      and "1 death"
      or saved.numDeaths .. " deaths"
    if type(saved.deathTimeLost) == "number" and saved.deathTimeLost > 0 then
      deathText = deathText .. " · " .. FormatDuration(saved.deathTimeLost) .. " lost"
    end
    GameTooltip:AddLine(deathText, 0.85, 0.85, 0.85)
  end

  local oldScore = type(saved.oldOverallDungeonScore) == "number"
    and saved.oldOverallDungeonScore
    or saved.scoreBefore
  local newScore = saved.newOverallDungeonScore
  if type(oldScore) == "number" and type(newScore) == "number" then
    local delta = newScore - oldScore
    local deltaText = FormatScore(delta)
    if delta > 0 then
      deltaText = "+" .. deltaText
    end
    GameTooltip:AddDoubleLine(
      "Score",
      FormatScore(oldScore) .. " → " .. FormatScore(newScore) .. " (" .. deltaText .. ")",
      0.78,
      0.78,
      0.78,
      1,
      1,
      1
    )
  elseif type(newScore) == "number" then
    GameTooltip:AddDoubleLine(
      "Score",
      FormatScore(newScore),
      0.78,
      0.78,
      0.78,
      1,
      1,
      1
    )
  end

  if saved.isEligibleForScore == false then
    GameTooltip:AddLine("Not eligible for score", 0.78, 0.78, 0.78)
  end

  local recordParts = {}
  if saved.isMapRecord == true then
    recordParts[#recordParts + 1] = "Map record"
  end
  if saved.isAffixRecord == true then
    recordParts[#recordParts + 1] = "Affix record"
  end
  if #recordParts > 0 then
    GameTooltip:AddLine(table_concat(recordParts, " · "), 1, 0.82, 0)
  end

  local dateText = SegmentPicker.FormatDate(saved.completedAt)
  if dateText then
    GameTooltip:AddDoubleLine(
      "Completed",
      dateText,
      0.78,
      0.78,
      0.78,
      1,
      1,
      1
    )
  end

  local members = saved.members
  if type(members) == "table" and #members > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Group", 1, 1, 1)
    for index = 1, #members do
      local member = members[index]
      if member and type(member.name) == "string" and member.name ~= "" then
        GameTooltip:AddLine(member.name, 0.85, 0.85, 0.85)
      end
    end
  end

  GameTooltip:Show()
end

local Clamp = ns.DamageMeterUtil.Clamp
local GetWindowDB = Config.GetWindowDB
local GetWindowSelection = Sessions.GetWindowSelection
local WindowSelectionsEqual = Sessions.WindowSelectionsEqual
local SelectWindowSegment = Windows.SelectWindowSegment
local PAD_LOCKED_TEXTURE = Constants.PAD_LOCKED_TEXTURE
local PAD_UNLOCKED_TEXTURE = Constants.PAD_UNLOCKED_TEXTURE
local TRASH_TEXTURE = Constants.TRASH_TEXTURE

local function ContextMenuButtonHandlesGlobalMouseEvent(button, buttonName, event)
  if event ~= "GLOBAL_MOUSE_DOWN" or buttonName ~= "LeftButton" then
    return false
  end

  local openMenu = Menu.GetManager():GetOpenMenu()
  return openMenu ~= nil and openMenu.ownerRegion == button
end

local function ToggleContextMenu(owner, generator)
  local menuManager = Menu.GetManager()
  local openMenu = menuManager:GetOpenMenu()
  if openMenu and openMenu.ownerRegion == owner then
    menuManager:CloseMenu(openMenu)
    return
  end

  MenuUtil.CreateContextMenu(owner, generator)
end

local function ConfirmClearUnsavedSegments()
  Addon:PUI_ConfirmAction({
    title = "Clear unsaved segments?",
    text = "Clear every unsaved PleebUI segment and reset Blizzard's combat sessions?\n\nSaved bosses and keystones will be kept.",
    yesText = "Clear unsaved",
    noText = "Cancel",
    onYes = function()
      DamageMeters:ClearUnsavedCombatHistory()
    end,
  })
end


function SegmentPicker.FormatDate(timestamp)
  if type(timestamp) ~= "number" or timestamp <= 0 then
    return nil
  end

  return _G.date("%b %d · %H:%M", timestamp)
end

function SegmentPicker.BuildSegmentMetadata(segment, segmentType)
  local parts = {}
  if segment and type(segment.instanceName) == "string" and segment.instanceName ~= "" then
    parts[#parts + 1] = segment.instanceName
  end
  parts[#parts + 1] = segmentType
  if segment then
    local dateText = SegmentPicker.FormatDate(segment.endedAt)
    if dateText then
      parts[#parts + 1] = dateText
    end
  end
  return table_concat(parts, " · ")
end

function SegmentPicker.BuildSavedSegmentRow(
  segment,
  segmentType,
  ownerSection
)
  local row = {
    rowType = "ITEM",
    title = segment.displayName,
    metadata = SegmentPicker.BuildSegmentMetadata(segment, segmentType),
    duration = segment.durationSeconds,
    selection = {
      kind = "SEGMENT_SAVED",
      segmentID = segment.id,
    },
  }
  if ownerSection then
    row.recordType = "SEGMENT"
    row.recordID = segment.id
    row.canSave = true
    row.canDelete = true
    row.isSaved = segment.isSaved == true
  end
  return row
end

function SegmentPicker.BuildRows()
  local availableSessions = C_DamageMeter.GetAvailableCombatSessions()

  local killRows = {}
  local keystoneRows = {}
  local recentRows = {}

  local savedSegments = History:GetSavedSegments()
  for index = 1, #savedSegments do
    local segment = savedSegments[index]
    if type(segment.modelVersion) == "number" and segment.modelVersion >= 2 then
      if segment.isRetainedBossKill then
        local segmentType = "Dungeon boss"
        if segment.instanceType == "raid" then
          segmentType = "Raid boss"
        elseif segment.runID then
          segmentType = "M+ boss"
        end
        killRows[#killRows + 1] = SegmentPicker.BuildSavedSegmentRow(
          segment,
          segmentType,
          "BOSS_KILLS"
        )
      end
    end
  end

  local recentCount = #availableSessions
  for index = recentCount, 1, -1 do
    local sessionInfo = availableSessions[index]
    local sessionName = sessionInfo.name
    if type(sessionName) ~= "string" or sessionName == "" then
      sessionName = DAMAGE_METER_COMBAT_NUMBER:format(sessionInfo.sessionID)
    end

    local recency
    if index == recentCount then
      recency = "Newest"
    elseif index == 1 then
      recency = "Oldest"
    end

    recentRows[#recentRows + 1] = {
      rowType = "ITEM",
      title = sessionName,
      duration = sessionInfo.durationSeconds,
      recency = recency,
      selection = {
        kind = "SESSION_AVAILABLE",
        sessionID = sessionInfo.sessionID,
      },
    }
  end

  local savedDungeons = History:GetSavedDungeons()
  for index = 1, #savedDungeons do
    local saved = savedDungeons[index]
    if saved.modelVersion == 3
      or saved.modelVersion == 4
      or saved.modelVersion == 5
    then
      keystoneRows[#keystoneRows + 1] = {
        rowType = "ACTION",
        action = "OPEN_KEYSTONE",
        savedID = saved.id,
        runSummarySavedID = saved.id,
        title = saved.name,
        metadata = SegmentPicker.BuildRunMetadata(saved, "Completed keystone"),
        duration = saved.runTime or saved.timeInCombat,
        timestamp = saved.completedAt or 0,
        recordType = "DUNGEON",
        recordID = saved.id,
        canSave = true,
        canDelete = true,
        isSaved = saved.isSaved == true,
      }
    end
  end

  table_sort(keystoneRows, function(left, right)
    return left.timestamp > right.timestamp
  end)

  if #killRows == 0 then
    killRows[1] = { rowType = "INFO", title = "No bosses saved" }
  end
  if #keystoneRows == 0 then
    keystoneRows[1] = { rowType = "INFO", title = "No keystones saved" }
  end
  if #recentRows == 0 then
    recentRows[1] = { rowType = "INFO", title = "No Blizzard recent segments" }
  end
  return {
    BOSS_KILLS = killRows,
    KEYSTONES = keystoneRows,
    RECENT = recentRows,
  }
end

function SegmentPicker.BuildKeystoneDetailRows(savedID)
  local saved = History:FindSavedDungeon(savedID)
  if not saved then
    return {
      {
        rowType = "ACTION",
        action = "CLOSE_KEYSTONE",
        title = "All keystones",
        metadata = "Back to completed keystones",
      },
      { rowType = "INFO", title = "Keystone is no longer retained" },
    }, nil
  end

  local rows = {
    {
      rowType = "ACTION",
      action = "CLOSE_KEYSTONE",
      title = "All keystones",
      metadata = "Back to completed keystones",
    },
    {
      rowType = "ITEM",
      title = "Overall",
      metadata = SegmentPicker.BuildRunDetailMetadata(saved),
      duration = saved.runTime or saved.timeInCombat,
      runSummarySavedID = saved.id,
      selection = {
        kind = "DUNGEON_SAVED",
        savedID = saved.id,
        view = "OVERALL",
      },
    },
  }

  local data = History:GetSavedDungeonData(saved)
  local segments = data and data.segments or {}
  for index = 1, #segments do
    local segment = segments[index]
    if segment.encounterSuccess == 1 and type(segment.meters) == "table" then
      rows[#rows + 1] = {
        rowType = "ITEM",
        title = (segment.encounterName or "Boss") .. " — Kill",
        metadata = SegmentPicker.BuildSegmentMetadata(segment, "M+ boss"),
        duration = segment.durationSeconds,
        selection = {
          kind = "DUNGEON_SAVED",
          savedID = saved.id,
          view = "BOSS",
          sessionID = segment.sessionID,
        },
      }
    end
  end

  return rows, saved
end

function SegmentPicker.IsRowSelected(window, data)
  local windowDB = GetWindowDB(window.index)
  if data.sessionKey then
    return GetWindowSelection(windowDB) == nil and windowDB.session == data.sessionKey
  end
  return data.selection
    and WindowSelectionsEqual(GetWindowSelection(windowDB), data.selection)
end

function SegmentPicker.SetKeystoneView(picker, savedID)
  local panel = picker.panelsByKey.KEYSTONES
  local previousSavedID = picker.keystoneSavedID
  panel.offset = 0
  picker.keystoneSavedID = savedID

  if savedID then
    local saved
    panel.data, saved = SegmentPicker.BuildKeystoneDetailRows(savedID)
    panel.currentLabel = saved and saved.name or "Completed keystones"
  else
    panel.data = SegmentPicker.BuildRows().KEYSTONES
    panel.currentLabel = nil
    for index = 1, #panel.data do
      if panel.data[index].savedID == previousSavedID then
        panel.offset = Clamp(
          index - 3,
          0,
          math_max(0, #panel.data - panel.rowCount)
        )
        break
      end
    end
  end

  SegmentPicker.Refresh(picker)
end

function SegmentPicker.ReloadData(picker)
  local panelRows = SegmentPicker.BuildRows()
  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    panel.data = panelRows[panel.key]
    panel.currentLabel = nil
    panel.offset = 0
  end

  if picker.keystoneSavedID then
    local detailRows, saved = SegmentPicker.BuildKeystoneDetailRows(picker.keystoneSavedID)
    if saved then
      local panel = picker.panelsByKey.KEYSTONES
      panel.data = detailRows
      panel.currentLabel = saved.name
    else
      picker.keystoneSavedID = nil
    end
  end
  SegmentPicker.Refresh(picker)
end

function SegmentPicker.ToggleSavedRecord(picker, data)
  local savedState = data.isSaved ~= true
  local changed
  if data.recordType == "SEGMENT" then
    changed = History:SetSavedSegment(data.recordID, savedState)
  elseif data.recordType == "DUNGEON" then
    changed = History:SetSavedDungeon(data.recordID, savedState)
  end

  if changed then
    SegmentPicker.ReloadData(picker)
    DamageMeters:RefreshWindows()
  end
end

function SegmentPicker.ConfirmDeleteRecord(picker, data)
  if data.isSaved == true then
    return
  end

  local recordName = data.recordType == "DUNGEON" and "keystone" or "segment"
  Addon:PUI_ConfirmAction({
    title = "Delete " .. recordName .. "?",
    text = "Delete " .. (data.title or recordName) .. "?\n\nIt will be removed from every history section.",
    yesText = "Delete",
    noText = "Cancel",
    onYes = function()
      local deleted
      if data.recordType == "SEGMENT" then
        deleted = History:DeleteSavedSegment(data.recordID)
      elseif data.recordType == "DUNGEON" then
        deleted = History:DeleteSavedDungeon(data.recordID)
      end
      if deleted then
        SegmentPicker.ReloadData(picker)
        DamageMeters:RefreshWindows()
      end
    end,
  })
end

function SegmentPicker.ConfirmDeleteSection(picker, panel)
  local count = History:GetSectionEntryCount(panel.key)
  if count <= 0 then
    return
  end

  local title
  local text
  local yesText
  if panel.key == "BOSS_KILLS" then
    title = "Delete boss kills?"
    text = "Delete " .. count .. " unsaved boss " .. (count == 1 and "kill" or "kills")
      .. "?\n\nSaved boss kills will be kept."
    yesText = "Delete kills"
  elseif panel.key == "KEYSTONES" then
    title = "Delete keystones?"
    text = "Delete " .. count .. " unsaved completed " .. (count == 1 and "keystone" or "keystones")
      .. "?\n\nSaved keystones will be kept."
    yesText = "Delete keystones"
  else
    return
  end

  Addon:PUI_ConfirmAction({
    title = title,
    text = text,
    yesText = yesText,
    noText = "Cancel",
    onYes = function()
      History:DeleteSection(panel.key)
      if panel.key == "KEYSTONES" then
        picker.keystoneSavedID = nil
      end
      SegmentPicker.ReloadData(picker)
      DamageMeters:RefreshWindows()
    end,
  })
end

function SegmentPicker.UpdateRowControls(row, colors)
  local data = row.data
  if not data or not data.canSave then
    row.saveButton:Hide()
    row.deleteButton:Hide()
    return
  end

  local hovered = row:IsMouseOver()
  row.saveButton:SetShown(hovered or data.isSaved == true)
  row.deleteButton:SetShown(hovered and data.canDelete == true and data.isSaved ~= true)
  row.saveButton.icon:SetTexture(
    data.isSaved == true and PAD_LOCKED_TEXTURE or PAD_UNLOCKED_TEXTURE
  )
  colors = colors or Theme.GetColors()
  row.saveButton.icon:SetVertexColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    data.isSaved == true and 1 or 0.75
  )
end

function SegmentPicker.RefreshRow(picker, row, data, colors)
  local compact = row.panel.compact == true
  local layoutKey
  if compact then
    layoutKey = row.recency and data.recency and "COMPACT_RECENCY" or "COMPACT"
  else
    layoutKey = data.canSave and "STANDARD_CONTROLS" or "STANDARD"
  end

  row.data = data
  row:Show()

  if row.layoutKey ~= layoutKey then
    row.layoutKey = layoutKey
    row.duration:ClearAllPoints()
    row.metadata:ClearAllPoints()
    row.title:ClearAllPoints()

    if compact then
      row.metadata:Hide()
      row.duration:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      if row.recency then
        row.recency:ClearAllPoints()
        row.recency:SetPoint("LEFT", row, "LEFT", 6, 0)
      end
      if layoutKey == "COMPACT_RECENCY" then
        row.title:SetPoint("LEFT", row.recency, "RIGHT", 6, 0)
      else
        row.title:SetPoint("LEFT", row, "LEFT", 6, 0)
      end
      row.title:SetPoint("RIGHT", row.duration, "LEFT", -8, 0)
    else
      if row.recency then
        row.recency:Hide()
      end
      row.metadata:Show()
      if layoutKey == "STANDARD_CONTROLS" then
        row.duration:SetPoint("RIGHT", row.saveButton, "LEFT", -4, 5)
        row.metadata:SetPoint("RIGHT", row.saveButton, "LEFT", -4, 0)
      else
        row.duration:SetPoint("RIGHT", row, "RIGHT", -6, 5)
        row.metadata:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      end
      row.metadata:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
      row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -1)
      row.title:SetPoint("RIGHT", row.duration, "LEFT", -8, 0)
    end
  end

  if compact and row.recency then
    if data.recency then
      row.recency:SetText(data.recency)
      if data.recency == "Newest" then
        row.recency:SetTextColor(
          colors.accent[1],
          colors.accent[2],
          colors.accent[3],
          1
        )
      else
        row.recency:SetTextColor(
          colors.text[1],
          colors.text[2],
          colors.text[3],
          0.55
        )
      end
      row.recency:Show()
    else
      row.recency:Hide()
    end
  end

  if data.rowType == "INFO" then
    row:EnableMouse(false)
    row.selected:Hide()
    row.title:SetText(data.title or "No entries")
    row.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.88)
    row.metadata:SetText(data.metadata or "")
    row.duration:SetText(
      type(data.duration) == "number" and data.duration > 0
        and FormatDuration(data.duration)
        or ""
    )
    row.background:SetColorTexture(
      colors.control[1],
      colors.control[2],
      colors.control[3],
      0.28
    )
    SegmentPicker.UpdateRowControls(row, colors)
    return
  end

  row:EnableMouse(true)
  row.title:SetText(data.title or "Combat")
  row.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
  row.metadata:SetText(data.metadata or "")
  row.duration:SetText(
    type(data.duration) == "number" and data.duration > 0
      and FormatDuration(data.duration)
      or ""
  )
  row.background:SetColorTexture(
    colors.control[1],
    colors.control[2],
    colors.control[3],
    0.44
  )
  row.selected:SetShown(SegmentPicker.IsRowSelected(picker.ownerWindow, data))
  SegmentPicker.UpdateRowControls(row, colors)
end

function SegmentPicker.Refresh(picker)
  local colors = Theme.GetColors()
  local rowAreaHeight = 0
  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    local visibleRows = math_min(#panel.data, panel.rowCount)
    local panelRowAreaHeight = visibleRows * panel.rowHeight
      + math_max(0, visibleRows - 1) * panel.rowGap
    rowAreaHeight = math_max(rowAreaHeight, panelRowAreaHeight)
  end

  if picker.rowAreaHeight ~= rowAreaHeight then
    picker.rowAreaHeight = rowAreaHeight
    picker:SetHeight(82 + rowAreaHeight)
    for panelIndex = 1, #picker.panels do
      picker.panels[panelIndex].viewport:SetHeight(rowAreaHeight)
    end
  end

  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    panel.title:SetText(panel.currentLabel or panel.label)
    local data = panel.data
    local maximumOffset = math_max(0, #data - panel.rowCount)
    panel.offset = Clamp(panel.offset or 0, 0, maximumOffset)

    for rowIndex = 1, panel.rowCount do
      local row = panel.rows[rowIndex]
      local rowData = data[panel.offset + rowIndex]
      if rowData then
        SegmentPicker.RefreshRow(picker, row, rowData, colors)
      else
        row.data = nil
        row:Hide()
      end
    end

    if #data > panel.rowCount then
      local first = panel.offset + 1
      local last = math_min(#data, panel.offset + panel.rowCount)
      if panel.key == "RECENT" then
        panel.scrollText:SetText(
          first .. "–" .. last .. " of " .. #data .. " · Newest to oldest"
        )
      else
        panel.scrollText:SetText(first .. "–" .. last .. " of " .. #data .. " · Mouse wheel")
      end
    elseif panel.key == "RECENT" then
      panel.scrollText:SetText(#data .. " entries · Newest to oldest")
    else
      panel.scrollText:SetText(#data .. " entries")
    end
    local deleteCount = History:GetSectionEntryCount(panel.key)
    panel.deleteButton:SetEnabled(deleteCount > 0)
    panel.deleteButton.count = deleteCount
    panel.deleteButton.background:SetColorTexture(
      colors.control[1],
      colors.control[2],
      colors.control[3],
      deleteCount > 0 and 0.44 or 0.22
    )
  end
end

function SegmentPicker.Scroll(picker, panel, delta)
  local maximumOffset = math_max(0, #panel.data - panel.rowCount)
  panel.offset = Clamp((panel.offset or 0) - delta * 3, 0, maximumOffset)
  SegmentPicker.Refresh(picker)
end

function SegmentPicker.RefreshSelectionStyle(picker, colors)
  local window = picker.ownerWindow
  if not window then
    return
  end

  colors = colors or Theme.GetColors()
  local windowDB = GetWindowDB(window.index)
  local selection = GetWindowSelection(windowDB)

  for index = 1, #picker.sessionButtons do
    local button = picker.sessionButtons[index]
    local selected = selection == nil and windowDB.session == button.sessionKey
    button.background:SetColorTexture(
      selected and colors.accent[1] or colors.control[1],
      selected and colors.accent[2] or colors.control[2],
      selected and colors.accent[3] or colors.control[3],
      selected and 0.5 or 0.44
    )
  end
end

function SegmentPicker.ApplyStyle(picker)
  local colors = Theme.GetColors()
  local fontSize = DamageMeters.db.profile.fontSize
  Theme.SetSquareBackdrop(picker, {
    bg = colors.background,
    border = colors.border,
  }, 2)
  Theme.ApplyFont(picker.title, "header", fontSize + 1, "OUTLINE")
  Theme.ApplyFont(picker.clearButton.text, "tiny", math_max(8, fontSize - 1), "OUTLINE")
  picker.title:SetText("Combat history")
  picker.clearButton.text:SetText("Clear unsaved…")
  picker.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
  picker.clearButton.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.82)
  picker.clearButton.background:SetColorTexture(
    colors.control[1],
    colors.control[2],
    colors.control[3],
    0.44
  )
  for index = 1, #picker.sessionButtons do
    local button = picker.sessionButtons[index]
    Theme.ApplyFont(button.text, "tiny", math_max(8, fontSize - 1), "OUTLINE")
    button.text:SetText(button.label)
    button.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.9)
  end
  SegmentPicker.RefreshSelectionStyle(picker, colors)

  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    Theme.ApplyFont(panel.title, "body", fontSize, "OUTLINE")
    Theme.ApplyFont(panel.scrollText, "tiny", math_max(8, fontSize - 2), "OUTLINE")
    Theme.ApplyFont(panel.deleteButton.text, "tiny", math_max(8, fontSize - 2), "OUTLINE")
    panel.title:SetText(panel.currentLabel or panel.label)
    panel.deleteButton.text:SetText(panel.deleteLabel)
    panel.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.9)
    panel.scrollText:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)
    panel.deleteButton.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.82)
    panel.deleteButton.background:SetColorTexture(
      colors.control[1],
      colors.control[2],
      colors.control[3],
      panel.deleteButton:IsEnabled() and 0.44 or 0.22
    )
    Theme.SetSquareBackdrop(panel.viewport, {
      bg = colors.background,
      border = colors.border,
    }, 1)

    for index = 1, #panel.rows do
      local row = panel.rows[index]
      if panel.compact then
        local compactFontSize = math_min(11, math_max(8, fontSize - 2))
        Theme.ApplyFont(row.title, "tiny", compactFontSize, "OUTLINE")
        Theme.ApplyFont(row.duration, "tiny", compactFontSize, "OUTLINE")
        if row.recency then
          Theme.ApplyFont(row.recency, "tiny", math_max(8, compactFontSize - 1), "OUTLINE")
        end
      else
        Theme.ApplyFont(row.title, "body", fontSize, "OUTLINE")
        Theme.ApplyFont(row.duration, "tiny", math_max(8, fontSize - 1), "OUTLINE")
      end
      Theme.ApplyFont(row.metadata, "tiny", math_max(8, fontSize - 2), "OUTLINE")
      row.metadata:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.58)
      row.duration:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.82)
      row.saveButton.icon:SetVertexColor(
        colors.accent[1],
        colors.accent[2],
        colors.accent[3],
        row.data and row.data.isSaved == true and 1 or 0.75
      )
      row.deleteButton.icon:SetVertexColor(1, 0.35, 0.35, 0.9)
      row.selected:SetColorTexture(
        colors.accent[1],
        colors.accent[2],
        colors.accent[3],
        0.22
      )
    end
  end

  picker.styledProfile = DamageMeters.db.profile
end

function SegmentPicker.CreateRow(picker, panel, parent, index)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(panel.rowHeight)
  row:SetPoint(
    "TOPLEFT",
    parent,
    "TOPLEFT",
    0,
    -((index - 1) * (panel.rowHeight + panel.rowGap))
  )
  row:SetPoint(
    "TOPRIGHT",
    parent,
    "TOPRIGHT",
    0,
    -((index - 1) * (panel.rowHeight + panel.rowGap))
  )
  row:RegisterForClicks("LeftButtonUp")
  row:EnableMouseWheel(true)
  row.picker = picker
  row.panel = panel

  local background = row:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(row)
  row.background = background

  local selected = row:CreateTexture(nil, "BORDER")
  selected:SetAllPoints(row)
  selected:Hide()
  row.selected = selected

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(row)
  highlight:SetColorTexture(1, 1, 1, 0.08)

  local deleteButton = CreateFrame("Button", nil, row)
  deleteButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  deleteButton:SetSize(16, 16)
  deleteButton:RegisterForClicks("LeftButtonUp")
  deleteButton:Hide()
  local deleteIcon = deleteButton:CreateTexture(nil, "ARTWORK")
  deleteIcon:SetAllPoints(deleteButton)
  deleteIcon:SetTexture(TRASH_TEXTURE)
  deleteButton.icon = deleteIcon
  local deleteHighlight = deleteButton:CreateTexture(nil, "HIGHLIGHT")
  deleteHighlight:SetAllPoints(deleteButton)
  deleteHighlight:SetColorTexture(1, 1, 1, 0.15)
  row.deleteButton = deleteButton

  local saveButton = CreateFrame("Button", nil, row)
  saveButton:SetPoint("RIGHT", deleteButton, "LEFT", -2, 0)
  saveButton:SetSize(16, 16)
  saveButton:RegisterForClicks("LeftButtonUp")
  saveButton:Hide()
  local saveIcon = saveButton:CreateTexture(nil, "ARTWORK")
  saveIcon:SetAllPoints(saveButton)
  saveButton.icon = saveIcon
  local saveHighlight = saveButton:CreateTexture(nil, "HIGHLIGHT")
  saveHighlight:SetAllPoints(saveButton)
  saveHighlight:SetColorTexture(1, 1, 1, 0.15)
  row.saveButton = saveButton

  local duration = row:CreateFontString(nil, "OVERLAY")
  duration:SetPoint("RIGHT", saveButton, "LEFT", -4, 5)
  duration:SetWidth(58)
  duration:SetJustifyH("RIGHT")
  row.duration = duration

  local title = row:CreateFontString(nil, "OVERLAY")
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  row.title = title

  if panel.compact then
    local recency = row:CreateFontString(nil, "OVERLAY")
    recency:SetWidth(42)
    recency:SetJustifyH("LEFT")
    recency:SetWordWrap(false)
    recency:Hide()
    row.recency = recency
  end

  local metadata = row:CreateFontString(nil, "OVERLAY")
  metadata:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
  metadata:SetPoint("RIGHT", saveButton, "LEFT", -4, 0)
  metadata:SetJustifyH("LEFT")
  metadata:SetWordWrap(false)
  row.metadata = metadata

  row:SetScript("OnClick", function(self)
    local data = self.data
    if not data then
      return
    end

    if data.action == "OPEN_KEYSTONE" then
      if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
      end
      SegmentPicker.SetKeystoneView(self.picker, data.savedID)
      return
    end
    if data.action == "CLOSE_KEYSTONE" then
      if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
      end
      SegmentPicker.SetKeystoneView(self.picker, nil)
      return
    end
    if data.rowType ~= "ITEM" then
      return
    end

    SelectWindowSegment(
      self.picker.ownerWindow,
      data.sessionKey,
      data.selection
    )
    SegmentPicker.RefreshSelectionStyle(self.picker)
    SegmentPicker.Refresh(self.picker)
  end)
  row:SetScript("OnMouseWheel", function(self, delta)
    SegmentPicker.Scroll(self.picker, self.panel, delta)
  end)
  row:SetScript("OnEnter", function(self)
    SegmentPicker.UpdateRowControls(self)
    local data = self.data
    if data and data.runSummarySavedID then
      SegmentPicker.ShowRunSummaryTooltip(
        self,
        History:FindSavedDungeon(data.runSummarySavedID)
      )
    end
  end)
  row:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then
      GameTooltip:Hide()
    end
    SegmentPicker.UpdateRowControls(self)
  end)

  saveButton:SetScript("OnClick", function()
    local data = row.data
    if data and data.canSave then
      SegmentPicker.ToggleSavedRecord(row.picker, data)
    end
  end)
  saveButton:SetScript("OnEnter", function(self)
    local data = row.data
    if not data then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.isSaved == true and "Unsave" or "Save")
    GameTooltip:AddLine(
      data.isSaved == true
        and "Allow retention and deletion rules to remove this record."
        or "Protect this record from retention and every delete action.",
      1,
      1,
      1,
      true
    )
    GameTooltip:Show()
    SegmentPicker.UpdateRowControls(row)
  end)
  saveButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    SegmentPicker.UpdateRowControls(row)
  end)

  deleteButton:SetScript("OnClick", function()
    local data = row.data
    if data and data.canDelete and data.isSaved ~= true then
      SegmentPicker.ConfirmDeleteRecord(row.picker, data)
    end
  end)
  deleteButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Delete")
    GameTooltip:AddLine("Permanently remove this record from every section.", 1, 1, 1, true)
    GameTooltip:Show()
    SegmentPicker.UpdateRowControls(row)
  end)
  deleteButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    SegmentPicker.UpdateRowControls(row)
  end)

  return row
end

function SegmentPicker.Ensure()
  if DamageMeters.segmentPicker then
    return DamageMeters.segmentPicker
  end

  local picker = CreateFrame(
    "Frame",
    "PUI_DamageMeterSegmentPicker",
    UIParent,
    "BackdropTemplate"
  )
  local pickerWidth = SegmentPicker.horizontalPadding * 2
    + SegmentPicker.panelWidth * 3
    + SegmentPicker.panelGap * 2
  picker:SetWidth(pickerWidth)
  picker:SetFrameStrata("DIALOG")
  picker:SetClampedToScreen(true)
  picker:EnableMouse(true)
  picker:EnableMouseWheel(true)
  picker:Hide()

  local title = picker:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -8)
  picker.title = title

  picker.sessionButtons = {}
  local sessionButtonDefinitions = {
    { key = "CURRENT", label = "Current", rightOffset = -8, width = 58 },
    { key = "OVERALL", label = "Blizzard Overall", rightOffset = -70, width = 104 },
  }
  for index = 1, #sessionButtonDefinitions do
    local definition = sessionButtonDefinitions[index]
    local button = CreateFrame("Button", nil, picker)
    button:SetPoint("TOPRIGHT", picker, "TOPRIGHT", definition.rightOffset, -7)
    button:SetSize(definition.width, 18)
    button:RegisterForClicks("LeftButtonUp")
    button.sessionKey = definition.key
    button.label = definition.label

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    button.background = background

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local buttonText = button:CreateFontString(nil, "OVERLAY")
    buttonText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.text = buttonText

    button:SetScript("OnClick", function(self)
      SelectWindowSegment(picker.ownerWindow, self.sessionKey, nil)
      SegmentPicker.RefreshSelectionStyle(picker)
      SegmentPicker.Refresh(picker)
    end)
    picker.sessionButtons[index] = button
  end

  picker.panels = {}
  picker.panelsByKey = {}
  local panelDefinitions = {
    { key = "BOSS_KILLS", title = "Bosses", deleteLabel = "Delete bosses…" },
    { key = "KEYSTONES", title = "Completed keystones", deleteLabel = "Delete keys…" },
    {
      key = "RECENT",
      title = "Recent segments",
      compact = true,
      rowCount = SegmentPicker.recentRowCount,
      rowHeight = SegmentPicker.recentRowHeight,
      rowGap = SegmentPicker.recentRowGap,
    },
  }
  for panelIndex = 1, #panelDefinitions do
    local definition = panelDefinitions[panelIndex]
    local panelX = SegmentPicker.horizontalPadding
      + (panelIndex - 1) * (SegmentPicker.panelWidth + SegmentPicker.panelGap)
    local panel = {
      key = definition.key,
      label = definition.title,
      data = {},
      offset = 0,
      rows = {},
      deleteLabel = definition.deleteLabel,
      compact = definition.compact == true,
      rowCount = definition.rowCount or SegmentPicker.rowCount,
      rowHeight = definition.rowHeight or SegmentPicker.rowHeight,
      rowGap = definition.rowGap or SegmentPicker.rowGap,
    }
    picker.panels[panelIndex] = panel
    picker.panelsByKey[panel.key] = panel

    local panelTitle = picker:CreateFontString(nil, "OVERLAY")
    panelTitle:SetPoint("TOPLEFT", picker, "TOPLEFT", panelX + 2, -31)
    panelTitle:SetWidth(SegmentPicker.panelWidth - 4)
    panelTitle:SetJustifyH("CENTER")
    panel.title = panelTitle

    local viewport = CreateFrame("Frame", nil, picker, "BackdropTemplate")
    viewport:SetPoint("TOPLEFT", picker, "TOPLEFT", panelX, -52)
    viewport:SetSize(
      SegmentPicker.panelWidth,
      panel.rowCount * panel.rowHeight
        + (panel.rowCount - 1) * panel.rowGap
    )
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(_, delta)
      SegmentPicker.Scroll(picker, panel, delta)
    end)
    panel.viewport = viewport

    for index = 1, panel.rowCount do
      panel.rows[index] = SegmentPicker.CreateRow(picker, panel, viewport, index)
    end

    local scrollText = picker:CreateFontString(nil, "OVERLAY")
    scrollText:SetPoint(
      "BOTTOMLEFT",
      picker,
      "BOTTOMLEFT",
      panelX + 2,
      10
    )
    scrollText:SetWidth(
      definition.deleteLabel and 110 or SegmentPicker.panelWidth - 4
    )
    scrollText:SetJustifyH("LEFT")
    panel.scrollText = scrollText

    local deleteButton = CreateFrame("Button", nil, picker)
    deleteButton:SetPoint(
      "BOTTOMRIGHT",
      picker,
      "BOTTOMLEFT",
      panelX + SegmentPicker.panelWidth - 2,
      7
    )
    deleteButton:SetSize(112, 18)
    deleteButton:RegisterForClicks("LeftButtonUp")
    deleteButton:SetShown(definition.deleteLabel ~= nil)
    deleteButton.panel = panel
    local deleteBackground = deleteButton:CreateTexture(nil, "BACKGROUND")
    deleteBackground:SetAllPoints(deleteButton)
    deleteButton.background = deleteBackground
    local deleteHighlight = deleteButton:CreateTexture(nil, "HIGHLIGHT")
    deleteHighlight:SetAllPoints(deleteButton)
    deleteHighlight:SetColorTexture(1, 1, 1, 0.08)
    local deleteText = deleteButton:CreateFontString(nil, "OVERLAY")
    deleteText:SetPoint("CENTER", deleteButton, "CENTER", 0, 0)
    deleteButton.text = deleteText
    deleteButton:SetScript("OnClick", function(self)
      SegmentPicker.ConfirmDeleteSection(picker, self.panel)
    end)
    panel.deleteButton = deleteButton
  end

  local clearButton = CreateFrame("Button", nil, picker)
  clearButton:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -140, -7)
  clearButton:SetSize(108, 18)
  clearButton:RegisterForClicks("LeftButtonUp")
  picker.clearButton = clearButton

  local clearBackground = clearButton:CreateTexture(nil, "BACKGROUND")
  clearBackground:SetAllPoints(clearButton)
  clearButton.background = clearBackground

  local clearHighlight = clearButton:CreateTexture(nil, "HIGHLIGHT")
  clearHighlight:SetAllPoints(clearButton)
  clearHighlight:SetColorTexture(1, 1, 1, 0.08)

  local clearText = clearButton:CreateFontString(nil, "OVERLAY")
  clearText:SetPoint("CENTER", clearButton, "CENTER", 0, 0)
  clearButton.text = clearText

  clearButton:SetScript("OnClick", function()
    picker:Hide()
    ConfirmClearUnsavedSegments()
  end)
  picker:SetScript("OnShow", function(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
  end)
  picker:SetScript("OnHide", function(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self.ownerWindow = nil
    self.keystoneSavedID = nil
    for panelIndex = 1, #self.panels do
      self.panels[panelIndex].data = {}
      self.panels[panelIndex].offset = 0
      self.panels[panelIndex].currentLabel = nil
    end
  end)
  picker:SetScript("OnEvent", function(self, event)
    if event ~= "GLOBAL_MOUSE_DOWN" then
      return
    end

    local ownerButton = self.ownerWindow and self.ownerWindow.sessionButton
    if self:IsMouseOver() or (ownerButton and ownerButton:IsMouseOver()) then
      return
    end

    self:Hide()
  end)

  DamageMeters.segmentPicker = picker
  return picker
end

function SegmentPicker.Hide()
  if DamageMeters.segmentPicker then
    DamageMeters.segmentPicker:Hide()
  end
end

function SegmentPicker.Show(window)
  local menuManager = Menu.GetManager()
  local openMenu = menuManager:GetOpenMenu()
  if openMenu then
    menuManager:CloseMenu(openMenu)
  end

  local picker = SegmentPicker.Ensure()
  if picker:IsShown() and picker.ownerWindow == window then
    picker:Hide()
    return
  end

  DamageMeters:ReconcileAvailableSessionSelections()
  DamageMeters:RefreshSelectionWindows()
  picker.ownerWindow = window
  local panelRows = SegmentPicker.BuildRows()
  local windowSelection = GetWindowSelection(GetWindowDB(window.index))
  local keystoneSavedID = windowSelection
    and windowSelection.kind == "DUNGEON_SAVED"
    and windowSelection.savedID
    or nil
  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    panel.data = panelRows[panel.key]
    panel.currentLabel = nil
  end
  if keystoneSavedID then
    local saved
    picker.panelsByKey.KEYSTONES.data, saved = SegmentPicker.BuildKeystoneDetailRows(
      keystoneSavedID
    )
    picker.panelsByKey.KEYSTONES.currentLabel = saved
      and saved.name
      or "Completed keystones"
  end
  picker.keystoneSavedID = keystoneSavedID

  for panelIndex = 1, #picker.panels do
    local panel = picker.panels[panelIndex]
    panel.offset = 0
    for index = 1, #panel.data do
      if SegmentPicker.IsRowSelected(window, panel.data[index]) then
        panel.offset = Clamp(index - 3, 0, math_max(0, #panel.data - panel.rowCount))
        break
      end
    end
  end

  if picker.styledProfile ~= DamageMeters.db.profile then
    SegmentPicker.ApplyStyle(picker)
  else
    SegmentPicker.RefreshSelectionStyle(picker)
  end
  SegmentPicker.Refresh(picker)
  picker:ClearAllPoints()
  picker:SetPoint("BOTTOMRIGHT", window.sessionButton, "TOPRIGHT", 0, 4)
  picker:Show()
end

local function ShowWindowConfigMenu(window)
  SegmentPicker.Hide()
  ToggleContextMenu(window.configButton, function(_, rootDescription)
    local windowDB = GetWindowDB(window.index)
    rootDescription:CreateTitle("Window " .. window.index)
    rootDescription:CreateButton("New window", function()
      DamageMeters:AddWindow()
    end)
    rootDescription:CreateButton("Hide window", function()
      DamageMeters:CloseWindow(window.index)
    end)
    rootDescription:CreateButton("Delete window", function()
      DamageMeters:DeleteWindow(window.index)
    end)
    rootDescription:CreateCheckbox(
      "Always show me",
      function()
        return windowDB.alwaysShowMe == true
      end,
      function()
        windowDB.alwaysShowMe = windowDB.alwaysShowMe ~= true
        Windows.RefreshWindow(window, nil, windowDB)
      end
    )
    rootDescription:CreateCheckbox(
      "Sync segment selection",
      function()
        return windowDB.syncSegments == true
      end,
      function()
        windowDB.syncSegments = windowDB.syncSegments ~= true
        window.runtime.syncSegments = windowDB.syncSegments
      end
    )
    rootDescription:CreateCheckbox(
      "Automatically switch to Current in combat",
      function()
        return windowDB.autoCurrentOnCombat == true
      end,
      function()
        windowDB.autoCurrentOnCombat = windowDB.autoCurrentOnCombat ~= true
        window.runtime.autoCurrentOnCombat = windowDB.autoCurrentOnCombat
      end
    )
    rootDescription:CreateDivider()
    rootDescription:CreateButton("Clear unsaved segments", function()
      ConfirmClearUnsavedSegments()
    end)
    rootDescription:CreateButton("Reset position", function()
      DamageMeters:ResetWindowPosition(window.index)
    end)
    rootDescription:CreateDivider()
    rootDescription:CreateButton("Open settings", function()
      Addon:OpenOptionsSection("DamageMeters")
    end)
  end)
end

ContextMenuButtonHandlesGlobalMouseEvent = P:Def("ContextMenuButtonHandlesGlobalMouseEvent", ContextMenuButtonHandlesGlobalMouseEvent)
ToggleContextMenu = P:Def("ToggleContextMenu", ToggleContextMenu)
ConfirmClearUnsavedSegments = P:Def("ConfirmClearUnsavedSegments", ConfirmClearUnsavedSegments)
SegmentPicker.BuildRows = P:Def("BuildSegmentPickerRows", SegmentPicker.BuildRows)
SegmentPicker.Refresh = P:Def("RefreshSegmentPicker", SegmentPicker.Refresh)
SegmentPicker.Show = P:Def("ShowSegmentPicker", SegmentPicker.Show)
ShowWindowConfigMenu = P:Def("ShowWindowConfigMenu", ShowWindowConfigMenu)

SegmentPicker.ContextMenuButtonHandlesGlobalMouseEvent = ContextMenuButtonHandlesGlobalMouseEvent
SegmentPicker.ConfirmClearUnsavedSegments = ConfirmClearUnsavedSegments
SegmentPicker.ShowWindowConfigMenu = ShowWindowConfigMenu
