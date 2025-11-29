# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI, 'table format for all commands' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def run_cli(*argv)
    cli = SimpleCovMcp::CoverageCLI.new
    output = nil
    silence_output do |stdout, _stderr|
      cli.send(:run, argv)
      output = stdout.string
    end
    output
  end

  describe 'table format consistency' do
    it 'list command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table', 'list')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('File')
      expect(output).to include('%')
    end

    it 'summary command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table',
        'summary', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('File')
      expect(output).to include('%')
    end

    it 'totals command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table', 'totals')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Lines')
      expect(output).to include('%')
    end

    it 'detailed command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table',
        'detailed', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
      expect(output).to include('Hits')
    end

    it 'uncovered command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table',
        'uncovered', 'lib/bar.rb')  # bar.rb has uncovered lines
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
    end

    it 'raw command produces formatted table' do
      output = run_cli('--root', root, '--resultset', 'coverage', '--format', 'table',
        'raw', 'lib/foo.rb')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Line')
      expect(output).to include('Coverage')
    end

    it 'version command produces formatted table' do
      output = run_cli('--format', 'table', 'version')
      expect(output).to include('│')  # Box drawing character
      expect(output).to include('Version')
    end
  end
end
