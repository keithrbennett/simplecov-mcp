# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Presenters::CoverageSummaryPresenter do
  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:path) { 'lib/foo.rb' }
  let(:summary_data) do
    {
      'file' => '/abs/path/lib/foo.rb',
      'summary' => { 'covered' => 8, 'total' => 10, 'pct' => 80.0 }
    }
  end

  subject(:presenter) { described_class.new(model: model, path: path) }

  before do
    allow(model).to receive(:summary_for).with(path).and_return(summary_data)
    allow(model).to receive(:staleness_for).with(path).and_return(false)
    allow(model).to receive(:relativize) do |payload|
      payload.merge('file' => 'lib/foo.rb')
    end
  end

  describe '#absolute_payload' do
    it 'returns summary data with stale metadata' do
      result = presenter.absolute_payload

      expect(result).to include(
        'file' => '/abs/path/lib/foo.rb',
        'summary' => summary_data['summary'],
        'stale' => false
      )
    end

    it 'does not mutate the model summary response' do
      presenter.absolute_payload

      expect(summary_data).not_to have_key('stale')
    end
  end

  describe '#relativized_payload' do
    it 'relativizes the payload once the summary is loaded' do
      result = presenter.relativized_payload

      expect(result).to include('file' => 'lib/foo.rb')
      expect(result).to include('stale' => false)
    end

    it 'only fetches summary data once across calls' do
      allow(model).to receive(:summary_for).with(path).and_return(summary_data)
      allow(model).to receive(:staleness_for).with(path).and_return(false)

      presenter.absolute_payload
      presenter.relativized_payload

      expect(model).to have_received(:summary_for).once
      expect(model).to have_received(:staleness_for).once
    end
  end

  describe '#relative_path' do
    it 'exposes the relativized file path' do
      expect(presenter.relative_path).to eq('lib/foo.rb')
    end
  end

  describe '#stale' do
    it 'returns the cached staleness flag' do
      expect(presenter.stale).to be(false)
      presenter.relativized_payload
      expect(presenter.stale).to be(false)
    end
  end
end
