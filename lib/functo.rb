require "functo/version"

class Functo < Module
  MAX_ATTRIBUTES = 3
  PASS = '__FUNCTO_PASS__'.freeze

  class << self
    private :new

    def wrap(obj)
      block = ->(*args) { obj.call(*args) }

      Class.new.tap do |klass|
        klass.define_singleton_method(:call, &block)
        klass.extend(ClassMethods)
      end
    end

    def pass
      PASS
    end

    def call(*args)
      new(*parse_args(args))
    end

    private

    def parse_args(args)
      function, *inputs = *args

      if inputs.first.is_a?(Hash)
        inputs = inputs.first

        attributes = inputs.keys
        filters = inputs.values
      else
        attributes = inputs
        filters = [pass] * inputs.length
      end

      if attributes.length > MAX_ATTRIBUTES
        raise ArgumentError.new("given #{attributes.length} attributes when only #{MAX_ATTRIBUTES} are allowed")
      end

      [attributes, function, filters]
    end
  end

  private

  def initialize(attributes, function, filters)
    @attributes = attributes
    @function = function
    @filters = filters

    @attributes_module = Module.new
    @function_module = Module.new

    define_initialize
    define_readers
    define_call
  end

  def included(host)
    host.include(@attributes_module)
    host.extend(@function_module)

    host.extend(ClassMethods)
  end

  def define_initialize
    ivars = @attributes.map { |name| "@#{name}" }
    size = @attributes.size
    filter = method(:apply_filters).to_proc

    @attributes_module.class_eval do
      define_method :initialize do |*args|
        args_size = args.size

        if args_size != size
          message = "wrong number of arguments (#{args_size} for #{size})"

          raise ArgumentError.new(message)
        end

        ivars.zip(filter.call(args)) do |ivar, arg|
          instance_variable_set(ivar, arg)
        end
      end

      private :initialize
    end
  end

  def define_readers
    attributes = @attributes

    @attributes_module.class_eval do
      attr_reader(*attributes)
      protected(*attributes)
    end
  end

  def define_call
    function = @function

    @function_module.class_eval do
      define_method :call do |*args|
        new(*args).public_send(function)
      end
    end
  end

  def apply_filters(args)
    args.zip(@filters).map do |arg, filter|
      if filter === Functo.pass
        arg
      elsif filter.respond_to?(:[])
        filter[arg]
      elsif filter.respond_to?(:call)
        filter.call(arg)
      else
        raise ArgumentError.new("filters must respond to `[]` or `call`")
      end
    end
  end

  module ClassMethods
    def [](*args)
      call(*args)
    end

    def to_proc
      public_method(:call).to_proc
    end

    def compose(outer, splat: false)
      inner = self
      block = Proc.new do |*args|
        if splat
          outer.call(*inner.call(*args))
        else
          outer.call(inner.call(*args))
        end
      end

      Class.new.tap do |klass|
        klass.define_singleton_method(:call, &block)
        klass.extend(ClassMethods)
      end
    end

    def >>(outer)
      compose(outer, splat: true)
    end
  end
  private_constant(:ClassMethods)

end
