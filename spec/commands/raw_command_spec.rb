# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::RawCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = 'coverage'
    cli_context.config.format = :table
  end

  describe '#execute' do
    it 'prints the raw coverage lines for the requested file' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute(['lib/foo.rb'])
        output = stdout.string
      end

      expect(output).to include('File: lib/foo.rb')
      # Example match: "[1, 0, nil, 2]"
      expect(output).to match(/\[1,\s0,\snil,\s2\]/)
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
      expect(payload['lines']).to eq([1, 0, nil, 2])
      expect(payload['stale']).to eq('L')
    end
  end
end
