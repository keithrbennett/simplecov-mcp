# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/formatted_command_examples'

RSpec.describe SimpleCovMcp::Commands::VersionCommand do
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.format = :table
  end

  describe '#execute' do
    context 'with table format' do
      it 'prints version, gem root, and documentation info in text mode' do
        output = capture_command_output(command, [])

        expect(output).to include('│', SimpleCovMcp::VERSION, 'Gem Root', 'Documentation',
          'README.md')
      end

      it 'includes a valid gem root path that exists' do
        output = capture_command_output(command, [])

        # Extract gem root from table output
        gem_root_line = output.lines.find { |line| line.include?('Gem Root') }
        expect(gem_root_line).not_to be_nil

        parts = gem_root_line.split('│')
        gem_root = parts[-2].strip
        expect(File.directory?(gem_root)).to be true
      end
    end

    it_behaves_like 'a command with formatted output', [], ['version', 'gem_root']
  end
end
