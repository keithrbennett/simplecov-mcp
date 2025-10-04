# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/coverage_table_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageTableTool do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  def run_tool(stale: 'off')
    # Let real CoverageModel work to test actual format_table behavior
    described_class.call(root: root, stale: stale, server_context: server_context).payload.first[:text]
  end

  it 'returns a formatted table as a string' do
    output = run_tool

    # Contains table structure, headers, and file data
    expect(output).to include(
      '┌', '┬', '┐', '│', '├', '┼', '┤', '└', '┴', '┘',
      'File', 'Covered', 'Total', ' │ Stale │',
      'lib/foo.rb', 'lib/bar.rb',
      'Files: total 2, ok 0, stale 2'
    )
  end

  it 'configures CLI to enforce stale checking when requested' do
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(model).to receive(:all_files).and_return([
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10, 'stale' => false }
    ])
    allow(model).to receive(:relativize) { |payload| payload }
    expect(SimpleCovMcp::CoverageModel).to receive(:new).with(
      root: root,
      resultset: nil,
      staleness: 'error',
      tracked_globs: nil
    ).and_return(model)
    allow(model).to receive(:format_table).and_return("Mock table output")

    described_class.call(root: root, stale: 'error', server_context: server_context)
  end
end
