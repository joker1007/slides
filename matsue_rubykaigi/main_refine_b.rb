class Foo
end

require_relative './refine_b'
using RefineB

p Foo.new.foo("refine_b")
p Foo.new.foo2
