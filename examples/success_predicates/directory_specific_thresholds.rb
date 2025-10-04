# Success predicate: Different thresholds for different directories
# Usage: simplecov-mcp --success-predicate examples/success_predicates/directory_specific_thresholds.rb

->(model) do
  files = model.all_files

  # API code requires 90% coverage
  api_files = files.select { |f| f['file'].include?('lib/api/') }
  api_ok = api_files.all? { |f| f['percentage'] >= 90 }

  # Core business logic requires 85% coverage
  core_files = files.select { |f| f['file'].include?('lib/core/') }
  core_ok = core_files.all? { |f| f['percentage'] >= 85 }

  # Legacy code only requires 60% coverage
  legacy_files = files.select { |f| f['file'].include?('lib/legacy/') }
  legacy_ok = legacy_files.all? { |f| f['percentage'] >= 60 }

  api_ok && core_ok && legacy_ok
end
