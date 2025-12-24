# frozen_string_literal: true

require_relative 'command_execution'

module CovLoupe
  module Scripts
    class SetupDocServer
      include CommandExecution

      def call
        puts 'Setting up Python virtual environment...'
        run_command(%w[python3 -m venv .venv], print_output: true)

        puts 'Installing dependencies...'
        # Install using the venv's pip directly
        pip_path = File.exist?('.venv/bin/pip') ? '.venv/bin/pip' : 'pip'
        run_command([pip_path, 'install', '-q', '-r', 'requirements.txt'], print_output: true)

        puts '✓ Documentation server setup complete.'
      end
    end
  end
end
