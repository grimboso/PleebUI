local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme
local Templates = {}
ns.AuctionSkins = Templates
local texts = setmetatable({}, { __mode = "k" })
local headers = setmetatable({}, { __mode = "k" })

local function ApplyNativeFont(text)
  Theme.ApplyFont(text, "body")
end

function Templates.Fonts(frame)
  if frame:IsForbidden() then return end
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("FontString") and not texts[region] then
      texts[region] = true
      -- Native quality, sold, outbid and disabled colors retain their meaning.
      Theme.ApplyFont(region, "body")
      Skins.Hook(region, "SetFontObject", ApplyNativeFont)
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if not ns.BlizzardWindowControls.IsControl(child) then Templates.Fonts(child) end
  end
end

local function DiscoverHeaders(list)
  for _, header in ipairs({ list.HeaderContainer:GetChildren() }) do
    if header:IsObjectType("Button") and not headers[header] then
      headers[header] = true
      Skins.Button(header, true)
      -- Arrow is a separate sort indicator, not the button's decorative artwork.
    end
  end
end

function Templates.ListRows(list)
  Skins.ScrollRows(list.ScrollBox, Templates.Fonts, Templates.Fonts)
  DiscoverHeaders(list)
end

function Templates.List(list)
  Skins.Chrome(list)
  Skins.Surface(list.ScrollBox, true, true)
  Skins.ScrollBar(list.ScrollBar)
  Templates.Fonts(list.RefreshFrame)
  Skins.Font(list.ResultsText)
  Skins.Font(list.LoadingSpinner.SearchingText)
  -- Refresh glyph, striped rows, favorites and selection visibility stay native.
  Skins.Hook(list, "UpdateTableBuilderLayout", Templates.ListRows)
  Skins.Hook(list, "RefreshScrollFrame", Templates.ListRows)
  Templates.ListRows(list)
end

function Templates.ItemDisplay(display)
  Skins.Chrome(display)
  for _, region in ipairs({ display:GetRegions() }) do
    if region:IsObjectType("Texture") then
      local atlas = region:GetAtlas()
      if not issecretvalue(atlas) and atlas == "auctionhouse-itemheaderframe" then Skins.Hide(region) end
    end
  end
  Templates.Fonts(display)
  -- ItemButton masks, quality borders, empty-slot and favorite icons are content.
end

function Templates.MoneyInputs(frame)
  for _, edit in ipairs({ frame:GetChildren() }) do
    if edit:IsObjectType("EditBox") then
      Skins.EditBox(edit)
      local name = edit:GetName()
      if name then Skins.Hide(_G[name .. "Middle"]) end
      Templates.Fonts(edit)
    end
  end
end

function Templates.Quantity(frame)
  Skins.EditBox(frame.InputBox)
  Skins.Button(frame.MaxButton, true)
  Templates.Fonts(frame)
end
