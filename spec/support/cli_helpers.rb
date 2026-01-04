# frozen_string_literal: true

# CLI test helpers
module CLITestHelpers
  # Run CLI with the given arguments and return [stdout, stderr, exit_status]
  def run_cli_with_status(*argv)
    cli = CovLoupe::CoverageCLI.new
    status = nil
    out_str = err_str = nil
    silence_output do
      begin
        cli.run(argv.flatten)
        status = 0
      rescue SystemExit => e
        status = e.status
      end
      out_str = $stdout.string
      err_str = $stderr.string
    end
    [out_str, err_str, status]
  end

  def run_fixture_cli_with_status(*argv)
    run_cli_with_status(*fixture_cli_args(*argv))
  end

  def run_fixture_cli_output(*argv)
    stdout, _stderr, _status = run_fixture_cli_with_status(*argv)
    stdout
  end

  private def fixture_cli_args(*argv)
    args = argv.flatten
    fixture_root = File.dirname(FIXTURE_PROJECT1_RESULTSET_PATH, 2)

    unless args.any? do |arg|
      arg == '--root' || arg.start_with?('--root=') || arg.start_with?('-R')
    end
      args = ['--root', fixture_root] + args
    end

    unless args.any? do |arg|
      arg == '--resultset' || arg.start_with?('--resultset=') || arg.start_with?('-r')
    end
      args = ['--resultset', FIXTURE_PROJECT1_RESULTSET_PATH] + args
    end

    args
  end
end
