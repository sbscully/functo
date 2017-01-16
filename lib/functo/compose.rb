module Functo::Compose
  def [](*args)
    call(*args)
  end

  def to_proc
    public_method(:call).to_proc
  end

  def compose(outer, splat: false)
    inner = self

    Functo.define_method_object do |*args|
      if splat
        outer.call(*inner.call(*args))
      else
        outer.call(inner.call(*args))
      end
    end
  end

  def >>(outer)
    compose(outer, splat: true)
  end
end