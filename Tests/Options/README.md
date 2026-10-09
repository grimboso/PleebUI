# Options regression checks

Install Python dependencies with `python -m pip install -r Tests/Options/requirements.txt`.
Install the parser with `npm install --prefix Tests/Options`.
Run `python Tests/Options/test_options.py` and `python Tests/Options/test_previews.py` from any directory.

The suite evaluates current production builders with a Lua 5.1 runtime and mocked WoW dependencies.
AST extraction reads complete functions from current files; it does not duplicate their implementations.
AceConfigRegistry validates the resulting trees. Coverage includes individual/grouped frames, action bars,
meter windows, PCM typography/search, theme, class filtering, shared callbacks, toggle ordering,
percentage conversion and repeated schema application. All Core/Modules Lua is compiled.
The preview suite also checks reminder independence, combat visibility, event shutdown,
preview construction and stable tab-strip placement with a taller header.

These checks do not render AceGUI, enter combat, or verify live taint behavior.
After UI changes, reload WoW and inspect each affected page at normal and maximum options font size
and at the narrowest supported options window. Check profile switching, class/spec filtering,
live setting updates and previews separately, and confirm destructive prompts before accepting them.
