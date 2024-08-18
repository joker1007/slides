require "tree_house"
require "rouge"

TreeHouse.register_lang("rbs", "./libtree-sitter-rbs.so")

parser = TreeHouse::Parser.new
parser.set_language("rbs")

source = File.read("./sample.rbs")

puts "== Source =="
puts source

puts "\n"

puts "==  Tree  =="
tree = parser.parse(source)

puts tree.root_node.to_sexp
