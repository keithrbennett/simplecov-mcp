# frozen_string_literal: true

require_relative 'resultset_path_resolver'
require_relative 'coverage_line_resolver'

module CovLoupe
  module Resolvers
    class ResolverHelpers
      def self.create_resultset_resolver(root: Dir.pwd, resultset: nil, candidates: nil)
        candidates ?
          ResultsetPathResolver.new(root: root, candidates: candidates) :
          ResultsetPathResolver.new(root: root)
      end

      def self.create_coverage_resolver(cov_data, root:, volume_case_sensitive:)
        CoverageLineResolver.new(cov_data, root: root, volume_case_sensitive: volume_case_sensitive)
      end

      def self.find_resultset(root, resultset: nil)
        ResultsetPathResolver.new(root: root).find_resultset(resultset: resultset)
      end

      def self.lookup_lines(cov, file_abs, root:, volume_case_sensitive:)
        CoverageLineResolver.new(cov, root: root,
          volume_case_sensitive: volume_case_sensitive).lookup_lines(file_abs)
      end

      # Detects whether the volume at the given path is case-sensitive.
      # Prefer using an existing file (via File.identical?) to avoid writing;
      # fall back to a temporary file if no suitable file exists.
      #
      # @param path [String] directory path to test
      # @return [Boolean] true if case-sensitive, false if case-insensitive
      def self.volume_case_sensitive?(path)
        require 'securerandom'
        require 'fileutils'

        abs_path = File.absolute_path(path)

        existing_file = Dir.children(abs_path).find do |name|
          name.match?(/[A-Za-z]/) && File.file?(File.join(abs_path, name))
        end

        if existing_file
          original = File.join(abs_path, existing_file)
          alternate = original.tr('A-Za-z', 'a-zA-Z')

          result = if File.exist?(alternate)
            # Same file -> case-insensitive, different files -> case-sensitive.
            !File.identical?(original, alternate)
          else
            true
          end
        else
          # Generate a unique mixed-case filename
          test_file = nil
          while test_file.nil?
            candidate = File.join(abs_path, "CovLoupe_CaseSensitivity_Test_#{SecureRandom.hex(16)}.tmp")
            variants = [candidate, candidate.upcase, candidate.downcase]
            test_file = candidate if variants.none? { |v| File.exist?(v) }
          end

          begin
            # Create the test file
            FileUtils.touch(test_file)

            # Test if exactly one variant exists (case-sensitive) vs all exist (case-insensitive)
            variants = [test_file, test_file.upcase, test_file.downcase]
            result = variants.one? { |variant| File.exist?(variant) }
          ensure
            # Clean up all potential variants
            [test_file, test_file.upcase, test_file.downcase].each do |variant|
              FileUtils.rm_f(variant)
            end
          end
        end

        result
      end
    end
  end
end
