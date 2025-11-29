# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CLI format option' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def run_cli(*argv)
    cli = SimpleCovMcp::CoverageCLI.new
    output = nil
    silence_output do |stdout, _stderr|
      cli.send(:run, argv)
      output = stdout.string
    end
    output
  end

  describe 'format normalization' do
    it 'normalizes short format aliases' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'j', 'list')
      expect(output).to include('"files":', '"percentage":')
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'normalizes table format' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 't', 'list')
      expect(output).to include('File', '%')  # Table output
      expect(output).not_to include('"files"')  # Not JSON
    end

    it 'supports yaml format' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'y', 'list')
      expect(output).to include('---', 'files:', 'file:')
    end

    it 'supports awesome_print format' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'a', 'list')
      # AwesomePrint output contains colored/formatted structure
      expect(output).to match(/:files|"files"/)
    end
  end

  describe 'option order requirements' do
    it 'works with format option before subcommand' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'json', 'list')
      data = JSON.parse(output)
      expect(data).to have_key('files')
    end

    it 'does NOT parse format option after subcommand' do
      # This should output table format because --format comes after 'list'
      output = run_cli('--root', root, '--resultset', 'coverage', 'list', '--format', 'json')
      expect(output).to include('File', '%')  # Table output
      expect(output).not_to include('"files"')  # Not JSON
    end
  end

  describe 'format with different subcommands' do
    it 'works with totals subcommand' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'json', 'totals')
      data = JSON.parse(output)
      expect(data).to have_key('lines')
      expect(data).to have_key('percentage')
    end

    it 'works with summary subcommand' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'json',
        'summary', 'lib/foo.rb')
      data = JSON.parse(output)
      expect(data).to have_key('file')
      expect(data).to have_key('summary')
    end

    it 'works with version subcommand' do
      output = run_cli('--format', 'json', 'version')
      data = JSON.parse(output)
      expect(data).to have_key('version')
      expect(data).to have_key('gem_root')
    end
  end
end
