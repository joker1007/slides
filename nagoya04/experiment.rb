module Ext
  def extract_source(source, first_lineno, first_column, last_lineno, last_column)
    lines = source[(first_lineno - 1)..(last_lineno-1)]
    first_line = lines.shift
    last_line = lines.pop

    if last_line.nil?
      first_line[first_column..last_column]
    else
      first_line[first_column..-1] + lines.join + last_line[0..last_column]
    end
  end

  def map(*args, &block)
    source = File.readlines(block.source_location[0])
    proc_binding = block.binding
    ast = RubyVM::AbstractSyntaxTree.of(block)
    args_tbl = ast.children[0]
    block_node = ast.children[2]
    if args_tbl.empty?
      extracted = extract_source(source, block_node.first_lineno, block_node.first_column, block_node.last_lineno, block_node.last_column)
      new_block = proc_binding.eval("proc { |it| #{extracted} }")
      super(*args, &new_block)
    else
      super(*args, &block)
    end
  end
end
Array.prepend(Ext)

n = 3
pp([1, 2, 3].map { it + n })
