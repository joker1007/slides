class String
  def |(other)
    self + other
  end
end

class Foo
  def self.concatter
    ->(a) {
      p (self | "foo")
    }
  end
end
