# frozen_string_literal: true

require 'spec_helper'

# Shared examples for file-based MCP tools that follow the same pattern:
# - Take a path parameter
# - Call a specific method on CoverageModel
# - Return JSON resource with consistent structure
# - Have predictable output filename

RSpec.shared_examples 'a file-based MCP tool' do |config|
  subject { tool_class.call(path: 'lib/foo.rb', server_context: server_context) }

  let(:server_context) { instance_double('ServerContext').as_null_object }
  let(:tool_class) { config[:tool_class] }
  let(:model_method) { config[:model_method] }
  let(:expected_keys) { config[:expected_keys] }
  let(:output_filename) { config[:output_filename] }
  let(:mock_data) { config[:mock_data] }
  let(:additional_validations) { config[:additional_validations] }

  before do
    setup_mcp_response_stub
    model = instance_double(SimpleCovMcp::CoverageModel)
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
    allow(model).to receive(model_method).with('lib/foo.rb').and_return(mock_data)
    relativizer = SimpleCovMcp::PathRelativizer.new(
      root: '/abs/path',
      scalar_keys: %w[file file_path],
      array_keys: %w[newer_files missing_files deleted_files]
    )
    allow(model).to receive(:relativize) { |payload| relativizer.relativize(payload) }
    allow(model).to receive(:staleness_for).with('lib/foo.rb').and_return(false)
  end


  it_behaves_like 'an MCP tool that returns text JSON'

  it "returns #{config[:description]} with expected structure" do
    response = subject
    data, item = expect_mcp_text_json(response, expected_keys: expected_keys)

    if data.is_a?(Hash) && data.key?('file')
      expect(data['file']).to eq('lib/foo.rb')
    end

    expect(data).to have_key('stale')
    expect(data['stale']).to be(false)

    # Run tool-specific validations if provided
    if additional_validations
      instance_exec(data, item, &additional_validations)
    end
  end

  # Generate tool-specific examples dynamically
  tool_specific_examples = config[:tool_specific_examples] || {}
  tool_specific_examples.each do |example_name, example_block|
    it example_name do
      expect { instance_exec(config, &example_block) }.not_to raise_error
    end
  end
end

# Configuration data for each file-based MCP tool
FILE_BASED_TOOL_CONFIGS = {
  summary: {
    tool_class: SimpleCovMcp::Tools::CoverageSummaryTool,
    model_method: :summary_for,
    expected_keys: ['file', 'summary', 'stale'],
    output_filename: 'coverage_summary.json',
    description: 'coverage summary data',
    mock_data: {
      'file' => '/abs/path/lib/foo.rb',
      'summary' => { 'covered' => 10, 'total' => 12, 'percentage' => 83.33 }
    },
    additional_validations: ->(data, _item) {
      expect(data['summary']).to include('covered', 'total', 'percentage')
    },
    tool_specific_examples: {
      'includes percentage in summary data' => ->(config) {
        model = instance_double(SimpleCovMcp::CoverageModel)
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(:summary_for).and_return(config[:mock_data])
        allow(model).to receive(:staleness_for).and_return(false)
        relativizer = SimpleCovMcp::PathRelativizer.new(
          root: '/abs/path',
          scalar_keys: %w[file file_path],
          array_keys: %w[newer_files missing_files deleted_files]
        )
        allow(model).to receive(:relativize) { |payload| relativizer.relativize(payload) }
        setup_mcp_response_stub

        response = config[:tool_class].call(path: 'lib/foo.rb',
          server_context: instance_double('ServerContext').as_null_object)
        data, = expect_mcp_text_json(response)

        expect(data['summary']['percentage']).to be_a(Float)
      }
    }
  },

  raw: {
    tool_class: SimpleCovMcp::Tools::CoverageRawTool,
    model_method: :raw_for,
    expected_keys: ['file', 'lines', 'stale'],
    output_filename: 'coverage_raw.json',
    description: 'raw coverage data',
    mock_data: {
      'file' => '/abs/path/lib/foo.rb',
      'lines' => [nil, 1, 0]
    },
    additional_validations: ->(data, _item) {
      expect(data['lines']).to be_an(Array)
    }
  },

  uncovered: {
    tool_class: SimpleCovMcp::Tools::UncoveredLinesTool,
    model_method: :uncovered_for,
    expected_keys: ['file', 'uncovered', 'summary', 'stale'],
    output_filename: 'uncovered_lines.json',
    description: 'uncovered lines data',
    mock_data: {
      'file' => '/abs/path/lib/foo.rb',
      'uncovered' => [5, 9, 12],
      'summary' => { 'covered' => 10, 'total' => 12, 'percentage' => 83.33 }
    },
    additional_validations: ->(data, _item) {
      expect(data['uncovered']).to eq([5, 9, 12])
    },
    tool_specific_examples: {
      'includes both uncovered lines and summary' => ->(config) {
        model = instance_double(SimpleCovMcp::CoverageModel)
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(:uncovered_for).and_return(config[:mock_data])
        allow(model).to receive(:staleness_for).and_return(false)
        relativizer = SimpleCovMcp::PathRelativizer.new(
          root: '/abs/path',
          scalar_keys: %w[file file_path],
          array_keys: %w[newer_files missing_files deleted_files]
        )
        allow(model).to receive(:relativize) { |payload| relativizer.relativize(payload) }
        setup_mcp_response_stub

        response = config[:tool_class].call(path: 'lib/foo.rb',
          server_context: instance_double('ServerContext').as_null_object)
        data, = expect_mcp_text_json(response)

        expect(data['uncovered']).to be_an(Array)
        expect(data['summary']).to include('covered', 'total', 'percentage')
      }
    }
  },

  detailed: {
    tool_class: SimpleCovMcp::Tools::CoverageDetailedTool,
    model_method: :detailed_for,
    expected_keys: ['file', 'lines', 'summary', 'stale'],
    output_filename: 'coverage_detailed.json',
    description: 'detailed coverage data',
    mock_data: {
      'file' => '/abs/path/lib/foo.rb',
      'lines' => [
        { 'line' => 1, 'hits' => 1, 'covered' => true },
        { 'line' => 2, 'hits' => 0, 'covered' => false }
      ],
      'summary' => { 'covered' => 1, 'total' => 2, 'percentage' => 50.0 }
    },
    additional_validations: ->(data, _item) {
      expect(data['lines']).to be_an(Array)
      expect(data['lines'].first).to include('line', 'hits', 'covered')
    }
  }
}.freeze
