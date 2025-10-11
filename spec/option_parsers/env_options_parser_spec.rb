# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::OptionParsers::EnvOptionsParser do
  let(:parser) { described_class.new }

  around do |example|
    original_value = ENV['SIMPLECOV_MCP_OPTS']
    example.run
  ensure
    ENV['SIMPLECOV_MCP_OPTS'] = original_value
  end

  describe '#parse_env_opts' do
    context 'with valid inputs' do
      it 'returns empty array when environment variable is not set' do
        ENV.delete('SIMPLECOV_MCP_OPTS')
        expect(parser.parse_env_opts).to eq([])
      end

      it 'returns empty array when environment variable is empty string' do
        ENV['SIMPLECOV_MCP_OPTS'] = ''
        expect(parser.parse_env_opts).to eq([])
      end

      it 'returns empty array when environment variable contains only whitespace' do
        ENV['SIMPLECOV_MCP_OPTS'] = '   '
        expect(parser.parse_env_opts).to eq([])
      end

      it 'parses simple options correctly' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--error-mode off --json'
        expect(parser.parse_env_opts).to eq(['--error-mode', 'off', '--json'])
      end

      it 'handles quoted strings with spaces' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--resultset "/path/to/my file.json"'
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/to/my file.json'])
      end

      it 'handles complex shell escaping scenarios' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--resultset "/path/with spaces/file.json" --error-mode on'
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/with spaces/file.json', '--error-mode', 'on'])
      end

      it 'handles single quotes' do
        ENV['SIMPLECOV_MCP_OPTS'] = "--resultset '/path/with spaces/file.json'"
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/with spaces/file.json'])
      end

      it 'handles escaped characters' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--resultset /path/with\\ spaces/file.json'
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/with spaces/file.json'])
      end

      it 'handles mixed quoting styles' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--option1 "value with spaces" --option2 \'another value\''
        expect(parser.parse_env_opts).to eq(['--option1', 'value with spaces', '--option2', 'another value'])
      end
    end

    context 'with malformed inputs' do
      it 'raises ConfigurationError for unmatched double quotes' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--resultset "unterminated string'

        expect {
          parser.parse_env_opts
        }.to raise_error(SimpleCovMcp::ConfigurationError, /Invalid SIMPLECOV_MCP_OPTS format/)
      end

      it 'raises ConfigurationError for unmatched single quotes' do
        ENV['SIMPLECOV_MCP_OPTS'] = "--resultset 'unterminated string"

        expect {
          parser.parse_env_opts
        }.to raise_error(SimpleCovMcp::ConfigurationError, /Invalid SIMPLECOV_MCP_OPTS format/)
      end

      it 'raises ConfigurationError with descriptive message' do
        ENV['SIMPLECOV_MCP_OPTS'] = '--option "bad quote'

        expect {
          parser.parse_env_opts
        }.to raise_error(SimpleCovMcp::ConfigurationError) do |error|
          expect(error.message).to include('Invalid SIMPLECOV_MCP_OPTS format')
          expect(error.message).to include('Unmatched') # from Shellwords error
        end
      end

      it 'handles multiple quoting errors' do
        ENV['SIMPLECOV_MCP_OPTS'] = '"first "second "third'

        expect {
          parser.parse_env_opts
        }.to raise_error(SimpleCovMcp::ConfigurationError, /Invalid SIMPLECOV_MCP_OPTS format/)
      end
    end
  end

  describe '#pre_scan_error_mode' do
    let(:error_mode_normalizer) { parser.send(:method, :normalize_error_mode) }

    context 'when error-mode is found' do
      it 'extracts error-mode with space separator' do
        argv = ['--error-mode', 'trace', '--other-option']
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:trace)
      end

      it 'extracts error-mode with equals separator' do
        argv = ['--error-mode=off', '--other-option']
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:off)
      end

      it 'handles error-mode with equals but empty value' do
        argv = ['--error-mode=', '--other-option']
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        # Empty value after = explicitly returns nil (line 32)
        expect(result).to be_nil
      end

      it 'returns first error-mode when multiple are present' do
        argv = ['--error-mode', 'on', '--error-mode', 'off']
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:on)
      end
    end

    context 'when error-mode is not found' do
      it 'returns nil when no error-mode is present' do
        argv = ['--other-option', 'value']
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil for empty argv' do
        argv = []
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to be_nil
      end
    end

    context 'error handling during pre-scan' do
      it 'returns nil when normalizer raises an error' do
        faulty_normalizer = ->(value) { raise StandardError, "Intentional error" }
        argv = ['--error-mode', 'on']

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil when normalizer raises ArgumentError' do
        faulty_normalizer = ->(value) { raise ArgumentError, "Bad argument" }
        argv = ['--error-mode', 'on']

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil when normalizer raises RuntimeError' do
        faulty_normalizer = ->(value) { raise RuntimeError, "Runtime problem" }
        argv = ['--error-mode=off']

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end
    end
  end

  describe 'integration with ErrorHandlerFactory' do
    it 'maps trace alias to an accepted error_mode' do
      mode = parser.pre_scan_error_mode(['--error-mode', 'trace'])
      expect { SimpleCovMcp::ErrorHandlerFactory.for_cli(error_mode: mode) }.not_to raise_error
      expect(mode).to eq(:trace)
    end
  end

  describe '#normalize_error_mode (private)' do
    it 'normalizes "off" to :off' do
      expect(parser.send(:normalize_error_mode, 'off')).to eq(:off)
      expect(parser.send(:normalize_error_mode, 'OFF')).to eq(:off)
      expect(parser.send(:normalize_error_mode, 'Off')).to eq(:off)
    end

    it 'normalizes "on" to :on' do
      expect(parser.send(:normalize_error_mode, 'on')).to eq(:on)
      expect(parser.send(:normalize_error_mode, 'ON')).to eq(:on)
    end

    it 'normalizes "trace" to :trace' do
      expect(parser.send(:normalize_error_mode, 'trace')).to eq(:trace)
      expect(parser.send(:normalize_error_mode, 'TRACE')).to eq(:trace)
    end

    it 'normalizes "t" to :trace' do
      expect(parser.send(:normalize_error_mode, 't')).to eq(:trace)
      expect(parser.send(:normalize_error_mode, 'T')).to eq(:trace)
    end

    it 'defaults unknown values to :on' do
      expect(parser.send(:normalize_error_mode, 'unknown')).to eq(:on)
      expect(parser.send(:normalize_error_mode, 'invalid')).to eq(:on)
      expect(parser.send(:normalize_error_mode, '')).to eq(:on)
    end

    it 'handles nil by defaulting to :on' do
      expect(parser.send(:normalize_error_mode, nil)).to eq(:on)
    end
  end

  describe 'custom environment variable name' do
    it 'uses custom environment variable when specified' do
      custom_parser = described_class.new(env_var: 'CUSTOM_OPTS')
      ENV['CUSTOM_OPTS'] = '--error-mode off'

      expect(custom_parser.parse_env_opts).to eq(['--error-mode', 'off'])
    end

    it 'includes custom env var name in error messages' do
      custom_parser = described_class.new(env_var: 'MY_CUSTOM_VAR')
      ENV['MY_CUSTOM_VAR'] = '"bad quote'

      expect {
        custom_parser.parse_env_opts
      }.to raise_error(SimpleCovMcp::ConfigurationError, /Invalid MY_CUSTOM_VAR format/)
    end
  end
end
