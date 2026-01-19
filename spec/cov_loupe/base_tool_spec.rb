# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe CovLoupe::BaseTool do
  let(:handler) { CovLoupe::ErrorHandler.new(error_mode: :log, logger: test_logger) }
  let(:test_logger) do
    Class.new do
      attr_reader :messages

      def initialize = @messages = []
      def error(msg) = @messages << msg
    end.new
  end

  let(:orig_handler) do
    CovLoupe.error_handler
  rescue
    nil
  end

  before do
    CovLoupe.error_handler = handler
    setup_mcp_response_stub
  end

  after do
    CovLoupe.error_handler = orig_handler if orig_handler
  end

  shared_examples 'friendly response and logged' do
    it 'returns friendly text' do
      resp = described_class.handle_mcp_error(error, tool, error_mode: :log)
      expect(resp).to be_a(MCP::Tool::Response)
      expect(resp.payload.first['text']).to match(expected_pattern)
    end

    it 'respects error_mode :off' do
      resp = described_class.handle_mcp_error(error, tool, error_mode: :off)
      expect(resp).to be_a(MCP::Tool::Response)
      expect(resp.payload.first['text']).to match(expected_pattern)
    end
  end

  context 'with CovLoupe::Error' do
    let(:error) { CovLoupe::UsageError.new('invalid args') }
    let(:tool) { 'coverage_summary' }
    let(:expected_pattern) { /Error: invalid args/ }
    let(:log_fragment) { 'invalid args' }

    it_behaves_like 'friendly response and logged'
  end

  context 'with standard error' do
    let(:error) { Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb') }
    let(:tool) { 'coverage_raw' }
    let(:expected_pattern) { /Error: .*File not found: missing.rb/ }
    let(:log_fragment) { 'File not found' }

    it_behaves_like 'friendly response and logged'
  end

  describe '.model_config_for' do
    let(:defaults) do
      { root: '.', resultset: nil, raise_on_stale: false, tracked_globs: [] }
    end

    # Helper to mock AppContext with a specific config
    def context_with_config(config_hash)
      app_config = instance_double('AppConfig', model_options: config_hash)
      instance_double('AppContext', app_config: app_config)
    end

    it 'uses defaults when no context or params are provided' do
      config = described_class.model_config_for(server_context:
        instance_double('AppContext', app_config: nil))
      expect(config).to eq(defaults)
    end

    it 'uses app_config over defaults' do
      cli_config = { root: '/cli/root', raise_on_stale: true }
      context = context_with_config(cli_config)

      config = described_class.model_config_for(server_context: context)

      expect(config[:root]).to eq('/cli/root')
      expect(config[:raise_on_stale]).to be(true)
      # resultset remains nil (default) if not in cli_config
      expect(config[:resultset]).to be_nil
    end

    it 'uses explicit params over app_config' do
      cli_config = { root: '/cli/root', raise_on_stale: true }
      context = context_with_config(cli_config)

      # Pass explicit raise_on_stale: false
      config = described_class.model_config_for(
        server_context: context,
        raise_on_stale: false
      )

      expect(config[:root]).to eq('/cli/root') # inherited from CLI
      expect(config[:raise_on_stale]).to be(false)   # overridden by explicit
    end

    it 'uses explicit params over defaults when app_config is nil' do
      context = instance_double('AppContext', app_config: nil)

      config = described_class.model_config_for(
        server_context: context,
        root: '/explicit/root'
      )

      expect(config[:root]).to eq('/explicit/root')
      expect(config[:raise_on_stale]).to be(false) # default
    end

    it 'ignores nil values in explicit params allowing fallbacks' do
      cli_config = { root: '/cli/root' }
      context = context_with_config(cli_config)

      # explicit root is nil, should fallback to cli_config
      config = described_class.model_config_for(
        server_context: context,
        root: nil
      )

      expect(config[:root]).to eq('/cli/root')
    end
  end

  describe '.create_model' do
    let(:context) { mcp_server_context }

    it 'creates and returns a configured model' do
      root = '/test/project'
      mock_resultset_with_timestamp(root, FIXTURE_COVERAGE_TIMESTAMP)
      resultset_path = File.join(root, 'coverage', '.resultset.json')

      mock_file_stat(resultset_path, mtime: Time.at(FIXTURE_COVERAGE_TIMESTAMP))
      mock_file_digest(resultset_path)

      model = described_class.create_model(server_context: context, root: root)
      expect(model).to be_a(CovLoupe::CoverageModel)
    end
  end

  describe '.respond_json' do
    it 'produces ASCII-only JSON when output_chars is :ascii' do
      payload = { 'name' => 'café', 'arrow' => '→' }
      response = described_class.respond_json(payload, output_chars: :ascii)

      json_text = response.payload.first['text']
      expect(json_text).not_to include('é')
      expect(json_text).not_to include('→')
      expect(json_text).to include('\\u') # Unicode escape sequences
    end

    it 'preserves Unicode in JSON when output_chars is :fancy' do
      payload = { 'name' => 'café' }
      response = described_class.respond_json(payload, output_chars: :fancy)

      json_text = response.payload.first['text']
      expect(json_text).to include('café')
    end

    it 'uses pretty formatting when requested with ASCII mode' do
      payload = { 'key' => 'valüe' }
      response = described_class.respond_json(payload, pretty: true, output_chars: :ascii)

      json_text = response.payload.first['text']
      expect(json_text).to include("\n") # Pretty formatted
      expect(json_text).not_to include('ü')
    end
  end

  describe '.create_configured_model' do
    let(:context) { mcp_server_context }

    it 'creates fresh model instances each time' do
      Dir.mktmpdir do |root|
        mock_resultset_with_timestamp(root, FIXTURE_COVERAGE_TIMESTAMP)
        resultset_path = File.join(root, 'coverage', '.resultset.json')

        mock_file_stat(resultset_path, mtime: Time.at(100))
        mock_file_digest(resultset_path)

        model1, = described_class.create_configured_model(server_context: context, root: root)
        model2, = described_class.create_configured_model(server_context: context, root: root)

        # Models are different objects (not cached at model level)
        expect(model2).not_to be(model1)
        # But they share the same underlying cached data
        expect(model2.instance_variable_get(:@cov)).to eq(model1.instance_variable_get(:@cov))
      end
    end

    it 'models share cached data when resultset is unchanged' do
      Dir.mktmpdir do |root|
        mock_resultset_with_timestamp(root, FIXTURE_COVERAGE_TIMESTAMP)
        resultset_path = File.join(root, 'coverage', '.resultset.json')

        mock_file_stat(resultset_path, mtime: Time.at(100))
        mock_file_digest(resultset_path)

        model1, = described_class.create_configured_model(server_context: context, root: root)
        model2, = described_class.create_configured_model(server_context: context, root: root)

        # Data is shared from ModelDataCache
        expect(model1.instance_variable_get(:@cov)).to be(model2.instance_variable_get(:@cov))
      end
    end
  end
end
