local _, ns = ...
local Skins = ns.BlizzardSkins
local spellRows = setmetatable({}, { __mode = "k" })
local transparent = { 0, 0, 0, 0 }

local function RefreshSpellHitArea(frame)
  local button = frame.Button
  local buttonWidth, buttonHeight = button:GetWidth(), button:GetHeight()
  local width, height = frame:GetWidth(), frame:GetHeight()
  if issecretvalue(buttonWidth) or issecretvalue(buttonHeight) or issecretvalue(width) or issecretvalue(height) then return end
  local verticalInset = (buttonHeight - height) / 2
  -- The native button stays anchored at LEFT; expand interaction without moving its flyout.
  button:SetHitRectInsets(0, buttonWidth - width, verticalInset, verticalInset)
end

local function SkinSpell(frame)
  local button = frame.Button
  if not button then
    Skins.Texts(frame)
    return
  end
  local state = spellRows[frame]
  if not state then
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:EnableMouse(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(frame)
    button:SetHighlightTexture(highlight)
    state = { border = border, highlight = highlight }
    spellRows[frame] = state
    frame:HookScript("OnSizeChanged", RefreshSpellHitArea)
  end
  ns.Theme.SetSquareBackdrop(state.border, {
    bg = transparent,
    border = ns.Theme.GetColors().border,
  }, 1)
  Skins.Selection(state.highlight, 0.08)
  -- Native hover changes alpha; transparent color keeps its backplate unfilled.
  frame.Backplate:SetColorTexture(0, 0, 0, 0)
  button.IconHighlight:SetColorTexture(0, 0, 0, 0)
  Skins.Hide(button.Border)
  button.BorderSheen:SetTexture(nil)
  Skins.Hide(button.BorderSheen)
  button.Icon:RemoveMaskTexture(button.IconMask)
  Skins.Icon(button.Icon)
  RefreshSpellHitArea(frame)
  Skins.Font(frame.Name)
  Skins.Font(frame.SubName)
  ns.Theme.ApplyFont(frame.RequiredLevel, "body")
  Skins.Hook(frame, "UpdateVisuals", function(item)
    SkinSpell(item)
  end)
end

local function RefreshSpells()
  for _, frame in PlayerSpellsFrame.SpellBookFrame.PagedSpellsFrame:EnumerateFrames() do SkinSpell(frame) end
end

local function RefreshSpellBook(frame)
  Skins.Shell(frame)
  Skins.TabSystem(frame.TabSystem)
  local book = frame.SpellBookFrame
  book.BookCornerFlipbook:SetTexture(nil)
  Skins.Apply(book, {
    Hide = { "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" },
    EditBox = { "SearchBox" },
    Dropdown = { "SettingsDropdown" },
    Panel = { "SearchPreviewContainer" },
    Paging = { "PagedSpellsFrame.PagingControls" },
  })
  Skins.TabSystem(book.CategoryTabSystem)
  Skins.IconButton(book.AssistedCombatRotationSpellFrame.Button, book.AssistedCombatRotationSpellFrame.Button.Icon)
  Skins.Hook(book.CategoryTabSystem, "AddTab", function(system)
    Skins.TabSystem(system)
  end)
  Skins.Hook(frame.TabSystem, "AddTab", function(system)
    Skins.TabSystem(system)
  end)
  RefreshSpells()
end

Skins.Register("Blizzard_PlayerSpells", "PlayerSpellsFrame", function(frame)
  RefreshSpellBook(frame)
  Skins.Hook(frame, "UpdatePortrait", function(updatedFrame)
    Skins.Icon(updatedFrame.PortraitContainer.portrait)
  end)
  Skins.Hook(frame.SpellBookFrame, "SetMinimized", function()
    RefreshSpellBook(frame)
  end)
  if not ns.BlizzardSkins.spellBookDisplayHook then
    ns.BlizzardSkins.spellBookDisplayHook = true
    EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged", RefreshSpells)
  end
end)
