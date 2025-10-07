# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::PathRelativizer do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:relativizer) do
    described_class.new(
      root: root,
      scalar_keys: %w[file file_path],
      array_keys: %w[newer_files missing_files deleted_files]
    )
  end

  describe '#relativize' do
    it 'converts configured scalar keys to root-relative paths' do
      payload = { 'file' => File.join(root, 'lib/foo.rb') }
      result = relativizer.relativize(payload)

      expect(result['file']).to eq('lib/foo.rb')
      expect(payload['file']).to eq(File.join(root, 'lib/foo.rb'))
    end

    it 'relativizes arrays for configured keys without mutating originals' do
      payload = {
        'newer_files' => [File.join(root, 'lib/foo.rb'), File.join(root, 'lib/bar.rb')]
      }

      result = relativizer.relativize(payload)

      expect(result['newer_files']).to contain_exactly('lib/foo.rb', 'lib/bar.rb')
      expect(payload['newer_files']).to all(start_with(root))
    end

    it 'leaves unconfigured keys untouched' do
      payload = { 'other' => File.join(root, 'lib/foo.rb') }
      result = relativizer.relativize(payload)

      expect(result['other']).to eq(payload['other'])
    end

    it 'ignores paths outside the root' do
      outside = '/tmp/external.rb'
      payload = { 'file' => outside }

      result = relativizer.relativize(payload)

      expect(result['file']).to eq(outside)
    end

    it 'relativizes nested arrays of hashes' do
      payload = {
        'files' => [
          { 'file' => File.join(root, 'lib/foo.rb') },
          { 'file' => File.join(root, 'lib/bar.rb') }
        ],
        'counts' => { 'total' => 2 }
      }

      result = relativizer.relativize(payload)

      expect(result['files'].map { |h| h['file'] }).to eq(%w[lib/foo.rb lib/bar.rb])
      expect(result['counts']).to eq('total' => 2)
    end

    it "handles paths with '..' components" do
      payload = { 'file' => File.join(root, 'lib/../lib/foo.rb') }
      result = relativizer.relativize(payload)
      expect(result['file']).to eq('lib/foo.rb')
    end

    it 'handles paths with spaces' do
      file_with_space = File.join(root, 'lib/file with space.rb')
      FileUtils.touch(file_with_space)

      payload = { 'file' => file_with_space }
      result = relativizer.relativize(payload)
      expect(result['file']).to eq('lib/file with space.rb')
    ensure
      FileUtils.rm_f(file_with_space)
    end
  end
end
