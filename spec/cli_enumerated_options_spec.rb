# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CLI enumerated option parsing' do
  def parse!(argv)
    cli = SimpleCovMcp::CoverageCLI.new
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

      { argv: ['--source=f', 'summary', 'lib/foo.rb'], accessor: :source_mode, expected: :full },
      { argv: ['--source=u', 'summary', 'lib/foo.rb'], accessor: :source_mode,
        expected: :uncovered },
      { argv: ['--source=full', 'summary', 'lib/foo.rb'], accessor: :source_mode, expected: :full },
      { argv: ['--source=uncovered', 'summary', 'lib/foo.rb'], accessor: :source_mode,
        expected: :uncovered },

      { argv: ['-S', 'e', 'list'], accessor: :staleness, expected: :error },
      { argv: ['-S', 'o', 'list'], accessor: :staleness, expected: :off },
      { argv: ['--staleness', 'e', 'list'], accessor: :staleness, expected: :error },
      { argv: ['--staleness', 'o', 'list'], accessor: :staleness, expected: :off },

      { argv: ['--error-mode', 'off', 'list'], accessor: :error_mode, expected: :off },
      { argv: ['--error-mode', 'log', 'list'], accessor: :error_mode, expected: :log },
      { argv: ['--error-mode', 'debug', 'list'], accessor: :error_mode, expected: :debug },
      { argv: ['--error-mode', 'on', 'list'], accessor: :error_mode, expected: :log },
      { argv: ['--error-mode', 't', 'list'], accessor: :error_mode, expected: :debug }
    ]

    cases.each do |c|
      it "parses #{c[:argv].join(' ')}" do
        cli = parse!(c[:argv])
        expect(cli.config.public_send(c[:accessor])).to eq(c[:expected])
      end
    end
  end

  describe 'rejects invalid values' do
    invalid_cases = [
      { argv: ['--sort-order', 'asc', 'list'] },
      { argv: ['--source=x', 'summary', 'lib/foo.rb'] },
      { argv: ['-S', 'x', 'list'] },
      { argv: ['--staleness', 'x', 'list'] },
      { argv: ['--error-mode', 'bad', 'list'] }
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
    it 'exits 1 when -S is provided without a value' do
      _out, err, status = run_cli_with_status('-S', 'list')
      expect(status).to eq(1)
      expect(err).to include('invalid argument')
    end

    it 'exits 1 when --staleness is provided without a value' do
      _out, err, status = run_cli_with_status('--staleness', 'list')
      expect(status).to eq(1)
      expect(err).to include('invalid argument')
    end
  end
end
