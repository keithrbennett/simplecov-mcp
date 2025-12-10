# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/coverage_table_tool'

RSpec.describe CovLoupe::Tools::CoverageTableTool do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
  end

  def run_tool(staleness: :off)
    # Let real CoverageModel work to test actual format_table behavior
    described_class.call(root: root, staleness: staleness,
      server_context: server_context).payload.first['text']
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
    model = instance_double(CovLoupe::CoverageModel,
      all_files: [
        { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10,
          'stale' => false }
      ],
      relativize: ->(payload) { payload },
      format_table: 'Mock table output'
    )
    allow(CovLoupe::CoverageModel).to receive(:new).with(
      root: root,
      resultset: nil,
      staleness: :error,
      tracked_globs: nil
    ).and_return(model)
    allow(model).to receive(:format_table).and_return('Mock table output')

    described_class.call(root: root, staleness: :error, server_context: server_context)

    expect(CovLoupe::CoverageModel).to have_received(:new).with(
      root: root,
      resultset: nil,
      staleness: :error,
      tracked_globs: nil
    )
    expect(model).to have_received(:format_table)
  end
end
