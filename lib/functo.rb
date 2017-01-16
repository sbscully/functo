require "functo/version"

class Functo < Module
  MAX_ARGUMENTS = 3

  private_class_method :new

  def self.call(*names)
    output = names.shift

    if names.length > MAX_ARGUMENTS
      raise ArgumentError.new("#{names.length} arguments given when only #{MAX_ARGUMENTS} are allowed")
    end

    new(names, output)
  end

  private

  def initialize(inputs, output)
    @inputs = Array(inputs)
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
    size = @inputs.size

    @inputs_module.class_eval do
      define_method :initialize do |*args|
        args_size = args.size

        if args_size != size
          fail ArgumentError, "wrong number of arguments (#{args_size} for #{size})"
        end

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

  module ClassMethods
    def [](*args)
      call(*args)
    end

    def to_proc
      public_method(:call).to_proc
    end

    def compose(outer)
      inner = self
      klass = Class.new

      klass.define_singleton_method :call do |*args|
        outer.call(*inner.call(*args))
      end

      klass.extend(ClassMethods)

      klass
    end
    alias :>> :compose
  end
  private_constant(:ClassMethods)

end
