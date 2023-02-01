# old indentation idea:
# higher indentation = higher parse depth
# must go to orig parse depth for unindent

# todo raw string indent idea
# "asdf""1234" = ["asdf","1234"]

def parse_line(tokens)
  get_expr(tokens,:EOL,DelimiterPriority[:EOL],nil)
end

DelimiterPriority = {:EOL => 0, 'else' => 0, ')' => 1, '}' => 2}
LBrackets = {"(" => ")", "{" => "}"}

def get_expr(tokens,delimiter,priority,last)
  lastop = nil
  loop {
    atom,t = get_atom(tokens)
    if atom
      # spaces indicate it was to actually be a unary op
      if lastop && last && lastop.space_after && !lastop.space_before && !is_op(t) && is_sym(lastop.str)
        last = make_op1(lastop, last)
        lastop = nil
      end

      if lastop
        implicit_value_check(lastop, last)
        if (op=Ops3[lastop.name])
          arg2 = get_expr(tokens,lastop.name=="then"?"else":")",DelimiterPriority['else'],atom)
          arg3,t2 = get_atom(tokens)
          check_for_delimiter(t2, delimiter, priority, tokens, nil){|ret| return AST.new(op,[last,arg2,ret])}
          implicit_value_check(t2, arg3)
          last = AST.new(op,[last,arg2,arg3],lastop)
        else# actual regular binary op
          last = make_op2(lastop, last, atom)
        end
      elsif !last #first atom
        last = atom
      else # implict cons
        last = AST.new(Ops2[" "],[last,atom],t)
      end
      lastop = nil
    else # not an atom
      if lastop
        implicit_value_check(lastop, last)
        last = make_op1(lastop, last)
      end

      check_for_delimiter(t, delimiter, priority, tokens, last){|ret| return ret}
      lastop = t
    end
  }
end

def implicit_value_check(lastop, last)
  raise ParseError.new "value missing and implicit value isn't implemented yet",lastop if !last
end

def check_for_delimiter(t, delimiter, priority, tokens, last)
  if DelimiterPriority[t.str]
    if t.str != delimiter
      if DelimiterPriority[t.str] >= priority
        raise ParseError.new "unexpected #{t.str}, expecting #{delimiter}", t
      else # e.g. token is eof, expecting )
        # return without consuming token
        tokens.unshift t
      end
    end
    yield last || AST.new(NilOp,[],t)
  end
end

# return atom or nil
def get_atom(tokens)
  t = tokens.shift
  str = t.str
  [if LBrackets.include? t.str
    rb = LBrackets[t.str]
    get_expr(tokens,rb,DelimiterPriority[rb],nil)
  elsif str[0] =~ /[0-9]/
    AST.new(create_int(str),[],t)
  elsif str[0] == '"'
    AST.new(create_str(str),[],t)
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
#   elsif is_special_zip(str)
#     Ops[str].dup
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  elsif is_op(t)
    if is_sym(str) && t.space_before && !t.space_after
      atom, t2 = get_prefix_atom(tokens)
      if atom
        return [make_op1(t, atom), t]
      else
        tokens.unshift t2
        return [nil, t]
      end
    else
      nil
    end
  elsif DelimiterPriority[str]
    nil
  else
    AST.new(Var,[],t)
  end,t]
end

def get_prefix_atom(tokens)
  if is_op(tokens[0])
    t = tokens.shift
    atom, t2 = get_prefix_atom(tokens)
    if atom
      [make_op1(t, atom), t]
    else
      [nil, t2]
    end
  else
    get_atom(tokens)
  end
end

def make_op1(t,arg)
  op = Ops1[t.name] || raise(ParseError.new("op not defined for unary operations",t))
  AST.new(op, [arg], t)
end

def make_op2(t,arg1,arg2)
  op = Ops2[t.name] || raise(ParseError.new("op not defined for binary operations",t))
  AST.new(op,[arg1,arg2],t)
end

def is_op(t)
  AllOps.include?(t.str[/!*(.*)/m,1]) && !Ops0.include?(t.str[/!*(.*)/m,1]) || t.str==":"
end

def is_sym(s)
  !(s =~ /^\!*#{VarRegex}$/)
end
