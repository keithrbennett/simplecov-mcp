# frozen_string_literal: true

require_relative 'command_execution'

module CovLoupe
  module Scripts
    class StartDocServer
      include CommandExecution

      def call
        mkdocs_path = File.exist?('.venv/bin/mkdocs') ? '.venv/bin/mkdocs' : 'mkdocs'

        unless command_exists?(mkdocs_path)
          warn "Error: mkdocs not found. Please run 'bin/set-up-python-for-doc-server' or " \
               "'rake docs:setup' first."
          exit 1
        end

        puts 'Starting documentation server...'
        exec(mkdocs_path, 'serve')
      end
    end
  end
end
