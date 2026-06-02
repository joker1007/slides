class String
  def |(other)
    self + other
  end
end

class Foo
  def foo
    "Hello, " | "foo!"
  end
end
