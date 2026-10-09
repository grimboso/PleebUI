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
function InCombatLockdown() return false end
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
  else assert(group.inline==true,'Unheaded widget '..ancestors..'/'..key) end
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
 ns.Modules[pair[1]]={db=copy(pair[2]),IsEnabled=function() return true end,SafeRefresh=function() end,RefreshText=function() end,RefreshTextures=function() end}
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
 for _,key in ipairs({'general','layout','visibility','text','indicators','auras'}) do
  assert(args[key],family..' missing '..key)
 end
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
 assert(not args.layout.args.health.args.texture and not args.layout.args.power.args.texture)
 if family=='party' or family=='raid' then
  assert(not textures.useCustomTexture)
 else
  assert(textures.useCustomTexture and textures.healthTexture.disabled())
  textures.useCustomTexture.set(nil,true);assert(not textures.healthTexture.disabled())
  textures.useCustomTexture.set(nil,false);assert(textures.healthTexture.disabled())
  local range=args.visibility.args.range
  assert(range.args.outOfRangeAlpha and not range.args.puiStyle_outOfRange)
 end
 for _,key in ipairs({'layout','text','visibility'}) do
  assert(not args[key].args.puiControls, family..' has a notice-only heading in '..key)
 end
end
assert(opts.args.player.args.pet.args.text)
assert(opts.args.target.args.targettarget.args.text)
assert(opts.args.focus.args.focustarget.args.text)
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
print('Actual Unit Frames builders: all frame trees, inline headings, typography order, setters, and text-only reset scopes passed.')

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
print('PCM section builder: text roles, inherited conditions, concise quick settings, original callbacks and detailed controls passed.')


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
assert(opts.childGroups=='tab' and opts.args.general and opts.args.layout and opts.args.colors and opts.args.text)
assert(opts.args.text.args.global.args.font.name=='Font')
assert(opts.args.layout.args.text.args.fontSize.name=='Font size')
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
function Quality_GetPreviewWarnings() return {"Combat message"} end
QualityPreviewIndex=1
function Clamp(v,a,b) return math.min(b,math.max(a,v)) end
function IsPetClass() return true end
function IsHealPetClass() return false end
ns.RaidUtilityModule={BuildBresLustOptions=function() return {type='group',name='Battle resurrection and bloodlust',inline=true,args={general={args={}},layout={args={bresLustWidgetIconSize={type='range',name='Icon size'}}}}} end,
BuildRaidUtilityOptions=function() return {type='group',name='Raid utility',inline=true,args={buttons={type='group',name='Ready',inline=true,args={}},raidMarkers={type='group',name='Targets',inline=true,args={}},worldMarkers={type='group',name='World',inline=true,args={}},general={type='group',name='General',inline=true,args={}}}} end}
''')
lua.execute(builders['QualityProvider'])
lua.execute('''
for _,class in ipairs({'HUNTER','MAGE'}) do
 TEST_CLASS=class
 local opts=QualityProvider(ns.Addon):GetOptions();ns.OptionsSchema.Apply(opts,'Quality');checkInline(opts)
 assert((opts.args.combatTab.args.emergencySalve~=nil)==(class=='HUNTER'),'Hunter visibility '..class..' '..tostring(opts.args.combatTab.args.emergencySalve))
 local status={message=opts.args.combatTab.args.combatMessages,timer=opts.args.combatTab.args.combatTimer}
 assert(status.message.args.fontSize.name=='Font size' and status.timer.args.showText.name=='Show text')
 local ring={inner=opts.args.cursorTab.args.innerRing,click=opts.args.cursorTab.args.clickRing}
 assert(ring.inner.args.size.name=='Size' and ring.click.args.color.name=='Color')
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
 assert(not args.general and args.layoutAppearance and args.textGroup)
 assert(args.layoutAppearance.args.border.args.borderSize.name=='Thickness')
 assert(args.layoutAppearance.args.border.args.borderSize.get==callback)
 assert(args.textGroup.args.leftFont.args.fontSize.name=='Font size')
 assert(args.textGroup.args.content.args.percentVisibility.name=='Percent visibility')
end
''')
print('Current PRD presentation builders: bar/style ownership, typography roles, and callback preservation passed.')


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
 opacity={type='range',name='Ready opacity',min=0,max=100,step=5,order=30,
 get=function() return 35 end,set=function(_,value) saved=value end},
 delete={type='execute',name='Delete window',order=2,confirm='Delete this window?'}
 }}}},
 layout={type='group',name='Layout and appearance',args={}}
}}
ns.OptionsSchema.Apply(options,'Example')
local controls=options.args.general.args.settings.args
assert(controls.show.order<controls.size.order and controls.delete.order>controls.opacity.order)
assert(controls.opacity.max==1 and controls.opacity.isPercent and controls.opacity.get({})==.35)
controls.opacity.set({},.8);assert(saved==80)
assert(not options.args.general.args.puiCommonSettings)
assert(not controls.puiStyle_text)
local order=controls.show.order
ns.OptionsSchema.Apply(options,'Example');assert(controls.show.order==order)

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
print('Chat: three tabs, preserved formatting/history/copy controls, and headings passed.')
local map=MinimapProvider(Addon):GetOptions();ns.OptionsSchema.Apply(map,'Minimap');checkInline(map);checkCompact(map)
assert(map.args.general.args.minimap.args.hideTracking and map.args.general.args.minimap.args.hideCalendar)
assert(map.args.topPanel.args.clock.args.hideClock and map.args.general.args.buttons.args.hide)
assert(map.args.topPanel.args.zone.args.hideZoneText.order<map.args.topPanel.args.zone.args.fontSize.order)
assert(map.args.topPanel.args.panel.args.clockBoxEnabled and map.args.general.args.minimap.args.clockBoxBorderSize)
print('Minimap: two tabs, existing hide settings exposed, panel toggle and shared border available.')
local sky=DragonridingProvider(Addon):GetOptions();ns.OptionsSchema.Apply(sky,'Dragonriding');checkInline(sky);checkCompact(sky)
assert(sky.args.general.args.swEnabled and sky.args.general.args.wsEnabled)
assert(sky.args.vigor.args.width and sky.args.vigor.args.barColor)
assert(sky.args.secondary.args.wsColor and sky.args.secondary.args.swGap)
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
