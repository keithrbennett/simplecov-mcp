# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe CovLoupe::StalenessChecker do
  let(:tmpdir) { Dir.mktmpdir('scmcp-stale') }

  after { FileUtils.remove_entry(tmpdir) if tmpdir && File.directory?(tmpdir) }

  def write_file(path, lines)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') { |f| lines.each { |l| f.puts(l) } }
  end

  shared_examples 'a staleness check' do |
    description:,
    file_lines:,
    coverage_lines:,
    timestamp:,
    expected_details:,
    expected_stale_char:,
    expected_error:
  |
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

      checker = described_class.new(root: tmpdir, resultset: nil, mode: 'error',
        tracked_globs: nil, timestamp: ts)

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

  context 'when computing file staleness details' do
    it_behaves_like 'a staleness check',
      description: 'detects newer file vs coverage timestamp',
      file_lines: %w[a b],
      coverage_lines: [1, 1],
      timestamp: Time.at(Time.now.to_i - 3600),
      expected_details: {
        exists: true,
        cov_len: 2,
        src_len: 2,
        newer: true,
        len_mismatch: false,
        file_mtime: :any,
        coverage_timestamp: :any
      },
      expected_stale_char: 'T',
      expected_error: CovLoupe::CoverageDataStaleError

    it_behaves_like 'a staleness check',
      description: 'detects length mismatch between source and coverage',
      file_lines: %w[a b c d],
      coverage_lines: [1, 1],
      timestamp: Time.now,
      expected_details: {
        exists: true,
        cov_len: 2,
        src_len: 4,
        newer: false,
        len_mismatch: true,
        file_mtime: :any,
        coverage_timestamp: :any
      },
      expected_stale_char: 'L',
      expected_error: CovLoupe::CoverageDataStaleError

    it_behaves_like 'a staleness check',
      description: 'treats missing file as stale',
      file_lines: nil,
      coverage_lines: [1, 1, 1],
      timestamp: Time.now,
      expected_details: {
        exists: false,
        newer: false,
        len_mismatch: true,
        file_mtime: nil,
        coverage_timestamp: :any
      },
      expected_stale_char: 'M',
      expected_error: CovLoupe::CoverageDataStaleError

    it_behaves_like 'a staleness check',
      description: 'is not stale when timestamps and lengths match',
      file_lines: %w[a b c],
      coverage_lines: [1, 0, nil],
      timestamp: :past,
      expected_details: {
        exists: true,
        newer: false,
        len_mismatch: false,
        file_mtime: :any,
        coverage_timestamp: :any
      },
      expected_stale_char: false,
      expected_error: nil
  end

  context 'when file stat calls raise errors' do
    let(:checker) do
      described_class.new(root: tmpdir, resultset: nil, mode: 'error',
        tracked_globs: nil, timestamp: Time.now)
    end

    it 'returns E and raises FileError when File.file? fails' do
      file = File.join(tmpdir, 'lib', 'test.rb')
      write_file(file, %w[a b])
      coverage_lines = [1, 1]

      allow(File).to receive(:file?).and_call_original
      allow(File).to receive(:file?).with(file).and_raise(Errno::EACCES.new('Permission denied'))

      details = checker.send(:compute_file_staleness_details, file, coverage_lines)
      expect(details[:read_error]).to be true
      expect(checker.stale_for_file?(file, coverage_lines)).to eq('E')
      expect { checker.check_file!(file, coverage_lines) }
        .to raise_error(CovLoupe::FileError, /Error reading file/)
    end

    it 'returns E and raises FileError when File.mtime fails' do
      file = File.join(tmpdir, 'lib', 'test.rb')
      write_file(file, %w[a b])
      coverage_lines = [1, 1]

      allow(File).to receive(:mtime).and_call_original
      allow(File).to receive(:mtime).with(file).and_raise(Errno::EACCES.new('Permission denied'))

      details = checker.send(:compute_file_staleness_details, file, coverage_lines)
      expect(details[:read_error]).to be true
      expect(checker.stale_for_file?(file, coverage_lines)).to eq('E')
      expect { checker.check_file!(file, coverage_lines) }
        .to raise_error(CovLoupe::FileError, /Error reading file/)
    end
  end

  context 'when handling safe_count_lines edge cases' do
    let(:checker) do
      described_class.new(root: tmpdir, resultset: nil, mode: 'off', timestamp: Time.now)
    end

    it 'returns 0 for non-existent file' do
      file = File.join(tmpdir, 'nonexistent.rb')
      expect(checker.send(:safe_count_lines, file)).to eq(0)
    end

    it 'returns :read_error on permission denied (EACCES)' do
      file = File.join(tmpdir, 'test.rb')
      File.write(file, "line1\nline2\n")

      # Mock File.foreach to raise permission error
      allow(File).to receive(:foreach).with(file).and_raise(Errno::EACCES.new('Permission denied'))

      expect(checker.send(:safe_count_lines, file)).to eq(:read_error)
    end

    it 'returns :read_error on permission denied (EPERM)' do
      file = File.join(tmpdir, 'test.rb')
      File.write(file, "line1\nline2\n")

      # Mock File.foreach to raise permission error
      allow(File).to receive(:foreach).with(file)
        .and_raise(Errno::EPERM.new('Operation not permitted'))

      expect(checker.send(:safe_count_lines, file)).to eq(:read_error)
    end

    it 'returns :read_error on IO errors' do
      file = File.join(tmpdir, 'test.rb')
      File.write(file, "line1\nline2\n")

      # Mock File.foreach to raise an IO error
      allow(File).to receive(:foreach).with(file).and_raise(IOError.new('IO error'))

      expect(checker.send(:safe_count_lines, file)).to eq(:read_error)
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

  context 'when rel has path prefix mismatches' do
    let(:checker) do
      described_class.new(root: tmpdir, resultset: nil, mode: 'off', timestamp: Time.now)
    end

    it 'returns relative path for files within project root' do
      file_inside = File.join(tmpdir, 'lib', 'test.rb')
      expect(checker.send(:rel, file_inside)).to eq('lib/test.rb')
    end

    it 'handles ArgumentError when path prefixes differ (absolute vs relative)' do
      # Test the specific ArgumentError scenario: absolute path vs relative root
      # This simulates the bug scenario where coverage data has absolute paths
      # but the root is somehow processed as relative (edge case)
      checker_with_relative_root = described_class.new(root: '.', resultset: nil, mode: 'off',
        timestamp: Time.now)

      # Override the @root to simulate the edge case where it's still relative
      checker_with_relative_root.instance_variable_set(:@root, './subdir')

      file_absolute = '/opt/shared_libs/utils/validation.rb'

      # This should trigger the ArgumentError rescue and return the absolute path
      expect(checker_with_relative_root.send(:rel, file_absolute))
        .to eq('/opt/shared_libs/utils/validation.rb')
    end

    it 'handles relative file paths with absolute root' do
      file_relative = './lib/test.rb'

      # This should work fine (both are converted to absolute internally)
      expect { checker.send(:rel, file_relative) }.not_to raise_error
    end

    it 'works with check_file! when rel encounters ArgumentError' do
      # Test the specific case where rel() would crash with ArgumentError
      # Instead of testing the full check_file! flow, just test that rel() works

      checker_with_edge_case = described_class.new(root: '.', resultset: nil, mode: 'off',
        timestamp: Time.now)
      checker_with_edge_case.instance_variable_set(:@root, './subdir')

      file_outside = '/opt/company_gem/lib/core.rb'

      # This should trigger the ArgumentError and return the absolute path
      # instead of crashing with ArgumentError
      result = checker_with_edge_case.send(:rel, file_outside)
      expect(result).to eq('/opt/company_gem/lib/core.rb')

      # Verify it doesn't raise ArgumentError
      expect { checker_with_edge_case.send(:rel, file_outside) }.not_to raise_error
    end

    it 'handles files outside project root gracefully (returns relative path with ..)' do
      # Use a sibling path to ensure both live on the same drive/volume
      file_outside = File.expand_path('../external_file.rb', tmpdir)

      # This should return a relative path with .. (not trigger ArgumentError)
      result = checker.send(:rel, file_outside)
      expect(result).to include('..') # Should contain relative navigation
      expect(result).not_to start_with('/') # Should be relative, not absolute
    end

    it 'allows project-level staleness checks to handle coverage outside root' do
      future_time = Time.at(Time.now.to_i + 3600)
      checker_with_relative_root = described_class.new(root: '.', resultset: nil, mode: 'error',
        timestamp: future_time)
      checker_with_relative_root.instance_variable_set(:@root, './subdir')

      external_dir = Dir.mktmpdir('scmcp-outside')

      begin
        external_file = File.join(external_dir, 'shared.rb')
        File.write(external_file, "puts 'hi'\n")

        coverage_map = { external_file => [1] }

        expect { checker_with_relative_root.check_project!(coverage_map) }.not_to raise_error
      ensure
        FileUtils.remove_entry(external_dir) if external_dir && File.directory?(external_dir)
      end
    end
  end

  context 'when checking project-level missing tracked files' do
    it 'raises error listing tracked files missing from coverage' do
      tracked_root = Dir.mktmpdir('tracked')
      begin
        file = File.join(tracked_root, 'lib', 'uncovered.rb')
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, "puts 'hello'\n")

        checker = described_class.new(root: tracked_root, resultset: nil, mode: :error,
          tracked_globs: ['lib/**/*.rb'], timestamp: Time.now.to_i)

        expect do
          checker.check_project!({})
        end.to raise_error(CovLoupe::CoverageDataProjectStaleError) { |error|
          expect(error.missing_files).to include('lib/uncovered.rb')
        }
      ensure
        FileUtils.remove_entry(tracked_root)
      end
    end
  end

  context 'when handling file permission errors in project checks' do
    let(:test_file) { File.join(tmpdir, 'test.rb') }
    let(:checker_mode) { :off }
    let(:checker_timestamp) { Time.now.to_i }
    let(:checker) do
      described_class.new(root: tmpdir, resultset: nil, mode: checker_mode,
        timestamp: checker_timestamp)
    end

    def create_test_file(path, content)
      File.write(path, content)
    end

    it 'handles File.file? errors gracefully in compute_newer_and_deleted_files' do
      file1 = File.join(tmpdir, 'accessible.rb')
      file2 = File.join(tmpdir, 'unreadable.rb')
      create_test_file(file1, "puts 'ok'\n")
      create_test_file(file2, "puts 'denied'\n")

      coverage_map = { file1 => [1], file2 => [1] }

      allow(File).to receive(:file?).and_call_original
      allow(File).to receive(:file?).with(file2).and_raise(Errno::EACCES.new('Permission denied'))

      details = checker.check_project!(coverage_map)
      expect(details[:unreadable_files]).to include('unreadable.rb')
    end

    it 'handles File.mtime errors gracefully in compute_newer_and_deleted_files' do
      create_test_file(test_file, "puts 'test'\n")
      coverage_map = { test_file => [1] }
      checker_with_old_timestamp = described_class.new(
        root: tmpdir, resultset: nil, mode: :off, timestamp: Time.at(0)
      )

      allow(File).to receive(:mtime).with(test_file)
        .and_raise(Errno::EPERM.new('Operation not permitted'))

      details = checker_with_old_timestamp.check_project!(coverage_map)
      expect(details[:unreadable_files]).to include('test.rb')
    end

    it 'reports unreadable files with read errors in check_project_with_lines!' do
      create_test_file(test_file, "line1\nline2\n")
      coverage_map = { test_file => [1, 1] }

      allow(File).to receive(:foreach).with(test_file)
        .and_raise(Errno::EACCES.new('Permission denied'))

      details = checker.check_project_with_lines!(coverage_map, coverage_files: [test_file])
      expect(details[:unreadable_files]).to include('test.rb')
      expect(details[:file_statuses][test_file]).to eq('E')
    end

    it 'raises error in error mode when unreadable files are present' do
      create_test_file(test_file, "line1\nline2\n")
      coverage_map = { test_file => [1, 1] }
      error_checker = described_class.new(root: tmpdir, resultset: nil, mode: :error,
        timestamp: Time.now.to_i)

      allow(File).to receive(:foreach).with(test_file)
        .and_raise(Errno::EACCES.new('Permission denied'))

      expect do
        error_checker.check_project_with_lines!(coverage_map, coverage_files: [test_file])
      end.to raise_error(CovLoupe::CoverageDataProjectStaleError) { |error|
        expect(error.unreadable_files).to include('test.rb')
      }
    end

    it 'does not crash in non-error mode when files are unreadable' do
      create_test_file(test_file, "line1\nline2\n")
      coverage_map = { test_file => [1, 1] }

      allow(File).to receive(:file?).with(test_file)
        .and_raise(Errno::EACCES.new('Permission denied'))

      expect { checker.check_project!(coverage_map) }.not_to raise_error
    end
  end
end
