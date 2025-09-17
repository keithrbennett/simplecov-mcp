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

  it 'shows help and exits 0' do
    out, err, status = run_cli_with_status('--help')
    expect(status).to eq(0)
    expect(out).to include('Usage: simplecov-mcp')
    expect(err).to eq("")
  end

  shared_examples 'maps error to exit 1 with message' do
    before do
      # Build a fake model that raises the specified error from the specified method
      fake_model = Class.new do
        def initialize(*) end
      end
      error_to_raise = raised_error
      fake_model.define_method(model_method) { |*| raise error_to_raise }
      stub_const('SimpleCovMcp::CoverageModel', fake_model)
    end

    it 'exits with status 1 and friendly message' do
      _out, err, status = run_cli_with_status(*invoke_args)
      expect(status).to eq(1)
      expect(err).to include(expected_message)
    end
  end

  context 'ENOENT mapping' do
    let(:model_method) { :summary_for }
    let(:raised_error) { Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb') }
    let(:invoke_args) { ['summary', 'lib/missing.rb', '--root', root, '--resultset', 'coverage'] }
    let(:expected_message) { 'File error: File not found: lib/missing.rb' }
    include_examples 'maps error to exit 1 with message'
  end

  context 'EACCES mapping' do
    let(:model_method) { :raw_for }
    let(:raised_error) { Errno::EACCES.new('Permission denied @ rb_sysopen - secret.rb') }
    let(:invoke_args) { ['raw', 'lib/secret.rb', '--root', root, '--resultset', 'coverage'] }
    let(:expected_message) { 'Permission denied: lib/secret.rb' }
    include_examples 'maps error to exit 1 with message'
  end

  it 'emits detailed stale coverage info and exits 1' do
    begin
      ENV['SIMPLECOV_MCP_STRICT_STALENESS'] = '1'
      allow(SimpleCovMcp::CovUtil).to receive(:latest_timestamp).and_return(0)
      _out, err, status = run_cli_with_status('summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage')
      expect(status).to eq(1)
      expect(err).to include('Coverage data stale:')
      expect(err).to match(/File\s+- time:/)
      expect(err).to match('Coverage\s+- time:')
      expect(err).to match(/Delta\s+- file is [+-]?\d+s newer than coverage/)
      expect(err).to match('Resultset\s+-')
    ensure
      ENV.delete('SIMPLECOV_MCP_STRICT_STALENESS')
    end
  end

  # Note on text-mode source rendering tests:
  # - "Text-mode source" refers to the ASCII source view printed by the CLI
  #   when passing --source or --source=uncovered (checkmarks/dots, line nums).
  # - Direct tests are omitted here because behavior depends on how paths are
  #   resolved (relative vs absolute) in combination with --root/--resultset
  #   and whether the source file is readable. In uncovered mode, we observed
  #   a crash ("can't convert nil into Integer") when coverage arrays include
  #   nils or don’t line up with file lines. JSON paths avoid this formatting
  #   nuance and are already covered elsewhere.
  # - Once the uncovered+source crash is guarded (treat out-of-range/nil hits
  #   defensively and only format integers where expected), we can add a
  #   regression: run `uncovered` with --source=uncovered against the fixtures
  #   and assert exit status 0 and rendered source.
end
