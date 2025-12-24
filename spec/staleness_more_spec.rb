# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  describe CovLoupe::CoverageModel do
    it 'raises file-level stale when source and coverage lengths differ' do
      # Ensure time is not the triggering factor - use current timestamp
      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: {
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [1, 1] } # 2 entries vs 3 lines in source
      })
      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)
      # bar.rb has 2 coverage entries but 3 source lines in fixtures
      expect do
        model.summary_for('lib/bar.rb')
      end.to raise_error(CovLoupe::CoverageDataStaleError, /stale/i)
    end

    it 'raises on list when source and coverage lengths differ' do
      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: {
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [1, 1] } # 2 entries vs 3 lines in source
      })
      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError, /stale/i)
    end

    it 'raises on list when file is newer than coverage but line count matches' do
      # Create coverage with an old timestamp (1 hour ago)
      old_timestamp = Time.now.to_i - 3600
      bar_path = File.join(root, 'lib', 'bar.rb')

      mock_resultset_with_timestamp(root, old_timestamp, coverage: {
        bar_path => { 'lines' => [1, 0, 1] } # 3 lines matching actual bar.rb
      })

      # Touch the file to make it newer than the coverage timestamp
      FileUtils.touch(bar_path)

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) do |error|
        expect(error.newer_files).to include('lib/bar.rb')
      end
    end

    it 'does not raise when all files are up to date with matching line counts' do
      # Create coverage with future timestamp and matching line counts
      # Use future timestamp to ensure files are not newer than coverage
      future_timestamp = Time.now.to_i + 3600
      bar_path = File.join(root, 'lib', 'bar.rb')
      foo_path = File.join(root, 'lib', 'foo.rb')

      mock_resultset_with_timestamp(root, future_timestamp, coverage: {
        bar_path => { 'lines' => [1, nil, 0, 0, 1] }, # 5 lines matching bar.rb
        foo_path => { 'lines' => [1, nil, 1, 0, nil, 1] } # 6 lines matching foo.rb
      })

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      # Should not raise - all files are current
      expect { model.list(raise_on_stale: true) }.not_to raise_error
    end

    it 'raises when a file in coverage no longer exists' do
      # Create coverage for a non-existent file
      missing_path = File.join(root, 'lib', 'deleted_file.rb')

      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: {
        missing_path => { 'lines' => [1, 1, 1] }
      })

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) do |error|
        expect(error.deleted_files).to include('lib/deleted_file.rb')
      end
    end

    it 'detects both time-based and length-based staleness for the same file' do
      # Create coverage with old timestamp AND different line count
      old_timestamp = Time.now.to_i - 3600
      bar_path = File.join(root, 'lib', 'bar.rb')

      mock_resultset_with_timestamp(root, old_timestamp, coverage: {
        bar_path => { 'lines' => [1, 1] } # 2 lines vs 3 in actual file
      })

      # Touch the file to make it newer than coverage
      FileUtils.touch(bar_path)

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) do |error|
        # File appears in both lists since it's both newer AND has wrong line count
        expect(error.newer_files).to include('lib/bar.rb')
        expect(error.length_mismatch_files).to include('lib/bar.rb')
      end
    end

    it 'includes length_mismatch_files in error message' do
      bar_path = File.join(root, 'lib', 'bar.rb')

      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: {
        bar_path => { 'lines' => [1, 1] } # 2 lines vs 3 in actual file
      })

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) do |error|
        error_message = error.user_friendly_message
        expect(error_message).to include('Line count mismatch')
        expect(error_message).to include('lib/bar.rb')
      end
    end

    it 'detects multiple staleness types in one project' do
      old_timestamp = Time.now.to_i - 3600
      bar_path = File.join(root, 'lib', 'bar.rb')
      foo_path = File.join(root, 'lib', 'foo.rb')
      missing_path = File.join(root, 'lib', 'deleted.rb')

      mock_resultset_with_timestamp(root, old_timestamp, coverage: {
        bar_path => { 'lines' => [1, 0, 1] }, # 3 lines - will be newer (T)
        foo_path => { 'lines' => [1, 1] },    # 2 lines vs 3 actual - length mismatch (L)
        missing_path => { 'lines' => [1, 1, 1] } # doesn't exist - missing (M)
      })

      # Touch bar.rb to make it newer
      FileUtils.touch(bar_path)

      model = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        raise_on_stale: true)

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) do |error|
        # Verify all three staleness types detected
        expect(error.newer_files).to include('lib/bar.rb')
        expect(error.length_mismatch_files).to include('lib/foo.rb')
        expect(error.deleted_files).to include('lib/deleted.rb')

        # Verify error message mentions all types
        message = error.user_friendly_message
        expect(message).to match(/newer.*bar\.rb/im)
        expect(message).to match(/line count mismatch.*foo\.rb/im)
        expect(message).to match(/deleted.*deleted\.rb/im)
      end
    end
  end

  describe CovLoupe::StalenessChecker do
    it 'flags deleted files present only in coverage' do
      checker = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        mode: :error,
        timestamp: Time.now.to_i)
      coverage_map = {
        File.join(root, 'lib', 'does_not_exist_anymore.rb') => { 'lines' => [1] }
      }
      expect do
        checker.check_project!(coverage_map)
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError)
    end

    it 'does not raise for empty tracked_globs when nothing else is stale' do
      checker = described_class.new(root: root, resultset: FIXTURE_PROJECT1_RESULTSET_PATH,
        mode: :error,
        tracked_globs: [], timestamp: Time.now.to_i)
      expect do
        checker.check_project!({})
      end.not_to raise_error
    end
  end
end
