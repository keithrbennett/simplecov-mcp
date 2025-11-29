# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::VersionCommand do
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.format = :table
  end

  describe '#execute' do
    it 'prints version, gem root, and documentation info in text mode' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute([])
        output = stdout.string
      end

      # Expect table format with box-drawing characters
      expect(output).to include('│')  # Box drawing character
      expect(output).to include(SimpleCovMcp::VERSION)
      expect(output).to include('Gem Root')
      expect(output).to include('Documentation')
      expect(output).to include('README.md')
    end

    it 'includes a valid gem root path that exists' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute([])
        output = stdout.string
      end

      # Extract gem root from table output - look for line with Gem Root
      gem_root_line = output.lines.find { |line| line.include?('Gem Root') }
      expect(gem_root_line).not_to be_nil

      # Extract path from table cell (value is in the last column before final │)
      parts = gem_root_line.split('│')
      gem_root = parts[-2].strip  # Second to last part is the value column
      expect(File.directory?(gem_root)).to be true
    end

    it 'emits JSON with version and gem_root when requested' do
      cli_context.config.format = :json

      json_output = nil
      silence_output do |stdout, _stderr|
        command.execute([])
        json_output = stdout.string
      end

      payload = JSON.parse(json_output)
      expect(payload).to have_key('version')
      expect(payload['version']).to eq(SimpleCovMcp::VERSION)
      expect(payload).to have_key('gem_root')
      expect(File.directory?(payload['gem_root'])).to be true
    end
  end
end
