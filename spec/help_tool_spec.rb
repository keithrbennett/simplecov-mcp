# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/help_tool'

RSpec.describe CovLoupe::Tools::HelpTool do
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
  end

  it 'returns guidance for each registered tool' do
    response = described_class.call(server_context: server_context)
    expect(response.meta).to be_nil

    payload = response.payload.first
    expect(payload['type']).to eq('text')
    data = JSON.parse(payload['text'])
    tool_names = data['tools'].map { |entry| entry['tool'] }

    expect(tool_names).to include('coverage_summary_tool', 'uncovered_lines_tool',
      'list_tool', 'coverage_totals_tool', 'coverage_table_tool', 'version_tool')
    expect(data['tools']).to all(include('use_when', 'avoid_when', 'inputs'))
  end
end
