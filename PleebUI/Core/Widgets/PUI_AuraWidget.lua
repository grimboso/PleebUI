local _, ns = ...

local AuraWidget = {}
ns.AuraWidget = AuraWidget

function AuraWidget.BindIconButton(button)
  local parts = button.__puiAuraIconParts
  if parts then
    return parts
  end

  local textHolder = button.PUITextHolder
  parts = {
    button = button,
    icon = button.PUIIcon,
    cooldown = button.PUIDurationCooldown,
    textHolder = textHolder,
    count = textHolder.PUIApplicationCount,
    duration = textHolder.PUIDurationText,
  }
  button.__puiAuraIconParts = parts

  parts.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  parts.cooldown:SetDrawEdge(false)
  parts.cooldown:SetDrawBling(false)
  parts.cooldown:SetHideCountdownNumbers(true)
  parts.cooldown:SetReverse(true)
  parts.cooldown:SetSwipeColor(0, 0, 0, 0.65)
  parts.textHolder:SetFrameLevel(parts.cooldown:GetFrameLevel() + 1)

  button.Icon = parts.icon
  button.Cooldown = parts.cooldown
  button.Count = parts.count
  button.Duration = parts.duration

  button:SetIcon(parts.icon)
  button:SetDurationCooldown(parts.cooldown)
  button:SetApplicationCount(parts.count, {})

  return parts
end

local P = select(1, ns.Pleebug:DropIn(AuraWidget, { name = "Core.AuraWidget" }))
AuraWidget.BindIconButton = P:Def("AuraWidget.BindIconButton", AuraWidget.BindIconButton)
