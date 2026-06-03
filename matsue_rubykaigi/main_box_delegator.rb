class Foo
  def main_foo
    "Hello, " | "foo"
  end
end

BoxA = Ruby::Box.new
BoxA.require_relative "./box_delegator"

foo = BoxA::FooWrapper.new(Foo.new)
p foo.box_foo
p foo.main_foo
