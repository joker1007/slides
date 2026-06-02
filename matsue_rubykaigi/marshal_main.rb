class Foo
end

f = Marshal.dump(Foo.new)
p Marshal.load(f)
