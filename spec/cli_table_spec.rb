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
end
