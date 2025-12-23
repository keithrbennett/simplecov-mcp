# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Resolvers::CoverageLineResolver do
  describe '#lookup_lines extended' do
    context 'with basename fallback' do
      it 'finds coverage data when only basename matches' do
        abs_path = '/project/lib/foo.rb'
        # Data is stored under a different path but same filename
        cov_data = {
          '/other/path/foo.rb' => { 'lines' => [1, 0, 1] }
        }

        resolver = described_class.new(cov_data)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 0, 1])
      end

      it 'prioritizes exact match over basename match' do
        abs_path = '/project/lib/foo.rb'
        cov_data = {
          '/project/lib/foo.rb' => { 'lines' => [1, 1, 1] },
          '/other/path/foo.rb' => { 'lines' => [0, 0, 0] }
        }

        resolver = described_class.new(cov_data)
        lines = resolver.lookup_lines(abs_path)

        expect(lines).to eq([1, 1, 1])
      end

      it 'raises error if multiple files match the basename (ambiguous)' do
        abs_path = '/project/lib/common.rb'
        cov_data = {
          '/path/a/common.rb' => { 'lines' => [1] },
          '/path/b/common.rb' => { 'lines' => [2] }
        }

        resolver = described_class.new(cov_data)
        expect do
          resolver.lookup_lines(abs_path)
        end.to raise_error(CovLoupe::FileError, /Multiple coverage entries match basename/)
      end
    end

    context 'with configured root' do
      it 'uses configured root for relative path resolution' do
        root = '/custom/root'
        relative_path = 'lib/bar.rb'
        abs_path = File.join(root, relative_path)

        cov_data = {
          relative_path => { 'lines' => [1, 0] }
        }

        # We expect to pass root to the initializer
        # This will fail initially because initialize doesn't accept root yet
        resolver = described_class.new(cov_data, root: root)

        # We need to stub Dir.pwd to ensure it's NOT using that
        allow(Dir).to receive(:pwd).and_return('/wrong/place')

        lines = resolver.lookup_lines(abs_path)
        expect(lines).to eq([1, 0])
      end
    end
  end
end
