# Pleebug

Pleebug records function and event activity for development. Open it with `/pleebug` or `/pbug`. Choose files in Light mode, switch to Full and reload before the encounter, then use Start and Stop whenever needed, including during combat. Switching modes reloads; Start and Stop do not. Start and Clear reset capture statistics.

## Measurement modes

- **Light:** registers original function references and returns them unchanged. Blizzard's native CPU counters require `scriptProfile=1` and a reload. Per-call memory and per-function frame measurements are unavailable.
- **Full:** switching to Full and reloading installs replacements only in the selected files. Recording is initially stopped. Start enables measurement immediately; Stop disables it immediately. The native measurement backend records time, allocated bytes and deallocated bytes. If unavailable, the timer backend records time only. Full mode can taint restricted execution paths.

Stop freezes the selected snapshot, aggregate statistics and exact tab-separated export text in runtime memory. Results remain available while stopped, including after closing and reopening the window. Start and Clear discard the frozen text. A reload clears results and never resumes capture automatically. No capture data, arguments, returns, original functions or Blizzard result tables are saved.

Choose files in Light mode before switching to Full. Full selections stay fixed for that loaded session, so excluded files retain original function identity. Selected wrappers remain installed while stopped, but forward calls without clocks, measurement calls, markers or recording. Switch to Light and reload to restore original references. Stop does not restore locals or erase existing taint. Only mode changes require leaving combat; Start and Stop work in combat. Full mode is a development tool; Light remains the ordinary investigation mode.

## Function frame measurements

In Full mode, hover a function row for frame statistics. Export includes these columns after the existing measurement columns:

| Column | Meaning |
| --- | --- |
| `active_frames` | Capture frames containing completed measured calls to this function |
| `cpu_avg_active_frame_ms` | Accumulated function time divided by active frames |
| `cpu_peak_frame_ms` | Highest accumulated function time in one capture frame |
| `calls_avg_active_frame` | Completed measured calls divided by active frames |
| `calls_peak_frame` | Most completed measured calls in one capture frame |

These statistics cover the selected measurement window, including the current partial frame. Idle frames are excluded. For example, 80 calls taking 0.04 ms each in one frame accumulate 3.2 ms. Light-mode exports leave these fields empty.

The frame key uses `GetTime()`, which is cached once per frame, so event and OnUpdate calls in that frame share the same key. There is no additional frame ticker or per-call history table. Each function retains at most 62 active-second aggregate buckets, covering the largest selectable window without retaining individual calls. Profiling clock ticks (`elapsedTicks`) are a separate quantity. If consecutive rendered frames return the same `GetTime()` value, their statistics merge; per-frame caching alone does not guarantee a unique frame identifier.

Full measurements are inclusive: nested calls and their instrumentation can contribute to a parent's measurement. Recursive calls also overlap. Do not add parent and child rows to estimate independent addon CPU time. Light-mode function counters use `GetFunctionCPUUsage(fn, false)`. Their peak is the highest sampled average, not an individual slow call; global event counters have their own scope. Native allocation totals describe allocation activity, not retained memory. Allocation averages divide by calls with allocation data, so timer-fallback calls do not dilute them.

## Call and sample meanings

Function and global-event tooltips distinguish the average per call, latest value and peak. Exports separate these quantities rather than using one peak column for both modes:

| Column | Meaning |
| --- | --- |
| `cpu_avg_ms` | Window cost divided by completed measured or sampled calls in that window |
| `cpu_peak_call_ms` | Slowest completed Full measured call; blank for native sampling |
| `cpu_last_call_ms` | Latest completed Full measured call |
| `cpu_peak_sampled_avg_ms` | Highest native sample cost divided by that sample's calls |
| `cpu_last_sampled_avg_ms` | Latest native sample cost divided by that sample's calls |
| `cpu_scope` | Inclusive Full call, native function counter with subroutines disabled, or global event counter |
| `phase_measurements` | Named phase call counts, average/peak milliseconds, allocated/deallocated averages |

The old `cpu_peak_sample_ms` export column is replaced by the two explicit peak columns. Calls, CPU, allocations, frame statistics and phase statistics now use the same selected window. Full function counts include completed measurements; an errored call propagates its error and adds no completed measurement. Alias rows refer to the canonical function's same statistics and must not be added as independent work.

## Capture windows and recording cost

The Settings window slider selects 5-60 seconds. Changing it changes the view immediately without restarting capture or clearing retained history. Start and Clear still reset capture data. Old peaks, allocation totals and phase measurements disappear as their buckets leave the selected window. A wider selection can recover data still inside the bounded history.

Full recording reads the cached frame timestamp once per call. The second conversion is shared across calls in that frame, and each function binds its current bucket. Count and cost updates go to that same bucket; there are no separate function-count ring writes or additional precise-clock reads per call. Aggregation runs when publishing a snapshot, refreshing the window or freezing Stop. Individual return values and result/event tables are not retained in history.

Buckets have one-second resolution. The oldest partial second is included, so an established selected window can cover up to one extra second. A newly started capture covers only its elapsed duration. Tooltips and the status show the covered duration; calls per second divide by that duration. Exports include `window_seconds` (covered duration), `window_start` and `window_end` on every row. They also include `cpu_total_ms`, `alloc_total_kb`, `dealloc_avg_kb`, `dealloc_max_kb`, `dealloc_total_kb` and `allocation_calls`. Allocation averages divide by the measured allocation-call count, including when a window contains timer-fallback calls.

One capture ticker owns native sampling, snapshot publication and visible-window refresh. Light sampling runs once per second while capture is active, whether the window is open or closed. There is no separate UI polling ticker. Native calls and CPU deltas are stored together at the sample timestamp. A sample cannot be split into individual call timestamps; delayed callbacks can make a sample span more than one second. Native peaks remain sample averages. The sampler never installs function wrappers. The addon overview in the status also uses the selected window; addon memory is a separate retained-memory snapshot, not window allocation activity.

Stop freezes the selected window and its text. Frozen values do not age away while stopped. Start or Clear discards them; reload clears all capture data.

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

Marker snapshots include instrumentation between their boundaries. They measure allocation activity, not retained memory. No per-call event history is kept. Start and Clear reset phase history along with call statistics; phase aggregates also expire with their selected window.

## Instrumentation instructions

1. Use `ns.Pleebug:DropIn(...)` once per source file. Source filenames own function grouping.
2. Put the registration block at the end of the file, after its function definitions, and register its owned named functions with `P:Def` or `P:SecDef`. Verify callers and any previously captured callback references reach the intended functions.
3. Registration must not execute the function. Keep profiling calls out of ordinary function bodies. Light mode must preserve original function and method identity.
4. Pass local function references to `P:Def`. Use `P:SecDef` for named owner methods when required. Neither helper discovers inaccessible locals automatically.
5. Keep payloads opaque. Do not inspect, compare, format or derive grouping from secret arguments or returns. Preserve the number and positions of all returns, including nils, and propagate original errors.
6. Build stable names and keys during registration. Full capture binds its registration record, native measurement function, optional phase marker names and module-settings table once. Backend availability is checked while measuring because Blizzard controls it. Full file selections apply when Full mode loads and stay fixed for that session; Light selections can change live. Do not normalize saved settings or reconstruct paths on each call.
7. Keep completed call counts and costs in the same bounded bucket. Aggregate outside the measured execution path, and keep window selection separate from sampling cadence. Do not introduce per-call history allocations or an idle recording ticker.
8. Start and Clear invalidate cached runtime statistics while preserving registrations. Stop freezes results and hides the existing frame sampler. Selected Full wrappers remain installed until switching to Light and reloading; while stopped, they must forward arguments and returns without performing measurement work. Keep these lifecycle responsibilities symmetrical.

## Validation

Check window expiry with an old expensive call followed by newer inexpensive calls: narrow the selection and confirm the old count, CPU peak, allocation and phase totals disappear together; widen it and confirm retained data returns without resetting capture. Verify `cpu_avg_ms * calls` agrees with `cpu_total_ms` within rounding, and calls per second uses the exported duration. Check bounded history after several minutes and Light sampling with the window closed.

Check Lua syntax and function contracts before in-game testing: no returns, nil gaps, trailing nils, multiple returns, errors, aliases, recursion, disabled files, group toggles, Stop, Start and Clear. Verify Light returns original function objects, selected Full files wrap when Full mode loads, excluded files preserve identity, and Full starts stopped after every reload. Exercise Start and Stop during combat without reload or reference replacement. Confirm stopped calls do not read clocks, invoke measurement APIs, emit markers or change aggregates. Test repeated captures, frozen export text, mode-change combat refusal, paired/recursive phase markers, and native/timer export fields.

After reload, exercise combat and restricted unit/action paths, file toggles, previews and live frames, and inspect Lua and taint logs. Confirm tooltips and exports agree, Stop freezes measurements, and several inexpensive calls in one frame produce the expected accumulated frame peak. Compare performance with a controlled uninstrumented baseline; a Lua harness cannot establish live taint safety or instrumentation overhead.
