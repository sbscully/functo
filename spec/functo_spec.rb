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

    it 'used as a block that slurps' do
      expect([[1, 2], [3, 4]].map(&TimeserAdder.slurp)).to eq([6, 20])
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

    it '> does not splat' do
      SplitterTimeserAdder2 = Splitter > TimeserAdder

      expect { SplitterTimeserAdder2[512] }.to raise_error(ArgumentError)
    end
  end

  describe 'filters' do
    before do
      class ValidationError < StandardError
      end

      class ValidatesNonZeroNumber
        include Functo.call :validate, :number

        def validate
          raise ValidationError if number.to_f == 0

          number.to_f
        end
      end

      class DividesTwoBy
        include Functo.call :divide, number: ValidatesNonZeroNumber

        def divide
          2.0 / number
        end
      end
    end

    it 'can be used for coercion' do
      expect(DividesTwoBy[5.0]).to eq(0.4)
      expect(DividesTwoBy[5]).to eq(0.4)
      expect(DividesTwoBy.call('5')).to eq(0.4)
    end

    it 'can be used for validation' do
      expect { DividesTwoBy[0] }.to raise_error(ValidationError)
      expect { DividesTwoBy['0'] }.to raise_error(ValidationError)
    end

    it 'can be used with a symbol' do
      class DividesThreeBy
        include Functo.call :divide, number: :to_f

        def divide
          3 / number
        end
      end

      expect(DividesThreeBy['4']).to eq(0.75)
    end

    it 'has a noop filter' do
      class Divide
        include Functo.call :divide, first: ValidatesNonZeroNumber, second: Functo.pass

        def divide
          second / first
        end
      end

      expect(Divide[2, 0]).to eq(0)
      expect { Divide[0, 2] }.to raise_error(ValidationError)
    end

    it 'fails if a filter has no [], to_proc, or call method' do
      class Divide2
        include Functo.call :divide, first: ValidatesNonZeroNumber, second: nil

        def divide
          second / first
        end
      end

      expect { Divide2[2, 0] }.to raise_error(ArgumentError)
    end
  end

  describe 'wrap' do
    it 'can wrap an object that responds to call' do
      AddsThree = Functo.wrap ->(n) { n + 3 }

      expect((Adder >> AddsThree)[10]).to eq(15)
    end
  end

  describe 'blocks' do
    before do
      class BlockAdder
        include Functo.call :add, :number

        def add
          number + yield(number * 2)
        end
      end

      class MapAdder
        include Functo.call :add, :arr

        def add(&block)
          arr.map(&block).reduce(:+)
        end
      end

      class Splitter
        include Functo.call :split, :number

        def split
          number.to_s.split(//).map(&:to_i)
        end
      end
    end

    it 'takes a block' do
      expect(BlockAdder.call(2) { 3 }).to eq(5)
    end

    it 'accepts the yield' do
      expect(BlockAdder.call(2) { |number| number + 3 }).to eq(9)
    end

    it 'allows the block to be pass in with &' do
      expect(MapAdder.call([1, 2, 3]) { |number| number * number }).to eq(14)
    end

    it 'can compose' do
      expect((Splitter > MapAdder).call(123) { |number| number + 3 }).to eq(15)
    end
  end
end
