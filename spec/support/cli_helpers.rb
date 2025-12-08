# frozen_string_literal: true

# CLI test helpers
module CLITestHelpers
  # Run CLI with the given arguments and return [stdout, stderr, exit_status]
  def run_cli_with_status(*argv)
    cli = CovLoupe::CoverageCLI.new
    status = nil
    out_str = err_str = nil
    silence_output do |out, err|
      begin
        cli.run(argv.flatten)
        status = 0
      rescue SystemExit => e
        status = e.status
      end
      out_str = out.string
      err_str = err.string
    end
    [out_str, err_str, status]
  end
end
