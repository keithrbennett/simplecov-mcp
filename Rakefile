# frozen_string_literal: true

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  task :spec do
    abort "RSpec is not installed. Add it to your bundle and run `bundle install`."
  end
  task default: :spec
end

