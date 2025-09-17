# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageModel do
  let(:root) { (FIXTURES / 'project1').to_s }
  
  def with_stubbed_coverage_timestamp(ts) = begin
    allow(SimpleCovMcp::CovUtil).to receive(:latest_timestamp).and_return(ts)
    yield
  end

  it "raises stale error when staleness mode is 'error' and file is newer" do
    with_stubbed_coverage_timestamp(0) do
      model = described_class.new(root: root, staleness: 'error')
      expect {
        model.summary_for('lib/foo.rb')
      }.to raise_error(SimpleCovMcp::CoverageDataStaleError, /stale/i)
    end
  end

  it "does not check staleness when mode is 'off'" do
    with_stubbed_coverage_timestamp(0) do
      model = described_class.new(root: root, staleness: 'off')
      expect { model.summary_for('lib/foo.rb') }.not_to raise_error
    end
  end
  it 'all_files raises project-level stale when any source file is newer than coverage' do
    with_stubbed_coverage_timestamp(0) do
      model = described_class.new(root: root, staleness: 'error')
      expect { model.all_files }.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
    end
  end

  it 'all_files detects new files via tracked_globs' do
    with_stubbed_coverage_timestamp(Time.now.to_i) do
      tmp = File.join(root, 'lib', 'brand_new_file.rb')
      begin
        File.write(tmp, "# new file\n")
        model = described_class.new(root: root, staleness: 'error')
        expect {
          model.all_files(tracked_globs: ['lib/**/*.rb'])
        }.to raise_error(SimpleCovMcp::CoverageDataProjectStaleError)
      ensure
        File.delete(tmp) if File.exist?(tmp)
      end
    end
  end
end
