# Release Notes

### v0.3.0
* MCP JSON responses now return as `type: "resource"` with `resource.mimeType: "application/json"` and JSON in `resource.text` for all JSON-producing tools. This clarifies media type, and was originally intended to circumvent a Claude Code content-type coercion bug, but the fix is also incorrectly processed.
* Affected tools: `all_files_coverage_tool`, `coverage_summary_tool`, `coverage_detailed_tool`, `coverage_raw_tool`, `uncovered_lines_tool`, `help_tool`.
* Unchanged (text responses): `coverage_table_tool` and `version_tool` remain `type: "text"`.

### v0.2.1
* Fixed JSON data key issue and resulting test failure.


### v0.2.0

* Massive enhancements and improvements.


### v0.1.0

* Initial version.
