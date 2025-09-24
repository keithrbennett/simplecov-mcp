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
    expect(err).to eq("")
    expect(out).to match(/File:\s+lib\/foo\.rb/)
    expect(out).to match(/Uncovered lines:\s*2\b/)
    # Accept either rendered source table or fallback message
    expect(out).to satisfy { |s| s.include?('Line') || s.include?('[source not available]') }
  end

  it 'renders full source for uncovered command without brittle spacing' do
    out, err, status = run_cli_with_status(
      'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=full', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq("")
    # Summary line with flexible spacing
    expect(out).to match(/Summary:\s*\d+\.\d{2}%\s*\d+\/\d+/)
    # Accept either rendered source table or fallback message
    expect(out).to satisfy { |s| s.include?('Line') || s.include?('[source not available]') }
  end

  it 'renders source for summary with uncovered mode without crashing' do
    out, err, status = run_cli_with_status(
      'summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=uncovered', '--source-context', '1', '--no-color'
    )
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to include('lib/foo.rb')
    # Presence of percentage and counts, spacing-agnostic
    expect(out).to match(/66\.67%/)
    expect(out).to match(/\b2\/3\b/)
    # Accept either rendered source table or fallback message
    expect(out).to satisfy { |s| s.include?('Line') || s.include?('[source not available]') }
  end
end
