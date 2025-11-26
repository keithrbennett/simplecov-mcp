# frozen_string_literal: true

module Api
  class Client
    def initialize(base_url:, http:)
      @base_url = base_url
      @http = http
    end

    def get(path)
      @http.get(url_for(path))
    end

    def post(path, body)
      @http.post(url_for(path), body: body)
    end

    private

    def url_for(path)
      "#{@base_url}/#{path}"
    end
  end
end
