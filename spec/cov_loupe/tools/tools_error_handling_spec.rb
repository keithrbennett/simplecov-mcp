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
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
  end

  shared_examples 'handles tool error' do |tool_class, method, error_msg, call_args = {}|
    it "handles errors during #{method} execution" do
      # If we're mocking CoverageModel.new directly (for tools that fail early)
      if method == :new
        allow(CovLoupe::CoverageModel).to receive(:new).and_raise(StandardError, error_msg)
      else
        # For tools that fail on a model method
        model = instance_double(CovLoupe::CoverageModel)
        allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(method).and_raise(StandardError, error_msg)
      end

      default_args = { error_mode: 'log', server_context: server_context }
      response = tool_class.call(**default_args, **call_args)

      expect(response).to be_a(MCP::Tool::Response)
      item = response.payload.first
      expect(item[:type] || item['type']).to eq('text')
      expect(item['text']).to include('Error')
    end
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
    it_behaves_like 'handles tool error', described_class, :new, 'Model error', path: 'lib/foo.rb'
  end

  describe CovLoupe::Tools::CoverageRawTool do
    it_behaves_like 'handles tool error', described_class, :raw_for, 'Raw data error',
      path: 'lib/foo.rb'
  end

  describe CovLoupe::Tools::UncoveredLinesTool do
    it_behaves_like 'handles tool error', described_class, :uncovered_for, 'Uncovered error',
      path: 'lib/foo.rb'
  end

  describe CovLoupe::Tools::CoverageDetailedTool do
    it_behaves_like 'handles tool error', described_class, :detailed_for, 'Detailed error',
      path: 'lib/foo.rb'
  end

  describe CovLoupe::Tools::CoverageTotalsTool do
    it_behaves_like 'handles tool error', described_class, :new, 'Model error'
  end
end
