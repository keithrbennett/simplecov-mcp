# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/glob_utils'

RSpec.describe CovLoupe::GlobUtils do
  describe '.normalize_patterns' do
    it 'converts patterns to strings' do
      expect(described_class.normalize_patterns([123])).to eq(['123'])
    end

    it 'removes nil patterns' do
      expect(described_class.normalize_patterns(['a', nil, 'b'])).to eq(%w[a b])
    end

    it 'removes empty patterns' do
      expect(described_class.normalize_patterns(['a', '', 'b'])).to eq(%w[a b])
    end

    it 'handles single string input' do
      expect(described_class.normalize_patterns('foo')).to eq(['foo'])
    end

    it 'handles nil input' do
      expect(described_class.normalize_patterns(nil)).to eq([])
    end
  end

  describe '.absolutize_pattern' do
    it 'returns absolute path for a relative pattern' do
      expect(described_class.absolutize_pattern('lib/*.rb', '/root')).to eq('/root/lib/*.rb')
    end

    it 'returns the pattern itself if it is already absolute' do
      expect(described_class.absolutize_pattern('/tmp/*.rb', '/root')).to eq('/tmp/*.rb')
    end
  end

  describe '.matches_any_pattern?' do
    it 'returns true if path matches one of the patterns' do
      patterns = ['/root/lib/*.rb', '/root/spec/*.rb']
      expect(described_class.matches_any_pattern?('/root/lib/foo.rb', patterns)).to be true
    end

    it 'returns false if path does not match any pattern' do
      patterns = ['/root/lib/*.rb']
      expect(described_class.matches_any_pattern?('/root/spec/foo_spec.rb', patterns)).to be false
    end

    it 'supports extglob' do
      # Example: matches either .rb or .erb
      patterns = ['/root/lib/*.{rb,erb}']
      expect(described_class.matches_any_pattern?('/root/lib/view.erb', patterns)).to be true
    end

    it 'supports recursive matching (**)' do
      patterns = ['/root/**/*.rb']
      expect(described_class.matches_any_pattern?('/root/lib/deeply/nested/file.rb',
        patterns)).to be true
    end

    it 'respects directory boundaries with * (does not cross directories)' do
      patterns = ['/root/lib/*.rb']
      expect(described_class.matches_any_pattern?('/root/lib/subdir/file.rb', patterns)).to be false
    end

    it 'supports character sets ([...])' do
      patterns = ['/root/file[1-9].rb']
      expect(described_class.matches_any_pattern?('/root/file5.rb', patterns)).to be true
      expect(described_class.matches_any_pattern?('/root/fileA.rb', patterns)).to be false
    end

    it 'supports single character wildcard (?)' do
      patterns = ['/root/test?.rb']
      expect(described_class.matches_any_pattern?('/root/test1.rb', patterns)).to be true
      expect(described_class.matches_any_pattern?('/root/test12.rb', patterns)).to be false
    end

    it 'does not match dotfiles with * by default' do
      patterns = ['/root/*']
      expect(described_class.matches_any_pattern?('/root/.hidden', patterns)).to be false
    end
  end

  describe '.filter_by_pattern' do
    let(:items) do
      [
        { 'file' => '/root/lib/foo.rb' },
        { 'file' => '/root/spec/foo_spec.rb' },
        { 'file' => '/root/lib/bar.rb' }
      ]
    end

    it 'returns all items if patterns is nil' do
      expect(described_class.filter_by_pattern(items, nil)).to eq(items)
    end

    it 'returns all items if patterns is empty' do
      expect(described_class.filter_by_pattern(items, [])).to eq(items)
    end

    it 'filters items matching the patterns' do
      patterns = ['/root/lib/*.rb']
      result = described_class.filter_by_pattern(items, patterns)
      expect(result).to contain_exactly(
        { 'file' => '/root/lib/foo.rb' },
        { 'file' => '/root/lib/bar.rb' }
      )
    end

    it 'allows specifying a custom key for file path' do
      custom_items = [
        { 'path' => '/root/lib/foo.rb' },
        { 'path' => '/root/spec/foo_spec.rb' }
      ]
      patterns = ['/root/lib/*.rb']
      result = described_class.filter_by_pattern(custom_items, patterns, key: 'path')
      expect(result).to contain_exactly({ 'path' => '/root/lib/foo.rb' })
    end
  end
end
