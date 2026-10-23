# Pleebug

Pleebug helps you find which parts of an addon are doing work. Open it with `/pleebug` or `/pbug`.

Debugging is off by default. Turn it on for an investigation, record a short capture, then turn it off before normal play.

## Record a capture

1. Open **Settings** and choose the addons and files you want to track.
2. Click **Enable debugging (reload)**.
3. Click **Start**, reproduce the problem, then click **Stop**.
4. Expand the relevant addon and bucket, or search for an operation.
5. Use **Export** to copy the displayed results.
6. When finished, click **Disable debugging (reload)**.

Start and Stop work immediately, including during combat. Enabling or disabling debugging, changing measurement modes, and changing file selections in Full mode require a reload outside combat. Light-mode selections apply immediately.

Every reload starts with recording stopped. Closing the window does not stop a running capture. Start begins a fresh capture; Clear discards the current results. Results are kept in memory until Start, Clear or reload.

The **Wrapping** indicator tells you whether Full wrappers are installed. Stopping a Full capture leaves those wrappers in place: calls still pass through a small enabled check, but do not read clocks or record measurements. Disable debugging and reload to restore the original functions. Stop does not remove existing taint.

## Read the list

The list has three levels: **addon**, **bucket**, then **function**. Buckets use stable source-file identities and can have readable labels supplied by their owning addon. Renaming a label does not rename a registration or reset its measurements.

- Click an addon or bucket to open or close it. Closing an addon remembers which buckets were open.
- **Expand children** opens the addon and all its buckets, even when the addon was collapsed.
- **Collapse children** closes its buckets and leaves the addon open.
- **Expand all** and **Collapse all** apply to the whole list.

The main columns are:

| Column | Meaning |
| --- | --- |
| Calls | Completed measured calls, or calls reported by a native sample |
| Total ms | Measured CPU time in the selected window |
| Avg ms | Total time divided by calls |
| Peak ms | Slowest completed call in Full mode |
| Sample ms | Highest sampled average in Light mode; this is not an individual slow call |
| Alloc KiB | Average allocation per call with allocation data; optional in Settings |

Hover a row for its full identity, measurement backend, calls per second, frame statistics and other available details. The allocation maximum remains available in the tooltip and export when the column is hidden. Allocation measures bytes allocated during work, not memory still in use.

Addon and bucket rows show grouped call counts. Their CPU columns stay blank because function measurements can overlap. They are not complete addon CPU totals.

The **Native addon CPU** summary is separate from the function list. It identifies the addon being measured and shows its native total, average and peak for the selected window. Addon memory is a separate memory-usage reading. Neither value is a sum of the function rows.

### Search, sort and missing rows

Search matches addon names, bucket names, function names and internal paths, without regard to case. Matching branches open temporarily; clearing the search restores your expansion choices. Search does not change what is collected.

Click a column heading to sort by total time, average, peak, calls or name. Click it again to reverse the direction. Addons keep their registered order; buckets use name order except when sorting by calls. CPU sorting applies to individual functions and events, not invented group totals.

Row order stays fixed during recording so the list does not move under the cursor. Click **Resort** or a heading to update it. New registrations are appended within their groups. Stopped results can be sorted normally.

Functions and buckets with no calls are hidden by default. **Settings > Show rows with no calls** reveals them. Addon headers remain visible and explain an empty group:

| Message | Meaning |
| --- | --- |
| No calls in this window | Registrations exist, but none have recorded activity in the selected window |
| Excluded from tracking | The addon or file is not selected |
| No registered functions | The addon registered its name but has no function registrations in this load |
| Addon not loaded | Metadata exists for the addon, but it is not loaded |
| Debugging disabled | Collection is off |
| Unwrapped function | A function is registered but has no Full wrapper or measured alias |

Only addons that register with Pleebug can appear. An optional addon that never loads cannot register itself; its absence is not a measurement of zero CPU. The settings list contains discovered files, regardless of their activity.

A call can take too little time to show at three decimal places and still have a nonzero call count. A zero count means no calls were recorded for that row in the current window; it does not prove that all of the addon's work was measured.

### Export

Export copies tab-separated rows into a window for Ctrl+C. It follows the current search, zero-call filter, expansion and row order. Collapsed groups export their summary; expanded groups export their visible descendants. Rows below the current scroll position are included.

Stop freezes the measurements. You can then search, sort, expand, collapse or change the zero-call filter and export again without changing those values. Hiding the allocation column does not remove detailed allocation fields from the export.

## Choose a measurement mode

| Mode | What it does |
| --- | --- |
| Debugging disabled | Keeps original function references. No measurement registrations, collection hooks or samplers are installed. Start and Stop are unavailable. |
| Full | Wraps selected functions when files load. Start and Stop control measurement without replacing functions or reloading. Uses the native call-measurement API when available, otherwise a timer. Full mode can taint restricted paths. |
| Light | Keeps original function references and samples Blizzard's CPU counters once per second. Requires `scriptProfile=1` and a reload. Does not provide per-call allocations or Full frame statistics. |

Both recording modes have a performance cost. Use an uninstrumented run when comparing normal gameplay performance. In Full mode, a parent's measurement includes nested calls and their instrumentation. Do not add parent, child, recursive or alias rows together as independent work.

The first update that introduced the debugging switch turns legacy debugging off once. It preserves file selections and display settings. After that, your choice persists across logins and reloads; it is not reset on every login. The same migration clears legacy native script profiling and can require one extra reload after login. Full is the initial mode when you opt in.

Disabling debugging sets `scriptProfile=0` before reloading. Light and Full are investigation tools, not recommended gameplay settings.

## Capture windows

The window slider covers 5-60 seconds. Changing it adjusts the view without restarting capture. Counts, CPU, peaks, allocations and phases all use the same selected window. Old activity disappears as it leaves the window; widening the window can recover data still in history.

History uses at most 62 one-second buckets per active function. The oldest partial second is included, so a settled window can cover up to one extra second. A new capture covers only the time since Start. Calls per second use the covered duration, which is also exported.

Native function and event sampling, snapshot publication and visible-list updates share the existing one-second capture ticker. Full calls update their aggregate buckets as they complete. There is no separate UI polling ticker and no per-call history log. Recording continues when the window is closed.

Full frame statistics use `GetTime()` as a frame key. They count active frames only and include the current partial frame. Consecutive frames with the same timestamp are combined. For example, 80 calls taking 0.04 ms each in one frame contribute 3.2 ms to that function's frame total. These are inclusive measurements, not independent frame CPU totals.

## Add instrumentation

Call `DropIn` once in each source file and register the functions that file owns:

```lua
local P = ns.Pleebug:DropIn({})

local function RefreshWidgets()
  -- Existing work goes here.
end
RefreshWidgets = P:Def("RefreshWidgets", RefreshWidgets)
```

Register a function before passing it to a timer, event handler, adapter or other code that keeps its reference. A registration at the end of the file is too late if an earlier statement has already captured the original function. `DropIn` alone does not discover local functions or wrap every method automatically.

`P:Def(name, fn)` returns the selected original function or Full wrapper. Assign that result back to the actual local or owner method. `P:SecDef(name, owner, methodName)` registers a named owner method and installs its Full wrapper when selected. Keep arguments and return values opaque, including secret values and nil returns. Original errors propagate; an errored Full call adds no completed measurement.

For dynamic widget callbacks, use `P:DefCallback(name, fn)` with a fixed name for the source site. Full mode groups all instances under one record without retaining their closures or widgets. Light mode and disabled debugging return the original callback without registering that dynamic group. A group appears only after its first callback is constructed.

The 20 files directly in PleebUI's `Core/GUI` use these registrations for their functions, methods and callbacks, including shared theme and font helpers. This does not imply coverage of every separate options provider or every function in every addon.

### Addon names and bucket labels

An addon can provide its own display metadata:

```lua
pleebug:RegisterAddon(addonName, "Readable addon name", {
  MyRuntimeFile = "Widget updates",
}, 50)
```

`RegisterAddon(addonName, displayName, bucketLabels, sortOrder)` changes presentation only. It does not create measurements, move callbacks, or activate runtime work. Use the real loaded addon name and unchanged source-file keys. Existing `DropIn` callers are discovered automatically; display metadata is optional.

Ownership comes from the calling file's addon path unless `DropIn` supplies an explicit `addonName` or `addon`. Sharing a namespace does not make every file core-owned. Keep runtime frames, event handlers and timers in their owning addon. Do not add forwarding frames just to change attribution.

### Phase markers

To examine a few operations inside a measured caller, give their existing registrations short fixed labels:

```lua
RefreshWidgets = P:Def("RefreshWidgets", RefreshWidgets, nil, "Refresh widgets")
```

`P:SecDef` accepts the phase label as its fifth argument. Labels must be 1-43 bytes without control characters. Never build them from runtime arguments or secret values.

The native backend emits paired markers. The enclosing measured caller reports their aggregate time and allocations in its tooltip and export. A top-level call has no enclosing measured caller to receive its phase. Light mode, excluded files and timer fallback emit no markers.

Repeated and recursive phases overlap, and ancestor measurements can contain the same phase. Do not sum them. Unmatched markers are ignored. Pleebug retains aggregates, not the native per-call result or event tables.

## Export field reference

The export keeps detailed fields even when the main list uses fewer columns.

| Fields | Meaning |
| --- | --- |
| `path`, `name`, `depth` | Stable row identity, display label and hierarchy level |
| `calls`, `calls_per_sec` | Count and rate in the covered window |
| `cpu_total_ms`, `cpu_avg_ms` | Measured total and average |
| `cpu_peak_call_ms`, `cpu_last_call_ms` | Full-mode peak and latest completed call |
| `cpu_peak_sampled_avg_ms`, `cpu_last_sampled_avg_ms` | Native sampled averages; not individual calls |
| `measurement_state`, `measurement_kind`, `canonical_path` | Registration details and shared function identity |
| `cpu_scope` | Inclusive Full measurement, native function counter or global event counter |
| `alloc_avg_kb`, `alloc_max_kb`, `alloc_total_kb`, `allocation_calls` | Allocation activity and the number of calls with allocation data |
| `dealloc_avg_kb`, `dealloc_max_kb`, `dealloc_total_kb` | Available deallocation measurements |
| `active_frames`, `cpu_avg_active_frame_ms`, `cpu_peak_frame_ms` | Active-frame count, average accumulated time and peak accumulated time |
| `calls_avg_active_frame`, `calls_peak_frame` | Average and peak calls per active frame |
| `phase_measurements` | Named phase counts, timings and allocations |
| `window_seconds`, `window_start`, `window_end` | Covered duration and boundaries |

The `_kb` fields use 1024-byte units. Fields without measurements are blank. Allocation averages use calls with allocation data, so timer-only measurements do not dilute them. Alias rows share their canonical function's statistics. Native global event measurements are not owned by individual addons.

## Before relying on a capture

Check that the intended addon and files are selected, the Wrapping indicator matches the chosen mode, and recording is running. Exercise the specific operation during the capture; startup-only work will not appear in a later window.

When changing instrumentation, verify original references in disabled and Light modes, selected wrappers in Full mode, nil returns, errors, aliases, repeated captures and Stop/Start/Clear. Check that UI filtering and sorting leave recorded values unchanged and that exports match the visible branches.

Finally test in the game: reload, toggle debugging, change profiles, exercise live and preview frames, and enter and leave combat. Check for Lua errors, restricted-value errors and taint. Syntax checks and mocked tests cannot establish live combat safety or native CPU attribution.
