require 'proc_to_ast'

module Kernel
  def get_local_variable_names(ast, buf = [])
    if ast.type == :send
      params = ast.to_a
      if params[0].nil? && params.length == 2
        buf << params[1]
      end
    end

    ast.children.each do |node|
      if node.is_a?(Parser::AST::Node)
        get_local_variable_names(node, buf)
      end
    end

    buf
  end

  def refining(b, mod, &block)
    block_source = block.to_source
    matched = block_source.match(/do(.*)end/m)
    proc_source = "proc #{matched[0]}"
    used_local_variables = get_local_variable_names(Parser::CurrentRuby.parse(matched[1]))

    c = TOPLEVEL_BINDING.eval(<<~RUBY)
      Class.new do
        using #{mod.to_s}

        def self.process(b)
          #{b.local_variables.select { |v| used_local_variables.include?(v) }.map { |v| "#{v} = b.local_variable_get(:#{v})" }.join("\n")}
          pr = #{proc_source}
          b.receiver.instance_exec(&pr)
        end
      end
    RUBY
    c.process(b)
  end
end
