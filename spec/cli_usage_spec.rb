# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES / 'project1').to_s }

  it 'errors with usage when summary path is missing' do
    _out, err, status = run_cli_with_status('summary', '--root', root, '--resultset', 'coverage')
    expect(status).to eq(1)
    expect(err).to include('Usage: simplecov-mcp summary <path>')
  end

  it 'treats unknown subcommand as no subcommand and prints default table' do
    out, err, status = run_cli_with_status('bogus', '--root', root, '--resultset', 'coverage')
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to include('File')
    expect(out).to include('lib/foo.rb')
  end

  it 'list honors stale=error and tracked_globs by exiting 1 when project is stale' do
    tmp = File.join(root, 'lib', 'brand_new_file_for_cli_usage_spec.rb')
    begin
      File.write(tmp, "# new file\n")
      _out, err, status = run_cli_with_status('list', '--root', root, '--resultset', 'coverage', '--stale', 'error', '--tracked-globs', 'lib/**/*.rb')
      expect(status).to eq(1)
      expect(err).to include('Coverage data stale (project)')
    ensure
      File.delete(tmp) if File.exist?(tmp)
    end
  end

  it 'list with stale=off prints table and exits 0' do
    out, err, status = run_cli_with_status('list', '--root', root, '--resultset', 'coverage', '--stale', 'off')
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to include('File')
    expect(out).to include('lib/foo.rb')
  end
end
