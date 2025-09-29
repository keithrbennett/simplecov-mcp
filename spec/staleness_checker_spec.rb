# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe SimpleCovMcp::StalenessChecker do
  let(:tmpdir) { Dir.mktmpdir('scmcp-stale') }
  after { FileUtils.remove_entry(tmpdir) if tmpdir && File.directory?(tmpdir) }

  def write_file(path, lines)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') { |f| lines.each { |l| f.puts(l) } }
  end

  context 'compute_file_staleness_details' do
    it 'detects newer file vs coverage timestamp' do
      file = File.join(tmpdir, 'lib', 'foo.rb')
      write_file(file, ["a", "b"]) # 2 lines
      ts = Time.at(Time.now.to_i - 3600) # 1 hour ago
      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error', tracked_globs: nil, timestamp: ts)

      details = checker.send(:compute_file_staleness_details, file, [1, 1])
      expect(details[:exists]).to eq(true)
      expect(details[:cov_len]).to eq(2)
      expect(details[:src_len]).to eq(2)
      expect(details[:newer]).to eq(true)
      expect(details[:len_mismatch]).to eq(false)

      expect(checker.stale_for_file?(file, [1, 1])).to eq(true)
      expect { checker.check_file!(file, [1, 1]) }.to raise_error(SimpleCovMcp::CoverageDataStaleError)
    end

    it 'detects length mismatch between source and coverage' do
      file = File.join(tmpdir, 'lib', 'bar.rb')
      write_file(file, ["a", "b", "c", "d"]) # 4 lines
      ts = Time.now # now, not relevant for mismatch
      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error', tracked_globs: nil, timestamp: ts)

      details = checker.send(:compute_file_staleness_details, file, [1, 1])
      expect(details[:exists]).to eq(true)
      expect(details[:cov_len]).to eq(2)
      expect(details[:src_len]).to eq(4)
      expect(details[:newer]).to eq(false)
      expect(details[:len_mismatch]).to eq(true)

      expect(checker.stale_for_file?(file, [1, 1])).to eq(true)
      expect { checker.check_file!(file, [1, 1]) }.to raise_error(SimpleCovMcp::CoverageDataStaleError)
    end

    it 'treats missing file as stale and raises in check_file! when coverage lines exist' do
      file = File.join(tmpdir, 'lib', 'missing.rb')
      ts = Time.now
      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error', tracked_globs: nil, timestamp: ts)

      details = checker.send(:compute_file_staleness_details, file, [1, 1, 1])
      expect(details[:exists]).to eq(false)
      expect(details[:newer]).to be_falsey
      # Missing file yields cov_len>0 with src_len=0, so len_mismatch is true
      expect(details[:len_mismatch]).to be_truthy

      expect(checker.stale_for_file?(file, [1, 1, 1])).to eq(true)
      expect { checker.check_file!(file, [1, 1, 1]) }.to raise_error(SimpleCovMcp::CoverageDataStaleError)
    end

    it 'is not stale when timestamps and lengths match' do
      file = File.join(tmpdir, 'lib', 'ok.rb')
      write_file(file, ["a", "b", "c"]) # 3 lines
      # Make file older than ts
      past = Time.at(Time.now.to_i - 3600)
      File.utime(past, past, file)
      ts = Time.now
      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error', tracked_globs: nil, timestamp: ts)

      details = checker.send(:compute_file_staleness_details, file, [1, 0, nil])
      expect(details[:exists]).to eq(true)
      expect(details[:newer]).to eq(false)
      expect(details[:len_mismatch]).to eq(false)

      expect(checker.stale_for_file?(file, [1, 0, nil])).to eq(false)
      expect { checker.check_file!(file, [1, 0, nil]) }.not_to raise_error
    end
  end
end
