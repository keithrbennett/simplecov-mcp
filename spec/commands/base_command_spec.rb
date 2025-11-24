# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Commands::BaseCommand do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli_context) { SimpleCovMcp::CoverageCLI.new }

  # Create a test command class that exposes protected methods for testing
  let(:test_command_class) do
    Class.new(SimpleCovMcp::Commands::BaseCommand) do
      def execute(args)
        # Not needed for these tests
      end

      # Expose protected methods for testing
      def public_handle_with_path(args, name, &block)
        handle_with_path(args, name, &block)
      end
    end
  end

  let(:test_command) { test_command_class.new(cli_context) }

  describe '#handle_with_path' do
    context 'when Errno::ENOENT is raised' do
      it 'converts to FileNotFoundError with correct message' do
        args = ['lib/missing.rb']

        # Stub the block to raise Errno::ENOENT
        expect do
          test_command.public_handle_with_path(args, 'test') do |path|
            raise Errno::ENOENT.new('No such file or directory')
          end
        end.to raise_error(SimpleCovMcp::FileNotFoundError, 'File not found: lib/missing.rb')
      end

      it 'includes the path from the args in the error message' do
        args = ['some/other/path.rb']

        expect do
          test_command.public_handle_with_path(args, 'test') do |path|
            raise Errno::ENOENT.new('No such file or directory')
          end
        end.to raise_error(SimpleCovMcp::FileNotFoundError, /some\/other\/path\.rb/)
      end
    end

    context 'when Errno::EACCES is raised' do
      it 'converts to FilePermissionError with correct message' do
        args = ['lib/secret.rb']

        # Stub the block to raise Errno::EACCES
        expect do
          test_command.public_handle_with_path(args, 'test') do |path|
            raise Errno::EACCES.new('Permission denied')
          end
        end.to raise_error(SimpleCovMcp::FilePermissionError, 'Permission denied: lib/secret.rb')
      end

      it 'includes the path from the args in the error message' do
        args = ['/root/protected.rb']

        expect do
          test_command.public_handle_with_path(args, 'test') do |path|
            raise Errno::EACCES.new('Permission denied')
          end
        end.to raise_error(SimpleCovMcp::FilePermissionError, /\/root\/protected\.rb/)
      end
    end

    context 'when no path is provided' do
      it 'raises UsageError' do
        args = []

        expect do
          test_command.public_handle_with_path(args, 'summary') do |path|
            # Should not reach here
          end
        end.to raise_error(SimpleCovMcp::UsageError, /summary <path>/)
      end
    end

    context 'when successful' do
      it 'yields the path to the block' do
        args = ['lib/foo.rb']
        yielded_path = nil

        test_command.public_handle_with_path(args, 'test') do |path|
          yielded_path = path
        end

        expect(yielded_path).to eq('lib/foo.rb')
      end

      it 'shifts the path from args' do
        args = ['lib/foo.rb', 'extra', 'args']

        test_command.public_handle_with_path(args, 'test') do |path|
          # Block execution
        end

        expect(args).to eq(['extra', 'args'])
      end
    end
  end
end
