# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::ModeDetector do
  describe '.cli_mode?' do
    # Array-driven test cases for comprehensive coverage
    # Format: [argv, tty?, expected_result, description]
    CLI_MODE_SCENARIOS = [
      # Priority 1: --force-cli flag (highest priority)
      [['--force-cli'], false, true, '--force-cli with piped input'],
      [['--force-cli', '--json'], false, true, '--force-cli with other flags'],

      # Priority 2: Valid subcommands (must be first arg)
      [['list'], false, true, 'list subcommand'],
      [['summary', 'lib/foo.rb'], false, true, 'summary with path'],
      [['version'], false, true, 'version subcommand'],
      [['total'], false, true, 'total subcommand'],
      [['list', '--json'], false, true, 'subcommand with trailing flags'],

      # Priority 3: Invalid subcommand attempts (must be first non-flag arg)
      [['invalid-command'], false, true, 'invalid subcommand (shows error)'],
      [['lib/foo.rb'], false, true, 'file path (shows error)'],

      # Priority 4: TTY determines mode when no subcommand/force-cli
      [[], true, true, 'empty args with TTY'],
      [[], false, false, 'empty args with piped input'],
      [['--json'], true, true, 'flags only with TTY'],
      [['--json'], false, false, 'flags only with piped input'],
      [['-r', 'foo', '--json'], false, false, 'multiple flags with piped input'],

      # Edge cases: flags before subcommands should now be detected as CLI mode
      [['--json', 'list'], false, true, 'flag first = CLI mode'],
      [['-r', 'foo', 'summary'], false, true, 'option first = CLI mode'],
    ].freeze

    CLI_MODE_SCENARIOS.each do |argv, is_tty, expected, description|
      it "#{expected ? 'CLI' : 'MCP'}: #{description}" do
        stdin = double('stdin', tty?: is_tty)
        result = described_class.cli_mode?(argv, stdin: stdin)
        expect(result).to be(expected),
          "Expected cli_mode?(#{argv.inspect}, tty: #{is_tty}) to be #{expected}, got #{result}"
      end
    end

    # Test all subcommands dynamically
    context 'with all valid subcommands' do
      SimpleCovMcp::ModeDetector::SUBCOMMANDS.each do |subcommand|
        it "CLI mode for '#{subcommand}' (no TTY)" do
          stdin = double('stdin', tty?: false)
          expect(described_class.cli_mode?([subcommand], stdin: stdin)).to be true
        end
      end
    end

    it 'uses STDIN by default when no stdin parameter given' do
      allow(STDIN).to receive(:tty?).and_return(true)
      expect(described_class.cli_mode?([])).to be true
    end
  end

  describe '.mcp_server_mode?' do
    # Simpler test cases for the inverse method
    MCP_SCENARIOS = [
      [[], false, true, 'piped input, no args'],
      [['--json'], false, true, 'piped input with flags'],
      [[], true, false, 'TTY, no args'],
      [['--force-cli'], false, false, '--force-cli flag'],
      [['list'], false, false, 'subcommand'],
    ].freeze

    MCP_SCENARIOS.each do |argv, is_tty, expected, description|
      it "#{expected ? 'MCP' : 'CLI'}: #{description}" do
        stdin = double('stdin', tty?: is_tty)
        expect(described_class.mcp_server_mode?(argv, stdin: stdin)).to be expected
      end
    end

    it 'is the logical inverse of cli_mode?' do
      [[[], true], [[], false], [['list'], false]].each do |argv, is_tty|
        stdin = double('stdin', tty?: is_tty)
        cli = described_class.cli_mode?(argv, stdin: stdin)
        mcp = described_class.mcp_server_mode?(argv, stdin: stdin)
        expect(mcp).to eq(!cli)
      end
    end
  end

  describe 'priority order' do
    let(:stdin) { double('stdin', tty?: false) }

    it '1. --force-cli overrides everything' do
      expect(described_class.cli_mode?(['--force-cli'], stdin: stdin)).to be true
    end

    it '2. subcommand (first arg) overrides TTY' do
      expect(described_class.cli_mode?(['list'], stdin: stdin)).to be true
    end

    it '3. invalid first arg (not flag) triggers CLI' do
      expect(described_class.cli_mode?(['invalid'], stdin: stdin)).to be true
    end

    it '4. TTY is checked last (when first arg is flag or empty)' do
      tty = double('stdin', tty?: true)
      no_tty = double('stdin', tty?: false)

      expect(described_class.cli_mode?([], stdin: tty)).to be true
      expect(described_class.cli_mode?([], stdin: no_tty)).to be false
    end
  end

  describe 'consistency checks' do
    it 'SUBCOMMANDS matches CoverageCLI' do
      expect(SimpleCovMcp::ModeDetector::SUBCOMMANDS).to eq(SimpleCovMcp::CoverageCLI::SUBCOMMANDS)
    end

    it 'all SUBCOMMANDS are lowercase without dashes' do
      SimpleCovMcp::ModeDetector::SUBCOMMANDS.each do |cmd|
        expect(cmd).to eq(cmd.downcase)
        expect(cmd).not_to start_with('-')
      end
    end
  end

  describe 'regression tests for non-TTY environment' do
    let(:stdin) { double('stdin', tty?: false) }

    it 'chooses CLI mode for --help' do
      expect(described_class.cli_mode?(['--help'], stdin: stdin)).to be true
    end

    it 'chooses CLI mode for -h' do
      expect(described_class.cli_mode?(['-h'], stdin: stdin)).to be true
    end

    it 'chooses CLI mode for --version' do
      expect(described_class.cli_mode?(['--version'], stdin: stdin)).to be true
    end

    it 'chooses CLI mode for -v' do
      expect(described_class.cli_mode?(['-v'], stdin: stdin)).to be true
    end

    it 'chooses CLI mode for --json list' do
      expect(described_class.cli_mode?(['--json', 'list'], stdin: stdin)).to be true
    end

    it 'chooses MCP mode for flags without a subcommand' do
      expect(described_class.cli_mode?(['--json'], stdin: stdin)).to be false
    end
  end
end
