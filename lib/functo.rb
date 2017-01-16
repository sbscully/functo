require "functo/version"

class Functo < Module
  MAX_ARGUMENTS = 3
  PASS = '__FUNCTO_PASS__'.freeze

  private_class_method :new

  def self.pass
    PASS
  end

  def self.call(*names)
    output = names.shift

    if names.first.is_a?(Hash)
      inputs = names.first
      filters = inputs.values
      names = inputs.keys
    else
      filters = [pass] * names.length
    end

    if names.length > MAX_ARGUMENTS
      raise ArgumentError.new("given #{names.length} arguments when only #{MAX_ARGUMENTS} are allowed")
    end

    new(names, filters, output)
  end

  private

  def initialize(inputs, filters, output)
    @inputs = inputs
    @filters = filters
    @output = output
    @inputs_module = Module.new
    @output_module = Module.new

    define_initialize
    define_readers
    define_call
  end

  def included(host)
    host.include(@inputs_module)
    host.extend(@output_module)

    host.extend(ClassMethods)
  end

  def define_initialize
    ivars = @inputs.map { |name| "@#{name}" }
    filter_proc = method(:apply_filters).to_proc
    size = @inputs.size

    @inputs_module.class_eval do
      define_method :initialize do |*args|
        args_size = args.size

        if args_size != size
          fail ArgumentError, "wrong number of arguments (#{args_size} for #{size})"
        end

        args = filter_proc.(args)
        ivars.zip(args) { |ivar, arg| instance_variable_set(ivar, arg) }
      end

      private :initialize
    end
  end

  def define_readers
    attribute_names = @inputs

    @inputs_module.class_eval do
      attr_reader(*attribute_names)
      protected(*attribute_names)
    end
  end

  def define_call
    call_method = @output

    @output_module.class_eval do
      define_method :call do |*args|
        new(*args).public_send(call_method)
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
      klass = Class.new

      klass.define_singleton_method :call do |*args|
        if splat
          outer.call(*inner.call(*args))
        else
          outer.call(inner.call(*args))
        end
      end

      klass.extend(ClassMethods)

      klass
    end

    def >>(outer)
      compose(outer, splat: true)
    end
  end
  private_constant(:ClassMethods)

end
