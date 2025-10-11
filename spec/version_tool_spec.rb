# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/version_tool'

RSpec.describe SimpleCovMcp::Tools::VersionTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  describe '.call' do
    it 'returns a text payload with the version string when called without arguments' do
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      text = item[:text] || item['text']
      expect(text).to eq('SimpleCovMcp version: 1.0.0-rc.1')
    end

    it 'includes the exact version constant value' do
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      text = item[:text] || item['text']
      expect(text).to include(SimpleCovMcp::VERSION)
    end

    it 'matches the expected format exactly' do
      expected_format = "SimpleCovMcp version: #{SimpleCovMcp::VERSION}"
      response = described_class.call(server_context: server_context)
      item = response.payload.first
      text = item[:text] || item['text']
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
        text = item[:text] || item['text']
        expect(text).to eq('SimpleCovMcp version: 1.0.0-rc.1')
      end

      it 'accepts error_mode "on" (default)' do
        response = described_class.call(error_mode: 'on', server_context: server_context)
        item = response.payload.first
        expect(item[:type] || item['type']).to eq('text')
      end

      it 'accepts error_mode "trace"' do
        response = described_class.call(error_mode: 'trace', server_context: server_context)
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
        text = item[:text] || item['text']
        expect(text).to eq('SimpleCovMcp version: 1.0.0-rc.1')
      end
    end
  end
end

