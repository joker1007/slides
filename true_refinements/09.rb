require_relative './ast_traverse'
require_relative './ext'

class Foo
  def hello(name)
    refining(binding, Ext) do
      name.hello
    end
  end

  def hello_koic
    process = proc { "koic".hello }
    refining(binding, Ext, &process)
  end
end

Foo.new.hello("joker1007") # => Yay!
Foo.new.hello_koic # => Yay!
