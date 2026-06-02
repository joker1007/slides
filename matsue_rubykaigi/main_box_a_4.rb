BoxA = Ruby::Box.new

trace = TracePoint.new(:end) do |tp|
  p tp.binding.eval("Ruby::Box.current")
end

trace.enable

BoxA.require_relative "./box_a"

a = BoxA::Foo.new
p a.foo
