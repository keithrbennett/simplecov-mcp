# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/scripts/setup_doc_server'

# rubocop:disable RSpec/SubjectStub
RSpec.describe CovLoupe::Scripts::SetupDocServer do
  subject(:script) { described_class.new }

  describe '#call' do
    before do
      allow($stdout).to receive(:puts)
      allow($stdout).to receive(:warn)
    end

    it 'creates a venv and installs dependencies' do
      expect(script).to receive(:run_command).with('python3 -m venv .venv', print_output: true)

      # Mock pip path check
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.venv/bin/pip').and_return(true)

      expect(script).to receive(:run_command).with(
        '.venv/bin/pip install -q -r requirements.txt',
        print_output: true
      )

      script.call
      expect($stdout).to have_received(:puts).with(/setup complete/)
    end

    it 'fails gracefully if pip install fails' do
      allow(script).to receive(:run_command).with('python3 -m venv .venv', print_output: true)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.venv/bin/pip').and_return(true)

      # Simulate failure in run_command (it calls abort_with on failure)
      allow(script).to receive(:run_command).with(
        '.venv/bin/pip install -q -r requirements.txt',
        print_output: true
      ).and_raise(SystemExit)

      expect { script.call }.to raise_error(SystemExit)
    end

    it 'falls back to global pip if venv pip is missing' do
      allow(script).to receive(:run_command).with('python3 -m venv .venv', print_output: true)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.venv/bin/pip').and_return(false)
      expect(script).to receive(:run_command).with(
        'pip install -q -r requirements.txt',
        print_output: true
      )

      script.call
    end
  end
end
# rubocop:enable RSpec/SubjectStub
