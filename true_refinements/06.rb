require_relative './pass_object'
require_relative './ext'

class Foo
  def initialize
    @name = "joker1007"
  end

  def hello
    refining(self, Ext) do
      @name.hello
    end
  end
end

Foo.new.hello # => Yay
