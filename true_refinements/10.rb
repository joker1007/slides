require_relative './main'
require_relative './ext'

class Context
  def initialize(name = nil)
    @name = name
  end

  def hello(str)
    TrueRefinements.refining(Ext) do
      str.hello
    end
  end

  def hello2
    TrueRefinements.refining(Ext) do
      @name.hello
    end
  end
end

Context.new("joker1007").hello2
Context.new.hello("hoge")
