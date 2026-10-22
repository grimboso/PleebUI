local _, ns = ...
local Examples = {}
ns.InstallerExamples = Examples
local Theme = ns.Theme
local roots = {}

local function Text(parent, value, point, x, y, size)
  local text = parent:CreateFontString(nil, "OVERLAY")
  text:SetPoint(point, parent, point, x, y)
  Theme.ApplyFont(text, "body", size or 14)
  text:SetText(value)
  return text
end

local function Icon(parent, texture)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(32, 32)
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(frame)
  icon:SetTexture(texture)
  ns.IconSkin.MakeIconSquare(icon, { crop = 0.08 })
  local cooldownText = Text(frame, "8", "CENTER", 0, 0, 12)
  local chargeText = Text(frame, "2", "BOTTOMRIGHT", -3, 3, 12)
  ns.BarWidget.ApplyBorder(frame, 1, Theme.GetColors().border)
  return { frame = frame, icon = icon, cooldownText = cooldownText, chargeText = chargeText }
end

local function Build(kind, host)
  local root = CreateFrame("Frame", nil, host, "BackdropTemplate")
  root:SetAllPoints(host)
  root.title = Text(root, "", "TOP", 0, -16, 16)
  root.body = CreateFrame("Frame", nil, root, "BackdropTemplate")
  root.body:SetPoint("CENTER", root, "CENTER", 0, -6)
  if kind == "chat" then
    root.body:SetSize(430, 180)
    root.chat = CreateFrame("ScrollingMessageFrame", nil, root.body)
    root.chat:SetPoint("TOPLEFT", 12, -12)
    root.chat:SetPoint("BOTTOMRIGHT", -12, 12)
    root.chat:SetFading(false)
    root.chat:SetJustifyH("LEFT")
  elseif kind == "minimap" then
    root.logo = root.body:CreateTexture(nil, "ARTWORK")
    root.logo:SetAllPoints(root.body)
    root.logo:SetTexture("Interface\\AddOns\\PleebUI\\Media\\logo.tga")
    root.clock = Text(root.body, "20:15", "TOP", 0, -8)
    root.coordinates = Text(root.body, "52.4, 48.1", "BOTTOM", 0, 8)
    root.zone = Text(root.body, "Zone name", "TOP", 0, 24)
  elseif kind == "buffs" or kind == "bags" then
    root.body:SetSize(300, 160)
    root.icons = {}
    for index, texture in ipairs({ 135940, 136085, 135987, 134400, 136243, 136116, 135915, 135932 }) do
      root.icons[index] = Icon(root.body, texture)
    end
  elseif kind == "skins" then
    root.body:SetSize(420, 180)
    Text(root.body, "Example game window", "TOPLEFT", 16, -16, 16)
    Text(root.body, "Window background, border, and controls", "CENTER", 0, 0)
    root.button = CreateFrame("Button", nil, root.body, "UIPanelButtonTemplate")
    root.button:SetSize(150, 34)
    root.button:SetPoint("BOTTOM", 0, 16)
    root.button:SetText("Sample button")
    root.button:EnableMouse(false)
  elseif kind == "skyriding" then
    root.bars, root.markers = {}, {}
    for index = 1, 3 do
      local bar = CreateFrame("StatusBar", nil, root.body, "BackdropTemplate")
      bar:SetMinMaxValues(0, 6)
      bar:SetValue(index == 1 and 4 or 2)
      root.bars[index] = bar
    end
    for index = 1, 5 do
      local marker = root.bars[1]:CreateTexture(nil, "OVERLAY")
      marker:SetColorTexture(0, 0, 0, 0.75)
      root.markers[index] = marker
    end
    root.vigor = Text(root.bars[1], "4 / 6", "LEFT", 4, 0, 12)
    root.speed = Text(root.bars[1], "800%", "RIGHT", -4, 0, 12)
  end
  return root
end

function Examples.Show(host, kind)
  for _, root in pairs(roots) do root:Hide() end
  local root = roots[kind]
  if not root then root = Build(kind, host); roots[kind] = root end
  root:SetParent(host)
  root:ClearAllPoints()
  root:SetAllPoints(host)
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(root, { bg = colors.control, border = colors.border }, Theme.GetEdgeSize())
  Theme.SetSquareBackdrop(root.body, { bg = colors.background, border = colors.border }, Theme.GetEdgeSize())
  Theme.ApplyFont(root.title, "header", 16)
  if kind == "chat" then
    local db = ns.Registry.ChatLinks.db.profile
    root.title:SetText("Chat â€” sample messages")
    Theme.SetSquareBackdrop(root.body, db.chatWindowStyle, db.chatWindowStyle.borderSize)
    local typography = db.chatTypography.message
    Theme.ApplyFont(root.chat, "body", 14, typography.outline)
    if typography.useGlobalFont ~= true and typography.font then
      ns.Theme.SetRuntimeFont(root.chat, ns.LSM:Fetch("font", typography.font), 14, typography.outline or "")
    end
    root.chat:Clear()
    root.chat:AddMessage("[Party] Player: Ready when you are.", 0.67, 0.67, 1)
    root.chat:AddMessage("[Party] Group member: Let's go!", 0.67, 0.67, 1)
    root.chat:AddMessage("These messages only appear in this example.", 1, 1, 1)
  elseif kind == "minimap" then
    local db = ns.Registry.Minimap.db.profile
    root.title:SetText("Minimap layout â€” sample map area")
    local size = math.min(230, db.size)
    root.body:SetSize(size, size)
    Theme.ApplyFont(root.clock, "body", db.clockFontSize)
    Theme.ApplyFont(root.coordinates, "body", db.clockBoxCoordFontSize)
    Theme.ApplyFont(root.zone, "body", db.zoneTextFontSize)
    root.clock:SetShown(not db.hideClock)
    root.coordinates:SetShown(db.clockBoxEnabled and db.clockBoxShowCoords)
    root.zone:SetShown(not db.hideZoneText)
  elseif kind == "buffs" or kind == "bags" then
    root.title:SetText(kind == "buffs" and "Player buffs â€” sample icons" or "Bags â€” sample item slots")
    local config = kind == "buffs" and ns.Modules.PlayerBuffs and ns.Modules.PlayerBuffs.db.buffs or nil
    local size = config and config.iconSize or 32
    for index, icon in ipairs(root.icons) do
      icon.frame:ClearAllPoints()
      icon.frame:SetPoint("TOPLEFT", root.body, "TOPLEFT", 16 + (index - 1) % 4 * (size + 5), -30 - math.floor((index - 1) / 4) * (size + 20))
      icon.frame:SetSize(size, size)
      ns.IconSkin.ApplyBorder(icon.frame, { enabled = true, thickness = config and config.borderSize or ns.Pixel.GetOnePixel(), useThemeColor = true })
      Theme.ApplyFont(icon.cooldownText, "body", config and config.textSize or 12, config and config.fontOutline or "")
      icon.cooldownText:SetShown(kind == "buffs")
      icon.chargeText:SetShown(kind == "bags")
    end
    root.body:SetSize(4 * (size + 5) + 32, 2 * (size + 20) + 40)
  elseif kind == "skins" then
    root.title:SetText("Window skins â€” sample controls")
    Theme.WidgetSkins.UIButton(root.button)
  elseif kind == "skyriding" then
    local db = ns.Addon.db.profile.dragonriding
    root.title:SetText("Skyriding â€” sample vigor, Second Wind, and Whirling Surge")
    root.body:SetSize(db.width, db.height + db.swHeight * 2 + db.swGap * 2)
    for index, bar in ipairs(root.bars) do
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", root.body, "TOPLEFT", 0, index == 1 and 0 or -db.height - db.swGap - (index - 2) * (db.swHeight + db.swGap))
      bar:SetSize(db.width, index == 1 and db.height or db.swHeight)
      bar:SetStatusBarTexture(ns.BarWidget.ResolveStatusBarTexture(db.texture))
      bar:SetStatusBarColor(unpack(index == 1 and db.barColor or index == 2 and db.swColor or db.wsColor))
      Theme.SetSquareBackdrop(bar, { bg = db.bgColor, border = db.borderColor }, 1)
      bar:SetShown(index == 1 or index == 2 and db.swEnabled ~= false or index == 3 and db.wsEnabled ~= false)
    end
    for index, marker in ipairs(root.markers) do
      marker:ClearAllPoints()
      marker:SetPoint("LEFT", root.bars[1], "LEFT", db.width * index / 6, 0)
      marker:SetSize(db.segmentThickness, db.height)
      marker:SetShown(db.showSegments ~= false)
    end
    root.vigor:SetShown(db.showVigorText)
    root.speed:SetShown(db.showSpeedText)
  end
  root.body:SetScale(math.min(1, math.max(1, host:GetWidth() - 30) / root.body:GetWidth(),
    math.max(1, host:GetHeight() - 70) / root.body:GetHeight()))
  root:Show()
  return root
end
