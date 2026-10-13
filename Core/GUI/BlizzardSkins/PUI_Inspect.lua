local _, ns = ...
local Theme = ns.Theme
local CharacterSheet = ns.Registry.CharacterSheet
local Shared = CharacterSheet.InspectSkinHelpers
local GetTextColor = Shared.GetTextColor
local StripTextures = Shared.StripTextures
local CS_BG = Shared.CS_BG
local CS_B = Shared.CS_B
local CS_CONTROL = Shared.CS_CONTROL
local EnsureBackdropFrame = Shared.EnsureBackdropFrame
local CS_ApplyBackdrop = Shared.CS_ApplyBackdrop
local CS_SkinButton = Shared.CS_SkinButton
local CS_SkinCloseButton = Shared.CS_SkinCloseButton
local CS_SkinTextureIcon = Shared.CS_SkinTextureIcon
local CS_IsInspectReady = Shared.CS_IsInspectReady
local CS_RefreshInspectData = Shared.CS_RefreshInspectData
local UpdateInspectAverageItemLevelText = Shared.UpdateInspectAverageItemLevelText
local CS_ClearInspectSlotOverlays = Shared.CS_ClearInspectSlotOverlays
local CS_ClearInspectAverageItemLevelText = Shared.CS_ClearInspectAverageItemLevelText
local CS_RefreshInspectSlotButtons = Shared.CS_RefreshInspectSlotButtons
local CS_ResetInspectItemDataRequests = Shared.CS_ResetInspectItemDataRequests
local CS_ForEachInspectSlotButton = Shared.CS_ForEachInspectSlotButton
local RefreshItemSlotOverlayTheme = Shared.RefreshItemSlotOverlayTheme

local function CS_SkinInspectPvPFrame()
  local pvp = _G.InspectPVPFrame
  if not pvp then
    return
  end

  if pvp.BG and pvp.BG.SetAlpha then
    pvp.BG:SetAlpha(0)
  end

  if pvp.SmallWreath then
    pvp.SmallWreath:ClearAllPoints()
    pvp.SmallWreath:SetPoint("TOPLEFT", pvp, "TOPLEFT", -2, -25)
  end

  for i = 1, 3 do
    local slot = pvp["TalentSlot" .. i]
    if slot then
      local keepIcon = slot.Texture

      local nt = slot.GetNormalTexture and slot:GetNormalTexture()
      if nt and nt.SetAlpha then nt:SetAlpha(0) end

      local pt = slot.GetPushedTexture and slot:GetPushedTexture()
      if pt and pt.SetAlpha then pt:SetAlpha(0) end

      local ht = slot.GetHighlightTexture and slot:GetHighlightTexture()
      if ht and ht.SetAlpha then ht:SetAlpha(0) end

      if slot.GetRegions then
        for _, region in ipairs({ slot:GetRegions() }) do
          if region and region.IsObjectType and region:IsObjectType("Texture") and region ~= keepIcon then
            if region.SetAlpha then
              region:SetAlpha(0)
            end
          end
        end
      end

      CS_ApplyBackdrop(slot, CS_CONTROL)

      if slot.Border then
        slot.Border:Hide()
      end

      if slot.Texture then
        slot.Texture:ClearAllPoints()
        slot.Texture:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        slot.Texture:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        CS_SkinTextureIcon(slot.Texture)
      end
    end
  end
end

-- InspectFrame (identical behavior, no durability)
local function EnsureInspectShellHost()
  if not InspectFrame then
    return
  end

  local host = CharacterSheet._inspectHost
  if not host then
    host = CreateFrame("Frame", "PUI_InspectShellHost", InspectFrame)
    CharacterSheet._inspectHost = host

    if host.EnableMouse then host:EnableMouse(false) end
    if host.SetMouseClickEnabled then host:SetMouseClickEnabled(false) end
  end

  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMRIGHT", 0, -40)

  ns.Theme.WidgetSkins.Frame(host)
end

local function SetupInspectFrameSkinning()

  if not InspectFrame then
    return
  end

  if CharacterSheet._inspectInit then return end

  CharacterSheet._inspectInit = true

  local function ApplyInspectDecorations()
    if not InspectFrame then
      return
    end

    if InspectFrame.NineSlice then
      InspectFrame.NineSlice:Hide()
    end
    if InspectFrame.Inset and InspectFrame.Inset.NineSlice then
      InspectFrame.Inset.NineSlice:Hide()
    end

    if InspectFramePortrait then
      InspectFramePortrait:SetAlpha(0)
    end
    if InspectFrameBg then
      InspectFrameBg:SetAlpha(0)
    end
    if InspectFrame.Background then
      InspectFrame.Background:SetAlpha(0)
    end
    if InspectFrame.TitleBg then
      InspectFrame.TitleBg:SetAlpha(0)
    end

    ns.BlizzardSkins.WindowTitle(InspectFrame, InspectFrame.TitleText)

    if InspectModelScene then
      StripTextures(InspectModelScene, true)
    end

    if InspectPaperDollFrame then
      StripTextures(InspectPaperDollFrame, true)
    end
    if InspectPaperDollItemsFrame then
      StripTextures(InspectPaperDollItemsFrame, true)
      if InspectPaperDollItemsFrame.NineSlice then InspectPaperDollItemsFrame.NineSlice:Hide() end
      if InspectPaperDollItemsFrame.BorderFrame then InspectPaperDollItemsFrame.BorderFrame:SetAlpha(0) end
    end
    if InspectFrameInset then
      StripTextures(InspectFrameInset, true)
      if InspectFrameInset.NineSlice then InspectFrameInset.NineSlice:Hide() end
      if InspectFrameInset.BorderFrame then InspectFrameInset.BorderFrame:SetAlpha(0) end
      if InspectFrameInset.Bg and InspectFrameInset.Bg.SetAlpha then InspectFrameInset.Bg:SetAlpha(0) end
      if InspectFrameInset.Background and InspectFrameInset.Background.SetAlpha then InspectFrameInset.Background:SetAlpha(0) end
    end
    if InspectFrameInsetRight then
      StripTextures(InspectFrameInsetRight, true)
      if InspectFrameInsetRight.NineSlice then InspectFrameInsetRight.NineSlice:Hide() end
      if InspectFrameInsetRight.BorderFrame then InspectFrameInsetRight.BorderFrame:SetAlpha(0) end
      if InspectFrameInsetRight.Bg and InspectFrameInsetRight.Bg.SetAlpha then InspectFrameInsetRight.Bg:SetAlpha(0) end
      if InspectFrameInsetRight.Background and InspectFrameInsetRight.Background.SetAlpha then InspectFrameInsetRight.Background:SetAlpha(0) end
    end
    if InspectFrameCloseButton then
      ns.Theme.WidgetSkins.CloseButton(InspectFrameCloseButton)
    end
  end

  ApplyInspectDecorations()

  local viewBtn = InspectPaperDollFrame and InspectPaperDollFrame.ViewButton
  if viewBtn then
    StripTextures(viewBtn, true)
    ns.Theme.WidgetSkins.Button(viewBtn)
  end

  local talentsBtn = InspectPaperDollItemsFrame and InspectPaperDollItemsFrame.InspectTalents
  if talentsBtn then
    StripTextures(talentsBtn, true)
    ns.Theme.WidgetSkins.Button(talentsBtn)
    talentsBtn:ClearAllPoints()
    talentsBtn:SetPoint("TOPRIGHT", InspectFrame, "BOTTOMRIGHT", 0, -1)
  end

  CS_SkinInspectPvPFrame() 

  if InspectModelFrame then
    StripTextures(InspectModelFrame, true)

    local bg = EnsureBackdropFrame(InspectModelFrame)
    if bg and bg.SetBackdrop then
      local edgeSize = Theme.GetEdgeSize()
      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })

      local r, g, b, a = CS_BG()
      local br, bgG, bB, bA = CS_B()
      bg:SetBackdropColor(r, g, b, a)
      bg:SetBackdropBorderColor(br, bgG, bB, bA)
    end

    if InspectModelFrame.BackgroundOverlay and InspectModelFrame.BackgroundOverlay.SetColorTexture then
      InspectModelFrame.BackgroundOverlay:SetColorTexture(0, 0, 0, 1)
    end

    if InspectModelFrameBorderTopLeft then InspectModelFrameBorderTopLeft:SetAlpha(0) end
    if InspectModelFrameBorderTopRight then InspectModelFrameBorderTopRight:SetAlpha(0) end
    if InspectModelFrameBorderTop then InspectModelFrameBorderTop:SetAlpha(0) end
    if InspectModelFrameBorderLeft then InspectModelFrameBorderLeft:SetAlpha(0) end
    if InspectModelFrameBorderRight then InspectModelFrameBorderRight:SetAlpha(0) end
    if InspectModelFrameBorderBottomLeft then InspectModelFrameBorderBottomLeft:SetAlpha(0) end
    if InspectModelFrameBorderBottomRight then InspectModelFrameBorderBottomRight:SetAlpha(0) end
    if InspectModelFrameBorderBottom then InspectModelFrameBorderBottom:SetAlpha(0) end
    if InspectModelFrameBorderBottom2 then InspectModelFrameBorderBottom2:SetAlpha(0) end
  end

  EnsureInspectShellHost()

  do
    local index = 1
    local lastTab = nil
    local tab = _G["InspectFrameTab" .. index]

    while tab do
      ns.BlizzardSkins.Tab(tab)

      tab:ClearAllPoints()
      if index == 1 then
        tab:SetPoint("TOPLEFT", InspectFrame, "BOTTOMLEFT", -3, 0)
      else
        tab:SetPoint("TOPLEFT", lastTab, "TOPRIGHT", -5, 0)
      end

      lastTab = tab
      index = index + 1
      tab = _G["InspectFrameTab" .. index]
    end
  end

  local function UpdateInspectPaperDollVisibility()
    local unit = InspectFrame and InspectFrame.unit
    local guid = unit and UnitGUID(unit) or nil
    local show = InspectPaperDollFrame and InspectPaperDollFrame.IsShown and InspectPaperDollFrame:IsShown()

    if show and unit and CS_IsInspectReady(unit) then
      if guid then
        CS_RefreshInspectData(guid)
      else
        UpdateInspectAverageItemLevelText()
      end
    else
      CS_ClearInspectSlotOverlays()
      CS_ClearInspectAverageItemLevelText()
    end
  end

  UpdateInspectPaperDollVisibility()

  if not InspectFrame._puiPaperDollVisibilityHooked then
    if InspectPaperDollFrame then
      InspectPaperDollFrame:HookScript("OnShow", UpdateInspectPaperDollVisibility)
      InspectPaperDollFrame:HookScript("OnHide", UpdateInspectPaperDollVisibility)
    end

    InspectFrame._puiPaperDollVisibilityHooked = true
  end

  if not CharacterSheet._inspectSlotHook then
    hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function()
      local unit = InspectFrame and InspectFrame.unit
      if not unit then
        return
      end

      local guid = UnitGUID(unit)
      if guid and CS_IsInspectReady(unit) then
        CS_RefreshInspectData(guid)
      else
        CS_RefreshInspectSlotButtons(unit)
      end
    end)
    CharacterSheet._inspectSlotHook = true
  end

  if not InspectFrame._puiCharacterSheetLifecycleHooked then
    InspectFrame:HookScript("OnHide", function()
      CharacterSheet._inspectReadyGUID = nil
      CS_ResetInspectItemDataRequests()
      CS_ClearInspectSlotOverlays()
      CS_ClearInspectAverageItemLevelText()
    end)
    InspectFrame._puiCharacterSheetLifecycleHooked = true
  end
end


local function RefreshInspectTheme()
  if InspectFrame and CharacterSheet._inspectInit then
    ns.Theme.WidgetSkins.Frame(CharacterSheet._inspectHost)

    local tr, tg, tb, ta = GetTextColor()
    ns.BlizzardSkins.WindowTitle(InspectFrame, InspectFrame.TitleText)

    CS_ApplyBackdrop(InspectModelFrame, CS_BG)
    CS_SkinCloseButton(InspectFrameCloseButton)
    CS_SkinButton(InspectPaperDollFrame and InspectPaperDollFrame.ViewButton)
    CS_SkinButton(InspectPaperDollItemsFrame and InspectPaperDollItemsFrame.InspectTalents)
    local pvp = _G.InspectPVPFrame
    if pvp then
      for index = 1, 3 do CS_ApplyBackdrop(pvp["TalentSlot" .. index], CS_CONTROL) end
    end

    if InspectFrame._puiAvgItemLevelText then
      ns.Theme.ApplyFont(InspectFrame._puiAvgItemLevelText, "body")
      InspectFrame._puiAvgItemLevelText:SetTextColor(tr, tg, tb, ta)
    end

    CS_ForEachInspectSlotButton(RefreshItemSlotOverlayTheme)
  end
end

ns.BlizzardSkins.Register("Blizzard_InspectUI", "InspectFrame", {
  install = function()
    SetupInspectFrameSkinning()
    RefreshInspectTheme()
  end,
  onTheme = RefreshInspectTheme,
  controlsRoot = function() return CharacterSheet._inspectHost end,
})
