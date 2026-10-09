import os, json, subprocess
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[2]
os.chdir(root)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
frames={};fonts={};events={};combat=false
local methods={}
function methods:IsShown() return self.shown~=false end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:SetFont(_,size,flags) self.fontSize=size;self.fontFlags=flags end
function methods:SetFontObject(font) self.fontObject=font end
function methods:SetText(t) self.text=t end
function methods:GetStringWidth() return #(self.text or '')*(self.fontSize or 12)/2 end
function methods:GetStringHeight() return rawget(self,'stringHeight') or 12 end
function methods:SetTextColor(...) self.color={...} end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:GetWidth() return rawget(self,'width') or 340 end
function methods:GetHeight() return rawget(self,'height') or 190 end
function methods:SetPoint(...) self.point={...} end
function methods:GetFrameLevel() return 1 end
function methods:SetCooldownFromDurationObject(d) self.duration=d end
function methods:SetHideCountdownNumbers(v) self.hideNumbers=v end
function methods:SetCountdownMillisecondsThreshold(v) self.threshold=v end
function methods:SetScript(k,v) self.scripts=rawget(self,'scripts') or {};self.scripts[k]=v end
function methods:Clear() self.duration=nil end
local meta={__index=function(t,k) return methods[k] or function() end end}
function object() return setmetatable({},meta) end
function methods:CreateFontString() return object() end
function methods:CreateTexture() return object() end
function methods:GetCountdownFontString() self.counter=rawget(self,'counter') or object();return self.counter end
function CreateFrame(kind,name,parent) local f=object();frames[#frames+1]=f;if name then frames[name]=f end;return f end
function CreateFont(name) local f=object();fonts[name]=f;return f end
UIParent=object()
function UnitClass() return 'Hunter','HUNTER' end
function InCombatLockdown() return combat end
function issecretvalue() return false end
function wipe(t) for k in pairs(t) do t[k]=nil end end
C_CurveUtil={CreateCurve=object};Enum={LuaCurveType={Step=1},SpellBookSpellBank={Player=1}}
C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 253 end}
C_SpellBook={IsSpellKnownOrInSpellBook=function() return true end}
C_Spell={GetOverrideSpell=function(id) return id end,GetSpellName=function(id) return 'Spell '..id end,
 GetSpellTexture=function(id) return id end,GetSpellCharges=function() return nil end,
 GetSpellCooldown=function() return {isActive=true} end,
 GetSpellCooldownDuration=function() return {EvaluateTotalDuration=function() return 1 end} end}
local owner={}
function owner:IsEnabled() return true end
function owner:RegisterEvent(e) events[e]=true end
function owner:UnregisterEvent(e) events[e]=nil end
function owner:UnregisterAllEvents() wipe(events) end
local db={enabled=false,x=0,y=50,spells={},fontSize=30,showDecimals=false,color={r=.3,g=.4,b=.5,a=1}}
ns={Modules={},Flags={IsEditing=false},Addon={db={profile={movementWarning=db}},NewModule=function() return owner end,
 RegisterOptionsSection=function(_,_,_,_,_,_,meta) previewBuilder=meta.page.buildPreview;pageMeta=meta.page end,
 NotifyOptionsTreeChanged=function() end},
 Pleebug={DropIn=function() return {Def=function(_,_,fn) return fn end} end},
 FrameUtil={RegisterMover=function() end,SetMoverSuppressed=function() end,IsMoverPreviewVisible=function() return true end},
 Theme={GetIconTextGlobal=function() return 'Font','OUTLINE' end,ResolveFontSize=function(s) return s end,ApplyFont=function() end},
 LSM={Fetch=function() return 'font.ttf' end}}
PleebUIAPI={RegisterPlugin=function() return {RegisterEditModeParticipant=function() end} end}
''')
lua.eval('function(s) return assert(loadstring(s))("PleebUI",ns) end')(Path('Modules/PUIModules/PUI_MovementWarning.lua').read_text())
lua.execute('''
local owner=ns.Modules.MovementWarning;local db=ns.Addon.db.profile.movementWarning
local opts=owner:GetOptions();local a=db.reminders[781];local b=db.reminders[186257]
assert(a.fontSize==30 and b.fontSize==30 and a.showDecimals==false and db.fontSize==nil)
assert(a.color~=b.color and a.countdownColor~=b.countdownColor)
local ga=opts.args.reminder781.args;local gb=opts.args.reminder186257.args
assert(ga.displayMode and ga.fontSize and ga.color and ga.showDecimals and ga.showCountdown and ga.countdownColor)
ga.fontSize.set(nil,40);gb.fontSize.set(nil,20);ga.countdownFontSize.set(nil,32)
ga.color.set(nil,1,0,0,1);assert(b.color.r==.3 and b.fontSize==20)
ga.showCountdown.set(nil,false);assert(b.showCountdown==true and ga.showDecimals.disabled())
ga.enabled.set(nil,false);assert(#frames==0 and next(events)==nil)
ga.enabled.set(nil,true);opts.args.general.args.enabled.set(nil,true)
assert(events.SPELL_UPDATE_COOLDOWN and events.PLAYER_REGEN_DISABLED)
assert(fonts.PleebUI_MovementWarningCountdownFont1.fontSize==32)
assert(fonts.PleebUI_MovementWarningCountdownFont2.fontSize==30)
ga.combatOnly.set(nil,true);owner:OnMovementEvent('SPELL_UPDATE_COOLDOWN',781)
local cooldowns={};for _,f in ipairs(frames) do if rawget(f,'counter') then cooldowns[#cooldowns+1]=f end end
assert(#cooldowns==2 and rawget(cooldowns[1],'duration')==nil)
combat=true;owner:OnMovementEvent('PLAYER_REGEN_DISABLED');assert(cooldowns[1].duration~=nil)
assert(cooldowns[1].hideNumbers==true and cooldowns[2].hideNumbers==false)
owner:OnInitialize();assert(pageMeta.previewAlwaysShown and pageMeta.tabsBeforeHeader)
previewBuilder(nil,nil,{previewHost=object()})
assert(#frames>0)
opts.args.general.args.enabled.set(nil,false);assert(next(events)==nil)
owner:OnDisable();assert(next(events)==nil)
print('Movement reminder: legacy migration, independent colors/styles/countdowns, disabled lifecycle, combat-only events, row fonts, and preview construction passed.')
''')
b=json.loads(subprocess.check_output(['node',str(Path(__file__).with_name('extract_builders.js'))],cwd=root,text=True))
lua.execute('''
Pixel={Point=function(f,...) f.point={...} end,Height=function(f,h) f.height=h end,Size=function(f,w,h) f.width=w;f.height=h end}
PUI_PAGE_GAP=10;PUI_PAGE_HEADER_HEIGHT=78;math_max=math.max
''')
for n in ['PUI_PageShell_SyncACDContainer','PUI_PageShell_RebuildLayout']:lua.execute(b[n])
lua.execute('''
local shell=object();shell.acdContainer=false;shell.__puiLayoutBuilding=false;for _,k in ipairs({'body','header','stickyStrip','contentHost','nativeHost','previewDock','previewHost','headerActions','title','description','helpLine','acdHost'}) do shell[k]=object() end
shell.headerActions:Hide();shell.__puiTitleText='Title';shell.__puiDescriptionText='Description';shell.__puiHelpText='Help';shell.__puiTabsBeforeHeader=true;shell.__puiPreviewHeight=190
shell.__puiLayoutBuilding=false;PUI_PageShell_RebuildLayout(shell);local y=shell.stickyStrip.point[5];assert(y==0)
shell.description.stringHeight=100;shell.__puiLayoutBuilding=false;PUI_PageShell_RebuildLayout(shell);assert(shell.stickyStrip.point[5]==y)
shell.__puiTabsBeforeHeader=false;shell.__puiLayoutBuilding=false;PUI_PageShell_RebuildLayout(shell);assert(shell.stickyStrip.point[5]<0)
print('QoL tab strip: fixed position with changing header height; default page layout retained.')
''')
