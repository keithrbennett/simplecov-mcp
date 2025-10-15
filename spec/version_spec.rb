# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SimpleCovMcp::VERSION' do
  describe 'constant existence' do
    it 'defines a VERSION constant' do
      expect(SimpleCovMcp.const_defined?(:VERSION)).to be true
    end

    it 'exposes VERSION as a non-empty string' do
      expect(SimpleCovMcp::VERSION).to be_a(String)
      expect(SimpleCovMcp::VERSION).not_to be_empty
    end

    it 'is frozen (immutable)' do
      expect(SimpleCovMcp::VERSION).to be_frozen
    end
  end

  describe 'semantic versioning compliance' do
    let(:version) { SimpleCovMcp::VERSION }
    # Semantic Versioning 2.0.0 specification regex from https://semver.org/
    let(:semver_regex) do
      /\A(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?\z/
    end

    it 'follows semantic versioning format' do
      expect(version).to match(semver_regex)
    end

    it 'has valid major.minor.patch core version' do
      match = version.match(semver_regex)
      expect(match).not_to be_nil, "VERSION '#{version}' does not match semantic versioning format"

      major = match[:major].to_i
      minor = match[:minor].to_i
      patch = match[:patch].to_i

      expect(major).to be >= 0
      expect(minor).to be >= 0
      expect(patch).to be >= 0
    end

    context 'when version has prerelease identifier' do
      before do
        skip unless version.include?('-')
      end

      it 'has valid prerelease format' do
        match = version.match(semver_regex)
        prerelease = match[:prerelease]
        expect(prerelease).not_to be_empty
        expect(prerelease).not_to start_with('.')
        expect(prerelease).not_to end_with('.')
      end
    end

    context 'when version has build metadata' do
      before do
        skip unless version.include?('+')
      end

      it 'has valid build metadata format' do
        match = version.match(semver_regex)
        buildmetadata = match[:buildmetadata]
        expect(buildmetadata).not_to be_empty
        expect(buildmetadata).to match(/\A[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*\z/)
      end
    end
  end

  describe 'version consistency' do
    it 'is accessible via require path' do
      expect { SimpleCovMcp::VERSION }.not_to raise_error
    end

    it 'matches the version referenced in gemspec' do
      gemspec_path = File.expand_path('../simplecov-mcp.gemspec', __dir__)
      gemspec_content = File.read(gemspec_path)

      version_line = gemspec_content.lines.find { |line| line.include?('spec.version') }
      expect(version_line).not_to be_nil, 'Could not find version line in gemspec'
      expect(version_line).to include('SimpleCovMcp::VERSION')
    end
  end

  describe 'current version sanity check' do
    it 'is not the initial 0.0.0 version' do
      # Ensure this is a real release, not an uninitialized version
      expect(SimpleCovMcp::VERSION).not_to eq('0.0.0')
    end
  end

  describe 'standalone version file load' do
    it 'defines the module and VERSION constant when only version.rb is loaded' do
      original_module = SimpleCovMcp
      original_version = SimpleCovMcp::VERSION

      Object.send(:remove_const, :SimpleCovMcp)

      version_path = File.expand_path('../lib/simplecov_mcp/version.rb', __dir__)
      load version_path

      expect(Object.const_defined?(:SimpleCovMcp)).to be true
      expect(SimpleCovMcp::VERSION).to eq(original_version)
    ensure
      Object.send(:remove_const, :SimpleCovMcp) if Object.const_defined?(:SimpleCovMcp)
      Object.const_set(:SimpleCovMcp, original_module)
    end
  end
end
