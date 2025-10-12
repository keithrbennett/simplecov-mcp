# frozen_string_literal: true

RSpec.shared_examples 'a coverage presenter' do |config|
  subject(:presenter) { described_class.new(model: model, path: config.fetch(:path, 'lib/foo.rb')) }

  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:raw_payload) { config.fetch(:payload) }
  let(:stale_value) { config.fetch(:stale) }
  let(:relative_path) { config.fetch(:relative_path, 'lib/foo.rb') }

  before do
    allow(model).to receive(config.fetch(:model_method)).with(config.fetch(:path, 'lib/foo.rb')).and_return(raw_payload)
    allow(model).to receive(:staleness_for).with(config.fetch(:path, 'lib/foo.rb')).and_return(stale_value)
    allow(model).to receive(:relativize) do |payload|
      payload.merge('file' => relative_path)
    end
  end

  describe '#absolute_payload' do
    it 'returns data with stale metadata' do
      result = presenter.absolute_payload

      expect(result).to include('file' => raw_payload['file'])
      Array(config.fetch(:expected_keys)).each do |key|
        expect(result).to include(key => raw_payload[key])
      end
      expect(result['stale']).to eq(stale_value)
    end

    it 'does not mutate the underlying model data' do
      presenter.absolute_payload
      expect(raw_payload).not_to have_key('stale')
    end
  end

  describe '#relativized_payload' do
    it 'relativizes the payload once data is loaded' do
      result = presenter.relativized_payload
      expect(result['file']).to eq(relative_path)
      expect(result['stale']).to eq(stale_value)
    end

    it 'only fetches model data once across calls' do
      presenter.absolute_payload
      presenter.relativized_payload
      expect(model).to have_received(config.fetch(:model_method)).once
      expect(model).to have_received(:staleness_for).once
    end
  end

  describe '#relative_path' do
    it 'returns the relativized path' do
      expect(presenter.relative_path).to eq(relative_path)
    end
  end

  describe '#stale' do
    it 'returns the cached staleness flag' do
      expect(presenter.stale).to eq(stale_value)
      presenter.relativized_payload
      expect(presenter.stale).to eq(stale_value)
    end
  end
end
