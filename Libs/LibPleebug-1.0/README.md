# Pleebug

Pleebug records function and event activity for development. Open it with `/pleebug` or `/pbug`. Select a debug mode in Settings, reload when prompted, then select the files to capture and press Start. Start and Clear reset capture statistics. Full Start and Stop reload; stopped results remain available after the removal reload.

## Measurement modes

- **Light:** registers original function references and returns them unchanged. Blizzard's native CPU counters require `scriptProfile=1` and a reload. Per-call memory and per-function frame measurements are unavailable.
- **Full:** Start arms a one-shot reload that installs replacements only in the selected files and begins capture. Selecting Full mode alone installs no replacements. The native measurement backend records time, allocated bytes and deallocated bytes. If unavailable, the timer backend records time only. Full mode can taint restricted execution paths.

Stop freezes Full results and reloads to remove replacements, including references captured by callbacks and locals. The stopped snapshot and aggregate statistics cross this reload once through `stoppedCapture`; the saved copy is deleted when restored. A later ordinary reload clears the runtime results and never resumes capture automatically. No call arguments, returns, original functions or Blizzard result tables are saved.

Choose files in Settings before Start. Full selections stay fixed until Stop, so excluded files retain original function identity. Start, Stop and mode changes require leaving combat. The reload is the removal boundary: disabling measurement before that boundary cannot restore Lua locals or erase taint introduced during a capture. Full capture is a development tool; Light remains the ordinary investigation mode.

## Function frame measurements

In Full mode, hover a function row for frame statistics. Export includes these columns after the existing measurement columns:

| Column | Meaning |
| --- | --- |
| `active_frames` | Capture frames containing completed measured calls to this function |
| `cpu_avg_active_frame_ms` | Accumulated function time divided by active frames |
| `cpu_peak_frame_ms` | Highest accumulated function time in one capture frame |
| `calls_avg_active_frame` | Completed measured calls divided by active frames |
| `calls_peak_frame` | Most completed measured calls in one capture frame |

These statistics cover the capture since Start or Clear, including the current partial frame. Idle frames are excluded. For example, 80 calls taking 0.04 ms each in one frame accumulate 3.2 ms. Light-mode exports leave these fields empty.

The frame key uses `GetTime()`, which is cached once per frame, so event and OnUpdate calls in that frame share the same key. There is no additional frame ticker or per-call history table. Each function retains one aggregate record. Profiling clock ticks (`elapsedTicks`) are a separate quantity.

Full measurements are inclusive: nested calls and their instrumentation can contribute to a parent's measurement. Recursive calls also overlap. Do not add parent and child rows to estimate independent addon CPU time. Light-mode function counters use `GetFunctionCPUUsage(fn, false)`. Their peak is the highest sampled average, not an individual slow call; global event counters have their own scope. Native allocation totals describe allocation activity, not retained memory. Allocation averages divide by calls with allocation data, so timer-fallback calls do not dilute them.

## Call and sample meanings

Function and global-event tooltips distinguish the average per call, latest value and peak. Exports separate these quantities rather than using one peak column for both modes:

| Column | Meaning |
| --- | --- |
| `cpu_avg_ms` | Capture cost divided by capture call count |
| `cpu_peak_call_ms` | Slowest completed Full measured call; blank for native sampling |
| `cpu_last_call_ms` | Latest completed Full measured call |
| `cpu_peak_sampled_avg_ms` | Highest native sample cost divided by that sample's calls |
| `cpu_last_sampled_avg_ms` | Latest native sample cost divided by that sample's calls |
| `cpu_scope` | Inclusive Full call, native function counter with subroutines disabled, or global event counter |
| `phase_measurements` | Named phase call counts, average/peak milliseconds, allocated/deallocated averages |

The old `cpu_peak_sample_ms` export column is replaced by the two explicit peak columns. Call counts shown in the tree use the rolling window; call-cost and frame aggregates cover the capture since Start or Clear.

## Targeted phase markers

Give a selected phase function a fixed label in its existing registration block:

```lua
CollectRows = P:Def("CollectRows", CollectRows, nil, "Collect rows")
UpdateWidgets = P:Def("UpdateWidgets", UpdateWidgets, nil, "Update widgets")
ApplyLayout = P:Def("ApplyLayout", ApplyLayout, nil, "Apply layout")
```

These are registration examples, not claims that these functions exist in a particular module. `P:SecDef` accepts the label as its fifth argument. Labels must contain 1-43 bytes and no control characters. Short fixed names keep the prefixed native markers below 48 bytes. Never construct labels from runtime arguments or secret values.

The existing Full wrapper emits begin/end markers only through the native backend. The enclosing measured caller receives them in `results.events`; Pleebug pairs the snapshots and retains only time and allocation deltas. Hover or export that enclosing caller to see phases. A top-level phase has no enclosing measured caller and therefore produces no phase row of its own. Timer fallback, Light mode and excluded files emit no markers.

This adds no calls to ordinary function bodies and no second wrapper around a phase function. Mark only the few named operations relevant to an investigation. Repeated and recursive same-name phases aggregate together and are inclusive; do not sum overlapping phases. Native markers reach all ongoing measurements, so ancestor rows can report the same phase. Unmatched markers are ignored. Original errors propagate unchanged, and an aborted measured call produces no completed phase statistics.

Marker snapshots include instrumentation between their boundaries. They measure allocation activity, not retained memory. No per-call event history is kept. Start and Clear reset the phase aggregates along with call statistics.

## Instrumentation instructions

1. Use `ns.Pleebug:DropIn(...)` once per source file. Source filenames own function grouping.
2. Put the registration block at the end of the file, after its function definitions, and register its owned named functions with `P:Def` or `P:SecDef`. Verify callers and any previously captured callback references reach the intended functions.
3. Registration must not execute the function. Keep profiling calls out of ordinary function bodies. Light mode must preserve original function and method identity.
4. Pass local function references to `P:Def`. Use `P:SecDef` for named owner methods when required. Neither helper discovers inaccessible locals automatically.
5. Keep payloads opaque. Do not inspect, compare, format or derive grouping from secret arguments or returns. Preserve the number and positions of all returns, including nils, and propagate original errors.
6. Build stable names and keys during registration. Full capture binds its registration record, native measurement function, optional phase marker names and module-settings table once. Backend availability is checked while measuring because Blizzard controls it. Full file selections are frozen for the capture and apply at its armed reload; Light selections can change live. Do not normalize saved settings or reconstruct paths on each call.
7. Start and Clear invalidate cached runtime statistics while preserving registrations. Stop freezes results, hides the existing frame sampler and removes Full instrumentation by reload. Keep these lifecycle responsibilities symmetrical.

## Validation

Check Lua syntax and function contracts before in-game testing: no returns, nil gaps, trailing nils, multiple returns, errors, aliases, recursion, disabled files, group toggles, Stop, Start and Clear. Verify Light and unarmed Full mode return original function objects, selected Full files wrap after Start reload, excluded files preserve identity, and Stop reload restores originals while preserving inspectable aggregates. Test one-shot flags and snapshot consumption, combat controls, paired/recursive phase markers, and native/timer export fields.

After reload, exercise combat and restricted unit/action paths, file toggles, previews and live frames, and inspect Lua and taint logs. Confirm tooltips and exports agree, Stop freezes measurements, and several inexpensive calls in one frame produce the expected accumulated frame peak. Compare performance with a controlled uninstrumented baseline; a Lua harness cannot establish live taint safety or instrumentation overhead.
