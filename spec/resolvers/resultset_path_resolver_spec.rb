# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe SimpleCovMcp::Resolvers::ResultsetPathResolver do
  describe '#find_resultset' do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmp_root = dir
        example.run
      end
    end

    let(:root) { @tmp_root }
    let(:resolver) { described_class.new(root: root) }

    it 'raises when a specified resultset file cannot be found' do
      expect do
        resolver.find_resultset(resultset: 'missing.json')
      end.to raise_error(RuntimeError, /Specified resultset not found/)
    end

    it 'raises when a specified directory does not contain .resultset.json' do
      nested_dir = File.join(root, 'coverage')
      Dir.mkdir(nested_dir)

      expect do
        resolver.find_resultset(resultset: nested_dir)
      end.to raise_error(RuntimeError, /No .resultset.json found in directory/)
    end

    it 'returns the resolved path when a valid resultset file is provided' do
      file = File.join(root, 'custom.json')
      File.write(file, '{}')

      expect(resolver.find_resultset(resultset: file)).to eq(file)
    end

    it 'raises a helpful error when no fallback candidates are found' do
      expect do
        resolver.find_resultset
      end.to raise_error(RuntimeError, /Could not find .resultset.json/)
    end

    it 'accepts a resultset path already nested under the provided root without double-prefixing' do
      project_root = (FIXTURES_DIR / 'project1').to_s
      resolver = described_class.new(root: project_root)

      resolved = resolver.find_resultset(resultset: 'spec/fixtures/project1/coverage')

      expect(resolved).to eq(File.join(project_root, 'coverage', '.resultset.json'))
    end
  end
end
