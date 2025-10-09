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

  shared_examples 'a staleness check' do |description:, file_lines:, coverage_lines:, timestamp:, expected_details:, expected_stale_char:, expected_error:|
    it description do
      file = File.join(tmpdir, 'lib', 'test.rb')
      write_file(file, file_lines) if file_lines

      ts = if timestamp == :past
             now = Time.now
             past = Time.at(now.to_i - 3600)
             File.utime(past, past, file)
             now
           else
             timestamp
           end

      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error', tracked_globs: nil, timestamp: ts)

      details = checker.send(:compute_file_staleness_details, file, coverage_lines)

      expected_details.each do |key, value|
        if value == :any
          expect(details).to have_key(key)
        else
          expect(details[key]).to eq(value)
        end
      end

      expect(checker.stale_for_file?(file, coverage_lines)).to eq(expected_stale_char)

      if expected_error
        expect { checker.check_file!(file, coverage_lines) }.to raise_error(expected_error)
      else
        expect { checker.check_file!(file, coverage_lines) }.not_to raise_error
      end
    end
  end

  context 'compute_file_staleness_details' do
    include_examples 'a staleness check',
                     description: 'detects newer file vs coverage timestamp',
                     file_lines: ['a', 'b'],
                     coverage_lines: [1, 1],
                     timestamp: Time.at(Time.now.to_i - 3600),
                     expected_details: { exists: true, cov_len: 2, src_len: 2, newer: true, len_mismatch: false, file_mtime: :any, coverage_timestamp: :any },
                     expected_stale_char: 'T',
                     expected_error: SimpleCovMcp::CoverageDataStaleError

    include_examples 'a staleness check',
                     description: 'detects length mismatch between source and coverage',
                     file_lines: ['a', 'b', 'c', 'd'],
                     coverage_lines: [1, 1],
                     timestamp: Time.now,
                     expected_details: { exists: true, cov_len: 2, src_len: 4, newer: false, len_mismatch: true, file_mtime: :any, coverage_timestamp: :any },
                     expected_stale_char: 'L',
                     expected_error: SimpleCovMcp::CoverageDataStaleError

    include_examples 'a staleness check',
                     description: 'treats missing file as stale',
                     file_lines: nil,
                     coverage_lines: [1, 1, 1],
                     timestamp: Time.now,
                     expected_details: { exists: false, newer: false, len_mismatch: true, file_mtime: nil, coverage_timestamp: :any },
                     expected_stale_char: 'M',
                     expected_error: SimpleCovMcp::CoverageDataStaleError

    include_examples 'a staleness check',
                     description: 'is not stale when timestamps and lengths match',
                     file_lines: ['a', 'b', 'c'],
                     coverage_lines: [1, 0, nil],
                     timestamp: :past,
                     expected_details: { exists: true, newer: false, len_mismatch: false, file_mtime: :any, coverage_timestamp: :any },
                     expected_stale_char: false,
                     expected_error: nil
  end

  context 'missing_trailing_newline? edge cases' do
    let(:checker) { described_class.new(root: tmpdir, resultset: nil, mode: 'off', timestamp: Time.now) }

    it 'detects file without trailing newline' do
      file = File.join(tmpdir, 'no_newline.rb')
      File.write(file, 'line1')
      expect(checker.send(:missing_trailing_newline?, file)).to be true
    end

    it 'detects file with trailing newline (LF)' do
      file = File.join(tmpdir, 'with_newline.rb')
      File.write(file, "line1\n")
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles file with CRLF endings (Windows-style)' do
      file = File.join(tmpdir, 'crlf.rb')
      File.write(file, "line1\r\nline2\r\n", mode: 'wb')
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles file ending with CRLF but no final newline' do
      file = File.join(tmpdir, 'crlf_no_final.rb')
      File.write(file, "line1\r\nline2", mode: 'wb')
      expect(checker.send(:missing_trailing_newline?, file)).to be true
    end

    it 'handles empty file' do
      file = File.join(tmpdir, 'empty.rb')
      File.write(file, '')
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles file with mixed line endings' do
      file = File.join(tmpdir, 'mixed.rb')
      File.write(file, "line1\nline2\r\nline3\n", mode: 'wb')
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'returns false for non-existent file' do
      file = File.join(tmpdir, 'nonexistent.rb')
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles errors gracefully' do
      file = File.join(tmpdir, 'test.rb')
      File.write(file, 'content')

      # Mock File.open to raise an error
      allow(File).to receive(:open).with(file, 'rb').and_raise(StandardError.new('IO error'))

      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles binary files that end with newline' do
      file = File.join(tmpdir, 'binary.dat')
      File.write(file, "\x00\x01\x02\x0A", mode: 'wb')
      expect(checker.send(:missing_trailing_newline?, file)).to be false
    end

    it 'handles binary files that do not end with newline' do
      file = File.join(tmpdir, 'binary_no_newline.dat')
      File.write(file, "\x00\x01\x02\xFF", mode: 'wb')
      expect(checker.send(:missing_trailing_newline?, file)).to be true
    end
  end

  context 'line count adjustment with missing trailing newline' do
    let(:checker) { described_class.new(root: tmpdir, resultset: nil, mode: 'off', timestamp: Time.now) }

    it 'adjusts line count when file has no trailing newline and counts differ by 1' do
      file = File.join(tmpdir, 'adjust.rb')
      # Write 3 lines without final newline
      File.write(file, "line1\nline2\nline3")

      # Coverage has 3 lines, file counts as 3 lines (no newline at end)
      # but File.foreach will count 3 iterations
      coverage_lines = [1, 0, 1]
      details = checker.send(:compute_file_staleness_details, file, coverage_lines)

      expect(details[:len_mismatch]).to be false
    end

    it 'does not adjust when file has trailing newline' do
      file = File.join(tmpdir, 'no_adjust.rb')
      # Write 3 lines with final newline
      File.write(file, "line1\nline2\nline3\n")

      # Coverage has 3 lines, file also counts as 3 lines (foreach counts by separator)
      coverage_lines = [1, 0, 1]
      details = checker.send(:compute_file_staleness_details, file, coverage_lines)

      # No mismatch - both are 3 lines
      expect(details[:src_len]).to eq(3)
      expect(details[:cov_len]).to eq(3)
      expect(details[:len_mismatch]).to be false
    end

    it 'does not adjust when difference is more than 1' do
      file = File.join(tmpdir, 'big_diff.rb')
      File.write(file, "line1\nline2\nline3\nline4\nline5")

      coverage_lines = [1, 0, 1]
      details = checker.send(:compute_file_staleness_details, file, coverage_lines)

      expect(details[:len_mismatch]).to be true
    end

    it 'does not adjust when coverage is empty' do
      file = File.join(tmpdir, 'empty_cov.rb')
      File.write(file, "line1\nline2")

      coverage_lines = []
      details = checker.send(:compute_file_staleness_details, file, coverage_lines)

      expect(details[:len_mismatch]).to be false
    end
  end

  context 'safe_count_lines edge cases' do
    let(:checker) { described_class.new(root: tmpdir, resultset: nil, mode: 'off', timestamp: Time.now) }

    it 'returns 0 for non-existent file' do
      file = File.join(tmpdir, 'nonexistent.rb')
      expect(checker.send(:safe_count_lines, file)).to eq(0)
    end

    it 'handles errors gracefully' do
      file = File.join(tmpdir, 'test.rb')
      File.write(file, "line1\nline2\n")

      # Mock File.foreach to raise an error
      allow(File).to receive(:foreach).with(file).and_raise(StandardError.new('IO error'))

      expect(checker.send(:safe_count_lines, file)).to eq(0)
    end

    it 'counts lines correctly for file with final newline' do
      file = File.join(tmpdir, 'with_newline.rb')
      File.write(file, "line1\nline2\nline3\n")
      # File.foreach counts 3 iterations (by line separator)
      expect(checker.send(:safe_count_lines, file)).to eq(3)
    end

    it 'counts lines correctly for file without final newline' do
      file = File.join(tmpdir, 'no_newline.rb')
      File.write(file, "line1\nline2\nline3")
      # File.foreach counts 3 iterations
      expect(checker.send(:safe_count_lines, file)).to eq(3)
    end

    it 'returns 0 for empty file' do
      file = File.join(tmpdir, 'empty.rb')
      File.write(file, '')
      expect(checker.send(:safe_count_lines, file)).to eq(0)
    end
  end
end