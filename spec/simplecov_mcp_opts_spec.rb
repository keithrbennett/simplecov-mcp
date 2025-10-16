# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SIMPLECOV_MCP_OPTS Environment Variable' do
  let(:cli) { SimpleCovMcp::CoverageCLI.new }

  around do |example|
    original_value = ENV['SIMPLECOV_MCP_OPTS']
    example.run
  ensure
    ENV['SIMPLECOV_MCP_OPTS'] = original_value
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

      expect(cli.config.error_mode).to eq(:off)
      expect(cli.config.json).to be true
    end

    it 'handles quoted options with spaces' do
      test_path = File.join(Dir.tmpdir, 'test path with spaces', '.resultset.json')
      ENV['SIMPLECOV_MCP_OPTS'] = "--resultset \"#{test_path}\""

      # Stub exit method to prevent process termination
      allow_any_instance_of(Object).to receive(:exit)

      # silence_output captures the expected error message from the CLI trying to
      # load the (non-existent) resultset, preventing it from leaking to the console.
      silence_output do
        cli.send(:run, ['--help'])
      end

      expect(cli.config.resultset).to eq(test_path)
    end

    it 'supports setting log-file to stdout from environment' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--log-file stdout'

      allow_any_instance_of(Object).to receive(:exit)

      silence_output do
        cli.send(:run, ['--help'])
      end

      expect(cli.config.log_file).to eq('stdout')
    end

    it 'command line arguments override environment options' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--error-mode off'

      begin
        silence_output { cli.send(:run, ['--error-mode', 'trace', 'summary', 'lib/foo.rb']) }
      rescue SystemExit, SimpleCovMcp::Error
        # Expected to fail, but options should be parsed
      end

      # Command line should override environment
      expect(cli.config.error_mode).to eq(:trace)
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
      stdin = double('stdin', tty?: false)

      env_opts = SimpleCovMcp.send(:parse_env_opts_for_mode_detection)
      full_argv = env_opts + []

      expect(SimpleCovMcp::ModeDetector.cli_mode?(full_argv, stdin: stdin)).to be true
    end

    it 'handles parse errors gracefully in mode detection' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--option "unclosed quote'

      # Should return empty array and not crash
      opts = SimpleCovMcp.send(:parse_env_opts_for_mode_detection)
      expect(opts).to eq([])
    end

    it 'actually runs CLI when --force-cli is in SIMPLECOV_MCP_OPTS' do
      ENV['SIMPLECOV_MCP_OPTS'] = '--force-cli'

      # Mock STDIN to not be a TTY (would normally trigger MCP server mode)
      allow(STDIN).to receive(:tty?).and_return(false)

      # Stub exit to prevent process termination
      allow_any_instance_of(Object).to receive(:exit)

      # Run with --help which should produce help output
      output = nil
      silence_output do |out, err|
        SimpleCovMcp.run(['--help'])
        output = out.string + err.string
      end

      # Verify CLI actually ran by checking for help text
      expect(output).to include('Usage:')
      expect(output).to include('simplecov-mcp')
    end

    it 'actually runs MCP server mode when no CLI indicators present' do
      ENV['SIMPLECOV_MCP_OPTS'] = ''

      # Mock STDIN to not be a TTY and to provide valid JSON-RPC
      allow(STDIN).to receive(:tty?).and_return(false)

      # Provide a minimal JSON-RPC request that the server can handle
      json_request = JSON.generate({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'test', version: '1.0' }
        }
      })

      allow(STDIN).to receive(:gets).and_return(json_request, nil)

      # Capture output to verify MCP server response
      output = nil
      silence_output do |out, err|
        SimpleCovMcp.run([])
        output = out.string + err.string
      end

      # Verify MCP server ran by checking for JSON-RPC response
      expect(output).to include('"jsonrpc"')
      expect(output).to include('"result"')
    end
  end

  describe 'integration with actual CLI usage' do
    it 'works end-to-end with --resultset option' do
      test_resultset = File.join(Dir.tmpdir, 'test_coverage', '.resultset.json')
      ENV['SIMPLECOV_MCP_OPTS'] = "--resultset #{test_resultset} --json"

      allow_any_instance_of(Object).to receive(:exit)

      expect do
        silence_output { cli.send(:run, ['--help']) }
      end.not_to raise_error

      expect(cli.config.resultset).to eq(test_resultset)
      expect(cli.config.json).to be true
    end
  end
end
