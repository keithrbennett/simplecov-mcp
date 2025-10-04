# Success predicate: Allow up to 5 files below threshold
# Usage: simplecov-mcp --success-predicate examples/success_predicates/max_low_coverage_files.rb

->(model) do
  threshold = 80
  max_allowed_low = 5

  low_files = model.all_files.select { |f| f['percentage'] < threshold }
  low_files.count <= max_allowed_low
end
