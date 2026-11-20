local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins

local dialogs = { "CalendarViewHolidayFrame", "CalendarViewRaidFrame", "CalendarViewEventFrame", "CalendarCreateEventFrame",
  "CalendarMassInviteFrame", "CalendarEventPickerFrame", "CalendarTexturePickerFrame" }
local layout = {
  Button = { "CalendarViewEventAcceptButton", "CalendarViewEventTentativeButton", "CalendarViewEventDeclineButton",
    "CalendarViewEventRemoveButton", "CalendarCreateEventInviteButton", "CalendarCreateEventMassInviteButton",
    "CalendarCreateEventRaidInviteButton", "CalendarCreateEventCreateButton", "CalendarMassInviteAcceptButton",
    "CalendarEventPickerCloseButton", "CalendarTexturePickerAcceptButton", "CalendarTexturePickerCancelButton" },
  Dropdown = { "CalendarFrame.FilterButton", "CalendarCreateEventFrame.EventTypeDropdown", "CalendarCreateEventFrame.HourDropdown",
    "CalendarCreateEventFrame.MinuteDropdown", "CalendarCreateEventFrame.AMPMDropdown", "CalendarCreateEventFrame.DifficultyOptionDropdown",
    "CalendarCreateEventFrame.CommunityDropdown", "CalendarMassInviteFrame.CommunityDropdown", "CalendarMassInviteFrame.RankDropdown" },
  EditBox = { "CalendarCreateEventTitleEdit", "CalendarCreateEventInviteEdit", "CalendarMassInviteMinLevelEdit", "CalendarMassInviteMaxLevelEdit" },
  Font = { "CalendarCreateEventDescriptionContainer.ScrollingEditBox.ScrollBox.EditBox",
    "CalendarViewEventDescriptionContainer.ScrollingFont.ScrollBox.FontStringContainer.FontString",
    "CalendarViewHolidayFrame.ScrollingFont.ScrollBox.FontStringContainer.FontString" },
  Panel = { "CalendarCreateEventDescriptionContainer", "CalendarViewEventDescriptionContainer", "CalendarCreateEventInviteList",
    "CalendarViewEventInviteList" },
  ScrollBar = { "CalendarCreateEventDescriptionContainer.ScrollBar", "CalendarViewEventDescriptionContainer.ScrollBar",
    "CalendarCreateEventInviteList.ScrollBar", "CalendarViewEventInviteList.ScrollBar", "CalendarEventPickerFrame.ScrollBar",
    "CalendarTexturePickerFrame.ScrollBar" },
  CheckBox = { "CalendarCreateEventAutoApproveCheck", "CalendarCreateEventLockEventCheck" },
  Hide = { "CalendarCreateEventFrameButtonBackground", "CalendarEventPickerFrameButtonBackground", "CalendarTexturePickerFrameButtonBackground", "CalendarCreateEventDivider" },
}

local function RepaintRow(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function PaintCalendar(frame)
  Skins.StripRegions(frame)
  Skins.Texts(frame)
  Skins.Arrow(CalendarPrevMonthButton, "<")
  Skins.Arrow(CalendarNextMonthButton, ">")
  for _, name in ipairs(dialogs) do
    local dialog = _G[name]
    Skins.Panel(dialog)
    Skins.Texts(dialog)
    if dialog.Header then
      Skins.StripRegions(dialog.Header)
      Skins.Texts(dialog.Header)
    end
  end
  Skins.Apply(_G, layout)
end

Skins.Register("Blizzard_Calendar", "CalendarFrame", {
  label = "Calendar", category = "Windows", manageControls = false,
  install = function(frame)
    PaintCalendar(frame)
    for _, name in ipairs({ "CalendarCloseButton", "CalendarViewHolidayCloseButton", "CalendarViewRaidCloseButton",
      "CalendarViewEventCloseButton", "CalendarCreateEventCloseButton", "CalendarMassInviteCloseButton" }) do
      ns.Theme.WidgetSkins.CloseButton(_G[name])
    end
    for index = 1, 42 do
      local name = "CalendarDayButton" .. index
      local day = _G[name]
      Skins.Hide(day:GetNormalTexture())
      Skins.Surface(day, true)
      Skins.Selection(day:GetHighlightTexture())
      ns.Theme.ApplyFont(_G[name .. "DateFrameDate"], "body")
      local eventIndex = 1
      while _G[name .. "EventButton" .. eventIndex] do
        RepaintRow(_G[name .. "EventButton" .. eventIndex])
        eventIndex = eventIndex + 1
      end
    end
    for _, box in ipairs({ CalendarCreateEventInviteList.ScrollBox, CalendarViewEventInviteList.ScrollBox,
      CalendarEventPickerFrame.ScrollBox, CalendarTexturePickerFrame.ScrollBox }) do
      Skins.ScrollRows(box, RepaintRow)
    end
  end,
  onTheme = PaintCalendar,
})
