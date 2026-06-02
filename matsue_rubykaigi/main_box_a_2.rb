BoxA = Ruby::Box.new
BoxA.require_relative "./box_a"

a = BoxA::Foo.new
puts a.foo
