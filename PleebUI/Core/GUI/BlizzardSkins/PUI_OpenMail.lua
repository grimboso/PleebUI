local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_MailFrame", "OpenMailFrame", {
  install = function(frame)
    Skins.Shell(frame)
    -- This frame's direct textures are decorative horizontal rules; attachments are children.
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Texts(frame)
    Skins.Apply(_G, {
      Hide = { "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight" },
      Button = { "OpenMailReplyButton", "OpenMailDeleteButton", "OpenMailCancelButton", "OpenMailReportSpamButton" },
      Font = { "OpenMailSubject", "OpenMailSender.Name", "OpenMailBodyText" },
    })
    Skins.ScrollBar(OpenMailScrollFrame.ScrollBar)
    Skins.Texts(OpenMailInvoiceFrame)
    Skins.Texts(ConsortiumMailFrame)
    Skins.Texts(ConsortiumMailFrame.CommissionPaidDisplay)
    Skins.Hide(ConsortiumMailFrame.CommissionPaidDisplay.Separator)
    for index = 1, ATTACHMENTS_MAX_RECEIVE do
      local button = _G["OpenMailAttachmentButton" .. index]
      Skins.IconButton(button, button.icon, true)
    end
    Skins.IconButton(OpenMailLetterButton, OpenMailLetterButton.icon, true)
    Skins.IconButton(OpenMailMoneyButton, OpenMailMoneyButton.icon, true)
  end,
})
