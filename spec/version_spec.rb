# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Version constant' do
  it 'exposes a semver-like version string' do
    expect(SimpleCovMcp::VERSION).to be_a(String)
    expect(SimpleCovMcp::VERSION).to match(/\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z]+)?\z/)
  end
end
