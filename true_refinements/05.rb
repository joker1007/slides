require_relative './class_new_base'
require_relative './ext'

class Foo
  def initialize
    @name = "joker1007"
  end

  def hello
    refining(Ext) do
      @name.hello
    end
  end
end

Foo.new.hello # => Dead!!
