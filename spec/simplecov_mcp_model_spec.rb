# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageModel do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  subject(:model) { described_class.new(root: root) }

  describe 'initialization error handling' do
    it 'raises FileError when File.read raises Errno::ENOENT directly' do
      # Stub find_resultset to return a path, but File.read to raise ENOENT
      allow(SimpleCovMcp::CovUtil).to receive(:find_resultset).and_return('/some/path/.resultset.json')
      allow(File).to receive(:read).with('/some/path/.resultset.json').and_raise(Errno::ENOENT, 'No such file')

      expect do
        described_class.new(root: root, resultset: '/some/path/.resultset.json')
      end.to raise_error(SimpleCovMcp::FileError, /Coverage data not found/)
    end

    it 'raises CoverageDataError when resultset file does not exist' do
      expect do
        described_class.new(root: root, resultset: '/nonexistent/path/.resultset.json')
      end.to raise_error(SimpleCovMcp::CoverageDataError, /Failed to load coverage data/)
    end
  end

  describe 'raw_for' do
    it 'returns absolute file and lines array' do
      data = model.raw_for('lib/foo.rb')
      expect(data['file']).to eq(File.expand_path('lib/foo.rb', root))
      expect(data['lines']).to eq([1, 0, nil, 2])
    end
  end

  describe 'summary_for' do
    it 'computes covered/total/pct' do
      data = model.summary_for('lib/foo.rb')
      expect(data['summary']['total']).to eq(3)
      expect(data['summary']['covered']).to eq(2)
      expect(data['summary']['pct']).to be_within(0.01).of(66.67)
    end
  end

  describe '#relativize' do
    it 'returns a copy with file paths relative to the root' do
      data = model.summary_for('lib/foo.rb')
      relative = model.relativize(data)

      expect(relative['file']).to eq('lib/foo.rb')
      expect(data['file']).not_to eq(relative['file'])
      expect(relative).not_to equal(data)
    end
  end

  describe 'uncovered_for' do
    it 'lists uncovered executable line numbers' do
      data = model.uncovered_for('lib/foo.rb')
      expect(data['uncovered']).to eq([2])
      expect(data['summary']['total']).to eq(3)
    end
  end

  describe 'detailed_for' do
    it 'returns per-line details for non-nil lines' do
      data = model.detailed_for('lib/foo.rb')
      expect(data['lines']).to eq([
        { 'line' => 1, 'hits' => 1, 'covered' => true },
        { 'line' => 2, 'hits' => 0, 'covered' => false },
        { 'line' => 4, 'hits' => 2, 'covered' => true }
      ])
    end
  end

  describe 'staleness_for' do
    it 'returns the staleness character for a file' do
      allow_any_instance_of(SimpleCovMcp::StalenessChecker).to receive(:stale_for_file?) do |_, file_abs, _|
        if file_abs == File.expand_path('lib/foo.rb', root)
          'T'
        else
          false
        end
      end

      expect(model.staleness_for('lib/foo.rb')).to eq('T')
      expect(model.staleness_for('lib/bar.rb')).to eq(false)
    end

    it 'returns false when an exception occurs during staleness check' do
      # Stub the checker to raise an error
      allow_any_instance_of(SimpleCovMcp::StalenessChecker).to receive(:stale_for_file?).and_raise(StandardError, 'Something went wrong')

      # The rescue clause should catch the error and return false
      expect(model.staleness_for('lib/foo.rb')).to eq(false)
    end

    it 'returns false when coverage data is not found for the file' do
      # Try to get staleness for a file that doesn't exist in coverage
      expect(model.staleness_for('lib/nonexistent.rb')).to eq(false)
    end
  end

  describe 'all_files' do
    it 'sorts ascending by percentage then by file path' do
      files = model.all_files(sort_order: :ascending)
      expect(files.first['file']).to eq(File.expand_path('lib/bar.rb', root))
      expect(files.first['percentage']).to be_within(0.01).of(33.33)
      expect(files.last['file']).to eq(File.expand_path('lib/foo.rb', root))
    end

    it 'filters rows when tracked_globs are provided' do
      files = model.all_files(tracked_globs: ['lib/foo.rb'])

      expect(files.length).to eq(1)
      expect(files.first['file']).to eq(File.expand_path('lib/foo.rb', root))
    end

    it 'combines results from multiple tracked_globs patterns' do
      abs_bar = File.expand_path('lib/bar.rb', root)

      files = model.all_files(tracked_globs: ['lib/foo.rb', abs_bar])

      expect(files.map { |f| f['file'] }).to contain_exactly(
        File.expand_path('lib/foo.rb', root),
        abs_bar
      )
    end

    it 'handles files with paths that cannot be relativized' do
      # Create a custom row with a path from a Windows-style drive (C:/) that will cause ArgumentError
      # when trying to make it relative to a Unix-style root
      custom_rows = [
        { 'file' => 'C:/Windows/system32/file.rb', 'percentage' => 100.0, 'covered' => 10, 'total' => 10, 'stale' => false }
      ]

      # This should trigger the ArgumentError rescue in filter_rows_by_globs
      # When the path cannot be made relative (different path types), it falls back to using the absolute path
      output = model.format_table(custom_rows, tracked_globs: ['C:/Windows/**/*.rb'])

      # The file should be included because the absolute path fallback matches the glob
      expect(output).to include('C:/Windows/system32/file.rb')
    end
  end

  describe 'resolve method error handling' do
    it 'raises FileError when coverage_lines is nil after lookup' do
      # Stub lookup_lines to return nil without raising
      allow(SimpleCovMcp::CovUtil).to receive(:lookup_lines).and_return(nil)

      expect do
        model.summary_for('lib/nonexistent.rb')
      end.to raise_error(SimpleCovMcp::FileError, /No coverage data found for file/)
    end

    it 'converts Errno::ENOENT to FileNotFoundError during resolve' do
      # We need to trigger Errno::ENOENT inside the resolve method
      # Stub the checker's check_file! method to raise Errno::ENOENT
      allow_any_instance_of(SimpleCovMcp::StalenessChecker).to receive(:check_file!).and_raise(Errno::ENOENT, 'No such file or directory')

      # Create a model with staleness checking enabled to trigger the check_file! call
      stale_model = described_class.new(root: root, staleness: 'error')

      expect do
        stale_model.summary_for('lib/foo.rb')
      end.to raise_error(SimpleCovMcp::FileNotFoundError, /File not found/)
    end
  end

  describe 'resultset directory handling' do
    it 'accepts a directory containing .resultset.json' do
      model = described_class.new(root: root, resultset: 'coverage')
      data = model.summary_for('lib/foo.rb')
      expect(data['summary']['total']).to eq(3)
      expect(data['summary']['covered']).to eq(2)
    end

  end

  describe 'branch-only coverage resultsets' do
    let(:branch_root) { (FIXTURES_DIR / 'branch_only_project').to_s }
    let(:branch_model) { described_class.new(root: branch_root) }

    it 'computes summaries by synthesizing branch data' do
      data = branch_model.summary_for('lib/branch_only.rb')

      expect(data['summary']['total']).to eq(5)
      expect(data['summary']['covered']).to eq(3)
      expect(data['summary']['pct']).to be_within(0.01).of(60.0)
    end

    it 'returns detailed data using branch-derived hits' do
      data = branch_model.detailed_for('lib/branch_only.rb')

      expect(data['lines']).to eq([
        { 'line' => 6,  'hits' => 3, 'covered' => true },
        { 'line' => 7,  'hits' => 0, 'covered' => false },
        { 'line' => 13, 'hits' => 0, 'covered' => false },
        { 'line' => 14, 'hits' => 2, 'covered' => true },
        { 'line' => 16, 'hits' => 2, 'covered' => true }
      ])
    end

    it 'identifies uncovered lines based on branch hits' do
      data = branch_model.uncovered_for('lib/branch_only.rb')

      expect(data['uncovered']).to eq([7, 13])
    end

    it 'includes branch-only files in all_files results' do
      files = branch_model.all_files(sort_order: :ascending)
      branch_path = File.expand_path('lib/branch_only.rb', branch_root)
      another_path = File.expand_path('lib/another.rb', branch_root)

      expect(files.map { |f| f['file'] }).to contain_exactly(branch_path, another_path)

      branch_entry = files.find { |f| f['file'] == branch_path }
      another_entry = files.find { |f| f['file'] == another_path }

      expect(branch_entry['total']).to eq(5)
      expect(branch_entry['covered']).to eq(3)
      expect(another_entry['total']).to eq(1)
      expect(another_entry['covered']).to eq(0)
    end
  end

    describe 'multiple suites in resultset' do
    let(:resultset_path) { '/tmp/multi_suite_resultset.json' }

    before do
      allow(SimpleCovMcp::CovUtil).to receive(:find_resultset).and_wrap_original do |original, search_root, resultset: nil|
        if File.absolute_path(search_root) == File.absolute_path(root) && (resultset.nil? || resultset.to_s.empty?)
          resultset_path
        else
          original.call(search_root, resultset: resultset)
        end
      end
      allow(File).to receive(:read).and_call_original
    end

    it 'merges coverage data from multiple suites while keeping latest timestamp' do
      suite_a_cov = {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil, 2] }
      }
      suite_b_cov = {
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [0, 1, 1] }
      }

      resultset = {
        'RSpec' => { 'timestamp' => 100, 'coverage' => suite_a_cov },
        'Cucumber' => { 'timestamp' => 200, 'coverage' => suite_b_cov }
      }

      allow(File).to receive(:read).with(resultset_path).and_return(resultset.to_json)

      model = described_class.new(root: root)
      files = model.all_files(sort_order: :ascending)

      expect(files.map { |f| File.basename(f['file']) }).to include('foo.rb', 'bar.rb')

      timestamp = model.instance_variable_get(:@cov_timestamp)
      expect(timestamp).to eq(200)
    end

    it 'combines coverage arrays when the same file appears in multiple suites' do
      shared_file = File.join(root, 'lib', 'foo.rb')
      suite_a_cov = {
        shared_file => { 'lines' => [1, 0, nil, 0] }
      }
      suite_b_cov = {
        shared_file => { 'lines' => [0, 3, nil, 1] }
      }

      resultset = {
        'RSpec' => { 'timestamp' => 100, 'coverage' => suite_a_cov },
        'Cucumber' => { 'timestamp' => 150, 'coverage' => suite_b_cov }
      }

      allow(File).to receive(:read).with(resultset_path).and_return(resultset.to_json)

      model = described_class.new(root: root)
      detailed = model.detailed_for('lib/foo.rb')
      hits_by_line = detailed['lines'].each_with_object({}) { |row, acc| acc[row['line']] = row['hits'] }

      expect(hits_by_line[1]).to eq(1)
      expect(hits_by_line[2]).to eq(3)
      expect(hits_by_line[4]).to eq(1)
    end
  end

  describe 'format_table' do
    it 'returns a formatted table string with all files coverage data' do
      output = model.format_table

      # Should contain table structure
      expect(output).to include('┌', '┬', '┐', '│', '├', '┼', '┤', '└', '┴', '┘')

      # Should contain headers
      expect(output).to include('File', '%', 'Covered', 'Total', 'Stale')

      # Should contain file data
      expect(output).to include('lib/foo.rb', 'lib/bar.rb')

      # Should contain summary
      expect(output).to include('Files: total', ', ok ', ', stale ')
    end

    it 'returns "No coverage data found" when rows is empty' do
      rows = []
      output = model.format_table(rows)
      expect(output).to eq('No coverage data found')
    end

    it 'accepts custom rows parameter' do
      custom_rows = [
        { 'file' => '/path/to/file1.rb', 'percentage' => 100.0, 'covered' => 10, 'total' => 10, 'stale' => false },
        { 'file' => '/path/to/file2.rb', 'percentage' => 50.0, 'covered' => 5, 'total' => 10, 'stale' => 'M' },
        { 'file' => '/path/to/file3.rb', 'percentage' => 75.0, 'covered' => 15, 'total' => 20, 'stale' => 'T' }
      ]

      output = model.format_table(custom_rows)

      expect(output).to include('file1.rb')
      expect(output).to include('file2.rb')
      expect(output).to include('file3.rb')
      expect(output).to include('100.00')
      expect(output).to include('50.00')
      expect(output).to include('75.00')
      expect(output).to include('M')
      expect(output).to include('T')
      expect(output).not_to include('!')
      expect(output).to include('Staleness: M = Missing file, T = Timestamp (source newer), L = Line count mismatch')
    end

    it 'accepts sort_order parameter' do
      # Test that sort_order parameter is passed through correctly
      rows_desc = model.all_files(sort_order: :descending)
      output_asc = model.format_table(sort_order: :ascending)
      output_desc = model.format_table(sort_order: :descending)

      # Both should be valid table outputs
      expect(output_asc).to include('┌')
      expect(output_desc).to include('┌')
      expect(output_asc).to include('Files: total')
      expect(output_desc).to include('Files: total')
    end

    it 'sorts table output correctly when provided with custom rows' do
      # Get all files data to use as custom rows
      all_files_data = model.all_files

      # Test ascending sort with custom rows
      output_asc = model.format_table(all_files_data, sort_order: :ascending)
      lines_asc = output_asc.split("\n")
      bar_line_asc = lines_asc.find { |line| line.include?('bar.rb') }
      foo_line_asc = lines_asc.find { |line| line.include?('foo.rb') }

      # In ascending order, bar.rb (33.33%) should come before foo.rb (66.67%)
      expect(lines_asc.index(bar_line_asc)).to be < lines_asc.index(foo_line_asc)

      # Test descending sort with custom rows
      output_desc = model.format_table(all_files_data, sort_order: :descending)
      lines_desc = output_desc.split("\n")
      bar_line_desc = lines_desc.find { |line| line.include?('bar.rb') }
      foo_line_desc = lines_desc.find { |line| line.include?('foo.rb') }

      # In descending order, foo.rb (66.67%) should come before bar.rb (33.33%)
      expect(lines_desc.index(foo_line_desc)).to be < lines_desc.index(bar_line_desc)
    end
  end
end
