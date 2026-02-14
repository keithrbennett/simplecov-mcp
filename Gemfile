# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Development dependencies
gem 'rake'
gem 'rspec', '~> 3.0'
gem 'rubocop', '>= 1.84.2', '< 2'
gem 'rubocop-rspec', '~> 3.9'
gem 'simplecov-cobertura'

# Security auditing
gem 'bundler-audit', require: false
gem 'ruby_audit', require: false

# Ruby 3.5+ will remove irb and rdoc from default gems
gem 'irb', '>= 1.0' if RUBY_VERSION >= '3.4'
gem 'rdoc', '>= 6.0' if RUBY_VERSION >= '3.4'
