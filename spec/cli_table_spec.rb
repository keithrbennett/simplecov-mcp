# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES / 'project1').to_s }

  def run_cli(*argv)
    cli = described_class.new
    silence_output do |out, _err|
      cli.run(argv.flatten)
      return out.string
    end
  end

  it 'prints default table when no subcommand is given' do
    output = run_cli('--root', root, '--resultset', 'coverage')

    # Contains a header row and at least one data row with expected columns
    expect(output).to include('File')
    expect(output).to include('Covered')
    expect(output).to include('Total')

    # Should list fixture files from the demo project
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')
  end
end
