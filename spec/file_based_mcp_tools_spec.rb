# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples/file_based_mcp_tools'

# Load all the tool classes that will be tested
require 'simplecov_mcp/tools/coverage_summary_tool'
require 'simplecov_mcp/tools/coverage_raw_tool'
require 'simplecov_mcp/tools/uncovered_lines_tool'
require 'simplecov_mcp/tools/coverage_detailed_tool'

RSpec.describe 'File-based MCP Tools' do
  # Test each file-based tool using the shared example with its specific configuration
  FILE_BASED_TOOL_CONFIGS.each do |tool_name, config|
    describe config[:tool_class] do
      it_behaves_like 'a file-based MCP tool', config
    end
  end
  
  # Test that all file-based tools handle the same parameters consistently
  describe 'parameter consistency' do
    let(:server_context) { instance_double('ServerContext').as_null_object }
    
    before do
      setup_mcp_response_stub
    end
    
    it 'all file-based tools accept the same basic parameters' do
      # Test that all tools can be called with the same parameter signature
      FILE_BASED_TOOL_CONFIGS.each do |tool_name, config|
        model = instance_double(SimpleCovMcp::CoverageModel)
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(config[:model_method]).and_return(config[:mock_data])
        allow(model).to receive(:relativize) { |payload| payload }
        
        expect {
          config[:tool_class].call(
            path: 'lib/example.rb',
            root: '.',
            resultset: 'coverage',
            server_context: server_context
          )
        }.not_to raise_error
      end
    end
    
    it 'all file-based tools return JSON resources with consistent structure' do
      FILE_BASED_TOOL_CONFIGS.each do |tool_name, config|
        model = instance_double(SimpleCovMcp::CoverageModel)
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(config[:model_method]).and_return(config[:mock_data])
        allow(model).to receive(:relativize) { |payload| payload }
        
        response = config[:tool_class].call(path: 'lib/foo.rb', server_context: server_context)
        
        # All should have the same basic MCP resource structure
        expect(response.payload).to be_an(Array)
        expect(response.payload.first['type']).to eq('resource')
        expect(response.payload.first['resource']['mimeType']).to eq('application/json')
        expect(response.payload.first['resource']).to have_key('name')
        expect(response.payload.first['resource']).to have_key('text')
        
        # All should return valid JSON
        expect { JSON.parse(response.payload.first['resource']['text']) }.not_to raise_error
      end
    end
  end
  
  # Performance/behavior comparison tests
  describe 'cross-tool consistency' do
    let(:server_context) { instance_double('ServerContext').as_null_object }
    
    before do
      setup_mcp_response_stub
    end
    
    it 'tools that include summary data return consistent summary format' do
      summary_tools = FILE_BASED_TOOL_CONFIGS.select { |_, config| 
        config[:expected_keys].include?('summary') 
      }
      
      summary_tools.each do |tool_name, config|
        model = instance_double(SimpleCovMcp::CoverageModel)
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
        allow(model).to receive(config[:model_method]).and_return(config[:mock_data])
        allow(model).to receive(:relativize) { |payload| payload }
        
        response = config[:tool_class].call(path: 'lib/foo.rb', server_context: server_context)
        data = JSON.parse(response.payload.first['resource']['text'])
        
        if data.key?('summary')
          expect(data['summary']).to include('covered', 'total', 'pct')
          expect(data['summary']['pct']).to be_a(Numeric)
        end
      end
    end
  end
end
