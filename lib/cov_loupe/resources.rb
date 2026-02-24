# frozen_string_literal: true

module CovLoupe
  module Resources
    REPOSITORY_URL = 'https://github.com/keithrbennett/cov-loupe'
    DOCUMENTATION_WEB_URL = 'https://keithrbennett.github.io/cov-loupe/'

    RESOURCE_MAP = {
      'repo' => REPOSITORY_URL,
      'repository' => REPOSITORY_URL,
      'docs' => DOCUMENTATION_WEB_URL,
      'docs-web' => DOCUMENTATION_WEB_URL,
      'docs_local' => 'local documentation',
      'docs-local' => 'local documentation'
    }.freeze

    def self.url_for(name)
      RESOURCE_MAP[name] || (raise UsageError, "Unknown resource: '#{name}'. Valid resources: #{RESOURCE_MAP.keys.sort.join(', ')}")
    end

    def self.all
      {
        'repository' => REPOSITORY_URL,
        'documentation_web' => DOCUMENTATION_WEB_URL
      }
    end

    def self.all_with_local(dir_path)
      all.merge('readme' => local_readme_path(dir_path))
    end

    def self.resolve_gem_root(dir_path)
      parts = dir_path.split('/')
      lib_index = parts.rindex('lib')

      if lib_index
        up_count = (parts.length - lib_index)
        File.expand_path('../' * up_count, dir_path)
      else
        File.expand_path(dir_path)
      end
    end

    def self.local_readme_path(dir_path)
      File.join(resolve_gem_root(dir_path), 'README.md')
    end
  end
end
