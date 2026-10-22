local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshDungeonReady(dialog)
  Skins.Panel(dialog)
  Skins.Apply(dialog, {
    Hide = { "background", "bottomArt", "instanceInfo.underline" },
    Button = { "enterButton", "leaveButton" },
    Font = { "label", "instanceInfo.name", "instanceInfo.statusText" },
  })
  Skins.Apply(_G, {
    Font = { "LFGDungeonReadyDialogYourRoleDescription", "LFGDungeonReadyDialogRoleLabel",
      "LFGDungeonReadyDialogRandomInProgressFrameStatusText", "LFGDungeonReadyDialogRewardsFrameLabel" },
  })
  ns.Theme.WidgetSkins.CloseButton(LFGDungeonReadyDialogCloseButton)
  for _, region in ipairs({ dialog.randomInProgress:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
end

Skins.Register("Blizzard_GroupFinder", "LFGDungeonReadyDialog", function(dialog)
  RefreshDungeonReady(dialog)
  Skins.Hook(_G, "LFGDungeonReadyPopup_Update", function()
    RefreshDungeonReady(dialog)
  end)
end)
