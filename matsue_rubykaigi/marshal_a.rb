class Foo
  def foo
    p :foo
  end

  def self.load(f)
    Marshal.load(f)
  end
end
