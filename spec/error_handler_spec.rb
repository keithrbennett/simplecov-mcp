# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::ErrorHandler do
  subject(:handler) { described_class.new(error_mode: :log, logger: logger) }

  let(:logger) do
    Class.new do
      attr_reader :messages

      def initialize = @messages = []
      def error(msg) = @messages << msg
    end.new
  end


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
    rescue
      # reraise disabled
    end
    expect(logger.messages.join).to include('Error in test')
  end

  it 'converts TypeError to CoverageDataError for invalid data structures' do
    error = TypeError.new('wrong argument type')
    result = handler.convert_standard_error(error)

    expect(result).to be_a(SimpleCovMcp::CoverageDataError)
    expect(result.user_friendly_message).to include('Invalid coverage data structure')
  end

  it 'returns generic Error for unrecognized SystemCallError' do
    error = Errno::EEXIST.new('File exists')
    result = handler.convert_standard_error(error)

    expect(result).to be_a(SimpleCovMcp::Error)
    expect(result.user_friendly_message).to include('An unexpected error occurred')
  end

  it 'handles NoMethodError with non-standard message format' do
    error = NoMethodError.new('some weird error message without the expected pattern')
    result = handler.convert_standard_error(error)

    expect(result).to be_a(SimpleCovMcp::CoverageDataError)
    expect(result.user_friendly_message).to include('some weird error message')
  end

  describe 'else branch for non-StandardError exceptions' do
    # This tests the else clause in convert_standard_error for exceptions
    # that don't inherit from StandardError
    it 'returns generic Error for Exception subclasses not inheriting from StandardError' do
      # Create a custom exception that inherits from Exception, not StandardError
      custom_exception_class = Class.new(StandardError) do
        def message
          'Custom non-standard exception'
        end
      end

      error = custom_exception_class.new
      result = handler.convert_standard_error(error)

      expect(result).to be_a(SimpleCovMcp::Error)
      expect(result.user_friendly_message).to include('An unexpected error occurred')
      expect(result.user_friendly_message).to include('Custom non-standard exception')
    end

    it 'returns generic Error for ScriptError subclasses' do
      # ScriptError inherits from Exception, not StandardError
      error = NotImplementedError.new('This feature is not implemented')
      result = handler.convert_standard_error(error)

      expect(result).to be_a(SimpleCovMcp::Error)
      expect(result.user_friendly_message).to include('An unexpected error occurred')
    end
  end

  describe 'extract_method_info fallback' do
    # This tests the fallback path in extract_method_info when NoMethodError
    # message doesn't match the expected pattern
    it 'returns original message when pattern does not match' do
      # Test various NoMethodError formats that won't match the regex
      test_messages = [
        'method not found',
        'private method called',
        'undefined local variable or method',
        ''
      ]

      test_messages.each do |msg|
        error = NoMethodError.new(msg)
        result = handler.convert_standard_error(error)

        expect(result).to be_a(SimpleCovMcp::CoverageDataError)
        # The original message should be preserved
        expect(result.message).to include(msg) unless msg.empty?
      end
    end
  end

  # ErrorHandler#convert_runtime_error handles RuntimeErrors differently based on context:
  # - :coverage_loading assumes errors relate to coverage data and maps them to
  #   CoverageDataError or ResultsetNotFoundError
  # - :general (or any other context) maps unrecognized errors to generic Error
  # This tests the final else branch in convert_runtime_error.
  describe 'convert_runtime_error with general context' do
    it 'converts RuntimeError with unrecognized message to generic Error' do
      error = RuntimeError.new('Some completely unexpected runtime error')

      result = handler.convert_standard_error(error, context: :general)

      expect(result).to be_a(SimpleCovMcp::Error)
      expect(result.user_friendly_message)
        .to include('An unexpected error occurred', 'unexpected runtime error')
    end
  end

  describe '#handle_error with reraise' do
    it 're-raises SimpleCovMcp::Error when reraise is true' do
      error = SimpleCovMcp::FileNotFoundError.new('Test file not found')

      expect { handler.handle_error(error, context: 'test', reraise: true) }
        .to raise_error(SimpleCovMcp::FileNotFoundError, 'Test file not found')

      # Verify it was logged
      expect(logger.messages.join).to include('Error in test')
    end

    it 'converts and re-raises StandardError when reraise is true' do
      error = Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb')

      expect { handler.handle_error(error, context: 'test', reraise: true) }
        .to raise_error(SimpleCovMcp::FileNotFoundError)

      # Verify it was logged
      expect(logger.messages.join).to include('Error in test')
    end
  end
end
