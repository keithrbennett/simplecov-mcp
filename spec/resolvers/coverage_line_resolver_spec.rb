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
  end
end
