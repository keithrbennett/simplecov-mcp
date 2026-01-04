# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/model_data_cache'
require 'cov_loupe/model_data'

RSpec.describe CovLoupe::ModelDataCache do
  let(:cache) { described_class.instance }
  let(:project1_root) { (FIXTURES_DIR / 'project1').to_s }
  let(:project1_resultset) { FIXTURE_PROJECT1_RESULTSET_PATH }

  # Clear the singleton cache before each test
  before { cache.clear }

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

  describe '#get' do
    it 'returns ModelData with coverage data' do
      data = cache.get(project1_resultset, root: project1_root)
      expect(data).to be_a(CovLoupe::ModelData)
      expect(data.coverage_map).to be_a(Hash)
      expect(data.timestamp).to be_a(Integer)
      expect(data.resultset_path).to eq(project1_resultset)
      expect(data.volume_case_sensitive).to be(true).or be(false)
    end

    it 'returns the same data for identical resultset path' do
      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      expect(data1).to eq(data2)
    end

    it 'shares data across different roots pointing to same resultset' do
      Dir.mktmpdir('cache_test') do |temp_dir|
        data1 = cache.get(project1_resultset, root: project1_root)
        data2 = cache.get(project1_resultset, root: temp_dir)
        # Should return the same cached data instance
        expect(data1).to eq(data2)
      end
    end

    it 'reloads data when resultset mtime changes' do
      stat_now = build_stat(mtime: Time.at(100), size: 10, inode: 1)
      stat_later = build_stat(mtime: Time.at(200), size: 10, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_later)

      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      # Should reload and get new data (different object)
      expect(data2).not_to eq(data1)
    end

    it 'detects subsecond mtime changes' do
      base_time = Time.at(100)
      stat_now = build_stat(mtime: base_time, mtime_nsec: 0, size: 10, inode: 1)
      stat_subsecond = build_stat(mtime: base_time, mtime_nsec: 1_000_000, size: 10, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_subsecond)

      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      expect(data2).not_to eq(data1)
    end

    it 'reloads when size changes within the same second' do
      base_time = Time.at(100)
      stat_now = build_stat(mtime: base_time, mtime_nsec: 0, size: 10, inode: 1)
      stat_size_change = build_stat(mtime: base_time, mtime_nsec: 0, size: 11, inode: 1)
      allow(File).to receive(:stat).with(project1_resultset)
        .and_return(stat_now, stat_size_change)

      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      expect(data2).not_to eq(data1)
    end

    it 'reloads when content changes but metadata is identical' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'digest_v1', 'digest_v2')

      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      expect(data2).not_to eq(data1)
    end

    it 'validates digest on every get call' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'unchanged', 'unchanged')

      data1 = cache.get(project1_resultset, root: project1_root)
      data2 = cache.get(project1_resultset, root: project1_root)
      expect(data2).to eq(data1)
    end

    it 'handles stat computation failures gracefully' do
      allow(File).to receive(:stat).with(project1_resultset).and_raise(Errno::ENOENT)

      # Should load data but not cache it
      expect { cache.get(project1_resultset, root: project1_root) }.not_to raise_error
    end

    it 'handles digest computation failures gracefully' do
      stub_unchanged_stat(project1_resultset)
      allow(Digest::MD5).to receive(:file).with(project1_resultset).and_raise(Errno::EACCES)

      # Should load data but not cache it
      expect { cache.get(project1_resultset, root: project1_root) }.not_to raise_error
    end
  end

  describe '#clear' do
    it 'clears all cached entries' do
      stub_unchanged_stat(project1_resultset)
      stub_digest(project1_resultset, 'unchanged', 'unchanged')

      data1 = cache.get(project1_resultset, root: project1_root)
      cache.clear
      data2 = cache.get(project1_resultset, root: project1_root)

      # After clear, should reload (different object)
      expect(data2).not_to eq(data1)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent access safely' do
      threads = 10.times.map do
        Thread.new do
          data = cache.get(project1_resultset, root: project1_root)
          expect(data).to be_a(CovLoupe::ModelData)
        end
      end
      threads.each(&:join)
    end
  end
end
