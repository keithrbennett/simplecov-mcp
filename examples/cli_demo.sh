#!/usr/bin/env bash
# Demo script for simplecov-mcp CLI subcommands and options
# Runs against the included fixture project at spec/fixtures/project1.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
CLI=("exe/simplecov-mcp")
PROJ="examples/fixtures/demo_project"
RESULTSET_DIR="coverage" # directory containing .resultset.json under PROJ

run() {
  cat <<BANNER



-------------------------------------------------------------------------------
+ ${CLI[*]} $*
-------------------------------------------------------------------------------

BANNER
  "${CLI[@]}" "$@"

}

cat <<INTRO
== simplecov-mcp CLI demo ==

Note: Project root and resultset JSON file normally do not need to be specified.
We set --root here to use the examples/fixtures/demo_project nondefault location,
and later demonstrate a nondefault resultset via SIMPLECOV_RESULTSET.

Project root:     $PROJ
Resultset (dir):  $RESULTSET_DIR

INTRO

# 1) List all files (table)
run list --root "$PROJ"

# 2) List as JSON, descending sort
run list --root "$PROJ" --sort-order descending --json

# 3) Summary for a file (text and JSON)
run summary lib/foo.rb --root "$PROJ"
run summary lib/foo.rb --root "$PROJ" --json

# 4) Include source with summary (full and uncovered-only with context)
run summary lib/foo.rb --root "$PROJ" --source
run summary lib/foo.rb --root "$PROJ" --source=uncovered --source-context 1

# 5) Uncovered lines (text with source and JSON)
run uncovered lib/foo.rb --root "$PROJ" --source=uncovered --source-context 2
run uncovered lib/foo.rb --root "$PROJ" --json

# 6) Detailed per-line data (text and JSON), with source
run detailed lib/foo.rb --root "$PROJ" --source --no-color
run detailed lib/foo.rb --root "$PROJ" --json

# 7) Raw lines array (JSON)
run raw lib/foo.rb --root "$PROJ" --json

# 8) Using environment variable for a NONDEFAULT resultset location
#    Copy the default resultset into a simple alt directory to simulate a custom layout.
ALT_DIR="$PROJ/alt_resultset"
mkdir -p "$ALT_DIR"
cp -f "$PROJ/coverage/.resultset.json" "$ALT_DIR/.resultset.json"
echo 
echo "+ SIMPLECOV_RESULTSET=$PROJ/alt_resultset ${CLI[*]} list --root $PROJ"
SIMPLECOV_RESULTSET="$PROJ/alt_resultset" "${CLI[@]}" list --root "$PROJ"

echo
echo "== Done =="

# Cleanup files created for the nondefault resultset demo
rm -rf "$ALT_DIR"
