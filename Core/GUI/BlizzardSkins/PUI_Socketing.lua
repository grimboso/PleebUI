local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_ItemSocketingUI", "ItemSocketingFrame", {
  install = function(frame)
    Skins.Shell(frame)
    -- All direct root textures in ItemSocketingFrame.xml are parchment, gold edges and nubs.
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") then
        Skins.Hide(region)
      elseif region:IsObjectType("FontString") then
        Skins.Font(region, "title")
      end
    end
    Skins.ScrollBar(frame.ScrollFrame.ScrollBar)
    Skins.Button(frame.SocketingContainer.ApplySocketsButton)
    for _, socket in ipairs(frame.SocketingContainer.SocketFrames) do
      Skins.Hide(socket.LeftFiligree)
      Skins.Hide(socket.RightFiligree)
      Skins.Icon(socket.Icon)
      ns.Theme.ApplyFont(socket.BracketFrame.ColorText, "body")
    end
    -- Gem-type backgrounds, open/closed brackets, match shine and the item tooltip remain native.
  end,
})
