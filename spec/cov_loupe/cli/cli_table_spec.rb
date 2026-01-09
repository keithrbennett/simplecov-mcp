# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI do
  def run_cli(*argv)
    run_fixture_cli_output(*argv)
  end

  it 'prints default table when no subcommand is given' do
    output = run_cli

    # Contains a header row and at least one data row with expected columns
    expect(output).to include('File', 'Covered', 'Total', 'lib/foo.rb', 'lib/bar.rb')
  end

  describe 'list command exclusions display' do
    it 'shows missing tracked files after the table' do
      output = run_cli('--tracked-globs', 'lib/**/*.rb', 'list')

      aggregate_failures do
        # Table should still be present with files that have coverage
        expect(output).to include('File', 'lib/foo.rb', 'lib/bar.rb')

        # Should show exclusions summary for files matching glob but without coverage
        expect(output).to include('Files excluded from coverage:')
        expect(output).to include('Missing tracked files')
        expect(output).to include('lib/uncovered_file.rb')
      end
    end

    it 'does not show exclusions when there are none' do
      # Using a very specific glob that only matches files with coverage
      output = run_cli('--tracked-globs', 'lib/foo.rb', 'list')

      aggregate_failures do
        expect(output).to include('File')
        expect(output).not_to include('Files excluded from coverage:')
        expect(output).not_to include('Missing tracked files')
      end
    end
  end
end
