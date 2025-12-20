# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Logging Fallback Behavior' do
  describe 'CovLoupe.logger error handling' do
    context 'when file logging fails in library mode' do
      it 'falls back to stderr with error message' do
        # Set up library mode context
        context = CovLoupe.create_context(
          error_handler: CovLoupe::ErrorHandlerFactory.for_library,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :library
        )

        stderr_output = nil
        CovLoupe.with_context(context) do
          silence_output do |_stdout, stderr|
            CovLoupe.logger.info('test message')
            stderr_output = stderr.string
          end
        end

        expect(stderr_output).to include('LOGGING ERROR')
        expect(stderr_output).to include('test message')
      end
    end

    context 'when file logging fails in CLI mode' do
      it 'falls back to stderr with error message' do
        # Set up CLI mode context
        context = CovLoupe.create_context(
          error_handler: CovLoupe::ErrorHandlerFactory.for_cli,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :cli
        )

        stderr_output = nil
        CovLoupe.with_context(context) do
          silence_output do |_stdout, stderr|
            CovLoupe.logger.info('test message')
            stderr_output = stderr.string
          end
        end

        expect(stderr_output).to include('LOGGING ERROR')
        expect(stderr_output).to include('test message')
      end
    end

    context 'when file logging fails in MCP server mode' do
      it 'suppresses stderr output to avoid interfering with JSON-RPC' do
        # Set up MCP server mode context
        context = CovLoupe.create_context(
          error_handler: CovLoupe::ErrorHandlerFactory.for_mcp_server,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :mcp
        )

        stderr_output = nil
        CovLoupe.with_context(context) do
          silence_output do |_stdout, stderr|
            CovLoupe.logger.info('test message')
            stderr_output = stderr.string
          end
        end

        expect(stderr_output).to be_empty
      end
    end

    context 'when logging succeeds' do
      it 'does not write to stderr' do
        Dir.mktmpdir do |dir|
          log_file = File.join(dir, 'test.log')
          context = CovLoupe.create_context(
            error_handler: CovLoupe::ErrorHandlerFactory.for_library,
            log_target: log_file,
            mode: :library
          )

          stderr_output = nil
          CovLoupe.with_context(context) do
            silence_output do |_stdout, stderr|
              CovLoupe.logger.info('test message')
              stderr_output = stderr.string
            end
          end

          expect(stderr_output).to be_empty
          expect(File.read(log_file)).to include('test message')
        end
      end
    end
  end

  describe 'AppContext mode predicates' do
    it 'correctly identifies library mode' do
      context = CovLoupe.create_context(
        error_handler: CovLoupe::ErrorHandlerFactory.for_library,
        mode: :library
      )
      expect(context.library_mode?).to be true
      expect(context.cli_mode?).to be false
      expect(context.mcp_mode?).to be false
    end

    it 'correctly identifies CLI mode' do
      context = CovLoupe.create_context(
        error_handler: CovLoupe::ErrorHandlerFactory.for_cli,
        mode: :cli
      )
      expect(context.library_mode?).to be false
      expect(context.cli_mode?).to be true
      expect(context.mcp_mode?).to be false
    end

    it 'correctly identifies MCP mode' do
      context = CovLoupe.create_context(
        error_handler: CovLoupe::ErrorHandlerFactory.for_mcp_server,
        mode: :mcp
      )
      expect(context.library_mode?).to be false
      expect(context.cli_mode?).to be false
      expect(context.mcp_mode?).to be true
    end
  end

  describe 'CovLoupe::Logger log levels' do
    [
      { level: :info, severity: 'INFO', message: 'info message' },
      { level: :warn, severity: 'WARN', message: 'warning message' },
      { level: :error, severity: 'ERROR', message: 'error message' },
      { level: :safe_log, severity: 'INFO', message: 'safe log message' }
    ].each do |test_case|
      it "logs with #{test_case[:level]} level" do
        Dir.mktmpdir do |dir|
          log_file = File.join(dir, 'test.log')
          logger = CovLoupe::Logger.new(target: log_file, mcp_mode: false)

          logger.send(test_case[:level], test_case[:message])

          log_content = File.read(log_file)
          expect(log_content).to include(test_case[:severity])
          expect(log_content).to include(test_case[:message])
        end
      end
    end

    it 'handles runtime errors during logging' do
      Dir.mktmpdir do |dir|
        log_file = File.join(dir, 'test.log')
        logger = CovLoupe::Logger.new(target: log_file, mcp_mode: false)

        # Create a mock logger that will raise during send
        mock_stdlib_logger = instance_double(::Logger)
        allow(mock_stdlib_logger).to receive(:info).and_raise(StandardError.new('runtime error'))

        # Inject the mock logger
        logger.instance_variable_set(:@logger, mock_stdlib_logger)

        stderr_output = nil
        silence_output do |_stdout, stderr|
          logger.info('test message')
          stderr_output = stderr.string
        end

        expect(stderr_output).to include('LOGGING ERROR')
        expect(stderr_output).to include('runtime error')
        expect(stderr_output).to include('test message')
      end
    end
  end
end
