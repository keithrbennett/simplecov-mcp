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

        expect(output).to include('Tracked globs:', 'Totals', '│', 'Lines', '50.00%')
      end

      it 'omits without coverage breakdown when tracking is disabled' do
        # Disable tracked globs to ensure tracking is off
        cli_context.config.tracked_globs = []
        output = capture_command_output(command, [])

        expect(output).to include('Tracked globs: (tracking disabled)')
        expect(output).not_to include('Without coverage')
      end

      it 'shows file breakdown with stale and without coverage details' do
        # Mock the presenter to return data with stale and without coverage counts
        presenter_double = instance_double(CovLoupe::Presenters::ProjectTotalsPresenter)
        allow(presenter_double).to receive(:absolute_payload).and_return(
          'lines' => {
            'total' => 6,
            'covered' => 3,
            'uncovered' => 3,
            'percent_covered' => 50.0
          },
          'tracking' => {
            'enabled' => true,
            'globs' => ['lib/**/*.rb']
          },
          'files' => {
            'total' => 4,
            'with_coverage' => {
              'total' => 3,
              'ok' => 2,
              'stale' => {
                'total' => 1,
                'by_type' => {
                  'missing_from_disk' => 0,
                  'newer' => 1,
                  'length_mismatch' => 0,
                  'unreadable' => 0
                }
              }
            },
            'without_coverage' => {
              'total' => 1,
              'by_type' => {
                'missing_from_coverage' => 1,
                'unreadable' => 0,
                'skipped' => 0
              }
            }
          }
        )
        allow(CovLoupe::Presenters::ProjectTotalsPresenter).to receive(:new)
          .and_return(presenter_double)

        output = capture_command_output(command, [])

        aggregate_failures do
          expect(output).to include('File breakdown:')
          expect(output).to include('With coverage: 3 total, 2 ok, 1 stale')
          expect(output).to include('newer than coverage = 1')
          expect(output).to include('Without coverage: 1 total')
          expect(output).to include('Missing from coverage = 1')
        end
      end
    end

    it_behaves_like 'a command with formatted output', [], %w[lines tracking files]

    it 'raises when unexpected arguments are provided' do
      expect do
        command.execute(%w[extra])
      end.to raise_error(CovLoupe::UsageError, include('totals'))
    end
  end
end
