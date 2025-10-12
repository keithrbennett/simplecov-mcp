# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Resolvers::CoverageLineResolver do
  describe '#lookup_lines' do
    it 'synthesizes line hits when only branch coverage exists' do
      abs_path = '/tmp/branch_only.rb'
      branch_cov = {
        abs_path => {
          'lines' => nil,
          'branches' => {
            '[:if, 0, 5, 2, 8, 5]' => {
              '[:then, 1, 6, 4, 6, 15]' => 3,
              '[:else, 2, 7, 4, 7, 15]' => 0
            },
            '[:case, 3, 12, 2, 17, 5]' => {
              '[:when, 4, 13, 4, 13, 14]' => 0,
              '[:when, 5, 14, 4, 14, 14]' => 2,
              '[:else, 6, 16, 4, 16, 12]' => 2
            }
          }
        }
      }

      resolver = described_class.new(branch_cov)
      lines = resolver.lookup_lines(abs_path)

      expect(lines[5]).to eq(3)  # line 6
      expect(lines[6]).to eq(0)  # line 7
      expect(lines[12]).to eq(0) # line 13
      expect(lines[13]).to eq(2) # line 14
      expect(lines[15]).to eq(2) # line 16
      expect(lines.count { |v| !v.nil? }).to eq(5)
    end

    it 'aggregates hits for multiple branches on the same line' do
      path = '/tmp/duplicated.rb'
      branch_cov = {
        path => {
          'lines' => nil,
          'branches' => {
            '[:if, 0, 3, 2, 3, 12]' => {
              '[:then, 1, 3, 2, 3, 12]' => 2,
              '[:else, 2, 3, 2, 3, 12]' => 3
            }
          }
        }
      }

      resolver = described_class.new(branch_cov)
      lines = resolver.lookup_lines(path)

      expect(lines[2]).to eq(5) # line 3 with summed hits
    end
  end
end
