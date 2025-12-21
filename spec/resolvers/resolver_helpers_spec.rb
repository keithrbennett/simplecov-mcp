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
      resolver = described_class.create_coverage_resolver(cov)

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
        described_class.lookup_lines(cov, '/tmp/bar.rb')
      ).to eq([0, 1])
    end
  end
end
