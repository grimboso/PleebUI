local _, ns = ...

local FrameUtil = ns.FrameUtil
local whiteTexture = "Interface\\Buttons\\WHITE8x8"

local function CreateBarBackdrop(frame, inset)
  local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  backdrop.ignoreInLayout = true
  backdrop:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
  backdrop:SetBackdrop({ bgFile = whiteTexture, edgeFile = whiteTexture, edgeSize = 1 })
  backdrop:SetBackdropColor(0, 0, 0, 0.7)
  backdrop:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
end

local function SkinBar(bar)
  if bar.BorderArt then
    bar.BorderArt:SetAlpha(0)
  end
  if bar.BackgroundArt then
    bar.BackgroundArt:SetAlpha(0)
  end

  CreateBarBackdrop(bar, 0)
end

local function SkinBagButtons(bar)
  if bar.useDividers then
    bar.useDividers = false
    if bar.HorizontalDividersPool then
      bar.HorizontalDividersPool:ReleaseAll()
      bar.VerticalDividersPool:ReleaseAll()
    end
  end

  for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
    if button == MainMenuBarBackpackButton and not ns.Client.IsForever then
      CreateBarBackdrop(button, -1)
    else
      button:GetNormalTexture():SetAlpha(0)
      button:GetPushedTexture():SetAlpha(0)
      if ns.Client.IsForever and button == KeyRingButton then
        local atlas = "bags-item-slot-keychain"
        if C_Texture.GetAtlasInfo(atlas) then
          local icon = button:CreateTexture(nil, "ARTWORK")
          icon:SetAllPoints(button.icon)
          icon:SetAtlas(atlas)
          button.icon:SetAlpha(0)
        end
      else
        -- Blizzard uses this texture when an equipment bag slot is empty.
        button.backgroundTextureName = nil
        CreateBarBackdrop(button, 1)
      end
    end
  end
end

local function SkinMicroButtons()
  for _, button in ipairs({ MicroMenu:GetChildren() }) do
    if button.Background and button.PushedBackground then
      button.Background:SetAlpha(0)
      button.PushedBackground:SetAlpha(0)
      if button.IconBorder then
        button.IconBorder:SetAlpha(0)
      end
      CreateBarBackdrop(button, 3)
    end
  end
end

local function RegisterBarMover(key, label, bar, artwork)
  local manager = EditModeManagerFrame

  local function IsAvailable()
    return manager:IsInitialized() and artwork:IsVisible()
      and (artwork == bar or artwork:GetParent() == bar)
  end

  FrameUtil:EnsureGhostMover(key, {
    label = label,
    moduleKey = "menuBars",
    moduleLabel = "Menu Bars",
    liveFrame = bar,
    isAvailable = IsAvailable,
    shouldShow = function()
      return ns.Flags.IsEditing and IsAvailable()
    end,
    getSize = function(_, liveFrame)
      local scale = liveFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
      return liveFrame:GetWidth() * scale, liveFrame:GetHeight() * scale
    end,
    getPoint = function(_, liveFrame)
      local right, top = liveFrame:GetRight(), liveFrame:GetTop()
      if right and top then
        local scale = liveFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return "TOPRIGHT", UIParent, "TOPRIGHT", right * scale - UIParent:GetRight(), top * scale - UIParent:GetTop()
      end
    end,
    savePosition = function(mover)
      if InCombatLockdown() or not IsAvailable() then
        return
      end

      local scale = UIParent:GetEffectiveScale() / bar:GetEffectiveScale()
      local x = (mover:GetRight() - UIParent:GetRight()) * scale
      local y = (mover:GetTop() - UIParent:GetTop()) * scale
      bar:ClearFrameSnap()
      bar:ClearAllPoints()
      bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
      bar:OnSystemPositionChange()
      if ns.Client.IsForever and artwork ~= bar and QueueStatusButton then
        QueueStatusButton:UpdateDefaultAnchor()
      end
      manager:SaveLayoutChanges()
    end,
    onDragStop = function()
      FrameUtil:RefreshGhostMover(key)
    end,
  })
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  if C_AddOns.IsAddOnLoaded("PleeBar") then
    return
  end

  if BagsBar then
    SkinBar(BagsBar)
    SkinBagButtons(BagsBar)
    RegisterBarMover("BagsBar", "Bags", BagsBar, BagsBar)
  end
  if MicroMenuContainer and MicroMenu then
    SkinBar(MicroMenu)
    SkinMicroButtons()
    RegisterBarMover("MicroMenu", "Micro Menu", MicroMenuContainer, MicroMenu)
  end
end)
