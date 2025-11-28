# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Formatters::SourceFormatter do
  let(:formatter) { described_class.new(color_enabled: true) }
  let(:no_color_formatter) { described_class.new(color_enabled: false) }

  describe '#format_source_for error handling' do
    it 'returns "[source not available]" when formatting raises an error' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(model).to receive(:raw_for).and_return({
        'file' => '/some/file.rb',
        'lines' => [1, 0, nil]
      })

      # Stub File methods to get past the initial checks
      allow(File).to receive_messages(file?: true, readlines: ['line 1', 'line 2'])

      # Stub build_source_rows to raise inside the begin/rescue block
      allow(formatter).to receive(:build_source_rows).and_raise(StandardError, 'Unexpected error')

      result = formatter.format_source_for(model, 'some/file.rb', mode: :full)
      expect(result).to eq('[source not available]')
    end
  end

  describe '#fetch_raw error handling' do
    it 'returns nil when model.raw_for raises an error' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(model).to receive(:raw_for).and_raise(StandardError, 'Model error')

      result = formatter.format_source_for(model, 'bad/path.rb')
      expect(result).to eq('[source not available]')
    end
  end

  describe '#colorize' do
    it 'applies ANSI color codes when color is enabled' do
      # Use format_source_rows which internally calls colorize via the marker lambda
      rows = [{ 'line' => 1, 'code' => 'puts "hi"', 'hits' => 1, 'covered' => true }]
      result = formatter.format_source_rows(rows)

      # Should contain ANSI escape codes for green (32)
      expect(result).to include("\e[32m")
      expect(result).to include("\e[0m")
    end

    it 'does not apply color codes when color is disabled' do
      rows = [{ 'line' => 1, 'code' => 'puts "hi"', 'hits' => 1, 'covered' => true }]
      result = no_color_formatter.format_source_rows(rows)

      expect(result).not_to include("\e[")
    end

    it 'uses red for uncovered lines' do
      rows = [{ 'line' => 1, 'code' => 'puts "hi"', 'hits' => 0, 'covered' => false }]
      result = formatter.format_source_rows(rows)

      # Should contain ANSI escape codes for red (31)
      expect(result).to include("\e[31m")
    end

    it 'uses dim for non-executable lines' do
      rows = [{ 'line' => 1, 'code' => '# comment', 'hits' => nil, 'covered' => nil }]
      result = formatter.format_source_rows(rows)

      # Should contain ANSI escape codes for dim (2)
      expect(result).to include("\e[2m")
    end
  end
end
