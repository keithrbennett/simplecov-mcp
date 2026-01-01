# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:cli) { described_class.new }

  before do
    cli.config.root = root
    cli.config.resultset = FIXTURE_PROJECT1_RESULTSET_PATH
    cli.config.raise_on_stale = false
    cli.config.tracked_globs = nil
  end

  describe '#show_default_report' do
    it 'prints JSON summary using relativized payload when json mode is enabled' do
      cli.config.format = :json

      output = nil
      silence_output do |stdout, _stderr|
        cli.show_default_report(sort_order: :ascending, output: stdout)
        output = stdout.string
      end

      payload = JSON.parse(output)

      expect(payload['files']).to be_an(Array)
      expect(payload['files'].first['file']).to eq('lib/bar.rb').or eq('lib/foo.rb')
      expect(payload['counts']).to include('total', 'ok', 'stale')
    end

    context 'when coverage rows are skipped due to errors' do
      let(:foo_path) { File.expand_path('lib/foo.rb', root) }

      before do
        cli.config.format = :table

        # Make the entry malformed for foo.rb so it falls back to the resolver
        # This needs to be done after the model is created, so we'll use a callback
        allow(CovLoupe::CoverageModel).to receive(:new).and_wrap_original do |method, **kwargs|
          model = method.call(**kwargs)
          cov = model.instance_variable_get(:@cov)
          cov[foo_path] = 'malformed_entry' # Not a Hash with 'lines' key
          model
        end

        allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:lookup_lines).and_wrap_original \
        do |method, coverage_map, abs_path, **kwargs|
          raise CovLoupe::CoverageDataError, 'corrupt data' if abs_path == foo_path

          method.call(coverage_map, abs_path, **kwargs)
        end
      end

      it 'prints a warning to stderr listing the skipped file' do
        warnings = nil
        silence_output do |stdout, stderr|
          cli.show_default_report(sort_order: :ascending, output: stdout)
          warnings = stderr.string
        end

        expect(warnings).to include('WARNING: 1 coverage row skipped due to errors')
        expect(warnings).to include('lib/foo.rb')
        expect(warnings).to include('corrupt data')
      end

      it 'raises immediately when raise-on-stale is enabled' do
        cli.config.raise_on_stale = true

        expect do
          silence_output do |stdout, _stderr|
            cli.show_default_report(sort_order: :ascending, output: stdout)
          end
        end.to raise_error(CovLoupe::CoverageDataError, /corrupt data/)
      end
    end

    context 'when exclusions include deleted files' do
      let(:presenter) do
        instance_double(
          CovLoupe::Presenters::ProjectCoveragePresenter,
          relative_files: [],
          relative_missing_tracked_files: [],
          relative_newer_files: [],
          relative_deleted_files: ['lib/old.rb'],
          relative_length_mismatch_files: [],
          relative_unreadable_files: [],
          relative_skipped_files: []
        )
      end

      before do
        cli.config.format = :table
        # Allow the model to be created naturally, only mock the presenter
        allow(CovLoupe::Presenters::ProjectCoveragePresenter).to receive(:new) do |model:, **_opts|
          # Stub model methods that are called in show_default_report
          allow(model).to receive_messages(format_table: "table\n", skipped_rows: [])
          presenter
        end
      end

      it 'prints the deleted files section in the exclusions summary' do
        output = nil
        silence_output do |stdout, _stderr|
          cli.show_default_report(sort_order: :ascending, output: stdout)
          output = stdout.string
        end

        expect(output).to include(
          'Files excluded from coverage:',
          'Deleted files with coverage (1):',
          '  - lib/old.rb'
        )
      end
    end
  end
end
