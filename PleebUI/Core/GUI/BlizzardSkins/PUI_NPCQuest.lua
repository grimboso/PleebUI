local _, ns = ...
local Skins = ns.BlizzardSkins
local greetingButtons = setmetatable({}, { __mode = "k" })

local function RefreshQuestGreeting()
  for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
    if not greetingButtons[button] then
      greetingButtons[button] = true
      local highlight = button:GetHighlightTexture()
      highlight:SetColorTexture(1, 1, 1, 0.08)
      highlight:SetAllPoints(button)
    end
    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("LEFT", button, "LEFT", 3, 0)
    local textHeight, iconHeight = button:GetTextHeight(), button.Icon:GetHeight()
    if not issecretvalue(textHeight) and not issecretvalue(iconHeight) then
      button:SetHeight(math.max(textHeight + 2, iconHeight))
    end
  end
end

local function RefreshQuestAccessibility()
  if not QuestFrame:IsShown() then return end
  if QuestFrameGreetingPanel:IsShown() then
    QuestFrameGreetingPanel_OnShow()
    return
  end
  if QuestFrameProgressPanel:IsShown() then
    QuestFrameProgressPanel_OnShow(QuestFrameProgressPanel)
    return
  end

  local material = QuestFrame_GetMaterial()
  for _, panel in ipairs({ QuestFrameDetailPanel, QuestFrameRewardPanel }) do
    if panel:IsShown() then QuestFrame_SetMaterial(panel, material) end
  end
  if QuestInfoFrame.questLog then return end
  for _, text in ipairs({ QuestInfoTitleHeader, QuestInfoDescriptionHeader,
    QuestInfoObjectivesHeader, QuestInfoRewardsFrame.Header }) do
    QuestFrame_SetTitleTextColor(text, material)
  end
  for _, text in ipairs({ QuestInfoDescriptionText, QuestInfoObjectivesText, QuestInfoGroupSize,
    QuestInfoRewardText, QuestInfoTimerText, QuestInfoSpellObjectiveLearnLabel,
    QuestInfoRewardsFrame.ItemChooseText, QuestInfoRewardsFrame.ItemReceiveText,
    QuestInfoRewardsFrame.PlayerTitleText, QuestInfoRewardsFrame.QuestSessionBonusReward,
    QuestInfoRewardsFrame.XPFrame.ReceiveText }) do
    QuestFrame_SetTextColor(text, material)
  end
  for text in QuestInfoRewardsFrame.spellHeaderPool:EnumerateActive() do
    QuestFrame_SetTextColor(text, material)
  end
  if QuestInfoObjectivesFrame:IsShown() then QuestInfo_ShowObjectives() end
  if QuestInfoQuestType:IsShown() then QuestInfo_ShowType() end
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
    Skins.Hide(QuestGreetingFrameHorizontalBreak)
    RefreshQuestGreeting()
    Skins.Hook(_G, "QuestFrameGreetingPanel_OnShow", RefreshQuestGreeting)
    CVarCallbackRegistry:RegisterCallback("questTextContrast", RefreshQuestAccessibility, frame)
    EventRegistry:RegisterCallback("TextSizeManager.OnTextScaleUpdated", RefreshQuestAccessibility, frame)
  end,
  onShow = RefreshQuestGreeting,
  onTheme = RefreshQuestAccessibility,
})
