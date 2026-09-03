local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local FrameScale = ns.FrameScale
local IconSkin = ns.IconSkin
local Round = ns.Pixel.Round

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local pairs = _G.pairs
local math_max = _G.math.max

local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local Bags = {}
ns.Registry.Bags = Bags

local itemBorders = setmetatable({}, { __mode = "k" })
local skinnedItemButtons = setmetatable({}, { __mode = "k" })
local pendingItemButtons = setmetatable({}, { __mode = "k" })
local bagFrameStates = setmetatable({}, { __mode = "k" })

local function HideRegion(region)
  if region then
    region:SetAlpha(0)
    region:Hide()
  end
end

local function GetBagFrameState(frame)
  local state = bagFrameStates[frame]
  if not state then
    state = {}
    bagFrameStates[frame] = state
  end

  return state
end

local function EnsureShellHost(frame)
  local state = GetBagFrameState(frame)
  local host = state.shellHost
  if not host then
    local hostName = frame == _G.ContainerFrameCombinedBags and "PUI_CombinedBagShellHost" or "PUI_ReagentBagShellHost"
    host = CreateFrame("Frame", hostName, frame)
    host:EnableMouse(false)
    state.shellHost = host
  end

  host:SetAllPoints(frame)
  Theme.WidgetSkins.Frame(host)
end

local function EnsureControlBackdrop(frame, control, controlFrame, stateKey, padding)
  local state = GetBagFrameState(frame)
  local backdrop = state[stateKey]
  if not backdrop then
    backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop.__puiIsBackdropFrame = true
    backdrop:EnableMouse(false)
    state[stateKey] = backdrop
  end

  backdrop:ClearAllPoints()
  backdrop:SetPoint("TOPLEFT", control, "TOPLEFT", -padding, padding)
  backdrop:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", padding, -padding)
  backdrop:SetFrameStrata(frame:GetFrameStrata())
  backdrop:SetFrameLevel(math_max((controlFrame:GetFrameLevel() or 1) - 1, frame:GetFrameLevel()))

  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(backdrop, {
    bg = colors.control,
    border = colors.border,
  })
  backdrop:Show()
end

local function SkinPortrait(frame)
  local portrait = frame:GetPortrait()
  IconSkin.StripIconMasks(portrait)

  portrait:ClearAllPoints()
  portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", Round(9), -Round(7))
  portrait:SetSize(Round(30), Round(30))
  portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  portrait:SetAlpha(1)
  portrait:Show()

  EnsureControlBackdrop(frame, portrait, frame.PortraitContainer, "portraitBackdrop", 2)
end

local function SkinMoneyFrame(frame)
  local moneyFrame = frame.MoneyFrame
  if not moneyFrame then
    return
  end

  HideRegion(moneyFrame.Border.Left)
  HideRegion(moneyFrame.Border.Middle)
  HideRegion(moneyFrame.Border.Right)

  EnsureControlBackdrop(frame, moneyFrame, moneyFrame, "moneyBackdrop", 2)
end

local function SkinSearchAndSort(frame)
  local searchBox = _G.BagItemSearchBox
  Theme.WidgetSkins.UIEditBox(searchBox)

  local colors = Theme.GetColors()
  searchBox.searchIcon:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4])

  local sortButton = _G.BagItemAutoSortButton
  EnsureControlBackdrop(frame, sortButton, sortButton, "sortBackdrop", 0)
end

local function CreateItemBorder(button)
  local border = {}

  border.top = button:CreateTexture(nil, "OVERLAY", nil, 7)
  border.top:SetTexture(WHITE8)
  border.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  border.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)

  border.bottom = button:CreateTexture(nil, "OVERLAY", nil, 7)
  border.bottom:SetTexture(WHITE8)
  border.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  border.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)

  border.left = button:CreateTexture(nil, "OVERLAY", nil, 7)
  border.left:SetTexture(WHITE8)

  border.right = button:CreateTexture(nil, "OVERLAY", nil, 7)
  border.right:SetTexture(WHITE8)

  itemBorders[button] = border
  return border
end

local function RefreshItemButtonTheme(button)
  local colors = Theme.GetColors()
  local border = itemBorders[button] or CreateItemBorder(button)
  local edge = FrameScale:BestOnePixel()

  border.top:SetHeight(edge)
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -edge)
  border.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, edge)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -edge)
  border.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, edge)
  border.right:SetWidth(edge)

  for _, texture in pairs(border) do
    texture:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4])
  end

  Theme.ApplyFont(button.Count, "tiny")
  button.Count:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
end

local function SkinItemButton(button)
  local frame = button:GetParent()
  if frame ~= _G.ContainerFrameCombinedBags and frame ~= _G.ContainerFrame6 then
    return
  end

  if InCombatLockdown() then
    pendingItemButtons[button] = true
    return
  end

  HideRegion(button:GetNormalTexture())
  HideRegion(button.ItemSlotBackground)

  if skinnedItemButtons[button] then
    pendingItemButtons[button] = nil
    return
  end

  local icon = button.icon
  local mask = button.IconMask
  if mask then
    icon:RemoveMaskTexture(mask)
    HideRegion(mask)
  end

  icon:ClearAllPoints()
  icon:SetAllPoints(button)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  RefreshItemButtonTheme(button)
  skinnedItemButtons[button] = true
  pendingItemButtons[button] = nil
end

local function SkinCurrentItems(frame)
  for _, button in ipairs(frame.Items) do
    SkinItemButton(button)
  end
end

local function ApplyBagFrameSkin(frame, usesSharedControls)
  if not frame then
    return
  end

  if InCombatLockdown() then
    Bags.themeRefreshPending = true
    return
  end

  EnsureShellHost(frame)
  HideRegion(frame.NineSlice)
  frame.Bg:Hide()

  local title = frame.TitleContainer.TitleText
  Theme.ApplyFont(title, "title")
  local colors = Theme.GetColors()
  title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

  Theme.WidgetSkins.CloseButton(frame.CloseButton)

  SkinPortrait(frame)
  SkinMoneyFrame(frame)
  if usesSharedControls then
    SkinSearchAndSort(frame)
  end
  SkinCurrentItems(frame)
end

local function ApplyCombinedBagSkin()
  ApplyBagFrameSkin(_G.ContainerFrameCombinedBags, true)
end

local function ApplyReagentBagSkin()
  ApplyBagFrameSkin(_G.ContainerFrame6, false)
end

local function RefreshBagScale()
  Bags:RefreshTheme()
end

local function SetupBagSkins()
  local frame = _G.ContainerFrameCombinedBags
  local reagentFrame = _G.ContainerFrame6
  local itemButtonMixin = _G.ContainerFrameItemButtonMixin
  if not frame or not reagentFrame or not itemButtonMixin then
    return
  end

  if not Bags.itemButtonHooked then
    Bags.itemButtonHooked = true
    hooksecurefunc(itemButtonMixin, "Initialize", SkinItemButton)
  end

  if not Bags.framesHooked then
    Bags.framesHooked = true
    frame:HookScript("OnShow", ApplyCombinedBagSkin)
    reagentFrame:HookScript("OnShow", ApplyReagentBagSkin)
  end

  if not Bags.scaleListenerRegistered then
    Bags.scaleListenerRegistered = true
    FrameScale:RegisterScaleListener(RefreshBagScale)
  else
    ApplyCombinedBagSkin()
    ApplyReagentBagSkin()
  end
end

local function RefreshCurrentItemThemes(frame)
  if not frame then
    return
  end

  for _, button in ipairs(frame.Items) do
    if skinnedItemButtons[button] then
      RefreshItemButtonTheme(button)
    end
  end
end

function Bags:RefreshTheme()
  if InCombatLockdown() then
    self.themeRefreshPending = true
    return
  end

  self.themeRefreshPending = false
  ApplyCombinedBagSkin()
  ApplyReagentBagSkin()
  RefreshCurrentItemThemes(_G.ContainerFrameCombinedBags)
  RefreshCurrentItemThemes(_G.ContainerFrame6)
end

local function ProcessDeferredWork()
  if Bags.themeRefreshPending then
    Bags:RefreshTheme()
  end

  for button in pairs(pendingItemButtons) do
    SkinItemButton(button)
  end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(self, event, arg1)
  if event == "PLAYER_LOGIN" then
    SetupBagSkins()
    self:UnregisterEvent("PLAYER_LOGIN")
    return
  end

  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_UIPanels_Game" and Addon.db then
      SetupBagSkins()
    end
    return
  end

  ProcessDeferredWork()
end)
local P = select(1, ns.Pleebug:DropIn(Bags, { name = "Modules.Bags" }))
HideRegion = P:Def("Bags.HideRegion", HideRegion)
GetBagFrameState = P:Def("Bags.GetBagFrameState", GetBagFrameState)
EnsureShellHost = P:Def("Bags.EnsureShellHost", EnsureShellHost)
EnsureControlBackdrop = P:Def("Bags.EnsureControlBackdrop", EnsureControlBackdrop)
SkinPortrait = P:Def("Bags.SkinPortrait", SkinPortrait)
SkinMoneyFrame = P:Def("Bags.SkinMoneyFrame", SkinMoneyFrame)
SkinSearchAndSort = P:Def("Bags.SkinSearchAndSort", SkinSearchAndSort)
CreateItemBorder = P:Def("Bags.CreateItemBorder", CreateItemBorder)
RefreshItemButtonTheme = P:Def("Bags.RefreshItemButtonTheme", RefreshItemButtonTheme)
SkinItemButton = P:Def("Bags.SkinItemButton", SkinItemButton)
SkinCurrentItems = P:Def("Bags.SkinCurrentItems", SkinCurrentItems)
ApplyBagFrameSkin = P:Def("Bags.ApplyBagFrameSkin", ApplyBagFrameSkin)
ApplyCombinedBagSkin = P:Def("Bags.ApplyCombinedBagSkin", ApplyCombinedBagSkin)
ApplyReagentBagSkin = P:Def("Bags.ApplyReagentBagSkin", ApplyReagentBagSkin)
RefreshBagScale = P:Def("Bags.RefreshBagScale", RefreshBagScale)
SetupBagSkins = P:Def("Bags.SetupBagSkins", SetupBagSkins)
RefreshCurrentItemThemes = P:Def("Bags.RefreshCurrentItemThemes", RefreshCurrentItemThemes)
Bags.RefreshTheme = P:Def("Bags:RefreshTheme", Bags.RefreshTheme)
ProcessDeferredWork = P:Def("Bags.ProcessDeferredWork", ProcessDeferredWork)
