# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/coverage_presenter_examples'

RSpec.describe CovLoupe::Presenters::CoverageDetailedPresenter do
  it_behaves_like 'a coverage presenter',
    model_method: :detailed_for,
    payload: {
      'file' => '/abs/path/lib/foo.rb',
      'lines' => [
        { 'line' => 1, 'hits' => 1, 'covered' => true },
        { 'line' => 2, 'hits' => 0, 'covered' => false }
      ],
      'summary' => { 'covered' => 1, 'total' => 2, 'percentage' => 50.0 }
    },
    stale: 'L',
    expected_keys: ['lines', 'summary']
end
