# Success predicate: Different thresholds for different directories, using a `call` class method
# Usage: simplecov-mcp --success-predicate examples/success_predicates/directory_specific_thresholds_predicate.rb

class DirectorySpecificThresholds

  def self.call(model)
    new(model).call
  end

  def initialize(model)
    @files = model.relativize(model.all_files)
  end

  def files_ok?(filemask, threshold_percentage)
    files = @files.select { |f| File.fnmatch?(filemask, f['file']) }
    files.all? { |f| f['percentage'] >= threshold_percentage }
  end

  def call
    [
      ['lib/simplecov_mcp/**/*.rb',                 85], # global default minimum
      ['lib/simplecov_mcp/option_parsers/**/*.rb',  95],
      ['lib/simplecov_mcp/tools/**/*.rb',          100]
    ].map { |(filemask, threshold_pct)| files_ok?(filemask, threshold_pct) } \
    .all?
  end
end

DirectorySpecificThresholds
