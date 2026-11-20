local _, ns = ...
local Skins = ns.BlizzardSkins
local itemButtons = setmetatable({}, { __mode = "k" })
local bankTabs = setmetatable({}, { __mode = "k" })

function Skins.BankItemButton(button)
  if itemButtons[button] then return end
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button.Background)
  Skins.Surface(button)
  Skins.Icon(button.icon)
  Skins.Font(button.Count, "tiny")
  itemButtons[button] = true
end

local function SkinBankItems(panel)
  for button in panel.itemButtonPool:EnumerateActive() do
    Skins.BankItemButton(button)
  end
end

local function SkinBankTab(button)
  if bankTabs[button] then return end
  Skins.Button(button)
  Skins.Icon(button.Icon)
  Skins.Selection(button.SelectedTexture, 0.25)
  bankTabs[button] = true
end

local function SkinBankTabs(panel)
  for button in panel.bankTabPool:EnumerateActive() do SkinBankTab(button) end
  SkinBankTab(panel.PurchaseTab)
end

local function SkinForeverBankPageTabs(frame)
  for tab in frame.bankPageTabPool:EnumerateActive() do
    if not bankTabs[tab] then
      bankTabs[tab] = true
      Skins.Hide(tab.Background)
      Skins.Surface(tab, true)
      tab.Icon:RemoveMaskTexture(tab.Mask)
      for _, texture in ipairs({ tab.SelectedTexture, tab.HighlightTexture, tab.TabGlow }) do
        texture:ClearAllPoints()
        texture:SetAllPoints(tab.Icon)
        Skins.Selection(texture, 0.25)
      end
    end
  end
end

local function SkinForeverBankBags(frame)
  for button in frame.itemButtonBagPool:EnumerateActive() do
    Skins.BankItemButton(button)
  end
end

local function SkinBankCheckbox(checkbox)
  Skins.CheckBox(checkbox)
  Skins.Hook(checkbox, "Init", function(control) Skins.Font(control.Text) end)
end

Skins.Register("Blizzard_UIPanels_Game", "BankFrame", {
  label = "Bank and Warband bank", category = "Bags",
  manageControls = false,
  install = function(frame)
    Skins.Shell(frame)
    if not ns.Client.IsForever then Skins.TabSystem(frame.TabSystem) end
    Skins.EditBox(frame.BankItemSearchBox)
    local panel = frame.BankPanel
    Skins.Hide(panel.NineSlice)
    Skins.Hide(panel.EdgeShadows)
    if not ns.Client.IsForever then Skins.Font(panel.Header.Text, "header") end
    Skins.Surface(panel.AutoSortButton, true)

    local money = panel.MoneyFrame
    Skins.StripRegions(money.Border)
    Skins.Surface(money.Border, true)
    Skins.Button(money.WithdrawButton)
    Skins.Button(money.DepositButton)

    if ns.Client.IsForever then
      Skins.Font(frame.BagText)
      Skins.Font(frame.BagCost)
      Skins.Button(panel.PurchaseButton)
      Skins.Hook(frame, "RefreshPageTabs", SkinForeverBankPageTabs)
      Skins.Hook(frame, "RefreshBagButtons", SkinForeverBankBags)
      SkinForeverBankPageTabs(frame)
      SkinForeverBankBags(frame)
    else
      local deposit = panel.AutoDepositFrame
      Skins.Button(deposit.DepositButton)
      SkinBankCheckbox(deposit.IncludeReagentsCheckbox)
    end

    for _, prompt in ipairs(panel.Prompts) do
      Skins.StripRegions(prompt)
      Skins.Font(prompt.Title, "title")
      Skins.Font(prompt.PromptText)
    end
    local cost = panel.PurchasePrompt.TabCostFrame
    Skins.Font(cost.TabCost)
    Skins.Button(cost.PurchaseButton)

    local settings = panel.TabSettingsMenu.DepositSettingsMenu
    for _, region in ipairs({ settings:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Font(settings.AssignExpansionHeader)
    Skins.Font(settings.AssignSettingsHeader)
    Skins.Font(settings.CleanUpSettingsHeader)
    Skins.Dropdown(settings.ExpansionFilterDropdown)
    Skins.DropdownMenu(settings.ExpansionFilterDropdown)
    for _, checkbox in ipairs(settings.DepositSettingsCheckboxes) do SkinBankCheckbox(checkbox) end

    -- Native pools rebuild on tab switches and purchases, not on every item update.
    Skins.Hook(panel, "GenerateItemSlotsForSelectedTab", SkinBankItems)
    SkinBankItems(panel)
    if panel.bankTabPool then
      Skins.Hook(panel, "RefreshBankTabs", SkinBankTabs)
      SkinBankTabs(panel)
    end
  end,
})

Skins.Register("Blizzard_UIPanels_Game", "BankCleanUpConfirmationPopup", {
  label = "Bank sorting confirmation", category = "Bags",
  manageControls = false,
  install = function(frame)
    Skins.Panel(frame)
    Skins.Font(frame.Text)
    Skins.Font(frame.HidePopupCheckbox.Label)
    Skins.CheckBox(frame.HidePopupCheckbox.Checkbox)
    Skins.Button(frame.AcceptButton)
    Skins.Button(frame.CancelButton)
  end,
})
