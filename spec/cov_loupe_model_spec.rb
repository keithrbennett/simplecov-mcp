# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageModel do
  subject(:model) { described_class.new(root: root) }

  let(:root) { (FIXTURES_DIR / 'project1').to_s }


  describe 'initialization error handling' do
    it 'raises FileError when File.read raises Errno::ENOENT directly' do
      # Stub find_resultset to return a path, but File.read to raise ENOENT
      allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:find_resultset)
        .and_return('/some/path/.resultset.json')
      allow(File).to receive(:read).with('/some/path/.resultset.json')
        .and_raise(Errno::ENOENT, 'No such file')

      expect do
        described_class.new(root: root, resultset: '/some/path/.resultset.json')
      end.to raise_error(CovLoupe::FileError, /Coverage data not found/)
    end

    it 'raises ResultsetNotFoundError when resultset file does not exist' do
      expect do
        described_class.new(root: root, resultset: '/nonexistent/path/.resultset.json')
      end.to raise_error(CovLoupe::ResultsetNotFoundError, /Specified resultset not found/)
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
    it 'computes covered/total/percentage' do
      data = model.summary_for('lib/foo.rb')
      expect(data['summary']['total']).to eq(3)
      expect(data['summary']['covered']).to eq(2)
      expect(data['summary']['percentage']).to be_within(0.01).of(66.67)
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
      checker = instance_double(CovLoupe::StalenessChecker, off?: false)
      allow(CovLoupe::StalenessChecker).to receive(:new).and_return(checker)
      allow(checker).to receive(:stale_for_file?) do |file_abs, _|
        if file_abs == File.expand_path('lib/foo.rb', root)
          'T'
        else
          false
        end
      end

      expect(model.staleness_for('lib/foo.rb')).to eq('T')
      expect(model.staleness_for('lib/bar.rb')).to be(false)
    end

    it 'returns false when an exception occurs during staleness check' do
      # Stub the checker to raise an error
      checker = instance_double(CovLoupe::StalenessChecker, off?: false)
      allow(CovLoupe::StalenessChecker).to receive(:new).and_return(checker)
      allow(checker).to receive(:stale_for_file?)
        .and_raise(StandardError, 'Something went wrong')

      # The rescue clause should catch the error and return false
      expect(model.staleness_for('lib/foo.rb')).to be(false)
    end

    it 'returns false when coverage data is not found for the file' do
      # Try to get staleness for a file that doesn't exist in coverage
      expect(model.staleness_for('lib/nonexistent.rb')).to be(false)
    end
  end

  describe 'list' do
    it 'returns a hash with files, skipped_files, missing_tracked_files,
      newer_files, and deleted_files keys' do
      result = model.list
      expect(result).to be_a(Hash)

      expected_keys = %w[files skipped_files missing_tracked_files newer_files deleted_files]
      expect(result.keys).to match_array(expected_keys)

      expected_keys.each do |key|
        expect(result[key]).to be_a(Array), "Expected result['#{key}'] to be an Array"
      end
    end

    it 'sorts descending (default) by percentage then by file path' do
      files = model.list['files']
      # lib/foo.rb has 66.67%, lib/bar.rb has 33.33%
      expect(files.first['file']).to eq(File.expand_path('lib/foo.rb', root))
      expect(files.first['percentage']).to be_within(0.01).of(66.67)
      expect(files.last['file']).to eq(File.expand_path('lib/bar.rb', root))
    end

    it 'sorts ascending by percentage then by file path' do
      files = model.list(sort_order: :ascending)['files']
      expect(files.first['file']).to eq(File.expand_path('lib/bar.rb', root))
      expect(files.first['percentage']).to be_within(0.01).of(33.33)
      expect(files.last['file']).to eq(File.expand_path('lib/foo.rb', root))
    end

    it 'filters rows when tracked_globs are provided' do
      files = model.list(tracked_globs: ['lib/foo.rb'])['files']
      expect(files.length).to eq(1)
      expect(files.first['file']).to eq(File.expand_path('lib/foo.rb', root))
    end

    it 'combines results from multiple tracked_globs patterns' do
      abs_bar = File.expand_path('lib/bar.rb', root)
      files = model.list(tracked_globs: ['lib/foo.rb', abs_bar])['files']
      expect(files.map { |f| f['file'] }).to contain_exactly(
        File.expand_path('lib/foo.rb', root),
        abs_bar
      )
    end

    it 'handles absolute patterns correctly' do
      abs_foo = File.expand_path('lib/foo.rb', root)
      files = model.list(tracked_globs: [abs_foo])['files']
      expect(files.map { |f| f['file'] }).to contain_exactly(abs_foo)
    end

    it 'records skipped rows when coverage data errors occur' do
      abs_foo = File.expand_path('lib/foo.rb', root)

      allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:lookup_lines).and_wrap_original do
      |method, coverage_map, absolute|
        if absolute == abs_foo
          raise CovLoupe::CoverageDataError, 'corrupt data'
        end

        method.call(coverage_map, absolute)
      end

      result = model.list

      expect(result['files'].map { |row| row['file'] }).not_to include(abs_foo)
      expect(result['skipped_files']).to contain_exactly(
        hash_including(
          'file' => abs_foo,
          'error' => 'corrupt data',
          'error_class' => 'CovLoupe::CoverageDataError'
        )
      )
    end

    it 'reports newer_files when a file is modified after coverage was generated' do
      newer_file_name = File.expand_path('lib/foo.rb', root) # Use absolute path for clarity in stub

      # Stub the entire staleness checker to return a predefined set of results
      stub_checker = instance_double(CovLoupe::StalenessChecker, off?: false)
      allow(CovLoupe::StalenessChecker).to receive(:new).and_return(stub_checker) # Fix: Stub the constructor
      allow(stub_checker).to receive_messages(check_project!: { newer_files: [newer_file_name], # Only foo.rb is newer
                                                                missing_files: [],
                                                                deleted_files: [] }, stale_for_file?: false) # Added stub for stale_for_file?

      result = model.list

      expect(result['newer_files']).to contain_exactly(newer_file_name)
    end

    it 'reports deleted_files when a file in coverage no longer exists on disk' do
      deleted_file_name = 'lib/bar.rb'
      deleted_file_abs = File.expand_path(deleted_file_name, root)

      # Stub File.file? for lib/bar.rb to return false (deleted)
      allow(File).to receive(:file?).and_call_original
      allow(File).to receive(:file?).with(deleted_file_abs).and_return(false)

      result = model.list

      expect(result['deleted_files']).to include(deleted_file_name)
      expect(result['deleted_files'].length).to eq(1)
    end
  end

  describe '#project_totals' do
    it 'aggregates coverage totals across all files' do
      totals = model.project_totals

      expect(totals['lines']).to include('total' => 6, 'covered' => 3, 'uncovered' => 3)
      expect(totals['percentage']).to be_within(0.01).of(50.0)
      expect(totals['files']).to include('total' => 2)
      expect(totals['files']['ok'] + totals['files']['stale']).to eq(totals['files']['total'])
    end

    it 'respects tracked_globs filtering' do
      totals = model.project_totals(tracked_globs: ['lib/foo.rb'])

      expect(totals['lines']).to include('total' => 3, 'covered' => 2, 'uncovered' => 1)
      expect(totals['files']).to include('total' => 1)
    end
  end

  describe 'resolve method error handling' do
    it 'raises FileError when coverage_lines is nil after lookup' do
      # Stub lookup_lines to return nil without raising
      allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:lookup_lines).and_return(nil)

      expect do
        model.summary_for('lib/nonexistent.rb')
      end.to raise_error(CovLoupe::FileError, /No coverage data found for file/)
    end

    it 'converts Errno::ENOENT to FileNotFoundError during resolve' do
      # We need to trigger Errno::ENOENT inside the resolve method
      # Stub the checker's check_file! method to raise Errno::ENOENT
      checker = instance_double(CovLoupe::StalenessChecker, off?: false)
      allow(CovLoupe::StalenessChecker).to receive(:new).and_return(checker)
      allow(checker).to receive(:check_file!)
        .and_raise(Errno::ENOENT, 'No such file or directory')

      # Create a model with staleness checking enabled to trigger the check_file! call
      stale_model = described_class.new(root: root, raise_on_stale: true)

      expect do
        stale_model.summary_for('lib/foo.rb')
      end.to raise_error(CovLoupe::FileNotFoundError, /File not found/)
    end

    it 'raises FileError when lookup_lines raises RuntimeError' do
      allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:lookup_lines)
        .and_raise(RuntimeError, 'Could not find coverage data')

      expect do
        model.summary_for('lib/some_file.rb')
      end.to raise_error(CovLoupe::FileError, /No coverage data found for file/)
    end
  end

  describe 'resultset directory handling' do
    it 'accepts a directory containing .resultset.json' do
      model = described_class.new(
        root: root,
        resultset: File.dirname(FIXTURE_PROJECT1_RESULTSET_PATH)
      )
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
      expect(data['summary']['percentage']).to be_within(0.01).of(60.0)
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

    it 'includes branch-only files in list results' do
      files = branch_model.list(sort_order: :ascending)['files']
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
    let(:suite_a_cov) do
      {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil, 2] }
      }
    end
    let(:suite_b_cov) do
      {
        File.join(root, 'lib', 'bar.rb') => { 'lines' => [0, 1, 1] }
      }
    end
    let(:resultset) do
      {
        'RSpec' => { 'timestamp' => 100, 'coverage' => suite_a_cov },
        'Cucumber' => { 'timestamp' => 200, 'coverage' => suite_b_cov }
      }
    end

    let(:shared_file) { File.join(root, 'lib', 'foo.rb') }
    let(:suite_a_cov_combined) do
      {
        shared_file => { 'lines' => [1, 0, nil, 0] }
      }
    end
    let(:suite_b_cov_combined) do
      {
        shared_file => { 'lines' => [0, 3, nil, 1] }
      }
    end
    let(:resultset_combined) do
      {
        'RSpec' => { 'timestamp' => 100, 'coverage' => suite_a_cov_combined },
        'Cucumber' => { 'timestamp' => 150, 'coverage' => suite_b_cov_combined }
      }
    end

    before do
      allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:find_resultset).and_wrap_original do
        |original, search_root, resultset: nil|
        root_match = File.absolute_path(search_root) == File.absolute_path(root)
        resultset_empty = resultset.nil? || resultset.to_s.empty?
        if root_match && resultset_empty
          resultset_path
        else
          original.call(search_root, resultset: resultset)
        end
      end
    end

    it 'merges coverage data from multiple suites while keeping latest timestamp' do
      allow(File).to receive(:read).with(resultset_path).and_return(JSON.generate(resultset))

      model = described_class.new(root: root)
      files = model.list(sort_order: :ascending)['files']

      expect(files.map { |f| File.basename(f['file']) }).to include('foo.rb', 'bar.rb')

      timestamp = model.instance_variable_get(:@cov_timestamp)
      expect(timestamp).to eq(200)
    end

    it 'combines coverage arrays when the same file appears in multiple suites' do
      allow(File).to receive(:read).with(resultset_path)
        .and_return(JSON.generate(resultset_combined))

      model = described_class.new(root: root)
      detailed = model.detailed_for('lib/foo.rb')
      hits_by_line = detailed['lines'].each_with_object({}) do |row, acc|
        acc[row['line']] = row['hits']
      end

      expect(hits_by_line[1]).to eq(1)
      expect(hits_by_line[2]).to eq(3)
      expect(hits_by_line[4]).to eq(1)
    end
  end

  describe 'format_table' do
    # Integration tests - detailed formatting is tested in coverage_table_formatter_spec.rb
    # These tests verify that CoverageModel correctly prepares rows and delegates to the formatter

    it 'returns a formatted table string with all files coverage data' do
      output = model.format_table

      # Should be a non-empty string (formatting details tested in CoverageTableFormatter)
      expect(output).to be_a(String)
      expect(output).not_to be_empty

      # Should contain file data from the model
      expect(output).to include('lib/foo.rb', 'lib/bar.rb')
    end

    it 'delegates to CoverageTableFormatter for formatting' do
      expect(CovLoupe::CoverageTableFormatter).to receive(:format).and_call_original

      model.format_table
    end

    it 'returns "No coverage data found" when rows is empty' do
      rows = []
      output = model.format_table(rows)
      expect(output).to eq('No coverage data found')
    end

    it 'accepts custom rows parameter' do
      custom_rows = [
        {
          'file' => '/path/to/file1.rb',
          'percentage' => 100.0,
          'covered' => 10,
          'total' => 10,
          'stale' => false
        }
      ]

      output = model.format_table(custom_rows)

      expect(output).to include('file1.rb')
    end

    it 'sorts rows by sort_order parameter before formatting' do
      # Get all files data to use as custom rows
      list_data = model.list['files']

      # Test ascending sort with custom rows
      output_asc = model.format_table(list_data, sort_order: :ascending)
      lines_asc = output_asc.split("\n")
      bar_line_asc = lines_asc.find { |line| line.include?('bar.rb') }
      foo_line_asc = lines_asc.find { |line| line.include?('foo.rb') }

      # In ascending order, bar.rb (33.33%) should come before foo.rb (66.67%)
      expect(lines_asc.index(bar_line_asc)).to be < lines_asc.index(foo_line_asc)

      # Test descending sort with custom rows
      output_desc = model.format_table(list_data, sort_order: :descending)
      lines_desc = output_desc.split("\n")
      bar_line_desc = lines_desc.find { |line| line.include?('bar.rb') }
      foo_line_desc = lines_desc.find { |line| line.include?('foo.rb') }

      # In descending order, foo.rb (66.67%) should come before bar.rb (33.33%)
      expect(lines_desc.index(foo_line_desc)).to be < lines_desc.index(bar_line_desc)
    end
  end

  describe 'default tracked_globs' do
    let(:tracked_globs) { ['lib/foo.rb'] }

    it 'uses constructor tracked_globs when none are passed to list' do
      model = described_class.new(root: root, tracked_globs: tracked_globs)
      allow(model).to receive(:filter_rows_by_globs).and_call_original
      stub_checker = instance_double(CovLoupe::StalenessChecker,
        stale_for_file?: false, off?: true)
      allow(stub_checker).to receive(:check_project!).and_return(
        newer_files: [], missing_files: [], deleted_files: []
      )
      allow(model).to receive(:build_staleness_checker).and_return(stub_checker)

      model.list # Call list to trigger filter_rows_by_globs
      expect(model).to have_received(:filter_rows_by_globs).with(anything, tracked_globs)
    end

    it 'uses constructor tracked_globs when none are passed to project_totals' do
      model = described_class.new(root: root, tracked_globs: tracked_globs)
      expect(model).to receive(:list).with(sort_order: :ascending,
        raise_on_stale: false, tracked_globs: tracked_globs).and_call_original

      model.project_totals
    end

    it 'uses constructor tracked_globs when none are passed to format_table' do
      model = described_class.new(root: root, tracked_globs: tracked_globs)
      allow(model).to receive(:prepare_rows).and_return([])
      model.format_table
      expect(model).to have_received(:prepare_rows).with(nil, sort_order: :descending,
        raise_on_stale: false, tracked_globs: tracked_globs)
    end
  end
end
