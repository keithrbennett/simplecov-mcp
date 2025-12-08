# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Presenters::BaseCoveragePresenter do
  let(:model) { instance_double(CovLoupe::CoverageModel) }
  let(:path) { 'lib/foo.rb' }
  let(:presenter) { described_class.new(model: model, path: path) }

  describe '#initialize' do
    it 'sets model and path' do
      expect(presenter.model).to eq(model)
      expect(presenter.path).to eq(path)
    end
  end

  describe '#absolute_payload' do
    it 'raises NotImplementedError because build_payload is abstract' do
      expect { presenter.absolute_payload }.to raise_error(NotImplementedError)
    end
  end

  context 'with a concrete implementation' do
    let(:concrete_class) do
      Class.new(described_class) do
        # Provide a concrete implementation of the abstract build_payload method
        # for testing the BaseCoveragePresenter functionality
        def build_payload
          { 'file' => path, 'data' => 'test' }
        end
      end
    end
    let(:presenter) { concrete_class.new(model: model, path: path) }
    let(:payload_with_stale) { { 'file' => path, 'data' => 'test', 'stale' => false } }

    before do
      allow(model).to receive(:staleness_for).with(path).and_return(false)
      allow(model).to receive(:relativize).with(payload_with_stale).and_return(payload_with_stale)
    end

    describe '#absolute_payload' do
      it 'merges stale status into payload' do
        expect(presenter.absolute_payload).to include('stale' => false)
        expect(presenter.absolute_payload).to include('data' => 'test')
      end

      it 'caches the result' do
        r1 = presenter.absolute_payload
        r2 = presenter.absolute_payload
        expect(r1).to equal(r2)
      end
    end

    describe '#relativized_payload' do
      it 'delegates to model.relativize' do
        expect(model).to receive(:relativize).with(presenter.absolute_payload)
        presenter.relativized_payload
      end

      it 'caches the result' do
        presenter.relativized_payload
        expect(model).to have_received(:relativize).once
        presenter.relativized_payload
      end
    end

    describe '#stale' do
      it 'delegates to absolute_payload' do
        expect(presenter.stale).to be(false)
      end
    end

    describe '#relative_path' do
      it 'delegates to relativized_payload' do
        expect(presenter.relative_path).to eq('lib/foo.rb')
      end
    end
  end
end
