local ADDON_NAME, ns = ...

local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_SpellCount" })

local function Build(owner)
  Secondary.BuildContinuous(owner, owner.secondaryMax, owner.secondaryMax)
  owner.secondaryStatusBar._puiSpellCountLastValue = nil

  local text = Secondary.PrepareSecondaryText(owner, owner.secondaryBar)
  Secondary.SetSecondaryCenterText(text, nil, false)
end

local function Update(owner)
  if owner.secondaryUsesCustom ~= true then
    return
  end

  local statusBar = owner.secondaryStatusBar
  local count = C_Spell.GetSpellCastCount(owner.secondaryDef.castCountSpellID)

  if issecretvalue(count) then
    statusBar._puiSpellCountLastValue = nil
    statusBar:SetValue(count)
  elseif statusBar._puiSpellCountLastValue ~= count then
    statusBar._puiSpellCountLastValue = count
    statusBar:SetValue(count)
  end

  if statusBar._puiLastColorP ~= owner._puiSecColorKey then
    statusBar._puiLastColorP = owner._puiSecColorKey
    statusBar:SetStatusBarColor(
      owner._puiSecColorR,
      owner._puiSecColorG,
      owner._puiSecColorB,
      owner._puiSecColorA
    )
  end
end

local function OnEvent(owner, event, spellID, baseSpellID)
  local trackedSpellID = owner.secondaryDef.castCountSpellID
  if spellID ~= trackedSpellID and baseSpellID ~= trackedSpellID then
    return
  end

  owner:UpdateSecondary()
end

Update = P:Def("SpellCount.Update", Update)
OnEvent = P:Def("SpellCount.OnEvent", OnEvent)

Secondary:RegisterAdapter("SPELL_COUNT", {
  directUpdate = true,
  events = {
    SPELL_UPDATE_USES = true,
  },
  Build = P:Def("SpellCount.Build", Build),
  OnEvent = OnEvent,
  Update = Update,
})
