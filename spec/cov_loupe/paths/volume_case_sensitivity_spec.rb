# frozen_string_literal: true

RSpec.describe CovLoupe::VolumeCaseSensitivity do
  describe '.volume_case_sensitive?' do
    let(:test_dir) { Dir.mktmpdir }
    let(:test_file) { File.join(test_dir, 'TestFile.txt') }

    before do
      FileUtils.touch(test_file)
    end

    after do
      FileUtils.rm_rf(test_dir)
      described_class.clear_cache
    end

    context 'when directory exists' do
      it 'returns a boolean value' do
        result = described_class.volume_case_sensitive?(test_dir)
        expect(result).to be(true).or be(false)
      end

      it 'caches the result' do
        first_call = described_class.volume_case_sensitive?(test_dir)
        cache = described_class.cache

        expect(cache).to have_key(File.absolute_path(test_dir))
        expect(cache[File.absolute_path(test_dir)]).to eq(first_call)
      end

      it 'uses cached result on subsequent calls' do
        described_class.volume_case_sensitive?(test_dir)
        first_cache = described_class.cache.dup

        # Make a second call
        described_class.volume_case_sensitive?(test_dir)
        second_cache = described_class.cache

        # Cache should be identical (no new entries)
        expect(first_cache).to eq(second_cache)
      end
    end

    context 'when using existing file for detection' do
      it 'finds an existing file with letters' do
        existing = described_class.find_existing_file(test_dir)
        expect(existing).to match(/[A-Za-z]/)
      end

      it 'returns nil when no suitable file exists' do
        empty_dir = Dir.mktmpdir
        begin
          FileUtils.touch(File.join(empty_dir, '12345'))
          existing = described_class.find_existing_file(empty_dir)
          expect(existing).to be_nil
        ensure
          FileUtils.rm_rf(empty_dir)
        end
      end
    end

    context 'when directory does not exist' do
      it 'returns false' do
        result = described_class.volume_case_sensitive?('/nonexistent/directory')
        expect(result).to be(false)
      end

      it 'does not cache the result' do
        described_class.volume_case_sensitive?('/nonexistent/directory')
        cache = described_class.cache

        expect(cache).to be_empty
      end
    end

    context 'when path is nil' do
      it 'uses current working directory' do
        result = described_class.volume_case_sensitive?(nil)
        expect(result).to be(true).or be(false)
      end
    end

    context 'when filesystem access fails' do
      before do
        allow(File).to receive(:directory?).and_raise(Errno::EACCES)
      end

      it 'returns false' do
        result = described_class.volume_case_sensitive?(test_dir)
        expect(result).to be(false)
      end

      it 'does not cache the result' do
        described_class.volume_case_sensitive?(test_dir)
        cache = described_class.cache

        expect(cache).to be_empty
      end
    end

    context 'when IOError occurs' do
      before do
        allow(File).to receive(:directory?).and_raise(IOError)
      end

      it 'returns false' do
        result = described_class.volume_case_sensitive?(test_dir)
        expect(result).to be(false)
      end
    end
  end

  describe '.clear_cache' do
    let(:test_dir) { Dir.mktmpdir }

    before do
      described_class.volume_case_sensitive?(test_dir)
    end

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'removes all cached entries' do
      expect(described_class.cache).not_to be_empty

      described_class.clear_cache

      expect(described_class.cache).to be_empty
    end

    it 'allows re-detection after clearing' do
      first_result = described_class.volume_case_sensitive?(test_dir)
      described_class.clear_cache

      second_result = described_class.volume_case_sensitive?(test_dir)

      expect(second_result).to eq(first_result)
    end
  end

  describe '.cache' do
    let(:test_dir) { Dir.mktmpdir }
    let(:test_file) { File.join(test_dir, 'TestFile.txt') }

    before do
      FileUtils.touch(test_file)
      described_class.volume_case_sensitive?(test_dir)
    end

    after do
      FileUtils.rm_rf(test_dir)
      described_class.clear_cache
    end

    it 'returns a hash of cached results' do
      cache = described_class.cache
      expect(cache).to be_a(Hash)
    end

    it 'returns a copy of the cache (not the original)' do
      cache1 = described_class.cache
      cache1['fake_key'] = true

      cache2 = described_class.cache
      expect(cache2).not_to have_key('fake_key')
    end
  end

  describe '.detect_case_sensitive_using_temp_file?' do
    let(:test_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(test_dir)
      described_class.clear_cache
    end

    it 'creates and removes temporary test files' do
      result = described_class.detect_case_sensitive_using_temp_file?(test_dir)
      expect(result).to be(true).or be(false)

      # Verify no test files remain
      temp_files = Dir.entries(test_dir).select { |f| f.include?('CovLoupe_CaseSensitivity_Test') }
      expect(temp_files).to be_empty
    end

    it 'handles concurrent access safely' do
      threads = 10.times.map do
        Thread.new do
          described_class.detect_case_sensitive_using_temp_file?(test_dir)
        end
      end

      results = threads.map(&:value)
      expect(results).to all(be(true).or(be(false)))
    end
  end

  describe '.generate_unique_test_filename' do
    let(:test_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'generates a unique filename' do
      filename1 = described_class.generate_unique_test_filename(test_dir)
      filename2 = described_class.generate_unique_test_filename(test_dir)

      expect(filename1).not_to eq(filename2)
    end

    it 'returns a path within the test directory' do
      filename = described_class.generate_unique_test_filename(test_dir)
      expect(filename).to start_with(test_dir)
    end

    it 'generates filename that does not exist' do
      filename = described_class.generate_unique_test_filename(test_dir)
      expect(File.exist?(filename)).to be(false)
      expect(File.exist?(filename.upcase)).to be(false)
      expect(File.exist?(filename.downcase)).to be(false)
    end

    it 'avoids conflicts with existing files' do
      # Create a file that might conflict
      conflicting = File.join(test_dir, 'CovLoupe_CaseSensitivity_Test_0123456789abcdef.tmp')
      FileUtils.touch(conflicting)

      filename = described_class.generate_unique_test_filename(test_dir)
      expect(filename).not_to eq(conflicting)
    end
  end

  describe '.find_existing_file' do
    let(:test_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'finds a file with letters in its name' do
      FileUtils.touch(File.join(test_dir, 'TestFile.txt'))
      FileUtils.touch(File.join(test_dir, '12345'))

      result = described_class.find_existing_file(test_dir)
      expect(result).to eq('TestFile.txt')
    end

    it 'returns nil when no files with letters exist' do
      FileUtils.touch(File.join(test_dir, '12345'))
      FileUtils.touch(File.join(test_dir, '67890'))

      result = described_class.find_existing_file(test_dir)
      expect(result).to be_nil
    end

    it 'skips directories' do
      FileUtils.mkdir(File.join(test_dir, 'TestDir'))
      FileUtils.touch(File.join(test_dir, 'test.txt'))

      result = described_class.find_existing_file(test_dir)
      expect(result).to eq('test.txt')
    end

    it 'returns nil when directory is empty' do
      result = described_class.find_existing_file(test_dir)
      expect(result).to be_nil
    end
  end

  describe '.detect_case_sensitive_using_existing_file?' do
    # This method detects filesystem case sensitivity by checking if an alternate-case
    # version of a filename exists. If it does, File.identical? is used to determine
    # if they're the same file (case-insensitive) or different files (case-sensitive).

    let(:test_dir) { Dir.mktmpdir }
    let(:filename) { 'TestFile.txt' }
    let(:alternate) { filename.tr('A-Za-z', 'a-zA-Z') } # 'TestFile.txt' -> 'tESTfILE.TXT'
    let(:alternate_path) { File.join(test_dir, alternate) }
    let(:original_path) { File.join(test_dir, filename) }

    after do
      FileUtils.rm_rf(test_dir)
    end

    before do
      allow(File).to receive(:exist?).and_call_original
    end

    # Shared test for the branch that uses File.identical? when an alternate-case file exists
    # - files_are_identical=true: files are the same, so filesystem is case-insensitive -> return false
    # - files_are_identical=false: files are different, so filesystem is case-sensitive -> return true
    shared_examples 'case detection with alternate file' do |files_are_identical|
      it "returns #{!files_are_identical} when File.identical? returns #{files_are_identical}" do
        allow(File).to receive(:exist?).with(alternate_path).and_return(true)
        allow(File).to receive(:identical?).with(original_path,
          alternate_path).and_return(files_are_identical)

        result = described_class.detect_case_sensitive_using_existing_file?(test_dir, filename)
        expect(result).to be(!files_are_identical)
      end
    end

    context 'when alternate-case file exists' do
      # Tests the File.identical? branch (line 127 in implementation)
      it_behaves_like 'case detection with alternate file', true
      it_behaves_like 'case detection with alternate file', false
    end

    context 'when alternate-case file does not exist' do
      # Tests the else branch - assumes case-sensitive as a safe default
      it 'returns true (assumes case-sensitive)' do
        allow(File).to receive(:exist?).with(alternate_path).and_return(false)
        allow(File).to receive(:identical?).and_raise('File.identical? should not be called')

        result = described_class.detect_case_sensitive_using_existing_file?(test_dir, filename)
        expect(result).to be(true)
      end
    end

    context 'with different case variations' do
      # Verify that case transformation (tr('A-Za-z', 'a-zA-Z')) works correctly
      # for various input filename case patterns
      %w[uppercase lowercase mixed].each do |variation|
        it "correctly handles #{variation} filename" do
          variant_filename = { 'uppercase' => 'TESTFILE.TXT',
                               'lowercase' => 'testfile.txt',
                               'mixed' => 'TestFile.Txt' }[variation]

          variant_alternate = variant_filename.tr('A-Za-z', 'a-zA-Z')
          allow(File).to receive(:exist?).with(File.join(test_dir, variant_alternate)).and_return(false)

          result = described_class.detect_case_sensitive_using_existing_file?(test_dir, variant_filename)
          expect(result).to be(true)
        end
      end
    end
  end

  describe 'thread safety' do
    let(:test_dir) { Dir.mktmpdir }
    let(:test_file) { File.join(test_dir, 'TestFile.txt') }

    before do
      FileUtils.touch(test_file)
    end

    after do
      FileUtils.rm_rf(test_dir)
      described_class.clear_cache
    end

    it 'handles concurrent calls safely' do
      threads = 20.times.map do
        Thread.new do
          described_class.volume_case_sensitive?(test_dir)
        end
      end

      results = threads.map(&:value)
      expect(results).to all(be(true).or(be(false)))
    end

    it 'maintains cache consistency under concurrent access' do
      threads = 10.times.map do
        Thread.new do
          described_class.volume_case_sensitive?(test_dir)
          described_class.cache
        end
      end

      caches = threads.map(&:value)
      expect(caches).to all(have_key(File.absolute_path(test_dir)))
    end
  end
end
