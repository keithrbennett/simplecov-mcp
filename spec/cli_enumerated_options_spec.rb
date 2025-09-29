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
      { argv: ['--sort-order', 'a', 'list'],          var: :@sort_order, expected: 'ascending' },
      { argv: ['--sort-order', 'd', 'list'],          var: :@sort_order, expected: 'descending' },
      { argv: ['--sort-order', 'ascending', 'list'],  var: :@sort_order, expected: 'ascending' },
      { argv: ['--sort-order', 'descending', 'list'], var: :@sort_order, expected: 'descending' },

      { argv: ['--source', 'f', 'summary', 'lib/foo.rb'],      var: :@source_mode, expected: 'full' },
      # For optional arg, use =-form to pass a value
      { argv: ['--source=u', 'summary', 'lib/foo.rb'],         var: :@source_mode, expected: 'uncovered' },
      { argv: ['--source=full', 'summary', 'lib/foo.rb'],      var: :@source_mode, expected: 'full' },
      { argv: ['--source=uncovered', 'summary', 'lib/foo.rb'], var: :@source_mode, expected: 'uncovered' },

      { argv: ['-S', 'e', 'list'], var: :@stale_mode, expected: 'error' },
      { argv: ['-S', 'o', 'list'], var: :@stale_mode, expected: 'off' },

      { argv: ['--error-mode', 'off', 'list'], var: :@error_mode, expected: :off },
      { argv: ['--error-mode', 'on', 'list'],  var: :@error_mode, expected: :on },
      { argv: ['--error-mode', 't', 'list'],   var: :@error_mode, expected: :on_with_trace }
    ]

    cases.each do |c|
      it "parses #{c[:argv].join(' ')}" do
        cli = parse!(c[:argv])
        expect(cli.instance_variable_get(c[:var])).to eq(c[:expected])
      end
    end
  end

  describe 'rejects invalid values' do
    invalid_cases = [
      { argv: ['--sort-order', 'asc', 'list'] },
      { argv: ['--source=x', 'summary', 'lib/foo.rb'] },
      { argv: ['-S', 'x', 'list'] },
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
  end
end
