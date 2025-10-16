# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::UncoveredCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = 'coverage'
    cli_context.config.json = false
    cli_context.config.source_mode = nil
  end

  describe '#execute' do
    it 'prints uncovered line numbers with the summary' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute(['lib/foo.rb'])
        output = stdout.string
      end

      expect(output).to include('File:            lib/foo.rb')
      expect(output).to include('Uncovered lines: 2')
      # Example match: "Summary:         66.67%       2/3"
      expect(output).to match(/Summary:\s+66\.67%.*2\/3/)
    end

    it 'emits JSON when requested, including stale metadata' do
      cli_context.config.json = true
      stub_staleness_check('L')

      json_output = nil
      silence_output do |stdout, _stderr|
        command.execute(['lib/foo.rb'])
        json_output = stdout.string
      end

      payload = JSON.parse(json_output)
      expect(payload['file']).to eq('lib/foo.rb')
      expect(payload['uncovered']).to eq([2])
      expect(payload['summary']).to include('covered' => 2, 'total' => 3, 'pct' => 66.67)
      expect(payload['stale']).to eq('L')
    end
  end
end
