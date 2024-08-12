require "tree_house"
require "rouge"

TreeHouse.register_lang("ruby", "./libtree-sitter-ruby.so")

parser = TreeHouse::Parser.new
parser.set_language("ruby")

source = File.read("./sample.rb")

formatter = Rouge::Formatters::Terminal256.new
lexer = Rouge::Lexers::Ruby.new

puts "== Source =="
puts formatter.format(lexer.lex(source))

puts "\n"

puts "==  Tree  =="
tree = parser.parse(source)

puts tree.root_node.to_sexp
