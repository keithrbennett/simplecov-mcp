# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_detailed_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageDetailedTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    stub_const('MCP::Tool::Response', Struct.new(:payload))
  end

  it 'returns JSON as an application/json resource' do
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:detailed_for).with('lib/foo.rb').and_return(
      {
        'file' => '/abs/path/lib/foo.rb',
        'lines' => [
          { 'line' => 1, 'hits' => 1, 'covered' => true },
          { 'line' => 2, 'hits' => 0, 'covered' => false }
        ],
        'summary' => { 'covered' => 1, 'total' => 2, 'pct' => 50.0 }
      }
    )

    response = described_class.call(path: 'lib/foo.rb', server_context: server_context)
    item = response.payload.first
    expect(item['type']).to eq('resource')
    expect(item['resource']).to include('mimeType' => 'application/json', 'name' => 'coverage_detailed.json')
    data = JSON.parse(item['resource']['text'])
    expect(data).to include('file', 'lines', 'summary')
    expect(data['lines']).to be_an(Array)
  end
end

