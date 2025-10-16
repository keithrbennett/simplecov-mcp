# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SimpleCovMcp error edge cases' do
  describe SimpleCovMcp::CoverageDataStaleError do
    describe 'time formatting edge cases' do
      it 'handles invalid epoch seconds gracefully in rescue path' do
        # Create an object that responds to to_i but breaks Time.at
        bad_timestamp = Object.new
        def bad_timestamp.to_i
          raise ArgumentError, "Can't convert"
        end

        error = SimpleCovMcp::CoverageDataStaleError.new(
          'Test error',
          nil,
          file_path: 'test.rb',
          file_mtime: Time.at(1000),
          cov_timestamp: bad_timestamp,
          src_len: 10,
          cov_len: 8
        )

        message = error.user_friendly_message
        expect(message).to include('Coverage data stale')
        expect(message).to include('Test error')
      end

      it 'handles time that breaks Time.parse but has valid to_s' do
        # Create an object that can't be parsed but has valid to_s
        bad_time = Object.new
        def bad_time.to_s
          'unparseable_time_string'
        end

        error = SimpleCovMcp::CoverageDataStaleError.new(
          'Test error',
          nil,
          file_path: 'test.rb',
          file_mtime: bad_time,
          cov_timestamp: 1000,
          src_len: 10,
          cov_len: 8
        )

        message = error.user_friendly_message
        expect(message).to include('Coverage data stale')
        expect(message).to include('Test error')
        # Should fallback to string representation
        expect(message).to include('unparseable_time_string')
      end

      it 'handles delta calculation with invalid values in rescue path' do
        # Create objects that break arithmetic
        bad_time = Object.new
        def bad_time.to_i
          raise ArgumentError, "Can't convert"
        end

        bad_timestamp = Object.new
        def bad_timestamp.to_i
          raise ArgumentError, "Can't convert"
        end

        error = SimpleCovMcp::CoverageDataStaleError.new(
          'Test error',
          nil,
          file_path: 'test.rb',
          file_mtime: bad_time,
          cov_timestamp: bad_timestamp,
          src_len: 10,
          cov_len: 8
        )

        message = error.user_friendly_message
        expect(message).to include('Coverage data stale')
        # Delta line should not appear when calculation fails
        expect(message).not_to match(/Delta\s+- file is/)
      end
    end

    describe 'default message generation' do
      it 'uses default message when message is nil' do
        error = SimpleCovMcp::CoverageDataStaleError.new(
          nil, # No message provided
          nil,
          file_path: 'test.rb',
          file_mtime: Time.at(2000),
          cov_timestamp: 1000
        )

        message = error.user_friendly_message
        # When message is nil, the error class name is used by StandardError
        # which then triggers default_message to be called
        expect(message).to include('Coverage data')
        expect(message).to include('stale')
        # File path should appear in the details section
        expect(message).to match(/File\s+-/)
      end

      it 'uses generic default message when file_path is nil' do
        error = SimpleCovMcp::CoverageDataStaleError.new(
          nil, # No message
          nil,
          file_path: nil, # No file path
          file_mtime: Time.at(2000),
          cov_timestamp: 1000
        )

        message = error.user_friendly_message
        # When file_path is nil, should use 'file' as fallback
        expect(message).to include('Coverage data')
        expect(message).to include('file')
      end
    end
  end

  describe SimpleCovMcp::CoverageDataProjectStaleError do
    describe 'default message generation' do
      it 'uses default message when message is nil' do
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          nil, # No message provided
          nil,
          cov_timestamp: 1000,
          newer_files: ['file1.rb', 'file2.rb']
        )

        message = error.user_friendly_message
        # When message is nil, StandardError uses class name, then default_message is called
        expect(message).to include('Coverage data')
        expect(message).to include('project')
      end
    end

    describe 'large file list truncation' do
      it 'shows all files when there are 10 or fewer deleted files' do
        deleted_files = (1..10).map { |i| "deleted_file_#{i}.rb" }
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          'Test error',
          nil,
          cov_timestamp: 1000,
          deleted_files: deleted_files
        )

        message = error.user_friendly_message
        expect(message).to include('Coverage-only files (deleted or moved in project, 10):')
        deleted_files.each do |file|
          expect(message).to include("  - #{file}")
        end
        expect(message).not_to include('...')
      end

      it 'truncates and shows ellipsis when there are more than 10 deleted files' do
        deleted_files = (1..15).map { |i| "deleted_file_#{i}.rb" }
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          'Test error',
          nil,
          cov_timestamp: 1000,
          deleted_files: deleted_files
        )

        message = error.user_friendly_message
        expect(message).to include('Coverage-only files (deleted or moved in project, 15):')
        # Should show first 10 files
        deleted_files[0..9].each do |file|
          expect(message).to include("  - #{file}")
        end
        # Should not show files beyond 10
        deleted_files[10..14].each do |file|
          expect(message).not_to include("  - #{file}")
        end
        # Should show ellipsis
        expect(message).to include('...')
      end

      it 'shows all files when there are 10 or fewer missing files' do
        missing_files = (1..10).map { |i| "missing_file_#{i}.rb" }
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          'Test error',
          nil,
          cov_timestamp: 1000,
          missing_files: missing_files
        )

        message = error.user_friendly_message
        expect(message).to include('Missing files (new in project, not in coverage, 10):')
        missing_files.each do |file|
          expect(message).to include("  - #{file}")
        end
        expect(message).not_to include('...')
      end

      it 'truncates and shows ellipsis when there are more than 10 missing files' do
        missing_files = (1..12).map { |i| "missing_file_#{i}.rb" }
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          'Test error',
          nil,
          cov_timestamp: 1000,
          missing_files: missing_files
        )

        message = error.user_friendly_message
        expect(message).to include('Missing files (new in project, not in coverage, 12):')
        # Should show first 10 files
        missing_files[0..9].each do |file|
          expect(message).to include("  - #{file}")
        end
        # Should not show files beyond 10
        expect(message).not_to include("  - #{missing_files[11]}")
        # Should show ellipsis
        expect(message).to include('...')
      end

      it 'truncates and shows ellipsis when there are more than 10 newer files' do
        newer_files = (1..20).map { |i| "newer_file_#{i}.rb" }
        error = SimpleCovMcp::CoverageDataProjectStaleError.new(
          'Test error',
          nil,
          cov_timestamp: 1000,
          newer_files: newer_files
        )

        message = error.user_friendly_message
        expect(message).to include('Newer files (20):')
        # Should show first 10 files
        newer_files[0..9].each do |file|
          expect(message).to include("  - #{file}")
        end
        # Should not show files beyond 10
        newer_files[10..19].each do |file|
          expect(message).not_to include("  - #{file}")
        end
        # Should show ellipsis
        expect(message).to include('...')
      end
    end
  end
end
