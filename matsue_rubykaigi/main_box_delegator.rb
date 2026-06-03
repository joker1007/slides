class Foo
  attr_reader :str
  def initialize
    @str = "foo"
  end

  def main_foo
    "Hello, " | "foo"
  end
end

BoxA = Ruby::Box.new
BoxA.require_relative "./box_delegator"

foo = BoxA::FooWrapper.new(Foo.new)
p foo.box_foo
p foo.str_concat
p foo.main_foo
