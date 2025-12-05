# frozen_string_literal: true

# Shared test helpers for I/O operations (e.g., capturing stdout/stderr).
module TestIOHelpers
  # Suppress stdout/stderr within the given block, yielding the StringIOs
  def silence_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield $stdout, $stderr
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  # Capture the output of a command execution
  # @param command [SimpleCovMcp::Commands::BaseCommand] The command instance to execute
  # @param args [Array] The arguments to pass to execute
  # @return [String] The captured output
  def capture_command_output(command, args)
    output = nil
    silence_output do |stdout, _stderr|
      command.execute(args.dup)
      output = stdout.string
    end
    output
  end
end
