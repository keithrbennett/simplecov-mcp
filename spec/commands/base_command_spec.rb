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

      def public_fetch_raw(model, path)
        fetch_raw(model, path)
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

  describe '#fetch_raw' do
    let(:model) { SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage') }

    context 'when model.raw_for raises an exception' do
      it 'returns nil instead of propagating the error' do
        # Stub model.raw_for to raise an exception
        allow(model).to receive(:raw_for).and_raise(StandardError, 'Something went wrong')

        result = test_command.public_fetch_raw(model, 'lib/nonexistent.rb')

        expect(result).to be_nil
      end

      it 'handles RuntimeError' do
        allow(model).to receive(:raw_for).and_raise(RuntimeError, 'Runtime error')

        result = test_command.public_fetch_raw(model, 'lib/foo.rb')

        expect(result).to be_nil
      end

      it 'handles ArgumentError' do
        allow(model).to receive(:raw_for).and_raise(ArgumentError, 'Invalid argument')

        result = test_command.public_fetch_raw(model, 'lib/foo.rb')

        expect(result).to be_nil
      end
    end

    context 'when successful' do
      it 'returns the raw coverage data' do
        result = test_command.public_fetch_raw(model, 'lib/foo.rb')

        expect(result).to be_a(Hash)
        expect(result).to have_key('lines')
        expect(result['lines']).to be_an(Array)
      end

      it 'caches the result for subsequent calls' do
        # First call should hit the model
        expect(model).to receive(:raw_for).with('lib/foo.rb').once.and_call_original

        result1 = test_command.public_fetch_raw(model, 'lib/foo.rb')
        result2 = test_command.public_fetch_raw(model, 'lib/foo.rb')

        expect(result1).to eq(result2)
      end

      it 'caches different paths separately' do
        result1 = test_command.public_fetch_raw(model, 'lib/foo.rb')
        result2 = test_command.public_fetch_raw(model, 'lib/bar.rb')

        expect(result1).not_to eq(result2)
      end

      it 'does not cache nil results from exceptions' do
        # Set up the stub to raise an error
        call_count = 0
        allow(model).to receive(:raw_for).with('lib/missing.rb') do
          call_count += 1
          raise StandardError, 'File not found'
        end

        result1 = test_command.public_fetch_raw(model, 'lib/missing.rb')
        result2 = test_command.public_fetch_raw(model, 'lib/missing.rb')

        expect(result1).to be_nil
        expect(result2).to be_nil
        # Note: Due to current implementation, nil results are NOT cached,
        # so raw_for is called each time an exception occurs
        expect(call_count).to eq(2)
      end
    end
  end
end
