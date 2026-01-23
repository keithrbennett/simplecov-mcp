# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CLI --output-chars option' do
  describe '--output-chars ascii' do
    it 'produces ASCII table borders for list output' do
      output = run_fixture_cli_output('--output-chars', 'ascii', 'list')

      aggregate_failures do
        # ASCII border characters should be present
        expect(output).to include('+')
        expect(output).to include('-')
        expect(output).to include('|')

        # Unicode box-drawing characters should NOT be present
        expect(output).not_to include("\u250C") # top-left corner
        expect(output).not_to include("\u2500") # horizontal
        expect(output).not_to include("\u2502") # vertical
        expect(output).not_to include("\u2510") # top-right corner
      end
    end

    it 'produces ASCII table borders for default (no subcommand) output' do
      output = run_fixture_cli_output('--output-chars', 'ascii')

      aggregate_failures do
        expect(output).to include('+')
        expect(output).to include('|')
        expect(output).not_to include("\u250C")
        expect(output).not_to include("\u2502")
      end
    end
  end

  describe '--output-chars fancy' do
    it 'produces Unicode table borders' do
      output = run_fixture_cli_output('--output-chars', 'fancy', 'list')

      aggregate_failures do
        # Unicode box-drawing characters should be present
        expect(output).to include("\u250C") # top-left corner
        expect(output).to include("\u2500") # horizontal
        expect(output).to include("\u2502") # vertical
      end
    end
  end

  describe '-O short flag' do
    it 'works as alias for --output-chars' do
      output = run_fixture_cli_output('-O', 'ascii', 'list')

      expect(output).to include('+')
      expect(output).not_to include("\u250C")
    end
  end
end
