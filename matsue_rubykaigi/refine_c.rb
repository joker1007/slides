module RefineC
  refine String do
    def |(other)
      self + other
    end
  end
end

class A
  using RefineC

  def fuga
    p "fuga" | "piyo"
  end
end

def fuga
  using RefineC
  p "fuga" | "piyo"
end

A.new.fuga
# p "hoge" | "bar"

fuga
