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
  end
end
