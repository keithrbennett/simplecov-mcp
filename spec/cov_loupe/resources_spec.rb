# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Resources do
  describe '.cli_url_for' do
    {
      'repository' => 'https://github.com/keithrbennett/cov-loupe',
      'repo'       => 'https://github.com/keithrbennett/cov-loupe',
      'docs'       => 'https://keithrbennett.github.io/cov-loupe/',
      'docs-web'   => 'https://keithrbennett.github.io/cov-loupe/'
    }.each do |name, expected_url|
      it "returns correct URL for '#{name}'" do
        expect(described_class.cli_url_for(name)).to eq(expected_url)
      end
    end

    it 'raises error for unknown resource' do
      expect { described_class.cli_url_for('unknown') }.to raise_error(CovLoupe::UsageError, /Unknown resource/)
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
