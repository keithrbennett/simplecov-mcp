# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_summary_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageSummaryTool do
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

  it 'returns JSON as an application/json resource' do
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:summary_for).with('lib/foo.rb').and_return(
      {
        'file' => '/abs/path/lib/foo.rb',
        'summary' => { 'covered' => 10, 'total' => 12, 'pct' => 83.33 }
      }
    )

    response = described_class.call(path: 'lib/foo.rb', server_context: server_context)
    item = response.payload.first
    expect(item['type']).to eq('resource')
    expect(item['resource']).to include('mimeType' => 'application/json', 'name' => 'coverage_summary.json')
    data = JSON.parse(item['resource']['text'])
    expect(data).to include('file', 'summary')
    expect(data['summary']).to include('covered', 'total', 'pct')
  end
end

