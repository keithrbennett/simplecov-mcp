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

  describe 'MCP_RESOURCE_MAP' do
    subject(:result) { described_class::MCP_RESOURCE_MAP }

    it 'includes remote resource URLs' do
      expect(result).to include(
        'public_repo' => 'https://github.com/keithrbennett/cov-loupe',
        'public_doc_server' => 'https://keithrbennett.github.io/cov-loupe/'
      )
    end

    it 'includes a local_readme key pointing to an existing file' do
      expect(result['local_readme']).to end_with('README.md')
      expect(File.exist?(result['local_readme'])).to be true
    end
  end
end
