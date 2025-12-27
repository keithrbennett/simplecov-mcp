# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe CovLoupe::CoverageModel do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def with_stubbed_coverage_timestamp(timestamp)
    mock_resultset_with_timestamp(root, timestamp)
    yield
  end

  it "raises stale error when staleness mode is 'error' and file is newer" do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, raise_on_stale: true)
      expect do
        model.summary_for('lib/foo.rb')
      end.to raise_error(CovLoupe::CoverageDataStaleError, /stale/i)
    end
  end

  it "does not check staleness when mode is 'off'" do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, raise_on_stale: false)
      expect { model.summary_for('lib/foo.rb') }.not_to raise_error
    end
  end

  it 'list raises project-level stale when any source file is newer than coverage' do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, raise_on_stale: true)
      expect { model.list }.to raise_error(CovLoupe::CoverageDataProjectStaleError)
    end
  end

  it 'list detects new files via tracked_globs' do
    with_stubbed_coverage_timestamp(Time.now.to_i) do
      Tempfile.create(%w[brand_new_file .rb], File.join(root, 'lib')) do |f|
        f.write("# new file\n")
        f.flush
        model = described_class.new(root: root, raise_on_stale: true)
        expect do
          model.list(tracked_globs: %w[lib/**/*.rb])
        end.to raise_error(CovLoupe::CoverageDataProjectStaleError)
      end
    end
  end

  describe 'tracked_globs scoping for staleness checks' do
    it 'only reports newer_files that match tracked_globs' do
      # Use coverage data with correct line counts (foo.rb: 6 lines, bar.rb: 5 lines)
      accurate_coverage = {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [nil, nil, 1, 0, nil, 2] },
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [nil, nil, 0, 0, 1] }
      }
      mock_resultset_with_timestamp(root, VERY_OLD_TIMESTAMP, coverage: accurate_coverage)

      # All files are newer than the very old timestamp, but we're only tracking lib/foo.rb
      model = described_class.new(root: root, raise_on_stale: false)
      result = model.list(tracked_globs: ['lib/foo.rb'])

      # Should only report foo.rb as newer, not bar.rb (which is also newer but outside scope)
      expect(result['newer_files']).to eq(['lib/foo.rb'])
      expect(result['newer_files']).not_to include('lib/bar.rb')
    end

    it 'only reports deleted_files that match tracked_globs' do
      # Create a scenario where bar.rb is in coverage but missing from filesystem
      coverage_with_missing = {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil, 2] },
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [0, 0, 1] },
        File.join(root, 'lib', 'nonexistent.rb') => { 'lines' => [1, 1] }
      }
      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: coverage_with_missing)

      model = described_class.new(root: root, raise_on_stale: false)
      result = model.list(tracked_globs: ['lib/foo.rb'])

      # Should not report nonexistent.rb as deleted since it's outside tracked_globs scope
      expect(result['deleted_files']).to eq([])
      expect(result['deleted_files']).not_to include('lib/nonexistent.rb')
    end

    it 'includes all stale files when tracked_globs is not specified' do
      # Use coverage data with correct line counts (foo.rb: 6 lines, bar.rb: 5 lines)
      accurate_coverage = {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [nil, nil, 1, 0, nil, 2] },
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [nil, nil, 0, 0, 1] }
      }
      mock_resultset_with_timestamp(root, VERY_OLD_TIMESTAMP, coverage: accurate_coverage)

      model = described_class.new(root: root, raise_on_stale: false)
      result = model.list

      # Should report both files as newer when no filtering is applied
      expect(result['newer_files']).to include('lib/foo.rb', 'lib/bar.rb')
    end
  end

  describe 'timestamp normalization' do
    it 'parses created_at strings to epoch seconds' do
      created_at = Time.new(2024, 7, 3, 16, 26, 40, '-07:00')
      mock_resultset_with_created_at(root, created_at.strftime('%Y-%m-%d %H:%M:%S %z'))

      model = described_class.new(root: root, raise_on_stale: false)

      expect(model.instance_variable_get(:@cov_timestamp)).to eq(created_at.to_i)
    end

    it 'propagates parsed created_at timestamps into stale errors' do
      file_mtime = File.mtime(File.join(root, 'lib', 'foo.rb'))
      created_at_time = (file_mtime + 3600).utc
      # Use mismatched coverage (3 lines instead of 4) to trigger staleness
      mismatched_coverage = {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil] }
      }
      mock_resultset_with_created_at(root, created_at_time.iso8601, coverage: mismatched_coverage)

      model = described_class.new(root: root, raise_on_stale: true)

      expect(model.instance_variable_get(:@cov_timestamp)).to eq(created_at_time.to_i)
      expect do
        model.summary_for('lib/foo.rb')
      end.to raise_error(CovLoupe::CoverageDataStaleError) { |error|
        expect(error.cov_timestamp).to eq(created_at_time.to_i)
      }
    end
  end
end
