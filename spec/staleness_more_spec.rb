# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Additional staleness cases' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  describe SimpleCovMcp::CoverageModel do
    it 'raises file-level stale when source and coverage lengths differ' do
      # Ensure time is not the triggering factor - use current timestamp
      mock_resultset_with_timestamp(root, Time.now.to_i, coverage: {
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [1, 1] }  # 2 entries vs 3 lines in source
      })
      model = SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage', staleness: 'error')
      # bar.rb has 2 coverage entries but 3 source lines in fixtures
      expect do
        model.summary_for('lib/bar.rb')
      end.to raise_error(SimpleCovMcp::CoverageDataStaleError, /stale/i)
    end
  end

  describe SimpleCovMcp::StalenessChecker do
    it 'flags deleted files present only in coverage' do
      checker = described_class.new(root: root, resultset: 'coverage', mode: 'error', timestamp: Time.now.to_i)
      coverage_map = {
        File.join(root, 'lib', 'does_not_exist_anymore.rb') => { 'lines' => [1] }
      }
      expect do
        checker.check_project!(coverage_map)
      end.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
    end

    it 'does not raise for empty tracked_globs when nothing else is stale' do
      checker = described_class.new(root: root, resultset: 'coverage', mode: 'error', tracked_globs: [], timestamp: Time.now.to_i)
      expect do
        checker.check_project!({})
      end.not_to raise_error
    end
  end
end
