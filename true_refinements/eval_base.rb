# evalによる解決策

module Kernel
  def refining(mod)
    TOPLEVEL_BINDING.eval(<<~RUBY)
      using #{mod.to_s}

      "joker1007".hello
    RUBY
  end
end
