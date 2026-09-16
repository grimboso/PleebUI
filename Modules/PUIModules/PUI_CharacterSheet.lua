local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Theme     = ns.Theme
local Round     = ns.Pixel.Round
local IconSkin  = ns.IconSkin
local EnsureBackdropFrame = Theme.EnsureBackdropFrame
local _G              = _G
local CreateFrame     = _G.CreateFrame
local C_Timer         = _G.C_Timer
local hooksecurefunc  = _G.hooksecurefunc
local Menu            = _G.Menu
local MenuUtil        = _G.MenuUtil
local GetCursorPosition = _G.GetCursorPosition
local GetAverageItemLevel = _G.GetAverageItemLevel
local InCombatLockdown = _G.InCombatLockdown
local issecretvalue = _G.issecretvalue
local GetInspectSpecialization = _G.GetInspectSpecialization
local GetMaxLevelForPlayerExpansion = _G.GetMaxLevelForPlayerExpansion
local UnitGUID        = _G.UnitGUID
local UnitLevel       = _G.UnitLevel
local pairs           = _G.pairs
local ipairs          = _G.ipairs
local tonumber        = _G.tonumber
local tostring        = _G.tostring
local format          = _G.string.format
local type            = _G.type
local GetInventoryItemLink       = _G.GetInventoryItemLink
local GetInventoryItemQuality    = _G.GetInventoryItemQuality
local GetInventoryItemDurability = _G.GetInventoryItemDurability
local GetItemQualityColor        = _G.GetItemQualityColor
local CharacterSheet = {}
ns.Registry.CharacterSheet = CharacterSheet


local P = ns.Pleebug:DropIn(CharacterSheet, { name = "Modules.CharacterSheet" })


-- Internal state
CharacterSheet._shellExtended   = true
CharacterSheet._shellHost       = nil
CharacterSheet._initialized     = false
CharacterSheet._inspectHost     = nil
CharacterSheet._inspectInit     = false
CharacterSheet._inspectSlotHook = false
CharacterSheet._inspectReadyGUID = nil
CharacterSheet._characterDragging = false
CharacterSheet._characterResizeState = nil
CharacterSheet._activeItemStatHighlight = false
CharacterSheet._hoveredStatFrame = nil
CharacterSheet._statFontFrames = {}

local CS_CHARACTER_SCALE_MIN = 0.75
local CS_CHARACTER_SCALE_MAX = 1.50
local CS_SHELL_BOTTOM_EXTENSION = 40
local CS_CONFIG_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\Config.png]]

local CS_FormatItemLevel
local CS_GetPlayerEquippedItemLevel
local CS_CalculateUnitAverageItemLevel
local UpdateItemSlotOverlay
local CS_RefreshPlayerItemStatPresence
local CS_SLOT_INFO_CACHE = {}
local CS_INSPECT_SLOT_QUEUE = {}
local CS_InspectSlotQueuePending = false
local CS_SLOT_CACHE_VERSION = 0
local CS_COLOR_CACHE_SOURCE = nil
local CS_COLOR_CACHE = {}
local CS_FALLBACK_TEXT    = { 0.92, 0.92, 0.92, 1.00 }
local CS_FALLBACK_BG      = { 0.059, 0.059, 0.078, 0.92 }
local CS_FALLBACK_CONTROL = { 0.070, 0.070, 0.090, 0.96 }
local CS_FALLBACK_BORDER  = { 0.20, 0.20, 0.24, 1.00 }
local CS_FALLBACK_ACCENT = { 0.431, 0.765, 1.00, 1.00 }
local CS_STAT_HIGHLIGHT_COLOR = { 1.00, 0.86, 0.55, 1.00 }
local CS_STAT_HIGHLIGHT_FADE_IN_SECONDS = 0.50
local CS_STAT_HIGHLIGHT_FADE_OUT_SECONDS = 1.00

local function CS_ClearSlotInfoCache()
  for guid in pairs(CS_SLOT_INFO_CACHE) do
    CS_SLOT_INFO_CACHE[guid] = nil
  end

  CS_SLOT_CACHE_VERSION = CS_SLOT_CACHE_VERSION + 1
end

local function CS_GetCachedSlotInfo(unit, slotId)
  if not unit or not slotId then
    return nil, nil
  end

  local itemLink = GetInventoryItemLink(unit, slotId)
  if not itemLink then
    return nil, nil
  end

  local guid = UnitGUID(unit) or unit
  local slotCache = CS_SLOT_INFO_CACHE[guid]
  if not slotCache then
    slotCache = {}
    CS_SLOT_INFO_CACHE[guid] = slotCache
  end

  local cache = slotCache[slotId]
  if not cache or cache.itemLink ~= itemLink then
    cache = { itemLink = itemLink }
    slotCache[slotId] = cache
  end

  return cache, itemLink
end

local function CS_GetCachedInventoryTooltipData(cache, unit, slotId)
  if cache and cache.tooltipData then
    return cache.tooltipData
  end

  local tooltipData = C_TooltipInfo.GetInventoryItem(unit, slotId)
  if cache and tooltipData then
    cache.tooltipData = tooltipData
  end

  return tooltipData
end

local _CSSubDB

local function _CS_GetDB()
  if not _CSSubDB then
    _CSSubDB = Addon.db:GetNamespace("CharacterSheet", true)
  end

  if not _CSSubDB then
    _CSSubDB = Addon.db:RegisterNamespace("CharacterSheet", {
      profile = {
        showEnchants = true,
        showSocketIcons = true,
        showBagItemLevel = false,
        showStatRatings = false,
        highlightStatGear = true,
        showMaxHealth = true,
        usePleebUIFont = false,
        windowScale = 1,
      },
    })
  end

  return _CSSubDB.profile
end

local function CS_GetShowEnchants()
  local csdb = _CS_GetDB()
  return not csdb or csdb.showEnchants ~= false
end

local function CS_SetShowEnchants(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.showEnchants = not not v
  end
end

local function CS_GetShowSocketIcons()
  local csdb = _CS_GetDB()
  return not csdb or csdb.showSocketIcons ~= false
end

local function CS_SetShowSocketIcons(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.showSocketIcons = not not v
  end
end

local function _Clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function ColorFromTheme(token, fallback)
  local colors = Theme.GetColors()
  if CS_COLOR_CACHE_SOURCE ~= colors then
    for key in pairs(CS_COLOR_CACHE) do
      CS_COLOR_CACHE[key] = nil
    end
    CS_COLOR_CACHE_SOURCE = colors
  end

  local cached = CS_COLOR_CACHE[token]
  if cached then
    return cached[1], cached[2], cached[3], cached[4]
  end

  local src = colors and colors[token] or nil
  local r, g, b, a

  if type(src) == "table" then
    r = src[1] or src.r
    g = src[2] or src.g
    b = src[3] or src.b
    a = src[4]
    if a == nil then a = src.a end
  end

  if r == nil or g == nil or b == nil then
    r = fallback and fallback[1] or 1
    g = fallback and fallback[2] or 1
    b = fallback and fallback[3] or 1
    a = fallback and fallback[4] or 1
  elseif a == nil then
    a = fallback and fallback[4] or 1
  end

  r, g, b, a = _Clamp01(r), _Clamp01(g), _Clamp01(b), _Clamp01(a)
  cached = { r, g, b, a }
  CS_COLOR_CACHE[token] = cached
  return r, g, b, a
end

local function GetTextColor()
  return ColorFromTheme("text", CS_FALLBACK_TEXT)
end

-- CharacterSheet theme roles.
local function CS_BG()
  return ColorFromTheme("background", CS_FALLBACK_BG)
end

local function CS_CONTROL()
  return ColorFromTheme("control", CS_FALLBACK_CONTROL)
end

local function CS_B()
  return ColorFromTheme("border", CS_FALLBACK_BORDER)
end

local function CS_ACCENT()
  return ColorFromTheme("accent", CS_FALLBACK_ACCENT)
end

local MIDNIGHT_ENCHANTABLE_SLOTS = {
  [INVSLOT_HEAD] = true,
  [INVSLOT_SHOULDER] = true,
  [INVSLOT_CHEST] = true,
  [INVSLOT_LEGS] = true,
  [INVSLOT_FEET] = true,
  [INVSLOT_FINGER1] = true,
  [INVSLOT_FINGER2] = true,
  [INVSLOT_MAINHAND] = true,
  [INVSLOT_OFFHAND] = true,
}

local function IsEnchantableSlot(slotId)
  return MIDNIGHT_ENCHANTABLE_SLOTS[slotId] == true
end

local function CS_IsEnchantWarningLevel(unit)
  return UnitLevel(unit) >= GetMaxLevelForPlayerExpansion()
end

local function StripTextures(frame, kill)
  if not frame or not frame.GetRegions then
    return
  end

  for _, region in ipairs({ frame:GetRegions() }) do
    if region and region.IsObjectType and region:IsObjectType("Texture") then
      if kill and region.SetTexture then
        region:SetTexture(nil)
      elseif region.SetAlpha then
        region:SetAlpha(0)
      end
    end
  end
end

local function CS_MarkItemSlotBlizzardTextures(button, keepIcon, keepIgnore)
  if not button or button._puiCharSlotTexturesMarked or not button.GetRegions then
    return
  end

  for _, region in ipairs({ button:GetRegions() }) do
    if region and region.IsObjectType and region:IsObjectType("Texture") then
      if region ~= keepIcon and region ~= keepIgnore then
        region._puiCharBlizzardSlotTexture = true
      end
    end
  end

  button._puiCharSlotTexturesMarked = true
end

local function CS_IsOwnedBlizzardSlotTexture(region)
  return region and region._puiCharBlizzardSlotTexture == true
end


local function CS_HideItemSlotChrome(button)
  if not button then
    return
  end

  -- Strip common Blizzard chrome layers on item buttons (varies by template).
  if button.IconBorder  then button.IconBorder:SetAlpha(0) end
  if button.IconBorder2 then button.IconBorder2:SetAlpha(0) end
  if button.Border      then button.Border:SetAlpha(0) end
  if button.Border2     then button.Border2:SetAlpha(0) end
  if button.BorderFrame then button.BorderFrame:SetAlpha(0) end
  if button.NineSlice   then button.NineSlice:Hide() end

  local nt = button.GetNormalTexture and button:GetNormalTexture()
  if nt and nt.SetAlpha then nt:SetAlpha(0) end

  local ht = button.GetHighlightTexture and button:GetHighlightTexture()
  if ht and ht.SetAlpha then ht:SetAlpha(0) end

  local pt = button.GetPushedTexture and button:GetPushedTexture()
  if pt and pt.SetAlpha then pt:SetAlpha(0) end
end

local function SkinItemSlotButton(button)
  if not button then
    return
  end

  CS_HideItemSlotChrome(button)

  if not button._puiCharItemSlotSkinned or button._puiCharItemSlotIconSkin ~= IconSkin then
    local keepIcon = button.icon or button.Icon or button.IconTexture
    local keepIgnore = button.ignoreTexture

    CS_MarkItemSlotBlizzardTextures(button, keepIcon, keepIgnore)

    button._puiCharItemSlotSkinned = true
    button._puiCharItemSlotIconSkin = IconSkin
  end

  if button.GetRegions then
    for _, region in ipairs({ button:GetRegions() }) do
      if region and region.IsObjectType and region:IsObjectType("Texture") then
        if CS_IsOwnedBlizzardSlotTexture(region) then
          if region.SetAlpha then
            region:SetAlpha(0)
          end
        end
      end
    end
  end

  -- Blizzard can restore slot masks/chrome during its own refresh paths.
  IconSkin.MakeIconSquare(button, { crop = 0.08 })
end


-- CharacterFrame shell background

local function EnsureShellHost()
  if not CharacterFrame then
    return
  end

  local host = CharacterSheet._shellHost

  if not host then
    host = CreateFrame("Frame", "PUI_CharacterShellHost", CharacterFrame)
    CharacterSheet._shellHost = host

    -- Never eat mouse input (let Blizzard frame handle all clicks).
    if host.EnableMouse then host:EnableMouse(false) end
    if host.SetMouseClickEnabled then host:SetMouseClickEnabled(false) end
  end

  host:ClearAllPoints()

  if CharacterSheet._shellExtended then
    host:SetPoint("TOPLEFT",     CharacterFrame, "TOPLEFT",     0,           0)
    -- Extend down to cover Character/Reputation/Currency tabs.
    host:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", 0,          -CS_SHELL_BOTTOM_EXTENSION)
  else
    host:SetAllPoints(CharacterFrame)
  end

  ns.Theme.WidgetSkins.Frame(host)
end

function CharacterSheet:SetShellExtended(extended)
  extended = not not extended

  if CharacterSheet._shellHost and CharacterSheet._shellExtended == extended then
    return
  end

  CharacterSheet._shellExtended = extended
  EnsureShellHost()
end

local function CS_ClampCharacterFrameScale(scale)
  scale = tonumber(scale) or 1

  if scale < CS_CHARACTER_SCALE_MIN then
    return CS_CHARACTER_SCALE_MIN
  end

  if scale > CS_CHARACTER_SCALE_MAX then
    return CS_CHARACTER_SCALE_MAX
  end

  return scale
end

local function CS_SetCharacterFrameScaledTopLeft(left, top, scale)
  local uiScale = UIParent:GetEffectiveScale()

  CharacterFrame:ClearAllPoints()
  CharacterFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / (uiScale * scale), top / (uiScale * scale))
end

local function CS_SaveCharacterFrameWindowState()
  if not CharacterFrame then
    return
  end

  local left, bottom, width, height = CharacterFrame:GetScaledRect()
  if not (left and bottom and width and height) then
    return
  end

  local db = _CS_GetDB()
  db.windowScale = CS_ClampCharacterFrameScale(CharacterFrame:GetScale())
  db.windowLeft = left
  db.windowTop = bottom + height
end

local function CS_ApplyCharacterFrameWindowState()
  if not CharacterFrame or CharacterSheet._characterDragging or CharacterSheet._characterResizeState then
    return
  end

  local db = _CS_GetDB()
  local scale = CS_ClampCharacterFrameScale(db.windowScale)

  if CharacterFrame:GetScale() ~= scale then
    CharacterFrame:SetScale(scale)
  end

  local left = tonumber(db.windowLeft)
  local top = tonumber(db.windowTop)
  if not (left and top) then
    return
  end

  CS_SetCharacterFrameScaledTopLeft(left, top, scale)
end

local function CS_UpdateCharacterFrameResize(grip)
  local state = CharacterSheet._characterResizeState
  if not state then
    grip:SetScript("OnUpdate", nil)
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local deltaX = cursorX - state.cursorX
  local deltaY = cursorY - state.cursorY
  local denominator = (state.width * state.width) + (state.height * state.height)
  if denominator <= 0 then
    return
  end

  local ratio = 1 + (((deltaX * state.width) - (deltaY * state.height)) / denominator)
  local scale = CS_ClampCharacterFrameScale(state.scale * ratio)

  CharacterFrame:SetScale(scale)
  CS_SetCharacterFrameScaledTopLeft(state.left, state.top, scale)
end

local function CS_EndCharacterFrameResize()
  local grip = CharacterFrame and CharacterFrame._puiCharacterResizeGrip
  if grip then
    grip:SetScript("OnUpdate", nil)
  end

  if not CharacterSheet._characterResizeState then
    return
  end

  CharacterSheet._characterResizeState = nil
  CS_SaveCharacterFrameWindowState()
end

local function CS_BeginCharacterFrameResize()
  if not CharacterFrame then
    return
  end

  local left, bottom, width, height = CharacterFrame:GetScaledRect()
  if not (left and bottom and width and height) then
    return
  end

  local scale = CS_ClampCharacterFrameScale(CharacterFrame:GetScale())
  local cursorX, cursorY = GetCursorPosition()
  local visualHeight = height

  if CharacterSheet._shellExtended then
    visualHeight = visualHeight + (CS_SHELL_BOTTOM_EXTENSION * CharacterFrame:GetEffectiveScale())
  end

  CharacterSheet._characterResizeState = {
    cursorX = cursorX,
    cursorY = cursorY,
    scale = scale,
    left = left,
    top = bottom + height,
    width = width,
    height = visualHeight,
  }

  CS_SetCharacterFrameScaledTopLeft(left, bottom + height, scale)
  CharacterFrame._puiCharacterResizeGrip:SetScript("OnUpdate", CS_UpdateCharacterFrameResize)
end

local function CS_BeginCharacterFrameDrag()
  CS_EndCharacterFrameResize()
  CharacterSheet._characterDragging = true
  CharacterFrame:StartMoving()
  CharacterFrame:SetUserPlaced(false)
end

local function CS_EndCharacterFrameDrag()
  if not CharacterSheet._characterDragging then
    return
  end

  CharacterFrame:StopMovingOrSizing()
  CharacterSheet._characterDragging = false

  CS_SaveCharacterFrameWindowState()
  CS_ApplyCharacterFrameWindowState()
end

local function CS_StopCharacterFrameInteraction()
  CS_EndCharacterFrameResize()
  CS_EndCharacterFrameDrag()
end

local function CS_AfterUIPanelPositionsUpdated()
  if CharacterFrame and CharacterFrame:IsShown() then
    CS_ApplyCharacterFrameWindowState()
  end
end

local function CS_EnsureCharacterFrameWindowControls()
  if not CharacterFrame then
    return
  end

  EnsureShellHost()

  local drag = CharacterFrame.TitleContainer
  if not drag._puiCharacterDragOwner then
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:HookScript("OnDragStart", CS_BeginCharacterFrameDrag)
    drag:HookScript("OnDragStop", CS_EndCharacterFrameDrag)
    drag._puiCharacterDragOwner = true
  end

  local grip = CharacterFrame._puiCharacterResizeGrip
  if not grip then
    grip = CreateFrame("Frame", "PUI_CharacterFrameResizeGrip", CharacterFrame)
    CharacterFrame._puiCharacterResizeGrip = grip

    grip:SetFrameStrata("DIALOG")
    grip:SetFrameLevel(CharacterFrame:GetFrameLevel() + 100)
    grip:SetSize(18, 18)
    grip:EnableMouse(true)
    grip._puiLines = {}

    for i = 0, 2 do
      local length = 12 - (i * 4)
      local offset = 2 + (i * 4)

      local horizontal = grip:CreateTexture(nil, "OVERLAY")
      horizontal:SetSize(length, 2)
      horizontal:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -2, offset)
      grip._puiLines[#grip._puiLines + 1] = horizontal

      local vertical = grip:CreateTexture(nil, "OVERLAY")
      vertical:SetSize(2, length)
      vertical:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -offset, 2)
      grip._puiLines[#grip._puiLines + 1] = vertical
    end

    grip:SetScript("OnMouseDown", function(_, button)
      if button == "LeftButton" then
        CS_BeginCharacterFrameResize()
      end
    end)
    grip:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" then
        CS_EndCharacterFrameResize()
      end
    end)
  end

  grip:ClearAllPoints()
  grip:SetPoint("BOTTOMRIGHT", CharacterSheet._shellHost, "BOTTOMRIGHT", -4, 4)

  local ar, ag, ab = CS_ACCENT()
  for _, texture in ipairs(grip._puiLines) do
    texture:SetColorTexture(ar, ag, ab, 0.75)
  end

  if not CharacterFrame._puiCharacterWindowHooks then
    hooksecurefunc(CharacterFrame, "Show", CS_ApplyCharacterFrameWindowState)
    hooksecurefunc(CharacterFrame, "Hide", CS_StopCharacterFrameInteraction)
    hooksecurefunc("UpdateUIPanelPositions", CS_AfterUIPanelPositionsUpdated)
    CharacterFrame._puiCharacterWindowHooks = true
  end
end

local function EnsureCharacterAverageItemLevelText()
  if not (CharacterFrame and CharacterStatsPane and CharacterStatsPane.ItemLevelFrame and CharacterStatsPane.ItemLevelFrame.Value) then
    return nil
  end

  local fs = CharacterFrame._puiAvgItemLevelText
  if not fs then
    fs = CharacterStatsPane.ItemLevelFrame:CreateFontString(nil, "ARTWORK")
    CharacterFrame._puiAvgItemLevelText = fs
    fs:SetPoint("CENTER", CharacterStatsPane.ItemLevelFrame.Value, "CENTER", 0, -1)
    ns.Theme.ApplyFont(fs, "body")
  end

  return fs
end

local function CS_GetShowBagItemLevel()
  local csdb = _CS_GetDB()
  return csdb and csdb.showBagItemLevel == true
end

local function CS_GetShowStatRatings()
  local csdb = _CS_GetDB()
  return csdb and csdb.showStatRatings == true
end

local function CS_GetHighlightStatGear()
  local csdb = _CS_GetDB()
  return not csdb or csdb.highlightStatGear ~= false
end

local function CS_GetShowMaxHealth()
  local csdb = _CS_GetDB()
  return not csdb or csdb.showMaxHealth ~= false
end

local function CS_GetUsePleebUIFont()
  local csdb = _CS_GetDB()
  return csdb and csdb.usePleebUIFont == true
end

local function CS_TrackCharacterStatFrame(statFrame)
  if not (statFrame and statFrame.Label and statFrame.Value) then
    return
  end

  if not statFrame._puiCharacterStatFontTracked then
    CharacterSheet._statFontFrames[#CharacterSheet._statFontFrames + 1] = statFrame
    statFrame._puiCharacterStatFontTracked = true
  end
end

local function CS_RestoreCharacterStatFont(statFrame)
  if not (statFrame and statFrame.Label and statFrame.Value) then
    return
  end

  local labelR, labelG, labelB, labelA = statFrame.Label:GetTextColor()
  local valueR, valueG, valueB, valueA = statFrame.Value:GetTextColor()
  local secondaryValue = statFrame._puiSecondaryStatValue

  Theme._AppliedFonts[statFrame.Label] = nil
  Theme._AppliedFonts[statFrame.Value] = nil
  if secondaryValue then
    Theme._AppliedFonts[secondaryValue] = nil
  end

  statFrame.Label:SetFontObject(_G.GameFontNormalSmall)
  statFrame.Value:SetFontObject(_G.STATFRAME_STATTEXT_FONT_OVERRIDE or _G.GameFontHighlightSmall)
  if secondaryValue then
    secondaryValue:SetFontObject(_G.STATFRAME_STATTEXT_FONT_OVERRIDE or _G.GameFontHighlightSmall)
  end

  statFrame.Label:SetTextColor(labelR, labelG, labelB, labelA)
  statFrame.Value:SetTextColor(valueR, valueG, valueB, valueA)
  if secondaryValue then
    secondaryValue:SetTextColor(valueR, valueG, valueB, valueA)
  end
end

local function CS_ApplyCharacterStatFont(statFrame)
  if not (statFrame and statFrame.Label and statFrame.Value) or statFrame == CharacterStatsPane.ItemLevelFrame then
    return
  end

  CS_TrackCharacterStatFrame(statFrame)

  if CS_GetUsePleebUIFont() then
    Theme.ApplyFont(statFrame.Label, "body")
    Theme.ApplyFont(statFrame.Value, "body")
    if statFrame._puiSecondaryStatValue then
      Theme.ApplyFont(statFrame._puiSecondaryStatValue, "body")
    end
    return
  end

  CS_RestoreCharacterStatFont(statFrame)
end

local function CS_RefreshCharacterStatFonts()
  for _, statFrame in ipairs(CharacterSheet._statFontFrames) do
    CS_ApplyCharacterStatFont(statFrame)
  end
end

local function UpdateCharacterAverageItemLevelText()
  if not (CharacterFrame and CharacterStatsPane and CharacterStatsPane.ItemLevelFrame and CharacterStatsPane.ItemLevelFrame.Value) then
    return
  end

  local fs = EnsureCharacterAverageItemLevelText()
  if not fs then
    return
  end

  CharacterStatsPane.ItemLevelFrame.Value:Hide()

  local itemLevel = CS_GetPlayerEquippedItemLevel()
  if not itemLevel then
    fs:SetText("")
    fs:Hide()
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  if CharacterStatsPane.ItemLevelFrame.Value.GetTextColor then
    tr, tg, tb, ta = CharacterStatsPane.ItemLevelFrame.Value:GetTextColor()
  end

  local itemLevelText = CS_FormatItemLevel(itemLevel)
  if CS_GetShowBagItemLevel() then
    local availableItemLevel = GetAverageItemLevel()
    local availableItemLevelText = CS_FormatItemLevel(availableItemLevel)
    if availableItemLevelText ~= "" then
      itemLevelText = format("%s (%s)", itemLevelText, availableItemLevelText)
    end
  end

  fs:SetTextColor(tr, tg, tb, ta)
  fs:SetText(itemLevelText)
  fs:Show()
end

local ITEM_STAT_CRIT = "ITEM_MOD_CRIT_RATING_SHORT"
local ITEM_STAT_HASTE = "ITEM_MOD_HASTE_RATING_SHORT"
local ITEM_STAT_MASTERY = "ITEM_MOD_MASTERY_RATING_SHORT"
local ITEM_STAT_VERSATILITY = "ITEM_MOD_VERSATILITY"
local ITEM_STAT_LIFESTEAL = "ITEM_MOD_CR_LIFESTEAL_SHORT"
local ITEM_STAT_AVOIDANCE = "ITEM_MOD_CR_AVOIDANCE_SHORT"
local ITEM_STAT_SPEED = "ITEM_MOD_CR_SPEED_SHORT"

local ITEM_STAT_DISPLAY_NAMES = {
  [ITEM_STAT_CRIT] = _G.STAT_CRITICAL_STRIKE,
  [ITEM_STAT_HASTE] = _G.STAT_HASTE,
  [ITEM_STAT_MASTERY] = _G.STAT_MASTERY,
  [ITEM_STAT_VERSATILITY] = _G.STAT_VERSATILITY,
  [ITEM_STAT_LIFESTEAL] = _G.STAT_LIFESTEAL,
  [ITEM_STAT_AVOIDANCE] = _G.STAT_AVOIDANCE,
  [ITEM_STAT_SPEED] = _G.STAT_SPEED,
}

local SECONDARY_STAT_RATING_IDS = {
  [ITEM_STAT_CRIT] = _G.CR_CRIT_MELEE,
  [ITEM_STAT_HASTE] = _G.CR_HASTE_MELEE,
  [ITEM_STAT_MASTERY] = _G.CR_MASTERY,
  [ITEM_STAT_VERSATILITY] = _G.CR_VERSATILITY_DAMAGE_DONE,
}

local function CS_ClearSecondaryStatRatingText(statFrame)
  local secondaryValue = statFrame and statFrame._puiSecondaryStatValue
  if secondaryValue then
    secondaryValue:SetText("")
    secondaryValue:Hide()
  end

  if statFrame and statFrame.Value then
    statFrame.Value:Show()
  end
end

local function CS_ForwardSecondaryStatRatingText(statFrame, ratingID)
  if not (statFrame and statFrame.Value and ratingID) then
    return
  end

  if not CS_GetShowStatRatings() then
    CS_ClearSecondaryStatRatingText(statFrame)
    return
  end

  local secondaryValue = statFrame._puiSecondaryStatValue
  if not secondaryValue then
    secondaryValue = statFrame:CreateFontString(nil, "ARTWORK")
    secondaryValue:SetPoint("RIGHT", statFrame, "RIGHT", -8, 0)
    statFrame._puiSecondaryStatValue = secondaryValue
    CS_ApplyCharacterStatFont(statFrame)
  end

  secondaryValue:SetFormattedText("%s (%s)", statFrame.Value:GetText(), _G.GetCombatRating(ratingID))
  statFrame.Value:Hide()
  secondaryValue:Show()
end

local function CS_RefreshSecondaryStatRatingTexts()
  for _, statFrame in ipairs(CharacterSheet._statFontFrames) do
    local statKey = statFrame and statFrame._puiItemStatKey
    local ratingID = statKey and SECONDARY_STAT_RATING_IDS[statKey]

    if ratingID then
      CS_ForwardSecondaryStatRatingText(statFrame, ratingID)
    else
      CS_ClearSecondaryStatRatingText(statFrame)
    end
  end
end

local function CS_EnsureMaxHealthRow()
  if not CharacterStatsPane then
    return nil
  end

  local row = CharacterSheet._maxHealthRow
  if row then
    return row
  end

  row = CreateFrame("Frame", nil, CharacterStatsPane)
  row:SetSize(187, 15)

  row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.Label:SetPoint("LEFT", row, "LEFT", 11, 0)
  row.Label:SetText("Max Health")

  row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.Value:SetPoint("RIGHT", row, "RIGHT", -8, 0)

  CharacterSheet._maxHealthRow = row
  CS_ApplyCharacterStatFont(row)
  return row
end

local function CS_UpdateMaxHealthValue()
  local row = CS_EnsureMaxHealthRow()
  if not row or not CS_GetShowMaxHealth() then
    return
  end

  local maxHealth = _G.UnitHealthMax("player")
  if issecretvalue(maxHealth) then
    row.Value:SetText(maxHealth)
    return
  end

  row.Value:SetText(_G.BreakUpLargeNumbers(maxHealth))
end

local function CS_LayoutMaxHealthRow()
  if not CharacterStatsPane then
    return
  end

  local row = CS_EnsureMaxHealthRow()
  if not row then
    return
  end

  local staminaFrame
  local armorFrame

  for _, statFrame in ipairs(CharacterSheet._statFontFrames) do
    if statFrame and statFrame.IsShown and statFrame:IsShown() then
      if statFrame._puiAttributeStat == "STAMINA" then
        staminaFrame = statFrame
      elseif statFrame._puiAttributeStat == "ARMOR" then
        armorFrame = statFrame
      end
    end
  end

  if not (staminaFrame and armorFrame) then
    row:Hide()
    return
  end

  armorFrame:ClearAllPoints()

  if not CS_GetShowMaxHealth() then
    row:Hide()
    armorFrame:SetPoint("TOP", staminaFrame, "BOTTOM", 0, 0)
    return
  end

  row:ClearAllPoints()
  row:SetPoint("TOP", staminaFrame, "BOTTOM", 0, 0)
  armorFrame:SetPoint("TOP", row, "BOTTOM", 0, 0)

  CS_UpdateMaxHealthValue()
  row:Show()
end

local function CS_SetItemStatHighlightVisible(highlight, visible, immediate)
  if not highlight then
    return
  end

  local fadeIn = highlight._puiFadeIn
  local fadeOut = highlight._puiFadeOut

  if immediate then
    if fadeIn then
      fadeIn:Stop()
    end
    if fadeOut then
      fadeOut:Stop()
    end

    highlight._puiStatVisible = visible
    highlight:SetAlpha(visible and 1 or 0)
    highlight:SetShown(visible)
    return
  end

  if visible then
    if fadeOut and fadeOut:IsPlaying() then
      fadeOut:Stop()
    end

    highlight:SetAlpha(1)
    highlight:Show()

    if highlight._puiStatVisible then
      return
    end

    highlight._puiStatVisible = true
    if fadeIn then
      fadeIn:Play()
    end
    return
  end

  if not highlight._puiStatVisible then
    return
  end

  if fadeOut and not fadeOut:IsPlaying() then
    fadeOut:Play()
  end
end

local function CS_ClearItemStatHighlights(immediate)
  if not CharacterSheet._activeItemStatHighlight and not immediate then
    return
  end

  CharacterSheet._activeItemStatHighlight = false

  local frame = _G.PaperDollItemsFrame
  if not (frame and frame.GetChildren) then
    return
  end

  for _, button in ipairs({ frame:GetChildren() }) do
    CS_SetItemStatHighlightVisible(button and button._puiCharStatHighlight, false, immediate)
  end
end

local function CS_RequestItemStatHighlightClear()
  local hovered = CharacterSheet._hoveredStatFrame
  if hovered and hovered.IsMouseOver and hovered:IsMouseOver() then
    return
  end

  CharacterSheet._hoveredStatFrame = nil
  CS_ClearItemStatHighlights(false)
end

local function CS_ShowItemStatHighlights(statFrame)
  if InCombatLockdown() or not CS_GetHighlightStatGear() then
    return
  end

  local statKey = statFrame and statFrame._puiItemStatKey
  if not statKey then
    return
  end

  CharacterSheet._hoveredStatFrame = statFrame

  if CharacterSheet._activeItemStatHighlight == statKey then
    return
  end

  CS_ClearItemStatHighlights()
  CharacterSheet._activeItemStatHighlight = statKey

  local frame = _G.PaperDollItemsFrame
  if not (frame and frame.GetChildren) then
    return
  end

  for _, button in ipairs({ frame:GetChildren() }) do
    local presence = button and button._puiCharItemStatPresence
    local highlight = button and button._puiCharStatHighlight
    if presence and highlight and presence[statKey] == true then
      CS_SetItemStatHighlightVisible(highlight, true, false)
    end
  end
end

local function CS_SetupPaperDollValueHooks()
  if CharacterSheet._paperDollValueHooks then
    return
  end

  hooksecurefunc("PaperDollFrame_UpdateStats", function()
    UpdateCharacterAverageItemLevelText()
    CS_LayoutMaxHealthRow()
  end)
  hooksecurefunc("PaperDollFrame_SetLabelAndText", function(statFrame)
    statFrame._puiItemStatKey = nil
    statFrame._puiAttributeStat = nil
    CS_ClearSecondaryStatRatingText(statFrame)
    CS_ApplyCharacterStatFont(statFrame)
  end)
  hooksecurefunc("PaperDollFrame_SetStat", function(statFrame, _, statIndex)
    if statIndex == _G.LE_UNIT_STAT_STAMINA then
      statFrame._puiAttributeStat = "STAMINA"
    end
  end)
  hooksecurefunc("PaperDollFrame_SetArmor", function(statFrame)
    statFrame._puiAttributeStat = "ARMOR"
  end)
  hooksecurefunc("PaperDollFrame_SetCritChance", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_CRIT
    CS_ForwardSecondaryStatRatingText(statFrame, SECONDARY_STAT_RATING_IDS[ITEM_STAT_CRIT])
  end)
  hooksecurefunc("PaperDollFrame_SetHaste", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_HASTE
    CS_ForwardSecondaryStatRatingText(statFrame, SECONDARY_STAT_RATING_IDS[ITEM_STAT_HASTE])
  end)
  hooksecurefunc("PaperDollFrame_SetMastery", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_MASTERY
    CS_ForwardSecondaryStatRatingText(statFrame, SECONDARY_STAT_RATING_IDS[ITEM_STAT_MASTERY])
  end)
  hooksecurefunc("PaperDollFrame_SetVersatility", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_VERSATILITY
    CS_ForwardSecondaryStatRatingText(statFrame, SECONDARY_STAT_RATING_IDS[ITEM_STAT_VERSATILITY])
  end)
  hooksecurefunc("PaperDollFrame_SetLifesteal", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_LIFESTEAL
  end)
  hooksecurefunc("PaperDollFrame_SetAvoidance", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_AVOIDANCE
  end)
  hooksecurefunc("PaperDollFrame_SetSpeed", function(statFrame)
    statFrame._puiItemStatKey = ITEM_STAT_SPEED
  end)
  hooksecurefunc("PaperDollStatTooltip", CS_ShowItemStatHighlights)
  hooksecurefunc("Mastery_OnEnter", CS_ShowItemStatHighlights)
  hooksecurefunc("GameTooltip_Hide", CS_RequestItemStatHighlightClear)

  CharacterSheet._paperDollValueHooks = true
end

local function CS_SetShowBagItemLevel(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.showBagItemLevel = not not v
  end

  UpdateCharacterAverageItemLevelText()
end

local function CS_SetShowStatRatings(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.showStatRatings = not not v
  end

  if CharacterStatsPane and CharacterStatsPane.IsShown and CharacterStatsPane:IsShown() then
    CS_RefreshSecondaryStatRatingTexts()
  end
end

local function CS_SetHighlightStatGear(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.highlightStatGear = not not v
  end

  CS_ClearItemStatHighlights()
  if v and CS_RefreshPlayerItemStatPresence then
    CS_RefreshPlayerItemStatPresence()
  end
end

local function CS_SetShowMaxHealth(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.showMaxHealth = not not v
  end

  CS_LayoutMaxHealthRow()
end

local function CS_SetUsePleebUIFont(v)
  local csdb = _CS_GetDB()
  if csdb then
    csdb.usePleebUIFont = not not v
  end

  CS_RefreshCharacterStatFonts()
end

local function EnsureInspectAverageItemLevelText()
  if not (InspectFrame and InspectPaperDollItemsFrame) then
    return nil
  end

  local fs = InspectFrame._puiAvgItemLevelText
  if not fs then
    fs = InspectPaperDollItemsFrame:CreateFontString(nil, "ARTWORK")
    InspectFrame._puiAvgItemLevelText = fs
    fs:SetPoint("BOTTOMLEFT", InspectPaperDollItemsFrame, "BOTTOMLEFT", 6, 6)
  end

  ns.Theme.ApplyFont(fs, "body")
  return fs
end

local function UpdateInspectAverageItemLevelText(expectedGUID)
  if not InspectFrame then
    return
  end

  local fs = EnsureInspectAverageItemLevelText()
  if not fs then
    return
  end

  if not (InspectPaperDollFrame and InspectPaperDollFrame.IsShown and InspectPaperDollFrame:IsShown()) then
    fs:SetText("")
    fs:Hide()
    return
  end

  local unit = InspectFrame.unit
  if not unit or not UnitExists(unit) then
    fs:SetText("")
    fs:Hide()
    return
  end

  if expectedGUID and UnitGUID(unit) ~= expectedGUID then
    return
  end

  local itemLevel = CS_CalculateUnitAverageItemLevel(unit)
  if not itemLevel then
    fs:SetText("")
    fs:Hide()
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  fs:SetTextColor(tr, tg, tb, ta)
  fs:SetText(CS_FormatItemLevel(itemLevel))
  fs:Show()
end

local function CS_ClearInspectAverageItemLevelText()
  if InspectFrame and InspectFrame._puiAvgItemLevelText then
    InspectFrame._puiAvgItemLevelText:SetText("")
    InspectFrame._puiAvgItemLevelText:Hide()
  end
end

local function CS_HideInspectSlotOverlay(button)
  if button then
    button._puiCharOverlaySignature = nil
    button._puiCharOverlayNextSignature = nil
    button._puiCharOverlayComplete = nil
  end

  local overlay = button and button._puiCharOverlay
  if not overlay then
    return
  end

  if overlay.ilvl then
    overlay.ilvl:SetText("")
    overlay.ilvl:Hide()
  end

  if overlay.enchant then
    overlay.enchant:SetTexture(nil)
    overlay.enchant:Hide()
  end

  if overlay.gems then
    overlay.gems:Hide()
    local icons = overlay.gems.icons or {}
    for i = 1, #icons do
      icons[i]:Hide()
    end
  end
end

local function CS_ClearInspectSlotOverlays()
  for i = 1, 19 do
    local button = _G["Inspect" .. i .. "Slot"]
    if button then
      CS_HideInspectSlotOverlay(button)
    end
  end
end

local function CS_SetInspectPending()
  CharacterSheet._inspectReadyGUID = nil
  CS_ClearInspectAverageItemLevelText()
  CS_ClearInspectSlotOverlays()
end

local function CS_IsInspectReady(unit)
  local guid = unit and UnitGUID(unit)
  return guid and CharacterSheet._inspectReadyGUID and guid == CharacterSheet._inspectReadyGUID
end

local function CS_RefreshInspectData(expectedGUID)
  if not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
    return
  end

  local unit = InspectFrame.unit
  if not unit or not UnitExists(unit) then
    return
  end

  local guid = UnitGUID(unit)
  if expectedGUID and guid ~= expectedGUID then
    return
  end

  if not CS_IsInspectReady(unit) then
    return
  end

  for i = 1, 19 do
    local button = _G["Inspect" .. i .. "Slot"]
    if button then
      SkinItemSlotButton(button)
      UpdateItemSlotOverlay(button, unit, false)
    end
  end

  UpdateInspectAverageItemLevelText(guid)
end

-- Reputation frame entries

local function CS_SkinReputationBar(repBar, tr, tg, tb, ta)
  if not (repBar and repBar.SetStatusBarTexture) then
    return
  end

  repBar:SetStatusBarTexture(Theme.GetBarTexture())

  local ar, ag, ab, aa = CS_ACCENT()
  repBar:SetStatusBarColor(ar * 0.7, ag * 0.7, ab * 0.7, aa)

  if repBar.LeftTexture then
    repBar.LeftTexture:SetAlpha(0)
  end
  if repBar.RightTexture then
    repBar.RightTexture:SetAlpha(0)
  end

  if repBar.Background and repBar.Background.SetColorTexture then
    repBar.Background:SetColorTexture(0, 0, 0, 0.6)
  end

  local sbTex = repBar.GetStatusBarTexture and repBar:GetStatusBarTexture()
  if sbTex and sbTex.SetMaskTexture then
    sbTex:SetMaskTexture(nil)
  end

  if repBar.GetRegions then
    for _, region in ipairs({ repBar:GetRegions() }) do
      if region and region.IsObjectType and region:IsObjectType("Texture") and region.SetMaskTexture then
        region:SetMaskTexture(nil)
      end
    end
  end

  if repBar.BarText then
    ns.Theme.ApplyFont(repBar.BarText, "tiny")
    repBar.BarText:SetTextColor(tr, tg, tb, ta)
  end
end

local function RefreshReputationEntryTheme(entry)
  if not entry then
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  local br, bgG, bB, bA = CS_B()
  local backdrop = EnsureBackdropFrame(entry)

  if backdrop then
    local r, g, b, a = CS_CONTROL()
    backdrop:SetBackdropColor(r, g, b, a)
    backdrop:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  if entry.Name then
    ns.Theme.ApplyFont(entry.Name, entry.Right and "nav" or "body")
    entry.Name:SetTextColor(tr, tg, tb, ta)
  elseif entry.Content and entry.Content.Name then
    ns.Theme.ApplyFont(entry.Content.Name, "body")
    entry.Content.Name:SetTextColor(tr, tg, tb, ta)
  end

  local toggle = entry.ToggleCollapseButton
  if toggle and toggle._puiToggleIcon then
    toggle._puiToggleIcon:SetVertexColor(tr, tg, tb, ta)
  end

  CS_SkinReputationBar(entry.Content and entry.Content.ReputationBar, tr, tg, tb, ta)
end

local function SkinReputationEntry(entry)
  if not entry then
    return
  end

  if entry._puiCharSkinned then
    RefreshReputationEntryTheme(entry)
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  local br, bgG, bB, bA = CS_B()

  -- Top-level header (Expansion headers use Left/Middle/Right atlases)
  if entry.Right and entry.Name then
    StripTextures(entry, true)

    local bg = EnsureBackdropFrame(entry)
    if bg and bg.SetBackdrop then
      local edgeSize = Theme.GetEdgeSize()
      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })

      local r, g, b, a = CS_CONTROL()
      bg:SetBackdropColor(r, g, b, a)
      bg:SetBackdropBorderColor(br, bgG, bB, bA)
    end

    ns.Theme.ApplyFont(entry.Name, "nav")
    entry.Name:SetTextColor(tr, tg, tb, ta)

    -- Replace collapse atlas on the right cap
    local function UpdateCollapseIcon(tex)
      if not (tex and tex.SetAtlas) then return end
      local atlas = tex.GetAtlas and tex:GetAtlas()
      if atlas == "Options_ListExpand_Right" or atlas == "Options_ListExpand_Right_Expanded" then
        if entry.IsCollapsed and entry:IsCollapsed() then
          tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true)
        else
          tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true)
        end
      end
    end

    UpdateCollapseIcon(entry.Right)
    UpdateCollapseIcon(entry.HighlightRight)

    if entry.Right and entry.Right.SetAtlas then
      hooksecurefunc(entry.Right, "SetAtlas", function() UpdateCollapseIcon(entry.Right) end)
    end
    if entry.HighlightRight and entry.HighlightRight.SetAtlas then
      hooksecurefunc(entry.HighlightRight, "SetAtlas", function() UpdateCollapseIcon(entry.HighlightRight) end)
    end

    CS_SkinReputationBar(entry.Content and entry.Content.ReputationBar, tr, tg, tb, ta)

    entry._puiCharSkinned = true
    return
  end

  -- Sub-header (Faction groups like Horde/Alliance have ToggleCollapseButton)
  if entry.ToggleCollapseButton and entry.ToggleCollapseButton.RefreshIcon then
    StripTextures(entry, true)

    local bg = EnsureBackdropFrame(entry)
    if bg and bg.SetBackdrop then
      local edgeSize = Theme.GetEdgeSize()
      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })

      local r, g, b, a = CS_CONTROL()
      bg:SetBackdropColor(r, g, b, a)
      bg:SetBackdropBorderColor(br, bgG, bB, bA)
    end

    if entry.Name then
      ns.Theme.ApplyFont(entry.Name, "body")
      entry.Name:SetTextColor(tr, tg, tb, ta)
    end

    local function UpdateToggleButton(btn)
      local header = btn.GetHeader and btn:GetHeader()
      if not header then return end

      StripTextures(btn, true)

      if btn.SetNormalTexture then btn:SetNormalTexture("") end
      if btn.SetPushedTexture then btn:SetPushedTexture("") end
      if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
      if btn.SetDisabledTexture then btn:SetDisabledTexture("") end

      if not btn._puiToggleIcon then
        local tex = btn:CreateTexture(nil, "OVERLAY")
        btn._puiToggleIcon = tex
      end

      local tex = btn._puiToggleIcon
      tex:ClearAllPoints()
      tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
      tex:SetSize(16, 16)
      local rr, rg, rb, ra = GetTextColor()
      tex:SetVertexColor(rr, rg, rb, ra)

      if header:IsCollapsed() then
        if tex.SetAtlas then tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true) end
      else
        if tex.SetAtlas then tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true) end
      end

      if tex.Show then
        tex:Show()
      end
    end

    if not entry.ToggleCollapseButton._puiHooked then
      hooksecurefunc(entry.ToggleCollapseButton, "RefreshIcon", UpdateToggleButton)
      entry.ToggleCollapseButton._puiHooked = true
    end
    UpdateToggleButton(entry.ToggleCollapseButton)

    CS_SkinReputationBar(entry.Content and entry.Content.ReputationBar, tr, tg, tb, ta)

    entry._puiCharSkinned = true
    return
  end

  -- Normal reputation entry (Content + ReputationBar)
  StripTextures(entry, true)

  local bg = EnsureBackdropFrame(entry)
  if bg and bg.SetBackdrop then
    local edgeSize = Theme.GetEdgeSize()
    bg:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edgeSize,
    })

    local r, g, b, a = CS_CONTROL()
    bg:SetBackdropColor(r, g, b, a)
    bg:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  if entry.Content and entry.Content.Name then
    ns.Theme.ApplyFont(entry.Content.Name, "body")
    entry.Content.Name:SetTextColor(tr, tg, tb, ta)
  end

  CS_SkinReputationBar(entry.Content and entry.Content.ReputationBar, tr, tg, tb, ta)

  entry._puiCharSkinned = true
end


-- Currency frame entries

local function RefreshCurrencyEntryTheme(button, isHeader)
  if not button then
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  local br, bgG, bB, bA = CS_B()
  local backdrop = EnsureBackdropFrame(button)

  if backdrop then
    local r, g, b, a = CS_CONTROL()
    backdrop:SetBackdropColor(r, g, b, a)
    backdrop:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  local nameFS = isHeader and (button.Name or button.Text) or (button.Content and button.Content.Name)
  if nameFS then
    ns.Theme.ApplyFont(nameFS, isHeader and "nav" or "body")
    nameFS:SetTextColor(tr, tg, tb, ta)
  end

  if not isHeader and button.Content then
    if button.Content.Count then
      ns.Theme.ApplyFont(button.Content.Count, "body")
      button.Content.Count:SetTextColor(tr, tg, tb, ta)
    end

    local icon = button.Content.CurrencyIcon
    if icon and icon._puiBorder then
      icon._puiBorder:SetBackdropBorderColor(br, bgG, bB, bA)
    end
  end

  local toggle = button.ToggleCollapseButton
  if toggle and toggle._puiToggleIcon then
    toggle._puiToggleIcon:SetVertexColor(tr, tg, tb, ta)
  end
end

local function SkinCurrencyEntry(button)
  if not button then
    return
  end

  if button._puiCharSkinned then
    RefreshCurrencyEntryTheme(button, false)
    return
  end

  StripTextures(button, true)

  local tr, tg, tb, ta = GetTextColor()
  local br, bgG, bB, bA = CS_B()

  local bg = EnsureBackdropFrame(button)
  if bg and bg.SetBackdrop then
    local edgeSize = Theme.GetEdgeSize()
    bg:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edgeSize,
    })

    local r, g, b, a = CS_CONTROL()
    bg:SetBackdropColor(r, g, b, a)
    bg:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  local content = button.Content
  if content then
    if content.Name then
      ns.Theme.ApplyFont(content.Name, "body")
      content.Name:SetTextColor(tr, tg, tb, ta)
    end
    if content.Count then
      ns.Theme.ApplyFont(content.Count, "body")
      content.Count:SetTextColor(tr, tg, tb, ta)
    end

    local icon = content.CurrencyIcon
    if icon then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

      if not icon._puiBorder then
        local ib = CreateFrame("Frame", nil, icon:GetParent(), "BackdropTemplate")
        ib:SetPoint("TOPLEFT", icon, -1, 1)
        ib:SetPoint("BOTTOMRIGHT", icon, 1, -1)

        local edgeSize = Theme.GetEdgeSize()
        ib:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        ib:SetBackdropColor(0, 0, 0, 0.8)
        ib:SetBackdropBorderColor(br, bgG, bB, bA)
        icon._puiBorder = ib
      else
        icon._puiBorder:SetBackdropBorderColor(br, bgG, bB, bA)
      end
    end
  end

  -- Sub-category collapse toggle
  local tcb = button.ToggleCollapseButton
  if tcb and tcb.RefreshIcon then
    local function UpdateToggle(btn)
      local header = btn.GetHeader and btn:GetHeader()
      if not header then return end

      StripTextures(btn, true)

      if btn.SetNormalTexture then btn:SetNormalTexture("") end
      if btn.SetPushedTexture then btn:SetPushedTexture("") end
      if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
      if btn.SetDisabledTexture then btn:SetDisabledTexture("") end

      if not btn._puiToggleIcon then
        local tex = btn:CreateTexture(nil, "OVERLAY")
        btn._puiToggleIcon = tex
      end

      local tex = btn._puiToggleIcon
      tex:ClearAllPoints()
      tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
      tex:SetSize(16, 16)
      local rr, rg, rb, ra = GetTextColor()
      tex:SetVertexColor(rr, rg, rb, ra)

      if header:IsCollapsed() then
        if tex.SetAtlas then tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true) end
      else
        if tex.SetAtlas then tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true) end
      end

      if tex.Show then
        tex:Show()
      end
    end

    if not tcb._puiHooked then
      hooksecurefunc(tcb, "RefreshIcon", UpdateToggle)
      tcb._puiHooked = true
    end
    UpdateToggle(tcb)
  end

  button._puiCharSkinned = true
end

local function SkinCurrencyHeader(button)
  if not button then
    return
  end

  if button._puiCharSkinned then
    RefreshCurrencyEntryTheme(button, true)
    return
  end

  StripTextures(button, true)

  local tr, tg, tb, ta = GetTextColor()
  local br, bgG, bB, bA = CS_B()

  local bg = EnsureBackdropFrame(button)
  if bg and bg.SetBackdrop then
    local edgeSize = Theme.GetEdgeSize()
    bg:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edgeSize,
    })

    local r, g, b, a = CS_CONTROL()
    bg:SetBackdropColor(r, g, b, a)
    bg:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  local nameFS = button.Name or button.Text
  if nameFS then
    ns.Theme.ApplyFont(nameFS, "nav")
    nameFS:SetTextColor(tr, tg, tb, ta)
  end

  -- Main category plus/minus (match Reputation styling)
  local function UpdateCollapseIcon(tex)
    if not (tex and tex.SetAtlas) then return end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas == "Options_ListExpand_Right" or atlas == "Options_ListExpand_Right_Expanded" then
      if button.IsCollapsed and button:IsCollapsed() then
        tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true)
      else
        tex:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true)
      end
    end
  end

  UpdateCollapseIcon(button.Right)
  UpdateCollapseIcon(button.HighlightRight)

  if not button._puiHeaderCollapseHooked then
    if button.Right and button.Right.SetAtlas then
      hooksecurefunc(button.Right, "SetAtlas", function() UpdateCollapseIcon(button.Right) end)
    end
    if button.HighlightRight and button.HighlightRight.SetAtlas then
      hooksecurefunc(button.HighlightRight, "SetAtlas", function() UpdateCollapseIcon(button.HighlightRight) end)
    end
    button._puiHeaderCollapseHooked = true
  end

  button._puiCharSkinned = true
end

local function SkinCurrencyButton(button)
  if not button then
    return
  end

  local kind
  if button.ToggleCollapseButton and button.ToggleCollapseButton.RefreshIcon then
    kind = "subheader"
  elseif (button.Right and (button.Name or button.Text)) or button.CategoryLeft or button.CategoryRight or button.CategoryMiddle then
    kind = "header"
  else
    kind = "row"
  end

  if button._puiCharSkinKind ~= kind then
    button._puiCharSkinned = nil
    button._puiCharSkinKind = kind
  end

  if kind == "subheader" then
    SkinCurrencyEntry(button)
    return
  end

  if kind == "header" then
    SkinCurrencyHeader(button)
    return
  end

  SkinCurrencyEntry(button)
end

-- Supplemental character / inspect parity skinning
local function CS_ApplyBackdrop(frame, colorFunc)
  if not frame then
    return nil
  end

  local bg = EnsureBackdropFrame(frame)
  if not (bg and bg.SetBackdrop) then
    return bg
  end

  local edgeSize = Theme.GetEdgeSize()
  bg:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edgeSize,
  })

  local r, g, b, a = CS_BG()
  if type(colorFunc) == "function" then
    r, g, b, a = colorFunc()
  end

  local br, bgG, bB, bA = CS_B()
  bg:SetBackdropColor(r, g, b, a)
  bg:SetBackdropBorderColor(br, bgG, bB, bA)

  return bg
end

local function CS_SkinButton(button)
  if not button then
    return
  end

  if not button._puiCharButtonSkinned then
    StripTextures(button, true)
    button._puiCharButtonSkinned = true
  end

  ns.Theme.WidgetSkins.Button(button)

  if button.Text then
    ns.Theme.ApplyFont(button.Text, "body")
    local tr, tg, tb, ta = GetTextColor()
    button.Text:SetTextColor(tr, tg, tb, ta)
  end
end

local function CS_SkinCloseButton(button)
  if not button then
    return
  end

  if not button._puiCharCloseSkinned then
    StripTextures(button, true)
    button._puiCharCloseSkinned = true
  end

  ns.Theme.WidgetSkins.CloseButton(button)
end

local function CS_SkinTextureIcon(icon)
  if not icon then
    return
  end

  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  if icon.SetMaskTexture then
    icon:SetMaskTexture(nil)
  end

  local host = icon._puiCharIconBackdrop
  if not host then
    host = CreateFrame("Frame", nil, icon:GetParent(), "BackdropTemplate")
    icon._puiCharIconBackdrop = host
  end

  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", icon, -1, 1)
  host:SetPoint("BOTTOMRIGHT", icon, 1, -1)
  CS_ApplyBackdrop(host, CS_CONTROL)
end

local function CS_SkinCheckBox(check)
  if not check then
    return
  end

  if not check._puiCharCheckSkinned then
    local nt = check.GetNormalTexture and check:GetNormalTexture()
    if nt and nt.SetAlpha then
      nt:SetAlpha(0)
    end

    local pt = check.GetPushedTexture and check:GetPushedTexture()
    if pt and pt.SetAlpha then
      pt:SetAlpha(0)
    end

    local ht = check.GetHighlightTexture and check:GetHighlightTexture()
    if ht then
      ht:SetColorTexture(1, 1, 1, 0.15)
    end

    check._puiCharCheckSkinned = true
  end

  local box = check._puiCharCheckBackdrop
  if not box then
    box = CreateFrame("Frame", nil, check, "BackdropTemplate")
    check._puiCharCheckBackdrop = box
    box:SetSize(14, 14)
    box:SetPoint("CENTER", check, "CENTER", 0, 0)
  end

  CS_ApplyBackdrop(box, CS_CONTROL)

  local checked = check.Check or (check.GetCheckedTexture and check:GetCheckedTexture())
  if checked then
    if checked.SetTexCoord then
      checked:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if checked.SetVertexColor then
      local ar, ag, ab, aa = CS_ACCENT()
      checked:SetVertexColor(ar, ag, ab, aa)
    end
  end

  if check.Text then
    ns.Theme.ApplyFont(check.Text, "body")
    local tr, tg, tb, ta = GetTextColor()
    check.Text:SetTextColor(tr, tg, tb, ta)
  end
end

local function CS_SkinDropDown(dropdown)
  if not dropdown then
    return
  end

  if not dropdown._puiCharDropSkinned then
    StripTextures(dropdown, true)
    dropdown._puiCharDropSkinned = true
  end

  CS_ApplyBackdrop(dropdown, CS_CONTROL)

  if dropdown.Text then
    ns.Theme.ApplyFont(dropdown.Text, "body")
    local tr, tg, tb, ta = GetTextColor()
    dropdown.Text:SetTextColor(tr, tg, tb, ta)
  end

  if dropdown.Button then
    CS_SkinButton(dropdown.Button)
  end

  if dropdown.DropdownButton then
    CS_SkinButton(dropdown.DropdownButton)
  end
end

local function CS_SkinEditBox(editBox)
  if not editBox then
    return
  end

  if not editBox._puiCharEditSkinned then
    StripTextures(editBox, true)
    editBox._puiCharEditSkinned = true
  end

  CS_ApplyBackdrop(editBox, CS_CONTROL)

  if editBox.SetTextInsets then
    editBox:SetTextInsets(6, 6, 0, 0)
  end
end

local function CS_SkinScrollBar(scrollBar)
  if not scrollBar then
    return
  end

  if not scrollBar._puiCharScrollSkinned then
    if scrollBar.Track and scrollBar.Track.SetAlpha then
      scrollBar.Track:SetAlpha(0.25)
    end

    if scrollBar.Thumb and scrollBar.Thumb.SetAlpha then
      scrollBar.Thumb:SetAlpha(0.80)
    end

    scrollBar._puiCharScrollSkinned = true
  end

  if scrollBar.BackButton then
    CS_SkinButton(scrollBar.BackButton)
  end

  if scrollBar.ForwardButton then
    CS_SkinButton(scrollBar.ForwardButton)
  end

  if scrollBar.ScrollUpButton then
    CS_SkinButton(scrollBar.ScrollUpButton)
  end

  if scrollBar.ScrollDownButton then
    CS_SkinButton(scrollBar.ScrollDownButton)
  end
end

local function CS_SkinModelControlButtons(controlFrame)
  if not controlFrame then
    return
  end

  for _, key in ipairs({
    "zoomInButton",
    "zoomOutButton",
    "rotateLeftButton",
    "rotateRightButton",
    "resetButton",
  }) do
    local button = controlFrame[key]
    CS_SkinButton(button)
    button:Init()
    button.Icon:SetAlpha(1)
    button.Icon:Show()
  end
end

local function CS_SkinSidebarTabs()
  local index = 1
  local tab = _G["PaperDollSidebarTab" .. index]

  while tab do
    CS_ApplyBackdrop(tab, CS_CONTROL)

    local nt = tab.GetNormalTexture and tab:GetNormalTexture()
    if nt and nt.SetAlpha then
      nt:SetAlpha(0)
    end

    if tab.TabBg and tab.TabBg.SetAlpha then
      tab.TabBg:SetAlpha(0)
    end

    if tab.Hider and tab.Hider.SetColorTexture then
      tab.Hider:SetColorTexture(0, 0, 0, 0.80)
      tab.Hider:SetAllPoints(tab)
    end

    if tab.Highlight and tab.Highlight.SetColorTexture then
      local ar, ag, ab = CS_ACCENT()
      tab.Highlight:SetColorTexture(ar, ag, ab, 0.20)
      tab.Highlight:SetAllPoints(tab)
    end

    if tab.Icon then
      local atlas = tab.Icon.GetAtlas and tab.Icon:GetAtlas()

      if tab.Icon._puiCharIconBackdrop and tab.Icon._puiCharIconBackdrop.Hide then
        tab.Icon._puiCharIconBackdrop:Hide()
      end

      tab.Icon:ClearAllPoints()
      tab.Icon:SetPoint("CENTER", tab, "CENTER", 0, 0)

      if tab.Icon.SetTexCoord then
        if atlas then
          tab.Icon:SetTexCoord(0, 1, 0, 1)
        else
          tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
      end
    end

    index = index + 1
    tab = _G["PaperDollSidebarTab" .. index]
  end
end

local function CS_SkinEquipmentManagerPane()
  local pane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
  if not pane then
    return
  end

  local function UpdateChild(child)
    if not child or not child.icon then
      return
    end

    if child.BgTop then child.BgTop:SetAlpha(0) end
    if child.BgMiddle then child.BgMiddle:SetAlpha(0) end
    if child.BgBottom then child.BgBottom:SetAlpha(0) end

    if child.HighlightBar and child.HighlightBar.SetColorTexture then
      child.HighlightBar:SetColorTexture(1, 1, 1, 0.25)
      child.HighlightBar:SetDrawLayer("BACKGROUND")
    end

    if child.SelectedBar and child.SelectedBar.SetColorTexture then
      local ar, ag, ab = CS_ACCENT()
      child.SelectedBar:SetColorTexture(ar, ag, ab, 0.18)
      child.SelectedBar:SetDrawLayer("BACKGROUND")
    end

    CS_SkinTextureIcon(child.icon)
  end

  CS_SkinScrollBar(pane.ScrollBar)

  if pane.ScrollBox and pane.ScrollBox.ForEachFrame then
    if not pane.ScrollBox._puiCharHooked then
      hooksecurefunc(pane.ScrollBox, "Update", function(scrollBox)
        scrollBox:ForEachFrame(UpdateChild)
      end)
      pane.ScrollBox._puiCharHooked = true
    end

    pane.ScrollBox:ForEachFrame(UpdateChild)
  end

  CS_SkinButton(_G.PaperDollFrameEquipSet)
  CS_SkinButton(_G.PaperDollFrameSaveSet)

  if not CharacterSheet._equipmentSetDialogHooked then
    hooksecurefunc("StaticPopup_Show", function(which, _, _, data)
      if which ~= "CONFIRM_SAVE_EQUIPMENT_SET" and which ~= "CONFIRM_OVERWRITE_EQUIPMENT_SET" then
        return
      end

      local dialog = StaticPopup_FindVisible(which, data)
      if dialog then
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
      end
    end)
    CharacterSheet._equipmentSetDialogHooked = true
  end

  if _G.GearManagerPopupFrame then
    if not _G.GearManagerPopupFrame._puiCharHooked then
      _G.GearManagerPopupFrame:HookScript("OnShow", function(frame)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame.IconSelector:SetFrameStrata("FULLSCREEN_DIALOG")
        frame.IconSelector:SetFrameLevel(frame.BorderBox:GetFrameLevel() + 1)
        StripTextures(frame, true)
        CS_ApplyBackdrop(frame, CS_BG)
      end)
      _G.GearManagerPopupFrame._puiCharHooked = true
    end

    if _G.GearManagerPopupFrame:IsShown() then
      _G.GearManagerPopupFrame:SetFrameStrata("FULLSCREEN_DIALOG")
      _G.GearManagerPopupFrame.IconSelector:SetFrameStrata("FULLSCREEN_DIALOG")
      _G.GearManagerPopupFrame.IconSelector:SetFrameLevel(_G.GearManagerPopupFrame.BorderBox:GetFrameLevel() + 1)
      CS_ApplyBackdrop(_G.GearManagerPopupFrame, CS_BG)
    end
  end
end

local function CS_SkinEquipmentFlyout()
  if not _G.EquipmentFlyoutFrame then
    return
  end

  local function UpdateItems()
    local flyout = _G.EquipmentFlyoutFrame
    flyout:SetFrameStrata("FULLSCREEN_DIALOG")

    local holder = flyout.buttonFrame
    if holder then
      holder:SetFrameStrata("FULLSCREEN_DIALOG")
      StripTextures(holder, true)
      CS_ApplyBackdrop(holder, CS_BG)
    end

    local navigation = flyout.NavigationFrame
    if navigation then
      navigation:SetFrameStrata("FULLSCREEN_DIALOG")
    end

    if _G.EquipmentFlyoutFrame.buttons then
      for _, button in pairs(_G.EquipmentFlyoutFrame.buttons) do
        if button then
          local keepIcon = button.icon or button.Icon or button.IconTexture

          local nt = button.GetNormalTexture and button:GetNormalTexture()
          if nt and nt.SetAlpha then nt:SetAlpha(0) end

          local pt = button.GetPushedTexture and button:GetPushedTexture()
          if pt and pt.SetAlpha then pt:SetAlpha(0) end

          local ht = button.GetHighlightTexture and button:GetHighlightTexture()
          if ht and ht.SetAlpha then ht:SetAlpha(0) end

          if button.GetRegions then
            for _, region in ipairs({ button:GetRegions() }) do
              if region and region.IsObjectType and region:IsObjectType("Texture") and region ~= keepIcon then
                if region.SetAlpha then
                  region:SetAlpha(0)
                end
              end
            end
          end

          CS_ApplyBackdrop(button, CS_CONTROL)

          if button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            CS_SkinTextureIcon(button.icon)
          end

          if button.IconBorder then
            button.IconBorder:SetAlpha(0)
          end
        end
      end
    end
  end

  local function UpdateNavigation()
    local nav = _G.EquipmentFlyoutFrame.NavigationFrame
    if not nav then
      return
    end

    nav:ClearAllPoints()
    if _G.EquipmentFlyoutFrameButtons then
      nav:SetPoint("TOPLEFT", _G.EquipmentFlyoutFrameButtons, "BOTTOMLEFT", 0, -2)
      nav:SetPoint("TOPRIGHT", _G.EquipmentFlyoutFrameButtons, "BOTTOMRIGHT", 0, -2)
    end

    StripTextures(nav, true)
    CS_ApplyBackdrop(nav, CS_BG)
    CS_SkinButton(nav.PrevButton)
    CS_SkinButton(nav.NextButton)
  end

  if _G.EquipmentFlyoutFrameHighlight then
    StripTextures(_G.EquipmentFlyoutFrameHighlight, true)
  end

  if _G.EquipmentFlyoutFrameButtons and _G.EquipmentFlyoutFrameButtons.bg1 then
    _G.EquipmentFlyoutFrameButtons.bg1:SetAlpha(0)
  end

  if _G.EquipmentFlyoutFrameButtons and _G.EquipmentFlyoutFrameButtons.DisableDrawLayer then
    _G.EquipmentFlyoutFrameButtons:DisableDrawLayer("ARTWORK")
  end

  UpdateItems()
  UpdateNavigation()

  if not CharacterSheet._equipmentFlyoutHooked then
    hooksecurefunc("EquipmentFlyout_UpdateItems", UpdateItems)
    hooksecurefunc("EquipmentFlyout_SetBackgroundTexture", UpdateNavigation)
    CharacterSheet._equipmentFlyoutHooked = true
  end
end

local function CS_SkinReputationAndCurrencyExtras()
  if ReputationFrame then
    CS_SkinDropDown(ReputationFrame.filterDropdown)

    local detail = ReputationFrame.ReputationDetailFrame
    if detail then
      StripTextures(detail, true)
      CS_ApplyBackdrop(detail, CS_BG)
      CS_SkinCloseButton(detail.CloseButton)
      CS_SkinCheckBox(detail.AtWarCheckbox)
      CS_SkinCheckBox(detail.MakeInactiveCheckbox)
      CS_SkinCheckBox(detail.WatchFactionCheckbox)
      CS_SkinButton(detail.ViewRenownButton)
      CS_SkinScrollBar(detail.ScrollingDescriptionScrollBar)
    end
  end

  if TokenFrame then
    CS_SkinDropDown(TokenFrame.filterDropdown)
  end

  if _G.TokenFramePopup then
    StripTextures(_G.TokenFramePopup, true)
    CS_ApplyBackdrop(_G.TokenFramePopup, CS_BG)
    CS_SkinCheckBox(_G.TokenFramePopup.InactiveCheckbox)
    CS_SkinCheckBox(_G.TokenFramePopup.BackpackCheckbox)
    CS_SkinButton(_G.TokenFramePopup.CurrencyTransferToggleButton)
    CS_SkinCloseButton(_G.TokenFramePopup.CloseButton)
  end

  if _G.CurrencyTransferLog then
    local function UpdateLine(frame)
      if frame and frame.CurrencyIcon then
        CS_SkinTextureIcon(frame.CurrencyIcon)
      end
    end

    StripTextures(_G.CurrencyTransferLog, true)
    CS_ApplyBackdrop(_G.CurrencyTransferLog, CS_BG)
    CS_SkinScrollBar(_G.CurrencyTransferLog.ScrollBar)

    if _G.CurrencyTransferLog.ScrollBox and _G.CurrencyTransferLog.ScrollBox.ForEachFrame then
      if not _G.CurrencyTransferLog.ScrollBox._puiCharHooked then
        hooksecurefunc(_G.CurrencyTransferLog.ScrollBox, "Update", function(scrollBox)
          scrollBox:ForEachFrame(UpdateLine)
        end)
        _G.CurrencyTransferLog.ScrollBox._puiCharHooked = true
      end

      _G.CurrencyTransferLog.ScrollBox:ForEachFrame(UpdateLine)
    end
  end

  local currencyTransfer = _G.CurrencyTransferMenu
  if currencyTransfer then
    StripTextures(currencyTransfer, true)
    CS_ApplyBackdrop(currencyTransfer, CS_BG)
    CS_SkinCloseButton(currencyTransfer.CloseButton)

    local content = currencyTransfer.Content
    if content then
      if content.SourceSelector then
        CS_SkinDropDown(content.SourceSelector.Dropdown)
      end

      if content.AmountSelector then
        CS_SkinButton(content.AmountSelector.MaxQuantityButton)
        CS_SkinEditBox(content.AmountSelector.InputBox)
      end

      CS_SkinButton(content.ConfirmButton)
      CS_SkinButton(content.CancelButton)

      if content.SourceBalancePreview and content.SourceBalancePreview.BalanceInfo then
        CS_SkinTextureIcon(content.SourceBalancePreview.BalanceInfo.CurrencyIcon)
      end

      if content.PlayerBalancePreview and content.PlayerBalancePreview.BalanceInfo then
        CS_SkinTextureIcon(content.PlayerBalancePreview.BalanceInfo.CurrencyIcon)
      end
    end
  end
end

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

-- Item slot helpers (ilvl / enchant / gems + icon skin)
local function GetSlotItemLevel(unit, slotId)
  local cache, itemLink = CS_GetCachedSlotInfo(unit, slotId)
  if not itemLink then
    return nil
  end

  if cache and cache.itemLevel ~= nil then
    return cache.itemLevel or nil
  end

  local itemLevel

  local itemID = tonumber(itemLink:match("item:(%d+)"))
  if itemID and not C_Item.IsItemDataCachedByID(itemID) then
    C_Item.RequestLoadItemDataByID(itemID)
  end

  local detailed = GetDetailedItemLevelInfo(itemLink)
  if detailed then
    itemLevel = detailed
  end

  if not itemLevel then
    local _, _, _, ilvl = GetItemInfo(itemLink)
    if ilvl then
      itemLevel = ilvl
    end
  end

  if not itemLevel then
    local tooltipData = CS_GetCachedInventoryTooltipData(cache, unit, slotId)
    if tooltipData and tooltipData.lines then
      local pattern
      if ITEM_LEVEL then
        pattern = ITEM_LEVEL:gsub("%%d", "(%%d+)")
      else
        pattern = "Item Level (%d+)"
      end

      for _, line in ipairs(tooltipData.lines) do
        local text = line.leftText or ""
        local tooltipIlvl = text:match(pattern)
        if tooltipIlvl then
          local parsed = tonumber(tooltipIlvl)
          if parsed then
            itemLevel = parsed
          end
          break
        end
      end
    end
  end

  if cache and itemLevel then
    cache.itemLevel = itemLevel
  end

  return itemLevel
end

local AVERAGE_ITEM_LEVEL_SLOT_COUNT = 16
local ARTIFACT_ITEM_QUALITY = 6
local WAND_WEAPON_SUBCLASS = 19
local FURY_WARRIOR_SPEC = 72

local function CS_GetEquippedItemState(unit, slotId)
  local itemLink = GetInventoryItemLink(unit, slotId)
  if itemLink then
    return itemLink, false
  end

  return nil, GetInventoryItemTexture(unit, slotId) ~= nil
end

local function CS_GetWeaponItemLevelTotal(unit, specializationID)
  local mainLink, mainPending = CS_GetEquippedItemState(unit, INVSLOT_MAINHAND)
  if mainPending then
    return nil
  end

  local offLink, offPending = CS_GetEquippedItemState(unit, INVSLOT_OFFHAND)
  if offPending then
    return nil
  end

  local mainLevel = mainLink and (GetSlotItemLevel(unit, INVSLOT_MAINHAND) or 0) or 0
  local offLevel = offLink and (GetSlotItemLevel(unit, INVSLOT_OFFHAND) or 0) or 0
  local mainQuality = mainLink and GetInventoryItemQuality(unit, INVSLOT_MAINHAND) or nil

  if mainQuality == ARTIFACT_ITEM_QUALITY then
    local artifactLevel = (mainLevel > offLevel) and mainLevel or offLevel
    return artifactLevel * 2
  end

  if mainLink and not offLink and specializationID ~= FURY_WARRIOR_SPEC then
    local _, _, _, equipLocation, _, classID, subClassID = C_Item.GetItemInfoInstant(mainLink)

    if equipLocation == "INVTYPE_2HWEAPON"
      or equipLocation == "INVTYPE_RANGED"
      or (
        equipLocation == "INVTYPE_RANGEDRIGHT"
        and not (classID == Enum.ItemClass.Weapon and subClassID == WAND_WEAPON_SUBCLASS)
      )
    then
      return mainLevel * 2
    end
  end

  return mainLevel + offLevel
end

CS_FormatItemLevel = function(value)
  if issecretvalue(value) then
    return ""
  end
  if value == nil then
    return ""
  end

  return format("%.2f", value)
end

CS_GetPlayerEquippedItemLevel = function()
  local _, equipped = GetAverageItemLevel()
  if issecretvalue(equipped) then
    return nil
  end
  if not equipped or equipped <= 0 then
    return nil
  end

  return equipped
end

CS_CalculateUnitAverageItemLevel = function(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end

  if UnitIsUnit(unit, "player") then
    return CS_GetPlayerEquippedItemLevel()
  end

  local specializationID = GetInspectSpecialization(unit) or 0
  local total = 0

  for slotId = INVSLOT_HEAD, INVSLOT_BACK do
    if slotId ~= INVSLOT_BODY then
      local itemLink, itemPending = CS_GetEquippedItemState(unit, slotId)
      if itemPending then
        return nil
      end

      if itemLink then
        local itemLevel = GetSlotItemLevel(unit, slotId)
        if itemLevel and itemLevel > 0 then
          total = total + itemLevel
        end
      end
    end
  end

  local weaponTotal = CS_GetWeaponItemLevelTotal(unit, specializationID)
  if weaponTotal == nil then
    return nil
  end

  total = total + weaponTotal
  if total == 0 then
    return nil
  end

  return total / AVERAGE_ITEM_LEVEL_SLOT_COUNT
end

local function GetSlotEnchantInfo(unit, slotId)
  local cache, itemLink = CS_GetCachedSlotInfo(unit, slotId)
  if not itemLink then
    return nil, false
  end

  local enchantRequired = IsEnchantableSlot(slotId) and CS_IsEnchantWarningLevel(unit)

  if slotId == INVSLOT_OFFHAND and enchantRequired then
    local itemClassID = select(6, C_Item.GetItemInfoInstant(itemLink))
    if itemClassID == Enum.ItemClass.Armor then
      enchantRequired = false
    end
  end

  if cache and cache.enchantChecked then
    return cache.enchantAtlas, cache.missingEnchant and true or false
  end

  local hasEnchant = false
  local enchantID = itemLink:match("item:%d+:([^:|]*)")
  if enchantID and enchantID ~= "" and enchantID ~= "0" then
    hasEnchant = true
  end

  if hasEnchant then
    local tooltipData = CS_GetCachedInventoryTooltipData(cache, unit, slotId)
    if tooltipData and tooltipData.lines then
      for _, line in ipairs(tooltipData.lines) do
        local text = line.leftText or ""
        local enchant

        if ENCHANTED_TOOLTIP_LINE then
          local pattern = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)")
          enchant = text:match(pattern)
        end

        if not enchant then
          enchant = text:match("Enchanted:%s*(.+)")
        end

        if enchant then
          local enchantAtlas = enchant:match("|A:([^:|]+)")
            or "Professions-ChatIcon-Quality-Tier5"
          if cache then
            cache.enchantChecked = true
            cache.enchantAtlas = enchantAtlas
            cache.missingEnchant = false
          end
          return enchantAtlas, false
        end
      end
    end
  end

  if hasEnchant then
    return nil, false
  end

  if cache then
    cache.enchantChecked = true
    cache.enchantAtlas = nil
    cache.missingEnchant = enchantRequired
  end

  return nil, enchantRequired
end

local function GetGemInfo(unit, slotId)
  local cache, itemLink = CS_GetCachedSlotInfo(unit, slotId)
  if not itemLink then
    return {}, 0
  end

  if cache and cache.gems then
    return cache.gems, cache.totalSockets or 0
  end

  local gems = {}
  local totalSockets = 0

  do
    local tooltipData = CS_GetCachedInventoryTooltipData(cache, unit, slotId)
    if tooltipData and tooltipData.lines then
      for _, line in ipairs(tooltipData.lines) do
        if line.type == 3 then
          totalSockets = totalSockets + 1
        end
      end
    end
  end

  local filledCount = 0
  for i = 1, 4 do
    local gemName, gemLink = GetItemGem(itemLink, i)
    if gemLink then
      filledCount = filledCount + 1
      gems[filledCount] = {
        link = gemLink,
        name = gemName,
      }
    end
  end

  if cache then
    cache.gems = gems
    cache.totalSockets = totalSockets
  end

  return gems, totalSockets
end

local function CS_RefreshItemStatHighlightColor(button)
  local highlight = button and button._puiCharStatHighlight
  if not highlight then
    return
  end

  local color = CS_STAT_HIGHLIGHT_COLOR
  for _, texture in ipairs(highlight._puiLines) do
    texture:SetColorTexture(color[1], color[2], color[3], color[4])
  end
end

local function CS_EnsureItemStatHighlight(button)
  if not button then
    return nil
  end

  local highlight = button._puiCharStatHighlight
  if highlight then
    return highlight
  end

  highlight = CreateFrame("Frame", nil, button)
  highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  highlight:SetFrameLevel(button:GetFrameLevel() + 20)
  highlight:EnableMouse(false)
  highlight:SetAlpha(0)
  highlight._puiLines = {}

  local top = highlight:CreateTexture(nil, "OVERLAY")
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(2)
  highlight._puiLines[#highlight._puiLines + 1] = top

  local bottom = highlight:CreateTexture(nil, "OVERLAY")
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(2)
  highlight._puiLines[#highlight._puiLines + 1] = bottom

  local left = highlight:CreateTexture(nil, "OVERLAY")
  left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
  left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
  left:SetWidth(2)
  highlight._puiLines[#highlight._puiLines + 1] = left

  local right = highlight:CreateTexture(nil, "OVERLAY")
  right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
  right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
  right:SetWidth(2)
  highlight._puiLines[#highlight._puiLines + 1] = right

  local fadeIn = highlight:CreateAnimationGroup()
  fadeIn:SetToFinalAlpha(true)
  local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
  fadeInAlpha:SetFromAlpha(0)
  fadeInAlpha:SetToAlpha(1)
  fadeInAlpha:SetDuration(CS_STAT_HIGHLIGHT_FADE_IN_SECONDS)
  fadeInAlpha:SetSmoothing("OUT")
  highlight._puiFadeIn = fadeIn
  highlight._puiFadeInAlpha = fadeInAlpha

  local fadeOut = highlight:CreateAnimationGroup()
  fadeOut:SetToFinalAlpha(true)
  local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
  fadeOutAlpha:SetFromAlpha(1)
  fadeOutAlpha:SetToAlpha(0)
  fadeOutAlpha:SetDuration(CS_STAT_HIGHLIGHT_FADE_OUT_SECONDS)
  fadeOutAlpha:SetSmoothing("OUT")
  fadeOut:SetScript("OnFinished", function()
    highlight._puiStatVisible = false
    highlight:SetAlpha(0)
    highlight:Hide()
  end)
  highlight._puiFadeOut = fadeOut
  highlight._puiFadeOutAlpha = fadeOutAlpha
  highlight._puiStatVisible = false

  button._puiCharStatHighlight = highlight
  CS_RefreshItemStatHighlightColor(button)
  highlight:Hide()
  return highlight
end

local function CS_AddPermanentEnchantStatPresence(cache, unit, slotId, presence)
  local tooltipData = CS_GetCachedInventoryTooltipData(cache, unit, slotId)
  if not (tooltipData and tooltipData.lines) then
    return
  end

  local enchantLineType = Enum.TooltipDataLineType.ItemEnchantmentPermanent

  for _, line in ipairs(tooltipData.lines) do
    if line.type == enchantLineType then
      local text = line.leftText
      if text and not issecretvalue(text) then
        for statKey, statName in pairs(ITEM_STAT_DISPLAY_NAMES) do
          if statName and text:find(statName, 1, true) then
            presence[statKey] = true
          end
        end
      end
    end
  end
end

local function CS_UpdatePlayerItemStatPresence(button)
  if not (button and button.GetID) then
    return
  end

  button._puiCharItemStatPresence = nil

  if InCombatLockdown() or not CS_GetHighlightStatGear() then
    return
  end

  local slotId = button:GetID()
  if not slotId then
    return
  end

  local cache, itemLink = CS_GetCachedSlotInfo("player", slotId)
  if not itemLink then
    return
  end

  local presence = cache and cache.itemStatPresence
  if not presence then
    local stats = C_Item.GetItemStats(itemLink)
    if not stats then
      return
    end

    presence = {}
    if stats[ITEM_STAT_CRIT] ~= nil then presence[ITEM_STAT_CRIT] = true end
    if stats[ITEM_STAT_HASTE] ~= nil then presence[ITEM_STAT_HASTE] = true end
    if stats[ITEM_STAT_MASTERY] ~= nil then presence[ITEM_STAT_MASTERY] = true end
    if stats[ITEM_STAT_VERSATILITY] ~= nil then presence[ITEM_STAT_VERSATILITY] = true end
    if stats[ITEM_STAT_LIFESTEAL] ~= nil then presence[ITEM_STAT_LIFESTEAL] = true end
    if stats[ITEM_STAT_AVOIDANCE] ~= nil then presence[ITEM_STAT_AVOIDANCE] = true end
    if stats[ITEM_STAT_SPEED] ~= nil then presence[ITEM_STAT_SPEED] = true end

    CS_AddPermanentEnchantStatPresence(cache, "player", slotId, presence)

    if cache then
      cache.itemStatPresence = presence
    end
  end

  button._puiCharItemStatPresence = presence
  CS_EnsureItemStatHighlight(button)
end

CS_RefreshPlayerItemStatPresence = function()
  CS_ClearItemStatHighlights()

  if InCombatLockdown() or not CS_GetHighlightStatGear() then
    return
  end

  if not (CharacterFrame and CharacterFrame.IsShown and CharacterFrame:IsShown()) then
    return
  end

  local frame = _G.PaperDollItemsFrame
  if not (frame and frame.GetChildren) then
    return
  end

  for _, button in ipairs({ frame:GetChildren() }) do
    if button and button.GetID and button:GetID() then
      CS_UpdatePlayerItemStatPresence(button)
    end
  end
end

UpdateItemSlotOverlay = function(button, unit, allowDurability)
  if not button or not button.GetID then
    return
  end

  local slotId = button:GetID()
  if not slotId then
    return
  end

  unit = unit or "player"
  if allowDurability == nil then
    allowDurability = true
  end

  local signature = button._puiCharOverlayNextSignature
  if not signature then
    local sigLink = GetInventoryItemLink(unit, slotId) or ""
    local sigQuality = GetInventoryItemQuality(unit, slotId) or ""
    local sigDurabilityCur, sigDurabilityMax = "", ""
    if allowDurability then
      sigDurabilityCur, sigDurabilityMax = GetInventoryItemDurability(slotId)
      sigDurabilityCur = sigDurabilityCur or ""
      sigDurabilityMax = sigDurabilityMax or ""
    end

    signature = tostring(CS_SLOT_CACHE_VERSION)
      .. "|" .. tostring(unit or "")
      .. "|" .. tostring(UnitGUID(unit) or "")
      .. "|" .. tostring(slotId)
      .. "|" .. tostring(sigLink or "")
      .. "|" .. tostring(sigQuality or "")
      .. "|" .. tostring(sigDurabilityCur or "")
      .. "|" .. tostring(sigDurabilityMax or "")
      .. "|" .. tostring(CS_GetShowEnchants())
      .. "|" .. tostring(CS_GetShowSocketIcons())
      .. "|" .. tostring(button.GetWidth and button:GetWidth() or "")
      .. "x" .. tostring(button.GetHeight and button:GetHeight() or "")
  end

  if button._puiCharOverlayComplete and button._puiCharOverlaySignature == signature then
    button._puiCharOverlayNextSignature = nil
    return
  end
  button._puiCharOverlayNextSignature = nil

  local overlay = button._puiCharOverlay

  if not overlay then
    overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    button._puiCharOverlay = overlay

    local tr, tg, tb, ta = GetTextColor()

    overlay.ilvl = overlay:CreateFontString(nil, "OVERLAY")
    ns.Theme.ApplyFont(overlay.ilvl, "tiny")
    overlay.ilvl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    overlay.ilvl:SetTextColor(tr, tg, tb, ta)

    overlay.enchant = overlay:CreateTexture(nil, "OVERLAY")
    overlay.enchant:SetSize(18, 18)
    overlay.enchant:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 1)
    overlay.enchant:SetAlpha(0.9)

    overlay.gems = CreateFrame("Frame", nil, overlay)
    overlay.gems:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    overlay.gems:SetSize(button:GetWidth() or 32, 12)
    overlay.gems.icons = overlay.gems.icons or {}
  end

  local ilvl = GetSlotItemLevel(unit, slotId)
  if ilvl then
    overlay.ilvl:SetFormattedText("%d", ilvl)
    overlay.ilvl:Show()
  else
    overlay.ilvl:SetText("")
    overlay.ilvl:Hide()
  end

  local enchantAtlas, missingEnchant = GetSlotEnchantInfo(unit, slotId)

  local showEnchants = CS_GetShowEnchants()

  if showEnchants and enchantAtlas then
    overlay.enchant:SetAtlas(enchantAtlas)
    overlay.enchant:SetAlpha(0.9)
    overlay.enchant:Show()
  else
    overlay.enchant:SetTexture(nil)
    overlay.enchant:Hide()
  end

  local gemContainer = overlay.gems

  if gemContainer then
    local icons = gemContainer.icons or {}
    gemContainer.icons = icons

    for i = 1, #icons do
      icons[i]:Hide()
    end

    if CS_GetShowSocketIcons() then
      local gems, totalSockets = GetGemInfo(unit, slotId)

      if totalSockets and totalSockets > 0 then
        local maxSlots = totalSockets
        if maxSlots > 4 then
          maxSlots = 4
        end

        local size = 12
        local spacing = 1

        for i = 1, maxSlots do
          local tex = icons[i]
          if not tex then
            tex = gemContainer:CreateTexture(nil, "OVERLAY")
            icons[i] = tex
          end

          tex:SetSize(size, size)
          tex:ClearAllPoints()
          if i == 1 then
            tex:SetPoint("BOTTOMLEFT", gemContainer, "BOTTOMLEFT", 0, 0)
          else
            tex:SetPoint("LEFT", icons[i - 1], "RIGHT", spacing, 0)
          end

          local gemInfo = gems[i]
          if gemInfo and gemInfo.link then
            local iconTexture = GetItemIcon(gemInfo.link)
            if iconTexture then
              tex:SetTexture(iconTexture)
            else
              tex:SetColorTexture(0, 0, 0, 0.7)
            end
          else
            tex:SetTexture(nil)
            tex:SetColorTexture(0, 0, 0, 0.7)
          end

          tex:Show()
        end

        gemContainer:Show()
      else
        gemContainer:Hide()
      end
    else
      gemContainer:Hide()
    end
  end

  -- Border color rules (CharacterSheet only, player unit):
  -- 1) RED if durability is 0
  -- 2) YELLOW if durability < 25%
  -- else 3) RED if enchantable + missing enchant
  -- else 4) item quality color
  do
    local r, g, b, a

    -- Durability override (only applies to equipped items that report durability).
    if allowDurability then
      local cur, max = GetInventoryItemDurability(slotId)
      if cur and max and max > 0 then
        if cur <= 0 then
          r, g, b, a = 1.00, 0.20, 0.20, 1.00
        elseif (cur / max) < 0.25 then
          r, g, b, a = 1.00, 0.90, 0.20, 1.00
        end
      end
    end

    -- Missing enchant override (only if no durability warning active).
    if not r then
      if missingEnchant and IsEnchantableSlot(slotId) then
        r, g, b, a = 1.00, 0.20, 0.20, 1.00
      end
    end

    -- Quality color fallback.
    if not r then
      local q = GetInventoryItemQuality(unit, slotId)
      if q ~= nil then
        r, g, b = GetItemQualityColor(q)
        a = 1.00
      else
        r, g, b, a = 0.20, 0.20, 0.24, 1.00
      end
    end

    local borderConfig = button._puiCharBorderConfig
    if not borderConfig then
      borderConfig = {
        enabled = true,
        thickness = 2,
        useThemeColor = false,
        color = { 0, 0, 0, 1 },
      }
      button._puiCharBorderConfig = borderConfig
    end

    local color = borderConfig.color
    color[1], color[2], color[3], color[4] = r, g, b, a
    IconSkin.ApplyBorder(button, borderConfig)
  end

  button._puiCharOverlaySignature = signature
  button._puiCharOverlayComplete = true
end

local function RefreshItemSlotOverlayTheme(button)
  local overlay = button and button._puiCharOverlay
  if not overlay then
    return
  end

  local tr, tg, tb, ta = GetTextColor()
  if overlay.ilvl then
    ns.Theme.ApplyFont(overlay.ilvl, "tiny")
    overlay.ilvl:SetTextColor(tr, tg, tb, ta)
  end

  if overlay.enchant then
    overlay.enchant:SetAlpha(0.9)
  end

  CS_RefreshItemStatHighlightColor(button)
end


local function CS_QueueInspectSlotButton(button)
  if not button or not button.GetID then
    return
  end

  local slotId = button:GetID()
  if not slotId then
    return
  end

  if button._puiCharInspectSlotQueued == true then
    CS_INSPECT_SLOT_QUEUE[slotId] = button
    return
  end

  button._puiCharInspectSlotQueued = true
  CS_INSPECT_SLOT_QUEUE[slotId] = button

  if CS_InspectSlotQueuePending then
    return
  end

  CS_InspectSlotQueuePending = true
  C_Timer.After(0, function()
    CS_InspectSlotQueuePending = false

    local unit = InspectFrame and InspectFrame.unit
    local ready = CS_IsInspectReady(unit)

    for id, queuedButton in pairs(CS_INSPECT_SLOT_QUEUE) do
      CS_INSPECT_SLOT_QUEUE[id] = nil
      if queuedButton then
        queuedButton._puiCharInspectSlotQueued = nil
        SkinItemSlotButton(queuedButton)

        if ready then
          UpdateItemSlotOverlay(queuedButton, unit, false)
        else
          CS_HideInspectSlotOverlay(queuedButton)
        end
      end
    end
  end)
end

local function CS_RefreshPlayerSlots(force)
  if not force and not (CharacterFrame and CharacterFrame.IsShown and CharacterFrame:IsShown()) then
    return
  end

  local frame = _G.PaperDollItemsFrame
  if not (frame and frame.GetChildren) then
    return
  end

  for _, button in ipairs({ frame:GetChildren() }) do
    if button and button.GetID and button:GetID() then
      SkinItemSlotButton(button)
      UpdateItemSlotOverlay(button, "player", true)
      CS_UpdatePlayerItemStatPresence(button)
    end
  end
end

local function CS_RefreshSlotDisplaySettings()
  CS_RefreshPlayerSlots()

  if not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
    return
  end

  local unit = InspectFrame.unit
  if unit and CS_IsInspectReady(unit) then
    CS_RefreshInspectData(UnitGUID(unit))
  else
    CS_ClearInspectSlotOverlays()
    CS_ClearInspectAverageItemLevelText()
  end
end

local function CS_SettingsButtonHandlesGlobalMouseEvent(button, buttonName, event)
  if event ~= "GLOBAL_MOUSE_DOWN" or buttonName ~= "LeftButton" then
    return false
  end

  local openMenu = Menu.GetManager():GetOpenMenu()
  return openMenu ~= nil and openMenu.ownerRegion == button
end

local function CS_ToggleCharacterSettingsMenu()
  local button = CharacterFrame and CharacterFrame._puiSettingsButton
  if not button then
    return
  end

  local menuManager = Menu.GetManager()
  local openMenu = menuManager:GetOpenMenu()
  if openMenu and openMenu.ownerRegion == button then
    menuManager:CloseMenu(openMenu)
    return
  end

  MenuUtil.CreateContextMenu(button, function(_, rootDescription)
    rootDescription:CreateCheckbox(
      "Show Enchant Icons",
      CS_GetShowEnchants,
      function()
        CS_SetShowEnchants(not CS_GetShowEnchants())
        CS_RefreshSlotDisplaySettings()
      end
    )
    rootDescription:CreateCheckbox(
      "Show Socket Icons",
      CS_GetShowSocketIcons,
      function()
        CS_SetShowSocketIcons(not CS_GetShowSocketIcons())
        CS_RefreshSlotDisplaySettings()
      end
    )
    rootDescription:CreateCheckbox(
      "Show Bag Item Level",
      CS_GetShowBagItemLevel,
      function()
        CS_SetShowBagItemLevel(not CS_GetShowBagItemLevel())
      end
    )
    rootDescription:CreateCheckbox(
      "Show Stat Values",
      CS_GetShowStatRatings,
      function()
        CS_SetShowStatRatings(not CS_GetShowStatRatings())
      end
    )
    rootDescription:CreateCheckbox(
      "Show Max Health",
      CS_GetShowMaxHealth,
      function()
        CS_SetShowMaxHealth(not CS_GetShowMaxHealth())
      end
    )
    rootDescription:CreateCheckbox(
      "Highlight gear on stat hover",
      CS_GetHighlightStatGear,
      function()
        CS_SetHighlightStatGear(not CS_GetHighlightStatGear())
      end
    )
    rootDescription:CreateCheckbox(
      "Use PleebUI font",
      CS_GetUsePleebUIFont,
      function()
        CS_SetUsePleebUIFont(not CS_GetUsePleebUIFont())
      end
    )
  end)
end

local function CS_UpdateCharacterSettingsButtonVisibility()
  local button = CharacterFrame and CharacterFrame._puiSettingsButton
  if not button then
    return
  end

  local show = PaperDollFrame and PaperDollFrame.IsShown and PaperDollFrame:IsShown()
  button:SetShown(show == true)
end

local function CS_AfterCharacterSubFrameShown(_, frameName)
  CharacterSheet:SetShellExtended(true)
  CS_UpdateCharacterSettingsButtonVisibility()

  if frameName == "PaperDollFrame" then
    UpdateCharacterAverageItemLevelText()
    CS_LayoutMaxHealthRow()
    CS_RefreshPlayerSlots(true)
    return
  end

  if frameName == "ReputationFrame" then
    CS_SkinReputationAndCurrencyExtras()

    if ReputationFrame.ScrollBox and ReputationFrame.ScrollBox.ForEachFrame then
      ReputationFrame.ScrollBox:ForEachFrame(SkinReputationEntry)
    end
    return
  end

  if frameName == "TokenFrame" then
    CS_SkinReputationAndCurrencyExtras()

    if TokenFrame.ScrollBox and TokenFrame.ScrollBox.ForEachFrame then
      TokenFrame.ScrollBox:ForEachFrame(SkinCurrencyButton)
    end
  end
end

-- Title manager pane
local function RefreshTitleEntryTheme(button)
  if not button then
    return
  end

  local bg = EnsureBackdropFrame(button)
  if bg then
    local r, g, b, a = CS_CONTROL()
    local br, bgG, bB, bA = CS_B()
    bg:SetBackdropColor(r, g, b, a)
    bg:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  local tr, tg, tb, ta = GetTextColor()

  if button.Text then
    ns.Theme.ApplyFont(button.Text, "body")
    button.Text:SetTextColor(tr, tg, tb, ta)
  end

  if button.Check and button.Check.SetVertexColor then
    local ar, ag, ab, aa = CS_ACCENT()
    button.Check:SetVertexColor(ar, ag, ab, aa)
  end

  if button.SelectedBar and button.SelectedBar.SetColorTexture then
    local ar, ag, ab, aa = CS_ACCENT()
    button.SelectedBar:SetColorTexture(ar, ag, ab, aa * 0.3)
  end

  if button.Highlight and button.Highlight.SetColorTexture then
    local ar, ag, ab, aa = CS_ACCENT()
    button.Highlight:SetColorTexture(ar, ag, ab, aa * 0.15)
  end
end

local function SkinTitleEntry(button)
  if not button then
    return
  end

  if not button._puiCharSkinned then
    StripTextures(button, true)

    local bg = EnsureBackdropFrame(button)
    if bg and bg.SetBackdrop then
      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = Theme.GetEdgeSize(),
      })
    end

    button._puiCharSkinned = true
  end

  RefreshTitleEntryTheme(button)
end

local function SkinTitleManagerPane()

  local pane = _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane
  if not pane then
    return
  end

  local container = pane

  -- Pane backdrop
  local bg = EnsureBackdropFrame(container)
  if bg and bg.SetBackdrop then
    local edgeSize = Theme.GetEdgeSize()

    bg:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edgeSize,
    })

    local r, g, b, a        = CS_BG()
    local br, bgG, bB, bA   = CS_B()

    bg:SetBackdropColor(r, g, b, a)
    bg:SetBackdropBorderColor(br, bgG, bB, bA)
  end

  if container.title then
    ns.Theme.ApplyFont(container.title, "header")
    local tr, tg, tb, ta = GetTextColor()
    container.title:SetTextColor(tr, tg, tb, ta)
  end

  if pane.ScrollBox and not pane.ScrollBox._puiCharHooked then
    hooksecurefunc(pane.ScrollBox, "Update", function(scrollBox)

      scrollBox:ForEachFrame(SkinTitleEntry)
    end)
    pane.ScrollBox._puiCharHooked = true
  end

  if pane.ScrollBox and pane.ScrollBox.ForEachFrame then
    pane.ScrollBox:ForEachFrame(SkinTitleEntry)
  end

  -- Simple scrollbar polish (respect theme colors if needed later).
  if pane.ScrollBar and pane.ScrollBar.Track and pane.ScrollBar.Track.SetAlpha then
    pane.ScrollBar.Track:SetAlpha(0.3)
  end
  if pane.ScrollBar and pane.ScrollBar.Thumb and pane.ScrollBar.Thumb.SetAlpha then
    pane.ScrollBar.Thumb:SetAlpha(0.7)
  end
end

local function CS_SuppressCoreBlizzardArt()
  if not CharacterFrame then
    return
  end

  if CharacterFrame.NineSlice then
    CharacterFrame.NineSlice:Hide()
  end
  if CharacterFrame.Inset and CharacterFrame.Inset.NineSlice then
    CharacterFrame.Inset.NineSlice:Hide()
  end
  if CharacterFramePortrait then
    CharacterFramePortrait:SetAlpha(0)
  end
  if CharacterFrameBg then
    CharacterFrameBg:SetAlpha(0)
  end
  if CharacterFrame.Background then
    CharacterFrame.Background:SetAlpha(0)
  end
  if CharacterFrame.TitleBg then
    CharacterFrame.TitleBg:SetAlpha(0)
  end

  if CharacterStatsPane then
    if CharacterStatsPane.NineSlice then
      CharacterStatsPane.NineSlice:Hide()
    end
    if CharacterStatsPane.Background then
      CharacterStatsPane.Background:SetAlpha(0)
    end
  end

  if PaperDollItemsFrame then
    if PaperDollItemsFrame.NineSlice then
      PaperDollItemsFrame.NineSlice:Hide()
    end
    if PaperDollItemsFrame.BorderFrame then
      PaperDollItemsFrame.BorderFrame:SetAlpha(0)
    end
  end

  if CharacterFrameInset then
    if CharacterFrameInset.NineSlice then CharacterFrameInset.NineSlice:Hide() end
    if CharacterFrameInset.BorderFrame then CharacterFrameInset.BorderFrame:SetAlpha(0) end
    if CharacterFrameInset.Bg and CharacterFrameInset.Bg.SetAlpha then CharacterFrameInset.Bg:SetAlpha(0) end
    if CharacterFrameInset.Background and CharacterFrameInset.Background.SetAlpha then CharacterFrameInset.Background:SetAlpha(0) end
  end

  if CharacterFrameInsetRight then
    if CharacterFrameInsetRight.NineSlice then CharacterFrameInsetRight.NineSlice:Hide() end
    if CharacterFrameInsetRight.BorderFrame then CharacterFrameInsetRight.BorderFrame:SetAlpha(0) end
    if CharacterFrameInsetRight.Bg and CharacterFrameInsetRight.Bg.SetAlpha then CharacterFrameInsetRight.Bg:SetAlpha(0) end
    if CharacterFrameInsetRight.Background and CharacterFrameInsetRight.Background.SetAlpha then CharacterFrameInsetRight.Background:SetAlpha(0) end
  end

  if PaperDollSidebarTabs then
    if PaperDollSidebarTabs.NineSlice then PaperDollSidebarTabs.NineSlice:Hide() end
    if PaperDollSidebarTabs.BorderFrame then PaperDollSidebarTabs.BorderFrame:SetAlpha(0) end
  end
end

-- Core CharacterFrame skin setup
local function SetupCharacterFrameSkinning()

  if not CharacterFrame then
    return
  end

  CharacterFrame:SetFrameStrata("DIALOG")

  if CharacterSheet._initialized then
    -- Already skinned once; just make sure shell and window controls are positioned.
    EnsureShellHost()
    CS_EnsureCharacterFrameWindowControls()
    CS_ApplyCharacterFrameWindowState()
    return
  end

  CharacterSheet._initialized = true
  CS_SetupPaperDollValueHooks()

  -- Core frame: hide Blizzard art we replace with our shell.
  -- Blizzard can re-show some regions on RefreshDisplay/UpdateSize, so we re-apply after those paths.
  local function ApplyCoreDecorations()
    if not CharacterFrame then
      return
    end

    if CharacterFrame.NineSlice then
      CharacterFrame.NineSlice:Hide()
    end
    if CharacterFrame.Inset and CharacterFrame.Inset.NineSlice then
      CharacterFrame.Inset.NineSlice:Hide()
    end

  if CharacterFramePortrait then
    CharacterFramePortrait:SetAlpha(0)
  end

  if CharacterFramePortraitFrame then
    StripTextures(CharacterFramePortraitFrame, true)

    local bg = EnsureBackdropFrame(CharacterFramePortraitFrame)
    if bg and bg.SetBackdrop then
      local edgeSize = Theme.GetEdgeSize()
      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
      })

      local r, g, b, a      = CS_BG()
      local br, bgG, bB, bA = CS_B()

      bg:SetBackdropColor(r, g, b, a)
      bg:SetBackdropBorderColor(br, bgG, bB, bA)
    end
  end
    if CharacterFrameBg then
      CharacterFrameBg:SetAlpha(0)
    end
    if CharacterFrame.Background then
      CharacterFrame.Background:SetAlpha(0)
    end
    if CharacterFrame.TitleBg then
      CharacterFrame.TitleBg:SetAlpha(0)
    end

    if CharacterFrame.TitleText then
      ns.Theme.ApplyFont(CharacterFrame.TitleText, "title")
      local tr, tg, tb, ta = GetTextColor()
      CharacterFrame.TitleText:SetTextColor(tr, tg, tb, ta)
    end

    if CharacterModelScene then
      StripTextures(CharacterModelScene, true)
    end
  if CharacterStatsPane then
    StripTextures(CharacterStatsPane, true)

    -- Remove Blizzard chrome around the whole stats group.
    if CharacterStatsPane.NineSlice then
      CharacterStatsPane.NineSlice:Hide()
    end
    if CharacterStatsPane.Background then
      CharacterStatsPane.Background:SetAlpha(0)
    end

    -- Add the shared PUI background and border.
    do
      local bg = EnsureBackdropFrame(CharacterStatsPane)
      if bg and bg.SetBackdrop then
        local edgeSize = Theme.GetEdgeSize()
        bg:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        local r, g, b, a      = CS_BG()
        local br, bgG, bB, bA = CS_B()

        bg:SetBackdropColor(r, g, b, a)
        bg:SetBackdropBorderColor(br, bgG, bB, bA)
      end
    end

    local function SkinStatsHeader(cat)
      if not cat then
        return
      end

      -- Always refresh colors (Blizzard can relayout/re-show, and palette tweaks should apply).
      local tr, tg, tb, ta = GetTextColor()
      local br, bgG, bB, bA = CS_B()

      if cat == CharacterStatsPane.AttributesCategory or cat == CharacterStatsPane.EnhancementsCategory then
        cat:SetSize(187, 22)
      end

      local title = cat.Title or cat.Text

      if cat._puiCharHeaderSkinned then
        local bg = EnsureBackdropFrame(cat)
        if bg and bg.SetBackdropColor then
          local r, g, b, a = CS_BG()
          bg:SetBackdropColor(r, g, b, a)
        end
        if bg and bg.SetBackdropBorderColor then
          bg:SetBackdropBorderColor(br, bgG, bB, bA)
        end
        if title then
          ns.Theme.ApplyFont(title, "nav")
          title:SetTextColor(tr, tg, tb, ta)
        end
        return
      end

      StripTextures(cat, true)

      local bg = EnsureBackdropFrame(cat)
      if bg and bg.SetBackdrop then
        local edgeSize = Theme.GetEdgeSize()
        bg:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        local r, g, b, a      = CS_BG()
        local br, bgG, bB, bA = CS_B()

        bg:SetBackdropColor(r, g, b, a)
        bg:SetBackdropBorderColor(br, bgG, bB, bA)
      end

      if title then
        ns.Theme.ApplyFont(title, "nav")
        local tr, tg, tb, ta = GetTextColor()
        title:SetTextColor(tr, tg, tb, ta)
      end

      cat._puiCharHeaderSkinned = true
    end

    local function SkinStatsFrame(frame)
      if not frame then
        return
      end

      -- Always refresh backdrop colors/border after first skin (but keep the expensive font walking only once).
      local tr, tg, tb, ta = GetTextColor()
      local br, bgG, bB, bA = CS_B()

      if frame._puiCharStatsSkinned then
        local bg = EnsureBackdropFrame(frame)
        if bg and bg.SetBackdropColor then
          local r, g, b, a = CS_BG()
          bg:SetBackdropColor(r, g, b, a)
        end
        if bg and bg.SetBackdropBorderColor then
          bg:SetBackdropBorderColor(br, bgG, bB, bA)
        end

        -- Keep text color in sync too.
        if frame.GetRegions then
          for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then
              region:SetTextColor(tr, tg, tb, ta)
            end
          end
        end
        return
      end

      StripTextures(frame, true)

      -- These sections often have their own NineSlice/backdrop chrome.
      if frame.NineSlice then frame.NineSlice:Hide() end
      if frame.BorderFrame then frame.BorderFrame:SetAlpha(0) end
      if frame.Background and frame.Background.SetAlpha then frame.Background:SetAlpha(0) end
      if frame.Bg and frame.Bg.SetAlpha then frame.Bg:SetAlpha(0) end
      if frame.Inset and frame.Inset.NineSlice then frame.Inset.NineSlice:Hide() end

      local bg = EnsureBackdropFrame(frame)
      if bg and bg.SetBackdrop then
        local edgeSize = Theme.GetEdgeSize()
        bg:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        local r, g, b, a      = CS_BG()
        local br, bgG, bB, bA = CS_B()

        bg:SetBackdropColor(r, g, b, a)
        bg:SetBackdropBorderColor(br, bgG, bB, bA)
      end

      -- Keep stat text colors in sync; row fonts are owned by PaperDollFrame_SetLabelAndText.
      local tr, tg, tb, ta = GetTextColor()

      if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
          if region and region.IsObjectType and region:IsObjectType("FontString") then
            region:SetTextColor(tr, tg, tb, ta)
          end
        end
      end

      if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
          if child and child.GetRegions then
            for _, region in ipairs({ child:GetRegions() }) do
              if region and region.IsObjectType and region:IsObjectType("FontString") then
                region:SetTextColor(tr, tg, tb, ta)
              end
            end
          end
        end
      end

      frame._puiCharStatsSkinned = true
    end

    -- Skin category headers if present on this build.
    SkinStatsHeader(CharacterStatsPane.ItemLevelCategory)
    SkinStatsHeader(CharacterStatsPane.AttributesCategory)
    SkinStatsHeader(CharacterStatsPane.EnhancementsCategory)

    -- Keep item level clean: the category header and value are enough.
    if CharacterStatsPane.ItemLevelFrame then
      StripTextures(CharacterStatsPane.ItemLevelFrame, true)
      local itemLevelBackdrop = CharacterStatsPane.ItemLevelFrame._puiBg
      if itemLevelBackdrop and itemLevelBackdrop.SetBackdrop then
        itemLevelBackdrop:SetBackdrop(nil)
      end
    end

    SkinStatsFrame(CharacterStatsPane.EnhancementsFrame)
    SkinStatsFrame(CharacterStatsPane.AttributesFrame)
  end
    if PaperDollFrame then
      StripTextures(PaperDollFrame, true)
    end
    if PaperDollItemsFrame then
      StripTextures(PaperDollItemsFrame, true)
      if PaperDollItemsFrame.NineSlice then PaperDollItemsFrame.NineSlice:Hide() end
      if PaperDollItemsFrame.BorderFrame then PaperDollItemsFrame.BorderFrame:SetAlpha(0) end
    end
    if CharacterFrameInset then
      StripTextures(CharacterFrameInset, true)
      if CharacterFrameInset.NineSlice then CharacterFrameInset.NineSlice:Hide() end
      if CharacterFrameInset.BorderFrame then CharacterFrameInset.BorderFrame:SetAlpha(0) end
      if CharacterFrameInset.Bg and CharacterFrameInset.Bg.SetAlpha then CharacterFrameInset.Bg:SetAlpha(0) end
      if CharacterFrameInset.Background and CharacterFrameInset.Background.SetAlpha then CharacterFrameInset.Background:SetAlpha(0) end
    end
    if CharacterFrameInsetRight then
      StripTextures(CharacterFrameInsetRight, true)
      if CharacterFrameInsetRight.NineSlice then CharacterFrameInsetRight.NineSlice:Hide() end
      if CharacterFrameInsetRight.BorderFrame then CharacterFrameInsetRight.BorderFrame:SetAlpha(0) end
      if CharacterFrameInsetRight.Bg and CharacterFrameInsetRight.Bg.SetAlpha then CharacterFrameInsetRight.Bg:SetAlpha(0) end
      if CharacterFrameInsetRight.Background and CharacterFrameInsetRight.Background.SetAlpha then CharacterFrameInsetRight.Background:SetAlpha(0) end
    end
    if PaperDollSidebarTabs then
      StripTextures(PaperDollSidebarTabs, true)
      if PaperDollSidebarTabs.NineSlice then PaperDollSidebarTabs.NineSlice:Hide() end
      if PaperDollSidebarTabs.BorderFrame then PaperDollSidebarTabs.BorderFrame:SetAlpha(0) end
    end
    if CharacterFrameCloseButton then
      ns.Theme.WidgetSkins.CloseButton(CharacterFrameCloseButton)
    end

    local talentsBtn = CharacterFrame and CharacterFrame.TalentsButton
    if talentsBtn then
      StripTextures(talentsBtn, true)
      ns.Theme.WidgetSkins.Button(talentsBtn)
    end
  end

  ApplyCoreDecorations()

  if not CharacterFrame._puiCharCoreDecorHooked then
    hooksecurefunc(CharacterFrame, "RefreshDisplay", CS_SuppressCoreBlizzardArt)
    hooksecurefunc(CharacterFrame, "UpdateSize", CS_SuppressCoreBlizzardArt)
    CharacterFrame._puiCharCoreDecorHooked = true
  end

  -- Kill tab borders/textures; we’ll restyle or leave minimal text only.
  for i = 1, 3 do
    local tab = _G["CharacterFrameTab" .. i]
    if tab then
      StripTextures(tab, true)
      if tab.SetNormalTexture   then tab:SetNormalTexture("")   end
      if tab.SetPushedTexture   then tab:SetPushedTexture("")   end
      if tab.SetDisabledTexture then tab:SetDisabledTexture("") end
      if tab.SetHighlightTexture then tab:SetHighlightTexture("") end

      local bg = EnsureBackdropFrame(tab)
      if bg and bg.SetBackdrop then
        local edgeSize = Theme.GetEdgeSize()
        bg:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        local r, g, b, a = CS_CONTROL()
        bg:SetBackdropColor(r, g, b, a)

        local br, bgG, bB, bA = CS_B()
        bg:SetBackdropBorderColor(br, bgG, bB, bA)
      end
    end
  end



  -- Initial shell state: character page uses extended shell.
  CharacterSheet._shellExtended = true
  EnsureShellHost()
  CS_EnsureCharacterFrameWindowControls()
  CS_ApplyCharacterFrameWindowState()
  UpdateCharacterAverageItemLevelText()
  CS_LayoutMaxHealthRow()

  if not CharacterFrame._puiSettingsButton then
    local button = CreateFrame("Button", "PUI_CharacterFrameSettings", CharacterFrame)
    CharacterFrame._puiSettingsButton = button

    button:SetParent(CharacterFrame)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(CharacterFrame:GetFrameLevel() + 100)
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(22, 22)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -12, 12)
    button.HandlesGlobalMouseEvent = CS_SettingsButtonHandlesGlobalMouseEvent

    button.__puiIconAlpha = 0.78
    button.__puiIconInsetX = 3
    button.__puiIconInsetY = 1

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", button.__puiIconInsetX, -button.__puiIconInsetY)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -button.__puiIconInsetX, button.__puiIconInsetY)
    icon:SetTexture(CS_CONFIG_TEXTURE)
    icon:SetTexCoord(0.30, 0.70, 0.20, 0.80)
    icon:SetAlpha(button.__puiIconAlpha)
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.10)

    button:SetScript("OnEnter", function(self)
      self.icon:SetAlpha(1)
    end)
    button:SetScript("OnLeave", function(self)
      self.icon:SetAlpha(self.__puiIconAlpha)
    end)
    button:SetScript("OnClick", CS_ToggleCharacterSettingsMenu)
  end

  CS_UpdateCharacterSettingsButtonVisibility()

  if not CharacterFrame._puiSubFrameHooked then
    hooksecurefunc(CharacterFrame, "ShowSubFrame", CS_AfterCharacterSubFrameShown)
    CharacterFrame._puiSubFrameHooked = true
  end

  if CharacterFrame.activeSubframe then
    CS_AfterCharacterSubFrameShown(CharacterFrame, CharacterFrame.activeSubframe)
  end

  -- Reputation: hook ScrollBox updates
  if ReputationFrame and ReputationFrame.ScrollBox and ReputationFrame.ScrollBox.ForEachFrame then
    hooksecurefunc(ReputationFrame.ScrollBox, "Update", function(scrollBox)

      scrollBox:ForEachFrame(SkinReputationEntry)
    end)

  end
  -- Currencies (TokenFrame)

  if TokenFrame and TokenFrame.ScrollBox and TokenFrame.ScrollBox.ForEachFrame then
    hooksecurefunc(TokenFrame.ScrollBox, "Update", function(scrollBox)

      scrollBox:ForEachFrame(SkinCurrencyButton)
    end)

  end

  CS_SkinModelControlButtons(CharacterModelScene and CharacterModelScene.ControlFrame)
  CS_SkinSidebarTabs()
  CS_SkinEquipmentFlyout()

  local titleManagerPane = PaperDollFrame and PaperDollFrame.TitleManagerPane
  if titleManagerPane then
    if not titleManagerPane._puiCharShowHooked then
      titleManagerPane:HookScript("OnShow", SkinTitleManagerPane)
      titleManagerPane._puiCharShowHooked = true
    end

    if titleManagerPane:IsShown() then
      SkinTitleManagerPane()
    end
  end

  local equipmentManagerPane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
  if equipmentManagerPane then
    if not equipmentManagerPane._puiCharShowHooked then
      equipmentManagerPane:HookScript("OnShow", CS_SkinEquipmentManagerPane)
      equipmentManagerPane._puiCharShowHooked = true
    end

    if equipmentManagerPane:IsShown() then
      CS_SkinEquipmentManagerPane()
    end
  end

  if not CharacterSheet._sidebarTabsHooked then
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", CS_SkinSidebarTabs)
    CharacterSheet._sidebarTabsHooked = true
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

  if CharacterSheet._inspectInit then
    EnsureInspectShellHost()
    return
  end

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

    if InspectFrame.TitleText then
      ns.Theme.ApplyFont(InspectFrame.TitleText, "title")
      local tr, tg, tb, ta = GetTextColor()
      InspectFrame.TitleText:SetTextColor(tr, tg, tb, ta)
    end

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
      StripTextures(tab, true)
      if tab.SetNormalTexture then tab:SetNormalTexture("") end
      if tab.SetPushedTexture then tab:SetPushedTexture("") end
      if tab.SetDisabledTexture then tab:SetDisabledTexture("") end
      if tab.SetHighlightTexture then tab:SetHighlightTexture("") end

      local bg = EnsureBackdropFrame(tab)
      if bg and bg.SetBackdrop then
        local edgeSize = Theme.GetEdgeSize()
        bg:SetBackdrop({
          bgFile   = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
        })

        local r, g, b, a = CS_CONTROL()
        local br, bgG, bB, bA = CS_B()
        bg:SetBackdropColor(r, g, b, a)
        bg:SetBackdropBorderColor(br, bgG, bB, bA)
      end

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
    end
    if InspectPVPFrame then
      InspectPVPFrame:HookScript("OnShow", UpdateInspectPaperDollVisibility)
    end
    if InspectGuildFrame then
      InspectGuildFrame:HookScript("OnShow", UpdateInspectPaperDollVisibility)
    end

    for i = 1, 3 do
      local tab = _G["InspectFrameTab" .. i]
      if tab then
        tab:HookScript("OnClick", function()
          C_Timer.After(0, UpdateInspectPaperDollVisibility)
        end)
      end
    end

    InspectFrame._puiPaperDollVisibilityHooked = true
  end

  -- Hook inspect item slots
  if not CharacterSheet._inspectSlotHook then
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
      CS_QueueInspectSlotButton(button)
    end)
    CharacterSheet._inspectSlotHook = true
  end

  InspectFrame:HookScript("OnShow", function()
    C_Timer.After(0.01, function()

      EnsureInspectShellHost()
      CS_SetInspectPending()

      if InspectFrame and InspectFrame.unit and CanInspect(InspectFrame.unit) then
        NotifyInspect(InspectFrame.unit)
      end

      for i = 1, 19 do
        local b = _G["Inspect" .. i .. "Slot"]
        if b then
          SkinItemSlotButton(b)
          CS_HideInspectSlotOverlay(b)
        end
      end
    end)
  end)
end

function CharacterSheet:RefreshTheme()
  if CharacterFrame and self._initialized then
    EnsureShellHost()
    CS_EnsureCharacterFrameWindowControls()
    UpdateCharacterAverageItemLevelText()
    CS_LayoutMaxHealthRow()
    CS_RefreshCharacterStatFonts()
    CS_RefreshSlotDisplaySettings()

    local tr, tg, tb, ta = GetTextColor()

    if CharacterFrame.TitleText then
      ns.Theme.ApplyFont(CharacterFrame.TitleText, "title")
      CharacterFrame.TitleText:SetTextColor(tr, tg, tb, ta)
    end

    CS_ApplyBackdrop(CharacterFramePortraitFrame, CS_BG)
    CS_ApplyBackdrop(CharacterStatsPane, CS_BG)

    if CharacterStatsPane then
      for _, category in pairs({
        CharacterStatsPane.ItemLevelCategory,
        CharacterStatsPane.AttributesCategory,
        CharacterStatsPane.EnhancementsCategory,
      }) do
        if category then
          CS_ApplyBackdrop(category, CS_BG)
          if category.Text then
            ns.Theme.ApplyFont(category.Text, "nav")
            category.Text:SetTextColor(tr, tg, tb, ta)
          end
        end
      end

      for _, statsFrame in pairs({
        CharacterStatsPane.EnhancementsFrame,
        CharacterStatsPane.AttributesFrame,
      }) do
        if statsFrame then
          CS_ApplyBackdrop(statsFrame, CS_BG)

          for _, region in ipairs({ statsFrame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then
              region:SetTextColor(tr, tg, tb, ta)
            end
          end

          for _, child in ipairs({ statsFrame:GetChildren() }) do
            if child and child.GetRegions then
              for _, region in ipairs({ child:GetRegions() }) do
                if region and region.IsObjectType and region:IsObjectType("FontString") then
                  region:SetTextColor(tr, tg, tb, ta)
                end
              end
            end
          end
        end
      end
    end

    for i = 1, 3 do
      CS_ApplyBackdrop(_G["CharacterFrameTab" .. i], CS_CONTROL)
    end

    CS_SkinCloseButton(CharacterFrameCloseButton)
    CS_SkinButton(CharacterFrame.TalentsButton)
    CS_SkinModelControlButtons(CharacterModelScene and CharacterModelScene.ControlFrame)
    CS_SkinSidebarTabs()
    SkinTitleManagerPane()
    CS_SkinEquipmentManagerPane()
    CS_SkinEquipmentFlyout()
    CS_SkinReputationAndCurrencyExtras()

    if ReputationFrame and ReputationFrame.ScrollBox and ReputationFrame.ScrollBox.ForEachFrame then
      ReputationFrame.ScrollBox:ForEachFrame(SkinReputationEntry)
    end

    if TokenFrame and TokenFrame.ScrollBox and TokenFrame.ScrollBox.ForEachFrame then
      TokenFrame.ScrollBox:ForEachFrame(SkinCurrencyButton)
    end

    local paperDollItems = _G.PaperDollItemsFrame
    if paperDollItems and paperDollItems.GetChildren then
      for _, button in ipairs({ paperDollItems:GetChildren() }) do
        RefreshItemSlotOverlayTheme(button)
      end
    end
  end

  if InspectFrame and self._inspectInit then
    EnsureInspectShellHost()

    local tr, tg, tb, ta = GetTextColor()
    if InspectFrame.TitleText then
      ns.Theme.ApplyFont(InspectFrame.TitleText, "title")
      InspectFrame.TitleText:SetTextColor(tr, tg, tb, ta)
    end

    CS_ApplyBackdrop(InspectModelFrame, CS_BG)
    CS_SkinCloseButton(InspectFrameCloseButton)
    CS_SkinButton(InspectPaperDollFrame and InspectPaperDollFrame.ViewButton)
    CS_SkinButton(InspectPaperDollItemsFrame and InspectPaperDollItemsFrame.InspectTalents)
    CS_SkinInspectPvPFrame()

    for i = 1, 3 do
      CS_ApplyBackdrop(_G["InspectFrameTab" .. i], CS_CONTROL)
    end

    if InspectFrame._puiAvgItemLevelText then
      ns.Theme.ApplyFont(InspectFrame._puiAvgItemLevelText, "body")
      InspectFrame._puiAvgItemLevelText:SetTextColor(tr, tg, tb, ta)
    end

    for i = 1, 19 do
      RefreshItemSlotOverlayTheme(_G["Inspect" .. i .. "Slot"])
    end
  end
end


-- Module lifecycle
do
  -- Standalone event driver; independent of Ace module state.
  local driver = CreateFrame("Frame")
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  driver:RegisterEvent("PLAYER_LEVEL_UP")
  driver:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
  driver:RegisterEvent("INSPECT_READY")
  driver:RegisterEvent("UNIT_MODEL_CHANGED")

  driver:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" then
      if arg1 == "Blizzard_UIPanels_Game" then
        C_Timer.After(0.1, SetupCharacterFrameSkinning)
      elseif arg1 == "Blizzard_InspectUI" then
        C_Timer.After(0.1, SetupInspectFrameSkinning)
      end

      return
    end

    if event == "PLAYER_LOGIN" then
      if CharacterFrame then
        C_Timer.After(0.1, SetupCharacterFrameSkinning)
      end
      if InspectFrame then
        C_Timer.After(0.1, SetupInspectFrameSkinning)
      end
      self:UnregisterEvent("PLAYER_LOGIN")
      return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
      CS_ClearSlotInfoCache()
      CS_RefreshPlayerSlots()
      return
    end

    if event == "PLAYER_LEVEL_UP" then
      CS_ClearSlotInfoCache()
      CS_RefreshPlayerSlots()
      return
    end

    if event == "UPDATE_INVENTORY_DURABILITY" then
      CS_RefreshPlayerSlots()
      return
    end

    if event == "PLAYER_REGEN_DISABLED" then
      CS_ClearItemStatHighlights(true)
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      CS_RefreshPlayerItemStatPresence()
      CS_RefreshSecondaryStatRatingTexts()
      return
    end

    if event == "UNIT_MAXHEALTH" then
      CS_UpdateMaxHealthValue()
      return
    end

    if event == "INSPECT_READY" then
      CS_ClearSlotInfoCache()
      CharacterSheet._inspectReadyGUID = arg1

      C_Timer.After(0.05, function()
        CS_RefreshInspectData(arg1)
      end)
      return
    end

    if event == "UNIT_MODEL_CHANGED" and arg1 == "target" then
      if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() and InspectFrame.unit == "target" then
        local guid = UnitGUID("target")
        if guid and guid ~= CharacterSheet._inspectReadyGUID then
          CS_SetInspectPending()
          if CanInspect("target") then
            NotifyInspect("target")
          end
        end
      end
      return
    end
  end)
end



  CS_ClearSlotInfoCache = P:Def("CS_ClearSlotInfoCache", CS_ClearSlotInfoCache)
  CS_GetCachedSlotInfo = P:Def("CS_GetCachedSlotInfo", CS_GetCachedSlotInfo)
  CS_GetCachedInventoryTooltipData = P:Def("CS_GetCachedInventoryTooltipData", CS_GetCachedInventoryTooltipData)
  _CS_GetDB = P:Def("_CS_GetDB", _CS_GetDB)
  CS_GetShowEnchants = P:Def("CS_GetShowEnchants", CS_GetShowEnchants)
  CS_SetShowEnchants = P:Def("CS_SetShowEnchants", CS_SetShowEnchants)
  CS_GetShowSocketIcons = P:Def("CS_GetShowSocketIcons", CS_GetShowSocketIcons)
  CS_SetShowSocketIcons = P:Def("CS_SetShowSocketIcons", CS_SetShowSocketIcons)
  CS_GetShowBagItemLevel = P:Def("CS_GetShowBagItemLevel", CS_GetShowBagItemLevel)
  CS_SetShowBagItemLevel = P:Def("CS_SetShowBagItemLevel", CS_SetShowBagItemLevel)
  CS_GetShowStatRatings = P:Def("CS_GetShowStatRatings", CS_GetShowStatRatings)
  CS_SetShowStatRatings = P:Def("CS_SetShowStatRatings", CS_SetShowStatRatings)
  CS_GetHighlightStatGear = P:Def("CS_GetHighlightStatGear", CS_GetHighlightStatGear)
  CS_SetHighlightStatGear = P:Def("CS_SetHighlightStatGear", CS_SetHighlightStatGear)
  CS_GetShowMaxHealth = P:Def("CS_GetShowMaxHealth", CS_GetShowMaxHealth)
  CS_SetShowMaxHealth = P:Def("CS_SetShowMaxHealth", CS_SetShowMaxHealth)
  CS_GetUsePleebUIFont = P:Def("CS_GetUsePleebUIFont", CS_GetUsePleebUIFont)
  CS_SetUsePleebUIFont = P:Def("CS_SetUsePleebUIFont", CS_SetUsePleebUIFont)
  CS_RestoreCharacterStatFont = P:Def("CS_RestoreCharacterStatFont", CS_RestoreCharacterStatFont)
  CS_TrackCharacterStatFrame = P:Def("CS_TrackCharacterStatFrame", CS_TrackCharacterStatFrame)
  CS_ApplyCharacterStatFont = P:Def("CS_ApplyCharacterStatFont", CS_ApplyCharacterStatFont)
  CS_RefreshCharacterStatFonts = P:Def("CS_RefreshCharacterStatFonts", CS_RefreshCharacterStatFonts)
  CS_ClearSecondaryStatRatingText = P:Def("CS_ClearSecondaryStatRatingText", CS_ClearSecondaryStatRatingText)
  CS_ForwardSecondaryStatRatingText = P:Def("CS_ForwardSecondaryStatRatingText", CS_ForwardSecondaryStatRatingText)
  CS_RefreshSecondaryStatRatingTexts = P:Def("CS_RefreshSecondaryStatRatingTexts", CS_RefreshSecondaryStatRatingTexts)
  CS_EnsureMaxHealthRow = P:Def("CS_EnsureMaxHealthRow", CS_EnsureMaxHealthRow)
  CS_UpdateMaxHealthValue = P:Def("CS_UpdateMaxHealthValue", CS_UpdateMaxHealthValue)
  CS_LayoutMaxHealthRow = P:Def("CS_LayoutMaxHealthRow", CS_LayoutMaxHealthRow)
  CS_ClearItemStatHighlights = P:Def("CS_ClearItemStatHighlights", CS_ClearItemStatHighlights)
  CS_ShowItemStatHighlights = P:Def("CS_ShowItemStatHighlights", CS_ShowItemStatHighlights)
  CS_SetupPaperDollValueHooks = P:Def("CS_SetupPaperDollValueHooks", CS_SetupPaperDollValueHooks)
  ColorFromTheme = P:Def("ColorFromTheme", ColorFromTheme)
  GetTextColor = P:Def("GetTextColor", GetTextColor)
  _Clamp01 = P:Def("_Clamp01", _Clamp01)
  CS_BG = P:Def("CS_BG", CS_BG)
  CS_CONTROL = P:Def("CS_CONTROL", CS_CONTROL)
  CS_B = P:Def("CS_B", CS_B)
  CS_ACCENT = P:Def("CS_ACCENT", CS_ACCENT)
  IsEnchantableSlot = P:Def("IsEnchantableSlot", IsEnchantableSlot)
  CS_IsEnchantWarningLevel = P:Def("CS_IsEnchantWarningLevel", CS_IsEnchantWarningLevel)
  StripTextures = P:Def("StripTextures", StripTextures)
  SkinItemSlotButton = P:Def("SkinItemSlotButton", SkinItemSlotButton)
  EnsureShellHost = P:Def("EnsureShellHost", EnsureShellHost)
  CharacterSheet.SetShellExtended = P:Def("CharacterSheet.SetShellExtended", CharacterSheet.SetShellExtended)
  EnsureCharacterAverageItemLevelText = P:Def("EnsureCharacterAverageItemLevelText", EnsureCharacterAverageItemLevelText)
  UpdateCharacterAverageItemLevelText = P:Def("UpdateCharacterAverageItemLevelText", UpdateCharacterAverageItemLevelText)
  EnsureInspectAverageItemLevelText = P:Def("EnsureInspectAverageItemLevelText", EnsureInspectAverageItemLevelText)
  UpdateInspectAverageItemLevelText = P:Def("UpdateInspectAverageItemLevelText", UpdateInspectAverageItemLevelText)
  CS_ClearInspectAverageItemLevelText = P:Def("CS_ClearInspectAverageItemLevelText", CS_ClearInspectAverageItemLevelText)
  CS_HideInspectSlotOverlay = P:Def("CS_HideInspectSlotOverlay", CS_HideInspectSlotOverlay)
  CS_ClearInspectSlotOverlays = P:Def("CS_ClearInspectSlotOverlays", CS_ClearInspectSlotOverlays)
  CS_SetInspectPending = P:Def("CS_SetInspectPending", CS_SetInspectPending)
  CS_IsInspectReady = P:Def("CS_IsInspectReady", CS_IsInspectReady)
  CS_RefreshInspectData = P:Def("CS_RefreshInspectData", CS_RefreshInspectData)
  CS_SkinReputationBar = P:Def("CS_SkinReputationBar", CS_SkinReputationBar)
  SkinReputationEntry = P:Def("SkinReputationEntry", SkinReputationEntry)
  SkinCurrencyEntry = P:Def("SkinCurrencyEntry", SkinCurrencyEntry)
  SkinCurrencyHeader = P:Def("SkinCurrencyHeader", SkinCurrencyHeader)
  SkinCurrencyButton = P:Def("SkinCurrencyButton", SkinCurrencyButton)
  CS_ApplyBackdrop = P:Def("CS_ApplyBackdrop", CS_ApplyBackdrop)
  CS_SkinButton = P:Def("CS_SkinButton", CS_SkinButton)
  CS_SkinCloseButton = P:Def("CS_SkinCloseButton", CS_SkinCloseButton)
  CS_SkinTextureIcon = P:Def("CS_SkinTextureIcon", CS_SkinTextureIcon)
  CS_SkinCheckBox = P:Def("CS_SkinCheckBox", CS_SkinCheckBox)
  CS_SkinDropDown = P:Def("CS_SkinDropDown", CS_SkinDropDown)
  CS_SkinEditBox = P:Def("CS_SkinEditBox", CS_SkinEditBox)
  CS_SkinScrollBar = P:Def("CS_SkinScrollBar", CS_SkinScrollBar)
  CS_SkinModelControlButtons = P:Def("CS_SkinModelControlButtons", CS_SkinModelControlButtons)
  CS_SkinSidebarTabs = P:Def("CS_SkinSidebarTabs", CS_SkinSidebarTabs)
  CS_SkinEquipmentManagerPane = P:Def("CS_SkinEquipmentManagerPane", CS_SkinEquipmentManagerPane)
  CS_SkinEquipmentFlyout = P:Def("CS_SkinEquipmentFlyout", CS_SkinEquipmentFlyout)
  CS_SkinReputationAndCurrencyExtras = P:Def("CS_SkinReputationAndCurrencyExtras", CS_SkinReputationAndCurrencyExtras)
  CS_SkinInspectPvPFrame = P:Def("CS_SkinInspectPvPFrame", CS_SkinInspectPvPFrame)
  GetSlotItemLevel = P:Def("GetSlotItemLevel", GetSlotItemLevel)
  CS_GetEquippedItemState = P:Def("CS_GetEquippedItemState", CS_GetEquippedItemState)
  CS_GetWeaponItemLevelTotal = P:Def("CS_GetWeaponItemLevelTotal", CS_GetWeaponItemLevelTotal)
  CS_FormatItemLevel = P:Def("CS_FormatItemLevel", CS_FormatItemLevel)
  CS_GetPlayerEquippedItemLevel = P:Def("CS_GetPlayerEquippedItemLevel", CS_GetPlayerEquippedItemLevel)
  CS_CalculateUnitAverageItemLevel = P:Def("CS_CalculateUnitAverageItemLevel", CS_CalculateUnitAverageItemLevel)
  GetSlotEnchantInfo = P:Def("GetSlotEnchantInfo", GetSlotEnchantInfo)
  GetGemInfo = P:Def("GetGemInfo", GetGemInfo)
  CS_AddPermanentEnchantStatPresence = P:Def("CS_AddPermanentEnchantStatPresence", CS_AddPermanentEnchantStatPresence)
  UpdateItemSlotOverlay = P:Def("UpdateItemSlotOverlay", UpdateItemSlotOverlay)
  CS_QueueInspectSlotButton = P:Def("CS_QueueInspectSlotButton", CS_QueueInspectSlotButton)
  CS_RefreshPlayerSlots = P:Def("CS_RefreshPlayerSlots", CS_RefreshPlayerSlots)
  CS_RefreshSlotDisplaySettings = P:Def("CS_RefreshSlotDisplaySettings", CS_RefreshSlotDisplaySettings)
  CS_SettingsButtonHandlesGlobalMouseEvent = P:Def("CS_SettingsButtonHandlesGlobalMouseEvent", CS_SettingsButtonHandlesGlobalMouseEvent)
  CS_ToggleCharacterSettingsMenu = P:Def("CS_ToggleCharacterSettingsMenu", CS_ToggleCharacterSettingsMenu)
  CS_UpdateCharacterSettingsButtonVisibility = P:Def("CS_UpdateCharacterSettingsButtonVisibility", CS_UpdateCharacterSettingsButtonVisibility)
  CS_AfterCharacterSubFrameShown = P:Def("CS_AfterCharacterSubFrameShown", CS_AfterCharacterSubFrameShown)
  RefreshItemSlotOverlayTheme = P:Def("RefreshItemSlotOverlayTheme", RefreshItemSlotOverlayTheme)
  RefreshTitleEntryTheme = P:Def("RefreshTitleEntryTheme", RefreshTitleEntryTheme)
  SkinTitleEntry = P:Def("SkinTitleEntry", SkinTitleEntry)
  SkinTitleManagerPane = P:Def("SkinTitleManagerPane", SkinTitleManagerPane)
  CS_SuppressCoreBlizzardArt = P:Def("CS_SuppressCoreBlizzardArt", CS_SuppressCoreBlizzardArt)
  CS_ClampCharacterFrameScale = P:Def("CS_ClampCharacterFrameScale", CS_ClampCharacterFrameScale)
  CS_SetCharacterFrameScaledTopLeft = P:Def("CS_SetCharacterFrameScaledTopLeft", CS_SetCharacterFrameScaledTopLeft)
  CS_SaveCharacterFrameWindowState = P:Def("CS_SaveCharacterFrameWindowState", CS_SaveCharacterFrameWindowState)
  CS_ApplyCharacterFrameWindowState = P:Def("CS_ApplyCharacterFrameWindowState", CS_ApplyCharacterFrameWindowState)
  CS_UpdateCharacterFrameResize = P:Def("CS_UpdateCharacterFrameResize", CS_UpdateCharacterFrameResize)
  CS_EndCharacterFrameResize = P:Def("CS_EndCharacterFrameResize", CS_EndCharacterFrameResize)
  CS_BeginCharacterFrameResize = P:Def("CS_BeginCharacterFrameResize", CS_BeginCharacterFrameResize)
  CS_BeginCharacterFrameDrag = P:Def("CS_BeginCharacterFrameDrag", CS_BeginCharacterFrameDrag)
  CS_EndCharacterFrameDrag = P:Def("CS_EndCharacterFrameDrag", CS_EndCharacterFrameDrag)
  CS_StopCharacterFrameInteraction = P:Def("CS_StopCharacterFrameInteraction", CS_StopCharacterFrameInteraction)
  CS_AfterUIPanelPositionsUpdated = P:Def("CS_AfterUIPanelPositionsUpdated", CS_AfterUIPanelPositionsUpdated)
  CS_EnsureCharacterFrameWindowControls = P:Def("CS_EnsureCharacterFrameWindowControls", CS_EnsureCharacterFrameWindowControls)
  SetupCharacterFrameSkinning = P:Def("SetupCharacterFrameSkinning", SetupCharacterFrameSkinning)
  EnsureInspectShellHost = P:Def("EnsureInspectShellHost", EnsureInspectShellHost)
  SetupInspectFrameSkinning = P:Def("SetupInspectFrameSkinning", SetupInspectFrameSkinning)
  CharacterSheet.RefreshTheme = P:Def("CharacterSheet.RefreshTheme", CharacterSheet.RefreshTheme)
