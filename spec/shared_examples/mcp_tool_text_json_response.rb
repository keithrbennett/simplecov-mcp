# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'an MCP tool that returns text JSON' do
  let(:server_context) { instance_double('ServerContext').as_null_object }

  before do
    setup_mcp_response_stub
  end

  it 'returns a properly structured MCP text JSON response' do
    response = subject
    expect_mcp_text_json(response)
  end
end
