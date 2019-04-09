pr = proc do
  puts :foo
  puts :bar
end
trace = TracePoint.new(:line) do |tp|
  p tp.lineno
end
trace.enable(target: pr)
pr.call
