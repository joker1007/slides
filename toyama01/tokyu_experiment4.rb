trace = TracePoint.new(:c_call) do |tp|
  pp tp.arguments
end

trace.enable

"foo".gsub(/u/, "aa")
