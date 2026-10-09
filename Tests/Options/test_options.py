from pathlib import Path
from lupa.lua51 import LuaRuntime
import os, json, subprocess
root=Path(__file__).resolve().parents[2]
os.chdir(root)
builders=json.loads(subprocess.check_output(['node',str(Path(__file__).with_name('extract_builders.js'))],cwd=root,text=True))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
captured={}; providers={}; applied={}; ns={Modules={},Registry={Options={}},UFPreview={}}
function copy(source)
 local result={};for k,v in pairs(source) do result[k]=type(v)=='table' and copy(v) or v end;return result
end
TEST_COMBAT=false
function InCombatLockdown() return TEST_COMBAT end
function GetBuildInfo() return '12.1.5','', '',120105 end
function GetTime() return 10 end
function UnitClass() return 'Hunter','HUNTER' end
function UnitHasVehicleUI() return false end
function wipe(t) for k in pairs(t) do t[k]=nil end end
C_Timer={After=function(_,f) f() end}
function LibStub() return {NotifyChange=function() end} end
ns.Pleebug={DropIn=function() return {Def=function(_,name,fn)
 captured[name]=fn
 if name=='UFCB_BuildUnitAurasArgs' or name=='UFCB_BuildPartyAuraArgs' or name=='UFCB_BuildCastbarArgs' then
   return function() return {note={type='description',name='Unchanged editor'}} end
 end
 return fn
end} end}
ns.Addon={RegisterOptionsSection=function(self,key,provider)
 providers[key]=provider; ns.Registry.Options[key]={}
end,ApplyOptionsChange=function(_,owner,flags) applied[#applied+1]={owner,flags} end,
NotifyOptionsTreeChanged=function() end, Print=function() end}
ns.FontDropdown={STANDARD_FONT_KEY='global'}
ns.Theme={STANDARD_OUTLINE_KEY='global', GetBarTexture=function() return 'bar' end}
ns.OptionsUtil={BuildFontValues=function() return {font='Font'} end,
BuildOutlineValues=function() return {global='Global',OUTLINE='Outline'} end,
BuildStatusbarValues=function() return {bar='Bar'} end,
ResolveFontKey=function(font) return font or 'global' end,
GetStoredOutlineValue=function(v) return v or 'global' end,
SetStoredOutlineValue=function(v) return v end}
ns.FrameUtil={RefreshSmartSnapState=function() end}
ns.UFPreview.RegisterAuraManagerDisplayCreator=function() end
ns.UFPreview.RegisterAuraManagerVisibilityCommitter=function() end
ns.UFPreview.RegisterAuraManagerPositionCommitter=function() end
ns.UFPreview.RefreshAuraManagerPreview=function() end
ns.TestMode={IsActive=function() return false end}
ns.UFStyle={GetUFThemeColors=function() return {} end}
function checkCompact(group, ancestors)
 ancestors=ancestors or group.name
 local widgets,children=0,0
 for key,option in pairs(group.args or {}) do
  if option.type=='group' then children=children+1;checkCompact(option,ancestors..'/'..key)
  else widgets=widgets+1 end
 end
 if group.inline then
  assert(widgets+children>0,'Empty inline group '..ancestors)
  assert(widgets>0,'Redundant inline wrapper '..ancestors)
 end
end
function checkInline(group, ancestors)
 ancestors=ancestors or group.name
 if group.inline then assert(type(group.name)=='string' and group.name:match('%S'),'Missing inline heading '..ancestors) end
 for key,option in pairs(group.args or {}) do
  if option.type=='group' then checkInline(option,ancestors..'/'..key)
  else
   assert(group.inline==true,'Unheaded widget '..ancestors..'/'..key)
   assert(type(option.confirm)~='string','Confirmation text used as a method name '..ancestors..'/'..key)
  end
 end
end
''')
ns=lua.globals().ns
def load(path): lua.execute((root/path).read_text(encoding='utf-8'),'PleebUI',ns)
lua.execute('''
registry={};LibStub=setmetatable({NewLibrary=function() return registry end},{__call=function() return {New=function() return {} end} end})
''')
load('libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua')
lua.execute('''
local headingCheck=checkInline
function checkInline(group,ancestors)
 headingCheck(group,ancestors)
 if not ancestors then registry:ValidateOptionsTable(group,'Builder test') end
end
''')
load('Core/GUI/PUI_OptionsSchema.lua')
load('Modules/UnitFrames/PUI_UF_Defaults.lua')
lua.execute('''
ns.UnitFrames={db={profile=copy(ns.UFDefaults.Profile)}}
for _,family in ipairs({ns.UFDefaults.Player,ns.UFDefaults.Target,ns.UFDefaults.Focus,ns.UFDefaults.Boss}) do
 for key,value in pairs(family) do ns.UnitFrames.db.profile.units[key]=copy(value) end
end
function ns.UnitFrames:GetConfigUnit(key) return self.db.profile.units[key] end
function ns.UnitFrames:GetDefaultUnitConfig(key)
 return ns.UFDefaults.Player[key] or ns.UFDefaults.Target[key] or ns.UFDefaults.Focus[key] or ns.UFDefaults.Boss[key]
end
function ns.UnitFrames:GetBaseTextSizesForUnit() return 12,12,12 end
function ns.UnitFrames:GetQuickSetupValue(key) return self.db.profile.quick and self.db.profile.quick[key] end
function ns.UnitFrames:SetQuickSetupValue(key,value) self.db.profile.quick=self.db.profile.quick or {};self.db.profile.quick[key]=value end
for _,pair in ipairs({{'PartyFrames',ns.UFDefaults.GetPartyDefaults()},{'RaidFrames',ns.UFDefaults.GetRaidDefaults()}}) do
 ns.Modules[pair[1]]={db=copy(pair[2]),IsEnabled=function() return true end,SafeRefresh=function() end,RefreshText=function() end,RefreshTextures=function() end,RefreshThreat=function() end,RefreshAuraDisplay=function() end,RefreshMouseoverSettings=function() end}
end
ns.Modules.CastBar={db={profile={enabled=true}}}
''')
load('Modules/UnitFrames/PUI_UF_Config.lua')
lua.execute('''
local provider=providers.unitframes()
local opts=provider:GetOptions()
ns.OptionsSchema.Apply(opts,'unitframes')
checkInline(opts)
for _,family in ipairs({'player','target','focus','boss','party','raid'}) do
 local args=opts.args[family].args
 for _,key in ipairs({'layout','text','indicators','auras'}) do
  assert(args[key],family..' missing '..key)
 end
 assert(not args.general and not args.visibility and not args.layout.args.commonSettings)
 assert(not args.health and not args.name and not args.power)
 for _,role in ipairs({'name','health','power'}) do
  local text=args.text.args[role].args
  assert(text.fontSize.name=='Font size')
  assert(text.font.name=='Font' and text.outline.name=='Outline')
  assert(text.anchor.name=='Anchor point' and text.offsetX.name=='Horizontal offset')
  assert(text.font.order<text.fontSize.order and text.fontSize.order<text.outline.order)
  assert(not text.height and not text.frameHeight and not text.powerHeight)
 end
 assert(args.layout.args.size.args.height.name=='Height')
 assert(not args.layout.args.absorb and args.layout.args.textures.name=='Textures')
 local textures=args.layout.args.textures.args
 assert(textures.healthTexture and textures.powerTexture and textures.absorbTexture)
 assert(not args.layout.args.power.args.texture)
 if family=='player' or family=='party' or family=='raid' then
  assert(args.layout.args.health and next(args.layout.args.health.args))
  assert(not args.layout.args.health.args.texture)
 else
  assert(not args.layout.args.health)
 end
 if family=='party' or family=='raid' then
  assert(not textures.useCustomTexture)
 else
  assert(textures.useCustomTexture and textures.healthTexture.disabled())
  textures.useCustomTexture.set(nil,true);assert(not textures.healthTexture.disabled())
  textures.useCustomTexture.set(nil,false);assert(textures.healthTexture.disabled())
  local range=args.layout.args.range
  assert(range.args.outOfRangeAlpha and not range.args.puiStyle_outOfRange)
 end
 for _,key in ipairs({'layout','text'}) do
  assert(not args[key].args.puiControls, family..' has a notice-only heading in '..key)
 end
end
assert(opts.args.target.order<opts.args.party.order and opts.args.party.order<opts.args.raid.order)
assert(opts.args.raid.order<opts.args.focus.order and opts.args.focus.order<opts.args.boss.order)
assert(not opts.args.general.args.auras and not opts.args.general.args.visibility)
for _,family in ipairs({'party','raid'}) do
 assert(opts.args[family].args.auras.order<opts.args[family].args.dispels.order)
 assert(opts.args[family].args.dispels.order<opts.args[family].args.indicators.order)
end
local highlights=opts.args.general.args.indicators.args.highlights
assert(highlights.inline and highlights.args.mouseoverThickness and highlights.args.targetThickness)
assert(not opts.args.general.args.indicators.args.puiStyle_mouseoverBorder)
highlights.args.mouseoverThickness.set(nil,6)
assert(highlights.args.mouseoverThickness.get()==6)
for _,family in ipairs({'party','raid'}) do
 local args=opts.args[family].args
 local db=ns.Modules[family=='party' and 'PartyFrames' or 'RaidFrames'].db.profile
 local aggro=args.indicators.args.aggro.args
 assert(aggro.enabled.name=='Enable' and aggro.style.name=='Style')
 aggro.enabled.set(nil,true);aggro.style.set(nil,'BOTH');aggro.thickness.set(nil,5)
 assert(db.threatIndicator.enabled and db.threatIndicator.style=='BOTH' and db.threatIndicator.borderSize==5)
 local dispels=args.dispels.args.highlighting.args
 assert(not args.dispels.args.puiStyle_border and args.dispels.args.blizzardIndicatorSettings)
 db.debuffHighlighting='NONE'
 dispels.healthColor.set(nil,true);assert(db.debuffHighlighting=='FILL' and dispels.borderSize.disabled())
 dispels.border.set(nil,true);dispels.borderSize.set(nil,7)
 assert(db.debuffHighlighting=='BOTH' and db.debuffHighlight.borderSize==7 and not dispels.borderSize.disabled())
 dispels.border.set(nil,false);assert(db.debuffHighlighting=='FILL')
end
assert(opts.args.player.args.pet.args.text)
assert(opts.args.target.args.targettarget.args.text)
assert(opts.args.focus.args.focustarget.args.text)
assert(not opts.args.player.args.pet.args.layout.args.health)
assert(not opts.args.target.args.targettarget.args.layout.args.health)
assert(not opts.args.focus.args.focustarget.args.layout.args.health)
assert(not opts.args.boss.args.bossinfo)
local bossNoteFound=false
local function FindBossNote(group)
 for _,option in pairs(group.args or {}) do
  if option.type=='group' then FindBossNote(option)
  elseif option.type=='description' and type(option.name)=='string' and option.name:find('Boss 1-5 share',1,true) then bossNoteFound=true end
 end
end
FindBossNote(opts.args.boss.args.layout);assert(bossNoteFound)
local player=ns.UnitFrames:GetConfigUnit('player')
local height=opts.args.player.args.layout.args.size.args.height
height.set(nil,47);assert(player.height==47)
local health=opts.args.player.args.text.args.health.args
player.text.healthUseCustomTypography=true
health.fontSize.set(nil,23);assert(player.text.sizeHealth==23 and player.height==47)
player.useClassColor=false
health.resetSection.func();assert(player.height==47 and player.useClassColor==false)
local party=ns.Modules.PartyFrames.db.profile
party.height=61;party.powerHeight=12;party.healthTexture='custom';party.colors.healthMissing={.1,.2,.3,.4}
opts.args.party.args.text.args.health.args.resetSection.func()
assert(party.height==61 and party.healthTexture=='custom' and party.colors.healthMissing[1]==.1)
opts.args.party.args.text.args.power.args.resetSection.func();assert(party.powerHeight==12)
''')
lua.execute("""
local opts=providers.unitframes():GetOptions()
ns.OptionsSchema.Apply(opts,'unitframes')
local player=ns.UnitFrames:GetConfigUnit('player')
local reset=opts.args.player.args.layout.args.core.args.reset
assert(reset.name=='Reset layout and core settings' and reset.confirm==true)
assert(reset.confirmText:find('resting',1,true) and reset.confirmText:find('stay unchanged',1,true))
player.width=333;player.text.sizeHealth=27;player.useClassColor=false
local text=player.text
reset.func()
assert(player.width==ns.UFDefaults.Player.player.width and player.text==text)
assert(player.text.sizeHealth==27 and player.useClassColor==false)
local prompts,reloads=0,0
function ns.Addon:PUI_ConfirmAction(options) prompts=prompts+1;prompt=options end
function ReloadUI() reloads=reloads+1 end
for _,family in ipairs({'party','raid'}) do
 local owner=ns.Modules[family=='party' and 'PartyFrames' or 'RaidFrames']
 local db=owner.db.profile
 local defaults=(family=='party' and ns.UFDefaults.GetPartyDefaults() or ns.UFDefaults.GetRaidDefaults()).profile
 db.enabled=defaults.enabled;db.hideBlizzard=defaults.hideBlizzard;db.showPlayer=defaults.showPlayer
 db.width=defaults.width+17
 local text,auras,range=db.text,db.auras,db.range
 local reset=opts.args[family].args.layout.args.core.args.reset
 assert(reset.confirm==false and reset.name=='Reset layout and core settings')
 local count=prompts
 reset.func()
 assert(prompts==count+1 and prompt.yesText=='Reset' and db.width==defaults.width+17)
 assert(not prompt.text:find('reload the UI',1,true))
 prompt.onYes()
 assert(prompts==count+1 and db.width==defaults.width and reloads==0)
 assert(db.text==text and db.auras==auras and db.range==range)
 db.enabled=not defaults.enabled
 count=prompts
 reset.func()
 assert(prompts==count+1 and prompt.yesText=='Reset + Reload')
 assert(prompt.text:find('reload the UI',1,true) and db.enabled~=defaults.enabled)
 TEST_COMBAT=true;prompt.onYes()
 assert(db.enabled~=defaults.enabled and reloads==0)
 TEST_COMBAT=false;prompt.onYes()
 assert(db.enabled==defaults.enabled and reloads==1)
 reloads=0
end
""")
print('Actual Unit Frames: reset scope, single confirmation, conditional reload and combat protection passed.')

lua.execute("""
ns.UFAuraFilters={NormalizeDisplays=function() end,NormalizeDisplay=function() end,
 BuildEffectiveAppearance=function() return {borderSize=2,durationTextSize=11,stackTextSize=12,tooltips=true} end}
C_Timer.NewTimer=function(_,callback) callback();return {Cancel=function() end} end
local display={id=100,displayType='group',auraType='HELPFUL',appearanceOverrides={}}
local auras={customDisplays={[100]=display}}
local args=captured.UFCB_BuildCustomAuraDisplaysArgs(function() return auras end,function() end,100,nil,'player')
local opts={type='group',name='Auras',args=args}
ns.OptionsSchema.Apply(opts,'unitframes')
local advanced=args.advanced.args
assert(not advanced.appearance)
for _,key in ipairs({'duration','stacks','border','tooltips','swipe','countdown'}) do
 local group=advanced[key]
 assert(group.inline and group.args.value.relWidth==.5 and group.args.override.relWidth==.5)
 assert(group.args.value.order<group.args.override.order)
end
local border=advanced.border.args
assert(border.value.disabled())
border.override.set(nil,true);assert(not border.value.disabled())
border.value.set(nil,4);assert(display.appearanceOverrides.borderSize==4)
border.override.set(nil,false);assert(border.value.disabled() and display.appearanceOverrides.borderSize==nil)
assert(advanced.sorting.args.sortMethod.relWidth==.5 and advanced.sorting.args.sortDirection.relWidth==.5)
""")
print('Actual aura Advanced builder: six paired rows and inherited override behavior passed.')

load('Modules/UnitFrames/Castbar/PUI_UF_CastBar_Defaults.lua')
lua.execute("ns.Modules.CastBar.db.profile=copy(ns.Modules.CastBar.defaults.profile);function ns.Modules.CastBar:GetUnitConfig(key) return self.db.profile[key] end;function ns.Modules.CastBar:RefreshPlayerSpellcastEvents() end")
lua.execute("""
for _,unit in ipairs({'player','target','focus','boss','pet'}) do
 local args=captured.UFCB_BuildCastbarArgs(unit)
 local opts={type='group',name='Castbar',args=args}
 ns.OptionsSchema.Apply(opts,'unitframes');checkInline(opts);checkCompact(opts)
 assert(args.appearance.args.showIcon and args.appearance.args.showPingOverlay)
 assert(not args.appearance.args.backgroundColor and not args.bar.args.puiStyle_background)
 assert(args.bar.args.texture.order<args.bar.args.color.order and args.bar.args.color.order<args.bar.args.backgroundColor.order)
 assert(args.spellName.args.showName.relWidth==.5 and not args.spellName.args.sharedFontInfo)
 assert(args.border.args.color and args.border.args.thickness.relWidth==.5)
 args.border.args.color.set(nil,.2,.3,.4,.7)
 local r,g,b,a=args.border.args.color.get();assert(r==.2 and g==.3 and b==.4 and a==.7)
 TEST_COMBAT=true;args.border.args.color.set(nil,1,1,1,1);TEST_COMBAT=false
 assert(ns.Modules.CastBar.db.profile[unit].borderColor[1]==.2)
 assert(args.empowerStageColors)
 if unit=='player' then
  local instant=args.instantCast.args
  assert(not instant.instantCastHelp and not instant.puiStyle_instantCast and not instant.puiStyle_instantOverlay)
  instant.instantCastAlpha.set(nil,.8);instant.instantCastOverlayAlpha.set(nil,.2)
  assert(instant.instantCastAlpha.get()==.8 and instant.instantCastOverlayAlpha.get()==.2)
  instant.instantCastUseOverlay.set(nil,false)
  assert(instant.instantCastOverlayTexture.disabled() and not instant.instantCastTexture.disabled())
  instant.instantCastTexture.set(nil,'Base');instant.instantCastUseOverlay.set(nil,true)
  instant.instantCastOverlayTexture.set(nil,'Overlay')
  assert(instant.instantCastTexture.get()=='Base' and instant.instantCastOverlayTexture.get()=='Overlay')
 end
 args.feature.args.reset.func()
 assert(ns.Modules.CastBar.db.profile[unit].borderColor[1]==0)
end
""")
print('Actual castbar builder: compact rows, all unit colors, reset/combat protection and independent instant layers passed.')

lua.execute("""
ns.Pixel={Round=function(v) return v end,GetOnePixel=function() return 1 end}
local methods={}
function methods:SetBackdropBorderColor(...) self.color={...} end
function methods:GetFrameStrata() return 'HIGH' end
function methods:GetFrameLevel() return 1 end
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:SetBackdrop(v) self.backdrop=v end
for _,key in ipairs({'SetFrameStrata','SetFrameLevel','ClearAllPoints','SetPoint'}) do methods[key]=function() end end
local meta={__index=methods}
function CreateFrame() return setmetatable({},meta) end
borderHost=setmetatable({},meta)
""")
load('Modules/UnitFrames/Castbar/PUI_UF_CastBar_Construct.lua')
lua.execute("""
local cfg={borderSize=2,borderColor={.2,.3,.4,.7}}
local border=ns.Modules.CastBar.GetBorder(borderHost,cfg)
assert(border.shown and border.color[1]==.2 and border.color[4]==.7)
cfg.borderColor={.9,.8,.7,.6};assert(ns.Modules.CastBar.GetBorder(borderHost,cfg)==border)
assert(border.color[1]==.9 and border.color[4]==.6)
cfg.borderSize=0;ns.Modules.CastBar.GetBorder(borderHost,cfg);assert(not border.shown)
""")
print('Castbar border renderer: saved RGBA updates in place and zero thickness hides the border.')

lua.execute('''
ns.ActionBarsCore={db={skin={},bars={},overrides={},ui={}},GetDB=function(self) return self.db end,
InvalidateCaches=function() end, InvalidateBarCache=function() end,
GetEffectiveSkin=function(self,key) return self.db.skin end,GetSpecialSkin=function(self,key) return self.db.skin end}
ns.ActionBarsPreview={Refresh=function() end}
''')
load('Modules/ActionBars/ActionBars_config.lua')
lua.execute('''
local opts=providers.ACTIONBARS(ns.Addon):GetOptions()
ns.OptionsSchema.Apply(opts,'ACTIONBARS');checkInline(opts);checkCompact(opts)
local shared=opts.args.general.args.visibility.args.visibilityGroup.args.alpha
shared.set({},.35);assert(ns.ActionBarsCore.db.skin.alpha==.35 and shared.get({})==.35 and shared.isPercent)
assert(opts.args['1'].args.visibility.args.group.args.alpha.get({})==.35)
assert(opts.args['1'].args.general.args.group.args.resetShared.confirm)
for _,key in ipairs({'general','1','12'}) do
 local page=opts.args[key].args
 assert(page.general and page.layout and page.visibility)
 assert(page.layout.name=='Layout and appearance' and not page.appearance and not page.behavior)
 assert(page.layout.args.buttonAppearance.name=='Button border')
 assert(page.layout.args.buttonAppearance.args.borderColor.name=='Color')
end
for bar=1,12 do
 local page=opts.args[tostring(bar)].args
 assert(not page.advanced and page.general.args.actionSlots.inline)
 local slots=page.general.args.actionSlots.args
 slots.buttonOffset.set({},3)
 assert(ns.ActionBarsCore.db.bars[tostring(bar)].buttonOffset==3)
 assert(slots.slotOrder.name():find('4',1,true))
end
for _,key in ipairs({'pet','stance'}) do
 local page=opts.args.special.args[key].args
 assert(page.general and page.layout and page.text)
end
''')
print('Actual Action Bars builder: shared, numbered, pet, and stance sections and mandatory headings passed.')

lua.execute('''
ns.Modules.DamageMeters={db={profile={windowCount=1}}}
ns.DamageMeterConfig={};ns.DamageMeterBreakdown={};ns.DamageMeterHistory={}
ns.DamageMeterConstants={MAX_WINDOWS=10,BREAKDOWN_ROW_POOL_SIZE=50,METER_TYPES={},SESSION_TYPES={}}
ns.DamageMeterProfiler={Def=function(_,name,fn) return fn end}
ns.DamageMeterUtil={Clamp=function(v,a,b) return math.min(b,math.max(a,v)) end}
ns.Pixel={Round=function(v) return v end}
''')
load('Modules/PUIModules/DamageMeter/PUI_DamageMeterConfig.lua')
lua.execute('''
local owner=ns.Modules.DamageMeters
owner.db=copy(ns.DamageMeterConfig.DEFAULTS)
local opts=owner:GetOptions();ns.OptionsSchema.Apply(opts,'DamageMeters');checkInline(opts)
assert(opts.args.general and opts.args.layout and opts.args.windows)
assert(opts.args.layout.args.bar.args.fontSize.name=='Font size')
assert(opts.args.windows.args.window1.args.puiControls.args.delete.confirm)
''')
print('Actual Damage Meter builder: sections, ten dynamic windows, hidden state, and typography passed.')

load('Modules/PCM/PUI_PCM_Options.lua')
lua.execute('''
local disabled=true
local source={fonts={type='group',name='Fonts',disabled=function() return disabled end,args={
 cooldownFontSize={type='range',name='Cooldown font size',get=function() return 18 end},
 cooldownFont={type='select',name='Cooldown font',values={global='Global'}},cooldownOutline={type='select',name='Cooldown font outline',values={OUTLINE='Outline'}},
 chargeFontSize={type='range',name='Charge font size'},keybindFontSize={type='range',name='Keybind font size'},
}}}
local sections=ns.PCMOptions:BuildSections(source)
local opts={type='group',name='Tracker',args=sections};ns.OptionsSchema.Apply(opts,'CooldownManager');checkInline(opts)
local countdown=sections.text.args.cooldown.args
assert(countdown.fonts_cooldownFontSize.name=='Font size')
assert(countdown.fonts_cooldownFontSize.disabled()==true)
disabled=false;assert(countdown.fonts_cooldownFontSize.disabled()==false)
assert(countdown.fonts_cooldownFont.order<countdown.fonts_cooldownFontSize.order)
''')
lua.execute("""
local changed
local function toggle(name) return {type='toggle',name=name,get=function() return false end,
 set=function(_,value) changed=value end} end
local source={
 forceCooldown=toggle('Enable duration timer'),cooldownTimerEnabled=toggle('Enable cooldown timer'),
 showTooltips=toggle('Show tooltips'),desaturateCooldown=toggle('Desaturation'),
 showCountdown=toggle('Show countdown'),countCharge=toggle('Show charges'),keybindShow=toggle('Show keybinds'),
 size={type='range',name='Icon size'},spacing={type='range',name='Spacing'},columns={type='range',name='Icons per row'},
}
local sections=ns.PCMOptions:BuildSections(source)
local opts={type='group',name='Tracker',args=sections}
ns.OptionsSchema.Apply(opts,'CooldownManager');checkInline(opts)
assert(sections.general.args.quickTimers.name=='Timers')
local function collect(group,result)
 for key,option in pairs(group.args or {}) do
  if option.type=='group' then collect(option,result) else result[key]=option end
 end
 return result
end
local quick=collect(sections.general,{})
assert(quick.forceCooldown and quick.cooldownTimerEnabled and quick.showTooltips and quick.desaturateCooldown)
assert(not quick.size and not quick.spacing and not quick.columns)
assert(not quick.showCountdown and not quick.countCharge and not quick.keybindShow)
quick.forceCooldown.set(nil,true);assert(changed==true)
local text=collect(sections.text,{})
local layout=collect(sections.layout,{})
assert(text.showCountdown and text.countCharge and text.keybindShow)
assert(layout.size and layout.spacing and layout.columns)
""")
lua.execute("""
local source={}
for _,prefix in ipairs({'duration','cooldown','gcd'}) do
 for _,suffix in ipairs({'SwipeColor','SwipeEdge','SwipeEdgeColor'}) do
  source[prefix..suffix]={type=suffix=='SwipeEdge' and 'toggle' or 'color',name=prefix..suffix}
 end
end
for _,key in ipairs({'forceCooldown','cooldownTimerEnabled','countDuration','countCooldown','swipeDuration','swipeCooldown','swipeGCD'}) do
 source[key]={type='toggle',name=key}
end
local sections=ns.PCMOptions:BuildSections(source)
local before={}
for groupKey,group in pairs(sections.timer.args) do
 before[groupKey]={}
 for key,option in pairs(group.args) do
  before[groupKey][key]={order=option.order,width=option.width,relWidth=option.relWidth}
 end
end
local opts={type='group',name='Timers',args=sections}
ns.OptionsSchema.Apply(opts,'CooldownManager');checkInline(opts)
for groupKey,group in pairs(sections.timer.args) do
 for key,option in pairs(group.args) do
  local original=before[groupKey][key]
  assert(original and option.order==original.order and option.width==original.width and option.relWidth==original.relWidth,
   'Timer row changed: '..groupKey..'/'..key)
 end
end
assert(sections.timer.args.durationTimer.args.forceCooldown.relWidth==.5)
assert(sections.timer.args.durationTimer.args.durationSwipeEdge.order==5)
assert(sections.timer.args.cooldownTimer.args.cooldownSwipeEdge.order==5)
assert(sections.timer.args.gcdTimer.args.gcdSwipeEdge.order==5)
""")
lua.execute("""
local deleted=0
local sections=ns.PCMOptions:BuildSections({
 deleteBar={type='execute',name='Delete tracker',confirm=true,confirmText='Delete this tracker and its saved settings?',
 func=function() deleted=deleted+1 end}
},{customTracker=true})
local actions=sections.general.args.actions.args
assert(actions.deleteBar.confirm==true and actions.deleteBar.confirmText=='Delete this tracker and its saved settings?')
assert(deleted==0)
actions.deleteBar.func();assert(deleted==1)
""")
print('PCM section builder: concise quick settings, preserved callbacks, confirmation metadata and timer-row ordering passed.')


lua.execute('''
Addon=ns.Addon;Theme=ns.Theme;OptionsUtil=ns.OptionsUtil;FrameUtil=ns.FrameUtil
Theme.OptionsUIScaleRange={min=.7,max=1.5,step=.05};Theme.OptionsFontSizeRange={min=8,max=20,step=1}
Theme.FontSizeOffsetRange={min=-5,max=10,step=1}
Theme.ColorPresetOrder={'default'};Theme.GetColorPresetLabel=function() return 'Default' end
''')
for name in ['_PUI_ThemeRegistry_CopyArgsWithoutHeader','PUI_THEME_COLOR_OPTIONS','PUI_ThemeColorOption','ThemeColorsProvider','ThemeFontsProvider','UIThemeOptionsProvider']:
    lua.execute(builders[name])
lua.execute('''
local opts=UIThemeOptionsProvider():GetOptions();ns.OptionsSchema.Apply(opts,'UITHEME');checkInline(opts)
assert(opts.childGroups=='tab' and opts.args.general and opts.args.layout and not opts.args.colors and not opts.args.text)
local tabs=0;for _ in pairs(opts.args) do tabs=tabs+1 end;assert(tabs==2)
assert(opts.args.layout.args.text.args.font.name=='Font')
assert(opts.args.layout.args.colors.inline and opts.args.layout.args.text.inline)
assert(opts.args.layout.args.window.order<opts.args.layout.args.colors.order)
assert(opts.args.layout.args.colors.order<opts.args.layout.args.text.order)
assert(opts.args.layout.args.window.args.fontSize.name=='Font size')
checkCompact(opts)
local savedFont
Theme.GetOptionsFontSize=function() return savedFont end
Theme.SetOptionsFontSize=function(value) savedFont=value end
opts.args.layout.args.window.args.fontSize.set(nil,16)
assert(opts.args.layout.args.window.args.fontSize.get()==16)
assert(opts.args.layout.args.window.args.optionsUIScale.name=='Scale')
''')
print('Actual UI Theme provider: named sections, global typography, options text, and mandatory headings passed.')

lua.execute('''
TEST_CLASS='MAGE';function UnitClass() return TEST_CLASS,TEST_CLASS end
ns.Addon.db={profile={}};ns.Flags={IsEditing=false};pluginCount=0;frameCount=0
function CreateFrame() frameCount=frameCount+1;error('A frame was created during this test') end
C_Secrets={ShouldAurasBeSecret=function() return false end}
C_Spell={};C_SpellBook={IsSpellKnown=function() return false end};Enum={SpellBookSpellBank={Player=1}}
PleebUIAPI={RegisterPlugin=function()
 pluginCount=pluginCount+1;return {RegisterEditModeParticipant=function() end}
end}
function ns.Addon:NewModule()
 return {SetEnabledState=function(self,v) self.enabledState=v end,RegisterEvent=function() end,UnregisterAllEvents=function() end}
end
''')
load('Modules/PUIModules/PUI_HunterTools.lua')
lua.execute('''
local owner=ns.Modules.HunterTools
owner:OnInitialize();owner:ApplySettings();owner:OnEditModeChanged(true);owner:RefreshFonts()
assert(owner.enabledState==false and ns.Addon.db.profile.hunterTools==nil and pluginCount==0 and frameCount==0)
assert(providers.HunterTools==nil)
TEST_CLASS='HUNTER';owner:OnInitialize();assert(pluginCount==1)
local opts=owner:GetOptions();ns.OptionsSchema.Apply(opts,'Quality');checkInline(opts)
opts.args.warning.args.fontSize.set(nil,54)
assert(ns.Addon.db.profile.hunterTools.emergencySalveFontSize==54 and frameCount==0)
''')
print('Actual Hunter module: non-Hunter initialization, events/frames/profile gating, moved options, and preserved settings passed.')

lua.execute('''
Quality={GetQuickSetupValue=function(_,key) return qualityDB[key] end,SetQuickSetupValue=function(_,key,value) qualityDB[key]=value;return qualityDB end,
IsPetWarningAvailable=function() return true end}
qualityDB={};function NormalizeDB() return qualityDB end
function Quality_RefreshPreview() end
function Clamp(v,a,b) return math.min(b,math.max(a,v)) end
function IsPetClass() return TEST_CLASS=='HUNTER' end
function IsHealPetClass() return false end
ns.RaidUtilityModule={BuildBresLustOptions=function(ctx) return {type='group',name='Battle resurrection and bloodlust',inline=true,args={general={args={bresWidgetEnable=ctx.ToggleOption('Battle resurrection','bresWidgetEnable',1),lustWidgetEnable=ctx.ToggleOption('Bloodlust','lustWidgetEnable',2),bresLustWidgetShowOnlyInGroup=ctx.ToggleOption('Show only in group','bresLustWidgetShowOnlyInGroup',3)}},layout={args={bresLustWidgetIconSize=ctx.RangeOption('Icon size','bresLustWidgetIconSize',16,64,1,1)}}}} end,
BuildRaidUtilityOptions=function() return {type='group',name='Raid utility',inline=true,args={buttons={type='group',name='Ready',inline=true,args={}},raidMarkers={type='group',name='Targets',inline=true,args={}},worldMarkers={type='group',name='World',inline=true,args={}},general={type='group',name='General',inline=true,args={}}}} end}
''')
lua.execute(builders['QualityProvider'])
lua.execute('Module={};POSITION_DEFAULTS={}')
for name in ['RAID_UTILITY_WINDOW_SPECS','Module.BuildBresLustOptions','Module.BuildRaidUtilityOptions']:
    lua.execute(builders[name])
lua.execute('ns.RaidUtilityModule=Module')
lua.execute('''
for _,class in ipairs({'HUNTER','MAGE'}) do
 TEST_CLASS=class
 local opts=QualityProvider(ns.Addon):GetOptions();ns.OptionsSchema.Apply(opts,'Quality');checkInline(opts)
 assert((opts.args.combatTab.args.emergencySalve~=nil)==(class=='HUNTER'),'Hunter visibility '..class..' '..tostring(opts.args.combatTab.args.emergencySalve))
 local bres=opts.args.groupTab.args.battleResLust.args
 qualityDB.bresLustWidgetIconSize=37;qualityDB.bresLustWidgetShowOnlyInGroup=true
 for _,showBres in ipairs({false,true}) do
  for _,showLust in ipairs({false,true}) do
   bres.bresWidgetEnable.set(nil,showBres);bres.lustWidgetEnable.set(nil,showLust)
   assert(bres.bresLustWidgetIconSize.disabled()==(not showBres and not showLust))
   assert(bres.bresLustWidgetShowOnlyInGroup.disabled()==(not showBres and not showLust))
   assert(bres.bresLustWidgetIconSize.get()==37 and bres.bresLustWidgetShowOnlyInGroup.get()==true)
  end
 end
 local status={message=opts.args.combatTab.args.combatMessages,timer=opts.args.combatTab.args.combatTimer}
 assert(status.message.args.fontSize.name=='Font size' and status.timer.args.showText.name=='Show text')
 local ring={inner=opts.args.cursorTab.args.innerRing,click=opts.args.cursorTab.args.clickRing}
 assert(ring.inner.args.size.name=='Size' and ring.click.args.color.name=='Color')
 assert(ring.click.args.size.name=='Extra size')
 for _,inner in ipairs({false,true}) do
  for _,click in ipairs({false,true}) do
   ring.inner.args.shown.set(nil,inner);ring.click.args.shown.set(nil,click)
   assert(ring.inner.args.size.disabled()==(not inner and not click))
   assert(ring.inner.args.color.disabled()==not inner)
   assert(ring.click.args.size.disabled()==not click and ring.click.args.color.disabled()==not click)
  end
 end
 local pets=opts.args.combatTab.args.petWarnings.args
 assert(not pets.missingPet and pets.missing and pets.dead and pets.missingPetWarning)
 assert(pets.missing.hidden()==(class~='HUNTER') and pets.dead.hidden()==(class~='HUNTER'))
 assert(pets.missingPetWarning.hidden()==(class~='HUNTER'))
 assert(pets.missing.args.fontSize.name=='Font size' and pets.dead.args.textColor.name=='Text color')
 assert(not opts.args.combatTab.args.preview)
 assert(opts.args.groupTab.args.battleResLust.order==20)
 assert(opts.args.groupTab.args.general.order<opts.args.groupTab.args.battleResLust.order)
 for _,key in ipairs({'buttons','raidMarkers','worldMarkers'}) do
  local group=opts.args.groupTab.args[key]
  assert(group.order>opts.args.groupTab.args.battleResLust.order)
  for _,control in pairs(group.args) do
   if control~=group.args.enabled then assert(group.args.enabled.order<control.order) end
  end
 end
 local invites=opts.args.automationTab.args.invites.args
 qualityDB.autoAcceptInvites=true;qualityDB.acceptInviteFriends=true
 invites.acceptInviteEveryone.set(nil,true)
 assert(qualityDB.acceptInviteEveryone and invites.acceptInviteFriends.disabled())
 assert(qualityDB.acceptInviteFriends)
 invites.acceptInviteEveryone.set(nil,false)
 assert(not invites.acceptInviteFriends.disabled() and qualityDB.acceptInviteFriends)
 qualityDB.autoAcceptInvites=false
 assert(invites.acceptInviteEveryone.disabled() and invites.acceptInviteFriends.disabled())
 assert(not opts.args.automationTab.args.loot.args.autoLoot)
end
''')
print('Actual Quality provider: Hunter-only Emergency Salve, role groups, cursor groups, and mandatory headings passed.')

lua.execute('''
PRD={GetQuickSetupValue=function() return true end,SetQuickSetupValue=function() end}
ns.PRDSecondary={PlayerClassHasAlternatePower=false}
function PRD_NormalizeNativeTextConfig() end
function PRD_UseGlobalFont(t) return t.useGlobalFont==true end
''')
for name in ['PRD_BuildNativeTextGroup','PRD_ArrangePresentationArgs','PRD_ArrangeNativeBarArgs']:
    lua.execute(builders[name])
lua.execute('''
local callback=function() return 1 end
for _,role in ipairs({'health','primary'}) do
 local config={text={}}
 local args={layoutGroup={type='group',name='Layout',inline=true,args={
  height={type='range',name='Bar height',get=callback},width={type='range',name='Detached width'},
  texture={type='select',name='Texture',values={bar='Bar'}},squareTexture={type='toggle',name='Square texture'}}},
  colorGroup={type='group',name='Colors',inline=true,args={colorMode={type='select',name='Color mode',values={custom='Custom'}}}},
  styleGroup={type='group',name='Frame style',inline=true,args={
   borderSize={type='range',name='Border size',order=1,get=callback},borderColor={type='color',name='Border color',order=2},
   bgColor={type='color',name='Background color',order=3}}},textGroup=PRD_BuildNativeTextGroup({},role,config.text)}
 local state={db={[role]=config}}
 args=PRD_ArrangeNativeBarArgs(args,state,role)
 local opts={type='group',name=role,args=args};ns.OptionsSchema.Apply(opts,'PRD');checkInline(opts);checkCompact(opts)
 assert(not args.general and not args.layoutAppearance and args.textGroup.inline and args.layoutGroup.inline)
 assert(args.border.args.borderSize.name=='Thickness')
 assert(args.border.args.borderSize.get==callback)
 assert(args.textAppearance.args.fontSize.name=='Font size')
 assert(args.textGroup.args.percentVisibility.name=='Percent visibility')
end
''')
print('Current PRD presentation builders: bar/style ownership, typography roles, and callback preservation passed.')

lua.execute(builders['defaults'])
lua.execute("""
local originalDropIn=ns.Pleebug.DropIn
ns.Pleebug.DropIn=function() return {Def=function(_,name,fn) captured[name]=fn;return fn end} end
prdTestResources={}
ns.Modules.PRD={db={profile=copy(defaults.profile)},
 GetPrimaryResourceSettings=function(self) return self:EnsurePrimaryResourceSettings('FOCUS') end,
 GetPrimaryResourceKey=function() return 'FOCUS' end,
 GetPrimaryTickMaximum=function() return 100 end,
 GetPrimaryResourceMaximum=function() return 100 end,
 SetUsePlayerHealth=function(self,value) self.db.profile.usePlayerHealth=value end,
 IsSecondaryResourceEnabled=function(self,key) return self.db.profile.secondary.resourceEnabled[key]~=false end,
 SetSecondaryResourceEnabled=function(self,key,value) self.db.profile.secondary.resourceEnabled[key]=value end}
ns.PRDSecondary={PlayerClassHasAlternatePower=false,
 GetResourceOptionsForClass=function() return prdTestResources end,
 HasResourceForCurrentSpec=function() return #prdTestResources>0 end,
 ResourceSupportsNumericCues=function() return true end,
 GetApplicationCountdownMax=function() return nil end,
 ResourceSupportsStackColorShifts=function() return false end,
 GetResourceSettings=function(_,db,key)
  local config=db.secondary.resourceSettings[key]
  if not config then
   config={height=15,width=240,texture='Pleebar',anchor={},style=copy(db.secondary.style),text={size=14,flags=''},behavior={},cues={}}
   db.secondary.resourceSettings[key]=config
  end
  return config
 end}
""")
load('Modules/PRD/PUI_PRD_Config.lua')
lua.execute("""
local function checkFlat(args)
 assert(not args.layoutAppearance and not args.general)
 for _,option in pairs(args) do if option.type=='group' then assert(option.inline and option.childGroups~='tab') end end
end
for _,resources in ipairs({{},{{key='COMBO_POINTS',name='Combo points',category='RESOURCE'}},
 {{key='RUNES',name='Runes',category='RESOURCE'},{key='TEST_EFFECT',name='Tracked effect',category='TRACKED_EFFECT'}}}) do
 prdTestResources=resources
 local opts=providers.PRD():GetOptions();ns.OptionsSchema.Apply(opts,'PRD');checkInline(opts)
 assert(not opts.args.general and opts.args.health.order==1 and opts.args.primary.order==2)
 for _,role in ipairs({'health','primary'}) do
  local page=opts.args[role];assert(not page.childGroups)
  local args=page.args;checkFlat(args)
  assert(args.feature.args.enabled.name=='Enable')
  local size=args.layoutGroup.args
  assert(size.height.order<size.detached.order and size.detached.order<size.width.order)
  assert(size.height.relWidth==.333 and size.detached.relWidth==.333 and size.width.relWidth==.333)
  assert(size.width.disabled());size.detached.set(nil,true);assert(not size.width.disabled());size.detached.set(nil,false)
  local bar=args.bar.args
  assert(bar.texture and bar.colorMode and bar.customColor and bar.bgColor)
  assert(not bar.puiStyle_background and not args.puiStyle_bar)
  for _,mode in ipairs({'DEFAULT','CLASS','CUSTOM','TEXTURE'}) do
   bar.colorMode.set(nil,mode);assert(bar.colorMode.get()==mode)
   assert(bar.customColor.disabled()==(mode~='CUSTOM'))
   assert(ns.Modules.PRD.db.profile[role].colorMode==mode)
  end
  bar.customColor.set(nil,.1,.2,.3,.4);assert(ns.Modules.PRD.db.profile[role].customColor[4]==.4)
  bar.bgColor.set(nil,.4,.3,.2,.1);assert(ns.Modules.PRD.db.profile[role].style.bgColor[4]==.1)
  args.feature.args.enabled.set(nil,false);assert(not args.feature.args.enabled.get())
  args.feature.args.enabled.set(nil,true);assert(args.feature.args.enabled.get())
  args.textGroup.args.percentVisibility.set(nil,'MOUSEOVER')
  assert(args.textGroup.args.percentVisibility.get()=='MOUSEOVER')
 end
 local health=opts.args.health.args
 assert(health.sharedStack and health.outerBorderGroup and health.appearanceCopyGroup)
 health.feature.args.usePlayerHealth.set(nil,true);assert(ns.Modules.PRD.db.profile.usePlayerHealth)
 TEST_COMBAT=true;assert(health.feature.args.usePlayerHealth.disabled());TEST_COMBAT=false
 health.sharedStack.args.width.set(nil,330);assert(ns.Modules.PRD.db.profile.size.width==330)
 if #resources>0 then
  local secondary=opts.args.secondary.args
  local shared=secondary.shared.args
  shared.enabled.set(nil,false);assert(shared.visibility.disabled())
  shared.enabled.set(nil,true);assert(not shared.visibility.disabled())
  shared.visibility.set(nil,'COMBAT');shared.spacing.set(nil,7)
  assert(ns.Modules.PRD.db.profile.secondary.visibilityMode=='COMBAT' and ns.Modules.PRD.db.profile.secondary.gap==7)
  for _,resource in ipairs(resources) do
   local args=#resources>1 and secondary[resource.key].args or secondary
   if #resources>1 then assert(not secondary[resource.key].childGroups) end
   checkFlat(args)
   assert(args.bar.args.bgColor and args.bar.args.customColor and args.feature.args.enabled.name=='Enable')
   assert(args.layout.args.height.relWidth==.333 and args.layout.args.detached.relWidth==.333)
   assert(args.textGroup.inline)
  end
 end
end
""")
print('Actual PRD provider: three top tabs, flat bar pages, size/color rows, moved settings and resource variants passed.')

for name in ['PRDPreview_ConfigureBarInteractions','PRDPreview_GetResourcePath','PRDPreview_Navigate','PRDPreview_SetBarHovered','PRD_HasMultipleSecondaryResources']:
    lua.execute(builders[name])
lua.execute("""
local function interaction() return {SetPreviewInteractionOptions=function(self,options) self.options=options end} end
local function verifyPreview(opts,role,definition)
 local bar={frame={},interactions={body=interaction(),leftText=interaction(),rightText=interaction(),centerText=interaction(),borders={interaction()}}}
 PRDPreview_ConfigureBarInteractions({},bar,role,nil,definition,{})
 ns.PreviewBox={NavigateToOption=function(_,path,section,option)
  assert(path[1]=='PRD' and path[2]~='general')
  local node=opts
  for i=2,#path do node=node.args[path[i]];assert(node,'Missing preview destination') end
  assert(node.args[section] and node.args[section].args[option],'Missing preview focus '..tostring(section)..'/'..tostring(option))
 end}
 bar.interactions.body.options.onClick();bar.interactions.leftText.options.onClick();bar.interactions.borders[1].options.onClick()
end
prdTestResources={{key='COMBO_POINTS',name='Combo points',category='RESOURCE'}}
local opts=providers.PRD():GetOptions();ns.OptionsSchema.Apply(opts,'PRD')
verifyPreview(opts,'health');verifyPreview(opts,'primary')
verifyPreview(opts,'secondary',{resourceKey='COMBO_POINTS'})
prdTestResources={{key='RUNES',name='Runes',category='RESOURCE'},{key='ESSENCE',name='Essence',category='RESOURCE'}}
opts=providers.PRD():GetOptions();ns.OptionsSchema.Apply(opts,'PRD')
verifyPreview(opts,'secondary',{resourceKey='RUNES'})
ns.PRDSecondary.PlayerClassHasAlternatePower=true
opts=providers.PRD():GetOptions();ns.OptionsSchema.Apply(opts,'PRD')
verifyPreview(opts,'secondary',{isAlternatePower=true,resourceKey='ALTERNATE_MANA'})
""")
print('PRD preview clicks reach flat bar, text, border and Alternate Mana controls for single/multiple resources.')

lua.execute("""
function UnitClass() return 'Druid','DRUID' end
function ns.Modules.PRD:NormalizeDruidFormPrimary(config) return config end
""")
load('Modules/PRD/PUI_PRD_Config.lua')
lua.execute("""
local opts=providers.PRD():GetOptions();ns.OptionsSchema.Apply(opts,'PRD');checkInline(opts)
assert(not opts.args.primary.childGroups and not opts.args.primary.args.formOverridesGroup)
for _,form in ipairs({'CASTER','MOONKIN','CAT','BEAR'}) do
 local group=opts.args.primary.args['form'..form]
 assert(group.inline and not group.childGroups)
 group.args.colorMode.set(nil,'CLASS')
 assert(ns.Modules.PRD.db.profile.class.DRUID.forms[form].primary.colorMode=='CLASS')
end
""")
print('Druid form color overrides remain editable inline without introducing subtabs.')


# Compile production Lua, including files whose runtime requires the WoW client.
for folder in ('Core', 'Modules'):
    for file in (root/folder).rglob('*.lua'):
        lua.execute('local source,name=...; local fn,err=loadstring(source,name); assert(fn,err)',
                    file.read_text(encoding='utf-8-sig'), str(file))

lua.execute("""
local notice={type='description',name='Unavailable in combat',order=-10,hidden=function() return true end}
local notices={type='group',name='Text',arg={puiExplicit=true},args={
 notice=notice,
 appearance={type='group',name='Appearance',inline=true,order=10,args={color={type='color',name='Text color'}}},
}}
ns.OptionsSchema.Apply(notices,'Example')
assert(not notices.args.puiControls and notices.args.appearance.args.notice==notice)
assert(notice.hidden())
local callback=function() return .35 end
local saved=.35
local source={args={layout={type='group',name='Layout',disabled=function() return true end,args={
 size={type='group',name='Size',args={width={type='range',name='Width',get=callback,
 set=function(_,value) saved=value end,disabled=function() return false end}}}
}}}}
local common=ns.OptionsSchema.BuildCommonSettings(source,{
 {path={'layout','size','width'},label='Frame width'}
})
assert(common.args.width.get==callback and common.args.width.disabled({})==true)
common.args.width.set({},.8);assert(saved==.8)
local options={type='group',name='Example',arg={puiExplicit=true},args={
 general={type='group',name='General',args={settings={type='group',name='Behaviour',inline=true,args={
 size={type='range',name='Font size',order=1},show={type='toggle',name='Show text',order=20},
 enable={type='toggle',name='Enable',order=40},hide={type='toggle',name='Hide in combat',order=1},
 opacity={type='range',name='Ready opacity',min=0,max=100,step=5,order=30,
 get=function() return 35 end,set=function(_,value) saved=value end},
 delete={type='execute',name='Delete window',order=2,confirm='Delete this window?'}
 }}}},
 layout={type='group',name='Layout and appearance',args={}}
}}
ns.OptionsSchema.Apply(options,'Example')
local controls=options.args.general.args.settings.args
assert(controls.show.order<controls.size.order and controls.delete.order>controls.opacity.order)
assert(controls.enable.order<controls.show.order and controls.enable.order<controls.hide.order)
assert(controls.opacity.max==1 and controls.opacity.isPercent and controls.opacity.get({})==.35)
controls.opacity.set({},.8);assert(saved==80)
assert(not options.args.general.args.puiCommonSettings)
assert(not controls.puiStyle_text)
local order=controls.show.order
ns.OptionsSchema.Apply(options,'Example');assert(controls.show.order==order)
assert(controls.enable.order<controls.show.order and controls.enable.order<controls.hide.order)

ns.PCMGroupManager={GetGroups=function() return {order={},byID={}} end}
local owner={};ns.Modules.CooldownManager=owner
owner.GetSpellBarsDB=function() return {[1]={label='Test',kind='cooldown'}} end
owner.GetCooldownStackBarsDB=function() return {} end
owner.IsSpellBarLoaded=function() return true end
owner.GetCustomBarDisplayName=function(_,config) return config.label end
owner.GetConsumableTrackerDefinitions=function() return {} end
ns.Modules.PCM_BB={GetStackBarsDB=function() return {} end}
ns.PCMOptions.GetSearchSections=function(kind)
 return {general={name='General'},visibility={name='Visibility and glow'},text={name='Text'}}
end
for _,entry in ipairs(ns.PCMOptions.GetSearchEntries()) do
 if entry.path[2]=='customTrackers' and #entry.path>3 then
  assert(entry.path[4]=='general' or entry.path[4]=='visibility' or entry.path[4]=='text')
 end
 assert(entry.path[#entry.path]~='glow')
end
""")
print('Schema ownership, curated callbacks/conditions, percentage round trips, toggle order, idempotence and PCM search destinations passed.')


lua.execute('''
Addon=ns.Addon;OptionsUtil=ns.OptionsUtil;Theme=ns.Theme
ChatLinks={db={profile={}},ChatHistoryTypes={CHAT='Chat'},ApplyCopyWindowStyle=function() end}
function date() return '12:00' end
function _PUI_GetTypographyDB() return {message={},tab={},input={}} end
function _PUI_GetChatConflictDB() return {} end
function _PUI_IsChattynatorLoaded() return false end
function _PUI_IsPratLoaded() return false end
function _PUI_GetHistoryTypeLabels() return {} end
function _PUI_GetHistoryTypeValues() return {} end
function _PUI_NormalizeHistoryTypeSelection() end
MinimapModule={db={profile={}}}; local sky={};function GetDB() return sky end
''')
for name in ['ChatProvider','MinimapProvider','DragonridingProvider']:lua.execute(builders[name])
lua.execute('''
local opts=ChatProvider(Addon):GetOptions();ns.OptionsSchema.Apply(opts,'Chat');checkInline(opts);checkCompact(opts)
assert(opts.childGroups=='tab' and opts.args.general and opts.args.appearance and opts.args.tools)
local n=0;for _ in pairs(opts.args) do n=n+1 end;assert(n==3)
assert(opts.args.general.args.features.args.scrollMessages and opts.args.general.args.history.args.persistHistory)
assert(opts.args.tools.args.copy.args.width and opts.args.tools.args.copy.args.height)
assert(opts.args.appearance.args.message.inline and opts.args.appearance.args.tab.inline and opts.args.appearance.args.input.inline)
local timestamps=opts.args.general.args.features.args.timestamps
local timestampFormat=opts.args.general.args.features.args.tsPreset
local originalFormat=timestampFormat.get()
ChatLinks.db.profile.chatFormat.timestamps=false;assert(not timestamps.get() and timestampFormat.disabled() and timestampFormat.get()==originalFormat)
ChatLinks.db.profile.chatFormat.timestamps=true;assert(timestamps.get() and not timestampFormat.disabled())
print('Chat: three tabs, preserved formatting/history/copy controls, and headings passed.')
local map=MinimapProvider(Addon):GetOptions();ns.OptionsSchema.Apply(map,'Minimap');checkInline(map);checkCompact(map)
assert(map.args.general.args.minimap.args.hideTracking and map.args.general.args.minimap.args.hideCalendar)
assert(map.args.topPanel.args.clock.args.hideClock and map.args.general.args.buttons.args.hide)
assert(map.args.topPanel.args.zone.args.hideZoneText.order<map.args.topPanel.args.zone.args.fontSize.order)
assert(map.args.topPanel.args.panel.args.clockBoxEnabled and map.args.general.args.minimap.args.clockBoxBorderSize)
local zone=map.args.topPanel.args.zone.args
MinimapModule.db.profile.clockBoxEnabled=true
MinimapModule.db.profile.hideZoneText=true;assert(zone.hideZoneText.get() and zone.fontSize.disabled())
MinimapModule.db.profile.hideZoneText=false;assert(not zone.hideZoneText.get() and not zone.fontSize.disabled())
MinimapModule.db.profile.clockBoxEnabled=false;assert(zone.fontSize.disabled())
print('Minimap: two tabs, existing hide settings exposed, panel toggle and shared border available.')
local sky=DragonridingProvider(Addon):GetOptions();ns.OptionsSchema.Apply(sky,'Dragonriding');checkInline(sky);checkCompact(sky)
assert(sky.args.general.args.swEnabled and sky.args.general.args.wsEnabled)
assert(sky.args.vigor.args.width and sky.args.vigor.args.barColor)
assert(sky.args.secondary.args.wsColor and sky.args.secondary.args.swGap)
local skyDB=GetDB()
skyDB.showSegments=false;assert(not sky.args.vigor.args.showSegments.get() and sky.args.vigor.args.segmentThickness.disabled())
skyDB.showSegments=true;assert(sky.args.vigor.args.showSegments.get() and not sky.args.vigor.args.segmentThickness.disabled())
assert(sky.args.secondary.args.swHeight.name=='Height' and sky.args.secondary.args.swGap.name=='Spacing')
skyDB.swHeight=12;skyDB.swGap=5
for _,showWind in ipairs({false,true}) do
 for _,showSurge in ipairs({false,true}) do
  skyDB.swEnabled=showWind;skyDB.wsEnabled=showSurge
  assert(sky.args.secondary.args.swHeight.disabled()==(not showWind and not showSurge))
  assert(sky.args.secondary.args.swGap.disabled()==(not showWind and not showSurge))
  assert(sky.args.secondary.args.swColor.disabled()==not showWind)
  assert(sky.args.secondary.args.wsColor.disabled()==not showSurge)
  assert(sky.args.secondary.args.swHeight.get()==12 and sky.args.secondary.args.swGap.get()==5)
 end
end
print('Skyriding: consolidated behavior, vigor styling, and secondary bars passed.')
''')

lua.execute('''
local methods={}
function methods:SetLabel(value) self.label=value end
function methods:SetSliderValues(min,max,step) self.min=min;self.max=max;self.step=step end
function methods:SetIsPercent(value) self.percent=value end
function methods:SetValue(value) self.value=value end
function methods:SetWidth() end
function methods:SetCallback(_,callback) self.changed=callback end
AceGUI={Create=function() return setmetatable({},{__index=methods}) end}
controls={AddChild=function() end}
function PreviewChanged(state) previewState=state end
''')
lua.execute(builders['AddSlider'])
lua.execute('''
local saved=35
local opacity=AddSlider('Ready opacity',saved,0,100,1,function(value) saved=value end,'READY')
assert(opacity.percent and opacity.max==1 and opacity.value==.35 and opacity.step==.01)
opacity.changed(nil,nil,.5);assert(saved==50 and previewState=='READY')
local size=AddSlider('Size',25,10,100,1,function(value) saved=value end)
assert(not size.percent and size.max==100 and size.value==25)
size.changed(nil,nil,40);assert(saved==40)
''')
print('Tracker installer: percentage display preserves draft units and ordinary slider behavior.')
