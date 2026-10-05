# Pleebug

Pleebug records function and event activity for development. Open it with `/pleebug` or `/pbug`. Select a debug mode in Settings, reload when prompted, then press Start. Stop preserves the results; Start and Clear reset capture statistics.

## Measurement modes

- **Light:** registers original function references and returns them unchanged. Blizzard's native CPU counters require `scriptProfile=1` and a reload. Per-call memory and per-function frame measurements are unavailable.
- **Full:** installs instrumented replacements at file load and measures enabled files only while capture is running. The native measurement backend records time, allocated bytes and deallocated bytes. If unavailable, the timer backend records time only. Full mode can taint restricted execution paths.

Stopping Full capture disables measurement, counting and profiler bookkeeping. It currently leaves forwarding replacements installed until a reload into Light mode. This is a remaining activation limitation: ordinary execution should use original references, and installing or removing replacements must be handled explicitly rather than assumed from the placement of a registration block.

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

Full measurements are inclusive: nested calls and their instrumentation can contribute to a parent's measurement. Recursive calls also overlap. Do not add parent and child rows to estimate independent addon CPU time. Light-mode peak samples describe sampled averages, not individual slow calls. Native allocation totals describe allocation activity, not retained memory.

## Instrumentation instructions

1. Use `ns.Pleebug:DropIn(...)` once per source file. Source filenames own function grouping.
2. Put the registration block at the end of the file, after its function definitions, and register its owned named functions with `P:Def` or `P:SecDef`. Verify callers and any previously captured callback references reach the intended functions.
3. Registration must not execute the function. Keep profiling calls out of ordinary function bodies. Light mode must preserve original function and method identity.
4. Pass local function references to `P:Def`. Use `P:SecDef` for named owner methods when required. Neither helper discovers inaccessible locals automatically.
5. Keep payloads opaque. Do not inspect, compare, format or derive grouping from secret arguments or returns. Preserve the number and positions of all returns, including nils, and propagate original errors.
6. Build stable names and keys during registration. Full capture binds its registration record, native measurement function and module-settings table once. Backend availability is checked while measuring because Blizzard controls it. Module setters update that same table, so enabled-file changes take effect immediately. Do not normalize saved settings or reconstruct paths on each call.
7. Start and Clear invalidate cached runtime statistics while preserving registrations. Stop freezes results and hides the existing frame sampler. Keep these lifecycle responsibilities symmetrical.

## Validation

Check Lua syntax and function contracts before in-game testing: no returns, nil gaps, trailing nils, multiple returns, errors, aliases, recursion, disabled files, group toggles, Stop, Start and Clear. Verify Light mode returns the original function objects and Full-mode calls perform no profiling while stopped.

After reload, exercise combat and restricted unit/action paths, file toggles, previews and live frames, and inspect Lua and taint logs. Confirm tooltips and exports agree, Stop freezes measurements, and several inexpensive calls in one frame produce the expected accumulated frame peak. Compare performance with a controlled uninstrumented baseline; a Lua harness cannot establish live taint safety or instrumentation overhead.
