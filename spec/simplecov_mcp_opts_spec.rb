# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SIMPLECOV_MCP_OPTS Environment Variable' do
  let(:cli) { SimpleCovMcp::CoverageCLI.new }

  around do |example|
    old_env = ENV['SIMPLECOV_MCP_OPTS']
    ENV.delete('SIMPLECOV_MCP_OPTS')
    example.run
    if old_env
      ENV['SIMPLECOV_MCP_OPTS'] = old_env
    else
      ENV.delete('SIMPLECOV_MCP_OPTS')
    end
  end

  describe 'CLI option parsing from environment' do
    it 'parses simple options from SIMPLECOV_MCP_OPTS' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--error-mode off --json'

      begin
        silence_output { cli.send(:run, ['summary', 'lib/foo.rb']) }
      rescue Exception => e
        # Expected to fail due to missing file, but options should be parsed
        puts "DEBUG: Caught exception: #{e.class}: #{e.message}" if ENV['DEBUG']
      end

      expect(cli.instance_variable_get(:@error_mode)).to eq(:off)
      expect(cli.instance_variable_get(:@json)).to be true
    end

    it 'handles quoted options with spaces' do
      test_path = File.join(Dir.tmpdir, 'test path with spaces', '.resultset.json')
      ENV['SIMPLECOV_MCP_OPTS'] = "--resultset \"#{test_path}\""

      # Stub exit method to prevent process termination
      allow_any_instance_of(Object).to receive(:exit)

      cli.send(:run, ['--help'])

      expect(cli.instance_variable_get(:@resultset)).to eq(test_path)
    end

    it 'command line arguments override environment options' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--error-mode off'

      begin
        silence_output { cli.send(:run, ['--error-mode', 'on_with_trace', 'summary', 'lib/foo.rb']) }
      rescue SystemExit, SimpleCovMcp::Error
        # Expected to fail, but options should be parsed
      end

      # Command line should override environment
      expect(cli.instance_variable_get(:@error_mode)).to eq(:on_with_trace)
    end

    it 'handles malformed SIMPLECOV_MCP_OPTS gracefully' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--option "unclosed quote'

      # Should catch the ConfigurationError and exit cleanly
      _out, _err, status = run_cli_with_status('summary', 'lib/foo.rb')
      expect(status).not_to eq(0)
    end

    it 'returns empty array when SIMPLECOV_MCP_OPTS is not set' do
      # ENV is already cleared by around block
      opts = cli.send(:parse_env_opts)
      expect(opts).to eq([])
    end

    it 'returns empty array when SIMPLECOV_MCP_OPTS is empty' do
      ENV['SIMPLECOV_MCP_OPTS'] = ''
      opts = cli.send(:parse_env_opts)
      expect(opts).to eq([])
    end
  end

  describe 'CLI mode detection with SIMPLECOV_MCP_OPTS' do
    it 'respects --force-cli from environment variable' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--force-cli'

      # This would normally be MCP mode (no TTY, no subcommand)
      allow(STDIN).to receive(:tty?).and_return(false)

      env_opts = SimpleCovMcp.send(:parse_env_opts_for_mode_detection)
      full_argv = env_opts + []

      expect(SimpleCovMcp.send(:should_run_cli?, full_argv)).to be true
    end

    it 'handles parse errors gracefully in mode detection' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--option "unclosed quote'

      # Should return empty array and not crash
      opts = SimpleCovMcp.send(:parse_env_opts_for_mode_detection)
      expect(opts).to eq([])
    end
  end

  describe 'integration with actual CLI usage' do
    it 'works end-to-end with --resultset option' do
      test_resultset = File.join(Dir.tmpdir, 'test_coverage', '.resultset.json')
      ENV['SIMPLECOV_MCP_OPTS'] = "--resultset #{test_resultset} --json"

      allow_any_instance_of(Object).to receive(:exit)

      expect {
        silence_output { cli.send(:run, ['--help']) }
      }.not_to raise_error

      expect(cli.instance_variable_get(:@resultset)).to eq(test_resultset)
      expect(cli.instance_variable_get(:@json)).to be true
    end
  end
end