# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/config/app_context'

RSpec.describe CovLoupe::AppContext do
  let(:error_handler) { instance_double(CovLoupe::ErrorHandler) }
  let(:app_config) { instance_double(CovLoupe::AppConfig) }

  describe 'mode helper methods' do
    context 'when mode is :mcp' do
      subject do
        described_class.new(error_handler: error_handler, mode: :mcp, app_config: app_config)
      end

      it { is_expected.to be_mcp_mode }
      it { is_expected.not_to be_cli_mode }
      it { is_expected.not_to be_library_mode }
    end

    context 'when mode is :cli' do
      subject do
        described_class.new(error_handler: error_handler, mode: :cli, app_config: app_config)
      end

      it { is_expected.not_to be_mcp_mode }
      it { is_expected.to be_cli_mode }
      it { is_expected.not_to be_library_mode }
    end

    context 'when mode is :library' do
      subject do
        described_class.new(error_handler: error_handler, mode: :library, app_config: app_config)
      end

      it { is_expected.not_to be_mcp_mode }
      it { is_expected.not_to be_cli_mode }
      it { is_expected.to be_library_mode }
    end
  end

  describe '#with' do
    let(:initial_target) { 'initial.log' }
    let(:initial_mode) { :cli }
    let(:context) do
      described_class.new(
        error_handler: error_handler,
        log_target: initial_target,
        mode: initial_mode,
        app_config: app_config
      )
    end

    it 'creates a new logger when log_target changes' do
      new_context = context.with(log_target: 'new.log')
      expect(new_context.logger.target).to eq('new.log')
      expect(new_context.logger).not_to eq(context.logger)
    end

    it 'creates a new logger when mode changes' do
      new_context = context.with(mode: :mcp)
      expect(new_context.mode).to eq(:mcp)
      expect(new_context.logger).not_to eq(context.logger)
    end

    it 'reuses the logger when neither log_target nor mode changes' do
      new_context = context.with(app_config: nil)
      expect(new_context.logger).to eq(context.logger)
    end
  end
end
