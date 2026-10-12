local _, ns = ...
local Skins = ns.BlizzardSkins

local function SkinSpell(frame)
  local button = frame.Button
  if not button then
    Skins.Texts(frame)
    return
  end
  local accent = ns.Theme.GetColors().accent
  frame.Backplate:SetColorTexture(accent[1], accent[2], accent[3], 0.2)
  frame.Backplate:SetAllPoints(frame)
  button.IconHighlight:SetColorTexture(1, 1, 1, 0.12)
  button.IconHighlight:SetAllPoints(button.Icon)
  Skins.Hide(button.Border)
  button.BorderSheen:SetTexture(nil)
  Skins.Hide(button.BorderSheen)
  button.Icon:RemoveMaskTexture(button.IconMask)
  Skins.IconButton(button, button.Icon)
  Skins.Font(frame.Name)
  Skins.Font(frame.SubName)
  ns.Theme.ApplyFont(frame.RequiredLevel, "body")
  Skins.Hook(frame, "UpdateVisuals", function(item)
    if Skins.CanStyle() then SkinSpell(item) end
  end)
end

local function RefreshSpells()
  if not Skins.CanStyle() then return end
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
    if Skins.CanStyle() then Skins.TabSystem(system) end
  end)
  Skins.Hook(frame.TabSystem, "AddTab", function(system)
    if Skins.CanStyle() then Skins.TabSystem(system) end
  end)
  RefreshSpells()
end

Skins.Register("Blizzard_PlayerSpells", "PlayerSpellsFrame", function(frame)
  RefreshSpellBook(frame)
  Skins.Hook(frame.SpellBookFrame, "SetMinimized", function()
    if Skins.CanStyle() then RefreshSpellBook(frame) end
  end)
  if not ns.BlizzardSkins.spellBookDisplayHook then
    ns.BlizzardSkins.spellBookDisplayHook = true
    EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged", RefreshSpells)
  end
end)
