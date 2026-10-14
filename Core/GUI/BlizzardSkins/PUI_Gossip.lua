local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintGossipRow(row)
  if not Skins.CanStyle() then return end
  local text = row.GreetingText or (row:IsObjectType("Button") and row:GetFontString())
  if not text then return end
  if row:IsObjectType("Button") then
    row.Icon:ClearAllPoints()
    row.Icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    local textHeight, iconHeight = row:GetTextHeight(), row.Icon:GetHeight()
    if not issecretvalue(textHeight) and not issecretvalue(iconHeight) then
      row:SetHeight(math.max(textHeight, iconHeight) + 10)
    end
  end
end

local function InstallGossipRow(row)
  RepaintGossipRow(row)
  if row:IsObjectType("Button") then
    local highlight = row:GetHighlightTexture()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    highlight:SetAllPoints(row)
    Skins.Hook(row, "Resize", RepaintGossipRow)
  end
end

local function RefreshGossipLayout(frame)
  if not Skins.CanStyle() then return end
  local scrollBox = frame.GreetingPanel.ScrollBox
  scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
  Skins.ScrollRows(scrollBox, InstallGossipRow, RepaintGossipRow)
end

local function ConfigureGossipLayout(frame)
  if not Skins.CanStyle() then return end
  local view = frame.GreetingPanel.ScrollBox:GetView()
  view:SetPadding(4, 4, 0, 0, 4)
  -- Blizzard measures hidden template instances, separate from the visible rows.
  view:SetElementExtentCalculator(function(_, elementData)
    local greeting = elementData.greetingTextFrame
    if greeting then
      greeting.GreetingText:SetText(elementData.text)
      RepaintGossipRow(greeting)
      local height = greeting.GreetingText:GetHeight()
      if issecretvalue(height) then return height end
      return height + 10
    end
    local button = elementData.titleOptionButton or elementData.availableQuestButton or elementData.activeQuestButton
    if button then
      button:Setup(elementData.info)
      RepaintGossipRow(button)
      return button:GetHeight()
    end
    return 16
  end)
  RefreshGossipLayout(frame)
end

Skins.Register("Blizzard_UIPanels_Game", "GossipFrame", {
  install = function(frame)
    Skins.Shell(frame)
    frame.Background:SetAlpha(1)
    Skins.Button(frame.GreetingPanel.GoodbyeButton, true)
    Skins.ScrollBar(frame.GreetingPanel.ScrollBar)
    Skins.Hook(frame, "UpdateScrollBox", ConfigureGossipLayout)
    Skins.Hook(frame, "UpdateTheme", RefreshGossipLayout)
    EventRegistry:RegisterCallback("TextSizeManager.OnTextScaleUpdated", function()
      if frame:IsShown() then RefreshGossipLayout(frame) end
    end, frame)
    ConfigureGossipLayout(frame)
  end,
  onShow = RefreshGossipLayout,
  onTheme = RefreshGossipLayout,
})
