BoxA = Ruby::Box.new
BoxA.require_relative "./box_a"

a = BoxA::String.new
a << "Hello, "
puts a | "world!"
