# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/tools/coverage_table_tool'

RSpec.describe CovLoupe::Tools::CoverageTableTool do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:server_context) { null_server_context }

  before do
    setup_mcp_response_stub
  end

  def run_tool(raise_on_stale: false)
    # Let real CoverageModel work to test actual format_table behavior
    described_class.call(root: root, raise_on_stale: raise_on_stale,
      server_context: server_context).payload.first['text']
  end

  it 'returns a formatted table as a string' do
    output = run_tool

    # Contains table structure, headers, and file data
    expect(output).to include(
      '┌', '┬', '┐', '│', '├', '┼', '┤', '└', '┴', '┘',
      'File', 'Covered', 'Total', ' │ Stale │',
      'lib/foo.rb', 'lib/bar.rb',
      'Files: total 2, ok 2, stale 0'
    )
  end

  it 'configures CLI to enforce stale checking when requested' do
    model = instance_double(CovLoupe::CoverageModel)
    files = [
      { 'file' => "#{root}/lib/foo.rb", 'percentage' => 100.0, 'covered' => 10, 'total' => 10,
        'stale' => 'ok' }
    ]
    payload = {
      'files' => files,
      'skipped_files' => [],
      'missing_tracked_files' => [],
      'newer_files' => [],
      'deleted_files' => [],
      'length_mismatch_files' => [],
      'unreadable_files' => []
    }
    allow(model).to receive(:relativize) { |p| p }

    relativizer = instance_double(CovLoupe::PathRelativizer)
    allow(relativizer).to receive(:relativize_path).and_return('lib/foo.rb')
    allow(model).to receive_messages(list: payload, format_table: 'Mock table output', skipped_rows: [],
      relativizer: relativizer)

    allow(CovLoupe::CoverageModel).to receive(:new).with(
      root: root,
      resultset: nil,
      raise_on_stale: true,
      tracked_globs: []
    ).and_return(model)

    described_class.call(root: root, raise_on_stale: true, server_context: server_context)

    expect(CovLoupe::CoverageModel).to have_received(:new).with(
      root: root,
      resultset: nil,
      raise_on_stale: true,
      tracked_globs: []
    )
    expect(model).to have_received(:format_table)
  end

  it 'uses descending sort order by default' do
    model = instance_double(CovLoupe::CoverageModel)
    allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
    payload = {
      'files' => [],
      'skipped_files' => [],
      'missing_tracked_files' => [],
      'newer_files' => [],
      'deleted_files' => [],
      'length_mismatch_files' => [],
      'unreadable_files' => []
    }
    allow(model).to receive(:relativize) { |p| p }

    relativizer = instance_double(CovLoupe::PathRelativizer)
    allow(model).to receive_messages(list: payload, format_table: 'Mock table', skipped_rows: [],
      relativizer: relativizer)

    described_class.call(root: root, server_context: server_context)

    expect(model).to have_received(:format_table).with(
      anything, hash_including(sort_order: :descending)
    )
  end

  describe 'sort_order parameter validation' do
    it 'accepts valid values: ascending, descending, a, d' do
      model = instance_double(CovLoupe::CoverageModel)
      allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
      payload = {
        'files' => [],
        'skipped_files' => [],
        'missing_tracked_files' => [],
        'newer_files' => [],
        'deleted_files' => [],
        'length_mismatch_files' => [],
        'unreadable_files' => []
      }
      allow(model).to receive(:relativize) { |p| p }

      relativizer = instance_double(CovLoupe::PathRelativizer)
      allow(model).to receive_messages(list: payload, format_table: 'Mock table', skipped_rows: [],
        relativizer: relativizer)

      %w[ascending descending a d].each do |sort_order|
        response = described_class.call(
          root: root,
          sort_order: sort_order,
          server_context: server_context
        )
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.payload.first['type']).to eq('text')
      end
    end

    it 'rejects invalid sort_order values' do
      response = described_class.call(
        root: root,
        sort_order: 'invalid',
        server_context: server_context
      )
      expect(response).to be_a(MCP::Tool::Response)
      text = response.payload.first['text']
      expect(text).to include('Error')
      expect(text).to include('invalid')
    end
  end

  describe 'CLI context parity' do
    describe 'exclusion scenarios' do
      let(:model) { instance_double(CovLoupe::CoverageModel) }
      let(:relativizer) { instance_double(CovLoupe::PathRelativizer) }
      let(:presenter) { instance_double(CovLoupe::Presenters::ProjectCoveragePresenter) }
      let(:presenter_data) do
        {
          relative_files: [],
          relative_missing_tracked_files: [],
          relative_newer_files: [],
          relative_deleted_files: [],
          relative_length_mismatch_files: [],
          relative_unreadable_files: [],
          relative_skipped_files: []
        }
      end

      before do
        allow(model).to receive_messages(
          relativizer: relativizer,
          skipped_rows: [],
          format_table: 'Mock table'
        )
        allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
        allow(CovLoupe::Presenters::ProjectCoveragePresenter).to receive(:new).and_return(presenter)
        allow(presenter).to receive_messages(**presenter_data)
      end

      it 'includes exclusions summary when tracked files are missing' do
        allow(presenter).to receive_messages(
          presenter_data.merge(relative_missing_tracked_files: ['lib/uncovered_file.rb'])
        )

        output = described_class.call(
          root: root,
          tracked_globs: ['lib/**/*.rb'],
          server_context: server_context
        ).payload.first['text']

        # Should include the exclusions summary for missing tracked file
        expect(output).to include(
          'Files excluded from coverage:',
          'Missing tracked files',
          'lib/uncovered_file.rb',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes exclusions summary for files newer than coverage data' do
        allow(presenter).to receive_messages(
          presenter_data.merge(relative_newer_files: ['lib/newer_file.rb'])
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        expect(output).to include(
          'Files excluded from coverage:',
          'Files newer than coverage',
          '(1)',
          'lib/newer_file.rb',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes exclusions summary for deleted files with coverage' do
        allow(presenter).to receive_messages(
          presenter_data.merge(relative_deleted_files: ['lib/deleted_file.rb', 'lib/another_deleted.rb'])
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        expect(output).to include(
          'Files excluded from coverage:',
          'Deleted files with coverage',
          '(2)',
          'lib/deleted_file.rb',
          'lib/another_deleted.rb',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes exclusions summary for line count mismatches' do
        allow(presenter).to receive_messages(
          presenter_data.merge(relative_length_mismatch_files: ['lib/mismatch_file.rb'])
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        expect(output).to include(
          'Files excluded from coverage:',
          'Line count mismatches',
          '(1)',
          'lib/mismatch_file.rb',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes exclusions summary for unreadable files' do
        allow(presenter).to receive_messages(
          presenter_data.merge(relative_unreadable_files: ['lib/permission_denied.rb'])
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        expect(output).to include(
          'Files excluded from coverage:',
          'Unreadable files',
          '(1)',
          'lib/permission_denied.rb',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes exclusions summary for files skipped due to errors' do
        allow(relativizer).to receive(:relativize_path)
          .with('/some/path/bad_file.rb')
          .and_return('bad_file.rb')
        allow(relativizer).to receive(:relativize_path)
          .with('/some/path/another_bad.rb')
          .and_return('another_bad.rb')
        allow(presenter).to receive_messages(
          presenter_data.merge(
            relative_skipped_files: [
              { 'file' => '/some/path/bad_file.rb', 'error' => 'Invalid coverage data' },
              { 'file' => '/some/path/another_bad.rb', 'error' => 'Corrupt entry' }
            ]
          )
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        expect(output).to include(
          'Files excluded from coverage:',
          'Files skipped due to errors',
          '(2)',
          'bad_file.rb: Invalid coverage data',
          'another_bad.rb: Corrupt entry',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'includes all exclusion types in a single summary' do
        allow(relativizer).to receive(:relativize_path).with('/some/path/skipped.rb').and_return('skipped.rb')
        allow(presenter).to receive_messages(
          presenter_data.merge(
            relative_missing_tracked_files: ['lib/missing.rb'],
            relative_newer_files: ['lib/newer.rb'],
            relative_deleted_files: ['lib/deleted.rb'],
            relative_length_mismatch_files: ['lib/mismatch.rb'],
            relative_unreadable_files: ['lib/unreadable.rb'],
            relative_skipped_files: [{ 'file' => '/some/path/skipped.rb', 'error' => 'Error' }]
          )
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        # Should include all exclusion types
        expect(output).to include(
          'Files excluded from coverage:',
          'Missing tracked files',
          'Files newer than coverage',
          'Deleted files with coverage',
          'Line count mismatches',
          'Unreadable files',
          'Files skipped due to errors',
          'Run with --raise-on-stale to exit when files are excluded.'
        )
      end

      it 'accurately counts files in each exclusion category' do
        allow(presenter).to receive_messages(
          presenter_data.merge(
            relative_missing_tracked_files: ['lib/missing1.rb', 'lib/missing2.rb', 'lib/missing3.rb'],
            relative_newer_files: ['lib/newer.rb']
          )
        )

        output = described_class.call(
          root: root,
          server_context: server_context
        ).payload.first['text']

        # Should show correct counts
        expect(output).to include('Missing tracked files (3)', 'Files newer than coverage (1)')
      end
    end

    it 'does not include exclusions summary when there are no exclusions' do
      output = run_tool

      # Should not include exclusions summary when no files are missing/stale/deleted
      expect(output).not_to include('Files excluded from coverage:')
      expect(output).not_to include('Run with --raise-on-stale to exit when files are excluded.')
    end

    it 'includes skipped rows warning when rows are skipped' do
      # Create a model with skipped rows
      model = instance_double(CovLoupe::CoverageModel)
      relativizer = instance_double(CovLoupe::PathRelativizer)
      allow(relativizer).to receive(:relativize_path).with('/some/path/file.rb').and_return('file.rb')
      allow(model).to receive_messages(relativizer: relativizer, skipped_rows: [
        { 'file' => '/some/path/file.rb', 'error' => 'Test error' }
      ], format_table: 'Mock table')

      # Create a presenter that returns data
      presenter = instance_double(CovLoupe::Presenters::ProjectCoveragePresenter)
      allow(presenter).to receive_messages(
        relative_files: [], relative_missing_tracked_files: [],
        relative_newer_files: [], relative_deleted_files: [],
        relative_length_mismatch_files: [], relative_unreadable_files: [],
        relative_skipped_files: []
      )

      allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
      allow(CovLoupe::Presenters::ProjectCoveragePresenter).to receive(:new).and_return(presenter)

      output = described_class.call(
        root: root,
        server_context: server_context
      ).payload.first['text']

      # Should include skipped rows warning
      expect(output).to include('WARNING: 1 coverage row skipped due to errors:')
      expect(output).to include('file.rb: Test error')
      expect(output).to include('Run again with --raise-on-stale to exit when rows are skipped.')
    end

    it 'does not include skipped rows warning when no rows are skipped' do
      output = run_tool

      # Should not include skipped rows warning when no rows are skipped
      expect(output).not_to include('WARNING:')
      expect(output).not_to include('coverage row')
      expect(output).not_to include('Run again with --raise-on-stale to exit when rows are skipped.')
    end

    it 'matches CLI --table output structure' do
      # Run the tool with tracked_globs to trigger exclusions
      output = described_class.call(
        root: root,
        tracked_globs: ['lib/**/*.rb'],
        server_context: server_context
      ).payload.first['text']

      # Should have the table first
      expect(output).to include('┌', '┬', '┐', '│', '├', '┼', '┤', '└', '┴', '┘')
      expect(output).to include('File', 'Covered', 'Total')

      # Then the exclusions summary
      expect(output).to include('Files excluded from coverage:')

      # Verify order: table comes before exclusions
      table_index = output.index('File')
      exclusions_index = output.index('Files excluded from coverage:')
      expect(table_index).to be < exclusions_index
    end
  end
end
