# frozen_string_literal: true

# Success predicate: Total project coverage >= 85%
# Usage: simplecov-mcp --success-predicate examples/success_predicates/project_coverage_minimum_predicate.rb

->(model) { model.project_totals['percentage'] >= 85.0 }
