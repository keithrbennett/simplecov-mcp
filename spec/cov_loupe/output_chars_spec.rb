# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::OutputChars do
  describe '.resolve_mode' do
    context 'with :fancy mode' do
      it 'returns :fancy' do
        expect(described_class.resolve_mode(:fancy)).to eq(:fancy)
      end
    end

    context 'with :ascii mode' do
      it 'returns :ascii' do
        expect(described_class.resolve_mode(:ascii)).to eq(:ascii)
      end
    end

    context 'with :default mode' do
      it 'returns :fancy when output encoding is UTF-8' do
        utf8_io = instance_double(IO)
        allow(utf8_io).to receive(:external_encoding).and_return(Encoding::UTF_8)

        expect(described_class.resolve_mode(:default, io: utf8_io)).to eq(:fancy)
      end

      it 'returns :ascii when output encoding is ASCII' do
        ascii_io = instance_double(IO)
        allow(ascii_io).to receive(:external_encoding).and_return(Encoding::US_ASCII)

        expect(described_class.resolve_mode(:default, io: ascii_io)).to eq(:ascii)
      end

      it 'returns :ascii when output encoding is nil' do
        nil_encoding_io = instance_double(IO)
        allow(nil_encoding_io).to receive(:external_encoding).and_return(nil)
        # Stub Encoding.default_external to return ASCII for this test
        allow(Encoding).to receive(:default_external).and_return(Encoding::US_ASCII)

        expect(described_class.resolve_mode(:default, io: nil_encoding_io)).to eq(:ascii)
      end
    end

    context 'with invalid mode' do
      it 'raises ArgumentError' do
        expect do
          described_class.resolve_mode(:invalid)
        end.to raise_error(ArgumentError, /Invalid output_chars mode/)
      end
    end
  end

  describe '.charset_for' do
    it 'returns UNICODE_CHARSET for :fancy mode' do
      charset = described_class.charset_for(:fancy)
      expect(charset[:top_left]).to eq('┌')
      expect(charset[:horizontal]).to eq('─')
      expect(charset[:vertical]).to eq('│')
    end

    it 'returns ASCII_CHARSET for :ascii mode' do
      charset = described_class.charset_for(:ascii)
      expect(charset[:top_left]).to eq('+')
      expect(charset[:horizontal]).to eq('-')
      expect(charset[:vertical]).to eq('|')
    end

    it 'resolves :default and returns appropriate charset' do
      utf8_io = instance_double(IO)
      allow(utf8_io).to receive(:external_encoding).and_return(Encoding::UTF_8)
      allow($stdout).to receive(:external_encoding).and_return(Encoding::UTF_8)

      charset = described_class.charset_for(:default)
      expect(charset).to eq(described_class::UNICODE_CHARSET)
    end
  end

  describe '.convert' do
    context 'with :fancy mode' do
      it 'returns text unchanged' do
        text = 'Hello café ☕'
        expect(described_class.convert(text, :fancy)).to eq(text)
      end
    end

    context 'with :ascii mode' do
      it 'converts accented characters to ASCII equivalents' do
        expect(described_class.convert('café', :ascii)).to eq('cafe')
        expect(described_class.convert('naïve', :ascii)).to eq('naive')
      end

      it 'converts special symbols to ASCII equivalents' do
        expect(described_class.convert('€100', :ascii)).to eq('EUR100')
        expect(described_class.convert('©2024', :ascii)).to eq('(c)2024')
        expect(described_class.convert('…', :ascii)).to eq('...')
      end

      it 'converts box-drawing characters to ASCII' do
        expect(described_class.convert('┌─┐', :ascii)).to eq('+-+')
        expect(described_class.convert('│', :ascii)).to eq('|')
      end

      it 'replaces unknown characters with ?' do
        # Use a character not in the transliteration map
        expect(described_class.convert('你好', :ascii)).to eq('??')
      end

      it 'preserves ASCII characters' do
        expect(described_class.convert('Hello World!', :ascii)).to eq('Hello World!')
      end
    end

    context 'with nil text' do
      it 'returns nil' do
        expect(described_class.convert(nil, :ascii)).to be_nil
      end
    end
  end

  describe '.ascii_mode?' do
    it 'returns true for :ascii mode' do
      expect(described_class.ascii_mode?(:ascii)).to be true
    end

    it 'returns false for :fancy mode' do
      expect(described_class.ascii_mode?(:fancy)).to be false
    end

    it 'resolves :default mode based on encoding' do
      utf8_io = instance_double(IO)
      allow(utf8_io).to receive(:external_encoding).and_return(Encoding::UTF_8)

      expect(described_class.ascii_mode?(:default, io: utf8_io)).to be false

      ascii_io = instance_double(IO)
      allow(ascii_io).to receive(:external_encoding).and_return(Encoding::US_ASCII)

      expect(described_class.ascii_mode?(:default, io: ascii_io)).to be true
    end
  end

  describe 'TRANSLITERATIONS' do
    it 'is frozen' do
      expect(described_class::TRANSLITERATIONS).to be_frozen
    end

    it 'contains common accented vowels' do
      expect(described_class::TRANSLITERATIONS['é']).to eq('e')
      expect(described_class::TRANSLITERATIONS['ñ']).to eq('n')
      expect(described_class::TRANSLITERATIONS['ü']).to eq('u')
    end
  end
end
