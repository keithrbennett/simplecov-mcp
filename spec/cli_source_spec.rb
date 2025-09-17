# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES / 'project1').to_s }

  def run_cli_with_status(*argv)
    cli = described_class.new
    status = nil
    out_str = err_str = nil
    silence_output do |out, err|
      begin
        cli.run(argv.flatten)
        status = 0
      rescue SystemExit => e
        status = e.status
      end
      out_str = out.string
      err_str = err.string
    end
    [out_str, err_str, status]
  end

  it 'renders uncovered source without error for fixture file' do
    out, err, status = run_cli_with_status(
      'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=uncovered', '--source-context', '1', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to include('File: lib/foo.rb')
    expect(out).to include('Uncovered lines: 2')
    # Accept either rendered source table or fallback message
    expect(out).to satisfy { |s| s.include?('Line') || s.include?('[source not available]') }
  end
end
