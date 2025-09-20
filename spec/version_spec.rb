# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Version constant' do
  it 'exposes a semver-like version string' do
    expect(SimpleCovMcp::VERSION).to be_a(String)
    # Named fragments for readability (simplified SemVer)
    CORE  = /\d+\.\d+\.\d+/
    ID    = /[[:alnum:].-]+/            # ASCII alnum plus dot/hyphen
    SEMVER = /\A#{CORE.source}(?:-#{ID.source})?(?:\+#{ID.source})?\z/

    expect(SimpleCovMcp::VERSION).to match(SEMVER)
  end
end
