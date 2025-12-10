# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/version_tool'

RSpec.describe CovLoupe::Tools::VersionTool do
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
  end

  describe '.call' do
    it 'returns a text payload with the version string when called without arguments' do
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      text = item['text']
      expect(text).to eq("CovLoupe version: #{CovLoupe::VERSION}")
    end

    it 'includes the exact version constant value' do
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      text = item['text']
      expect(text).to include(CovLoupe::VERSION)
    end

    it 'matches the expected format exactly' do
      expected_format = "CovLoupe version: #{CovLoupe::VERSION}"
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      text = item['text']
      expect(text).to eq(expected_format)
    end

    it 'returns an MCP::Tool::Response object' do
      response = described_class.call(server_context: server_context)
      expect(response).to be_a(MCP::Tool::Response)
    end

    it 'has a single payload item' do
      response = described_class.call(server_context: server_context)
      expect(response.payload).to be_an(Array)
      expect(response.payload.size).to eq(1)
    end

    context 'when error_mode is specified' do
      it 'accepts error_mode parameter without affecting output' do
        response = described_class.call(error_mode: 'off', server_context: server_context)
        item = response.payload.first
        text = item['text']
        expect(text).to eq("CovLoupe version: #{CovLoupe::VERSION}")
      end

      it 'accepts error_mode "log" (default)' do
        response = described_class.call(error_mode: 'log', server_context: server_context)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')
      end

      it 'accepts error_mode "debug"' do
        response = described_class.call(error_mode: 'debug', server_context: server_context)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')
      end
    end

    context 'when additional arguments are passed' do
      it 'ignores additional arguments gracefully' do
        response = described_class.call(
          server_context: server_context,
          extra_arg: 'value',
          another: { nested: 'data' }
        )
        item = response.payload.first
        text = item['text']
        expect(text).to eq("CovLoupe version: #{CovLoupe::VERSION}")
      end
    end

    context 'when an error occurs' do
      it 'handles VERSION constant access errors and returns structured error response' do
        # Force an error by hiding VERSION so const_missing is triggered
        hide_const('CovLoupe::VERSION')
        allow(CovLoupe).to receive(:const_missing).with(:VERSION)
          .and_raise(StandardError, 'Version access error')

        response = described_class.call(error_mode: 'log', server_context: server_context)

        # Should return error response in MCP format
        expect(response).to be_a(MCP::Tool::Response)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')

        error_text = item['text']
        expect(error_text).to include('Error')
      end

      it 'handles errors in the response creation process' do
        # Force an error by mocking string interpolation to fail
        version_obj = double('VERSION')
        allow(version_obj).to receive(:to_s).and_raise(StandardError, 'String conversion error')

        # Replace VERSION with our mock object
        stub_const('CovLoupe::VERSION', version_obj)

        response = described_class.call(error_mode: 'log', server_context: server_context)

        # Should return error response in MCP format via the rescue block
        expect(response).to be_a(MCP::Tool::Response)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')

        error_text = item['text']
        expect(error_text).to include('Error')
      end

      it 'respects error_mode setting when handling errors' do
        # Force an error using a mock VERSION that raises an exception
        version_obj = double('VERSION')
        allow(version_obj).to receive(:to_s).and_raise(StandardError, 'Version error')
        stub_const('CovLoupe::VERSION', version_obj)

        # Test error_mode 'off' (should be silent but still return structured response)
        response = described_class.call(error_mode: 'off', server_context: server_context)
        expect(response).to be_a(MCP::Tool::Response)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')

        # Test error_mode 'debug' (should include more detail)
        response = described_class.call(error_mode: 'debug', server_context: server_context)
        expect(response).to be_a(MCP::Tool::Response)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')
        error_text = item['text']
        expect(error_text).to include('Error')
      end
    end
  end
end
