# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI, 'json format options' do
  def run_cli_output(*argv)
    run_fixture_cli_output(*argv)
  end

  describe 'JSON format options' do
    it 'produces compact JSON with -f j' do
      output = run_cli_output('-f', 'j', 'list')

      expect(output.strip.lines.count).to eq(1)
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces pretty JSON with -f J (uppercase short flag)' do
      output = run_cli_output('-f', 'J', 'list')
      expect(output.strip.lines.count).to be > 1
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces pretty JSON with -f pretty-json' do
      output = run_cli_output('-f', 'pretty-json', 'list')
      expect(output.strip.lines.count).to be > 1
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces pretty JSON with -f pretty_json (underscore variant)' do
      output = run_cli_output('-f', 'pretty_json', 'list')
      expect(output.strip.lines.count).to be > 1
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end

    it 'produces compact JSON with -f json' do
      output = run_cli_output('-f', 'json', 'list')
      expect(output.strip.lines.count).to eq(1)
      data = JSON.parse(output)
      expect(data['files']).to be_an(Array)
    end
  end
end
