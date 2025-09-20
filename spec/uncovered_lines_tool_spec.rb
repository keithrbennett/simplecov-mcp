# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/uncovered_lines_tool'

RSpec.describe SimpleCovMcp::Tools::UncoveredLinesTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    stub_const('MCP::Tool::Response', Struct.new(:payload))
  end

  it 'returns JSON as an application/json resource' do
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:uncovered_for).with('lib/foo.rb').and_return(
      {
        'file' => '/abs/path/lib/foo.rb',
        'uncovered' => [5, 9, 12],
        'summary' => { 'covered' => 10, 'total' => 12, 'pct' => 83.33 }
      }
    )

    response = described_class.call(path: 'lib/foo.rb', server_context: server_context)
    item = response.payload.first
    expect(item['type']).to eq('resource')
    expect(item['resource']).to include('mimeType' => 'application/json', 'name' => 'uncovered_lines.json')
    data = JSON.parse(item['resource']['text'])
    expect(data).to include('file', 'uncovered', 'summary')
    expect(data['uncovered']).to eq([5, 9, 12])
  end
end

