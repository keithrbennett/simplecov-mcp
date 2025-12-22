# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe CovLoupe::Resolvers::ResultsetPathResolver do
  describe '#find_resultset' do
    let(:root) { Dir.mktmpdir }
    let(:resolver) { described_class.new(root: root) }

    after do
      FileUtils.remove_entry(root) if root && Dir.exist?(root)
    end

    it 'raises when a specified resultset file cannot be found' do
      expect do
        resolver.find_resultset(resultset: 'missing.json')
      end.to raise_error(CovLoupe::ResultsetNotFoundError, /Specified resultset not found/)
    end

    it 'raises when a specified directory does not contain .resultset.json' do
      nested_dir = File.join(root, 'coverage')
      Dir.mkdir(nested_dir)

      expect do
        resolver.find_resultset(resultset: nested_dir)
      end.to raise_error(CovLoupe::ResultsetNotFoundError, /No .resultset.json found in directory/)
    end

    it 'returns the resolved path when a valid resultset file is provided' do
      file = File.join(root, 'custom.json')
      File.write(file, '{}')

      expect(resolver.find_resultset(resultset: file)).to eq(file)
    end

    it 'locates .resultset.json inside a provided directory' do
      Dir.mktmpdir do |dir|
        nested = File.join(dir, 'coverage')
        FileUtils.mkdir_p(nested)
        File.write(File.join(nested, '.resultset.json'), '{}')

        resolver = described_class.new(root: dir)
        expect(resolver.find_resultset(resultset: nested))
          .to eq(File.join(nested, '.resultset.json'))
      end
    end

    it 'raises a helpful error when no fallback candidates are found' do
      expect do
        resolver.find_resultset
      end.to raise_error(CovLoupe::ResultsetNotFoundError, /Could not find .resultset.json/)
    end

    it 'accepts a resultset path already nested under the provided root without double-prefixing' do
      project_root = (FIXTURES_DIR / 'project1').to_s
      resolver = described_class.new(root: project_root)

      resolved = resolver.find_resultset(resultset: 'spec/fixtures/project1/coverage')

      expect(resolved).to eq(File.join(project_root, 'coverage', '.resultset.json'))
    end

    it 'raises when relative resultset is ambiguous between root and Dir.pwd' do
      FileUtils.mkdir_p(File.join(root, 'coverage'))
      File.write(File.join(root, 'coverage', '.resultset.json'), '{}')

      Dir.mktmpdir do |pwd|
        FileUtils.mkdir_p(File.join(pwd, 'coverage'))
        File.write(File.join(pwd, 'coverage', '.resultset.json'), '{}')

        Dir.chdir(pwd) do
          expect do
            resolver.find_resultset(resultset: 'coverage')
          end.to raise_error(CovLoupe::ConfigurationError, /Ambiguous resultset location specified/)
        end
      end
    end

    it 'prefers the root candidate when the Dir.pwd candidate is missing' do
      FileUtils.mkdir_p(File.join(root, 'coverage'))
      File.write(File.join(root, 'coverage', '.resultset.json'), '{}')

      Dir.mktmpdir do |pwd|
        Dir.chdir(pwd) do
          resolved = resolver.find_resultset(resultset: 'coverage')
          expect(resolved).to eq(File.join(root, 'coverage', '.resultset.json'))
        end
      end
    end

    # In non-strict mode, resolve_candidate returns nil instead of raising
    # when the path doesn't exist, allowing fallback resolution to continue.
    it 'returns nil for non-existent path in non-strict mode' do
      result = resolver.send(:resolve_candidate, '/nonexistent/path.json', strict: false)
      expect(result).to be_nil
    end
  end
end
