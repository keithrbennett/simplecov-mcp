# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::TotalsCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = 'coverage'
    cli_context.config.format = :table
  end

  describe '#execute' do
    it 'prints aggregated totals for the project' do
    output = nil

    silence_output do |stdout, _stderr|
      command.execute([])
      output = stdout.string
    end

    # Expect table format with box-drawing characters
    expect(output).to include('│')  # Box drawing character
    expect(output).to include('Lines')
    expect(output).to include('50.00%')
  end

  it 'emits JSON when requested' do
      cli_context.config.format = :json

      json_output = nil
      silence_output do |stdout, _stderr|
        command.execute([])
        json_output = stdout.string
      end

      payload = JSON.parse(json_output)
      expect(payload['lines']).to include('total' => 6, 'covered' => 3, 'uncovered' => 3)
      expect(payload['files']).to include('total' => 2)
      expect(payload['files']['ok'] + payload['files']['stale']).to eq(payload['files']['total'])
      expect(payload).to include('percentage')
    end

    it 'raises when unexpected arguments are provided' do
      expect do
        command.execute(['extra'])
      end.to raise_error(SimpleCovMcp::UsageError, include('totals'))
    end
  end
end
