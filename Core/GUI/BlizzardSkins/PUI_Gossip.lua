local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintGossipRow(row)
  if not Skins.CanStyle() then return end
  local text = row.GreetingText or (row:IsObjectType("Button") and row:GetFontString())
  if not text then return end
  ns.Theme.ApplyFont(text, "body")
end

local function InstallGossipRow(row)
  RepaintGossipRow(row)
  if row:IsObjectType("Button") then
    local highlight = row:GetHighlightTexture()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    highlight:SetAllPoints(row)
  end
end

Skins.Register("Blizzard_UIPanels_Game", "GossipFrame", {
  install = function(frame)
    Skins.Shell(frame)
    -- Native text contains inline dark colors. Keep its themed content background
    -- rather than rewrite NPC dialogue, quest titles or hyperlink text.
    frame.Background:SetAlpha(1)
    Skins.Button(frame.GreetingPanel.GoodbyeButton, true)
    Skins.ScrollBar(frame.GreetingPanel.ScrollBar)
    Skins.ScrollRows(frame.GreetingPanel.ScrollBox, InstallGossipRow, RepaintGossipRow)
  end,
  onShow = function(frame)
    Skins.ScrollRows(frame.GreetingPanel.ScrollBox, InstallGossipRow, RepaintGossipRow)
  end,
})
