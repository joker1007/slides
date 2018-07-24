# proc_to_astによる解決策

require 'proc_to_ast'

module Kernel
  def refining(mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| "proc #{m[0]}" }

    TOPLEVEL_BINDING.eval(<<~RUBY)
      using #{mod.to_s}

      pr = #{proc_source}
      pr.call
    RUBY
  end
end
