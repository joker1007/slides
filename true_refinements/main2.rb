require 'parser/current'
require 'proc_to_ast'
require 'binding_ninja'

module TrueRefinements
  class << self
    extend BindingNinja

    def refined_class_table
      @refined_class_table ||= Hash.new { |h, k| h[k] = {} }
    end

    auto_inject_binding def refining(b, mod, *variables, &block)
      source_location = block.source_location
      unless refined_class_table[source_location][mod]
        block_source = block.to_source
        matched = block_source.match(/do(.*)end/m)
        proc_source = "proc #{matched[0]}"

        refined_class_table[source_location][mod] = TOPLEVEL_BINDING.eval(<<~RUBY)
          Class.new do
            using #{mod.to_s}

            def self.process(b, *variables)
              pr = #{proc_source}
              b.receiver.instance_exec(*variables, &pr)
            end
          end
        RUBY
      end
      refined_class_table[source_location][mod].process(b, *variables)
    end
  end
end
