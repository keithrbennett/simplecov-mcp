# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_summary_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageSummaryTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }
  
  before do
    setup_mcp_response_stub
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:summary_for).with('lib/foo.rb').and_return(
      {
        'file' => '/abs/path/lib/foo.rb',
        'summary' => { 'covered' => 10, 'total' => 12, 'pct' => 83.33 }
      }
    )
  end

  subject { described_class.call(path: 'lib/foo.rb', server_context: server_context) }

  it_behaves_like 'an MCP tool that returns JSON resource'

  it 'returns coverage summary data with expected structure' do
    response = subject
    data, item = expect_mcp_json_resource(response, expected_keys: ['file', 'summary'])
    
    expect(item['resource']['name']).to eq('coverage_summary.json')
    expect(data['summary']).to include('covered', 'total', 'pct')
  end
end

