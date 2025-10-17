# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageModel, 'error handling' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  describe 'initialization error handling' do
    it 'raises CoverageDataError with message detail for invalid JSON format' do
      # Mock JSON.parse to raise JSON::ParserError
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError.new('unexpected token'))

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data format')
        expect(error.message).to include('unexpected token')
      end
    end

    it 'raises FilePermissionError when coverage file is not readable' do
      # Mock File.read to raise Errno::EACCES
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(end_with('.resultset.json')).and_raise(
        Errno::EACCES.new('Permission denied')
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::FilePermissionError) do |error|
        expect(error.message).to include('Permission denied reading coverage data')
        expect(error.message).to include('Permission denied')
      end
    end

    it 'raises CoverageDataError when resultset structure is invalid (TypeError)' do
      # Create a malformed resultset that will cause TypeError
      malformed_resultset = {
        'RSpec' => {
          'coverage' => 'not_a_hash' # Should be a hash, not a string
        }
      }

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(end_with('.resultset.json'))
        .and_return(malformed_resultset.to_json)

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data structure')
      end
    end

    it 'raises CoverageDataError when resultset structure causes NoMethodError' do
      # Create a resultset structure that will cause NoMethodError
      malformed_resultset = {
        'RSpec' => {
          'coverage' => {
            'file.rb' => nil # Should have 'lines' key, this will cause NoMethodError
          }
        }
      }

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(end_with('.resultset.json'))
        .and_return(malformed_resultset.to_json)

      # This might succeed or fail depending on how the code handles it
      # Let's make it fail by mocking transform_keys to raise NoMethodError
      allow_any_instance_of(Hash).to receive(:transform_keys)
        .and_raise(NoMethodError.new("undefined method `upcase' for nil:NilClass"))

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data structure')
      end
    end

    it 'raises CoverageDataError when path operations raise ArgumentError' do
      # Create a valid resultset structure with a problematic path
      valid_resultset = {
        'RSpec' => {
          'coverage' => {
            "lib/foo\x00bar.rb" => { 'lines' => [1, 0, 1] } # Path with NULL byte
          },
          'timestamp' => 1000
        }
      }

      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(end_with('.resultset.json'))
        .and_return(valid_resultset.to_json)

      # Mock File.absolute_path to raise ArgumentError when called with the problematic path
      # But allow it to work for the root initialization
      allow(File).to receive(:absolute_path).and_call_original
      allow(File).to receive(:absolute_path).with(include("\x00"), anything).and_raise(
        ArgumentError.new('string contains null byte')
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Invalid path in coverage data')
        expect(error.message).to include('null byte')
      end
    end

    it 'preserves error context in JSON::ParserError messages' do
      # Mock JSON.parse to raise JSON::ParserError with specific message
      allow(JSON).to receive(:parse).and_raise(
        JSON::ParserError.new('765: unexpected token at line 3, column 5')
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        # Verify the original error message details are preserved
        expect(error.message).to include('765')
        expect(error.message).to include('line 3')
      end
    end

    it 'provides helpful error for permission issues with file path' do
      # Mock to raise permission error with actual file path
      resultset_path = File.join(root, 'coverage', '.resultset.json')
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(resultset_path).and_raise(
        Errno::EACCES.new(resultset_path)
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::FilePermissionError) do |error|
        expect(error.message).to include('Permission denied')
        expect(error.message).to match(/\.resultset\.json/)
      end
    end
  end

  describe 'error context preservation' do
    it 'includes original exception message in all specific error types' do
      test_cases = [
        {
          error_class: JSON::ParserError,
          message: 'unexpected character at byte 42',
          expected_type: SimpleCovMcp::CoverageDataError,
          expected_content: 'unexpected character at byte 42'
        },
        {
          error_class: Errno::EACCES,
          message: '/path/to/coverage/.resultset.json',
          expected_type: SimpleCovMcp::FilePermissionError,
          expected_content: '/path/to/coverage/.resultset.json'
        },
        {
          error_class: TypeError,
          message: 'no implicit conversion of String into Integer',
          expected_type: SimpleCovMcp::CoverageDataError,
          expected_content: 'no implicit conversion'
        }
      ]

      test_cases.each do |test_case|
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(end_with('.resultset.json')).and_raise(
          test_case[:error_class].new(test_case[:message])
        )

        expect do
          SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
        end.to raise_error(test_case[:expected_type]) do |error|
          expect(error.message).to include(test_case[:expected_content])
        end
      end
    end
  end

  describe 'RuntimeError handling from find_resultset' do
    it 'converts RuntimeError to CoverageDataError with helpful message' do
      # Mock find_resultset to raise RuntimeError (simulating missing resultset)
      allow(SimpleCovMcp::CovUtil).to receive(:find_resultset).and_raise(
        RuntimeError.new('Specified resultset not found: /nonexistent/path/.resultset.json')
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: '/nonexistent/path')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Failed to load coverage data')
        expect(error.message).to include('Specified resultset not found')
      end
    end

    it 'handles RuntimeError with generic messages' do
      # Test RuntimeError with any generic message
      allow(SimpleCovMcp::CovUtil).to receive(:find_resultset).and_raise(
        RuntimeError.new('Something went wrong during resultset lookup')
      )

      expect do
        SimpleCovMcp::CoverageModel.new(root: root, resultset: 'coverage')
      end.to raise_error(SimpleCovMcp::CoverageDataError) do |error|
        expect(error.message).to include('Failed to load coverage data')
        expect(error.message).to include('Something went wrong')
      end
    end
  end
end
