# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  it 'renders uncovered source without error for fixture file' do
    out, err, status = run_cli_with_status(
      'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=uncovered', '--source-context', '1', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq('')
    expect(out).to match(/File:\s+lib\/foo\.rb/)
    expect(out).to match(/Uncovered lines:\s*2\b/)
    expect(out).to show_source_table_or_fallback
  end

  it 'renders full source for uncovered command without brittle spacing' do
    out, err, status = run_cli_with_status(
      'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=full', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq('')
    # Summary line with flexible spacing
    expect(out).to match(/Summary:\s*\d+\.\d{2}%\s*\d+\/\d+/)
    expect(out).to show_source_table_or_fallback
  end

  it 'renders source for summary with uncovered mode without crashing' do
    out, err, status = run_cli_with_status(
      'summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=uncovered', '--source-context', '1', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq('')
    expect(out).to include('lib/foo.rb')
    # Presence of percentage and counts, spacing-agnostic
    expect(out).to match(/66\.67%/)
    expect(out).to match(/\b2\/3\b/)
    expect(out).to show_source_table_or_fallback
  end

  context 'source option without equals sign' do
    it 'parses --source uncovered correctly (space-separated argument)' do
      out, err, status = run_cli_with_status(
        'summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
        '--source', 'uncovered', '--source-context', '1', '--no-color'
      )
      expect(status).to eq(0)
      expect(err).to eq('')
      expect(out).to include('lib/foo.rb')
      expect(out).to match(/66\.67%/)
      expect(out).to match(/\b2\/3\b/)
      expect(out).to show_source_table_or_fallback
    end

    it 'parses -s full correctly (short form with space-separated argument)' do
      out, err, status = run_cli_with_status(
        'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
        '-s', 'full', '--no-color'
      )
      expect(status).to eq(0)
      expect(err).to eq('')
      expect(out).to match(/Summary:\s*\d+\.\d{2}%\s*\d+\/\d+/)
      expect(out).to show_source_table_or_fallback
    end

    it 'handles --source uncovered in default report (no subcommand)' do
      out, err, status = run_cli_with_status(
        '--root', root, '--resultset', 'coverage',
        '--source', 'uncovered', '--no-color'
      )
      expect(status).to eq(0)
      expect(err).to eq('')
      expect(out).to match(/66\.67%/)
      # Default report doesn't show source tables, that's OK - just check it parses correctly
      expect(out).not_to include('Unknown subcommand')
    end

    it 'does not misinterpret following token as subcommand when using --source' do
      # This test specifically addresses the bug where --source uncovered
      # was interpreting 'uncovered' as a subcommand
      out, err, status = run_cli_with_status(
        '--root', root, '--resultset', 'coverage',
        '--source', 'uncovered'
      )
      expect(status).to eq(0)
      expect(err).to eq('')
      expect(out).not_to include('Unknown subcommand')
      expect(out).to match(/66\.67%/)
    end
  end
end
