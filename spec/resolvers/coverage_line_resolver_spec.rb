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

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, nil, 2])
      end

      it 'returns lines array when entry has lines directly' do
        path = '/tmp/test.rb'
        cov_data = {
          path => { 'lines' => [1, 1, 1] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)
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

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, 1])
      end

      it 'matches via basename fallback when absolute path does not start with root' do
        cov_data = {
          'lib/baz.rb' => { 'lines' => [1, 1] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

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

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

        expect do
          resolver.lookup_lines('/project/lib/missing.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'raises FileError when coverage data is empty' do
        resolver = described_class.new({}, root: root, volume_case_sensitive: true)

        expect do
          resolver.lookup_lines('/any/path.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'raises CorruptCoverageDataError when entry exists but has no valid lines' do
        cov_data = {
          '/project/lib/foo.rb' => { 'other_key' => 'value' }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

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

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

        expect do
          resolver.lookup_lines('/project/lib/branch_only.rb')
        end.to raise_error(CovLoupe::CorruptCoverageDataError,
          /Entry for .* has no valid lines/)
      end
    end

    context 'with volume-specific path normalization' do
      it 'applies case-sensitive matching when volume_case_sensitive is true' do
        cov_data = {
          '/project/lib/Foo.rb' => { 'lines' => [1, 0] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

        # On case-sensitive volumes, different casing = different file
        expect do
          resolver.lookup_lines('/project/lib/foo.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'applies case-insensitive matching when volume_case_sensitive is false' do
        cov_data = {
          '/project/lib/Foo.rb' => { 'lines' => [1, 0] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: false)

        # On case-insensitive volumes, different casing = same file
        lines = resolver.lookup_lines('/project/lib/foo.rb')
        expect(lines).to eq([1, 0])
      end
    end

    context 'with normalized path resolution edge cases' do
      it 'resolves single normalized match when exact match fails on case-insensitive FS' do
        # Simulate case-insensitive volume behavior
        allow(CovLoupe).to receive(:windows?).and_return(false)

        cov_data = {
          'lib/Foo.rb' => { 'lines' => [1, 2, 3] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: false)

        # Request with different casing - should normalize and find the match
        lines = resolver.lookup_lines('lib/foo.rb')
        expect(lines).to eq([1, 2, 3])
      end

      it 'raises FileError for ambiguous normalized matches on case-insensitive filesystems' do
        # Simulate case-insensitive volume where 'Foo.rb' and 'foo.rb' both normalize to 'foo.rb'
        allow(CovLoupe).to receive(:windows?).and_return(false)

        cov_data = {
          'lib/Foo.rb' => { 'lines' => [1, 2, 3] },
          'lib/foo.rb' => { 'lines' => [4, 5, 6] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: false)

        # Both keys normalize to the same path, causing ambiguity
        expect do
          resolver.lookup_lines('lib/FOO.rb')
        end.to raise_error(CovLoupe::FileError, /Multiple coverage entries match path/)
      end
    end

    context 'with path normalization' do
      it 'normalizes backslashes on Windows' do
        # Windows needs backslash normalization
        allow(CovLoupe).to receive(:windows?).and_return(true)

        cov_data = {
          'lib/utils/Helper.rb' => { 'lines' => [10, 20, 30] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

        # Windows path with backslashes (but case-sensitive volume)
        lines = resolver.lookup_lines('lib\\utils\\Helper.rb')
        expect(lines).to eq([10, 20, 30])
      end

      it 'normalizes both slashes and case on Windows with case-insensitive filesystem' do
        # Windows with case-insensitive volume needs both normalizations
        allow(CovLoupe).to receive(:windows?).and_return(true)

        cov_data = {
          'lib/utils/Helper.rb' => { 'lines' => [10, 20, 30] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: false)

        # Windows path with backslashes and different casing
        lines = resolver.lookup_lines('lib\\utils\\HELPER.rb')
        expect(lines).to eq([10, 20, 30])
      end

      it 'does not normalize on case-sensitive volumes' do
        skip 'Test requires case-sensitive volume' unless CovLoupe::PathUtils.volume_case_sensitive?('.')

        # Ensure no slash normalization either (non-Windows)
        allow(CovLoupe).to receive(:windows?).and_return(false)

        cov_data = {
          'lib/Helper.rb' => { 'lines' => [1, 2] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: true)

        # On case-sensitive volumes, backslashes are literal characters (not separators)
        # and case matters, so this should not match
        expect do
          resolver.lookup_lines('lib\\helper.rb')
        end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
      end

      it 'normalizes case on case-insensitive volumes' do
        skip 'Test requires case-insensitive volume' if CovLoupe::PathUtils.volume_case_sensitive?('.')

        # Ensure no slash normalization (non-Windows)
        allow(CovLoupe).to receive(:windows?).and_return(false)

        cov_data = {
          'lib/Helper.rb' => { 'lines' => [1, 2, 3] }
        }

        resolver = described_class.new(cov_data, root: root, volume_case_sensitive: false)

        # On case-insensitive volumes, different casing should match
        lines = resolver.lookup_lines('lib/helper.rb')
        expect(lines).to eq([1, 2, 3])

        lines = resolver.lookup_lines('lib/HELPER.rb')
        expect(lines).to eq([1, 2, 3])
      end
    end
  end
end
