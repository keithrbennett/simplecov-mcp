# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Presenters::BaseCoveragePresenter do
  # BaseCoveragePresenter is abstract; subclasses must implement build_payload.
  describe '#build_payload' do
    it 'raises NotImplementedError when called directly' do
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(model).to receive(:staleness_for).and_return(false)

      presenter = described_class.new(model: model, path: '/test/file.rb')

      expect { presenter.send(:build_payload) }
        .to raise_error(NotImplementedError, /must implement #build_payload/)
    end
  end
end
