# frozen_string_literal: true

require 'open3'
require 'shellwords'

module CovLoupe
  module Scripts
    module CommandExecution
      # Execute a command and return its stdout.
      #
      # @param cmd [String, Array<String>] The shell command to run.
      # @param print_output [Boolean] If true, prints output to stdout/stderr in real-time.
      # @param fail_on_error [Boolean] If true, aborts execution if the command fails.
      # @return [String] The stdout output of the command (stripped).
      def run_command(cmd, print_output: false, fail_on_error: true)
        if print_output
          run_streamed(cmd, fail_on_error: fail_on_error)
        else
          run_captured(cmd, fail_on_error: fail_on_error)
        end
      end

      # Execute a command and return stdout and success status.
      #
      # @param cmd [String, Array<String>] The shell command to run.
      # @return [Array<String, Boolean>] The stdout and success boolean.
      def run_command_with_status(cmd)
        stdout, status = capture_command(cmd)
        [stdout.strip, status.success?]
      end

      # Print an error message and exit with status 1.
      def abort_with(message)
        warn "ERROR: #{message}"
        exit 1
      end

      # Check if a command exists in the system PATH.
      def command_exists?(cmd)
        return true if File.exist?(cmd) && File.executable?(cmd)

        system('which', cmd, out: File::NULL, err: File::NULL)
      end

      private def run_streamed(cmd, fail_on_error:)
        puts "→ #{command_display(cmd)}"
        output = +''
        status = nil

        popen_command(cmd) do |_stdin, stdout_err, wait_thr|
          stdout_err.each do |line|
            print line
            output << line
          end
          status = wait_thr.value
        end

        if fail_on_error && !status&.success?
          abort_with("Command failed: #{cmd}")
        end

        output.strip
      end

      private def run_captured(cmd, fail_on_error:)
        stdout, status = capture_command(cmd)

        if fail_on_error && !status.success?
          warn "Error running: #{command_display(cmd)}"
          exit 1
        end

        stdout.strip
      end

      private def popen_command(cmd, &)
        if cmd.is_a?(Array)
          Open3.popen2e(*cmd, &)
        else
          Open3.popen2e(cmd, &)
        end
      end

      private def capture_command(cmd)
        if cmd.is_a?(Array)
          Open3.capture2(*cmd)
        else
          Open3.capture2(cmd)
        end
      end

      private def command_display(cmd)
        return Shellwords.join(cmd) if cmd.is_a?(Array)

        cmd.to_s
      end
    end
  end
end
