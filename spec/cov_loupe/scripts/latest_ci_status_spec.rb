# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/scripts/latest_ci_status'

# rubocop:disable RSpec/SubjectStub
RSpec.describe CovLoupe::Scripts::LatestCiStatus do
  subject(:script) { described_class.new }

  describe '#call' do
    let(:branch) { 'main' }
    let(:run_json) do
      [
        {
          'databaseId' => 123_456,
          'status' => 'completed',
          'conclusion' => 'success',
          'url' => 'https://github.com/example/repo/actions/runs/123456',
          'displayTitle' => 'Test Run',
          'createdAt' => '2023-10-27T10:00:00Z'
        }
      ].to_json
    end

    before do
      # Mock git branch detection
      allow(Open3).to receive(:capture2)
        .with('git rev-parse --abbrev-ref HEAD')
        .and_return([branch, instance_double(Process::Status, success?: true)])

      # Mock gh run list
      allow(Open3).to receive(:capture2)
        .with("gh run list --branch #{branch} --limit 1 --json databaseId,status,conclusion,url,displayTitle,createdAt")
        .and_return([run_json, instance_double(Process::Status, success?: true)])

      # Suppress stdout
      allow($stdout).to receive(:puts)
      allow($stdout).to receive(:print)
    end

    it 'fetches and displays the latest CI run details' do
      script.call
      expect($stdout).to have_received(:puts).with(/Fetching latest CI run/)
      expect($stdout).to have_received(:puts).with(/Title:\s+Test Run/)
      expect($stdout).to have_received(:puts).with(/Status:.*SUCCESS/)
    end

    context 'when no runs are found' do
      let(:run_json) { '[]' }

      it 'notifies the user and exits gracefully' do
        script.call
        expect($stdout).to have_received(:puts).with("No workflow runs found for branch '#{branch}'.")
      end
    end

    context 'when the fetch command fails' do
      before do
        allow(Open3).to receive(:capture2)
          .with(include('gh run list'))
          .and_return(['', instance_double(Process::Status, success?: false)])
      end

      it 'warns and exits with error code 1' do
        expect { script.call }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end
    end

    context 'when the run failed' do
      let(:run_json) do
        [
          {
            'databaseId' => 654_321,
            'status' => 'completed',
            'conclusion' => 'failure',
            'url' => 'url',
            'displayTitle' => 'Failed Run',
            'createdAt' => 'time'
          }
        ].to_json
      end

      before do
        allow(script).to receive(:system)
      end

      it 'attempts to fetch failure logs' do
        script.call
        expect(script).to have_received(:system).with('gh run view 654321 --log-failed')
      end
    end
  end
end
# rubocop:enable RSpec/SubjectStub
