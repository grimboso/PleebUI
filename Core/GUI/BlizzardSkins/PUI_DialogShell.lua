local _, ns = ...
local Theme = ns.Theme

function Theme:ApplyDialogShell(frame)
  local colors = self:GetColors()

  ns.IconSkin.StripNineSliceAndBackdrop(frame)
  Theme.SetSquareBackdrop(frame, {
    bg = colors.background,
    border = colors.border,
  }, Theme.GetEdgeSize())
end

function ns.BlizzardSkins.StripDialogTextures(root, keepFrame, keepRegion)
  local seen = {}

  local function StripFrame(frame)
    if seen[frame] or frame.__puiIsBackdropFrame then
      return
    end
    seen[frame] = true

    if frame ~= root and keepFrame(frame) then
      return
    end

    if frame.SetBackdrop then
      frame:SetBackdrop(nil)
    end

    local buttonSkin = frame.__puiButtonTextureSkin
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:GetObjectType() == "Texture" then
        local ownedButtonTexture = buttonSkin and (
          region == buttonSkin.bg
          or region == buttonSkin.top
          or region == buttonSkin.bottom
          or region == buttonSkin.left
          or region == buttonSkin.right
        )

        if ownedButtonTexture or keepRegion(region) then
          region:SetAlpha(1)
          region:Show()
        else
          region:SetTexture(nil)
          region:SetAlpha(0)
          region:Hide()
        end
      end
    end

    for _, borderFrame in ipairs({ frame.BorderBox, frame.Border, frame.NineSlice }) do
      if borderFrame and borderFrame ~= frame then
        StripFrame(borderFrame)
        borderFrame:Hide()
      end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
      if child ~= frame._puiBg and not child.__puiIsBackdropFrame then
        StripFrame(child)
      end
    end
  end

  StripFrame(root)
end

