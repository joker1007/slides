class Foo
end

BoxB = Ruby::Box.new
BoxB.require_relative './box_b'

p BoxB::Foo.new.foo("box_b")
p BoxB::Foo.new.foo2
