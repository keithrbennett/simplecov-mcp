# Success predicate: Total project coverage >= 85%
# Usage: simplecov-mcp --success-predicate examples/success_predicates/project_coverage_minimum.rb

->(model) do
  files = model.all_files
  total_covered = files.sum { |f| f['covered'] }
  total_lines = files.sum { |f| f['total'] }
  coverage_pct = (total_covered.to_f / total_lines * 100)

  coverage_pct >= 85.0
end
