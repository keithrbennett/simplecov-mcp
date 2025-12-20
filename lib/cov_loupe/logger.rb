# frozen_string_literal: true

require 'logger'
require 'time'

module CovLoupe
  class Logger
    DEFAULT_LOG_FILESPEC = './cov_loupe.log'

    def initialize(target:, mcp_mode: false)
      @mcp_mode = mcp_mode
      @init_error = nil
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
      io = case target
           when 'stdout' then $stdout
           when 'stderr' then $stderr
           else
             path = target || DEFAULT_LOG_FILESPEC
             File.open(File.expand_path(path), 'a').tap { |f| f.sync = true }
      end

      ::Logger.new(io).tap do |l|
        l.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime.iso8601}] #{severity}: #{msg}\n"
        end
      end
    end

    private def handle_logging_error(error, original_msg)
      # Fallback to stderr if file logging fails, but suppress in MCP mode
      return if @mcp_mode

      # We can't rely on the logger itself if it failed, so write directly to stderr
      timestamp = Time.now.iso8601
      $stderr.puts "[#{timestamp}] LOGGING ERROR: #{error.message}"
      $stderr.puts "[#{timestamp}] #{original_msg}"
    rescue
      # Silently ignore stderr fallback failures
    end
  end
end
