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

namespace :security do
  desc 'Audit dependencies for vulnerabilities with bundler-audit'
  task :bundler_audit do
    sh 'bundle exec bundle audit check --update'
  end

  desc 'Audit Ruby and RubyGems for known vulnerabilities with ruby_audit'
  task :ruby_audit do
    sh 'bundle exec ruby-audit'
  end

  desc 'Run all security audits'
  task :all do
    failures = []

    begin
      Rake::Task['security:bundler_audit'].invoke
    rescue => e
      failures << "bundler-audit failed: #{e.message}"
    end

    begin
      Rake::Task['security:ruby_audit'].invoke
    rescue => e
      failures << "ruby-audit failed: #{e.message}"
    end

    if failures.empty?
      puts '--- Security audits completed successfully ---'
      next
    end

    failures.each { |message| warn message }
    abort 'Security audits failed'
  end
end

desc 'Run all security audits'
task security: 'security:all'
