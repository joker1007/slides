A = Ruby::Box.new
A.require_relative "module_eval_sub"

pr = A::Foo.concatter

"Hoge".instance_eval(&pr)
