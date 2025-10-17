# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::ErrorHandler do
  let(:logger) do
    Class.new do
      attr_reader :messages
      def initialize; @messages = []; end
      def error(msg); @messages << msg; end
    end.new
  end

  subject(:handler) { described_class.new(error_mode: :on, logger: logger) }

  it 'maps filesystem errors to friendly custom errors' do
    e = handler.convert_standard_error(Errno::EISDIR.new('Is a directory @ rb_sysopen - a_dir'))
    expect(e).to be_a(SimpleCovMcp::NotAFileError)

    e = handler.convert_standard_error(
      Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.txt')
    )
    expect(e).to be_a(SimpleCovMcp::FileNotFoundError)

    e = handler.convert_standard_error(Errno::EACCES.new('Permission denied @ rb_sysopen - secret'))
    expect(e).to be_a(SimpleCovMcp::FilePermissionError)
  end

  it 'maps JSON::ParserError to CoverageDataError' do
    e = handler.convert_standard_error(JSON::ParserError.new('unexpected token'))
    expect(e).to be_a(SimpleCovMcp::CoverageDataError)
    expect(e.user_friendly_message).to include('Invalid coverage data format')
  end

  it 'maps ArgumentError by message' do
    e = handler.convert_standard_error(
      ArgumentError.new('wrong number of arguments (given 1, expected 2)')
    )
    expect(e).to be_a(SimpleCovMcp::UsageError)

    e = handler.convert_standard_error(ArgumentError.new('invalid option'))
    expect(e).to be_a(SimpleCovMcp::ConfigurationError)
  end

  it 'maps NoMethodError to CoverageDataError with helpful info' do
    e = handler.convert_standard_error(
      NoMethodError.new("undefined method `fetch' for #<Hash:0x123>")
    )
    expect(e).to be_a(SimpleCovMcp::CoverageDataError)
    expect(e.user_friendly_message).to include('Invalid coverage data structure')
  end

  it 'maps runtime strings from util to friendly errors' do
    e = handler.convert_standard_error(
      RuntimeError.new('Could not find .resultset.json under /path; run tests')
    )
    expect(e).to be_a(SimpleCovMcp::CoverageDataError)
    expect(e.user_friendly_message).to include('run your tests first')

    e = handler.convert_standard_error(
      RuntimeError.new('No .resultset.json found in directory: /path')
    )
    expect(e).to be_a(SimpleCovMcp::CoverageDataError)

    e = handler.convert_standard_error(
      RuntimeError.new('Specified resultset not found: /nowhere/file.json')
    )
    expect(e).to be_a(SimpleCovMcp::ResultsetNotFoundError)
  end

  it 'logs via provided logger' do
    begin
      handler.handle_error(Errno::ENOENT.new('No such file or directory @ rb_sysopen - x'),
        context: 'test', reraise: false)
    rescue StandardError
      # reraise disabled
    end
    expect(logger.messages.join).to include('Error in test')
  end
end
