# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageModel do
  let(:root)  { (FIXTURES_DIR / 'project1').to_s }
  subject(:model) { described_class.new(root: root) }

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
  end

  describe 'resultset directory handling' do
    it 'accepts a directory containing .resultset.json' do
      model = described_class.new(root: root, resultset: 'coverage')
      data = model.summary_for('lib/foo.rb')
      expect(data['summary']['total']).to eq(3)
      expect(data['summary']['covered']).to eq(2)
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
        { 'file' => '/path/to/file2.rb', 'percentage' => 50.0, 'covered' => 5, 'total' => 10, 'stale' => true }
      ]

      output = model.format_table(custom_rows)

      expect(output).to include('file1.rb')
      expect(output).to include('file2.rb')
      expect(output).to include('100.00')
      expect(output).to include('50.00')
      expect(output).to include('!')
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
