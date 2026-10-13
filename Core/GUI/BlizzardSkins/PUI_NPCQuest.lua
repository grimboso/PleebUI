local _, ns = ...
local Skins = ns.BlizzardSkins
local greetingButtons = setmetatable({}, { __mode = "k" })

local function RefreshQuestGreeting()
  if not Skins.CanStyle() then return end
  for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
    if not greetingButtons[button] then
      greetingButtons[button] = true
      local highlight = button:GetHighlightTexture()
      highlight:SetColorTexture(1, 1, 1, 0.08)
      highlight:SetAllPoints(button)
    end
    ns.Theme.ApplyFont(button:GetFontString(), "body")
    local textHeight, iconHeight = button:GetTextHeight(), button.Icon:GetHeight()
    if not issecretvalue(textHeight) and not issecretvalue(iconHeight) then
      button:SetHeight(math.max(textHeight + 2, iconHeight))
    end
  end
end

Skins.Register("Blizzard_UIPanels_Game", "QuestFrame", {
  install = function(frame)
    Skins.Shell(frame)
    QuestFramePortrait:ClearAllPoints()
    QuestFramePortrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    QuestFramePortrait:SetSize(36, 36)
    for _, button in ipairs({ QuestFrameAcceptButton, QuestFrameDeclineButton,
      QuestFrameCompleteButton, QuestFrameCompleteQuestButton, QuestFrameGoodbyeButton,
      QuestFrameGreetingGoodbyeButton }) do Skins.Button(button, true) end
    for _, scroll in ipairs({ QuestDetailScrollFrame, QuestProgressScrollFrame,
      QuestRewardScrollFrame, QuestGreetingScrollFrame }) do Skins.ScrollBar(scroll.ScrollBar) end
    -- Keep material/contrast backgrounds paired with Blizzard's native text colors.
    -- Shared QuestInfo reward widgets also serve the map; this owner leaves them intact.
    for _, text in ipairs({ GreetingText, QuestProgressText, QuestProgressRequiredMoneyText }) do
      ns.Theme.ApplyFont(text, "body")
    end
    for _, text in ipairs({ CurrentQuestsText, AvailableQuestsText,
      QuestProgressTitleText, QuestProgressRequiredItemsText }) do ns.Theme.ApplyFont(text, "header") end
    ns.Theme.ApplyFont(frame.AccountCompletedNotice.Text, "body")
    Skins.Hide(QuestGreetingFrameHorizontalBreak)
    RefreshQuestGreeting()
    Skins.Hook(_G, "QuestFrameGreetingPanel_OnShow", RefreshQuestGreeting)
  end,
  onShow = RefreshQuestGreeting,
  onTheme = RefreshQuestGreeting,
})
