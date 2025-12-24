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
