# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Error Mode System' do
  let(:test_logger) do
    Class.new do
      attr_reader :messages
      def initialize; @messages = []; end
      def error(msg); @messages << msg; end
    end.new
  end

  let(:test_error) { StandardError.new('Test error message') }

  describe 'ErrorHandler error modes' do
    context 'with error_mode: :off' do
      subject(:handler) { SimpleCovMcp::ErrorHandler.new(error_mode: :off, logger: test_logger) }

      it 'does not log errors' do
        expect(handler.log_errors?).to be false
        expect(handler.show_stack_traces?).to be false

        handler.handle_error(test_error, context: 'test', reraise: false)
        expect(test_logger.messages).to be_empty
      end
    end

    context 'with error_mode: :on' do
      subject(:handler) { SimpleCovMcp::ErrorHandler.new(error_mode: :on, logger: test_logger) }

      it 'logs errors but not stack traces' do
        expect(handler.log_errors?).to be true
        expect(handler.show_stack_traces?).to be false

        handler.handle_error(test_error, context: 'test', reraise: false)
        logged_message = test_logger.messages.join
        expect(logged_message).to include('Error in test: StandardError: Test error message')
        expect(logged_message).not_to include('spec/error_mode_spec.rb') # No stack trace
      end
    end

    context 'with error_mode: :trace' do
      subject(:handler) { SimpleCovMcp::ErrorHandler.new(error_mode: :trace, logger: test_logger) }

      it 'logs errors with stack traces' do
        expect(handler.log_errors?).to be true
        expect(handler.show_stack_traces?).to be true

        # Create an error with a proper backtrace
        begin
          raise StandardError, 'Test error message'
        rescue StandardError => e
          handler.handle_error(e, context: 'test', reraise: false)
        end

        logged_message = test_logger.messages.join
        expect(logged_message).to include('Error in test: StandardError: Test error message')
        expect(logged_message).to include('spec/error_mode_spec.rb') # Stack trace included
      end
    end
  end

  describe 'ErrorHandlerFactory' do
    it 'creates handlers with correct modes' do
      cli_handler = SimpleCovMcp::ErrorHandlerFactory.for_cli(error_mode: :trace)
      expect(cli_handler.error_mode).to eq(:trace)

      lib_handler = SimpleCovMcp::ErrorHandlerFactory.for_library(error_mode: :off)
      expect(lib_handler.error_mode).to eq(:off)

      mcp_handler = SimpleCovMcp::ErrorHandlerFactory.for_mcp_server(error_mode: :on)
      expect(mcp_handler.error_mode).to eq(:on)
    end
  end

  describe 'MCP Tools error mode support' do
    before { setup_mcp_response_stub }

    it 'BaseTool.handle_mcp_error respects error modes' do
      test_error = StandardError.new('Test MCP error')

      # Test different error modes
      [:off, :on, :trace].each do |mode|
        expect(SimpleCovMcp::ErrorHandlerFactory).to receive(:for_mcp_server).with(error_mode: mode).and_call_original

        response = SimpleCovMcp::BaseTool.handle_mcp_error(test_error, 'TestTool', error_mode: mode)
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.payload.first[:text]).to include('Error:')
      end
    end
  end

  describe 'CLI error mode support' do
    let(:project_dir) { File.join(__dir__, 'fixtures', 'project1') }

    it 'accepts --error-mode flag' do
      cli = SimpleCovMcp::CoverageCLI.new

      # Test that the option parser accepts the flag
      expect do
        cli.send(:parse_options!, ['--error-mode', 'trace', 'summary', 'lib/foo.rb'])
      end.not_to raise_error

      expect(cli.config.error_mode).to eq(:trace)
    end

    it 'creates error handler with specified mode' do
      cli = SimpleCovMcp::CoverageCLI.new
      cli.send(:parse_options!, ['--error-mode', 'off', 'summary', 'lib/foo.rb'])

      # Trigger error handler creation
      cli.send(:ensure_error_handler)

      error_handler = cli.instance_variable_get(:@error_handler)
      expect(error_handler.error_mode).to eq(:off)
    end

    it 'validates error mode values' do
      cli = SimpleCovMcp::CoverageCLI.new

      expect do
        cli.send(:parse_options!, ['--error-mode', 'invalid', 'summary', 'lib/foo.rb'])
      end.to raise_error(OptionParser::InvalidArgument)
    end
  end

  describe 'Error mode validation' do
    it 'raises ArgumentError for invalid error modes' do
      expect do
        SimpleCovMcp::ErrorHandler.new(error_mode: :invalid)
      end.to raise_error(ArgumentError, /Invalid error_mode: :invalid/)
    end

    it 'accepts all valid error modes' do
      expect { SimpleCovMcp::ErrorHandler.new(error_mode: :off) }.not_to raise_error
      expect { SimpleCovMcp::ErrorHandler.new(error_mode: :on) }.not_to raise_error
      expect { SimpleCovMcp::ErrorHandler.new(error_mode: :trace) }.not_to raise_error
    end
  end
end
