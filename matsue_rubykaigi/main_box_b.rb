class Foo
end

BoxB = Ruby::Box.new
require_relative './box_b'

p BoxB::Foo.new.foo("box_b")
