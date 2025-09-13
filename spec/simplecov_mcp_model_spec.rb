# frozen_string_literal: true

require "spec_helper"

RSpec.describe Simplecov::Mcp::CoverageModel do
  let(:root)  { (FIXTURES / "project1").to_s }
  subject(:model) { described_class.new(root: root) }

  describe "raw_for" do
    it "returns absolute file and lines array" do
      data = model.raw_for("lib/foo.rb")
      expect(data[:file]).to eq(File.expand_path("lib/foo.rb", root))
      expect(data[:lines]).to eq([1, 0, nil, 2])
    end
  end

  describe "summary_for" do
    it "computes covered/total/pct" do
      data = model.summary_for("lib/foo.rb")
      expect(data[:summary]["total"]).to eq(3)
      expect(data[:summary]["covered"]).to eq(2)
      expect(data[:summary]["pct"]).to be_within(0.01).of(66.67)
    end
  end

  describe "uncovered_for" do
    it "lists uncovered executable line numbers" do
      data = model.uncovered_for("lib/foo.rb")
      expect(data[:uncovered]).to eq([2])
      expect(data[:summary]["total"]).to eq(3)
    end
  end

  describe "detailed_for" do
    it "returns per-line details for non-nil lines" do
      data = model.detailed_for("lib/foo.rb")
      expect(data[:lines]).to eq([
        { line: 1, hits: 1, covered: true },
        { line: 2, hits: 0, covered: false },
        { line: 4, hits: 2, covered: true }
      ])
    end
  end

  describe "all_files" do
    it "sorts ascending by percentage then by file path" do
      files = model.all_files(sort_order: :ascending)
      expect(files.first[:file]).to eq(File.expand_path("lib/bar.rb", root))
      expect(files.first[:percentage]).to be_within(0.01).of(33.33)
      expect(files.last[:file]).to eq(File.expand_path("lib/foo.rb", root))
    end
  end
end

