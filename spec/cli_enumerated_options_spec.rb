# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CLI enumerated option parsing' do
  def parse!(argv)
    cli = CovLoupe::CoverageCLI.new
    cli.send(:parse_options!, argv.dup)
    cli
  end

  describe 'accepts short and long forms' do
    cases = [
      { argv: ['--sort-order', 'a', 'list'], accessor: :sort_order, expected: :ascending },
      { argv: ['--sort-order', 'd', 'list'], accessor: :sort_order, expected: :descending },
      { argv: ['--sort-order', 'ascending', 'list'], accessor: :sort_order, expected: :ascending },
      { argv: ['--sort-order', 'descending', 'list'], accessor: :sort_order,
        expected: :descending },

      { argv: ['--source', 'f', 'summary', 'lib/foo.rb'], accessor: :source_mode, expected: :full },
      { argv: ['--source', 'u', 'summary', 'lib/foo.rb'], accessor: :source_mode,
        expected: :uncovered },
      { argv: ['--source', 'full', 'summary', 'lib/foo.rb'], accessor: :source_mode,
        expected: :full },
      { argv: ['--source', 'uncovered', 'summary', 'lib/foo.rb'], accessor: :source_mode,
        expected: :uncovered },

      { argv: ['-S', 'yes', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale', 'yes', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=false', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=yes', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale', 'no', 'list'], accessor: :raise_on_stale, expected: false },

      { argv: ['--error-mode', 'off', 'list'], accessor: :error_mode, expected: :off },
      { argv: ['--error-mode', 'o', 'list'], accessor: :error_mode, expected: :off },
      { argv: ['--error-mode', 'log', 'list'], accessor: :error_mode, expected: :log },
      { argv: ['--error-mode', 'debug', 'list'], accessor: :error_mode, expected: :debug }
    ]

    cases.each do |c|
      it "parses #{c[:argv].join(' ')}" do
        cli = parse!(c[:argv])
        expect(cli.config.public_send(c[:accessor])).to eq(c[:expected])
      end
    end
  end

  describe 'boolean options with BooleanType accept various values' do
    boolean_cases = [
      # --raise-on-stale with = syntax
      { argv: ['--raise-on-stale=yes', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=no', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=true', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=false', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=on', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=off', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=y', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=n', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=+', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=-', 'list'], accessor: :raise_on_stale, expected: false },
      { argv: ['--raise-on-stale=1', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale=0', 'list'], accessor: :raise_on_stale, expected: false },

      # --raise-on-stale with space syntax
      { argv: ['--raise-on-stale', 'yes', 'list'], accessor: :raise_on_stale, expected: true },
      { argv: ['--raise-on-stale', 'no', 'list'], accessor: :raise_on_stale, expected: false },

      # --color with various values
      { argv: ['--color=yes', 'list'], accessor: :color, expected: true },
      { argv: ['--color=no', 'list'], accessor: :color, expected: false },
      { argv: ['--color=true', 'list'], accessor: :color, expected: true },
      { argv: ['--color=false', 'list'], accessor: :color, expected: false },
      { argv: ['--color', 'on', 'list'], accessor: :color, expected: true },
      { argv: ['--color', 'off', 'list'], accessor: :color, expected: false },

    ]

    boolean_cases.each do |c|
      it "parses #{c[:argv].join(' ')}" do
        cli = parse!(c[:argv])
        expect(cli.config.public_send(c[:accessor])).to eq(c[:expected])
      end
    end
  end

  describe 'rejects invalid values' do
    invalid_cases = [
      { argv: ['--sort-order', 'asc', 'list'] },
      { argv: ['--source', 'x', 'summary', 'lib/foo.rb'] },
      { argv: ['--error-mode', 'bad', 'list'] },
      { argv: ['--error-mode', 'on', 'list'] },
      { argv: ['--error-mode', 'trace', 'list'] }
    ]

    invalid_cases.each do |c|
      it "exits 1 for #{c[:argv].join(' ')}" do
        _out, err, status = run_cli_with_status(*c[:argv])
        expect(status).to eq(1)
        expect(err).to include('Error:')
        expect(err).to include('invalid argument')
      end
    end
  end

  describe 'missing value hints' do
    it 'exits 1 when --source is provided without a value' do
      _out, err, status = run_cli_with_status('--source', 'summary', 'lib/foo.rb')
      expect(status).to eq(1)
      # Depending on OptParse implementation for required argument, it might say "missing argument"
      # But usually it consumes next arg. If 'summary' is consumed as argument for source:
      # normalize_source_mode('summary') -> raises InvalidArgument.
      expect(err).to include('invalid argument')
    end
  end
end
