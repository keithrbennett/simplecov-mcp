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
    let(:pattern_start) { Gem.win_platform? ? /\A[a-zA-Z]:/ : /\A/ }

    it 'returns absolute path for a relative pattern' do
      expect(described_class.absolutize_pattern('lib/*.rb', '/root'))
        .to match(/#{pattern_start}\/root\/lib\/\*\.rb\z/)
    end

    it 'returns the pattern itself if it is already absolute' do
      expect(described_class.absolutize_pattern('/tmp/*.rb', '/root'))
        .to match(/#{pattern_start}\/tmp\/\*\.rb\z/)
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

  describe '.filter_paths' do
    let(:root) { File.expand_path('/project') }
    let(:paths) do
      [
        File.expand_path('/project/lib/foo.rb'),
        File.expand_path('/project/lib/bar.rb'),
        File.expand_path('/project/spec/foo_spec.rb'),
        File.expand_path('/project/spec/bar_spec.rb')
      ]
    end

    it 'returns all paths when globs is nil' do
      expect(described_class.filter_paths(paths, nil, root: root)).to eq(paths)
    end

    it 'returns all paths when globs is empty array' do
      expect(described_class.filter_paths(paths, [], root: root)).to eq(paths)
    end

    it 'filters paths by a single glob pattern' do
      result = described_class.filter_paths(paths, 'lib/*.rb', root: root)
      expect(result).to contain_exactly(
        File.expand_path('/project/lib/foo.rb'),
        File.expand_path('/project/lib/bar.rb')
      )
    end

    it 'filters paths by multiple glob patterns' do
      result = described_class.filter_paths(paths, ['lib/foo.rb', 'spec/*.rb'], root: root)
      expect(result).to contain_exactly(
        File.expand_path('/project/lib/foo.rb'),
        File.expand_path('/project/spec/foo_spec.rb'),
        File.expand_path('/project/spec/bar_spec.rb')
      )
    end

    it 'handles absolute glob patterns' do
      result = described_class.filter_paths(paths,
        File.expand_path('/project/lib/*.rb'), root: root)
      expect(result).to contain_exactly(
        File.expand_path('/project/lib/foo.rb'),
        File.expand_path('/project/lib/bar.rb')
      )
    end

    it 'supports recursive patterns' do
      nested_paths = [
        File.expand_path('/project/lib/utils/helper.rb'),
        File.expand_path('/project/lib/foo.rb'),
        File.expand_path('/project/spec/foo_spec.rb')
      ]
      result = described_class.filter_paths(nested_paths, 'lib/**/*.rb', root: root)
      expect(result).to contain_exactly(
        File.expand_path('/project/lib/utils/helper.rb'),
        File.expand_path('/project/lib/foo.rb')
      )
    end

    it 'returns empty array when no paths match' do
      result = described_class.filter_paths(paths, 'src/*.rb', root: root)
      expect(result).to eq([])
    end
  end
end
