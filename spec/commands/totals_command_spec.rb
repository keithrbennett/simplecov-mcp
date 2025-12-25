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

      it 'does not show excluded rows when no files are excluded' do
        # Disable tracked globs to ensure no missing files are detected
        cli_context.config.tracked_globs = []
        output = capture_command_output(command, [])

        expect(output).not_to include('Excluded')
        expect(output).not_to include('Skipped')
      end

      it 'shows excluded files breakdown when files are excluded' do
        # Mock the presenter to return data with excluded files
        presenter_double = instance_double(CovLoupe::Presenters::ProjectTotalsPresenter)
        allow(presenter_double).to receive(:absolute_payload).and_return(
          'lines' => { 'total' => 6, 'covered' => 3, 'uncovered' => 3 },
          'percentage' => 50.0,
          'files' => { 'total' => 2, 'ok' => 2, 'stale' => 0 },
          'excluded_files' => {
            'skipped' => 1,
            'missing_tracked' => 0,
            'newer' => 2,
            'deleted' => 1
          }
        )
        allow(CovLoupe::Presenters::ProjectTotalsPresenter).to receive(:new)
          .and_return(presenter_double)

        output = capture_command_output(command, [])

        aggregate_failures do
          expect(output).to include('Excluded', '4')
          expect(output).to include('Skipped', '1')
          expect(output).to include('Newer', '2')
          expect(output).to include('Deleted', '1')
          expect(output).not_to include('Missing') # 0, so not shown
        end
      end
    end

    it_behaves_like 'a command with formatted output', [], %w[lines files percentage]

    context 'with JSON format' do
      before { cli_context.config.format = :json }

      it 'includes excluded_files metadata in output' do
        output = capture_command_output(command, [])
        data = JSON.parse(output)

        expect(data).to have_key('excluded_files')
        expect(data['excluded_files']).to be_a(Hash)
        expect(data['excluded_files'].keys).to contain_exactly(
          'skipped', 'missing_tracked', 'newer', 'deleted'
        )
      end
    end

    it 'raises when unexpected arguments are provided' do
      expect do
        command.execute(%w[extra])
      end.to raise_error(CovLoupe::UsageError, include('totals'))
    end
  end
end
