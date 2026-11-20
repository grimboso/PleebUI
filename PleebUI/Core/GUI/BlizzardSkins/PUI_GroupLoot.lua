local _, ns = ...
local Skins = ns.BlizzardSkins

local function RaiseRollTimer(frame)
  -- This unprotected status bar is lowered by Blizzard's OnShow below our shell.
  frame.Timer:SetFrameLevel(frame:GetFrameLevel() + 1)
end

local function RefreshRollColors(frame)
  local accent = ns.Theme.GetColors().accent
  frame.Timer:SetStatusBarColor(accent[1], accent[2], accent[3], accent[4])
end

local rollAnchor
local hasRollPosition = false
local activeDrag

local function StopRollDragging(control)
  if activeDrag ~= control then return end
  rollAnchor:StopMovingOrSizing()
  control:UnregisterEvent("PLAYER_REGEN_DISABLED")
  activeDrag = nil
end

local function ApplyRollPosition(container)
  if not hasRollPosition or InputUtil.IsGamepadUIEnabled() then return end
  -- Keep Blizzard's slot order and spacing around our movable origin.
  for _, frame in pairs(container.rollFrames) do
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if relativeTo == container then
      frame:ClearAllPoints()
      frame:SetPoint(point, rollAnchor, relativePoint, x, y)
    end
  end
end

local function ResetRollPosition()
  if not hasRollPosition then return end
  if activeDrag then StopRollDragging(activeDrag) end
  hasRollPosition = false
  GroupLootContainer_Update(GroupLootContainer)
end

local function InstallRollDragging(frame)
  if not rollAnchor then
    rollAnchor = CreateFrame("Frame", nil, UIParent)
    rollAnchor:SetSize(1, 1)
    rollAnchor:SetMovable(true)
    rollAnchor:SetClampedToScreen(true)
    rollAnchor:SetDontSavePosition(true)
    Skins.Hook(_G, "GroupLootContainer_Update", ApplyRollPosition)
    EventRegistry:RegisterCallback("EditMode.Enter", ResetRollPosition, rollAnchor)
    EventRegistry:RegisterCallback("EditMode.SavedLayouts", ResetRollPosition, rollAnchor)
    ns.FrameUtil.RegisterEditModeParticipant("LootRollDragging", {
      OnEditModeChanged = function(_, active)
        if active then ResetRollPosition() end
      end,
    })
  end

  local drag = CreateFrame("Frame", nil, frame)
  drag:SetAllPoints(frame.Name)
  drag:SetFrameLevel(frame:GetFrameLevel() + 5)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function(control)
    if InCombatLockdown() or ns.Flags.IsEditing or EditModeManagerFrame:IsEditModeActive()
      or InputUtil.IsGamepadUIEnabled() then return end
    if activeDrag then StopRollDragging(activeDrag) end
    if not hasRollPosition then
      rollAnchor:ClearAllPoints()
      rollAnchor:SetPoint("BOTTOM", GroupLootContainer, "BOTTOM", 0, 0)
      hasRollPosition = true
    end
    activeDrag = control
    control:RegisterEvent("PLAYER_REGEN_DISABLED")
    rollAnchor:StartMoving()
    ApplyRollPosition(GroupLootContainer)
  end)
  drag:SetScript("OnDragStop", StopRollDragging)
  drag:SetScript("OnMouseUp", StopRollDragging)
  drag:SetScript("OnHide", StopRollDragging)
  drag:SetScript("OnEvent", StopRollDragging)
end

local function InstallRoll(frame)
  Skins.Panel(frame)
  Skins.Icon(frame.IconFrame.Icon)
  ns.Theme.ApplyFont(frame.Name, "body")
  ns.Theme.ApplyFont(frame.IconFrame.Count, "tiny")
  Skins.Bar(frame.Timer)
  RaiseRollTimer(frame)
  frame:HookScript("OnShow", RaiseRollTimer)
  RefreshRollColors(frame)
  InstallRollDragging(frame)
  -- Need/Greed/Transmog/Pass glyphs, eligibility and roll animations stay native.
end

for index = 1, 4 do
  Skins.Register("Blizzard_UIPanels_Game", "GroupLootFrame" .. index, {
    install = InstallRoll,
    manageControls = false,
    onTheme = RefreshRollColors,
  })
end
