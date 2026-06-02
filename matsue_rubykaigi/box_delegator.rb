require "delegate"

class String
  def |(other)
    self + other
  end
end

class FooWrapper < Delegator
  def initialize(foo)
    @foo = foo
  end

  def __getobj__
    @foo
  end

  def box_foo
    "Hello, " | "foo"
  end

  def str_concat
    str | "hogehoge"
  end
end
