# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/coverage_totals_tool'

RSpec.describe CovLoupe::Tools::CoverageTotalsTool do
  subject(:tool_response) { described_class.call(root: root, server_context: server_context) }

  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
    model = instance_double(CovLoupe::CoverageModel)
    allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)

    payload = {
      'lines' => { 'total' => 42, 'covered' => 40, 'uncovered' => 2 },
      'percentage' => 95.24,
      'files' => { 'total' => 4, 'ok' => 4, 'stale' => 0 },
      'excluded_files' => {
        'skipped' => 0,
        'missing_tracked' => 0,
        'newer' => 0,
        'deleted' => 0,
        'length_mismatch' => 0,
        'unreadable' => 0
      }
    }

    presenter = instance_double(CovLoupe::Presenters::ProjectTotalsPresenter)
    allow(CovLoupe::Presenters::ProjectTotalsPresenter).to receive(:new).and_return(presenter)
    allow(presenter).to receive(:relativized_payload).and_return(payload)
  end

  it_behaves_like 'an MCP tool that returns text JSON'

  it 'returns aggregated totals' do
    data, = expect_mcp_text_json(tool_response, expected_keys: %w[lines percentage files])

    expect(data['lines']).to include('total' => 42, 'covered' => 40, 'uncovered' => 2)
    expect(data['files']).to include('total' => 4, 'stale' => 0)
    expect(data['percentage']).to eq(95.24)
  end

  it 'includes excluded_files metadata in output' do
    data, = expect_mcp_text_json(
      tool_response,
      expected_keys: %w[lines percentage files excluded_files]
    )

    expect(data).to have_key('excluded_files')
    expect(data['excluded_files']).to be_a(Hash)
    expect(data['excluded_files'].keys).to contain_exactly(
      'skipped', 'missing_tracked', 'newer', 'deleted', 'length_mismatch', 'unreadable'
    )
  end
end
