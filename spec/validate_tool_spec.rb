# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/validate_tool'

RSpec.describe SimpleCovMcp::Tools::ValidateTool do
  # We need to mock the MCP server context that BaseTool expects
  let(:server_context) { double('server_context') }

  # Setup the mock model and predicate evaluator
  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }

  before do
    setup_mcp_response_stub
    allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
  end

  describe '.call' do
    context 'with code parameter' do
      let(:code) { '->(m) { true }' }

      it 'evaluates the code using PredicateEvaluator' do
        allow(SimpleCovMcp::PredicateEvaluator).to receive(:evaluate_code)
          .with(code, model)
          .and_return(true)

        response = described_class.call(code: code, server_context: server_context)

        data, = expect_mcp_text_json(response, expected_keys: ['result'])
        expect(data['result']).to be true
      end

      it 'returns false when predicate evaluates to false' do
        allow(SimpleCovMcp::PredicateEvaluator).to receive(:evaluate_code)
          .with(code, model)
          .and_return(false)

        response = described_class.call(code: code, server_context: server_context)

        data, = expect_mcp_text_json(response, expected_keys: ['result'])
        expect(data['result']).to be false
      end
    end

    context 'with file parameter' do
      let(:file) { 'policy.rb' }

      it 'evaluates the file using PredicateEvaluator' do
        allow(SimpleCovMcp::PredicateEvaluator).to receive(:evaluate_file)
          .with(file, model)
          .and_return(true)

        response = described_class.call(file: file, server_context: server_context)

        data, = expect_mcp_text_json(response, expected_keys: ['result'])
        expect(data['result']).to be true
      end
    end

    context 'with both code and file parameters' do
      it 'returns an error response' do
        response = described_class.call(code: 'foo', file: 'bar', server_context: server_context)

        item = response.payload.first
        expect(item[:type]).to eq('text')
        expect(item[:text]).to include('Error:')
        expect(item[:text]).to include('Provide either code or file parameter, not both')
      end
    end

    context 'with neither code nor file parameter' do
      it 'returns an error response' do
        response = described_class.call(server_context: server_context)

        item = response.payload.first
        expect(item[:type]).to eq('text')
        expect(item[:text]).to include('Error:')
        expect(item[:text]).to include('Either code or file parameter is required')
      end
    end

    context 'when PredicateEvaluator raises an error' do
      it 'handles the error gracefully' do
        allow(SimpleCovMcp::PredicateEvaluator).to receive(:evaluate_code)
          .and_raise('Syntax Error')

        response = described_class.call(code: 'bad code', server_context: server_context)

        item = response.payload.first
        expect(item[:type]).to eq('text')
        expect(item[:text]).to include('Error:')
        expect(item[:text]).to include('Syntax Error')
      end
    end

    context 'when CoverageModel initialization fails' do
      it 'handles the error gracefully' do
        allow(SimpleCovMcp::CoverageModel).to receive(:new).and_raise(RuntimeError, 'Model error')

        response = described_class.call(code: 'ok', server_context: server_context)

        item = response.payload.first
        expect(item[:type]).to eq('text')
        expect(item[:text]).to include('Error:')
        expect(item[:text]).to include('Model error')
      end
    end
  end
end
