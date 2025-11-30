# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp do
  describe SimpleCovMcp::ConfigurationError do
    describe '#user_friendly_message' do
      it 'prefixes message with "Configuration error:"' do
        error = described_class.new('Invalid option value')

        expect(error.user_friendly_message).to eq('Configuration error: Invalid option value')
      end

      it 'handles empty message' do
        error = described_class.new('')

        expect(error.user_friendly_message).to eq('Configuration error: ')
      end

      it 'handles nil message' do
        # When nil is passed to StandardError, it uses the class name as the message
        error = described_class.new(nil)

        expect(error.user_friendly_message).to eq('Configuration error: SimpleCovMcp::ConfigurationError')
      end
    end
  end


  describe SimpleCovMcp::CoverageDataStaleError do
    describe 'time formatting edge cases' do
      it 'handles invalid epoch seconds gracefully in rescue path' do
        # Create an object that responds to to_i but breaks Time.at
        bad_timestamp = Object.new
        def bad_timestamp.to_i
          raise ArgumentError, "Can't convert"
        end

        error = described_class.new(
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

        error = described_class.new(
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

        error = described_class.new(
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
      it 'uses default message when message is nil with file_path' do
        error = described_class.new(
          nil, # No message provided - triggers default_message
          nil,
          file_path: 'test.rb',
          file_mtime: Time.at(2000),
          cov_timestamp: 1000
        )

        message = error.user_friendly_message
        # default_message returns "Coverage data appears stale for test.rb"
        expect(message).to include('Coverage data appears stale for test.rb')
        # File path should appear in the details section
        expect(message).to match(/File\s+-/)
      end

      it 'uses generic default message when file_path is nil' do
        # This tests the fallback path when file_path is nil: fp = file_path || 'file'
        error = described_class.new(
          nil, # No message - triggers default_message
          nil,
          file_path: nil, # No file path - triggers 'file' fallback
          file_mtime: Time.at(2000),
          cov_timestamp: 1000
        )

        message = error.user_friendly_message
        # When file_path is nil, default_message returns "Coverage data appears stale for file"
        expect(message).to include('Coverage data appears stale for file')
      end
    end
  end

  describe SimpleCovMcp::CoverageDataProjectStaleError do
    describe 'default message generation' do
      # These tests exercise the private default_message method
      it 'includes project stale info when message is nil' do
        error = described_class.new(
          nil, # StandardError sets message to class name when nil
          nil,
          cov_timestamp: 1000,
          newer_files: ['file1.rb', 'file2.rb']
        )

        message = error.user_friendly_message
        # user_friendly_message prefixes with "Coverage data stale (project):"
        expect(message).to include('Coverage data stale (project)')
        expect(message).to include('Newer files')
      end

      it 'exercises default_message directly via send' do
        # Directly test the private default_message method for coverage
        # This is necessary because user_friendly_message uses `message || default_message`
        # and StandardError sets message to class name when initialized with nil
        error = described_class.new(
          'explicit message',
          nil,
          cov_timestamp: 1000
        )

        # Call the private default_message method directly
        result = error.send(:default_message)
        expect(result).to eq('Coverage data appears stale for project')
      end
    end

    describe 'large file list truncation' do
      it 'shows all files when there are 10 or fewer deleted files' do
        deleted_files = (1..10).map { |i| "deleted_file_#{i}.rb" }
        error = described_class.new(
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
        error = described_class.new(
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
        error = described_class.new(
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
        error = described_class.new(
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
        error = described_class.new(
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
