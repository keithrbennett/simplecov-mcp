# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe CovLoupe::Resolvers::ResolverHelpers do
  describe '.create_resultset_resolver' do
    it 'uses provided candidates when present' do
      custom_candidates = ['alt/.resultset.json']
      resolver = described_class.create_resultset_resolver(
        root: '/tmp/sample',
        candidates: custom_candidates
      )

      expect(resolver).to be_a(CovLoupe::Resolvers::ResultsetPathResolver)
      expect(resolver.instance_variable_get(:@root)).to eq('/tmp/sample')
      expect(resolver.instance_variable_get(:@candidates)).to eq(custom_candidates)
    end

    it 'falls back to default candidates when none provided' do
      resolver = described_class.create_resultset_resolver(root: '/tmp/sample')

      expect(resolver.instance_variable_get(:@candidates)).to eq(
        CovLoupe::Resolvers::ResultsetPathResolver::DEFAULT_CANDIDATES
      )
    end
  end

  describe '.create_coverage_resolver' do
    it 'wraps coverage data in a CoverageLineResolver' do
      cov = { '/tmp/foo.rb' => { 'lines' => [1, 0] } }
      resolver = described_class.create_coverage_resolver(
        cov, root: '/tmp', volume_case_sensitive: true)

      expect(resolver).to be_a(CovLoupe::Resolvers::CoverageLineResolver)
      expect(resolver.lookup_lines('/tmp/foo.rb')).to eq([1, 0])
    end
  end

  describe '.find_resultset' do
    it 'locates default resultset within the provided root' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        File.write(resultset_path, '{}')

        resolved = described_class.find_resultset(dir)

        expect(resolved).to eq(resultset_path)
      end
    end
  end

  describe '.lookup_lines' do
    it 'delegates to CoverageLineResolver for lookups' do
      cov = { '/tmp/bar.rb' => { 'lines' => [0, 1] } }

      expect(
        described_class.lookup_lines(cov, '/tmp/bar.rb', root: '/tmp', volume_case_sensitive: true)
      ).to eq([0, 1])
    end

    it 'passes root parameter to CoverageLineResolver' do
      cov = { 'lib/foo.rb' => { 'lines' => [1, 1] } }
      root = '/my/root'
      abs_path = '/my/root/lib/foo.rb'

      # If root is passed, it should find it via stripping root
      expect(
        described_class.lookup_lines(cov, abs_path, root: root, volume_case_sensitive: true)
      ).to eq([1, 1])
    end
  end

  describe '.volume_case_sensitive?' do
    let(:test_dir) { Dir.mktmpdir("cov_loupe_volume_test_#{SecureRandom.hex(4)}") }

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'returns a boolean value' do
      result = described_class.volume_case_sensitive?(test_dir)
      expect([true, false].include?(result)).to be(true)
    end

    it 'returns consistent results when called multiple times' do
      # Write 2 files whose names differ only in case in the temporary test directory
      %w[SampleFile.txt sAMPLEfILE.TXT]
        .map { |filename| File.join(test_dir, filename) }
        .each { |filespec| FileUtils.touch(filespec) }

      test_count = 3
      results = Array.new(test_count) { described_class.volume_case_sensitive?(test_dir) }
      expect(results.size).to eq(test_count)
      expect(results.uniq.size).to eq(1) # All results should be identical
    end

    [true, false].each do |identical|
      expected_state_str = identical ? 'identical' : 'different'
      it "returns #{!identical} when case-variant files exist and are #{expected_state_str}" do
        abs_path = File.absolute_path(test_dir)
        original = File.join(abs_path, 'SampleFile.txt')
        alternate = original.tr('A-Za-z', 'a-zA-Z')

        # Force the "existing file" branch without relying on OS case behavior.
        allow(Dir).to receive(:children) do |path, *_opts|
          path == abs_path ? [File.basename(original)] : []
        end
        allow(File).to receive(:file?) { |path| path == original }
        # Simulate a case-variant path that exists so we hit the identical? check.
        allow(File).to receive(:exist?) { |path| path == alternate }
        # Drive the outcome by controlling whether the two paths refer to the same file.
        allow(File).to receive(:identical?).and_return(identical)

        expect(described_class.volume_case_sensitive?(test_dir)).to be(!identical)
      end
    end
  end
end
