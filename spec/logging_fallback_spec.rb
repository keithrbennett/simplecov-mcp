# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Logging Fallback Behavior' do
  describe 'CovUtil.log error handling' do
    context 'when file logging fails in library mode' do
      it 'falls back to stderr with error message' do
        # Set up library mode context
        context = SimpleCovMcp.create_context(
          error_handler: SimpleCovMcp::ErrorHandlerFactory.for_library,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :library
        )

        stderr_output = nil
        SimpleCovMcp.with_context(context) do
          silence_output do |_stdout, stderr|
            SimpleCovMcp::CovUtil.log('test message')
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
        context = SimpleCovMcp.create_context(
          error_handler: SimpleCovMcp::ErrorHandlerFactory.for_cli,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :cli
        )

        stderr_output = nil
        SimpleCovMcp.with_context(context) do
          silence_output do |_stdout, stderr|
            SimpleCovMcp::CovUtil.log('test message')
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
        context = SimpleCovMcp.create_context(
          error_handler: SimpleCovMcp::ErrorHandlerFactory.for_mcp_server,
          log_target: '/invalid/path/that/does/not/exist.log',
          mode: :mcp_server
        )

        stderr_output = nil
        SimpleCovMcp.with_context(context) do
          silence_output do |_stdout, stderr|
            SimpleCovMcp::CovUtil.log('test message')
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
          context = SimpleCovMcp.create_context(
            error_handler: SimpleCovMcp::ErrorHandlerFactory.for_library,
            log_target: log_file,
            mode: :library
          )

          stderr_output = nil
          SimpleCovMcp.with_context(context) do
            silence_output do |_stdout, stderr|
              SimpleCovMcp::CovUtil.log('test message')
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
      context = SimpleCovMcp.create_context(
        error_handler: SimpleCovMcp::ErrorHandlerFactory.for_library,
        mode: :library
      )
      expect(context.library_mode?).to be true
      expect(context.cli_mode?).to be false
      expect(context.mcp_mode?).to be false
    end

    it 'correctly identifies CLI mode' do
      context = SimpleCovMcp.create_context(
        error_handler: SimpleCovMcp::ErrorHandlerFactory.for_cli,
        mode: :cli
      )
      expect(context.library_mode?).to be false
      expect(context.cli_mode?).to be true
      expect(context.mcp_mode?).to be false
    end

    it 'correctly identifies MCP server mode' do
      context = SimpleCovMcp.create_context(
        error_handler: SimpleCovMcp::ErrorHandlerFactory.for_mcp_server,
        mode: :mcp_server
      )
      expect(context.library_mode?).to be false
      expect(context.cli_mode?).to be false
      expect(context.mcp_mode?).to be true
    end
  end
end
