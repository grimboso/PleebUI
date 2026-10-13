local _, ns = ...
local Skins = ns.BlizzardSkins
local Templates = {}
ns.ProfessionSkins = Templates
local items = setmetatable({}, { __mode = "k" })
local slots = setmetatable({}, { __mode = "k" })
local tabs = setmetatable({}, { __mode = "k" })
local forms = setmetatable({}, { __mode = "k" })
local flyouts = setmetatable({}, { __mode = "k" })
local activeFlyout
local flyoutHooked = false

function Templates.Fonts(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

function Templates.Item(button)
  if not button or items[button] then return end
  items[button] = true
  Skins.Surface(button, true, true)
  Skins.Hide(button.SlotBackground)
  Skins.Icon(button.Icon)
  Templates.Fonts(button)
  -- Normal/pushed slots can hold an add-reagent symbol; quality/lock state stays native.
end

function Templates.Spinner(edit)
  Skins.EditBox(edit)
  for _, region in ipairs({ edit:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
  Skins.Arrow(edit.DecrementButton, "<")
  Skins.Arrow(edit.IncrementButton, ">")
end

function Templates.Note(note)
  Skins.Hide(note.Border)
  Skins.Surface(note, true, true)
  Templates.Fonts(note.TitleBox)
  local edit = note.ScrollingEditBox.ScrollBox.EditBox
  ns.Theme.ApplyFont(edit, "body")
  Skins.Hook(edit, "SetFontObject", function(text)
    if Skins.CanStyle() then ns.Theme.ApplyFont(text, "body") end
  end)
end

function Templates.Tabs(system)
  if not Skins.CanStyle() then return end
  for _, tab in ipairs({ system:GetChildren() }) do
    if tab:IsObjectType("Button") and not tabs[tab] then
      tabs[tab] = true
      Skins.Tab(tab)
    end
  end
end

function Templates.Rank(bar)
  Skins.Hide(bar.Border)
  Skins.Hide(bar.Background)
  Skins.Surface(bar, true, true)
  ns.Theme.ApplyFont(bar.Rank.Text, "tiny")
  bar.Rank.Text:SetHeight(0)
  Skins.Arrow(bar.ExpansionDropdownButton, "v")
  -- Fill, mask and flare are owned by the native profession/rank animation.
end

local function RepaintRecipeRow(row)
  if not Skins.CanStyle() then return end
  if row.Label then
    ns.Theme.ApplyFont(row.Label, "body")
    row.Label:SetHeight(0)
  end
  if row.Count then
    ns.Theme.ApplyFont(row.Count, "body")
    row.Count:SetHeight(0)
  end
end

local function InstallRecipeRow(row)
  RepaintRecipeRow(row)
  if row.LeftPiece then
    Skins.Hide(row.LeftPiece)
    Skins.Hide(row.CenterPiece)
    Skins.Hide(row.RightPiece)
    Skins.Surface(row, true, true)
    for _, border in ipairs({ row.RankBar.BorderLeft, row.RankBar.BorderMid, row.RankBar.BorderRight }) do Skins.Hide(border) end
    ns.Theme.ApplyFont(row.RankBar.Rank, "tiny")
    Skins.Hook(row.Label, "SetFontObject", function() RepaintRecipeRow(row) end)
  end
  if row.SelectedOverlay then
    row.SelectedOverlay:SetDrawLayer("BACKGROUND", 1)
    row.SelectedOverlay:SetAllPoints(row)
    Skins.Selection(row.SelectedOverlay, 0.07)
    row.HighlightOverlay:SetDrawLayer("HIGHLIGHT")
    row.HighlightOverlay:SetAllPoints(row)
    row.HighlightOverlay:SetColorTexture(1, 1, 1, 0.06)
    ns.Theme.ApplyFont(row.SkillUps.Text, "tiny")
  end
end

function Templates.RecipeList(list)
  Skins.Chrome(list)
  Skins.Hide(list.BackgroundNineSlice)
  Skins.EditBox(list.SearchBox)
  Skins.Dropdown(list.FilterDropdown)
  Skins.ScrollBar(list.ScrollBar)
  Skins.Font(list.NoResultsText)
  Skins.ScrollRows(list.ScrollBox, InstallRecipeRow, RepaintRecipeRow)
end

function Templates.RecipeRows(list)
  Skins.ScrollRows(list.ScrollBox, InstallRecipeRow, RepaintRecipeRow)
end

local function RepaintTableRow(row)
  if not Skins.CanStyle() then return end
  for _, cell in ipairs({ row:GetChildren() }) do Templates.Fonts(cell) end
end

local function InstallTableRow(row)
  row.HighlightTexture:SetColorTexture(1, 1, 1, 0.08)
  row.HighlightTexture:SetDrawLayer("BACKGROUND", 1)
  RepaintTableRow(row)
end

function Templates.TableRows(list)
  if not Skins.CanStyle() then return end
  Skins.ScrollRows(list.ScrollBox, InstallTableRow, RepaintTableRow)
  for _, header in ipairs({ list.HeaderContainer:GetChildren() }) do Templates.Fonts(header) end
end

function Templates.TableList(list)
  Skins.Chrome(list)
  Skins.ScrollBar(list.ScrollBar)
  Skins.Font(list.ResultsText)
  Templates.TableRows(list)
end

local function SkinReagentSlot(slot)
  if not slots[slot] then
    slots[slot] = true
    Templates.Item(slot.Button)
    Skins.CheckBox(slot.Checkbox)
    ns.Theme.ApplyFont(slot.Name, "body")
  end
end

local function RepaintFlyoutRow(button)
  if not Skins.CanStyle() then return end
  Templates.Fonts(button)
end

local function RefreshFlyout()
  if not activeFlyout or not Skins.CanStyle() then return end
  local shown = activeFlyout:IsVisible()
  if issecretvalue(shown) or not shown then return end
  local frame = activeFlyout
  if not flyouts[frame] then
    flyouts[frame] = true
    Skins.Panel(frame)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.CheckBox(frame.HideUnownedCheckbox)
    Templates.Item(frame.UndoItem)
    Templates.Fonts(frame)
    Skins.Hook(frame, "InitializeContents", RefreshFlyout)
  end
  Skins.ScrollRows(frame.ScrollBox, Templates.Item, RepaintFlyoutRow)
end

function Templates.ObserveFlyouts()
  if flyoutHooked then return end
  flyoutHooked = true
  Skins.Hook(_G, "OpenProfessionsItemFlyout", function(_, _, behavior)
    activeFlyout = behavior.flyout
    RefreshFlyout()
  end)
end

function Templates.RefreshForm(form)
  if not Skins.CanStyle() then return end
  for slot in form.reagentSlotPool:EnumerateActive() do SkinReagentSlot(slot) end
  for _, key in ipairs({ "salvageSlot", "enchantSlot" }) do
    local slot = form[key]
    if slot then
      Templates.Item(slot.Button)
      ns.Theme.ApplyFont(slot.Name, "body")
    end
  end
  RefreshFlyout()
end

function Templates.Schematic(form)
  if not forms[form] then
    forms[form] = true
    Skins.Chrome(form)
    Skins.Hide(form.MinimalBackground)
    Templates.Fonts(form)
    Templates.Fonts(form.Details)
    for _, container in ipairs({ form.Reagents, form.OptionalReagents, form.FinishingReagents, form.Concentrate }) do Templates.Fonts(container) end
    Templates.Fonts(form.FirstCraftBonus)
    ns.Theme.ApplyFont(form.RecipeSourceButton.Text, "body")
    ns.Theme.ApplyFont(form.OutputIcon.Count, "body")
    Skins.CheckBox(form.TrackRecipeCheckbox)
    Skins.CheckBox(form.AllocateBestQualityCheckbox)
    Skins.Dropdown(form.RecipeLevelDropdown)
    Skins.Hook(form, "Init", Templates.RefreshForm)
    Templates.ObserveFlyouts()
  end
  Templates.RefreshForm(form)
end
