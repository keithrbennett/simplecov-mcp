# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::OptionParsers::EnvOptionsParser do
  let(:parser) { described_class.new }

  around do |example|
    original_value = ENV['COV_LOUPE_OPTS']
    example.run
  ensure
    ENV['COV_LOUPE_OPTS'] = original_value
  end

  describe '#parse_env_opts' do
    context 'with valid inputs' do
      it 'returns empty array when environment variable is not set' do
        ENV.delete('COV_LOUPE_OPTS')
        expect(parser.parse_env_opts).to eq([])
      end

      it 'returns empty array when environment variable is empty string' do
        ENV['COV_LOUPE_OPTS'] = ''
        expect(parser.parse_env_opts).to eq([])
      end

      it 'returns empty array when environment variable contains only whitespace' do
        ENV['COV_LOUPE_OPTS'] = '   '
        expect(parser.parse_env_opts).to eq([])
      end

      it 'parses simple options correctly' do
        ENV['COV_LOUPE_OPTS'] = '--error-mode off --format json'
        expect(parser.parse_env_opts).to eq(%w[--error-mode off --format json])
      end

      it 'handles quoted strings with spaces' do
        ENV['COV_LOUPE_OPTS'] = '--resultset "/path/to/my file.json"'
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/to/my file.json'])
      end

      it 'handles complex shell escaping scenarios' do
        ENV['COV_LOUPE_OPTS'] = '--resultset "/path/with spaces/file.json" --error-mode on'
        expect(parser.parse_env_opts)
          .to eq(['--resultset', '/path/with spaces/file.json', '--error-mode', 'on'])
      end

      it 'handles single quotes' do
        ENV['COV_LOUPE_OPTS'] = "--resultset '/path/with spaces/file.json'"
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/with spaces/file.json'])
      end

      it 'handles escaped characters' do
        ENV['COV_LOUPE_OPTS'] = '--resultset /path/with\\ spaces/file.json'
        expect(parser.parse_env_opts).to eq(['--resultset', '/path/with spaces/file.json'])
      end

      it 'handles mixed quoting styles' do
        ENV['COV_LOUPE_OPTS'] = '--option1 "value with spaces" --option2 \'another value\''
        expect(parser.parse_env_opts).to eq(
          ['--option1', 'value with spaces', '--option2', 'another value']
        )
      end
    end

    context 'with malformed inputs' do
      it 'raises ConfigurationError for unmatched double quotes' do
        ENV['COV_LOUPE_OPTS'] = '--resultset "unterminated string'

        expect do
          parser.parse_env_opts
        end.to raise_error(CovLoupe::ConfigurationError, /Invalid COV_LOUPE_OPTS format/)
      end

      it 'raises ConfigurationError for unmatched single quotes' do
        ENV['COV_LOUPE_OPTS'] = "--resultset 'unterminated string"

        expect do
          parser.parse_env_opts
        end.to raise_error(CovLoupe::ConfigurationError, /Invalid COV_LOUPE_OPTS format/)
      end

      it 'raises ConfigurationError with descriptive message' do
        ENV['COV_LOUPE_OPTS'] = '--option "bad quote'

        expect do
          parser.parse_env_opts
        end.to raise_error(CovLoupe::ConfigurationError) do |error|
          expect(error.message).to include('Invalid COV_LOUPE_OPTS format')
          expect(error.message).to include('Unmatched') # from Shellwords error
        end
      end

      it 'handles multiple quoting errors' do
        ENV['COV_LOUPE_OPTS'] = '"first "second "third'

        expect do
          parser.parse_env_opts
        end.to raise_error(CovLoupe::ConfigurationError, /Invalid COV_LOUPE_OPTS format/)
      end
    end
  end

  describe '#pre_scan_error_mode' do
    let(:error_mode_normalizer) { parser.send(:method, :normalize_error_mode) }

    context 'when error-mode is found' do
      it 'extracts error-mode with space separator' do
        argv = %w[--error-mode debug --other-option]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:debug)
      end

      it 'extracts error-mode with equals separator' do
        argv = %w[--error-mode=off --other-option]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:off)
      end

      it 'handles error-mode with equals but empty value' do
        argv = %w[--error-mode= --other-option]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        # Empty value resolves to default :log
        expect(result).to eq(:log)
      end

      it 'returns last error-mode when multiple are present' do
        argv = %w[--error-mode log --error-mode off]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:off)
      end

      it 'supports short -e flag' do
        argv = %w[-e debug]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:debug)
      end

      it 'supports attached short -e flag (-edebug)' do
        argv = %w[-edebug]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:debug)
      end

      it 'returns default for -e=debug because optparse does not strip equals for short options' do
        argv = %w[-e=debug]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:log)
      end

      it 'prioritizes later flags over earlier ones (mixed short/long)' do
        argv = %w[--error-mode log -e debug]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:debug)
      end

      it 'treats trailing empty assignment as an override (returning default)' do
        # Simulates ENV providing 'off', but CLI providing invalid/empty override.
        # Should stop at the last one and return default (:log), not fall back to :off.
        argv = %w[--error-mode off --error-mode=]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to eq(:log)
      end

      it 'returns nil when a standalone option lacks a value at the end of argv' do
        %w[--error-mode -e].each do |opt|
          argv = ['--other-opt', opt]
          result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
          expect(result).to be_nil
        end
      end
    end

    context 'when error-mode is not found' do
      it 'returns nil when no error-mode is present' do
        argv = %w[--other-option value]
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil for empty argv' do
        argv = []
        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: error_mode_normalizer)
        expect(result).to be_nil
      end
    end

    context 'when handling errors during pre-scan' do
      it 'returns nil when normalizer raises an error' do
        faulty_normalizer = ->(_) { raise StandardError, 'Intentional error' }
        argv = %w[--error-mode log]

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil when normalizer raises ArgumentError' do
        faulty_normalizer = ->(_) { raise ArgumentError, 'Bad argument' }
        argv = %w[--error-mode log]

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end

      it 'returns nil when normalizer raises RuntimeError' do
        faulty_normalizer = ->(_) { raise 'Runtime problem' }
        argv = %w[--error-mode=off]

        result = parser.pre_scan_error_mode(argv, error_mode_normalizer: faulty_normalizer)
        expect(result).to be_nil
      end
    end
  end

  describe '#normalize_error_mode (private)' do
    it 'normalizes "off" to :off' do
      expect(parser.send(:normalize_error_mode, 'off')).to eq(:off)
      expect(parser.send(:normalize_error_mode, 'OFF')).to eq(:off)
      expect(parser.send(:normalize_error_mode, 'Off')).to eq(:off)
    end

    it 'normalizes "log" to :log' do
      expect(parser.send(:normalize_error_mode, 'log')).to eq(:log)
      expect(parser.send(:normalize_error_mode, 'LOG')).to eq(:log)
      expect(parser.send(:normalize_error_mode, 'Log')).to eq(:log)
    end

    it 'normalizes "debug" to :debug' do
      expect(parser.send(:normalize_error_mode, 'debug')).to eq(:debug)
      expect(parser.send(:normalize_error_mode, 'DEBUG')).to eq(:debug)
    end

    it 'defaults unknown values to :log' do
      expect(parser.send(:normalize_error_mode, 'unknown')).to eq(:log)
      expect(parser.send(:normalize_error_mode, 'invalid')).to eq(:log)
      expect(parser.send(:normalize_error_mode, '')).to eq(:log)
    end

    it 'handles nil by defaulting to :log' do
      expect(parser.send(:normalize_error_mode, nil)).to eq(:log)
    end
  end

  describe 'custom environment variable name' do
    it 'uses custom environment variable when specified' do
      custom_parser = described_class.new(env_var: 'CUSTOM_OPTS')
      ENV['CUSTOM_OPTS'] = '--error-mode off'

      expect(custom_parser.parse_env_opts).to eq(%w[--error-mode off])
    end

    it 'includes custom env var name in error messages' do
      custom_parser = described_class.new(env_var: 'MY_CUSTOM_VAR')
      ENV['MY_CUSTOM_VAR'] = '"bad quote'

      expect do
        custom_parser.parse_env_opts
      end.to raise_error(CovLoupe::ConfigurationError, /Invalid MY_CUSTOM_VAR format/)
    end
  end
end
