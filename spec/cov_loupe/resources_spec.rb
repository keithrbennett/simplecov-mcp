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

  describe '.resolve_gem_root' do
    it 'calculates gem root from lib/cov_loupe/cli.rb' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe'
      result = described_class.resolve_gem_root(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe')
    end

    it 'calculates gem root from lib/cov_loupe/config/option_parser_builder.rb' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe/config'
      result = described_class.resolve_gem_root(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe')
    end

    it 'calculates gem root from lib/cov_loupe/tools/help_tool.rb' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe/tools'
      result = described_class.resolve_gem_root(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe')
    end

    it 'calculates gem root from installed gem path' do
      dir_path = '/home/user/.rvm/gems/ruby-3.4.8/gems/cov-loupe-4.0.0/lib/cov_loupe'
      result = described_class.resolve_gem_root(dir_path)
      expect(result).to eq('/home/user/.rvm/gems/ruby-3.4.8/gems/cov-loupe-4.0.0')
    end

    it 'returns from_dir unchanged when no lib directory found' do
      dir_path = '/some/other/path'
      result = described_class.resolve_gem_root(dir_path)
      expect(result).to eq(dir_path)
    end
  end

  describe '.local_docs_path' do
    it 'returns full markdown glob from cli directory' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe'
      result = described_class.local_docs_path(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe/**/*.md')
    end

    it 'returns full markdown glob from config directory' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe/config'
      result = described_class.local_docs_path(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe/**/*.md')
    end

    it 'returns full markdown glob from tools directory' do
      dir_path = '/home/kbennett/code/cov-loupe/lib/cov_loupe/tools'
      result = described_class.local_docs_path(dir_path)
      expect(result).to eq('/home/kbennett/code/cov-loupe/**/*.md')
    end

    it 'returns full markdown glob from installed gem' do
      dir_path = '/home/user/.rvm/gems/ruby-3.4.8/gems/cov-loupe-4.0.0/lib/cov_loupe'
      result = described_class.local_docs_path(dir_path)
      expect(result).to eq('/home/user/.rvm/gems/ruby-3.4.8/gems/cov-loupe-4.0.0/**/*.md')
    end
  end
end
