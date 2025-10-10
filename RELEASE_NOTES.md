# Release Notes

### v0.3.0
* **Documentation update (2025-10-10):** We experimented with returning JSON via `type: "resource"` plus `mimeType: "application/json"`, but popular MCP clients (Anthropic Claude, Google Gemini, Codex) expect resources to carry a URI and rejected inline JSON. To preserve compatibility the release continues to emit JSON inside `type: "text"` parts. Earlier notes referencing a resource envelope have been superseded.
* Affected tools: `all_files_coverage_tool`, `coverage_summary_tool`, `coverage_detailed_tool`, `coverage_raw_tool`, `uncovered_lines_tool`, `help_tool` (all return JSON as text payloads).
* Unchanged (text responses): `coverage_table_tool` and `version_tool` remain `type: "text"`.

### v0.2.1
* Fixed JSON data key issue and resulting test failure.


### v0.2.0

* Massive enhancements and improvements.


### v0.1.0

* Initial version.
