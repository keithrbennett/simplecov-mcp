# frozen_string_literal: true

# MCP Tool shared examples and helpers
module MCPToolTestHelpers
  def null_server_context
    instance_double('ServerContext', app_config: nil).as_null_object
  end

  def setup_mcp_response_stub
    # Standardized MCP::Tool::Response stub that works for all tools
    response_class = Class.new do
      attr_reader :payload, :meta

      def initialize(payload, meta: nil)
        @payload = payload
        @meta = meta
      end
    end
    stub_const('MCP::Tool::Response', response_class)
  end

  def expect_mcp_text_json(response, expected_keys: [])
    item = response.payload.first

    # Check for a 'text' part
    expect(item['type']).to eq('text')
    expect(item).to have_key('text')

    # Parse and validate JSON content
    data = JSON.parse(item['text'])

    # Check for expected keys
    expected_keys.each do |key|
      expect(data).to have_key(key)
    end

    [data, item] # Return for additional custom assertions
  end
end
