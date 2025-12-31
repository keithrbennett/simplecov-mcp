# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/repositories/coverage_repository'

RSpec.describe CovLoupe::Repositories::CoverageRepository do
  subject(:repo) { described_class.new(root: root, resultset_path: resultset_arg, logger: logger) }

  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:resultset_arg) { nil }
  let(:logger) { instance_double('CovLoupe::Logger', safe_log: nil) }

  describe '#initialize' do
    context 'with valid data' do
      it 'loads coverage map' do
        expect(repo.coverage_map).not_to be_empty
        expect(repo.coverage_map).to have_key(File.join(root, 'lib', 'foo.rb'))
      end

      it 'normalizes keys to absolute paths' do
        repo.coverage_map.each_key do |key|
          expect(Pathname.new(key)).to be_absolute
        end
      end

      it 'sets timestamp' do
        expect(repo.timestamp).to be > 0
      end

      it 'resolves resultset path' do
        expected = File.join(root, 'coverage', '.resultset.json')
        expect(repo.resultset_path).to eq(expected)
      end
    end

    context 'when loading fails' do
      let(:resultset_arg) { '/nonexistent/path' }

      it 'raises error' do
        expect do
          repo
        end.to raise_error(CovLoupe::ResultsetNotFoundError)
      end
    end

    context 'when underlying loader raises generic error' do
      before do
        allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:find_resultset).and_return('dummy')
        allow(CovLoupe::ResultsetLoader).to receive(:load).and_raise(RuntimeError.new('Boom'))
      end

      it 'wraps RuntimeError as UnknownError' do
        expect do
          repo
        end.to raise_error(CovLoupe::UnknownError, /Boom/)
      end
    end

    # Tests for collision detection during path normalization.
    # When multiple keys in the resultset normalize to the same absolute path,
    # this indicates problematic data that would cause silent overwrites.
    # The repository should detect and report these collisions with clear errors.
    context 'when resultset contains duplicate normalized paths' do
      # Tests the most common collision scenario: same file referenced by
      # both relative path and absolute path in the coverage data.
      # Example: "lib/foo.rb" and "/full/path/lib/foo.rb" both normalize
      # to the same absolute path, causing one entry to silently overwrite the other
      # without collision detection.
      context 'with relative and absolute path collision' do
        let(:abs_foo_path) { File.join(root, 'lib', 'foo.rb') }
        let(:rel_foo_path) { 'lib/foo.rb' }

        before do
          # Simulate a resultset with both relative and absolute paths for the same file
          # Note: the 'lines' arrays differ to show that data would be lost
          coverage_data = {
            rel_foo_path => { 'lines' => [1, 0, nil, 2] },
            abs_foo_path => { 'lines' => [1, 1, nil, 2] }
          }
          mock_resultset_with_timestamp(root, FIXTURE_COVERAGE_TIMESTAMP, coverage: coverage_data)
        end

        it 'raises CoverageDataError with details about colliding keys' do
          expect { repo }.to raise_error(CovLoupe::CoverageDataError,
            /Duplicate paths detected after normalization/)
        end

        it 'includes both original keys in the error message' do
          expect { repo }.to raise_error(CovLoupe::CoverageDataError,
            /#{Regexp.escape(rel_foo_path)}/)
        end
      end

      # Tests that multiple simultaneous collisions are all detected and reported.
      # This verifies the error message includes details for every collision found,
      # not just the first one encountered.
      context 'with multiple collisions' do
        let(:abs_foo_path) { File.join(root, 'lib', 'foo.rb') }
        let(:abs_bar_path) { File.join(root, 'lib', 'bar.rb') }

        before do
          # Simulate a resultset with collisions for multiple files
          coverage_data = {
            'lib/foo.rb' => { 'lines' => [1, 0] },
            abs_foo_path => { 'lines' => [1, 1] },
            'lib/bar.rb' => { 'lines' => [2, 0] },
            abs_bar_path => { 'lines' => [2, 2] }
          }
          mock_resultset_with_timestamp(root, FIXTURE_COVERAGE_TIMESTAMP, coverage: coverage_data)
        end

        it 'raises CoverageDataError listing all collisions' do
          expect do
            repo
          end.to raise_error(CovLoupe::CoverageDataError) do |error|
            # Verify both files appear in the error message
            expect(error.message).to include('lib/foo.rb')
            expect(error.message).to include('lib/bar.rb')
          end
        end

        it 'formats error message as parseable JSON with normalized paths and original keys' do
          expect do
            repo
          end.to raise_error(CovLoupe::CoverageDataError) do |error|
            # Verify the error message contains valid JSON
            # Example: "/full/path/lib/foo.rb": ["lib/foo.rb", "/full/path/lib/foo.rb"]
            json_match = error.message.match(/\{.*\}/m)
            expect(json_match).not_to be_nil

            parsed = JSON.parse(json_match[0])
            expect(parsed).to have_key(abs_foo_path)
            expect(parsed).to have_key(abs_bar_path)
            expect(parsed[abs_foo_path]).to include('lib/foo.rb', abs_foo_path)
            expect(parsed[abs_bar_path]).to include('lib/bar.rb', abs_bar_path)
          end
        end
      end
    end
  end
end
