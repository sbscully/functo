require 'spec_helper'

describe Functo do
  it 'has a version number' do
    expect(Functo::VERSION).not_to be nil
  end

  before do
    class Adder
      include Functo.call :add, :number

      def add
        number + 2
      end
    end

    class TimeserAdder
      include Functo.call :add, :adder, :timeser

      def add
        timeser * (adder + 2)
      end
    end

    class Splitter
      include Functo.call :split, :number

      def split
        number.to_s.split('', 2).map(&:to_i)
      end
    end
  end

  describe 'inputs and output' do
    it 'creates the input and output methods' do
      expect(Adder.new(13).add).to eq(15)
    end

    it 'takes multiple inputs' do
      expect(TimeserAdder.new(13, 4).add).to eq(60)
    end

    it 'defines a protected reader on the host' do
      expect { Adder.number }.to raise_error(NoMethodError)
    end

    it 'only allows up to three input arguments' do
      expect {
        Functo.call :in, :one, :two, :three, :four
      }.to raise_error(ArgumentError)
    end
  end

  describe 'calling' do
    it 'called with call' do
      expect(Adder.call(13)).to eq(15)
    end

    it 'called with .()' do
      expect(Adder.(13)).to eq(15)
    end

    it 'called with []' do
      expect(TimeserAdder[13, 4]).to eq(60)
    end

    it 'used as a block' do
      expect([1, 2, 3].map(&Adder)).to eq([3, 4, 5])
    end
  end

  describe 'composition' do
    it 'compose' do
      SuperAdder = Adder >> Adder

      expect(SuperAdder[3]).to eq(7)
    end

    it 'compose in chains' do
      SuperDuperAdder = Adder >> Adder >> Adder >> Adder

      expect(SuperDuperAdder[3]).to eq(11)
    end

    it 'compose splatting' do
      SplitterTimeserAdder = Splitter >> TimeserAdder

      expect(SplitterTimeserAdder[512]).to eq(84)
    end

    it '#compose does not splat' do
      SplitterTimeserAdder2 = Splitter.compose(TimeserAdder)

      expect { SplitterTimeserAdder2[512] }.to raise_error(ArgumentError)
    end
  end
end
