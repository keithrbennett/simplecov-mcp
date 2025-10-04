# Success predicate: Using a class with call method
# Usage: simplecov-mcp --success-predicate examples/success_predicates/class_based_policy.rb

class CoveragePolicy
  THRESHOLD = 80

  def call(model)
    files = model.all_files(tracked_globs: ['lib/**/*.rb'])

    low_files = files.select { |f| f['percentage'] < THRESHOLD }

    if low_files.empty?
      true
    else
      # Can add custom logging/reporting here
      warn "Files below #{THRESHOLD}%:"
      low_files.each { |f| warn "  #{f['file']}: #{f['percentage']}%" }
      false
    end
  end
end

CoveragePolicy.new
