require_relative './bar'

class String
  def |(other)
    self + other
  end
end

class Foo < Ruby::Box.main::Foo
  def foo(other)
    "foo_box:" + other
  end

  def foo2
    Bar.new.bar(self)
  end
end
