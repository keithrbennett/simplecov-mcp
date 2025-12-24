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

    context 'with separator normalization' do
      it 'matches Windows-style coverage keys against Unix-style lookups' do
        abs_path = '/project/lib/foo.rb'
        cov_data = {
          'C:\\project\\lib\\foo.rb' => { 'lines' => [1, 0, nil, 2] }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, nil, 2])
      end

      it 'matches Unix-style coverage keys against Windows-style lookups' do
        abs_path = 'C:\\project\\lib\\bar.rb'
        cov_data = {
          '/project/lib/bar.rb' => { 'lines' => [1, 0, 1] }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, 1])
      end

      it 'raises when multiple normalized keys match a single lookup' do
        abs_path = 'C:\\project\\lib/dup.rb'
        cov_data = {
          'C:\\project\\lib\\dup.rb' => { 'lines' => [1] },
          'C:/project/lib/dup.rb' => { 'lines' => [0] }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines(abs_path)
        end.to raise_error(CovLoupe::FileError, /Multiple coverage entries match path/)
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

      it 'raises CorruptCoverageDataError when entry exists but has no lines or branches' do
        cov_data = {
          '/project/lib/foo.rb' => { 'other_key' => 'value' }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines('/project/lib/foo.rb')
        end.to raise_error(CovLoupe::CorruptCoverageDataError,
          /Entry for .* has no valid lines or branches/)
      end
    end

    context 'with branch-only coverage synthesis' do
      it 'synthesizes line hits when only branch coverage exists' do
        abs_path = '/tmp/branch_only.rb'
        branch_cov = {
          abs_path => {
            'lines' => nil,
            'branches' => {
              '[:if, 0, 5, 2, 8, 5]' => {
                '[:then, 1, 6, 4, 6, 15]' => 3,
                '[:else, 2, 7, 4, 7, 15]' => 0
              },
              '[:case, 3, 12, 2, 17, 5]' => {
                '[:when, 4, 13, 4, 13, 14]' => 0,
                '[:when, 5, 14, 4, 14, 14]' => 2,
                '[:else, 6, 16, 4, 16, 12]' => 2
              }
            }
          }
        }

        resolver = described_class.new(branch_cov, root: root)
        lines = resolver.lookup_lines(abs_path)

        expect(lines[5]).to eq(3)  # line 6
        expect(lines[6]).to eq(0)  # line 7
        expect(lines[12]).to eq(0) # line 13
        expect(lines[13]).to eq(2) # line 14
        expect(lines[15]).to eq(2) # line 16
        expect(lines.count { |v| !v.nil? }).to eq(5)
      end

      it 'aggregates hits for multiple branches on the same line' do
        path = '/tmp/duplicated.rb'
        branch_cov = {
          path => {
            'lines' => nil,
            'branches' => {
              '[:if, 0, 3, 2, 3, 12]' => {
                '[:then, 1, 3, 2, 3, 12]' => 2,
                '[:else, 2, 3, 2, 3, 12]' => 3
              }
            }
          }
        }

        resolver = described_class.new(branch_cov, root: root)
        lines = resolver.lookup_lines(path)

        expect(lines[2]).to eq(5) # line 3 with summed hits
      end

      it 'handles array-style branch metadata' do
        path = '/tmp/array_style.rb'
        cov_data = {
          path => {
            'lines' => nil,
            'branches' => {
              [:if, 0, 5, 2, 8, 5] => {
                [:then, 1, 6, 4, 6, 15] => 2
              }
            }
          }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(path)

        expect(lines[5]).to eq(2) # line 6
      end

      it 'raises CorruptCoverageDataError for entries with empty branches' do
        path = '/tmp/empty_branches.rb'
        cov_data = {
          path => {
            'lines' => nil,
            'branches' => {}
          }
        }

        resolver = described_class.new(cov_data, root: root)

        expect do
          resolver.lookup_lines(path)
        end.to raise_error(CovLoupe::CorruptCoverageDataError)
      end

      it 'skips malformed branch entries' do
        path = '/tmp/malformed.rb'
        cov_data = {
          path => {
            'lines' => nil,
            'branches' => {
              '[:if, 0, 5, 2, 8, 5]' => {
                '[:then, 1, 6, 4, 6, 15]' => 2
              },
              'malformed_key' => 'not_a_hash',
              '[:if, 1, 10]' => { # missing elements in tuple
                '[:then]' => 1 # also malformed
              }
            }
          }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(path)

        # Should still get line 6 from the valid branch
        expect(lines[5]).to eq(2)
      end
    end

    context 'with extract_line_number edge cases' do
      let(:resolver) { described_class.new({}, root: root) }

      it 'extracts line number from array metadata' do
        result = resolver.send(:extract_line_number, [:if, 0, 10, 2, 15, 5])
        expect(result).to eq(10)
      end

      it 'extracts line number from stringified array metadata' do
        result = resolver.send(:extract_line_number, '[:if, 0, 15, 2, 20, 5]')
        expect(result).to eq(15)
      end

      it 'returns nil for short array' do
        result = resolver.send(:extract_line_number, [:if, 0])
        expect(result).to be_nil
      end

      it 'returns nil for short string' do
        result = resolver.send(:extract_line_number, '[:if, 0]')
        expect(result).to be_nil
      end

      it 'returns nil for non-numeric line element in array' do
        result = resolver.send(:extract_line_number, [:if, 0, 'not_a_number', 2])
        expect(result).to be_nil
      end

      it 'returns nil for non-numeric line element in string' do
        result = resolver.send(:extract_line_number, '[:if, 0, abc, 2]')
        expect(result).to be_nil
      end

      it 'handles empty string' do
        result = resolver.send(:extract_line_number, '')
        expect(result).to be_nil
      end

      it 'handles nil input' do
        result = resolver.send(:extract_line_number, nil)
        expect(result).to be_nil
      end

      # The rescue block catches ArgumentError/TypeError from malformed metadata
      # that can't be converted to line numbers.
      [ArgumentError, TypeError].each do |error_class|
        it "returns nil when string operations raise #{error_class}" do
          weird_object = Object.new
          allow(weird_object).to receive(:to_s).and_raise(error_class, 'test error')

          result = resolver.send(:extract_line_number, weird_object)
          expect(result).to be_nil
        end
      end
    end

    context 'with preference for lines over branches' do
      it 'prefers lines array when both lines and branches exist' do
        path = '/tmp/both.rb'
        cov_data = {
          path => {
            'lines' => [1, 2, 3],
            'branches' => {
              '[:if, 0, 100, 2, 105, 5]' => {
                '[:then, 1, 101, 4, 101, 15]' => 99
              }
            }
          }
        }

        resolver = described_class.new(cov_data, root: root)
        lines = resolver.lookup_lines(path)

        # Should return the lines array, not synthesized branch data
        expect(lines).to eq([1, 2, 3])
      end
    end
  end
end
