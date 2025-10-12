# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Presenters::CoverageRawPresenter do
  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:path) { 'lib/foo.rb' }
  let(:raw_data) do
    {
      'file' => '/abs/path/lib/foo.rb',
      'lines' => [1, 0, nil, 2]
    }
  end

  subject(:presenter) { described_class.new(model: model, path: path) }

  before do
    allow(model).to receive(:raw_for).with(path).and_return(raw_data)
    allow(model).to receive(:staleness_for).with(path).and_return('L')
    allow(model).to receive(:relativize) do |payload|
      payload.merge('file' => 'lib/foo.rb')
    end
  end

  describe '#absolute_payload' do
    it 'returns raw data with stale metadata' do
      result = presenter.absolute_payload

      expect(result).to include(
        'file' => '/abs/path/lib/foo.rb',
        'lines' => raw_data['lines'],
        'stale' => 'L'
      )
    end

    it 'does not mutate the model response' do
      presenter.absolute_payload

      expect(raw_data).not_to have_key('stale')
    end
  end

  describe '#relativized_payload' do
    it 'relativizes the payload once the raw data is loaded' do
      result = presenter.relativized_payload

      expect(result).to include('file' => 'lib/foo.rb')
      expect(result).to include('stale' => 'L')
    end

    it 'only fetches raw data once across calls' do
      presenter.absolute_payload
      presenter.relativized_payload

      expect(model).to have_received(:raw_for).once
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
      expect(presenter.stale).to eq('L')
      presenter.relativized_payload
      expect(presenter.stale).to eq('L')
    end
  end
end
