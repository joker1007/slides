require_relative './bar'

Main = Ruby::Box.main
class Foo < Main::Foo
  def foo(other)
    "foo_box:" + other
  end
end
