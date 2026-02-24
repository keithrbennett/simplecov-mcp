# frozen_string_literal: true

module CovLoupe
  module Resources
    REPOSITORY_URL = 'https://github.com/keithrbennett/cov-loupe'
    DOCUMENTATION_WEB_URL = 'https://keithrbennett.github.io/cov-loupe/'
    LOCAL_README_PATH = File.expand_path('../../README.md', __dir__).freeze

    RESOURCE_MAP = {
      'repo' => REPOSITORY_URL,
      'repository' => REPOSITORY_URL,
      'docs' => DOCUMENTATION_WEB_URL,
      'docs-web' => DOCUMENTATION_WEB_URL,
      'docs_local' => LOCAL_README_PATH,
      'docs-local' => LOCAL_README_PATH
    }.freeze

    def self.url_for(name)
      RESOURCE_MAP[name] || (raise UsageError, "Unknown resource: '#{name}'. Valid resources: #{RESOURCE_MAP.keys.sort.join(', ')}")
    end

    def self.all
      {
        'public_repo' => REPOSITORY_URL,
        'public_doc_server' => DOCUMENTATION_WEB_URL,
        'local_readme' => LOCAL_README_PATH
      }
    end

  end
end
