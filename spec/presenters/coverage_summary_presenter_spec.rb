# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/coverage_presenter_examples'

RSpec.describe CovLoupe::Presenters::CoverageSummaryPresenter do
  it_behaves_like 'a coverage presenter',
    model_method: :summary_for,
    payload: {
      'file' => '/abs/path/lib/foo.rb',
      'summary' => { 'covered' => 8, 'total' => 10, 'percentage' => 80.0 }
    },
    stale: false,
    expected_keys: ['summary']
end
