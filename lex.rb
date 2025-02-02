class Token<Struct.new(:str,:char_no,:line_no)
  def name
    str[/^#{ApplyRx}?(.*?)#{FlipRx}?$/m,1]
  end
  def is_alpha
    name =~ /^#{IdRx}$/
  end
end

AllSymbols='@!?`~#%^&*-_=+[]|;<,>.()\'"{}$/\\:'.chars.to_a
UnmodableSymbols='()\'"{}$'.chars.to_a # these cannot have op modifiers
FlipModifier="\\"
FlipRx=Regexp.escape FlipModifier
ApplyModifier="@"
ApplyRx=Regexp.escape ApplyModifier
ModableSymbols=AllSymbols-UnmodableSymbols-[FlipModifier,ApplyModifier]

# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRx = /[0-9]+/
CharRx = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/
StrRx = /"(\\.|[^"])*"?/
AtomRx = /#{CharRx}|#{NumRx}|#{StrRx}/
# if change, then change auto complete chars
IdRx = /[a-z][a-zA-Z0-9_]*/
SymRx = /#{ModableSymbols.map{|c|Regexp.escape c}*'|'}/
OpRx = /#{IdRx}|#{ApplyRx}?#{SymRx}#{FlipRx}?|#{FlipRx}|#{ApplyRx}/
OtherRx = /#{UnmodableSymbols.map{|c|Regexp.escape c}*'|'}/
CommentRx = /--.*/
EmptyLineRx = /\n[ \t]*#{CommentRx}?/
IgnoreRx = /#{CommentRx}|#{EmptyLineRx}*\n[ \t]+| /

def assertVar(token)
  raise ParseError.new "cannot set #{token.str}", token unless token.str =~ /^#{IdRx}$/
end

def lex(code,line_no=1) # returns a list of lines which are a list of tokens
	tokens = [[]]
  char_no = 1
  code.scan(/#{AtomRx}|#{CommentRx}|#{OpRx}|#{OtherRx}|#{IgnoreRx}|./m) {|matches|
    $from=token=Token.new($&,char_no,line_no)
    line_no += $&.count("\n")
    if $&["\n"]
      char_no = $&.size-$&.rindex("\n")
    else
      char_no += $&.size
    end
    if token.str =~ /^#{IgnoreRx}$/
      # pass
    elsif token.str == "\n"
      tokens[-1] << Token.new(:EOL,char_no,line_no)
      tokens << []
    else
  	  tokens[-1] << token
  	end
  }
  tokens[-1]<<Token.new(:EOL,char_no,line_no)
  [tokens,line_no+1]
end

