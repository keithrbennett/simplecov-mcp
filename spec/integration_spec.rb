# frozen_string_literal: true

require 'spec_helper'

# Timeout for MCP server operations (increased for JRuby compatibility)
MCP_TIMEOUT = 5

RSpec.describe 'SimpleCov MCP Integration Tests' do
  let(:project_root) { (FIXTURES_DIR / 'project1').to_s }
  let(:coverage_dir) { File.join(project_root, 'coverage') }
  let(:resultset_path) { File.join(coverage_dir, '.resultset.json') }

  describe 'End-to-End Coverage Model Functionality' do
    context 'with real coverage data and files' do
      it 'provides complete coverage analysis workflow' do
        # Initialize model with real fixture data
        model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

        # Test all_files returns real coverage data
        all_files = model.all_files
        expect(all_files).to be_an(Array)
        expect(all_files.length).to eq(2)

        # Verify file paths and coverage data structure
        foo_file = all_files.find { |f| f['file'].include?('foo.rb') }
        bar_file = all_files.find { |f| f['file'].include?('bar.rb') }

        expect(foo_file).to include('covered', 'total', 'percentage', 'stale')
        expect(bar_file).to include('covered', 'total', 'percentage', 'stale')

        # Verify actual coverage calculations match fixture data
        # foo.rb has coverage: [1, 0, nil, 2] -> 2 covered out of 3 executable = 66.67%
        expect(foo_file['total']).to eq(3)
        expect(foo_file['covered']).to eq(2)
        expect(foo_file['percentage']).to be_within(0.01).of(66.67)

        # bar.rb has coverage: [0, 0, 1] -> 1 covered out of 3 executable = 33.33%
        expect(bar_file['total']).to eq(3)
        expect(bar_file['covered']).to eq(1)
        expect(bar_file['percentage']).to be_within(0.01).of(33.33)
      end

      it 'provides detailed per-file analysis' do
        model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

        # Test raw coverage data
        raw = model.raw_for('lib/foo.rb')
        expect(raw['file']).to end_with('lib/foo.rb')
        expect(raw['lines']).to eq([1, 0, nil, 2])

        # Test summary calculation
        summary = model.summary_for('lib/foo.rb')
        expect(summary['file']).to end_with('lib/foo.rb')
        expect(summary['summary']).to include('covered' => 2, 'total' => 3)
        expect(summary['summary']['percentage']).to be_within(0.01).of(66.67)

        # Test uncovered lines detection
        uncovered = model.uncovered_for('lib/foo.rb')
        expect(uncovered['file']).to end_with('lib/foo.rb')
        expect(uncovered['uncovered']).to eq([2]) # Line 2 has 0 hits
        expect(uncovered['summary']).to include('covered' => 2, 'total' => 3)

        # Test detailed line-by-line analysis
        detailed = model.detailed_for('lib/foo.rb')
        expect(detailed['file']).to end_with('lib/foo.rb')
        expect(detailed['lines']).to eq([
          { 'line' => 1, 'hits' => 1, 'covered' => true },
          { 'line' => 2, 'hits' => 0, 'covered' => false },
          { 'line' => 4, 'hits' => 2, 'covered' => true }
        ])
      end

      it 'generates properly formatted coverage tables' do
        model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

        # Test default table generation
        table = model.format_table

        # Verify table structure (Unicode box drawing)
        expect(table).to include('┌', '┬', '┐', '│', '├', '┼', '┤', '└', '┴', '┘')

        # Verify headers
        expect(table).to include('File', '%', 'Covered', 'Total', 'Stale')

        # Verify file data appears
        expect(table).to include('lib/foo.rb', 'lib/bar.rb')

        # Verify percentages are formatted correctly
        expect(table).to include('66.67', '33.33')

        # Verify counts summary
        expect(table).to include('Files: total 2')

        # Test sorting (ascending by default - bar.rb should be first with lower coverage)
        lines = table.split("\n")
        data_lines = lines.select { |line| line.include?('lib/') }
        expect(data_lines.first).to include('lib/bar.rb') # Lower coverage first
        expect(data_lines.last).to include('lib/foo.rb')  # Higher coverage last
      end

      it 'supports different sorting options' do
        model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

        # Test ascending sort
        asc_files = model.all_files(sort_order: :ascending)
        expect(asc_files.first['file']).to end_with('lib/bar.rb')  # Lower coverage first
        expect(asc_files.last['file']).to end_with('lib/foo.rb')   # Higher coverage last

        # Test descending sort
        desc_files = model.all_files(sort_order: :descending)
        expect(desc_files.first['file']).to end_with('lib/foo.rb') # Higher coverage first
        expect(desc_files.last['file']).to end_with('lib/bar.rb')  # Lower coverage last
      end
    end
  end

  describe 'CLI Integration with Real Coverage Data' do
    it 'executes all major CLI commands without errors' do
      # Test list command
      list_output, _err, status = run_cli_with_status('--root', project_root, '--resultset',
        coverage_dir, 'list')
      expect(status).to eq(0)
      expect(list_output).to include('lib/foo.rb', 'lib/bar.rb')
      expect(list_output).to include('66.67', '33.33')
      data_lines = list_output.lines.select { |line| line.include?('lib/') }
      expect(data_lines.first).to include('lib/foo.rb') # Highest coverage first (descending default)
      expect(data_lines.last).to include('lib/bar.rb')

      # Test summary command
      summary_output, _err, status = run_cli_with_status('--root', project_root, '--resultset',
        coverage_dir, 'summary', 'lib/foo.rb')
      expect(status).to eq(0)
      expect(summary_output).to include('│')  # Table format
      expect(summary_output).to include('66.67%')
      expect(summary_output).to include('2')
      expect(summary_output).to include('3')

      # Test JSON output
      json_output, _err, status = run_cli_with_status(
        '--format', 'json', '--root', project_root, '--resultset', coverage_dir,
        'summary', 'lib/foo.rb'
      )
      expect(status).to eq(0)
      json_data = JSON.parse(json_output)
      expect(json_data).to include('file', 'summary')
      expect(json_data['summary']).to include('covered' => 2, 'total' => 3)
    end

    it 'handles different output formats correctly' do
      # Test uncovered command with different outputs
      uncovered_output, _err, status = run_cli_with_status(
        '--root', project_root, '--resultset', coverage_dir, 'uncovered', 'lib/foo.rb'
      )
      expect(status).to eq(0)
      expect(uncovered_output).to include('│')  # Table format

      # Test detailed command
      detailed_output, _err, status = run_cli_with_status(
        '--root', project_root, '--resultset', coverage_dir, 'detailed', 'lib/foo.rb'
      )
      expect(status).to eq(0)
      expect(detailed_output).to include('Line', 'Hits', 'Covered')
    end
  end

  describe 'MCP Tool Integration with Real Data' do
    let(:server_context) { instance_double('ServerContext').as_null_object }

    before do
      setup_mcp_response_stub
    end

    it 'executes all MCP tools with real coverage data' do
      # Test coverage summary tool
      summary_response = SimpleCovMcp::Tools::CoverageSummaryTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )

      data, _item = expect_mcp_text_json(summary_response, expected_keys: ['file', 'summary'])
      expect(data['summary']).to include('covered' => 2, 'total' => 3)

      # Test raw coverage tool
      raw_response = SimpleCovMcp::Tools::CoverageRawTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )

      raw_data, _raw_item = expect_mcp_text_json(raw_response, expected_keys: ['file', 'lines'])
      expect(raw_data['lines']).to eq([1, 0, nil, 2])

      # Test all files tool
      all_files_response = SimpleCovMcp::Tools::AllFilesCoverageTool.call(
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )

      all_data, = expect_mcp_text_json(all_files_response, expected_keys: ['files', 'counts'])
      expect(all_data['files'].length).to eq(2)
      expect(all_data['counts']['total']).to eq(2)
    end

    it 'provides consistent data across different tools' do
      # Get data from summary tool
      summary_response = SimpleCovMcp::Tools::CoverageSummaryTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )
      summary_data, = expect_mcp_text_json(summary_response)

      # Get data from detailed tool
      detailed_response = SimpleCovMcp::Tools::CoverageDetailedTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )
      detailed_data, = expect_mcp_text_json(detailed_response)

      # Verify consistency between tools
      expect(summary_data['summary']['covered']).to eq(2)
      expect(summary_data['summary']['total']).to eq(3)
      expect(detailed_data['summary']['covered']).to eq(2)
      expect(detailed_data['summary']['total']).to eq(3)

      # Count covered lines in detailed data
      covered_lines = detailed_data['lines'].count { |line| line['covered'] }
      expect(covered_lines).to eq(2)
    end
  end

  describe 'Error Handling Integration' do
    it 'handles missing files gracefully' do
      model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

      expect do
        model.summary_for('lib/nonexistent.rb')
      end.to raise_error(SimpleCovMcp::FileError, /No coverage entry found/)
    end

    it 'handles invalid resultset paths gracefully' do
      expect do
        SimpleCovMcp::CoverageModel.new(root: project_root, resultset: '/nonexistent/path')
      end.to raise_error(SimpleCovMcp::ResultsetNotFoundError, /Specified resultset not found/)
    end

    it 'provides helpful CLI error messages' do
      _output, error, status = run_cli_with_status(
        '--root', project_root, '--resultset', coverage_dir, 'summary', 'lib/nonexistent.rb'
      )

      expect(status).to eq(1)
      expect(error).to include('File error:', 'No coverage entry found')
    end
  end

  describe 'Multi-File Scenarios' do
    it 'handles projects with mixed coverage levels' do
      model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

      # Get all files and verify range of coverage
      files = model.all_files
      coverages = files.map { |f| f['percentage'] }

      expect(coverages.min).to be < 50  # bar.rb at ~33%
      expect(coverages.max).to be > 50  # foo.rb at ~67%
      expect(coverages).to include(a_value_within(0.1).of(33.33))
      expect(coverages).to include(a_value_within(0.1).of(66.67))
    end

    it 'generates comprehensive project reports' do
      model = SimpleCovMcp::CoverageModel.new(root: project_root, resultset: coverage_dir)

      table = model.format_table

      # Should show both files with different coverage levels
      expect(table).to match(/lib\/bar\.rb.*33\.33/)
      expect(table).to match(/lib\/foo\.rb.*66\.67/)

      # Should show project totals
      expect(table).to include('Files: total 2')
    end
  end

  describe 'MCP Server Protocol Integration', :slow do
    # spec/ is one level deep, so ../.. goes up to repo root
    let(:repo_root) { File.expand_path('..', __dir__) }
    let(:exe_path) { File.join(repo_root, 'exe', 'simplecov-mcp') }
    let(:lib_path) { File.join(repo_root, 'lib') }

    let(:default_env) do
      {
        'RUBY_LIB' => lib_path,
        'SIMPLECOV_MCP_OPTS' => "--root #{project_root} --resultset #{coverage_dir} --log-file /dev/null"
      }
    end

    def runner_args(env: default_env, timeout: 5)
      {
        env: env,
        lib_path: lib_path,
        exe_path: exe_path,
        timeout: timeout
      }
    end

    # Run the MCP executable with a single JSON-RPC request hash and return the captured streams.
    def run_mcp_json(request_hash, env: default_env, timeout: MCP_TIMEOUT)
      Spec::Support::McpRunner.call_json(
        request_hash,
        **runner_args(env: env, timeout: timeout)
      )
    end

    # Run the MCP executable with a sequence of JSON-RPC requests (one per line).
    def run_mcp_json_stream(request_hashes, env: default_env, timeout: MCP_TIMEOUT)
      Spec::Support::McpRunner.call_json_stream(
        request_hashes,
        **runner_args(env: env, timeout: timeout)
      )
    end

    # Run the MCP executable with a raw string payload (already encoded as needed).
    def run_mcp_input(input, env: default_env, timeout: MCP_TIMEOUT)
      Spec::Support::McpRunner.call(
        input: input,
        **runner_args(env: env, timeout: timeout)
      )
    end

    def parse_jsonrpc_response(output)
      # MCP server should only write JSON-RPC responses to stdout.
      # Force UTF-8 encoding to handle any binary data in the output stream.
      safe_output = output.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      safe_output.lines.each do |line|
        stripped = line.strip
        next if stripped.empty?

        begin
          parsed = JSON.parse(stripped)
        rescue JSON::ParserError => e
          raise "Unexpected non-JSON output from MCP server stdout: #{stripped.inspect} (#{e.message})"
        end

        return parsed if parsed['jsonrpc'] == '2.0'

        raise "Unexpected JSON-RPC payload on stdout: #{stripped.inspect}"
      end

      raise "No JSON-RPC response found on stdout. Raw output: #{output.inspect}"
    end

    it 'starts MCP server without errors' do
      request = {
        jsonrpc: '2.0',
        id: 1,
        method: 'tools/list'
      }

      result = run_mcp_json(request)
      stdout = result[:stdout]
      stderr = result[:stderr]

      # Should not crash with NameError about OptionParser
      expect(stderr).not_to include('NameError')
      expect(stderr).not_to include('uninitialized constant')
      expect(stderr).not_to include('OptionParser')

      # Should produce valid JSON-RPC output
      response = parse_jsonrpc_response(stdout)
      expect(response).not_to be_nil
      expect(response['jsonrpc']).to eq('2.0')
      expect(response['id']).to eq(1)
    end

    it 'handles tools/list request' do
      request = {
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/list'
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response).to include('result')
      tools = response['result']['tools']
      expect(tools).to be_an(Array)

      # Verify expected tools are registered
      tool_names = tools.map { |t| t['name'] }
      expect(tool_names).to include(
        'all_files_coverage_tool',
        'coverage_summary_tool',
        'coverage_raw_tool',
        'uncovered_lines_tool',
        'coverage_detailed_tool',
        'coverage_table_tool',
        'help_tool',
        'version_tool'
      )
    end

    it 'executes coverage_summary_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 3,
        method: 'tools/call',
        params: {
          name: 'coverage_summary_tool',
          arguments: {
            path: 'lib/foo.rb',
            root: project_root,
            resultset: coverage_dir
          }
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(3)
      expect(response).to have_key('result')

      content = response['result']['content']
      expect(content).to be_an(Array)
      expect(content.first['type']).to eq('text')

      # Parse the JSON coverage data from the text response
      coverage_data = JSON.parse(content.first['text'])
      expect(coverage_data).to include('file', 'summary')
      expect(coverage_data['summary']).to include('covered' => 2, 'total' => 3)
    end

    it 'executes all_files_coverage_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 4,
        method: 'tools/call',
        params: {
          name: 'all_files_coverage_tool',
          arguments: {
            root: project_root,
            resultset: coverage_dir
          }
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(4)
      content = response['result']['content']
      coverage_data = JSON.parse(content.first['text'])

      expect(coverage_data).to include('files', 'counts')
      expect(coverage_data['files']).to be_an(Array)
      expect(coverage_data['files'].length).to eq(2)
      expect(coverage_data['counts']['total']).to eq(2)
    end

    it 'executes uncovered_lines_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 5,
        method: 'tools/call',
        params: {
          name: 'uncovered_lines_tool',
          arguments: {
            path: 'lib/foo.rb',
            root: project_root,
            resultset: coverage_dir
          }
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(5)
      content = response['result']['content']
      coverage_data = JSON.parse(content.first['text'])

      expect(coverage_data).to include('file', 'uncovered', 'summary')
      expect(coverage_data['uncovered']).to eq([2]) # Line 2 is uncovered
    end

    it 'executes help_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 6,
        method: 'tools/call',
        params: {
          name: 'help_tool',
          arguments: {}
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(6)
      content = response['result']['content']
      expect(content.first['type']).to eq('text')

      # Help tool returns JSON with tool list
      help_data = JSON.parse(content.first['text'])
      expect(help_data).to have_key('tools')
      expect(help_data['tools']).to be_an(Array)
      tool_names = help_data['tools'].map { |t| t['tool'] }
      expect(tool_names).to include('coverage_summary_tool')
    end

    it 'executes version_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 7,
        method: 'tools/call',
        params: {
          name: 'version_tool',
          arguments: {}
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(7)
      content = response['result']['content']
      expect(content.first['type']).to eq('text')

      version_text = content.first['text']
      # Version format is "SimpleCovMcp version: X.Y.Z"
      expect(version_text).to match(/SimpleCovMcp version: \d+\.\d+/)
    end

    it 'executes validate_tool via JSON-RPC' do
      request = {
        jsonrpc: '2.0',
        id: 80,
        method: 'tools/call',
        params: {
          name: 'validate_tool',
          arguments: {
            code: '->(m) { true }',
            root: project_root,
            resultset: coverage_dir
          }
        }
      }

      stdout = run_mcp_json(request)[:stdout]
      response = parse_jsonrpc_response(stdout)

      expect(response['id']).to eq(80)
      content = response['result']['content']
      expect(content.first['type']).to eq('text')

      begin
        result_json = JSON.parse(content.first['text'])
      rescue JSON::ParserError
        puts "DEBUG: Failed to parse JSON. Content was: #{content.first['text']}"
        raise
      end
      expect(result_json).to include('result' => true)
    end

    it 'handles error responses for invalid tool calls' do
      request = {
        jsonrpc: '2.0',
        id: 8,
        method: 'tools/call',
        params: {
          name: 'coverage_summary_tool',
          arguments: {
            path: 'nonexistent_file.rb',
            root: project_root,
            resultset: coverage_dir
          }
        }
      }

      result = run_mcp_json(request)
      response = parse_jsonrpc_response(result[:stdout])

      # MCP should return a response (not crash)
      expect(response['id']).to eq(8)

      # Should include error information in content or error field
      if response['error']
        expect(response['error']).to have_key('message')
      elsif response['result']
        content = response['result']['content']
        text = content.first['text']
        expect(text.downcase).to include('error').or include('not found')
      end
    end

    it 'handles malformed JSON-RPC requests' do
      malformed_request = "{'jsonrpc': '2.0', 'id': 999, 'method': 'invalid'}"

      env = { 'RUBY_LIB' => lib_path }
      result = run_mcp_input(malformed_request, env: env)

      # Should handle gracefully without crashing
      # May return error response or empty output
      expect(result[:stderr]).not_to include('NameError')
      expect(result[:stderr]).not_to include('uninitialized constant')
    end

    it 'respects --log-file configuration in MCP mode' do
      request = {
        jsonrpc: '2.0',
        id: 10,
        method: 'tools/call',
        params: {
          name: 'version_tool',
          arguments: {}
        }
      }

      result = run_mcp_json(
        request,
        env: default_env.merge('SIMPLECOV_MCP_OPTS' => '--log-file stderr')
      )

      response = parse_jsonrpc_response(result[:stdout])
      expect(response).not_to be_nil
      expect(response['id']).to eq(10)
    end

    it 'prohibits stdout logging in MCP mode' do
      # Attempt to start MCP server with --log-file stdout should fail
      env = {
        'RUBY_LIB' => lib_path,
        'SIMPLECOV_MCP_OPTS' => '--log-file stdout'
      }

      result = run_mcp_input(nil, env: env)

      combined_output = result[:stdout] + result[:stderr]
      expect(combined_output).to include('stdout').and include('not permitted')
      expect(result[:status].exitstatus).not_to eq(0)
    end

    it 'handles multiple sequential requests' do
      requests = [
        { jsonrpc: '2.0', id: 100, method: 'tools/list' },
        { jsonrpc: '2.0', id: 101, method: 'tools/call',
          params: { name: 'version_tool', arguments: {} } }
      ]

      result = run_mcp_json_stream(requests)

      # Force UTF-8 encoding to handle any binary data in the output stream
      safe_stdout = result[:stdout].to_s
        .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      responses = safe_stdout.lines.map do |line|
        next if line.strip.empty?

        begin
          parsed = JSON.parse(line)
          parsed if parsed['jsonrpc'] == '2.0'
        rescue JSON::ParserError
          nil
        end
      end.compact

      expect(responses.length).to be >= 1
      response_ids = responses.map { |r| r['id'] }
      expect(response_ids).to include(100).or include(101)
    end

    context 'when handling MCP protocol errors' do
      it 'returns error for unknown tool name' do
        request = {
          jsonrpc: '2.0',
          id: 200,
          method: 'tools/call',
          params: {
            name: 'nonexistent_tool_that_does_not_exist',
            arguments: {}
          }
        }

        result = run_mcp_json(request)
        response = parse_jsonrpc_response(result[:stdout])

        expect(response['id']).to eq(200)
        expect(response['jsonrpc']).to eq('2.0')

        # MCP server should return error in result content or error field
        if response['error']
          # Standard JSON-RPC error format
          expect(response['error']).to have_key('message')
          # MCP returns "Internal error" for unknown tools
          expect(response['error']['message']).to be_a(String)
          expect(response['error']['message'].length).to be > 0
        elsif response['result']
          # MCP may wrap errors in content
          content = response['result']['content']
          expect(content).to be_an(Array)
          text = content.first['text']
          expect(text.downcase).to include('error').or include('not found')
        else
          raise 'Expected either error or result field in response'
        end
      end

      it 'returns error for missing required arguments' do
        request = {
          jsonrpc: '2.0',
          id: 201,
          method: 'tools/call',
          params: {
            name: 'coverage_summary_tool',
            arguments: {} # Missing required 'path' argument
          }
        }

        result = run_mcp_json(request)
        response = parse_jsonrpc_response(result[:stdout])

        expect(response['id']).to eq(201)
        expect(response['jsonrpc']).to eq('2.0')

        # Should return an error about missing path
        if response['error']
          expect(response['error']).to have_key('message')
        elsif response['result']
          content = response['result']['content']
          text = content.first['text']
          expect(text.downcase).to include('error').or include('required').or include('path')
        else
          raise 'Expected either error or result field in response'
        end
      end

      it 'handles invalid argument types gracefully' do
        request = {
          jsonrpc: '2.0',
          id: 202,
          method: 'tools/call',
          params: {
            name: 'coverage_summary_tool',
            arguments: {
              path: 12_345, # Should be string, not number
              root: project_root,
              resultset: coverage_dir
            }
          }
        }

        result = run_mcp_json(request)
        response = parse_jsonrpc_response(result[:stdout])

        expect(response['id']).to eq(202)
        expect(response['jsonrpc']).to eq('2.0')

        # Should handle gracefully (may coerce to string or return error)
        expect(response).to have_key('result').or have_key('error')
      end

      it 'returns properly formatted JSON-RPC error responses' do
        request = {
          jsonrpc: '2.0',
          id: 203,
          method: 'tools/call',
          params: {
            name: 'coverage_summary_tool',
            arguments: {
              path: 'definitely_does_not_exist.rb',
              root: project_root,
              resultset: coverage_dir
            }
          }
        }

        result = run_mcp_json(request)
        response = parse_jsonrpc_response(result[:stdout])

        # Verify JSON-RPC 2.0 compliance
        expect(response).to include('jsonrpc' => '2.0', 'id' => 203)

        # Must have either 'result' or 'error', but not both
        has_result = response.key?('result')
        has_error = response.key?('error')
        expect(has_result ^ has_error).to be true

        # If error field exists, verify structure
        if has_error
          expect(response['error']).to have_key('message')
          expect(response['error']['message']).to be_a(String)
        end
      end

      it 'handles requests with missing params field' do
        request = {
          jsonrpc: '2.0',
          id: 204,
          method: 'tools/call'
          # Missing params field entirely
        }

        result = run_mcp_json(request)

        # Should not crash - either returns error or handles gracefully
        expect(result[:stderr]).not_to include('NameError')
        expect(result[:stderr]).not_to include('NoMethodError')

        # Parse response if available
        if result[:stdout] && !result[:stdout].strip.empty?
          response = parse_jsonrpc_response(result[:stdout])
          expect(response['jsonrpc']).to eq('2.0')
          expect(response['id']).to eq(204)
        end
      end

      it 'handles completely invalid JSON input' do
        invalid_json = 'this is not JSON at all'

        result = run_mcp_input(invalid_json, env: default_env)

        # Should not crash with unhandled exception
        combined = result[:stdout] + result[:stderr]
        expect(combined).not_to include('uninitialized constant')

        # May log error to stderr, but shouldn't crash
        if result[:status]
          # Exit code may be non-zero but shouldn't be a crash (e.g., signal)
          expect(result[:status].exitstatus).to be_a(Integer)
        end
      end

      it 'handles empty input gracefully' do
        result = run_mcp_input('', env: default_env)

        # Empty input should be handled without crash
        expect(result[:stderr]).not_to include('NameError')
        expect(result[:stderr]).not_to include('NoMethodError')
      end

      it 'handles partial JSON input' do
        partial_json = '{"jsonrpc": "2.0", "id": 300, "method":'

        result = run_mcp_input(partial_json, env: default_env)

        # Should handle gracefully without crashing
        expect(result[:stderr]).not_to include('uninitialized constant')
      end
    end
  end
end
