# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe SimpleCovMcp::CoverageCLI, 'success predicate' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def with_temp_predicate(content)
    Tempfile.create(['predicate', '.rb']) do |file|
      file.write(content)
      file.flush
      yield file.path
    end
  end

  describe '--success-predicate' do
    it 'exits 0 when predicate returns truthy value' do
      with_temp_predicate("->(model) { true }\n") do |path|
        _out, _err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(0)
      end
    end

    it 'exits 1 when predicate returns falsy value' do
      with_temp_predicate("->(model) { false }\n") do |path|
        _out, _err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(1)
      end
    end

    it 'exits 2 when predicate raises an error' do
      with_temp_predicate("->(model) { raise 'Boom!' }\n") do |path|
        _out, err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(2)
        expect(err).to include('Success predicate error: Boom!')
      end
    end

    it 'shows backtrace when predicate errors with --error-mode trace' do
      with_temp_predicate("->(model) { raise 'Boom!' }\n") do |path|
        _out, err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage',
          '--error-mode', 'trace'
        )
        expect(status).to eq(2)
        expect(err).to include('Success predicate error: Boom!')
        # With trace mode, should show backtrace
        expect(err).to match(/predicate.*\.rb:\d+/)
      end
    end

    it 'exits 2 when predicate file is not found' do
      _out, err, status = run_cli_with_status(
        '--success-predicate', '/nonexistent/predicate.rb',
        '--root', root,
        '--resultset', 'coverage'
      )
      expect(status).to eq(2)
      expect(err).to include('Success predicate file not found')
    end

    it 'exits 2 when predicate has syntax error' do
      with_temp_predicate("-> { this is invalid syntax\n") do |path|
        _out, err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(2)
        expect(err).to include('Syntax error in success predicate file')
      end
    end

    it 'exits 2 when predicate is not callable' do
      with_temp_predicate("42\n") do |path|
        _out, err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(2)
        expect(err).to include('Success predicate must be callable')
      end
    end

    it 'provides model to predicate that can query coverage' do
      # Test that the predicate receives a working CoverageModel
      with_temp_predicate(<<~RUBY) do |path|
        ->(model) do
          # Access coverage data via the model
          summary = model.summary_for('lib/foo.rb')
          summary['summary']['pct'] > 50  # Should be true for foo.rb
        end
      RUBY
        _out, _err, status = run_cli_with_status(
          '--success-predicate', path,
          '--root', root,
          '--resultset', 'coverage'
        )
        expect(status).to eq(0)
      end
    end
  end

  describe 'run_subcommand error handling' do
    it 'handles generic errors in subcommands' do
      # Force a generic error in the command execution
      fake_command_class = Class.new do
        def initialize(_cli); end

        def execute(_args)
          raise StandardError, 'Generic error in command'
        end
      end

      allow(SimpleCovMcp::Commands::CommandFactory).to receive(:create).and_return(fake_command_class.new(nil))

      _out, err, status = run_cli_with_status('summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage')

      expect(status).to eq(1)
      expect(err).to include('An unexpected error occurred')
    end
  end
end
