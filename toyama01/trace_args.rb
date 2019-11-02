def hoge(i)
  puts "hoge #{i}"
end

hoge(1)

trace = TracePoint.new(:c_call) do |tp|
  p tp.arguments
end

trace.enable

"foo".gsub(/o/, "a")
