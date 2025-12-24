# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative 'command_execution'

module CovLoupe
  module Scripts
    class PreReleaseCheck
      include CommandExecution

      ROOT = Pathname.new(__dir__).join('../../..').expand_path

      def call
        Dir.chdir(ROOT) do
          verify_git_clean!
          puts '✓ Git working tree is clean'

          verify_branch!
          puts '✓ On main branch'

          verify_sync!
          puts '✓ Local branch is in sync with origin/main'

          verify_ci_passed!
          puts '✓ GitHub Actions CI passed'

          @version = fetch_version
          @tag_name = "v#{@version}"
          puts "✓ Preparing release for version #{@version}"

          verify_release_notes!
          puts "✓ Release notes found for #{@tag_name}"

          verify_tag_new!
          puts "✓ Tag #{@tag_name} does not yet exist"

          build_gem!
          puts '✓ Gem built successfully'

          puts "\nBuild complete! To finish the release, run:"
          puts
          puts "  git tag -a #{@tag_name} -m 'Version #{@version}'"
          puts '  git push origin main --follow-tags'
          puts "  gem push #{@gem_file.basename}"
          puts
          puts 'Then draft the GitHub release via the web UI.'
        end
      end

      private def verify_git_clean!
        status = run_command(%w[git status --porcelain], print_output: false)
        unless status.strip.empty?
          abort_with('Uncommitted changes present. Commit or stash before releasing.')
        end
      end

      private def verify_branch!
        current_branch = run_command(%w[git rev-parse --abbrev-ref HEAD], print_output: false).strip
        abort_with('Releases must be cut from the main branch.') unless current_branch == 'main'
      end

      private def verify_sync!
        run_command(%w[git fetch origin --tags], print_output: true)
        local = run_command(%w[git rev-parse HEAD], print_output: false).strip
        remote = run_command(%w[git rev-parse origin/main], print_output: false).strip
        return if local == remote

        base = run_command(%w[git merge-base HEAD origin/main], print_output: false).strip

        if base == local
          abort_with('Local main is behind origin. Pull before releasing.')
        elsif base == remote
          abort_with('Local main is ahead of origin. Push before releasing.')
        else
          abort_with('Local main has diverged from origin. Reconcile before releasing.')
        end
      end

      private def verify_ci_passed!
        run_command(%w[gh workflow run test.yml --ref main], print_output: true)
        puts 'Waiting for workflow to initialize...'
        sleep 5

        run_id = run_command(
          %w[gh run list --workflow test.yml --branch main --limit 1] \
            + %w[--json databaseId --jq .[0].databaseId],
          print_output: false
        ).strip
        abort_with('Failed to retrieve the CI run ID.') if run_id.empty?

        puts "Monitoring CI build (Run ID: #{run_id})..."
        run_command(['gh', 'run', 'watch', run_id, '--exit-status'], print_output: true)
      end

      private def fetch_version
        version_file = ROOT.join('lib/cov_loupe/version.rb')
        version_source = version_file.read
        version = version_source[/VERSION\s*=\s*["'](.+?)["']/, 1]
        abort_with("Could not find VERSION constant in #{version_file}") unless version
        version
      end

      private def verify_release_notes!
        release_notes = ROOT.join('RELEASE_NOTES.md').read
        header = "## #{@tag_name}"
        unless release_notes.include?(header)
          abort_with("Add a '#{header}' section to RELEASE_NOTES.md before releasing.")
        end
      end

      private def verify_tag_new!
        existing_tag = run_command(['git', 'tag', '-l', @tag_name], print_output: false)
          .split("\n").include?(@tag_name)
        abort_with("Tag #{@tag_name} already exists. Bump the version before releasing.") if existing_tag
      end

      private def build_gem!
        @gem_file = ROOT.join("cov-loupe-#{@version}.gem")
        FileUtils.rm_f(@gem_file)
        run_command(%w[gem build cov-loupe.gemspec], print_output: true)
        abort_with("Gem file #{@gem_file} not found after build.") unless @gem_file.exist?
      end
    end
  end
end
