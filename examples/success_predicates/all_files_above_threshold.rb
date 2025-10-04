# Success predicate: All files must have >= 80% coverage
# Usage: simplecov-mcp --success-predicate examples/success_predicates/all_files_above_threshold.rb

->(model) do
  threshold = 80
  low_files = model.all_files.select { |f| f['percentage'] < threshold }
  low_files.empty?
end
