# frozen_string_literal: true

require 'spec_helper'

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
        expect(summary['summary']['pct']).to be_within(0.01).of(66.67)
        
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
      list_output = nil
      silence_output do |out, _err|
        cli = SimpleCovMcp::CoverageCLI.new
        cli.run(['list', '--root', project_root, '--resultset', coverage_dir])
        list_output = out.string
      end
      
      expect(list_output).to include('lib/foo.rb', 'lib/bar.rb')
      expect(list_output).to include('66.67', '33.33')
      
      # Test summary command
      summary_output = nil
      silence_output do |out, _err|
        cli = SimpleCovMcp::CoverageCLI.new
        cli.run(['summary', 'lib/foo.rb', '--root', project_root, '--resultset', coverage_dir])
        summary_output = out.string
      end
      
      expect(summary_output).to include('66.67%', '2/3')
      
      # Test JSON output
      json_output = nil
      silence_output do |out, _err|
        cli = SimpleCovMcp::CoverageCLI.new
        cli.run(['summary', 'lib/foo.rb', '--json', '--root', project_root, '--resultset', coverage_dir])
        json_output = out.string
      end
      
      json_data = JSON.parse(json_output)
      expect(json_data).to include('file', 'summary')
      expect(json_data['summary']).to include('covered' => 2, 'total' => 3)
    end
    
    it 'handles different output formats correctly' do
      # Test uncovered command with different outputs
      uncovered_output = nil
      silence_output do |out, _err|
        cli = SimpleCovMcp::CoverageCLI.new
        cli.run(['uncovered', 'lib/foo.rb', '--root', project_root, '--resultset', coverage_dir])
        uncovered_output = out.string
      end
      
      expect(uncovered_output).to match(/Uncovered lines:\s*2\b/)
      
      # Test detailed command
      detailed_output = nil
      silence_output do |out, _err|
        cli = SimpleCovMcp::CoverageCLI.new
        cli.run(['detailed', 'lib/foo.rb', '--root', project_root, '--resultset', coverage_dir])
        detailed_output = out.string
      end
      
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
      
      data, item = expect_mcp_json_resource(summary_response, expected_keys: ['file', 'summary'])
      expect(data['summary']).to include('covered' => 2, 'total' => 3)
      expect(item['resource']['name']).to eq('coverage_summary.json')
      
      # Test raw coverage tool
      raw_response = SimpleCovMcp::Tools::CoverageRawTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )
      
      raw_data, raw_item = expect_mcp_json_resource(raw_response, expected_keys: ['file', 'lines'])
      expect(raw_data['lines']).to eq([1, 0, nil, 2])
      expect(raw_item['resource']['name']).to eq('coverage_raw.json')
      
      # Test all files tool
      all_files_response = SimpleCovMcp::Tools::AllFilesCoverageTool.call(
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )
      
      all_data, _ = expect_mcp_json_resource(all_files_response, expected_keys: ['files', 'counts'])
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
      summary_data, _ = expect_mcp_json_resource(summary_response)
      
      # Get data from detailed tool
      detailed_response = SimpleCovMcp::Tools::CoverageDetailedTool.call(
        path: 'lib/foo.rb',
        root: project_root,
        resultset: coverage_dir,
        server_context: server_context
      )
      detailed_data, _ = expect_mcp_json_resource(detailed_response)
      
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
      
      expect {
        model.summary_for('lib/nonexistent.rb')
      }.to raise_error(RuntimeError, /No coverage entry found/)
    end
    
    it 'handles invalid resultset paths gracefully' do
      expect {
        SimpleCovMcp::CoverageModel.new(root: project_root, resultset: '/nonexistent/path')
      }.to raise_error(SimpleCovMcp::CoverageDataError, /Failed to load coverage data/)
    end
    
    it 'provides helpful CLI error messages' do
      output, error, status = nil, nil, nil
      silence_output do |out, err|
        begin
          cli = SimpleCovMcp::CoverageCLI.new
          cli.run(['summary', 'lib/nonexistent.rb', '--root', project_root, '--resultset', coverage_dir])
          status = 0
        rescue SystemExit => e
          status = e.status
        end
        output = out.string
        error = err.string
      end
      
      expect(status).to eq(1)
      expect(error).to include('File error:', 'No coverage data found for file')
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
end
