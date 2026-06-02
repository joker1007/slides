module RefineA
  refine String do
    def |(other)
      self + other
    end
  end
end
