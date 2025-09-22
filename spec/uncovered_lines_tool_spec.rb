# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/uncovered_lines_tool'

RSpec.describe SimpleCovMcp::Tools::UncoveredLinesTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }
  
  before do
    setup_mcp_response_stub
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:uncovered_for).with('lib/foo.rb').and_return(
      {
        'file' => '/abs/path/lib/foo.rb',
        'uncovered' => [5, 9, 12],
        'summary' => { 'covered' => 10, 'total' => 12, 'pct' => 83.33 }
      }
    )
  end

  subject { described_class.call(path: 'lib/foo.rb', server_context: server_context) }

  it_behaves_like 'an MCP tool that returns JSON resource'

  it 'returns uncovered lines data with expected structure' do
    response = subject
    data, item = expect_mcp_json_resource(response, expected_keys: ['file', 'uncovered', 'summary'])
    
    expect(item['resource']['name']).to eq('uncovered_lines.json')
    expect(data['uncovered']).to eq([5, 9, 12])
  end
end

