# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_detailed_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageDetailedTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }
  
  before do
    setup_mcp_response_stub
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
  end

  subject { described_class.call(path: 'lib/foo.rb', server_context: server_context) }

  it_behaves_like 'an MCP tool that returns JSON resource'

  it 'returns detailed coverage data with expected structure' do
    response = subject
    data, item = expect_mcp_json_resource(response, expected_keys: ['file', 'lines', 'summary'])
    
    expect(item['resource']['name']).to eq('coverage_detailed.json')
    expect(data['lines']).to be_an(Array)
  end
end

