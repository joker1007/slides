pr = proc { puts :foo }
ast = RubyVM::AbstractSyntaxTree.of(pr)
pp ast

pr = proc { puts :hello_proc }
p pr
