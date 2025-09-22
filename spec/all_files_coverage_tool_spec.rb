# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/all_files_coverage_tool'

RSpec.describe SimpleCovMcp::Tools::AllFilesCoverageTool do
  let(:root) { (FIXTURES / 'project1').to_s }
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:all_files).and_return([
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10, 'stale' => false },
      { 'file' => "#{root}/lib/bar.rb", 'percentage' => 50.0,  'covered' => 5,  'total' => 10, 'stale' => true }
    ])
  end

  subject { described_class.call(root: root, server_context: server_context) }

  it_behaves_like 'an MCP tool that returns JSON resource'

  it 'returns all files coverage data with counts' do
    response = subject
    data, item = expect_mcp_json_resource(response, expected_keys: ['files', 'counts'])
    
    files = data['files']
    counts = data['counts']
    
    expect(files.length).to eq(2)
    expect(counts).to include('total' => 2).or include(total: 2)
    
    # ok + stale equals total
    ok = counts[:ok] || counts['ok']
    stale = counts[:stale] || counts['stale']
    total = counts[:total] || counts['total']
    expect(ok + stale).to eq(total)
    expect(stale).to eq(1)
  end
end
