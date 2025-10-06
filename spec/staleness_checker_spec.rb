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
end