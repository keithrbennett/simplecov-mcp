# frozen_string_literal: true

require 'spec_helper'
require 'simple_cov_mcp/tools/coverage_table_tool'

RSpec.describe SimpleCovMcp::Tools::CoverageTableTool do
  let(:root) { (FIXTURES / 'project1').to_s }

  def run_tool
    # Stub the CoverageModel to avoid file system access
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(:all_files).and_return([
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10 },
      { 'file' => "#{root}/lib/bar.rb", 'percentage' => 50.0, 'covered' => 5, 'total' => 10 }
    ])

    tool = described_class.new
    tool.execute
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
end
