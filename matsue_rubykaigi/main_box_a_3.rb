BoxA = Ruby::Box.new
BoxA.require_relative "./box_a"

BoxA::Foo.class_eval do
  p Ruby::Box.current
  def hoge
    p Ruby::Box.current
    "hoge" | "foo"
  end
end

a = BoxA::Foo.new
p a.foo
p a.hoge
