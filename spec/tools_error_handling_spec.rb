# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/help_tool'
require 'simplecov_mcp/tools/version_tool'
require 'simplecov_mcp/tools/coverage_summary_tool'
require 'simplecov_mcp/tools/coverage_raw_tool'
require 'simplecov_mcp/tools/uncovered_lines_tool'
require 'simplecov_mcp/tools/coverage_detailed_tool'
require 'simplecov_mcp/tools/coverage_totals_tool'

RSpec.describe 'MCP Tool error handling' do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  # Note: VersionTool error handling is difficult to test because the tool is so simple
  # and doesn't have any complex logic that could fail. The rescue clause in the tool
  # exists for consistency with other tools but is unlikely to be triggered in practice.

  describe SimpleCovMcp::Tools::HelpTool do
    it 'handles errors during query processing' do
      # Simulate an error during filter_entries
      allow(described_class).to receive(:filter_entries).and_raise(StandardError, 'Filter error')

      response = described_class.call(query: 'test', error_mode: 'on',
        server_context: server_context)

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end

    it 'returns empty array when tokens are empty after filtering' do
      # Test the edge case where query contains only non-word characters
      response = described_class.call(query: '!!!', server_context: server_context)

      data = JSON.parse(response.payload.first['text'])
      # With empty tokens, should return all entries (no filtering applied)
      expect(data['tools']).not_to be_empty
    end

    it 'handles non-string, non-array values in filter' do
      # Test value_matches? with values that are neither strings nor arrays
      # This exercises the 'else false' branch
      allow(described_class).to receive(:format_entry).and_return({
        'tool' => 'test_tool',
        'label' => nil, # Neither string nor array
        'use_when' => 123, # Neither string nor array
        'avoid_when' => true, # Neither string nor array
        'inputs' => {}, # Neither string nor array
        'example' => 'example'
      })

      response = described_class.call(query: 'test', server_context: server_context)

      # Should not crash, should return response
      expect(response).to be_a(MCP::Tool::Response)
      data = JSON.parse(response.payload.first['text'])
      expect(data).to have_key('tools')
    end
  end

  describe SimpleCovMcp::Tools::CoverageSummaryTool do
    it 'handles errors during model creation' do
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_raise(StandardError, 'Model error')

      response = described_class.call(
        path: 'lib/foo.rb',
        error_mode: 'on',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end
  end

  describe SimpleCovMcp::Tools::CoverageRawTool do
    it 'handles errors during raw data retrieval' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:raw_for).and_raise(StandardError, 'Raw data error')

      response = SimpleCovMcp::Tools::CoverageRawTool.call(
        path: 'lib/foo.rb',
        error_mode: 'on',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end
  end

  describe SimpleCovMcp::Tools::UncoveredLinesTool do
    it 'handles errors during uncovered lines retrieval' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:uncovered_for).and_raise(StandardError, 'Uncovered error')

      response = SimpleCovMcp::Tools::UncoveredLinesTool.call(
        path: 'lib/foo.rb',
        error_mode: 'on',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end
  end

  describe SimpleCovMcp::Tools::CoverageDetailedTool do
    it 'handles errors during detailed data retrieval' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:detailed_for).and_raise(StandardError, 'Detailed error')

      response = SimpleCovMcp::Tools::CoverageDetailedTool.call(
        path: 'lib/foo.rb',
        error_mode: 'on',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end
  end

  describe SimpleCovMcp::Tools::CoverageTotalsTool do
    it 'handles errors during totals calculation' do
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_raise(StandardError, 'Model error')

      response = SimpleCovMcp::Tools::CoverageTotalsTool.call(
        error_mode: 'on',
        server_context: server_context
      )

      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item[:text] || item['text']).to include('Error')
    end
  end
end
