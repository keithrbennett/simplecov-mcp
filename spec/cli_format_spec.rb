# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI, 'format option' do
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

    it 'shows helpful error when global option comes after subcommand' do
      _out, err, status = run_cli_with_status(
        '--root', root, '--resultset', 'coverage', 'list', '--format', 'json'
      )
      expect(status).to eq(1)
      expect(err).to include(
        'Global option(s) must come BEFORE the subcommand',
        'You used: list --format',
        'Correct: --format list',
        'Example:'
      )
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

  describe 'comprehensive misplaced option detection' do
    # Array of test cases: [description, args_array, expected_option_in_error]
    [
      # Short-form options
      ['short -f after list', ['list', '-f', 'json'], '-f'],
      ['short -r after totals', ['totals', '-r', '.resultset.json'], '-r'],
      ['short -R after list', ['list', '-R', '/tmp'], '-R'],
      ['short -o after list', ['list', '-o', 'a'], '-o'],
      ['short -s after list', ['list', '-s', 'full'], '-s'],
      ['short -S after list', ['list', '-S', 'error'], '-S'],

      # Long-form options
      ['--sort-order after list', ['list', '--sort-order', 'ascending'], '--sort-order'],
      ['--source after list', ['list', '--source', 'full'], '--source'],
      ['--staleness after totals', ['totals', '--staleness', 'error'], '--staleness'],
      ['--color after list', ['list', '--color'], '--color'],
      ['--no-color after list', ['list', '--no-color'], '--no-color'],
      ['--log-file after list', ['list', '--log-file', '/tmp/test.log'], '--log-file'],

      # Different subcommands
      ['option after version', ['version', '--format', 'json'], '--format'],
      ['option after summary', ['summary', 'lib/foo.rb', '--format', 'json'], '--format'],
      ['option after raw', ['raw', 'lib/foo.rb', '-f', 'json'], '-f'],
      ['option after detailed', ['detailed', 'lib/foo.rb', '-f', 'json'], '-f'],
      ['option after uncovered', ['uncovered', 'lib/foo.rb', '--root', '/tmp'], '--root']
    ].each do |desc, args, option|
      it "detects #{desc}" do
        _out, err, status = run_cli_with_status(*args)
        expect(status).to eq(1)
        expect(err).to include('Global option(s) must come BEFORE the subcommand')
        expect(err).to include(option)
      end
    end
  end
end
