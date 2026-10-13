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

local function InstallRoll(frame)
  Skins.Panel(frame)
  Skins.Icon(frame.IconFrame.Icon)
  ns.Theme.ApplyFont(frame.Name, "body")
  ns.Theme.ApplyFont(frame.IconFrame.Count, "tiny")
  Skins.Bar(frame.Timer)
  RaiseRollTimer(frame)
  frame:HookScript("OnShow", RaiseRollTimer)
  RefreshRollColors(frame)
  -- Need/Greed/Transmog/Pass glyphs, eligibility and roll animations stay native.
end

for index = 1, 4 do
  Skins.Register("Blizzard_UIPanels_Game", "GroupLootFrame" .. index, {
    install = InstallRoll,
    onTheme = RefreshRollColors,
  })
end
