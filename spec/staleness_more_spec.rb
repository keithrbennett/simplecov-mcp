# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Additional staleness cases' do
  let(:root) { (FIXTURES / 'project1').to_s }

  describe SimpleCovMcp::CoverageModel do
    it 'raises file-level stale when source and coverage lengths differ' do
      # Ensure time is not the triggering factor
      allow(SimpleCovMcp::CovUtil).to receive(:latest_timestamp).and_return(Time.now.to_i)
      model = SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage', staleness: 'error')
      # bar.rb has 3 coverage entries but 4 source lines in fixtures
      expect {
        model.summary_for('lib/bar.rb')
      }.to raise_error(SimpleCovMcp::CoverageDataStaleError, /stale/i)
    end
  end

  describe SimpleCovMcp::StalenessChecker do
    it 'flags deleted files present only in coverage' do
      checker = described_class.new(root: root, resultset: 'coverage', mode: 'error')
      coverage_map = {
        File.join(root, 'lib', 'does_not_exist_anymore.rb') => { 'lines' => [1] }
      }
      expect {
        checker.check_project!(coverage_map)
      }.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
    end

    it 'does not raise for empty tracked_globs when nothing else is stale' do
      allow(SimpleCovMcp::CovUtil).to receive(:latest_timestamp).and_return(Time.now.to_i)
      checker = described_class.new(root: root, resultset: 'coverage', mode: 'error', tracked_globs: [])
      expect {
        checker.check_project!({})
      }.not_to raise_error
    end
  end
end
