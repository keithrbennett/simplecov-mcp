# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe CovLoupe::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  it 'errors with usage when summary path is missing' do
    _out, err, status = run_fixture_cli_with_status('summary')
    expect(status).to eq(1)
    expect(err).to include('Usage: cov-loupe summary <path>')
  end

  it 'errors with meaningful message for unknown subcommand' do
    _out, err, status = run_fixture_cli_with_status('bogus')
    expect(status).to eq(1)
    expect(err).to include("Unknown subcommand: 'bogus'", 'Valid subcommands:')
  end

  it 'list honors stale=error and tracked_globs by exiting 1 when project is stale' do
    Tempfile.create(%w[brand_new_file_for_cli_usage_spec .rb], File.join(root, 'lib')) do |f|
      f.write("# new file\n")
      f.flush
      _out, err, status = run_fixture_cli_with_status(
        '--raise-on-stale', 'true', '--tracked-globs', 'lib/**/*.rb', 'list'
      )
      expect(status).to eq(1)
      expect(err).to include('Coverage data stale (project)')
    end
  end

  it 'list with stale=off prints table and exits 0' do
    out, err, status = run_fixture_cli_with_status('--raise-on-stale=false', 'list')
    expect(status).to eq(0)
    expect(err).to eq('')
    expect(out).to include('File', 'lib/foo.rb')
  end
end
