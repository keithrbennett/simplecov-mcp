# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI, 'json format options' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def run_cli_output(*argv)
    cli = CovLoupe::CoverageCLI.new
    output = nil
    silence_output do |stdout, _stderr|
      cli.send(:run, argv)
      output = stdout.string
    end
    output
  end

  describe 'JSON format options' do
    it 'produces compact JSON with -f j' do
      output = run_cli_output('--root', root, '--resultset', 'coverage', '-f', 'j', 'list')

      expect(output.strip.lines.count).to eq(1)
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces pretty JSON with -f pretty-json' do
      output = run_cli_output('--root', root, '--resultset', 'coverage', '-f', 'pretty-json',
        'list')
      expect(output.strip.lines.count).to be > 1
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces pretty JSON with -f pretty_json (underscore variant)' do
      output = run_cli_output('--root', root, '--resultset', 'coverage', '-f', 'pretty_json',
        'list')
      expect(output.strip.lines.count).to be > 1
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces compact JSON with -f json' do
      output = run_cli_output('--root', root, '--resultset', 'coverage', '-f', 'json', 'list')
      expect(output.strip.lines.count).to eq(1)
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end
  end
end
