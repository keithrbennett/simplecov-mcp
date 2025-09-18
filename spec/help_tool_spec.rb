# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/help_tool'

RSpec.describe SimpleCovMcp::Tools::HelpTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    response_class = Class.new do
      attr_reader :payload, :meta

      def initialize(payload, meta: nil)
        @payload = payload
        @meta = meta
      end
    end
    stub_const('MCP::Tool::Response', response_class)
  end

  it 'returns guidance for each registered tool' do
    response = described_class.call(server_context: server_context)
    expect(response.meta[:mimeType]).to eq('application/json')

    payload = response.payload.first
    expect(payload[:type]).to eq('json')

    data = payload[:json]
    tool_names = data[:tools].map { |entry| entry['tool'] }

    expect(tool_names).to include('coverage_summary_tool', 'uncovered_lines_tool', 'all_files_coverage_tool', 'coverage_table_tool', 'version_tool')
    expect(data[:tools]).to all(include('use_when', 'avoid_when', 'inputs', 'example'))
  end

  it 'filters entries when a query is provided' do
    response = described_class.call(query: 'uncovered', server_context: server_context)
    payload = response.payload.first
    data = payload[:json]

    expect(data[:tools]).not_to be_empty
    expect(data[:tools]).to all(satisfy do |entry|
      combined = [entry['tool'], entry['label'], entry['use_when'], entry['avoid_when']].compact.join(' ').downcase
      combined.include?('uncovered')
    end)
    expect(data[:tools].map { |entry| entry['tool'] }).to include('uncovered_lines_tool')
  end
end
