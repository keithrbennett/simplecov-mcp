# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/scripts/pre_release_check'

# rubocop:disable RSpec/SubjectStub
RSpec.describe CovLoupe::Scripts::PreReleaseCheck do
  subject(:script) { described_class.new }

  describe '#call' do
    let(:root) { Pathname.new('/fake/root') }
    let(:version_file) { root.join('lib/cov_loupe/version.rb') }
    let(:release_notes) { root.join('RELEASE_NOTES.md') }

    before do
      # Mock the ROOT constant logic or Dir.chdir
      allow(Dir).to receive(:chdir).and_yield

      # Mock simple commands
      allow(script).to receive(:run_command).and_call_original

      status_double = instance_double(Process::Status, success?: true)
      thread_double = instance_double(Thread, value: status_double)
      allow(Open3).to receive(:popen2e).and_yield(nil, [], thread_double)

      # Mock version file
      allow(described_class::ROOT).to receive(:join).and_call_original
      allow(described_class::ROOT).to receive(:join).with('lib/cov_loupe/version.rb')
        .and_return(version_file)
      allow(version_file).to receive(:read).and_return("module CovLoupe\n  VERSION = '1.2.3'\nend")

      # Mock Release Notes
      allow(described_class::ROOT).to receive(:join).with('RELEASE_NOTES.md')
        .and_return(release_notes)
      allow(release_notes).to receive(:read).and_return("## v1.2.3\n\n- Some changes")

      # Mock Gem build
      allow(FileUtils).to receive(:rm_f)
      fake_gem = instance_double(Pathname, basename: 'cov-loupe-1.2.3.gem')
      allow(fake_gem).to receive(:exist?).and_return(true)
      allow(described_class::ROOT).to receive(:join).with('cov-loupe-1.2.3.gem')
        .and_return(fake_gem)

      # Stub puts to avoid noise
      allow($stdout).to receive(:puts)
      allow($stdout).to receive(:print)
    end

    # Helper to mock run! output for specific commands
    def mock_command(cmd, output)
      status_double = instance_double(Process::Status, success?: true)
      thread_double = instance_double(Thread, value: status_double)

      # Mock popen2e for streamed commands
      allow(Open3).to receive(:popen2e).with(cmd).and_yield(nil, [output], thread_double)

      # Mock capture2 for captured commands
      allow(Open3).to receive(:capture2).with(cmd).and_return([output, status_double])
    end

    it 'runs through the checklist successfully' do
      # 1. Clean git
      mock_command('git status --porcelain', '')
      # 2. Main branch
      mock_command('git rev-parse --abbrev-ref HEAD', 'main')
      # 3. Sync
      mock_command('git fetch origin --tags', '')
      mock_command('git rev-parse HEAD', 'sha1')
      mock_command('git rev-parse origin/main', 'sha1')
      # 4. CI passed
      mock_command('gh workflow run test.yml --ref main', '')
      allow(script).to receive(:sleep) # Don't sleep in tests
      mock_command(
        'gh run list --workflow=test.yml --branch=main --limit=1 --json databaseId ' \
        "--jq '.[0].databaseId'",
        '999'
      )
      mock_command('gh run watch 999 --exit-status', '')
      # 5. Tag check
      mock_command('git tag -l v1.2.3', '')
      # 6. Gem build
      mock_command('gem build cov-loupe.gemspec', '')

      expect { script.call }.not_to raise_error
      expect($stdout).to have_received(:puts).with('✓ Gem built successfully')
    end

    it 'aborts if git is not clean' do
      mock_command('git status --porcelain', 'M lib/foo.rb')
      expect { script.call }.to raise_error(SystemExit)
    end

    it 'aborts if not on main branch' do
      mock_command('git status --porcelain', '')
      mock_command('git rev-parse --abbrev-ref HEAD', 'feature-branch')
      expect { script.call }.to raise_error(SystemExit)
    end

    it 'aborts if local is behind remote' do
      mock_command('git status --porcelain', '')
      mock_command('git rev-parse --abbrev-ref HEAD', 'main')
      mock_command('git fetch origin --tags', '')
      mock_command('git rev-parse HEAD', 'sha1')
      mock_command('git rev-parse origin/main', 'sha2')
      mock_command('git merge-base HEAD origin/main', 'sha1') # base == local (behind)

      expect { script.call }.to raise_error(SystemExit)
    end

    it 'aborts if local is ahead of remote' do
      mock_command('git status --porcelain', '')
      mock_command('git rev-parse --abbrev-ref HEAD', 'main')
      mock_command('git fetch origin --tags', '')
      mock_command('git rev-parse HEAD', 'sha1')
      mock_command('git rev-parse origin/main', 'sha2')
      mock_command('git merge-base HEAD origin/main', 'sha2') # base == remote (ahead)

      expect { script.call }.to raise_error(SystemExit)
    end

    it 'aborts if local has diverged from remote' do
      mock_command('git status --porcelain', '')
      mock_command('git rev-parse --abbrev-ref HEAD', 'main')
      mock_command('git fetch origin --tags', '')
      mock_command('git rev-parse HEAD', 'sha1')
      mock_command('git rev-parse origin/main', 'sha2')
      mock_command('git merge-base HEAD origin/main', 'sha3') # base != local and != remote (diverged)

      expect { script.call }.to raise_error(SystemExit)
    end

    it 'aborts if release notes are missing' do
      mock_command('git status --porcelain', '')
      mock_command('git rev-parse --abbrev-ref HEAD', 'main')
      mock_command('git fetch origin --tags', '')
      mock_command('git rev-parse HEAD', 'sha1')
      mock_command('git rev-parse origin/main', 'sha1')
      mock_command('gh workflow run test.yml --ref main', '')
      allow(script).to receive(:sleep)
      mock_command(
        'gh run list --workflow=test.yml --branch=main --limit=1 --json databaseId ' \
        "--jq '.[0].databaseId'",
        '999'
      )
      mock_command('gh run watch 999 --exit-status', '')
      mock_command('git tag -l v1.2.3', '')

      # Override release notes to not include the expected header
      allow(release_notes).to receive(:read).and_return("## v1.0.0\n\n- Old changes")

      expect { script.call }.to raise_error(SystemExit)
    end
  end
end
# rubocop:enable RSpec/SubjectStub
