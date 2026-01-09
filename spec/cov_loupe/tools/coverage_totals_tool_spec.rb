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
      'lines' => {
        'total' => 42,
        'covered' => 40,
        'uncovered' => 2,
        'percent_covered' => 95.24
      },
      'tracking' => {
        'enabled' => true,
        'globs' => ['lib/**/*.rb']
      },
      'files' => {
        'total' => 4,
        'with_coverage' => {
          'total' => 4,
          'ok' => 4,
          'stale' => {
            'total' => 0,
            'by_type' => {
              'missing_from_disk' => 0,
              'newer' => 0,
              'length_mismatch' => 0,
              'unreadable' => 0
            }
          }
        },
        'without_coverage' => {
          'total' => 0,
          'by_type' => {
            'missing_from_coverage' => 0,
            'unreadable' => 0,
            'skipped' => 0
          }
        }
      }
    }

    presenter = instance_double(CovLoupe::Presenters::ProjectTotalsPresenter)
    allow(CovLoupe::Presenters::ProjectTotalsPresenter).to receive(:new).and_return(presenter)
    allow(presenter).to receive(:relativized_payload).and_return(payload)
  end

  it_behaves_like 'an MCP tool that returns text JSON'

  it 'returns aggregated totals' do
    data, = expect_mcp_text_json(tool_response, expected_keys: %w[lines tracking files])

    expect(data['lines']).to include(
      'total' => 42,
      'covered' => 40,
      'uncovered' => 2,
      'percent_covered' => 95.24
    )
    expect(data['files']).to include('total' => 4)
    expect(data['tracking']).to include('enabled' => true)
  end

  it 'includes tracking metadata in output' do
    data, = expect_mcp_text_json(
      tool_response,
      expected_keys: %w[lines tracking files]
    )

    expect(data['tracking']).to include('enabled' => true)
    expect(data['tracking']['globs']).to eq(['lib/**/*.rb'])
  end
end
