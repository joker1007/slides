require_relative './ext'

# 理想形

refining(Ext) do
  "joker1007".hello # => "Hello joker1007"
end

"joker1007".hello # => NoMethodError
