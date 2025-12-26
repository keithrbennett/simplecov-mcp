# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Resolvers::CoverageLineResolver do
  describe '#lookup_lines' do
    let(:root) { '/project' }

    context 'with direct path matching' do
      it 'returns lines array for exact path match' do
        abs_path = '/project/lib/foo.rb'
        cov_data = {
          abs_path => { 'lines' => [1, 0, nil, 2] }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, nil, 2])
      end

      it 'returns lines array when entry has lines directly' do
        path = '/tmp/test.rb'
        cov_data = {
          path => { 'lines' => [1, 1, 1] }
        }

        resolver = described_class.new(cov_data, root: root)
        expect(resolver.lookup_lines(path)).to eq([1, 1, 1])
      end
    end

    context 'with root stripping fallback' do
      it 'finds relative path when absolute path includes root' do
        root = '/project'
        relative_path = 'lib/bar.rb'
        abs_path = File.join(root, relative_path)
        cov_data = {
          relative_path => { 'lines' => [1, 0, 1] }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, 1])
      end

      it 'matches via basename fallback when absolute path does not start with root' do
        cov_data = {
          'lib/baz.rb' => { 'lines' => [1, 1] }
        }

        resolver = described_class.new(cov_data, root: root)

        # Previously this raised FileError because stripping logic failed.
        # Now it should match via basename fallback.
        expect(resolver.lookup_lines('/other/directory/lib/baz.rb')).to eq([1, 1])
      end
    end

    context 'when handling errors' do
      it 'raises FileError when file is not found in coverage data' do
        cov_data = {
          '/project/lib/foo.rb' => { 'lines' => [1, 0] }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines('/project/lib/missing.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'raises FileError when coverage data is empty' do
        resolver = described_class.new({}, root: root)

        expect do
          resolver.lookup_lines('/any/path.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'raises CorruptCoverageDataError when entry exists but has no valid lines' do
        cov_data = {
          '/project/lib/foo.rb' => { 'other_key' => 'value' }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines('/project/lib/foo.rb')
        end.to raise_error(CovLoupe::CorruptCoverageDataError,
          /Entry for .* has no valid lines/)
      end

      it 'raises CorruptCoverageDataError for branch-only coverage (no lines array)' do
        cov_data = {
          '/project/lib/branch_only.rb' => {
            'branches' => { '[:if, 0, 1, 0, 1, 4]' => { '[:then, 1, 1, 0, 1, 4]' => 1 } }
          }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines('/project/lib/branch_only.rb')
        end.to raise_error(CovLoupe::CorruptCoverageDataError,
          /Entry for .* has no valid lines/)
      end
    end

    context 'with platform-specific path normalization' do
      # On Unix: paths are case-sensitive (Foo.rb != foo.rb)
      # On Windows: paths are case-insensitive (Foo.rb == foo.rb) due to filesystem semantics
      it 'applies case-sensitive matching on Unix' do
        skip 'Windows-specific test' if CovLoupe.windows?

        cov_data = {
          '/project/lib/Foo.rb' => { 'lines' => [1, 0] }
        }

        resolver = described_class.new(cov_data, root: root)

        # On Unix, different casing = different file
        expect do
          resolver.lookup_lines('/project/lib/foo.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'applies case-insensitive matching on Windows' do
        skip 'Unix-specific test' unless CovLoupe.windows?

        cov_data = {
          'C:/Project/Lib/Foo.rb' => { 'lines' => [1, 0] }
        }

        resolver = described_class.new(cov_data, root: 'C:/Project')

        # On Windows, different casing = same file
        lines = resolver.lookup_lines('c:/project/lib/foo.rb')
        expect(lines).to eq([1, 0])
      end
    end

    context 'with normalized path resolution edge cases' do
      it 'resolves single normalized match when exact match fails' do
        # Coverage line 106: return match_keys.first if match_keys.length == 1
        # Simulate Windows-like behavior where paths differ only in case/separators
        allow(CovLoupe).to receive(:windows?).and_return(true)

        cov_data = {
          'lib/Foo.rb' => { 'lines' => [1, 2, 3] }
        }

        resolver = described_class.new(cov_data, root: root)

        # Request with different casing - should normalize and find the match
        lines = resolver.lookup_lines('lib/foo.rb')
        expect(lines).to eq([1, 2, 3])
      end

      it 'raises FileError for ambiguous normalized matches' do
        # Coverage line 108: raise FileError when multiple keys normalize to the same path
        # Simulate Windows where 'Foo.rb' and 'foo.rb' both normalize to 'foo.rb'
        allow(CovLoupe).to receive(:windows?).and_return(true)

        cov_data = {
          'lib/Foo.rb' => { 'lines' => [1, 2, 3] },
          'lib/foo.rb' => { 'lines' => [4, 5, 6] }
        }

        resolver = described_class.new(cov_data, root: root)

        # Both keys normalize to the same path on Windows, causing ambiguity
        expect do
          resolver.lookup_lines('lib/FOO.rb')
        end.to raise_error(CovLoupe::FileError, /Multiple coverage entries match path/)
      end
    end

    context 'with Windows path normalization' do
      it 'normalizes backslashes and applies case-folding on Windows' do
        # Coverage line 116: Windows-specific normalizer with backslash conversion and downcase
        allow(CovLoupe).to receive(:windows?).and_return(true)

        cov_data = {
          'lib/utils/Helper.rb' => { 'lines' => [10, 20, 30] }
        }

        resolver = described_class.new(cov_data, root: root)

        # Windows path with backslashes and different casing
        lines = resolver.lookup_lines('lib\\utils\\HELPER.rb')
        expect(lines).to eq([10, 20, 30])
      end

      it 'does not apply Windows normalization on Unix' do
        skip 'Windows-specific test' if CovLoupe.windows?

        cov_data = {
          'lib/Helper.rb' => { 'lines' => [1, 2] }
        }

        resolver = described_class.new(cov_data, root: root)

        # On Unix, backslashes are literal characters in filenames (not separators)
        # and case matters, so this should not match
        expect do
          resolver.lookup_lines('lib\\helper.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end
    end
  end
end
