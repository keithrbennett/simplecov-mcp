# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::VersionCommand do
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }
  let(:command) { described_class.new(cli_context) }

  before do
    cli_context.config.json = false
  end

  describe '#execute' do
    it 'prints version, gem root, and documentation info in text mode' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute([])
        output = stdout.string
      end

      expect(output).to include("SimpleCovMcp version #{SimpleCovMcp::VERSION}")
      expect(output).to include('Gem root:')
      expect(output).to include('For usage help, consult README.md and docs/user/**/*.md')
      expect(output).to include('gem root directory')
    end

    it 'includes a valid gem root path that exists' do
      output = nil

      silence_output do |stdout, _stderr|
        command.execute([])
        output = stdout.string
      end

      # Extract gem root path from output
      gem_root_line = output.lines.find { |line| line.start_with?('Gem root:') }
      expect(gem_root_line).not_to be_nil

      gem_root = gem_root_line.split('Gem root:').last.strip
      expect(File.directory?(gem_root)).to be true
    end

    it 'emits JSON with version and gem_root when requested' do
      cli_context.config.json = true

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
