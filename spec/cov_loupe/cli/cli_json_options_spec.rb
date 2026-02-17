# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI, 'json format options' do
  def run_cli_output(*argv)
    run_fixture_cli_output(*argv)
  end

  describe 'JSON format options' do
    [
      { flag: 'j',   expect_compact: true },
      { flag: 'p',   expect_compact: false },
      { flag: 'pretty-json',   expect_compact: false },
      { flag: 'pretty_json',   expect_compact: false },
      { flag: 'json', expect_compact: true }
    ].each do |test_case|
      it "produces #{test_case[:expect_compact] ? 'compact' : 'pretty'} JSON with -f #{test_case[:flag]}" do
        output = run_cli_output('-f', test_case[:flag], 'list')

        if test_case[:expect_compact]
          expect(output.strip.lines.count).to eq(1)
        else
          expect(output.strip.lines.count).to be > 1
        end
        data = JSON.parse(output)
        expect(data['files']).to be_an(Array)
      end
    end
  end
end
