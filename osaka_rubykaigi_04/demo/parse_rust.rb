require "tree_house"
require "rouge"

TreeHouse.register_lang("rust", "./libtree-sitter-rust.so")

parser = TreeHouse::Parser.new
parser.set_language("rust")

source = File.read("./sample.rs")

formatter = Rouge::Formatters::Terminal256.new
lexer = Rouge::Lexers::Rust.new

puts "== Source =="
puts formatter.format(lexer.lex(source))

puts "\n"

puts "==  Tree  =="
tree = parser.parse(source)

puts tree.root_node.to_sexp
