local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintMailItems()
  if not Skins.CanStyle() then return end
  for index = 1, INBOXITEMS_TO_DISPLAY do
    ns.Theme.ApplyFont(_G["MailItem" .. index .. "Subject"], "body")
  end
  for index = 1, ATTACHMENTS_MAX_SEND do
    -- The normal texture IS the attachment icon on this template.
    Skins.Icon(SendMailFrame.SendMailAttachments[index]:GetNormalTexture())
  end
end

Skins.Register("Blizzard_MailFrame", "MailFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(InboxFrameBg)
    Skins.Tab(MailFrameTab1)
    Skins.Tab(MailFrameTab2)
    for _, entry in ipairs({ { InboxPrevPageButton, "<" }, { InboxNextPageButton, ">" } }) do
      for _, region in ipairs({ entry[1]:GetRegions() }) do Skins.Hide(region) end
      Skins.Arrow(entry[1], entry[2])
    end
    Skins.Button(OpenAllMail, true)
    Skins.Font(InboxCurrentPage)
    for index = 1, INBOXITEMS_TO_DISPLAY do
      local item = _G["MailItem" .. index]
      -- MailItemTemplate's direct textures are its parchment edges and separator.
      for _, region in ipairs({ item:GetRegions() }) do
        if region:IsObjectType("Texture") then Skins.Hide(region) end
      end
      Skins.Surface(item, true, true)
      Skins.IconButton(item.Button, item.Button.Icon, true)
      Skins.Selection(item.Button:GetCheckedTexture(), 0.08)
      Skins.Hide(_G["MailItem" .. index .. "ButtonSlot"])
      Skins.Font(_G["MailItem" .. index .. "Sender"])
      Skins.Font(_G["MailItem" .. index .. "ExpireTime"]:GetFontString())
    end
    for _, region in ipairs({ SendMailFrame:GetRegions() }) do
      if region:IsObjectType("Texture") and region ~= SendMailErrorCoin then Skins.Hide(region) end
    end
    for _, suffix in ipairs({ "Left", "Middle", "Right" }) do Skins.Hide(_G["SendMailMoneyBg" .. suffix]) end
    Skins.Apply(_G, {
      Hide = { "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight" },
      Button = { "SendMailMailButton", "SendMailCancelButton" },
      EditBox = { "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" },
      Font = { "SendMailMoneyText", "SendMailSendMoneyButtonText", "SendMailCODButtonText" },
      Chrome = { "SendMailMoneyInset", "SendMailMoneyBg" },
    })
    for _, edit in ipairs({ SendMailNameEditBox, SendMailSubjectEditBox }) do
      Skins.Texts(edit)
      for _, suffix in ipairs({ "Left", "Middle", "Right" }) do Skins.Hide(_G[edit:GetName() .. suffix]) end
    end
    Skins.Panel(SendMailScrollFrame)
    Skins.ScrollBar(SendMailScrollFrame.ScrollBar)
    Skins.Font(SendMailBodyEditBox)
    Skins.CheckBox(SendMailSendMoneyButton)
    Skins.CheckBox(SendMailCODButton)
    for index = 1, ATTACHMENTS_MAX_SEND do
      local button = SendMailFrame.SendMailAttachments[index]
      Skins.Surface(button, true, true)
      ns.Theme.ApplyFont(button.Count, "body")
    end
    RepaintMailItems()
    Skins.Hook(_G, "InboxFrame_Update", RepaintMailItems)
    Skins.Hook(_G, "SendMailFrame_Update", RepaintMailItems)
  end,
  onShow = RepaintMailItems,
})
