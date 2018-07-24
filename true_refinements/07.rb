require_relative './pass_object'
require_relative './ext'

class Foo
  def hello(name)
    refining(self, Ext) do
      name.hello
    end
  end
end

Foo.new.hello("joker1007") # => Dead again!!
