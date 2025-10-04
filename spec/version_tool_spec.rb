# frozen_string_literal: true

require 'spec_helper'
require 'simplecov_mcp/tools/version_tool'

RSpec.describe SimpleCovMcp::Tools::VersionTool do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  it 'returns a text payload with the version string' do
    response = described_class.call(server_context: server_context)
    item = response.payload.first
    expect(item[:type] || item['type']).to eq('text')
    text = item[:text] || item['text']
    expect(text).to include('SimpleCovMcp version:')
    expect(text).to include(SimpleCovMcp::VERSION)
  end
end

