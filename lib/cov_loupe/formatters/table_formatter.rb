# frozen_string_literal: true

module CovLoupe
  # General-purpose table formatter with box-drawing characters
  # Used by commands to create consistent formatted output
  class TableFormatter
    # Format data as a table with box-drawing characters
    # @param headers [Array<String>] Column headers
    # @param rows [Array<Array>] Data rows (each row is an array of cell values)
    # @param alignments [Array<Symbol>] Column alignments (:left, :right, :center)
    # @return [String] Formatted table
    def self.format(headers:, rows:, alignments: nil)
      return 'No data to display' if rows.empty?

      alignments ||= [:left] * headers.size
      all_rows = [headers] + rows.map { |row| row.map(&:to_s) }

      # Calculate column widths
      widths = headers.size.times.map do |col|
        all_rows.map { |row| row[col].to_s.length }.max
      end

      lines = []
      lines << border_line(widths, '┌', '┬', '┐')
      lines << data_row(headers, widths, alignments)
      lines << border_line(widths, '├', '┼', '┤')
      rows.each { |row| lines << data_row(row, widths, alignments) }
      lines << border_line(widths, '└', '┴', '┘')

      lines.join("\n")
    end

    # Format a single key-value table (vertical layout)
    # @param data [Hash] Key-value pairs
    # @return [String] Formatted table
    def self.format_vertical(data)
      rows = data.map { |k, v| [k.to_s, v.to_s] }
      format(headers: ['Key', 'Value'], rows: rows, alignments: [:left, :left])
    end

    private_class_method def self.border_line(widths, left, mid, right)
      segments = widths.map { |w| '─' * (w + 2) }
      left + segments.join(mid) + right
    end

    private_class_method def self.data_row(cells, widths, alignments)
      formatted = cells.each_with_index.map do |cell, i|
        align_cell(cell.to_s, widths[i], alignments[i])
      end
      "│ #{formatted.join(' │ ')} │"
    end

    private_class_method def self.align_cell(content, width, alignment)
      case alignment
      when :right
        content.rjust(width)
      when :center
        content.center(width)
      else # :left
        content.ljust(width)
      end
    end
  end
end
