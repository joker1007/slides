require_relative './main'
require_relative './ext'
require 'benchmark/ips'

class Context
  def initialize(name = nil)
    @name = name
  end

  def hello(str)
    TrueRefinements.refining(Ext) do
      str.hello_no_puts
    end
  end

  def hello3(str)
    pr = proc do
      "Hello #{str}"
    end
    pr.call
  end
end

Benchmark.ips do |x|
  ctx = Context.new
  name = "joker1007"
  x.report("plain") { ctx.hello3(name) }
  x.report("refining") { ctx.hello(name) }
  x.compare!
end
