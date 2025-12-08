# frozen_string_literal: true

require 'spec_helper'
require_relative '../shared_examples/coverage_presenter_examples'

RSpec.describe CovLoupe::Presenters::CoverageRawPresenter do
  it_behaves_like 'a coverage presenter',
    model_method: :raw_for,
    payload: {
      'file' => '/abs/path/lib/foo.rb',
      'lines' => [1, 0, nil, 2]
    },
    stale: 'L',
    expected_keys: ['lines']
end
