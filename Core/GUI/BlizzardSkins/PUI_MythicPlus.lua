local _, ns = ...
local Skins = ns.BlizzardSkins
local skinnedDungeonIcons = setmetatable({}, { __mode = "k" })

local function RefreshMythicPlus(frame)
  Skins.Hide(frame.Background)
  Skins.Panel(ChallengesFrameInset)
  local info = frame.WeeklyInfo.Child
  Skins.StripRegions(info)
  Skins.Texts(info)
  Skins.Texts(info.WeeklyChest)
  ns.Theme.ApplyFont(info.DungeonScoreInfo.Title, "header")
  ns.Theme.ApplyFont(info.DungeonScoreInfo.Score, "title")
  for _, key in ipairs({ "RuneBG", "RunesLarge", "RunesSmall", "LargeRuneGlow", "SmallRuneGlow" }) do
    info[key]:SetTexture(nil)
  end
  if frame.DungeonIcons then
    for _, dungeon in ipairs(frame.DungeonIcons) do
      if not skinnedDungeonIcons[dungeon] then
        Skins.StripRegions(dungeon, { [dungeon.Icon] = true })
        Skins.Surface(dungeon, true)
        Skins.Icon(dungeon.Icon)
        Skins.Texts(dungeon)
        skinnedDungeonIcons[dungeon] = true
      end
    end
  end
  Skins.StripRegions(frame.SeasonChangeNoticeFrame)
  Skins.Texts(frame.SeasonChangeNoticeFrame)
  Skins.Button(frame.SeasonChangeNoticeFrame.Leave)
end

Skins.Register("Blizzard_ChallengesUI", "ChallengesFrame", function(frame)
  RefreshMythicPlus(frame)
  Skins.Hook(frame, "Update", function()
    RefreshMythicPlus(frame)
  end)
end)
