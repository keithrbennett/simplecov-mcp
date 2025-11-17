# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/coverage_totals_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageTotalsTool do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)

    payload = {
      'lines' => { 'total' => 42, 'covered' => 40, 'uncovered' => 2 },
      'pct' => 95.24,
      'files' => { 'total' => 4, 'ok' => 4, 'stale' => 0 }
    }

    presenter = instance_double(SimpleCovMcp::Presenters::ProjectTotalsPresenter)
    allow(SimpleCovMcp::Presenters::ProjectTotalsPresenter).to receive(:new).and_return(presenter)
    allow(presenter).to receive(:relativized_payload).and_return(payload)
  end

  subject { described_class.call(root: root, server_context: server_context) }

  it_behaves_like 'an MCP tool that returns text JSON'

  it 'returns aggregated totals' do
    response = subject
    data, = expect_mcp_text_json(response, expected_keys: ['lines', 'pct', 'files'])

    expect(data['lines']).to include('total' => 42, 'covered' => 40, 'uncovered' => 2)
    expect(data['files']).to include('total' => 4, 'stale' => 0)
    expect(data['pct']).to eq(95.24)
  end
end
