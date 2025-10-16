# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::CommandFactory do
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }

  describe '.create' do
    context 'with valid command names' do
      [
        ['list', SimpleCovMcp::Commands::ListCommand],
        ['version', SimpleCovMcp::Commands::VersionCommand],
        ['summary', SimpleCovMcp::Commands::SummaryCommand],
        ['raw', SimpleCovMcp::Commands::RawCommand],
        ['uncovered', SimpleCovMcp::Commands::UncoveredCommand],
        ['detailed', SimpleCovMcp::Commands::DetailedCommand]
      ].each do |command_name, command_class|
        it "creates a #{command_class.name.split('::').last} for \"#{command_name}\"" do
          command = described_class.create(command_name, cli_context)
          expect(command).to be_a(command_class)
        end
      end
    end

    context 'with unknown command name' do
      [
        ['invalid_cmd', 'invalid command',        
           /list | summary <path> | raw <path> | uncovered <path> | detailed <path> | version/],
        [nil,           'nil command',            nil],
        ['',            'empty string command',   nil],
        ['sumary',      'misspelled command',     nil]
      ].each do |command_name, description, pattern|
        it "raises UsageError for #{description}" do
          expect do
            described_class.create(command_name, cli_context)
          end.to raise_error(SimpleCovMcp::UsageError, pattern)
        end
      end
    end
  end

  describe '.available_commands' do
    it 'returns an array of available command names' do
      commands = described_class.available_commands
      expect(commands).to be_an(Array)
      expect(commands).to contain_exactly('list', 'version', 'summary', 'raw', 'uncovered', 
        'detailed')
    end

    it 'returns the keys from COMMAND_MAP' do
      expect(described_class.available_commands).to eq(described_class::COMMAND_MAP.keys)
    end
  end

  describe 'COMMAND_MAP' do
    it 'is frozen to prevent modifications' do
      expect(described_class::COMMAND_MAP).to be_frozen
    end

    it 'maps command names to command classes' do
      expect(described_class::COMMAND_MAP['list']).to eq(SimpleCovMcp::Commands::ListCommand)
      expect(described_class::COMMAND_MAP['version']).to eq(SimpleCovMcp::Commands::VersionCommand)
      expect(described_class::COMMAND_MAP['summary']).to eq(SimpleCovMcp::Commands::SummaryCommand)
      expect(described_class::COMMAND_MAP['raw']).to eq(SimpleCovMcp::Commands::RawCommand)
      expect(described_class::COMMAND_MAP['uncovered']).to eq(SimpleCovMcp::Commands::UncoveredCommand)
      expect(described_class::COMMAND_MAP['detailed']).to eq(SimpleCovMcp::Commands::DetailedCommand)
    end
  end
end
