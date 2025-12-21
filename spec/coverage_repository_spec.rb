# frozen_string_literal: true

require 'spec_helper'
require 'cov_loupe/repositories/coverage_repository'

RSpec.describe CovLoupe::Repositories::CoverageRepository do
  subject(:repo) { described_class.new(root: root, resultset_path: resultset_arg, logger: logger) }

  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:resultset_arg) { nil }
  let(:logger) { instance_double('CovLoupe::Logger', safe_log: nil) }

  describe '#initialize' do
    context 'with valid data' do
      it 'loads coverage map' do
        expect(repo.coverage_map).not_to be_empty
        expect(repo.coverage_map).to have_key(File.join(root, 'lib', 'foo.rb'))
      end

      it 'normalizes keys to absolute paths' do
        repo.coverage_map.each_key do |key|
          expect(Pathname.new(key)).to be_absolute
        end
      end

      it 'sets timestamp' do
        expect(repo.timestamp).to be > 0
      end

      it 'resolves resultset path' do
        expected = File.join(root, 'coverage', '.resultset.json')
        expect(repo.resultset_path).to eq(expected)
      end
    end

    context 'when loading fails' do
      let(:resultset_arg) { '/nonexistent/path' }

      it 'raises error' do
        expect do
          repo
        end.to raise_error(CovLoupe::ResultsetNotFoundError)
      end
    end

    context 'when underlying loader raises generic error' do
      before do
        allow(CovLoupe::Resolvers::ResolverHelpers).to receive(:find_resultset).and_return('dummy')
        allow(CovLoupe::ResultsetLoader).to receive(:load).and_raise(RuntimeError.new('Boom'))
      end

      it 'wraps generic errors in CoverageDataError' do
        expect do
          repo
        end.to raise_error(CovLoupe::CoverageDataError, /Boom/)
      end
    end
  end
end
