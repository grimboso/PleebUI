local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_FrameXML", "StackSplitFrame", {
  install = function(frame)
    Skins.Panel(frame)
    Skins.Hide(frame.SingleItemSplitBackground)
    Skins.Hide(frame.MultiItemSplitBackground)
    Skins.Font(frame.StackSplitText)
    Skins.Font(frame.StackItemCountText)
    Skins.Arrow(frame.LeftButton, "<")
    Skins.Arrow(frame.RightButton, ">")
    Skins.Button(frame.OkayButton, true)
    Skins.Button(frame.CancelButton, true)
    -- ChooseFrameType retains native size, text, keyboard and item-owner behavior.
  end,
})
