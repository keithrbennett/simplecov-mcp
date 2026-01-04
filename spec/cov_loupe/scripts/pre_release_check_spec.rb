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
    end

    # Helper to mock run! output for specific commands
    def mock_command(cmd, output)
      status_double = instance_double(Process::Status, success?: true)
      thread_double = instance_double(Thread, value: status_double)

      # Mock popen2e for streamed commands
      if cmd.is_a?(Array)
        allow(Open3).to receive(:popen2e).with(*cmd).and_yield(nil, [output], thread_double)
      else
        allow(Open3).to receive(:popen2e).with(cmd).and_yield(nil, [output], thread_double)
      end

      # Mock capture2 for captured commands
      if cmd.is_a?(Array)
        allow(Open3).to receive(:capture2).with(*cmd).and_return([output, status_double])
      else
        allow(Open3).to receive(:capture2).with(cmd).and_return([output, status_double])
      end
    end

    def mock_commands(command_outputs)
      command_outputs.each { |cmd, output| mock_command(cmd, output) }
    end

    def git_clean_commands(status: '')
      [[%w[git status --porcelain], status]]
    end

    def branch_commands(name)
      [[%w[git rev-parse --abbrev-ref HEAD], name]]
    end

    def sync_commands(local:, remote:, base: nil)
      commands = [
        [%w[git fetch origin --tags], ''],
        [%w[git rev-parse HEAD], local],
        [%w[git rev-parse origin/main], remote]
      ]
      commands << [%w[git merge-base HEAD origin/main], base] if base
      commands
    end

    def ci_commands(run_id: '999')
      [
        [%w[gh workflow run test.yml --ref main], ''],
        [%w[gh run list --workflow test.yml --branch main --limit 1] \
           + %w[--json databaseId --jq .[0].databaseId], run_id],
        [['gh', 'run', 'watch', run_id, '--exit-status'], '']
      ]
    end

    def tag_check_commands(tag = 'v1.2.3')
      [[['git', 'tag', '-l', tag], '']]
    end

    it 'runs through the checklist successfully' do
      mock_commands(
        git_clean_commands +
        branch_commands('main') +
        sync_commands(local: 'sha1', remote: 'sha1') +
        ci_commands +
        tag_check_commands
      )
      allow(script).to receive(:sleep) # Don't sleep in tests
      # 6. Gem build
      mock_command(%w[gem build cov-loupe.gemspec], '')

      silence_output do
        expect { script.call }.not_to raise_error
        expect($stdout.string).to include('✓ Gem built successfully')
      end
    end

    it 'aborts if git is not clean' do
      mock_commands(git_clean_commands(status: 'M lib/foo.rb'))
      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include(
          'Uncommitted changes present. Commit or stash before releasing.'
        )
      end
    end

    it 'aborts if not on main branch' do
      mock_commands(git_clean_commands + branch_commands('feature-branch'))
      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include('Releases must be cut from the main branch.')
      end
    end

    it 'aborts if local is behind remote' do
      mock_commands(
        git_clean_commands +
        branch_commands('main') +
        sync_commands(local: 'sha1', remote: 'sha2', base: 'sha1') # base == local (behind)
      )

      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include('Local main is behind origin. Pull before releasing.')
      end
    end

    it 'aborts if local is ahead of remote' do
      mock_commands(
        git_clean_commands +
        branch_commands('main') +
        sync_commands(local: 'sha1', remote: 'sha2', base: 'sha2') # base == remote (ahead)
      )

      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include('Local main is ahead of origin. Push before releasing.')
      end
    end

    it 'aborts if local has diverged from remote' do
      mock_commands(
        git_clean_commands +
        branch_commands('main') +
        sync_commands(local: 'sha1', remote: 'sha2', base: 'sha3') # base != local and != remote (diverged)
      )

      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include(
          'Local main has diverged from origin. Reconcile before releasing.'
        )
      end
    end

    it 'aborts if release notes are missing' do
      mock_commands(
        git_clean_commands +
        branch_commands('main') +
        sync_commands(local: 'sha1', remote: 'sha1') +
        ci_commands +
        tag_check_commands
      )
      allow(script).to receive(:sleep)

      # Override release notes to not include the expected header
      allow(release_notes).to receive(:read).and_return("## v1.0.0\n\n- Old changes")

      silence_output do
        expect { script.call }.to raise_error(SystemExit)
        expect($stderr.string).to include("Add a '## v1.2.3' section to RELEASE_NOTES.md before releasing.")
      end
    end
  end
end
# rubocop:enable RSpec/SubjectStub
