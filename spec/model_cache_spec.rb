# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/model_cache'
require 'cov_loupe/model'

RSpec.describe CovLoupe::ModelCache do
  let(:cache) { described_class.new }
  let(:project1_root) { (FIXTURES_DIR / 'project1').to_s }
  let(:project1_resultset) { FIXTURE_PROJECT1_RESULTSET_PATH }
  let(:config) { { root: project1_root, resultset: project1_resultset } }
  let(:model) { CovLoupe::CoverageModel.new(**config) }

  def build_stat(mtime:, mtime_nsec: nil, size: 0, inode: 0)
    stat = double('File::Stat', mtime: mtime, size: size, ino: inode)
    return stat unless mtime_nsec

    allow(stat).to receive(:mtime_nsec).and_return(mtime_nsec)
    stat
  end

  def stub_unchanged_stat(path)
    stat = build_stat(mtime: Time.at(100), mtime_nsec: 0, size: 10, inode: 1)
    allow(File).to receive(:stat).with(path).and_return(stat)
  end

  def stub_digest(path, *digests)
    allow(Digest::MD5).to receive(:file).with(path)
      .and_return(*digests.map { |d| double(hexdigest: d) })
  end

  def expect_cache_invalidation
    cache.store(config, model)
    expect(cache.fetch(config)).to eq(model)
    expect(cache.fetch(config)).to be_nil
  end

  describe '#fetch and #store' do
    it 'caches models by both root and resultset path' do
      # Use a temporary directory as a different root with same resultset
      Dir.mktmpdir('cache_test') do |temp_dir|
        config1 = { root: project1_root, resultset: project1_resultset }
        config2 = { root: temp_dir, resultset: project1_resultset }

        model1 = CovLoupe::CoverageModel.new(**config1)
        model2 = CovLoupe::CoverageModel.new(**config2)

        # Store models with different roots but same resultset
        cache.store(config1, model1)
        cache.store(config2, model2)

        # Verify each config retrieves its own model
        expect(cache.fetch(config1)).to eq(model1)
        expect(cache.fetch(config2)).to eq(model2)
        expect(cache.fetch(config1)).not_to eq(model2)
      end
    end

    it 'returns the same model for identical config' do
      cache.store(config, model)
      expect(cache.fetch(config)).to eq(model)
      expect(cache.fetch(config)).to eq(model)
    end

    it 'returns nil for config that has not been cached' do
      expect(cache.fetch(config)).to be_nil
    end

    it 'invalidates cache when resultset mtime changes' do
      stat_now = build_stat(mtime: Time.at(100), size: 10, inode: 1)
      stat_later = build_stat(mtime: Time.at(200), size: 10, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_now, stat_later)

      expect_cache_invalidation
    end

    it 'detects subsecond mtime changes' do
      base_time = Time.at(100)
      stat_now = build_stat(mtime: base_time, mtime_nsec: 0, size: 10, inode: 1)
      stat_subsecond = build_stat(mtime: base_time, mtime_nsec: 1_000_000, size: 10, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_now, stat_subsecond)

      expect_cache_invalidation
    end

    it 'invalidates cache when size changes within the same second' do
      base_time = Time.at(100)
      stat_now = build_stat(mtime: base_time, mtime_nsec: 0, size: 10, inode: 1)
      stat_size_change = build_stat(mtime: base_time, mtime_nsec: 0, size: 11, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_now, stat_size_change)

      expect_cache_invalidation
    end

    it 'does not raise if the resultset disappears between calls' do
      allow(File).to receive(:stat).with(project1_resultset).and_raise(Errno::ENOENT)

      expect(cache.store(config, model)).to eq(model)
      expect(cache.fetch(config)).to be_nil
    end

    it 'invalidates cache when content changes but metadata is identical' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'digest_v1', 'digest_v1', 'digest_v2')

      expect_cache_invalidation
    end

    it 'validates digest on every fetch' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'unchanged', 'unchanged', 'unchanged')

      cache.store(config, model)
      expect(cache.fetch(config)).to eq(model)
    end

    it 'handles digest computation failures gracefully on store' do
      allow(Digest::MD5).to receive(:file).with(project1_resultset).and_raise(Errno::ENOENT)

      expect(cache.store(config, model)).to eq(model)
      expect(cache.fetch(config)).to be_nil
    end

    it 'handles digest computation failures gracefully on fetch' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'valid', 'valid')

      cache.store(config, model)
      allow(Digest::MD5).to receive(:file).with(project1_resultset).and_raise(Errno::EACCES)
      expect(cache.fetch(config)).to be_nil
    end

    it 'handles absolute and relative root paths consistently' do
      # Both should resolve to the same absolute path and cache key
      config_absolute = { root: File.absolute_path(project1_root), resultset: project1_resultset }
      config_relative = { root: project1_root, resultset: project1_resultset }

      model = CovLoupe::CoverageModel.new(**config_absolute)
      cache.store(config_absolute, model)

      # Should retrieve the same model regardless of absolute vs relative root
      expect(cache.fetch(config_relative)).to eq(model)
    end

    it 'treats nil and "." as the current directory consistently' do
      config_nil = { root: nil, resultset: project1_resultset }
      config_dot = { root: '.', resultset: project1_resultset }

      model = CovLoupe::CoverageModel.new(root: '.', resultset: project1_resultset)
      cache.store(config_nil, model)

      # Both should map to the same cache entry
      expect(cache.fetch(config_dot)).to eq(model)
    end
  end

  describe 'prevents incorrect root-sensitive behavior (bug fix verification)' do
    it 'does not return a model with the wrong root' do
      # This is the key test for the bug fix:
      # Two different roots with the same resultset should NOT share a cache entry

      Dir.mktmpdir('cache_test') do |different_root|
        config1 = { root: project1_root, resultset: project1_resultset }
        config2 = { root: different_root, resultset: project1_resultset }

        model1 = CovLoupe::CoverageModel.new(**config1)
        cache.store(config1, model1)

        # Attempting to fetch with different root should return nil (cache miss)
        # because root is now part of the cache key
        fetched_model = cache.fetch(config2)

        expect(fetched_model).to be_nil
      end
    end

    it 'ensures each root gets its own model instance' do
      # Verifies the practical implication: different roots maintain isolation
      Dir.mktmpdir('cache_test') do |different_root|
        config1 = { root: project1_root, resultset: project1_resultset }
        config2 = { root: different_root, resultset: project1_resultset }

        model1 = CovLoupe::CoverageModel.new(**config1)
        model2 = CovLoupe::CoverageModel.new(**config2)

        cache.store(config1, model1)
        cache.store(config2, model2)

        # Each should maintain its own root
        cached1 = cache.fetch(config1)
        cached2 = cache.fetch(config2)

        expect(cached1.instance_variable_get(:@root)).to eq(File.absolute_path(project1_root))
        expect(cached2.instance_variable_get(:@root)).to eq(File.absolute_path(different_root))
        expect(cached1.instance_variable_get(:@root)).not_to eq(
          cached2.instance_variable_get(:@root)
        )
      end
    end
  end
end
