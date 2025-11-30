# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Presenters::ProjectCoveragePresenter do
  subject(:presenter) do
    described_class.new(
      model: model,
      sort_order: sort_order,
      check_stale: check_stale,
      tracked_globs: tracked_globs
    )
  end

  let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
  let(:sort_order) { :ascending }
  let(:check_stale) { true }
  let(:tracked_globs) { ['lib/**/*.rb'] }
  let(:files) do
    [
      {
        'file' => '/abs/path/lib/foo.rb',
        'covered' => 5,
        'total' => 6,
        'percentage' => 83.33,
        'stale' => false
      },
      {
        'file' => '/abs/path/lib/bar.rb',
        'covered' => 1,
        'total' => 6,
        'percentage' => 16.67,
        'stale' => 'L'
      }
    ]
  end


  before do
    allow(model).to receive(:all_files).with(sort_order: sort_order, check_stale: check_stale,
      tracked_globs: tracked_globs).and_return(files)
    allow(model).to receive(:relativize) do |payload|
      relativizer = SimpleCovMcp::PathRelativizer.new(
        root: '/abs/path',
        scalar_keys: %w[file file_path],
        array_keys: %w[newer_files missing_files deleted_files]
      )
      relativizer.relativize(payload)
    end
  end

  describe '#absolute_payload' do
    it 'returns files and counts with stale metadata' do
      payload = presenter.absolute_payload

      expect(payload['files']).to eq(files)
      expect(payload['counts']).to eq({ 'total' => 2, 'ok' => 1, 'stale' => 1 })
    end

    it 'memoizes the computed payload' do
      presenter.absolute_payload
      presenter.absolute_payload

      expect(model).to have_received(:all_files).once
    end
  end

  describe '#relativized_payload' do
    it 'relativizes the files list' do
      relativized = presenter.relativized_payload

      expect(relativized['files'].map { |f| f['file'] }).to eq(['lib/foo.rb', 'lib/bar.rb'])
    end
  end

  describe '#relative_files' do
    it 'returns the relativized file list' do
      expect(presenter.relative_files.map { |f| f['file'] }).to eq(['lib/foo.rb', 'lib/bar.rb'])
    end
  end

  describe '#relative_counts' do
    it 'returns the relativized counts hash' do
      expect(presenter.relative_counts).to eq({ 'total' => 2, 'ok' => 1, 'stale' => 1 })
    end
  end
end
