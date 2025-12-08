# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/help_tool'
require 'cov_loupe/tools/version_tool'
require 'cov_loupe/tools/coverage_summary_tool'
require 'cov_loupe/tools/coverage_raw_tool'
require 'cov_loupe/tools/uncovered_lines_tool'
require 'cov_loupe/tools/coverage_detailed_tool'
require 'cov_loupe/tools/coverage_totals_tool'

RSpec.describe CovLoupe::Tools do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  # NOTE: VersionTool error handling is difficult to test because the tool is so simple
  # and doesn't have any complex logic that could fail. The rescue clause in the tool
  # exists for consistency with other tools but is unlikely to be triggered in practice.

  describe CovLoupe::Tools::HelpTool do
    it 'returns tool information without errors' do
      response = described_class.call(error_mode: 'log', server_context: server_context)

      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')

      data = JSON.parse(item['text'])
      expect(data).to have_key('tools')
      expect(data['tools']).not_to be_empty
    end
  end

  describe CovLoupe::Tools::CoverageSummaryTool do
    it 'handles errors during model creation' do
      allow(CovLoupe::CoverageModel).to receive(:new).and_raise(StandardError, 'Model error')

      response = described_class.call(
        path: 'lib/foo.rb',
        error_mode: 'log',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
  end

  describe CovLoupe::Tools::CoverageRawTool do
    it 'handles errors during raw data retrieval' do
      model = instance_double(CovLoupe::CoverageModel)
      allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:raw_for).and_raise(StandardError, 'Raw data error')

      response = described_class.call(
        path: 'lib/foo.rb',
        error_mode: 'log',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
  end

  describe CovLoupe::Tools::UncoveredLinesTool do
    it 'handles errors during uncovered lines retrieval' do
      model = instance_double(CovLoupe::CoverageModel)
      allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:uncovered_for).and_raise(StandardError, 'Uncovered error')

      response = described_class.call(
        path: 'lib/foo.rb',
        error_mode: 'log',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
  end

  describe CovLoupe::Tools::CoverageDetailedTool do
    it 'handles errors during detailed data retrieval' do
      model = instance_double(CovLoupe::CoverageModel)
      allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:detailed_for).and_raise(StandardError, 'Detailed error')

      response = described_class.call(
        path: 'lib/foo.rb',
        error_mode: 'log',
        server_context: server_context
      )

      # Should return error response
      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
  end

  describe CovLoupe::Tools::CoverageTotalsTool do
    it 'handles errors during totals calculation' do
      allow(CovLoupe::CoverageModel).to receive(:new).and_raise(StandardError, 'Model error')

      response = described_class.call(
        error_mode: 'log',
        server_context: server_context
      )

      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
  end
end
