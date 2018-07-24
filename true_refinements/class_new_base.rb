# Class.newによる解決策

require 'proc_to_ast'

module Kernel
  def refining(mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| "proc #{m[0]}" }

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process
          pr = #{proc_source}
          pr.call
        end
      end
    RUBY
    c.process
  end
end
