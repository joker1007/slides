require 'set'

def defer(&block)
  meth = method(caller_locations[0].label)
  fiber = fiberize(&block)
  trace = TracePoint.new(:return) do |tp|
    fiber.resume
  ensure
    trace.disable
  end
  trace.enable(target: meth)
end

def fiberize(&block)
  current_self = nil
  current_method_id = nil

  normal_args = []
  kw_args = {}
  keyrest_args = {}

  proc_location = block.source_location
  pp RubyVM::AbstractSyntaxTree.of(block)
  
  trace1 = TracePoint.new(:call) do |tp|
    p tp.event
    p tp.path
    p tp.lineno
    p tp.self
    p tp.method_id
    p tp.arguments
    stack = caller_locations
    onelevel_caller = stack[1]
    twolevel_caller = stack[2]
    directly_below_block = onelevel_caller.path == proc_location[0] && onelevel_caller.lineno == proc_location[1] && twolevel_caller.label == "block in #{__callee__}"
    next unless directly_below_block
    next if tp.defined_class == TracePoint

    current_self = tp.self
    current_method_id = tp.method_id
    tp.parameters.map do |param|
      case param[0]
      when :rest
        normal_args.concat(tp.binding.local_variable_get(param[1]))
      when :keyreq, :key
        kw_args[param[1]] = tp.binding.local_variable_get(param[1])
      when :keyrest
        keyrest_args = tp.binding.local_variable_get(param[1])
      else
        normal_args << tp.binding.local_variable_get(param[1])
      end
    end

    throw :escape
  rescue => e
    trace1.disable
    raise e
  end

  begin
    catch(:escape) do
      trace1.enable
      block.call
    end
    trace1.disable
    if current_self && current_method_id
      Fiber.new do
        if current_method_id == :initialize
          current_self.class.new(*normal_args, **(kw_args.merge(keyrest_args)))
        else
          current_self.send(current_method_id, *normal_args, **(kw_args.merge(keyrest_args)))
        end
      end
    end
  rescue => e
    trace1.disable
    raise e
  ensure
    trace1.disable
  end
end

class A
  def initialize(a)
    @a = a
  end

  def a(val, val2, val2_opt = false, *val3, val4:, val5: true, **val6)
    p val
    p val2
    p val2_opt
    p val3
    p val4
    p val5
    p val6
    n = 1
    val + @a + n
  end

  define_method(:a_block) do |val, val2_opt = false, *val3, val4:|
    p val
    p val2_opt
    p val3
    p val4
  end
end

pp RubyVM::InstructionSequence.of(A.instance_method(:a)).to_a

class Foo
  def hoge
    b = [:hoge]
    obj = A.new(12)
    # a = fiberize {
      # test_meth(obj.a(7, 8, 9, 10, val4: 11), 1, 2, 3, kw2: :kw2, opt: :opt)
    # }
    a2 = fiberize {
      obj.a_block(7, 8, 9, 10, val4: 11)
    }
    c = fiberize {
      b[0]
    }
    r = fiberize { test_meth(b, 2, 3, 4, kw2: :kw2_test, a: 1) }
    fiberize { "hoge".gsub(/o/, "n") }
    b = nil
    # p a.resume
    # p c.resume
    # p r.resume
  end

  def hoge2
    defer { test_meth(A.new(15), 1, 2, 3, kw2: false) }
    p "exec hoge2"
  end

  def test_meth(a, b, *c, kw1: true, kw2:, **opts)
    p "exec test_meth"
    [a, :good]
  end
end

Foo.new.hoge
