# Codex MCP env var passthrough workaround

## Issue
- Codex do not forward `GEM_HOME`/`GEM_PATH` to MCP servers by default. When they are missing, `cov-loupe` cannot locate installed gems and fails to start.

## Workaround (Codex config)
1) Ensure the helper script below exists at `/home/kbennett/.local/bin/codex-cov-loupe` and is executable.
2) Edit `/home/kbennett/.codex/config.toml` to allow env var passthrough:
   ```
   [mcp_servers.cov-loupe]
   command = "/home/kbennett/.local/bin/codex-cov-loupe"
   env_vars = ["GEM_HOME", "GEM_PATH"]
   ```
3) Restart the Codex session so the new env var whitelist is applied.

## Helper script (`/home/kbennett/.local/bin/codex-cov-loupe`)
```bash
#!/usr/bin/env bash
set -euo pipefail

# To let Codex pass GEM_HOME/GEM_PATH through to this script, add (or update)
# the following in `/home/kbennett/.codex/config.toml`, then restart Codex:
# [mcp_servers.cov-loupe]
# command = "/home/kbennett/.local/bin/codex-cov-loupe"
# env_vars = ["GEM_HOME", "GEM_PATH"]

# Save the current directory to use as the coverage root
PROJECT_DIR="$PWD"

# Prevent Bundler from auto-loading project Gemfile
unset BUNDLE_GEMFILE 2>/dev/null || true

# Run from /tmp to avoid loading local project files (prevents double-loading)
cd /tmp

# Execute cov-loupe - env vars are provided by Codex via env_vars whitelist
exec cov-loupe -F mcp -R "$PROJECT_DIR"
```
