# bindingによる解決策

require 'proc_to_ast'

module Kernel
  def refining(b, mod, &block)
    proc_source = block.to_source
      .match(/do(.*)end/m)
      .yield_self { |m| "proc #{m[0]}" }

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process(b)
          #{b.local_variables.map { |v| "#{v} = b.local_variable_get(:#{v})" }.join("\n")}
          pr = #{proc_source}
          b.receiver.instance_exec(&pr)
        end
      end
    RUBY
    c.process(b)
  end
end
