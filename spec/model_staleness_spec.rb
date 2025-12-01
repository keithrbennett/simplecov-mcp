# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe SimpleCovMcp::CoverageModel do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def with_stubbed_coverage_timestamp(timestamp)
    mock_resultset_with_timestamp(root, timestamp)
    yield
  end

  it "raises stale error when staleness mode is 'error' and file is newer" do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, staleness: :error)
      expect do
        model.summary_for('lib/foo.rb')
      end.to raise_error(SimpleCovMcp::CoverageDataStaleError, /stale/i)
    end
  end

  it "does not check staleness when mode is 'off'" do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, staleness: :off)
      expect { model.summary_for('lib/foo.rb') }.not_to raise_error
    end
  end

  it 'all_files raises project-level stale when any source file is newer than coverage' do
    with_stubbed_coverage_timestamp(VERY_OLD_TIMESTAMP) do
      model = described_class.new(root: root, staleness: :error)
      expect { model.all_files }.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
    end
  end

  it 'all_files detects new files via tracked_globs' do
    with_stubbed_coverage_timestamp(Time.now.to_i) do
      Tempfile.create(['brand_new_file', '.rb'], File.join(root, 'lib')) do |f|
        f.write("# new file\n")
        f.flush
        model = described_class.new(root: root, staleness: :error)
        expect do
          model.all_files(tracked_globs: ['lib/**/*.rb'])
        end.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
      end
    end
  end

  describe 'timestamp normalization' do
    it 'parses created_at strings to epoch seconds' do
      created_at = Time.new(2024, 7, 3, 16, 26, 40, '-07:00')
      mock_resultset_with_created_at(root, created_at.strftime('%Y-%m-%d %H:%M:%S %z'))

      model = described_class.new(root: root, staleness: :off)

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

      model = described_class.new(root: root, staleness: :error)

      expect(model.instance_variable_get(:@cov_timestamp)).to eq(created_at_time.to_i)
      expect do
        model.summary_for('lib/foo.rb')
      end.to raise_error(SimpleCovMcp::CoverageDataStaleError) { |error|
        expect(error.cov_timestamp).to eq(created_at_time.to_i)
      }
    end
  end
end
