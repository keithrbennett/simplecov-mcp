# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CovLoupe::VERSION' do
  describe 'constant existence' do
    it 'defines a VERSION constant' do
      expect(CovLoupe.const_defined?(:VERSION)).to be true
    end

    it 'exposes VERSION as a non-empty string' do
      expect(CovLoupe::VERSION).to be_a(String)
      expect(CovLoupe::VERSION).not_to be_empty
    end

    it 'is frozen (immutable)' do
      expect(CovLoupe::VERSION).to be_frozen
    end
  end

  describe 'semantic versioning compliance' do
    let(:version) { CovLoupe::VERSION }
    # Simplified semantic versioning regex
    # Preserves key semver rules: no leading zeros on numeric parts, optional prerelease/build metadata
    let(:semver_regex) do
      %r{\A
        (?<major>0|[1-9]\d*)\.
        (?<minor>0|[1-9]\d*)\.
        (?<patch>0|[1-9]\d*)
        (?:[.-](?<prerelease>[0-9A-Za-z.-]+))?
        (?:\+(?<buildmetadata>[0-9A-Za-z.-]+))?
      \z}x
    end

    it 'follows semantic versioning format (accepting hyphen or dot pre-release separator)' do
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
      let(:prerelease_version) { '9.9.9-rc.1' }

      before do
        stub_const('CovLoupe::VERSION', prerelease_version)
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
      let(:build_metadata_version) { '9.9.9+build.42' }

      before do
        stub_const('CovLoupe::VERSION', build_metadata_version)
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
      expect { CovLoupe::VERSION }.not_to raise_error
    end

    it 'matches the version referenced in gemspec' do
      gemspec_path = File.expand_path('../cov-loupe.gemspec', __dir__)
      gemspec_content = File.read(gemspec_path)

      version_line = gemspec_content.lines.find { |line| line.include?('spec.version') }
      expect(version_line).not_to be_nil, 'Could not find version line in gemspec'
      expect(version_line).to include('CovLoupe::VERSION')
    end
  end

  describe 'current version sanity check' do
    it 'is not the initial 0.0.0 version' do
      # Ensure this is a real release, not an uninitialized version
      expect(CovLoupe::VERSION).not_to eq('0.0.0')
    end
  end

  describe 'standalone version file load' do
    it 'defines the module and VERSION constant when only version.rb is loaded' do
      original_version = CovLoupe::VERSION

      stub_const('CovLoupe', Module.new do
        class << self
          attr_accessor :default_log_file, :active_log_file
        end
      end)

      version_path = File.expand_path('../lib/cov_loupe/version.rb', __dir__)
      load version_path

      expect(Object.const_defined?(:CovLoupe)).to be true
      expect(CovLoupe::VERSION).to eq(original_version)
    end
  end
end
