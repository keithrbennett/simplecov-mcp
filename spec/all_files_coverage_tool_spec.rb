# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/all_files_coverage_tool'

RSpec.describe CovLoupe::Tools::AllFilesCoverageTool do
  subject(:call_tool) { described_class.call(root: root, server_context: server_context) }

  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
    model = instance_double(CovLoupe::CoverageModel)
    allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)

    payload = {
      'files' => [
        { 'file' => 'lib/foo.rb', 'percentage' => 100.0, 'covered' => 10, 'total' => 10,
          'stale' => false },
        { 'file' => 'lib/bar.rb', 'percentage' => 50.0,  'covered' => 5,  'total' => 10,
          'stale' => true }
      ],
      'counts' => { 'total' => 2, 'ok' => 1, 'stale' => 1 }
    }

    presenter = instance_double(CovLoupe::Presenters::ProjectCoveragePresenter)
    allow(CovLoupe::Presenters::ProjectCoveragePresenter).to receive(:new).and_return(presenter)
    allow(presenter).to receive(:relativized_payload).and_return(payload)
  end


  it_behaves_like 'an MCP tool that returns text JSON'

  it 'returns all files coverage data with counts' do
    response = call_tool
    data, _item = expect_mcp_text_json(response, expected_keys: ['files', 'counts'])

    files = data['files']
    counts = data['counts']

    expect(files.length).to eq(2)
    expect(counts).to include('total' => 2).or include(total: 2)
    expect(files.map { |f| f['file'] }).to eq(['lib/foo.rb', 'lib/bar.rb'])

    # ok + stale equals total
    ok = counts[:ok] || counts['ok']
    stale = counts[:stale] || counts['stale']
    total = counts[:total] || counts['total']
    expect(ok + stale).to eq(total)
    expect(stale).to eq(1)
  end
end
