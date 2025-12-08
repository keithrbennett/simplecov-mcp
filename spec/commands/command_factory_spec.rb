# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Commands::CommandFactory do
  let(:cli_context) { CovLoupe::CoverageCLI.new }

  describe '.create' do
    context 'with valid command names' do
      [
        ['list', CovLoupe::Commands::ListCommand],
        ['version', CovLoupe::Commands::VersionCommand],
        ['summary', CovLoupe::Commands::SummaryCommand],
        ['raw', CovLoupe::Commands::RawCommand],
        ['uncovered', CovLoupe::Commands::UncoveredCommand],
        ['detailed', CovLoupe::Commands::DetailedCommand],
        ['totals', CovLoupe::Commands::TotalsCommand],
        ['total', CovLoupe::Commands::TotalsCommand] # Alias
      ].each do |command_name, command_class|
        it "creates a #{command_class.name.split('::').last} for \"#{command_name}\"" do
          command = described_class.create(command_name, cli_context)
          expect(command).to be_a(command_class)
        end
      end
    end

    context 'with unknown command name' do
      [
        [
          'invalid_cmd',
          'invalid command',
          /list \| summary <path> \| raw <path> \| uncovered <path>/
        ],
        [nil,           'nil command',            nil],
        ['',            'empty string command',   nil],
        ['sumary',      'misspelled command',     nil]
      ].each do |command_name, description, pattern|
        it "raises UsageError for #{description}" do
          expect do
            described_class.create(command_name, cli_context)
          end.to raise_error(CovLoupe::UsageError, pattern)
        end
      end
    end
  end

  describe '.available_commands' do
    it 'returns an array of available command names' do
      commands = described_class.available_commands
      expect(commands).to be_an(Array)
      expect(commands).to contain_exactly('list', 'version', 'summary', 'raw', 'uncovered',
        'detailed', 'totals', 'total', 'validate')
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
      expect(described_class::COMMAND_MAP['list']).to eq(CovLoupe::Commands::ListCommand)
      expect(described_class::COMMAND_MAP['version']).to eq(CovLoupe::Commands::VersionCommand)
      expect(described_class::COMMAND_MAP['summary']).to eq(CovLoupe::Commands::SummaryCommand)
      expect(described_class::COMMAND_MAP['raw']).to eq(CovLoupe::Commands::RawCommand)
      expect(described_class::COMMAND_MAP['uncovered']).to eq(CovLoupe::Commands::UncoveredCommand)
      expect(described_class::COMMAND_MAP['detailed']).to eq(CovLoupe::Commands::DetailedCommand)
      expect(described_class::COMMAND_MAP['totals']).to eq(CovLoupe::Commands::TotalsCommand)
      expect(described_class::COMMAND_MAP['total']).to eq(CovLoupe::Commands::TotalsCommand)
    end
  end
end
