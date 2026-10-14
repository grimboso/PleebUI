local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme
local modules
local styledButtons = setmetatable({}, { __mode = "k" })
local styledBars = setmetatable({}, { __mode = "k" })
local barArtwork = { "BorderLeft", "BorderMid", "BorderRight", "BarFrame", "BarFrame2", "BarFrame3" }

local function TintTrackerButton(button)
  local color = Theme.GetColors().text
  local normal, pushed = button:GetNormalTexture(), button:GetPushedTexture()
  normal:SetDesaturated(true)
  normal:SetVertexColor(color[1], color[2], color[3], color[4])
  pushed:SetDesaturated(true)
  pushed:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function RefreshTrackerHeader(header)
  if not Skins.CanStyle() then return end
  local colors = Theme.GetColors()
  header.Background:SetColorTexture(unpack(colors.control))
  header.Text:SetTextColor(unpack(colors.accent))
  -- Blizzard selects the collapse atlas; only tint its existing texture slots.
  TintTrackerButton(header.MinimizeButton)
  if header.FilterButton then TintTrackerButton(header.FilterButton) end
end

local function SkinTrackerItem(button, icon)
  if styledButtons[button] then return end
  styledButtons[button] = true
  button:GetNormalTexture():SetTexture(nil)
  button:GetPushedTexture():SetTexture(nil)
  button:GetHighlightTexture():SetColorTexture(1, 1, 1, 0.2)
  Skins.Surface(button, true)
  Skins.Icon(icon)
end

local function SkinTrackerBlock(block)
  if not Skins.CanStyle() then return end
  -- Both regular and bonus quests attach their item as the last right-edge frame.
  local item = block.rightEdgeFrame
  if item and item.template == "QuestObjectiveItemButtonTemplate" then
    SkinTrackerItem(item, item.icon)
  end
  if block.SpellButton then SkinTrackerItem(block.SpellButton, block.SpellButton.Icon) end
end

local function SkinTrackerBar(wrapper)
  local bar = wrapper.Bar
  if styledBars[bar] then return end
  styledBars[bar] = true
  for _, key in ipairs(barArtwork) do
    local texture = bar[key]
    if texture then texture:SetTexture(nil) end
  end
  bar:SetStatusBarTexture(Theme.GetBarTexture())
  Skins.Surface(bar, true)
  if bar.Label then Theme.ApplyFont(bar.Label, "body") end
  if wrapper.Label then Theme.ApplyFont(wrapper.Label, "body") end
end

local function SkinTrackerProgressBar(module, key)
  if not Skins.CanStyle() then return end
  SkinTrackerBar(module.usedProgressBars[key])
end

local function SkinTrackerTimerBar(module, key)
  if not Skins.CanStyle() then return end
  SkinTrackerBar(module.usedTimerBars[key])
end

local function RefreshObjectiveTracker(frame)
  if not Skins.CanStyle() then return end
  RefreshTrackerHeader(frame.Header)
  for _, module in pairs(modules) do
    RefreshTrackerHeader(module.Header)
    module:EnumerateActiveBlocks(SkinTrackerBlock)
    if module.usedProgressBars then
      for _, wrapper in pairs(module.usedProgressBars) do SkinTrackerBar(wrapper) end
    end
    if module.usedTimerBars then
      for _, wrapper in pairs(module.usedTimerBars) do SkinTrackerBar(wrapper) end
    end
  end
end

Skins.Register("Blizzard_ObjectiveTracker", "ObjectiveTrackerFrame", {
  label = "Objective tracker",
  category = "Windows",
  manageControls = false,
  install = function(frame)
    modules = {
      ScenarioObjectiveTracker, UIWidgetObjectiveTracker, CampaignQuestObjectiveTracker,
      QuestObjectiveTracker, AdventureObjectiveTracker, AchievementObjectiveTracker,
      MonthlyActivitiesObjectiveTracker, ProfessionsRecipeTracker, BonusObjectiveTracker,
      WorldQuestObjectiveTracker, InitiativeTasksObjectiveTracker,
    }
    Skins.Hook(frame.Header, "SetCollapsed", RefreshTrackerHeader)
    for _, module in pairs(modules) do
      Skins.Hook(module.Header, "SetCollapsed", RefreshTrackerHeader)
      Skins.Hook(module, "AddBlock", function(_, block) SkinTrackerBlock(block) end)
      Skins.Hook(module, "GetProgressBar", SkinTrackerProgressBar)
      Skins.Hook(module, "GetTimerBar", SkinTrackerTimerBar)
    end
  end,
  onShow = RefreshObjectiveTracker,
  onTheme = RefreshObjectiveTracker,
})
