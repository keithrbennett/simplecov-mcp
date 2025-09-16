# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Legacy require shim' do
  it "defines SimpleCov::Mcp aliasing SimpleCovMcp" do
    # Ensure the legacy file itself is executed for coverage and behavior
    load File.expand_path('../../lib/simple_cov/mcp.rb', __FILE__)
    expect(defined?(SimpleCov::Mcp)).to be_truthy
    expect(SimpleCov::Mcp).to eq(SimpleCovMcp)
  end
end

