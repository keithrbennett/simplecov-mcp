# Release Notes

### v1.0.0-rc.1
* **Feature (2025-10-12):** Multi-suite `.resultset.json` files are now merged using SimpleCov’s combine helpers. The gem lazily requires SimpleCov when multiple suites are present and keeps the newest suite timestamp for staleness checks (per-file timestamps to follow).
* **Documentation update (2025-10-10):** We experimented with returning JSON via `type: "resource"` plus `mimeType: "application/json"`, but popular MCP clients (Anthropic Claude, Google Gemini, Codex) expect resources to carry a URI and rejected inline JSON. To preserve compatibility the release continues to emit JSON inside `type: "text"` parts. Earlier notes referencing a resource envelope have been superseded.

### v0.2.1
* Fixed JSON data key issue and resulting test failure.


### v0.2.0

* Massive enhancements and improvements.


### v0.1.0

* Initial version.
