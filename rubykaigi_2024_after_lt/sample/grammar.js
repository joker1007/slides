/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: "sample",

  extras: $ => [
    /\s/,
    /\r?\n/
  ],

  rules: {
    program: $ => repeat(choice($.hello, $.expr)),

    hello: $ => "hello",
    number: $ => /\d+/,
    expr: $ => choice($.number, $.plus),
    plus: $ => prec.left(seq($.expr, "+", $.expr)),
  }
});
