Most recent commit: a55bd50bffe66a7d798cc1bc96969f9b1bc93992 (Mark stale files in CoverageReporter test suite output, 2026-01-09 21:38:49 +0800)

---

## Issue: CoverageModel can serve stale data in long-lived instances

### Description
`CoverageModel` memoizes `@cov` and `@cov_timestamp` after the first load, which bypasses `ModelDataCache` change detection for any long-lived model instance. If a consumer holds a model across multiple coverage runs (e.g., embedding the library in a long-running process), the model will continue to serve old data until `refresh_data` is called manually. The code comments claim cache auto-reload, but the memoization blocks it. See `lib/cov_loupe/model/model.rb:211`, `lib/cov_loupe/model/model.rb:220`, and `lib/cov_loupe/model/model.rb:225`.

### Assessment
- **Severity:** Medium
- **Effort to Fix:** Medium
- **Impact if Unaddressed:** Long-lived integrations return stale coverage summaries after a new `.resultset.json` is generated, leading to incorrect CLI/API output and potential CI misinterpretation.

### Strategy
Stop memoizing `@cov`/`@cov_timestamp` for normal runtime (or invalidate them based on the resultset digest/signature), and rely on `ModelDataCache` to provide fresh data. Keep `refresh_data` for explicit resets if needed, but make default behavior correct for long-lived models.

### Actionable Prompt
```
Fix stale data in CoverageModel by preventing instance-level memoization from bypassing ModelDataCache refreshes. Specifically:
1. Rework coverage_map and coverage_timestamp to fetch from ModelDataCache on each call, or
2. Store and compare the ModelDataCache signature/digest and invalidate @cov/@cov_timestamp when it changes.
Add tests that simulate a resultset update and verify the same CoverageModel instance returns refreshed data.
```

---

## Issue: Windows-incompatible command detection in scripts

### Description
`CommandExecution#command_exists?` relies on the `which` command to check PATH availability. This fails on Windows environments where `which` is not present, causing scripts like `StartDocServer` to incorrectly report missing dependencies even when they are installed. See `lib/cov_loupe/scripts/command_execution.rb:38` and `lib/cov_loupe/scripts/start_doc_server.rb:9`.

### Assessment
- **Severity:** Medium
- **Effort to Fix:** Low
- **Impact if Unaddressed:** Documentation tooling cannot be started on Windows, weakening cross-platform dev workflows.

### Strategy
Add a Windows-aware fallback using `where` (or Ruby’s built-in `RbConfig::CONFIG[host_os]` to branch) and/or PATH scanning when `which` is unavailable. Keep the existing POSIX behavior unchanged.

### Actionable Prompt
```
Make CommandExecution#command_exists? work on Windows. Use a platform check to run `where` on Windows and `which` elsewhere, falling back to PATH scanning if the command is a bare name. Add unit tests that stub platform detection and verify both branches.
```

---

## Issue: Missing tests for PathUtils error-handling branches

### Description
Coverage shows two uncovered lines in `PathUtils`, both in exception-handling branches (`rescue ArgumentError` in `relativize` and filesystem error fallback in `normalized_start_with?`). These are edge-paths for cross-volume and error-prone filesystem scenarios and are currently untested. See `lib/cov_loupe/paths/path_utils.rb:113` and `lib/cov_loupe/paths/path_utils.rb:284`.

### Assessment
- **Severity:** Low
- **Effort to Fix:** Low
- **Impact if Unaddressed:** Regressions in path handling or case-sensitivity detection could slip through undetected, especially on Windows or restricted file systems.

### Strategy
Add targeted specs that force those rescue branches (stub `Pathname#relative_path_from` to raise `ArgumentError`, stub `PathUtils.volume_case_sensitive?` to raise `SystemCallError`) and assert the fallbacks behave as intended.

### Actionable Prompt
```
Add specs for PathUtils error branches:
1) Stub Pathname#relative_path_from to raise ArgumentError and assert PathUtils.relativize returns the original path.
2) Stub PathUtils.volume_case_sensitive? to raise SystemCallError and assert normalized_start_with? falls back to case-insensitive behavior.
Use minimal stubbing and keep the specs in spec/cov_loupe/paths/path_utils_spec.rb.
```

---

### Summary Table

| Brief Description (<= 50 chars) | Severity (H/M/L) | Effort (H/M/L) | Impact if Unaddressed | Link to Detail |
| :--- | :---: | :---: | :--- | :--- |
| Stale data in long-lived CoverageModel | M | M | Incorrect coverage output after reruns | [See below](#issue-coveragemodel-can-serve-stale-data-in-long-lived-instances) |
| Windows `which` dependency breaks scripts | M | L | Doc server tooling fails on Windows | [See below](#issue-windows-incompatible-command-detection-in-scripts) |
| Untested PathUtils error paths | L | L | Edge-case regressions slip in | [See below](#issue-missing-tests-for-pathutils-error-handling-branches) |
