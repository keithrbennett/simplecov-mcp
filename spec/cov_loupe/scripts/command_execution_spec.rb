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
        # Using capture3: [stdout, stderr, status]
        allow(Open3).to receive(:capture3).and_return(['', 'error details', status_double])

        silence_output do
          expect { executor.run_command('false', print_output: false) }
            .to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          expect($stderr.string).to include('Error running: false')
          expect($stderr.string).to include('error details')
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
        # Using capture3: [stdout, stderr, status]
        allow(Open3).to receive(:capture3).and_return(['output', '', status_double])

        silence_output do
          expect(executor.run_command('false', print_output: false, fail_on_error: false))
            .to eq('output')
        end
      end
    end

    context 'when command is missing (Errno::ENOENT)' do
      before do
        allow(Open3).to receive(:popen2e).and_raise(Errno::ENOENT)
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)
      end

      context 'with fail_on_error: true' do
        it 'aborts when streamed' do
          silence_output do
            expect { executor.run_command('missing', print_output: true) }
              .to raise_error(SystemExit)
            expect($stderr.string).to include('Command not found: missing')
          end
        end

        it 'aborts when captured' do
          silence_output do
            expect { executor.run_command('missing', print_output: false) }
              .to raise_error(SystemExit)
            expect($stderr.string).to include('Command not found: missing')
          end
        end
      end

      context 'with fail_on_error: false' do
        it 'returns empty string when streamed' do
          silence_output do
            expect(executor.run_command('missing', print_output: true, fail_on_error: false))
              .to eq('')
          end
        end

        it 'returns empty string when captured' do
          silence_output do
            expect(executor.run_command('missing', print_output: false, fail_on_error: false))
              .to eq('')
          end
        end
      end
    end
  end

  describe '#run_command_with_status' do
    context 'when command runs successfully' do
      it 'returns stdout and true' do
        status_double = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return(['output', '', status_double])

        expect(executor.run_command_with_status('echo hello')).to eq(['output', true])
      end
    end

    context 'when command fails' do
      it 'returns stdout and false' do
        status_double = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['', 'error', status_double])

        expect(executor.run_command_with_status('false')).to eq(['', false])
      end
    end

    context 'when command is missing' do
      it 'returns error message and false' do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

        stdout, success = executor.run_command_with_status('missing')
        expect(stdout).to include('Command not found: missing')
        expect(success).to be false
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
