local _, ns = ...
local Skins = ns.BlizzardSkins
local Theme = ns.Theme
local options = setmetatable({}, { __mode = "k" })
local buttons = setmetatable({}, { __mode = "k" })
local rewards = setmetatable({}, { __mode = "k" })
local containers = setmetatable({}, { __mode = "k" })

local function InstallButtons(container)
  for frame in container.buttonFramePool:EnumerateActive() do
    if not buttons[frame] then
      buttons[frame] = true
      Skins.Button(frame.Button)
      Theme.ApplyFont(frame.ListText, "body")
    end
  end
end

local function ObserveButtons(container)
  if not containers[container] then
    containers[container] = true
    Skins.Hook(container, "Setup", InstallButtons)
  end
  InstallButtons(container)
end

local function PaintReward(row)
  Skins.Font(row.Name)
  Skins.Font(row.Text)
end

local function InstallRewards(container)
  for row in container.rewardsPool:EnumerateActive() do
    if not rewards[row] then
      rewards[row] = true
      Skins.Icon(row.Icon)
      if row.itemButton then Skins.Icon(row.itemButton.icon) end
      Skins.Font(row.Count, "tiny")
      Skins.Hook(row, "Setup", PaintReward)
    end
    PaintReward(row)
  end
end

local function PaintOptionFonts(option)
  if option.Header then
    if option.Header.Contents then
      Skins.Font(option.Header.Contents.Text, "header")
    elseif option.Header.Text then
      -- Power choices use native rarity colors in their headings.
      Theme.ApplyFont(option.Header.Text, "header")
    end
  end
  if option.SubHeader then Skins.Font(option.SubHeader.Text) end
  if option.OptionText then
    Skins.Font(option.OptionText.String)
    Skins.Font(option.OptionText.HTML)
  end
  Skins.Font(option.Text, "header")
  Skins.Font(option.SubHeaderText)
end

local function PaintOption(option)
  -- Covenant cards bake their identifying artwork into the background texture.
  if not option.PreviewButton then Skins.Hide(option.Background) end
  Skins.Hide(option.ArtworkBorder)
  if option.Header then Skins.Hide(option.Header.Ribbon) end
  if option.SubHeader then Skins.Hide(option.SubHeader.BG) end
  if option.BackgroundContainer then
    Skins.Hide(option.BackgroundContainer.Background)
    Skins.Hide(option.BackgroundContainer.BackgroundBorder)
    Skins.Hide(option.BackgroundContainer.BackgroundBorderShineSilver)
    Skins.Hide(option.BackgroundContainer.BackgroundBorderShineGold)
  end
  if option.OptionButtonsContainer then ObserveButtons(option.OptionButtonsContainer) end
  if option.Rewards then InstallRewards(option.Rewards) end
  PaintOptionFonts(option)
end

local function RefreshOptions(frame)
  for option in frame.optionPools:EnumerateActive() do
    if not options[option] then
      options[option] = true
      Skins.Surface(option, false, true)
      if option.Selected then Skins.Selection(option.Selected, 0.12) end
      if option.SetupTextFonts then
        -- Reapply fonts before Blizzard measures the next description for layout.
        Skins.Hook(option, "SetupTextFonts", PaintOptionFonts)
      end
      Skins.Hook(option, "Setup", PaintOption)
    end
    PaintOption(option)
  end
  InstallButtons(frame.OptionButtonsContainer)
end

local function PaintShell(frame)
  Skins.Hide(frame.NineSlice)
  Skins.Hide(frame.BorderOverlay)
  Skins.Hide(frame.Header.Texture)
  Skins.Hide(frame.Background.BackgroundTile)
  Skins.Hide(frame.Title.Left)
  Skins.Hide(frame.Title.Middle)
  Skins.Hide(frame.Title.Right)
  Skins.Hide(frame.CloseButton.Border)
  Skins.Hide(frame.BorderLayerModelScene)
  Skins.Hide(frame.GridDivider)
  -- Floating power choices omit the main shell; mirror the native presentation.
  local shown = frame.Background:IsShown()
  if not issecretvalue(shown) then Skins.Surface(frame):SetShown(shown) end
  Skins.Font(frame.Title.Text, "title")
  Skins.Font(frame.GridNoSelectionHeader, "header")
  Skins.Font(frame.GridNoSelectionDescription)
  Skins.Font(frame.GridSelectionHeader, "header")
  Skins.Font(frame.GridSelectionDescription)
end

Skins.Register("Blizzard_PlayerChoice", "PlayerChoiceFrame", {
  label = "Player choices",
  category = "Choices",
  manageControls = false,
  install = function(frame)
    Skins.Surface(frame)
    Theme.WidgetSkins.CloseButton(frame.CloseButton)
    Skins.Paging(frame.PagingControls)
    ObserveButtons(frame.OptionButtonsContainer)
    Skins.Hook(frame.OptionButtonsContainer, "Layout", function() PaintShell(frame) end)
    Skins.Hook(frame, "SetupFrame", PaintShell)
    Skins.Hook(frame, "SetupOptions", RefreshOptions)
    Skins.Hook(frame, "OnPageChanged", RefreshOptions)
  end,
  onShow = function(frame)
    PaintShell(frame)
    RefreshOptions(frame)
  end,
  onTheme = PaintShell,
})
