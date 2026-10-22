local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme
local styledFrames = setmetatable({}, { __mode = "k" })
local scrollBoxes = setmetatable({}, { __mode = "k" })
local framePools = setmetatable({}, { __mode = "k" })
local skinName = "AuctionatorAHTabsContainer"
local driver = CreateFrame("Frame")
local hooked = false
local loggedIn = false
local nextDialog = 1

local function RefreshFont(text)
  Theme.ApplyFont(text, "body")
end

local SkinFrame

local function SkinChildren(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    SkinFrame(child)
  end
end

SkinFrame = function(frame)
  if styledFrames[frame] or frame:IsForbidden() then return end
  styledFrames[frame] = true
  -- Capture Auctionator's children before the skins create their own surfaces.
  local children = { frame:GetChildren() }

  if frame.Track and frame.Back and frame.Forward then
    Skins.ScrollBar(frame)
    Skins.Hide(frame.Backplate)
    Skins.Hide(frame.Back.Overlay)
    Skins.Hide(frame.Forward.Overlay)
    return
  elseif frame.ScrollUpButton then
    Skins.ScrollBar(frame)
    return
  elseif frame.MiddleActive then
    Skins.Tab(frame)
  elseif frame:IsObjectType("CheckButton") then
    Skins.CheckBox(frame)
  elseif frame:IsObjectType("EditBox") then
    Skins.EditBox(frame)
  elseif frame:IsObjectType("DropdownButton") then
    Skins.Dropdown(frame)
  elseif frame:IsObjectType("Button") and frame:GetFontString() then
    Skins.Button(frame)
  elseif frame.NineSlice or frame.Bg or (frame.Border and frame.Border:IsObjectType("Frame")) then
    Skins.Panel(frame)
  end

  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("FontString") then
      RefreshFont(region)
      Skins.Hook(region, "SetFontObject", RefreshFont)
    end
  end

  if frame.CloseButton then
    Theme.WidgetSkins.CloseButton(frame.CloseButton)
    styledFrames[frame.CloseButton] = true
  end
  if frame.CloseDialog then
    Theme.WidgetSkins.CloseButton(frame.CloseDialog)
    styledFrames[frame.CloseDialog] = true
  end

  if frame.ScrollBox and frame.ScrollBox.ForEachFrame then
    scrollBoxes[frame.ScrollBox] = true
    Skins.ScrollRows(frame.ScrollBox, SkinFrame, SkinChildren)
  end
  if frame.ScrollArea and frame.HeaderContainer then
    Skins.Hook(frame, "InitializeTable", function(list)
      SkinChildren(list.HeaderContainer)
    end)
  end
  if frame.checkBoxPool then
    framePools[frame.checkBoxPool] = true
    Skins.Hook(frame, "RefreshLists", function(list)
      for checkbox in list.checkBoxPool:EnumerateActive() do
        SkinFrame(checkbox)
      end
    end)
  end
  if frame.groupPool and frame.buttonPool then
    framePools[frame.groupPool] = true
    framePools[frame.buttonPool] = true
    Skins.Hook(frame, "UpdateFromExisting", function(view)
      for group in view.groupPool:EnumerateActive() do SkinFrame(group) end
      for button in view.buttonPool:EnumerateActive() do SkinFrame(button) end
    end)
  end

  for _, child in ipairs(children) do SkinFrame(child) end
end

local function SkinDialogs()
  local dialog = _G["AuctionatorDialog" .. nextDialog]
  while dialog do
    Skins.StripRegions(dialog)
    SkinFrame(dialog)
    nextDialog = nextDialog + 1
    dialog = _G["AuctionatorDialog" .. nextDialog]
  end
end

local function SkinAuctionator(container)
  if not ns.BlizzardSkinOptions.IsEnabled("AuctionHouseFrame") then return end
  for _, tab in ipairs(container.Tabs) do
    SkinFrame(tab)
    SkinFrame(tab.frameRef)
  end
  -- Buying panes are created after the tab container and parented to Shopping.
  for _, name in ipairs({ "AuctionatorBuyItemFrame", "AuctionatorBuyCommodityFrame" }) do
    local frame = _G[name]
    if frame then SkinFrame(frame) end
  end
  for scrollBox in pairs(scrollBoxes) do
    scrollBox:ForEachFrame(function(row)
      SkinFrame(row)
      SkinChildren(row)
    end)
  end
  for pool in pairs(framePools) do
    for frame in pool:EnumerateActive() do SkinFrame(frame) end
  end
  SkinDialogs()
end

Skins.Register("Auctionator", skinName, {
  label = "Auctionator", category = "Auction house", manageControls = false,
  install = SkinAuctionator,
  onShow = SkinAuctionator,
  onTheme = SkinAuctionator,
})

local function ObserveAuctionator()
  local frame = _G.AuctionatorAHFrame
  if frame then
    Skins.Hook(frame, "OnShow", function()
      Skins.ObserveAddon("Auctionator")
    end)
  end
  Skins.ObserveAddon("Auctionator")
end

local function InstallHooks()
  if not ns.BlizzardSkinOptions.IsEnabled(skinName)
    or not ns.BlizzardSkinOptions.IsEnabled("AuctionHouseFrame") then
    driver:UnregisterAllEvents()
    return
  end
  local initializer = _G.AuctionatorInitalizeMainlineFrame
  if hooked or not initializer then return end
  hooked = true
  Skins.Hook(initializer, "AuctionHouseShown", ObserveAuctionator)
  for _, method in ipairs({ "ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney" }) do
    Skins.Hook(Auctionator.Dialogs, method, SkinDialogs)
  end
  ObserveAuctionator()
  driver:UnregisterAllEvents()
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, addonName)
  if event == "PLAYER_LOGIN" then
    loggedIn = true
    InstallHooks()
  elseif loggedIn and addonName == "Auctionator" then
    InstallHooks()
  end
end)
