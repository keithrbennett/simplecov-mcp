# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI do
  def run_cli(*argv)
    run_fixture_cli_output(*argv)
  end

  it 'prints default table when no subcommand is given' do
    output = run_cli

    # Contains a header row and at least one data row with expected columns
    expect(output).to include('File')
    expect(output).to include('Covered')
    expect(output).to include('Total')

    # Should list fixture files from the demo project
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')
  end
end
