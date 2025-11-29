# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/formatted_command_examples'

RSpec.describe SimpleCovMcp::Commands::SummaryCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.root = root
    cli_context.config.resultset = 'coverage'
    cli_context.config.format = :table
    cli_context.config.source_mode = nil
  end

  describe '#execute' do
    context 'with table format' do
      it 'prints a coverage summary line with a relative path' do
        output = capture_command_output(command, ['lib/foo.rb'])

        expect(output).to include('│', '66.67%', 'lib/foo.rb')
      end
    end

    context 'with stale data' do
      before { stub_staleness_check('L') }

      it_behaves_like 'a command with formatted output', ['lib/foo.rb'],
        { 'file' => 'lib/foo.rb', 'summary' => nil, 'stale' => 'L' }
    end
  end
end
