# frozen_string_literal: true

require_relative 'base_command'
require_relative '../formatters/source_formatter'
require_relative '../presenters/coverage_payload_presenter'
require_relative '../staleness/stale_status'

module CovLoupe
  module Commands
    class DetailedCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'detailed') do |path|
          presenter = Presenters::CoveragePayloadPresenter.new(model: model, path: path,
            payload_method: :detailed_for)
          data = presenter.absolute_payload
          break if emit_structured_format_with_optional_source?(data, model, path)

          relative_path = presenter.relative_path
          summary = data['summary']
          puts "File: #{relative_path}"
          puts "Coverage: #{summary['covered']}/#{summary['total']} lines (#{format('%.2f%%', summary['percentage'])})"
          puts "Stale: #{data['stale']}" if StaleStatus.stale?(data['stale'])
          puts

          # Table format with box-drawing
          headers = ['Line', 'Hits', 'Covered']
          rows = data['lines'].map do |r|
            [r['line'].to_s, r['hits'].to_s, r['covered'] ? 'yes' : 'no']
          end

          puts TableFormatter.format(
            headers: headers,
            rows: rows,
            alignments: [:right, :right, :center]
          )

          print_source_for(model, path) if config.source_mode
        end
      end
    end
  end
end
