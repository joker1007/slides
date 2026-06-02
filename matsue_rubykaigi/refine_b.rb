require_relative './bar'

module RefineB
  refine Foo do
    def foo(other)
      "foo_refine: " + other
    end

    def foo2
      Bar.new.bar(self)
    end
  end
end


