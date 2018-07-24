module Ext
  refine String do
    def hello
      puts "Hello #{self}!"
    end

    def hello_no_puts
      "Hello #{self}!"
    end
  end
end
