trace = TracePoint.new(:b_call) do |tp|
  pp tp.arguments
end

trace.enable

pr = proc { |a, b, *c, key1:, key2: true, **opts| p a }

pr.call(1, 2, 3, 4, 5, key1: :aaa)
