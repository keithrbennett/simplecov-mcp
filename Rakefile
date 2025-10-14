# frozen_string_literal: true

begin
  require 'bundler/setup'
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  task :spec do
    abort 'RSpec is not installed. Add it to your bundle and run `bundle install`.'
  end
  task default: :spec
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    abort 'RuboCop is not installed. Add it to your bundle and run `bundle install`.'
  end
end

