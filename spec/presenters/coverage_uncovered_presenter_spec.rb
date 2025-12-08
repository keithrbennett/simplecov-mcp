# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/coverage_presenter_examples'

RSpec.describe CovLoupe::Presenters::CoverageUncoveredPresenter do
  it_behaves_like 'a coverage presenter',
    model_method: :uncovered_for,
    payload: {
      'file' => '/abs/path/lib/foo.rb',
      'uncovered' => [2, 4],
      'summary' => { 'covered' => 2, 'total' => 4, 'percentage' => 50.0 }
    },
    stale: 'M',
    expected_keys: ['uncovered', 'summary']
end
