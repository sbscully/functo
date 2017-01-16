# Functo

Functo is a dynamic module for composable method objects in ruby.

It turns this:

```ruby
class AddsTwo
  attr_reader :number
  protected :number

  def initialize(number)
    @number = number
  end

  def add
    number + 2
  end
end
```

in to this:

```ruby
class AddsTwo
  include Functo.call :add, :number

  def add
    number + 2
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'functo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install functo

## Usage

Functo objects can take up to three arguments.

```ruby
class Multiply
  include Functo.call :multiply, :first, :second, :third

  def multiply
    first * second * third
  end
end

Multiply.call(10, 20, 30)
# => 6000

class Divide
  include Functo.call :multiply, :first, :second, :third, :fourth

  def divide
    first / second / third / fourth
  end
end
# => ArgumentError: given 4 arguments when only 3 are allowed
```

If you find yourself needing more you should consider composing method objects or encapsulating some of your arguments in another object.

You can use square brackets to call Functo objects:

```ruby
AddsTwo[3]
# => 5
```

and they can be used in blocks:

```ruby
[1, 2, 3].map(&AddsTwo)
# => [3, 4, 5]
```

### Composition

Functo objects can be composed using `compose` or the turbo operator `>>`:

```ruby
AddMulti = AddsTwo.compose(MultipliesThree)

AddMulti.call(3)
# => 15

MultiAdd = MultipliesThree >> AddsTwo

MultiAdd[3]
# => 11
```

The difference between the two is that the turbo operator will splat arrays passed between the composed objects but `compose` will not.

```ruby
class SplitDigits
  include Functo.call :split, :number

  def split
    number.to_s.split(//).map(&:to_i)
  end
end

class Sum
  include Functo.call :sum, :first, :second, :third

  def sum
    first + second + third
  end
end

SumDigits = SplitDigits >> Sum

SumDigits[123]
# => 6

SumDigits2 = SplitDigits.compose(Sum)

SumDigits2[123]
# => ArgumentError: wrong number of arguments (given 1, expected 3)
```

### Types

Types and coercion are not built in to Functo but they can be achieved by passing anything that responds to `[]` to the constructor.

```ruby
class ValidatesNumeric
  include Functo.call :validate, :number

  ValidationError = Class.new(StandardError)

  def validate
    raise ValidationError unless number.is_a?(Numeric)

    number
  end
end

class AddsThree
  include Functo.call :add, number: ValidatesNumeric

  def add
    number + 2
  end
end

AddsThree[10]
# => 13

AddsThree['10']
# => ValidationError
```

You could use the `dry-types` gem for example.

```ruby
require 'dry-types'

module Types
  include Dry::Types.module
end

class AddsFour
  include Functo.call :add, number: Types::Strict::Int

  def add
    number + 4
  end
end

AddsFour[4]
# => 4

AddsFour['4']
# => Dry::Types::ConstraintError

```

## Acknowledgements

Functo was inspired by these gems:

* [concord](https://github.com/mbj/concord) by mbj
* [procto](https://github.com/snusnu/procto) by snusnu

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sbscully/functo.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

