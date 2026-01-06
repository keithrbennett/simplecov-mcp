# frozen_string_literal: true

require 'logger'
require 'time'

module CovLoupe
  class Logger
    DEFAULT_LOG_FILESPEC = './cov_loupe.log'
    FALLBACK_LOG_FILE = 'COV-LOUPE-LOG-ERROR.log'

    attr_reader :target

    def initialize(target:, mode: :library)
      @mode = mode
      @target = target
      @init_error = nil
      @stderr_warning_emitted = false

      begin
        @logger = build_logger(target)
      rescue => e
        @init_error = e
      end
    end

    def info(msg)
      log_with_level(:info, msg)
    end

    def warn(msg)
      log_with_level(:warn, msg)
    end

    def error(msg)
      log_with_level(:error, msg)
    end

    # Safe logging that never raises - use when logging should not interrupt execution.
    def safe_log(msg)
      info(msg)
    rescue
      # Silently ignore all logging failures
    end

    private def log_with_level(level, msg)
      if @init_error
        handle_logging_error(@init_error, msg)
      else
        @logger.send(level, msg)
      end
    rescue => e
      handle_logging_error(e, msg)
    end

    private def build_logger(target)
      io_or_path = case target
                   when 'stdout' then $stdout
                   when 'stderr' then $stderr
                   else
                     path = target || DEFAULT_LOG_FILESPEC
                     File.expand_path(path)
      end

      ::Logger.new(io_or_path).tap do |l|
        l.formatter = ->(severity, datetime, _progname, msg) { "[#{datetime.iso8601}] #{severity}: #{msg}\n" }
      end
    end

    private def handle_logging_error(error, original_msg)
      write_fallback_file(error, original_msg)
      warn_stderr_once if @mode == :cli
    rescue
      # Silently ignore all fallback failures
    end

    private def write_fallback_file(error, original_msg)
      File.open(FALLBACK_LOG_FILE, 'a') do |f|
        timestamp = Time.now.iso8601
        f.puts "[#{timestamp}] MODE:#{@mode} ERROR:#{error.message} MSG:#{original_msg}"
      end
    rescue
      # Best effort - ignore write failures
    end

    private def warn_stderr_once
      return if @stderr_warning_emitted

      @stderr_warning_emitted = true
      $stderr.puts "Warning: Logging failed. See #{FALLBACK_LOG_FILE} for details."
    end
  end
end
