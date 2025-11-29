# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli) { described_class.new }

  before do
    cli.config.root = root
    cli.config.resultset = 'coverage'
    cli.config.staleness = :off
    cli.config.tracked_globs = nil
  end

  describe '#show_default_report' do
    it 'prints JSON summary using relativized payload when json mode is enabled' do
      cli.config.format = :json

      output = nil
      silence_output do |stdout, _stderr|
        cli.show_default_report(sort_order: :ascending, output: stdout)
        output = stdout.string
      end

      payload = JSON.parse(output)

      expect(payload['files']).to be_an(Array)
      expect(payload['files'].first['file']).to eq('lib/bar.rb').or eq('lib/foo.rb')
      expect(payload['counts']).to include('total', 'ok', 'stale')
    end
  end
end
