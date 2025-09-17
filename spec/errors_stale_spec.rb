# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageDataStaleError do
  it 'formats a detailed, user-friendly message with UTC/local, delta, and resultset' do
    file_time = Time.at(1_000) # 1970-01-01T00:16:40Z
    cov_epoch = 0              # 1970-01-01T00:00:00Z
    err = described_class.new(
      'Coverage data appears stale for foo.rb',
      nil,
      file_path: 'foo.rb',
      file_mtime: file_time,
      cov_timestamp: cov_epoch,
      src_len: 10,
      cov_len: 8,
      resultset_path: '/path/to/coverage/.resultset.json'
    )

    msg = err.user_friendly_message

    expect(msg).to include('Coverage data stale: Coverage data appears stale for foo.rb')
    expect(msg).to match(/File\s*-\s*time:\s*1970-01-01T00:16:40Z/)
    expect(msg).to include('(local ') # do not assert exact local tz
    expect(msg).to match(/Coverage\s*-\s*time:\s*1970-01-01T00:00:00Z/)
    expect(msg).to match(/lines:\s*10/)
    expect(msg).to match(/lines:\s*8/)
    expect(msg).to match(/Delta\s*- file is \+1000s newer than coverage/)
    expect(msg).to include('Resultset - /path/to/coverage/.resultset.json')
  end

  it 'handles missing timestamps gracefully' do
    err = described_class.new(
      'Coverage data appears stale for bar.rb',
      nil,
      file_path: 'bar.rb',
      file_mtime: nil,
      cov_timestamp: nil,
      src_len: 1,
      cov_len: 0,
      resultset_path: nil
    )
    msg = err.user_friendly_message
    expect(msg).to include('Coverage data stale: Coverage data appears stale for bar.rb')
    expect(msg).to match(/File\s*-\s*time:\s*not found.*lines: 1/m)
    expect(msg).to match(/Coverage\s*-\s*time:\s*not found.*lines: 0/m)
    expect(msg).not_to include('Delta')
  end
end
