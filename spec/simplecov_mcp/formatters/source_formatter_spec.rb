# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Formatters::SourceFormatter do
  subject(:formatter) { described_class.new(color_enabled: color_enabled) }

  let(:color_enabled) { false }
  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:path) { 'lib/foo.rb' }
  let(:abs_path) { File.expand_path(path) }
  let(:source_content) do
    <<~RUBY
      class Foo
        def bar
          puts 'bar'
        end
      end
    RUBY
  end
  let(:coverage_lines) { [1, 1, 0, nil, nil] } # Line 3 is uncovered

  before do
    allow(model).to receive(:raw_for).with(path).and_return(
      'file' => abs_path,
      'lines' => coverage_lines
    )
    allow(File).to receive(:file?).with(abs_path).and_return(true)
    allow(File).to receive(:readlines).with(abs_path, chomp: true)
      .and_return(source_content.lines(chomp: true))
  end

  describe '#format_source_for' do
    context 'when source is available' do
      it 'renders formatted source lines with line numbers and markers' do
        # Full mode should print every line with coverage markers and numbering.
        result = formatter.format_source_for(model, path, mode: :full)

        expect(result.lines(chomp: true)).to eq(
          [
            '  Line     | Source',
            '------  ---+-------------------------------------------------------------',
            '     1   ✓ | class Foo',
            '     2   ✓ |   def bar',
            "     3   · |     puts 'bar'",
            '     4     |   end',
            '     5     | end'
          ]
        )
      end

      it 'marks covered lines with a checkmark' do
        # Two covered lines should each get a ✓ in the rendered output.
        result = formatter.format_source_for(model, path, mode: :full)
        # covered: true -> '✓', false -> '·', nil -> ' '
        expect(result.count('✓')).to eq(2)
        expect(result.lines[2]).to match(/\b1\s+✓ \| class Foo/)
        expect(result.lines[3]).to match(/\b2\s+✓ \|   def bar/)
      end

      it 'marks uncovered lines with a dot' do
        # The single uncovered line should be marked with a dot.
        result = formatter.format_source_for(model, path, mode: :full)
        expect(result.count('·')).to eq(1)
        expect(result.lines[4]).to match(/\b3\s+· \|     puts 'bar'/)
      end

      it 'returns only header when mode is nil (default)' do
        # Default mode skips body rows but still emits the header scaffold.
        result = formatter.format_source_for(model, path)
        # Example header-only output:
        #   Line     | Source
        # ------  ---+-------------------------------------------------------------
        expect(result).not_to include('class Foo')
        expect(result).to include('Line', 'Source')
      end
    end

    context 'when source file is not found' do
      it 'returns fallback message' do
        # Simulate missing file; formatter should not raise and should return a placeholder.
        allow(File).to receive(:file?).with(abs_path).and_return(false)
        expect(formatter.format_source_for(model, path)).to eq('[source not available]')
      end
    end

    context 'when raw coverage data is missing' do
      it 'returns fallback message' do
        # No coverage entry for the path should also trigger the placeholder.
        allow(model).to receive(:raw_for).with(path).and_return(nil)
        expect(formatter.format_source_for(model, path)).to eq('[source not available]')
      end
    end

    context 'when an error occurs during formatting' do
      it 'returns fallback message instead of crashing' do
        # Create a pathological coverage array with an object that raises on to_i
        bad_object = Object.new
        def bad_object.to_i = raise(StandardError, 'Bad data')
        def bad_object.nil? = false

        bad_coverage = [1, 1, bad_object, nil, nil]

        allow(model).to receive(:raw_for).with(path)
          .and_return('file' => abs_path, 'lines' => bad_coverage)

        result = formatter.format_source_for(model, path, mode: :full)
        expect(result).to eq('[source not available]')
      end
    end

    context 'with color enabled' do
      let(:color_enabled) { true }

      it 'includes ANSI color codes' do
        # Markers should be wrapped with green/red ANSI sequences when colors are on.
        # Example colored line: "     1  \e[32m✓\e[0m | class Foo"
        result = formatter.format_source_for(model, path, mode: :full)
        expect(result).to include("\e[32m", "\e[31m") # green for checkmark, red for dot
        expect(result.lines[2]).to include("\e[32m✓\e[0m") # line 1 checkmark is green
        expect(result.lines[3]).to include("\e[32m✓\e[0m") # line 2 checkmark is green
        expect(result.lines[4]).to include("\e[31m·\e[0m") # line 3 dot is red
      end
    end
  end

  describe '#build_source_payload' do
    it 'returns row data when source is available' do
      # Payload should mirror the row hashes used by CLI formatting.
      result = formatter.build_source_payload(model, path, mode: :full)
      expect(result).to be_a(Array)
      expect(result.size).to eq(5)
      expect(result.first).to include('code' => 'class Foo', 'line' => 1)
    end

    it 'returns nil when raw coverage is missing' do
      # Without coverage data, there is no payload to build.
      allow(model).to receive(:raw_for).with(path).and_return(nil)
      expect(formatter.build_source_payload(model, path)).to be_nil
    end

    it 'returns nil when source file is missing' do
      # Missing source file should also produce a nil payload.
      allow(File).to receive(:file?).with(abs_path).and_return(false)
      expect(formatter.build_source_payload(model, path)).to be_nil
    end
  end

  describe '#build_source_rows' do
    it 'handles negative context count by defaulting to 0' do
      # Negative context should be clamped to zero, so only uncovered lines appear.
      rows = formatter.build_source_rows(
        source_content.lines(chomp: true),
        coverage_lines,
        mode: :uncovered,
        context: -1
      )
      # Only the uncovered line (index 2, line 3) should be included if context is 0
      expect(rows.size).to eq(1)
      expect(rows.first['line']).to eq(3)
    end

    it 'handles default context (2 lines)' do
      # With the default context of 2, uncovered lines pull in surrounding rows.
      rows = formatter.build_source_rows(
        source_content.lines(chomp: true),
        coverage_lines,
        mode: :uncovered,
        context: 2
      )
      # Uncovered is line 3. Context 2 means lines 1..5 (indexes 0..4).
      # Total line count is 5, so all lines should be included.
      expect(rows.size).to eq(5)
    end

    it 'handles bad context input (non-numeric)' do
      # Non-numeric context coerces to 0 via to_i, so only the miss is included.
      rows = formatter.build_source_rows(
        source_content.lines(chomp: true),
        coverage_lines,
        mode: :uncovered,
        context: 'bad'
      )
      # "bad".to_i is 0 so context should be 0.
      # Uncovered is line 3.
      expect(rows.size).to eq(1)
      expect(rows.first['line']).to eq(3)
    end

    it 'handles context input that raises error on to_i conversion' do
      # Create an object where to_i raises an error
      bad_context = Object.new
      def bad_context.to_i = raise(StandardError, 'Cannot convert')

      # Falling back to default context should still include surrounding lines.
      rows = formatter.build_source_rows(
        source_content.lines(chomp: true),
        coverage_lines,
        mode: :uncovered,
        context: bad_context
      )
      # Should fall back to default context of 2
      # Uncovered is line 3. Context 2 means lines 1..5 (indexes 0..4).
      # Total lines is 5. So all lines should be included.
      expect(rows.size).to eq(5)
    end

    it 'handles nil coverage lines defensively' do
      # Nil coverage array should not raise; hits/covered become nil.
      # This covers the "coverage data missing entirely" path; in real coverage we'd see 1/0 hits.
      # Expected rows when coverage is nil:
      # [
      #   { 'line' => 1, 'code' => 'class Foo', 'hits' => nil, 'covered' => nil },
      #   { 'line' => 2, 'code' => '  def bar', 'hits' => nil, 'covered' => nil },
      #   { 'line' => 3, 'code' => "    puts 'bar'", 'hits' => nil, 'covered' => nil },
      #   { 'line' => 4, 'code' => '  end', 'hits' => nil, 'covered' => nil },
      #   { 'line' => 5, 'code' => 'end', 'hits' => nil, 'covered' => nil }
      # ]
      # And the formatted output (markers blank because coverage is missing) would be:
      #   Line     | Source
      # ------  ---+-------------------------------------------------------------
      #      1     | class Foo
      #      2     |   def bar
      #      3     |     puts 'bar'
      #      4     |   end
      #      5     | end
      rows = formatter.build_source_rows(
        source_content.lines(chomp: true),
        nil,
        mode: :full,
        context: 2
      )
      expect(rows.size).to eq(5)
      expect(rows.first['hits']).to be_nil
    end
  end

  describe '#format_detailed_rows' do
    it 'formats rows into a table' do
      # Detailed mode should align numeric columns and boolean covered flags.
      rows = [
        { 'line' => 1, 'hits' => 5, 'covered' => true },
        { 'line' => 2, 'hits' => 0, 'covered' => false }
      ]
      # Expected table:
      #   Line    Hits  Covered
      #   -----   ----  -------
      #       1      5      yes
      #       2      0       no
      result = formatter.format_detailed_rows(rows)
      expect(result).to include('Line', 'Hits', 'Covered', '5', 'yes', 'no')
    end
  end

  describe 'private #fetch_raw error handling' do
    it 'returns nil if model raises error' do
      # fetch_raw should swallow model errors and return nil instead of propagating.
      allow(model).to receive(:raw_for).and_raise(StandardError)
      expect(formatter.send(:fetch_raw, model, path)).to be_nil
    end
  end
end
