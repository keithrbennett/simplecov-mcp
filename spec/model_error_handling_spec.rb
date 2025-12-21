# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageModel, 'error handling' do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:malformed_resultset) do
    {
      'RSpec' => {
        'coverage' => 'not_a_hash' # Should be a hash, not a string
      }
    }
  end

  describe 'initialization error handling' do
    let(:valid_resultset) do
      {
        'RSpec' => {
          'coverage' => {
            "lib/foo\x00bar.rb" => { 'lines' => [1, 0, 1] } # Path with NULL byte
          }
        },
        'timestamp' => 1000
      }
    end
    let(:malformed_resultset) do
      {
        'RSpec' => {
          'coverage' => 'not_a_hash' # Should be a hash, not a string
        }
      }
    end

    it 'raises CoverageDataError with message detail for invalid JSON format' do
      mock_json_parse_error(JSON::ParserError.new('unexpected token'))

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data format', 'unexpected token')
      end
    end

    it 'raises FilePermissionError when coverage file is not readable' do
      mock_file_read_error(Errno::EACCES.new('Permission denied'))

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::FilePermissionError) do |error|
        expect(error.message).to include('Permission denied reading coverage data')
      end
    end


    it 'raises CoverageDataError when resultset structure is invalid (TypeError)' do
      mock_resultset_data(malformed_resultset)

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
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

      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(end_with('.resultset.json'), 'r')
        .and_return(StringIO.new(malformed_resultset.to_json))

      broken_map = instance_double('CoverageMap')
      allow(broken_map).to receive(:transform_keys)
        .and_raise(NoMethodError.new("undefined method `upcase' for nil:NilClass"))
      allow(CovLoupe::ResultsetLoader).to receive(:load).and_return(
        CovLoupe::ResultsetLoader::Result.new(coverage_map: broken_map,
          timestamp: 0, suite_names: ['RSpec'])
      )

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data structure')
      end
    end




    it 'raises CoverageDataError when path operations raise ArgumentError' do
      mock_resultset_data(valid_resultset, path_matcher: end_with('.resultset.json'))

      # Mock File.absolute_path to raise ArgumentError when called with the problematic path
      # But allow it to work for the root initialization
      allow(File).to receive(:absolute_path).and_call_original
      allow(File).to receive(:absolute_path).with(include("\x00"), anything).and_raise(
        ArgumentError.new('string contains null byte')
      )

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('Invalid path in coverage data', 'null byte')
      end
    end

    it 'preserves error context in JSON::ParserError messages' do
      mock_json_parse_error(JSON::ParserError.new('765: unexpected token at line 3, column 5'))

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        # Verify the original error message details are preserved
        expect(error.message).to include('765', 'line 3')
      end
    end

    it 'provides helpful error for permission issues with file path' do
      # Mock to raise permission error with actual file path
      resultset_path = File.join(root, 'coverage', '.resultset.json')
      mock_file_read_error(Errno::EACCES.new(resultset_path), path_matcher: resultset_path)

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::FilePermissionError) do |error|
        expect(error.message).to include('Permission denied')
        expect(error.message).to match(/\.resultset\.json/)
      end
    end
  end

  describe 'error context preservation' do
    it 'includes original exception message for JSON::ParserError' do
      mock_json_parse_error(JSON::ParserError.new('unexpected character at byte 42'))

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('unexpected character at byte 42')
      end
    end

    it 'includes original exception message for Errno::EACCES' do
      resultset_path = File.join(root, 'coverage', '.resultset.json')
      mock_file_read_error(Errno::EACCES.new(resultset_path), path_matcher: resultset_path)

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::FilePermissionError) do |error|
        expect(error.message).to include(resultset_path)
      end
    end

    it 'includes original exception message for TypeError' do
      # Mock to cause TypeError within ResultsetLoader's processing
      mock_resultset_data(malformed_resultset)

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('Invalid coverage data structure', 'suite "RSpec"')
      end
    end
  end

  describe 'RuntimeError handling from find_resultset' do
    it 'converts RuntimeError to CoverageDataError with helpful message' do
      # Mock find_resultset to raise RuntimeError (simulating missing resultset)
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:find_resultset).and_raise(
        RuntimeError.new('Specified resultset not found: /nonexistent/path/.resultset.json')
      )

      expect do
        described_class.new(root: root, resultset: '/nonexistent/path')
      end.to raise_error(CovLoupe::ResultsetNotFoundError) do |error|
        expect(error.message).to include('Specified resultset not found')
      end
    end

    it 'handles RuntimeError with generic messages' do
      # Test RuntimeError with any generic message that includes 'resultset'
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:find_resultset).and_raise(
        RuntimeError.new('Something went wrong during resultset lookup')
      )

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::ResultsetNotFoundError) do |error|
        expect(error.message).to include('Something went wrong during resultset lookup')
      end
    end

    it 'converts RuntimeError without "resultset" in message to CoverageDataError' do
      # Test RuntimeError that does NOT contain 'resultset' in its message
      # This exercises the else branch in the RuntimeError rescue clause
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:find_resultset).and_raise(
        RuntimeError.new('Some completely unrelated runtime error')
      )

      expect do
        described_class.new(root: root, resultset: 'coverage')
      end.to raise_error(CovLoupe::CoverageDataError) do |error|
        expect(error.message).to include('Failed to load coverage data',
          'Some completely unrelated runtime error')
      end
    end
  end

  describe 'list error handling' do
    it 'skips files that raise FileError during coverage lookup' do
      # This exercises the `next` statement in the list loop when FileError is raised

      # Create mock logger first
      mock_logger = instance_double(CovLoupe::Logger)

      # Expect the error to be logged only once (per model.list call)
      expect(mock_logger).to receive(:safe_log)
        .with(a_string_including('Skipping coverage row', 'Corrupted coverage entry')).once

      model = described_class.new(root: root, resultset: 'coverage', logger: mock_logger)

      # Mock lookup_lines to raise FileError for one specific file
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines).and_call_original
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines)
        .with(anything, include('/lib/foo.rb'))
        .and_raise(CovLoupe::FileError.new('Corrupted coverage entry'))

      # Should not raise, just skip the problematic file
      list_result = model.list(raise_on_stale: false)
      files = list_result['files']

      # The result should contain bar.rb but not foo.rb
      file_names = files.map { |r| File.basename(r['file']) }
      expect(file_names).to include('bar.rb')
      expect(file_names).not_to include('foo.rb')
      expect(list_result['skipped_files']).to contain_exactly(
        hash_including(
          'file' => File.expand_path('lib/foo.rb', root),
          'error' => 'Corrupted coverage entry',
          'error_class' => 'CovLoupe::FileError'
        )
      )
    end

    it 'skips files that raise CorruptCoverageDataError during coverage lookup' do
      mock_logger = instance_double(CovLoupe::Logger)
      expect(mock_logger).to receive(:safe_log)
        .with(a_string_including('Skipping coverage row', 'Corrupted coverage entry')).once

      model = described_class.new(root: root, resultset: 'coverage', logger: mock_logger)

      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines).and_call_original
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines)
        .with(anything, include('/lib/foo.rb'))
        .and_raise(CovLoupe::CorruptCoverageDataError.new('Corrupted coverage entry'))

      list_result = model.list(raise_on_stale: false)
      files = list_result['files']

      file_names = files.map { |r| File.basename(r['file']) }
      expect(file_names).to include('bar.rb')
      expect(file_names).not_to include('foo.rb')
      expect(list_result['skipped_files']).to contain_exactly(
        hash_including(
          'file' => File.expand_path('lib/foo.rb', root),
          'error' => 'Corrupted coverage entry',
          'error_class' => 'CovLoupe::CorruptCoverageDataError'
        )
      )
    end

    it 'raises FileError when raise_on_stale is true and file lookup fails' do
      model = described_class.new(root: root, resultset: 'coverage')

      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines).and_call_original
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines)
        .with(anything, include('/lib/foo.rb'))
        .and_raise(CovLoupe::FileError.new('Missing file'))

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::FileError, 'Missing file')
    end

    it 'raises CorruptCoverageDataError when raise_on_stale is true and data is corrupt' do
      model = described_class.new(root: root, resultset: 'coverage')

      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines).and_call_original
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines)
        .with(anything, include('/lib/foo.rb'))
        .and_raise(CovLoupe::CorruptCoverageDataError.new('Corrupted coverage entry'))

      expect do
        model.list(raise_on_stale: true)
      end.to raise_error(CovLoupe::CorruptCoverageDataError, 'Corrupted coverage entry')
    end
  end

  describe 'resolve method error handling' do
    it 'converts RuntimeError from lookup_lines to FileError' do
      # This exercises the RuntimeError rescue clause in the resolve method
      model = described_class.new(root: root, resultset: 'coverage')

      # Mock lookup_lines to raise RuntimeError for a specific file
      allow(CovLoupe::Resolvers::ResolverFactory).to receive(:lookup_lines)
        .and_raise(RuntimeError.new('Unexpected runtime error during lookup'))

      expect do
        model.summary_for('nonexistent_file.rb')
      end.to raise_error(CovLoupe::FileError) do |error|
        expect(error.message).to include('No coverage data found for file')
      end
    end
  end
end
