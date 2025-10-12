# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Presenters::CoverageUncoveredPresenter do
  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:path) { 'lib/foo.rb' }
  let(:uncovered_data) do
    {
      'file' => '/abs/path/lib/foo.rb',
      'uncovered' => [2, 4],
      'summary' => { 'covered' => 2, 'total' => 4, 'pct' => 50.0 }
    }
  end

  subject(:presenter) { described_class.new(model: model, path: path) }

  before do
    allow(model).to receive(:uncovered_for).with(path).and_return(uncovered_data)
    allow(model).to receive(:staleness_for).with(path).and_return('M')
    allow(model).to receive(:relativize) do |payload|
      payload.merge('file' => 'lib/foo.rb')
    end
  end

  describe '#absolute_payload' do
    it 'returns uncovered data with stale metadata' do
      result = presenter.absolute_payload

      expect(result).to include(
        'file' => '/abs/path/lib/foo.rb',
        'uncovered' => [2, 4],
        'summary' => uncovered_data['summary'],
        'stale' => 'M'
      )
    end

    it 'does not mutate the model response' do
      presenter.absolute_payload

      expect(uncovered_data).not_to have_key('stale')
    end
  end

  describe '#relativized_payload' do
    it 'relativizes the payload once the uncovered data is loaded' do
      result = presenter.relativized_payload

      expect(result).to include('file' => 'lib/foo.rb')
      expect(result).to include('stale' => 'M')
    end

    it 'only fetches uncovered data once across calls' do
      presenter.absolute_payload
      presenter.relativized_payload

      expect(model).to have_received(:uncovered_for).once
      expect(model).to have_received(:staleness_for).once
    end
  end

  describe '#relative_path' do
    it 'exposes the relativized file path' do
      expect(presenter.relative_path).to eq('lib/foo.rb')
    end
  end

  describe '#stale' do
    it 'returns the cached stale status' do
      expect(presenter.stale).to eq('M')
      presenter.relativized_payload
      expect(presenter.stale).to eq('M')
    end
  end
end
