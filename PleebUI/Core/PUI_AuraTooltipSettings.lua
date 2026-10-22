local _, ns = ...
local TooltipSettings = {}
ns.AuraTooltipSettings = TooltipSettings

function TooltipSettings.ApplyCVar(enabled)
  C_CVar.SetCVar("tooltipShowAuraSpellIDs", enabled and "1" or "0")
end

function TooltipSettings.ApplyPreference(enabled)
  local optionsFrame = ns.Addon._OptionsWindow
  TooltipSettings.ApplyCVar(optionsFrame and optionsFrame:IsShown() or enabled == true)
end
