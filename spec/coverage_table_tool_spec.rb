# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_table_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageTableTool do
  let(:root) { (FIXTURES / 'project1').to_s }
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    stub_const('MCP::Tool::Response', Struct.new(:payload))
  end

  def run_tool(stale: 'off')
    # Stub the CoverageModel to avoid file system access
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:all_files).and_return([
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10 },
      { 'file' => "#{root}/lib/bar.rb", 'percentage' => 50.0, 'covered' => 5, 'total' => 10 }
    ])

    response = described_class.call(root: root, stale: stale, server_context: server_context)
    response.payload.first[:text]
  end

  it 'returns a formatted table as a string' do
    output = run_tool

    # Contains a header row and at least one data row with expected columns
    expect(output).to include('File')
    expect(output).to include('Covered')
    expect(output).to include('Total')

    # Should list fixture files from the demo project
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')

    # Check for table borders
    expect(output).to include('┌')
    expect(output).to include('│')
    expect(output).to include('└')
  end

  it 'configures the CLI to enforce stale checking when requested' do
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(model).to receive(:all_files).and_return([
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10 }
    ])
    expect(SimpleCovMcp::CoverageModel).to receive(:new).with(
      root: root,
      resultset: nil,
      staleness: 'error',
      tracked_globs: nil
    ).and_return(model)

    described_class.call(root: root, stale: 'error', server_context: server_context)
  end
end
