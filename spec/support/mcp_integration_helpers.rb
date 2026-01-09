# frozen_string_literal: true

module Spec
  module Support
    module McpIntegrationHelpers
      MCP_TIMEOUT = 5

      def jsonrpc_request(id, method, params = nil)
        request = { jsonrpc: '2.0', id: id, method: method }
        request[:params] = params if params
        request
      end

      def jsonrpc_call(id, method, params = nil)
        result = run_mcp_json(jsonrpc_request(id, method, params))
        parse_jsonrpc(result[:stdout])
      end

      def jsonrpc_tool_call(id, name, arguments = {})
        jsonrpc_call(id, 'tools/call', { name: name, arguments: arguments })
      end

      def parse_jsonrpc(output)
        lines = output.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          .lines
          .map(&:strip)
          .reject(&:empty?)

        lines.each do |line|
          parsed = JSON.parse(line)
          return parsed if parsed['jsonrpc'] == '2.0'
        rescue JSON::ParserError
          # Continue searching
        end
        raise "No valid JSON-RPC response found. Output: #{output.inspect}"
      end

      def expect_jsonrpc_result(response, id)
        expect(response).to include('jsonrpc' => '2.0', 'id' => id)
        expect(response).to have_key('result')
        response['result']
      end

      def expect_jsonrpc_error(response, id)
        expect(response).to include('jsonrpc' => '2.0', 'id' => id)
        if response['error']
          expect(response['error']).to have_key('message')
        elsif response['result']
          content = response['result']['content']
          text = content.first['text']
          expect(text.downcase).to match(/error|not found|required/)
        else
          raise 'Expected error or result with error message'
        end
      end
    end
  end
end
