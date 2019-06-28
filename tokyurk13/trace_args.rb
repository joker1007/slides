trace = TracePoint.new(:c_call) do |tp|
  p tp.arguments
end

trace.enable

"foo".gsub(/o/, "a")
