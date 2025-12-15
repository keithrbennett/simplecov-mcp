# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::TableFormatter do
  describe '.format' do
    it 'returns a friendly message when no rows are provided' do
      result = described_class.format(headers: %w[Column], rows: [])
      expect(result).to eq('No data to display')
    end

    it 'aligns each column according to the provided alignments' do
      headers = %w[Left Right Center]
      rows = [%w[x 1 ok]]

      output = described_class.format(
        headers: headers,
        rows: rows,
        alignments: [:left, :right, :center]
      )

      body_line = output.lines[3] # first data row after borders/header
      # Split by vertical bars to inspect each rendered cell without the borders.
      cells = body_line.split('│')[1..]
      cells.pop # drop trailing empty string after final separator

      trimmed = cells.map(&:strip)
      expect(trimmed).to eq(%w[x 1 ok])
      expect(cells[0][1..-2]).to eq('x   ')   # left aligned -> trailing spaces
      expect(cells[1][1..-2]).to eq('    1')  # right aligned -> leading spaces
      expect(cells[2][1..-2]).to eq('  ok  ') # centered -> spaces on both sides
    end
  end

  describe '.format_vertical' do
    it 'renders key/value pairs as a two-column table' do
      result = described_class.format_vertical('foo' => 1, 'bar' => 2)
      expect(result).to include('Key', 'Value', 'foo', 'bar', '1', '2')
    end
  end

  describe '.align_cell' do
    it 'right-aligns content' do
      expect(described_class.send(:align_cell, '7', 4, :right)).to eq('   7')
    end

    it 'centers content' do
      expect(described_class.send(:align_cell, 'mid', 5, :center)).to eq(' mid ')
    end

    it 'left-aligns by default' do
      expect(described_class.send(:align_cell, 'abc', 5, :unknown)).to eq('abc  ')
    end
  end
end
