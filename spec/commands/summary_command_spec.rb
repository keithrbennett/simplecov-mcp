# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::SummaryCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = 'coverage'
    cli_context.config.format = :table
    cli_context.config.source_mode = nil
  end

  describe '#execute' do
    it 'prints a coverage summary line with a relative path' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute(['lib/foo.rb'])
        output = stdout.string
      end

      # Expect table format with box-drawing characters
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('66.67%')
      expect(output).to include('2')
      expect(output).to include('3')
      expect(output).to include('lib/foo.rb')
    end

    it 'emits JSON when requested, including stale metadata' do
      cli_context.config.format = :json
      stub_staleness_check('L')

      json_output = nil
      silence_output do |stdout, _stderr|
        command.execute(['lib/foo.rb'])
        json_output = stdout.string
      end

      payload = JSON.parse(json_output)
      expect(payload['file']).to eq('lib/foo.rb')
      expect(payload['summary']).to include('covered' => 2, 'total' => 3, 'percentage' => 66.67)
      expect(payload).to have_key('stale')
      expect(payload['stale']).to eq('L')
    end
  end
end
