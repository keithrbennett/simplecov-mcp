# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/scripts/start_doc_server'

# rubocop:disable RSpec/SubjectStub
RSpec.describe CovLoupe::Scripts::StartDocServer do
  subject(:script) { described_class.new }

  describe '#call' do
    before do
      allow($stdout).to receive(:puts)
      allow($stdout).to receive(:warn)
    end

    context 'when mkdocs is found in venv' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('.venv/bin/mkdocs').and_return(true)
        allow(File).to receive(:executable?).with('.venv/bin/mkdocs').and_return(true)
      end

      it 'executes the venv mkdocs' do
        expect(script).to receive(:exec).with('.venv/bin/mkdocs', 'serve')
        script.call
      end
    end

    context 'when mkdocs is NOT in venv' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('.venv/bin/mkdocs').and_return(false)
        # Mock global existence check
        checker = Gem.win_platform? ? 'where' : 'which'
        allow(script).to receive(:system).with(checker, 'mkdocs', out: File::NULL, err: File::NULL).and_return(true)
      end

      it 'executes the global mkdocs' do
        expect(script).to receive(:exec).with('mkdocs', 'serve')
        script.call
      end
    end

    context 'when mkdocs is missing entirely' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('.venv/bin/mkdocs').and_return(false)
        checker = Gem.win_platform? ? 'where' : 'which'
        allow(script).to receive(:system).with(checker, 'mkdocs', out: File::NULL, err: File::NULL).and_return(false)
        allow(script).to receive(:warn)
      end

      it 'warns and exits' do
        expect { script.call }.to raise_error(SystemExit)
        expect(script).to have_received(:warn).with(/mkdocs not found/)
      end
    end
  end
end
# rubocop:enable RSpec/SubjectStub
