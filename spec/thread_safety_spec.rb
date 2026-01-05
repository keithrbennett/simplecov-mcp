# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Thread Safety' do
  describe 'Global Configuration' do
    before do
      # Stub logger creation to prevent file creation during thread safety tests
      mock_logger = instance_double(
        CovLoupe::Logger, info: nil, warn: nil, error: nil, safe_log: nil)
      allow(CovLoupe::Logger).to receive(:new).and_return(mock_logger)
    end

    it 'handles concurrent default_log_file= safely' do
      # Reset state
      CovLoupe.default_log_file = nil

      threads = 10.times.map do |i|
        Thread.new do
          100.times do
            CovLoupe.default_log_file = "log-#{i}.txt"
            expect(CovLoupe.default_log_file).to match(/log-\d+\.txt/)
          end
        end
      end
      threads.each(&:join)

      # Reset to avoid file creation in spec_helper's after hook
      CovLoupe.default_log_file = File::NULL
    end

    it 'handles concurrent error_handler= safely' do
      # Reset state
      initial_handler = CovLoupe.error_handler

      threads = 10.times.map do |_i|
        Thread.new do
          100.times do
            dummy_handler = Object.new
            CovLoupe.error_handler = dummy_handler
            expect(CovLoupe.error_handler).to be_a(Object)
          end
        end
      end
      threads.each(&:join)

      # Restore
      CovLoupe.error_handler = initial_handler
    end

    it 'isolates thread-local active_log_file changes' do
      CovLoupe.default_log_file = 'default.log'

      t1 = Thread.new do
        CovLoupe.active_log_file = 'thread1.log'
        sleep 0.1
        expect(CovLoupe.active_log_file).to eq('thread1.log')
        expect(CovLoupe.default_log_file).to eq('default.log')
      end

      t2 = Thread.new do
        CovLoupe.active_log_file = 'thread2.log'
        sleep 0.1
        expect(CovLoupe.active_log_file).to eq('thread2.log')
        expect(CovLoupe.default_log_file).to eq('default.log')
      end

      t1.join
      t2.join

      expect(CovLoupe.default_log_file).to eq('default.log')

      # Reset to avoid file creation in spec_helper's after hook
      CovLoupe.default_log_file = File::NULL
    end
  end
end
