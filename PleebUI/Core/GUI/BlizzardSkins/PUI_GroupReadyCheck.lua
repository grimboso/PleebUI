local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_FrameXML", "ReadyCheckListenerFrame", {
  install = function(frame)
    -- ReadyCheckFrame is empty and also appears for the initiator without this child.
    Skins.Panel(frame)
    Skins.Font(frame.TitleContainer.TitleText, "title")
    Skins.Font(ReadyCheckFrameText)
    Skins.Button(ReadyCheckFrameYesButton)
    Skins.Button(ReadyCheckFrameNoButton)
    ReadyCheckPortrait:ClearAllPoints()
    ReadyCheckPortrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    ReadyCheckPortrait:SetSize(36, 36)
  end,
  controlsFrame = function(frame)
    return frame:GetParent()
  end,
  controlsParent = function(frame)
    return frame
  end,
})
