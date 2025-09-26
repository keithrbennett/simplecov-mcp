# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  it 'shows help and exits 0' do
    out, err, status = run_cli_with_status('--help')
    expect(status).to eq(0)
    expect(out).to include('Usage: simplecov-mcp')
    expect(err).to eq("")
  end

  shared_examples 'maps error to exit 1 with message' do
    before do
      # Build a fake model that raises the specified error from the specified method
      fake_model = Class.new do
        def initialize(*) end
      end
      error_to_raise = raised_error
      fake_model.define_method(model_method) { |*| raise error_to_raise }
      stub_const('SimpleCovMcp::CoverageModel', fake_model)
    end

    it 'exits with status 1 and friendly message' do
      _out, err, status = run_cli_with_status(*invoke_args)
      expect(status).to eq(1)
      expect(err).to include(expected_message)
    end
  end

  context 'ENOENT mapping' do
    let(:model_method) { :summary_for }
    let(:raised_error) { Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb') }
    let(:invoke_args) { ['summary', 'lib/missing.rb', '--root', root, '--resultset', 'coverage'] }
    let(:expected_message) { 'File error: File not found: lib/missing.rb' }
    include_examples 'maps error to exit 1 with message'
  end

  context 'EACCES mapping' do
    let(:model_method) { :raw_for }
    let(:raised_error) { Errno::EACCES.new('Permission denied @ rb_sysopen - secret.rb') }
    let(:invoke_args) { ['raw', 'lib/secret.rb', '--root', root, '--resultset', 'coverage'] }
    let(:expected_message) { 'Permission denied: lib/secret.rb' }
    include_examples 'maps error to exit 1 with message'
  end

  it 'emits detailed stale coverage info and exits 1' do
    begin
      mock_resultset_with_timestamp(root, VERY_OLD_TIMESTAMP, coverage: {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, 1] }
      })
      _out, err, status = run_cli_with_status('summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--stale', 'error')
      expect(status).to eq(1)
      expect(err).to include('Coverage data stale:')
      expect(err).to match(/File\s+- time:/)
      expect(err).to match('Coverage\s+- time:')
      expect(err).to match(/Delta\s+- file is [+-]?\d+s newer than coverage/)
      expect(err).to match('Resultset\s+-')
    ensure
    end
  end

  it 'honors --no-strict-staleness to disable checks' do
    begin
      mock_resultset_with_timestamp(root, VERY_OLD_TIMESTAMP, coverage: {
        File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, 1] }
      })
      _out, err, status = run_cli_with_status('summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--stale', 'off')
      expect(status).to eq(0)
      expect(err).to eq("")
    ensure
    end
  end

  it 'handles source rendering errors gracefully with fallback message' do
    # Test that source rendering with problematic coverage data doesn't crash
    # This is a regression test for the "can't convert nil into Integer" crash
    # that was previously mentioned in comments
    out, err, status = run_cli_with_status(
      'uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=uncovered', '--source-context', '2', '--no-color'
    )
    
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to match(/File:\s+lib\/foo\.rb/)
    expect(out).to include('Uncovered lines: 2')
    expect(out).to show_source_table_or_fallback
  end
  
  it 'renders source with full mode without crashing' do
    # Additional regression test for source rendering with full mode
    out, err, status = run_cli_with_status(
      'summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
      '--source=full', '--no-color'
    )
    
    expect(status).to eq(0)
    expect(err).to eq("")
    expect(out).to include('lib/foo.rb')
    expect(out).to include('66.67%')
    expect(out).to show_source_table_or_fallback
  end
  
  it 'shows fallback message when source file is unreadable' do
    # Test the fallback path when source files can't be read
    # Temporarily rename the source file to make it unreadable
    foo_path = File.join(root, 'lib', 'foo.rb')
    temp_path = "#{foo_path}.hidden"
    
    begin
      File.rename(foo_path, temp_path) if File.exist?(foo_path)
      
      out, err, status = run_cli_with_status(
        'summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage',
        '--source=full', '--no-color'
      )
      
      expect(status).to eq(0)
      expect(err).to eq("")
      expect(out).to include('lib/foo.rb')
      expect(out).to include('66.67%')
      expect(out).to include('[source not available]')
    ensure
      # Restore the file
      File.rename(temp_path, foo_path) if File.exist?(temp_path)
    end
  end
end
