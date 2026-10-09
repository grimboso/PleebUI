const fs = require('fs'), path = require('path');
const lua = require(process.env.PLEEBUI_LUAPARSE || 'luaparse');
const root = path.resolve(__dirname, '../..');
const targets = {
 'Modules/PCM/PUI_PCM_CustomTrackerInstaller.lua': ['AddSlider'],
 'Modules/PUIModules/Chat/PUI_Chat.lua': ['ChatProvider'],
 'Modules/PUIModules/PUI_Minimap.lua': ['MinimapProvider'],
 'Modules/PUIModules/PUI_Dragonriding.lua': ['DragonridingProvider'],
 'Core/GUI/PUI_PageShell.lua': ['PUI_PageShell_SyncACDContainer','PUI_PageShell_RebuildLayout'],
 'Core/PUI_Quality.lua': ['QualityProvider','Quality_GetPreviewWarnings','Quality_RefreshPreview','Quality_BuildPreview','EnsureInviteDriver','EnsureLootFrame','NormalizeDB','NormalizeBool','SeedAnchorDefaults','QUALITY_POSITION_DEFAULTS','Quality:ApplyAll'],
 'Modules/PUIModules/PUI_RaidUtility.lua': ['RAID_UTILITY_WINDOW_SPECS','Module.BuildBresLustOptions','Module.BuildRaidUtilityOptions'],
 'Core/GUI/PUI_Theme.lua': ['UIThemeOptionsProvider','ThemeColorsProvider','ThemeFontsProvider','PUI_ThemeColorOption','_PUI_ThemeRegistry_CopyArgsWithoutHeader','PUI_THEME_COLOR_OPTIONS'],
 'Modules/PRD/PUI_PRD_Config.lua': ['PRD_ArrangePresentationArgs','PRD_ArrangeNativeBarArgs','PRD_BuildNativeTextGroup']
};
const output = {};
for (const [file, names] of Object.entries(targets)) {
 const source = fs.readFileSync(path.join(root, file), 'utf8');
 const ast = lua.parse(source, {luaVersion: '5.1', ranges: true});
 function visit(node) {
  if (!node || typeof node !== 'object') return;
  if (node.type === 'FunctionDeclaration') {
   const identifier = node.identifier;
   const name = identifier?.name || (identifier?.base?.name && identifier?.identifier?.name
    ? identifier.base.name + identifier.indexer + identifier.identifier.name : null);
   if (names.includes(name)) output[name] = source.slice(...node.range).replace(/^local function /, 'function ');
  }
  if (['AssignmentStatement','LocalStatement'].includes(node.type))
   (node.variables || []).forEach((variable,index) => {
    if (names.includes(variable.name) && node.init[index] && !output[variable.name])
     output[variable.name] = variable.name + ' = ' + source.slice(...node.init[index].range);
   });
  for (const [key,value] of Object.entries(node)) {
   if (['range','loc'].includes(key)) continue;
   if (Array.isArray(value)) value.forEach(visit);
   else if (value && typeof value === 'object') visit(value);
  }
 }
 visit(ast);
 for (const name of names) if (!output[name]) throw Error('Missing builder: ' + name);
}
process.stdout.write(JSON.stringify(output));
