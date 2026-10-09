# PleebUI options standard

Builders own section placement and choose shortcuts explicitly. The shared schema normalizes labels,
values and inline widget order; it must not infer new tabs or quick settings from widget labels.
Mark deliberately organized trees with `arg = { puiExplicit = true }`.

Use General for activation, tracking and a small set of deliberately selected common controls.
Use Layout and appearance for dimensions, arrangement, texture, colors, backgrounds and borders.
Use Text for content and typography, Visibility for display conditions, opacity and fading.
Keep meaningful feature sections such as Auras, Castbar and Indicators. Advanced is for uncommon
settings with a clear reason for separation. Small features may use fewer pages.
Unit Frames use General, Layout and appearance, Text, Auras, Castbar, Visibility, Indicators,
Portrait, then special frame sections.

Every widget belongs to a named inline group. Avoid inline containers whose only purpose is to
wrap other inline groups. A parent with real shared controls may contain independently named roles.
Combine sparse pages or groups when their controls serve the same goal; do not invent empty groups
to meet a template. Lazy editor placeholders may be empty until selected.
Place page notices inside an existing visible inline group rather than adding a notice-only heading.
Keep shared range opacity in one group. Keep related texture sources and selectors together.
Use an inline group in General for a small advanced setting instead of giving it a sparse page.

Use short property labels when the heading identifies the affected object. Keep qualifiers when
multiple objects share one group. Use Behaviour consistently. Use Enable for activation and Show
for display, preserving existing toggle polarity.

Within each group put activation/display toggles first, then modes and source selections, primary
values, styling, position, and scoped reset/delete actions. Preserve intentionally arranged rows
and keep custom-color toggles next to their pickers.
Relative-width rows keep their builder order during label normalization and final widget ordering.
Text roles use Show text, Format, inheritance, Font, Font size, Outline, Text color, Anchor point,
Horizontal offset and Vertical offset, omitting properties that do not apply.

Opacity sliders display percentages with a 0–1 UI range. Existing saved values keep their original
units; the UI translates where required. Do not change runtime database units to standardize a label.

General shortcuts use `OptionsSchema.BuildCommonSettings` with explicit source paths and clear
labels. Copies retain source callbacks and inherited visibility/disabled conditions. Avoid callbacks
that infer their owner from the complete options path. Keep the list small and omit font-size lists.
PCM quick settings keep timer activation, tooltips and desaturation; dimensions, spacing and text
display controls stay in their detailed sections. Name size controls for the selected display type.
Use Spacing between icon and bar for the distance separating those two elements.

Search section destinations come from the same builders as the actual editors.
Delete actions and resets that discard saved customization require a scoped confirmation.
Describe the fields a reset actually changes. Use one confirmation owner per action, including
conditional reloads, and recheck combat restrictions when the user accepts.
Routine position resets may remain immediate.

Run the checked-in Options tests after changing builders or the schema, then perform the live
checks in Tests/Options/README.md. Mocked previews and Lua parsing cannot prove live UI or taint safety.
