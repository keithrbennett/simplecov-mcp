# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/formatted_command_examples'

RSpec.describe CovLoupe::Commands::TotalsCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { CovLoupe::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = FIXTURE_PROJECT1_RESULTSET_PATH
    cli_context.config.format = :table
  end

  describe '#execute' do
    context 'with table format' do
      it 'prints aggregated totals for the project' do
        output = capture_command_output(command, [])

        expect(output).to include('│', 'Lines', '50.00%')
      end
    end

    it_behaves_like 'a command with formatted output', [], %w[lines files percentage]

    it 'raises when unexpected arguments are provided' do
      expect do
        command.execute(%w[extra])
      end.to raise_error(CovLoupe::UsageError, include('totals'))
    end
  end
end
