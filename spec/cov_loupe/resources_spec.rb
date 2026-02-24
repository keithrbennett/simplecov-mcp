# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Resources do
  describe '.url_for' do
    it 'returns repository URL for repository' do
      expect(described_class.url_for('repository')).to eq('https://github.com/keithrbennett/cov-loupe')
    end

    it 'returns repository URL for repo' do
      expect(described_class.url_for('repo')).to eq('https://github.com/keithrbennett/cov-loupe')
    end

    it 'returns documentation web URL for docs' do
      expect(described_class.url_for('docs')).to eq('https://keithrbennett.github.io/cov-loupe/')
    end

    it 'returns documentation web URL for docs-web' do
      expect(described_class.url_for('docs-web')).to eq('https://keithrbennett.github.io/cov-loupe/')
    end

    it 'raises error for unknown resource' do
      expect do
        described_class.url_for('unknown')
      end.to raise_error(CovLoupe::UsageError, /Unknown resource/)
    end
  end

  describe '.all' do
    it 'returns all resources' do
      expect(described_class.all).to eq({
        'repository' => 'https://github.com/keithrbennett/cov-loupe',
        'documentation_web' => 'https://keithrbennett.github.io/cov-loupe/'
      })
    end
  end

  describe 'LOCAL_README_PATH' do
    it 'ends with README.md' do
      expect(described_class::LOCAL_README_PATH).to end_with('README.md')
    end

    it 'points to an existing file' do
      expect(File.exist?(described_class::LOCAL_README_PATH)).to be true
    end
  end

  describe '.all_with_local' do
    subject(:result) { described_class.all_with_local }

    it 'includes repository and documentation_web keys from .all' do
      expect(result).to include(described_class.all)
    end

    it 'includes a readme key pointing to an existing file' do
      expect(result['readme']).to end_with('README.md')
      expect(File.exist?(result['readme'])).to be true
    end
  end
end
