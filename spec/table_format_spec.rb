# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI, 'table format for all commands' do
  describe 'table format consistency' do
    it 'list command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'list')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('File')
      expect(output).to include('%')
    end

    it 'summary command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'summary', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('File')
      expect(output).to include('%')
    end

    it 'totals command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'totals')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Lines')
      expect(output).to include('%')
    end

    it 'detailed command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'detailed', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
      expect(output).to include('Hits')
    end

    it 'uncovered command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'uncovered', 'lib/bar.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
    end

    it 'raw command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'raw', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
      expect(output).to include('Coverage')
    end

    it 'version command produces formatted table' do
      output = run_fixture_cli_output('--format', 'table', 'version')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Version')
    end
  end
end
