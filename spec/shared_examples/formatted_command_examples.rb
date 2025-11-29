# frozen_string_literal: true

require 'yaml'
require 'json'

RSpec.shared_examples 'a command with formatted output' do |command_args, expected_json_keys|
  context 'with json format' do
    before { cli_context.config.format = :json }

    it 'outputs valid JSON' do
      output = capture_command_output(command, command_args)
      json = JSON.parse(output)

      if expected_json_keys.is_a?(Array)
        expected_json_keys.each { |k| expect(json).to have_key(k) }
      elsif expected_json_keys.is_a?(Hash)
        expected_json_keys.each do |k, v|
          expect(json).to have_key(k)
          # Skip deep comparison if v is nil, just check key existence
          expect(json[k]).to eq(v) if v
        end
      end
    end
  end

  context 'with yaml format' do
    before { cli_context.config.format = :yaml }

    it 'outputs valid YAML' do
      output = capture_command_output(command, command_args)
      # Allow Symbol for keys that might be symbols (e.g. from version command)
      yaml = YAML.safe_load(output, permitted_classes: [Symbol])

      if expected_json_keys.is_a?(Array)
        expected_json_keys.each do |k|
          # Check for string or symbol key
          expect(yaml).to have_key(k).or have_key(k.to_sym)
        end
      elsif expected_json_keys.is_a?(Hash)
        expected_json_keys.each do |k, v|
          val = yaml.key?(k) ? yaml[k] : yaml[k.to_sym]
          expect(val).not_to be_nil
          expect(val).to eq(v) if v
        end
      end
    end
  end

  context 'with awesome_print format' do
    before { cli_context.config.format = :awesome_print }

    it 'outputs awesome_print formatted string' do
      output = capture_command_output(command, command_args)
      # Strip ANSI color codes for matching
      plain_output = output.gsub(/\e\[([;\d]+)?m/, '')

      keys_to_check = expected_json_keys.is_a?(Hash) ? expected_json_keys.keys : expected_json_keys
      keys_to_check.each do |k|
        # Check for string key "key" => or symbol key :key =>
        expect(plain_output).to match(/"#{k}"\s*=>|:#{k}\s*=>/)
      end
    end
  end
end
