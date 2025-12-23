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

        expect { executor.run_command('false', print_output: true) }
          .to raise_error(SystemExit)
      end
    end

    context 'when fail_on_error is true and captured command fails' do
      it 'warns and exits with status 1' do
        status_double = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(['', status_double])

        expect { executor.run_command('false', print_output: false) }
          .to raise_error(SystemExit) do |error|
            expect(error.status).to eq(1)
          end
      end
    end

    context 'when fail_on_error is false and command fails' do
      it 'does not raise an error for streamed commands' do
        status_double = instance_double(Process::Status, success?: false)
        thread_double = instance_double(Thread, value: status_double)

        allow(Open3).to receive(:popen2e).and_yield(nil, ['output'], thread_double)

        result = executor.run_command('false', print_output: true, fail_on_error: false)
        expect(result).to eq('output')
      end

      it 'does not raise an error for captured commands' do
        status_double = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2).and_return(['output', status_double])

        result = executor.run_command('false', print_output: false, fail_on_error: false)
        expect(result).to eq('output')
      end
    end
  end
end
