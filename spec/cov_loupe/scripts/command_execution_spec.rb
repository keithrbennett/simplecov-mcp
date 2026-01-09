# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/scripts/command_execution'

RSpec.describe CovLoupe::Scripts::CommandExecution do
  subject(:executor) { test_class.new }

  let(:test_class) do
    Class.new do
      include CovLoupe::Scripts::CommandExecution
    end
  end

  describe '#run_command' do
    context 'when fail_on_error is true and streamed command fails' do
      it 'calls abort_with and exits' do
        status_double = instance_double(Process::Status, success?: false)
        thread_double = instance_double(Thread, value: status_double)

        allow(Open3).to receive(:popen2e).and_yield(nil, [], thread_double)

        silence_output do
          expect { executor.run_command('false', print_output: true) }
            .to raise_error(SystemExit)
          expect($stderr.string).to include('Command failed: false')
        end
      end
    end

    context 'when fail_on_error is true and captured command fails' do
      it 'warns and exits with status 1' do
        status_double = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(['', status_double])

        silence_output do
          expect { executor.run_command('false', print_output: false) }
            .to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          expect($stderr.string).to include('Error running: false')
        end
      end
    end

    context 'when fail_on_error is false and command fails' do
      it 'does not raise an error for streamed commands' do
        status_double = instance_double(Process::Status, success?: false)
        thread_double = instance_double(Thread, value: status_double)

        allow(Open3).to receive(:popen2e).and_yield(nil, ['output'], thread_double)

        silence_output do
          expect(executor.run_command('false', print_output: true, fail_on_error: false))
            .to eq('output')
        end
      end

      it 'does not raise an error for captured commands' do
        status_double = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(['output', status_double])

        silence_output do
          expect(executor.run_command('false', print_output: false, fail_on_error: false))
            .to eq('output')
        end
      end
    end
  end

  describe '#command_exists?' do
    let(:cmd) { 'some_command' }

    before do
      allow(File).to receive_messages(exist?: false, executable?: false)
    end

    context 'when command is an executable file' do
      it 'returns true' do
        allow(File).to receive_messages(exist?: true, executable?: true)
        expect(executor.command_exists?(cmd)).to be true
      end
    end

    context 'when on Windows' do
      before do
        allow(Gem).to receive(:win_platform?).and_return(true)
      end

      it 'uses "where" to check for command' do
        # We must stub the subject because command_exists? calls the system kernel method on itself.
        # rubocop:disable RSpec/SubjectStub
        allow(executor).to receive(:system).and_return(true)
        # rubocop:enable RSpec/SubjectStub

        expect(executor.command_exists?(cmd)).to be true
        # rubocop:disable RSpec/SubjectStub
        expect(executor).to have_received(:system).with('where', cmd, anything)
        # rubocop:enable RSpec/SubjectStub
      end
    end

    context 'when on non-Windows' do
      before do
        allow(Gem).to receive(:win_platform?).and_return(false)
      end

      it 'uses "which" to check for command' do
        # We must stub the subject because command_exists? calls the system kernel method on itself.
        # rubocop:disable RSpec/SubjectStub
        allow(executor).to receive(:system).and_return(true)
        # rubocop:enable RSpec/SubjectStub

        expect(executor.command_exists?(cmd)).to be true
        # rubocop:disable RSpec/SubjectStub
        expect(executor).to have_received(:system).with('which', cmd, anything)
        # rubocop:enable RSpec/SubjectStub
      end
    end
  end
end
