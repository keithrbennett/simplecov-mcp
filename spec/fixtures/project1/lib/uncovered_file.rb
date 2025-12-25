# frozen_string_literal: true

# This file exists in the project but is never loaded by tests,
# so it won't appear in coverage data. Used to test missing tracked file detection.
class UncoveredFile
  def self.hello
    puts 'Hello from an uncovered file'
  end
end
