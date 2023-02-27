# Test that parse generates the correct AST
tests = <<'EOF'
1+2 -> 1+2
1+2*3 -> 1+2*3
1+(2*3) -> 1+(2*3)
1~+2*3 -> 1~+2*3
1+2~*3 -> 1+2~*3
1+(2~)*3 -> 1+(2~)*3
1~~ -> 1~~
~2 -> ParseError

// Test implicit cons
1 2 -> 1‿2
1 (2*3) -> 1‿(2*3)
(1*2) 3 -> 1*2‿3

1 2 3 -> 1‿2‿3
(1 2) 3 -> 1‿2‿3
1 (2 3) -> 1‿(2‿3)
(1)(2)(3) -> 1‿2‿3
(1)(2) (3) -> 1‿2‿3
(1) (2)(3) -> 1‿2‿3
(1 2) (3 4) -> 1‿2‿(3‿4)
(1 2) 3 (4 5) -> 1‿2‿3‿(4‿5)

// Space can make unary/cons
1~ 2 -> 1~‿2
1 ~ -> 1~
1 2~ -> 1‿2~
1 2 ~ -> 1‿2~
(1~ ) -> 1~

// Space can prefix a unary op on a single atom
1 ~2 -> 1‿(2~)
1* ~2 -> 1*(2~)
1+2 ~3 -> 1+2‿(3~)
1+2* ~3 -> 1+2*(3~)
1 ~2+3 -> 1‿(2~)+3
1* ~2+3 -> 1*(2~)+3
1 ~~2+3 -> 1‿(2~~)+3
1* ~~2+3 -> 1*(2~~)+3
( ~2) -> 2~

// Test space doesnt do anything else
1 + 2~ -> 1+2~
1 + 2*3 -> 1+2*3
1 ~ -> 1~
1+2 * 3+4 -> 1+2*3+4
1+2 3*4 -> 1+2‿3*4
(1+2 ) -> 1+2
( 1+2) -> 1+2

// test unbalanced parens
1+2)+3 -> ParseError
1+(2*3 -> 1+(2*3)

// Identifiers ->
AA -> A‿A
aA -> aA
a_a -> a_a
A_ A -> A_‿A

1; head 2 -> 1;[‿2

EOF

require "./repl.rb"

def clear_volatile(ast)
  ast.token = nil
  ast.op.impl = nil
  ast.op.type = nil
  ast.args.each{|arg| clear_volatile(arg) }
end

start_line=2
pass = 0
name = $0.sub('test/test_','').sub(".rb","")
tests.lines.each{|test|
  start_line += 1
  next if test.strip == "" || test =~ /^\/\//
  i,o=test.split("-"+">")
  STDERR.puts "INVALID test #{test}" if !o
  o.strip!
  begin
    tokens,lines = lex(i)
    found = parse_line(tokens[0],[])
    clear_volatile(found)

    tokens,lines = lex(o)
    expected = parse_line(tokens[0],[])
    clear_volatile(expected)
  rescue Exception
    found = $!
  end

  if o=~/Error/ ? found.class.to_s!=o : found != expected
    STDERR.puts "FAIL: #{name} test line #{start_line}"
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts expected
    STDERR.puts "found:"
    raise found if Exception === found
    STDERR.puts found
    exit(1)
  end

  pass += 1
}

puts "PASS #{pass} #{name} tests"
