require "readline"
Dir[__dir__+"/*.rb"].each{|f| require_relative f }
HistFile = Dir.home + "/.atlas_history"

def repl(input=nil,output=STDOUT,step_limit=Float::INFINITY)
  context={}

  stack=3.downto(0).map{|i|
    AST.new(create_op(
      name: "col#{i}",
      type: VecOf.new(VecOf.new(Int)),
      impl: int_col(i)
    ),[])
  }

  line_no = 1

  if input
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    input_fn = lambda { gets(nil) }
  else
    if File.exists? HistFile
      Readline::HISTORY.push *File.read(HistFile).split("\n")
    end
    input_fn = lambda {
      line = Readline.readline("\e[33m ᐳ \e[0m", true)
      File.open(HistFile,'a'){|f|f.puts line} unless !line || line.empty?
      line
    }
    Readline.completion_append_character = " "
    Readline.basic_word_break_characters = " \n\t1234567890~`!@\#$%^&*()_-+={[]}\\|:;'\",<.>/?"
    Readline.completion_proc = lambda{|s|
      all = context.keys + OpsList.filter(&:name).map(&:name)
      all << "ops"
      all.grep(/^#{Regexp.escape(s)}/)
    }
  end

  ast = nil
  file_args = !ARGV.empty?
  assignment = false
  stop = false
  until stop
    prev_context = context.dup
    line=input_fn.call
    begin
      if line==nil # eof
        stop = true # incase error is caught we still wish to stop
        if assignment # was last
          ir = to_ir(ast,context)
          printit(ir, output, step_limit)
        end
        break
      end
      token_lines,line_no=lex(line, line_no)
      token_lines.each{|tokens| # each line
        next if tokens[0].str == :EOL
        if tokens.size == 2 && (Ops1[tokens[0].str] || Ops2[tokens[0].str])
          OpsList.filter{|o|[o.name, o.sym].include?(tokens[0].str)}.each(&:help)
          next
        elsif tokens.size == 2 && tokens[0].str == "ops"
          OpsList.each{|op|op.help(false)}
          next
        end

        if tokens.size > 2 && tokens[1].str=="=" && tokens[0].is_alpha
          assignment = true
          assertVar(tokens[0])
          ast = parse_line(tokens[2..-1], stack)
          set(tokens[0], ast, context)
        else
          assignment = false
          ast = parse_line(tokens, stack)
          ir = to_ir(ast,context)
          printit(ir, output, step_limit)
        end
      }
    rescue AtlasError => e
      STDERR.puts e.message
      assignment = false
      context = prev_context
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  end # until
end

def printit(ir,output,step_limit)
    ir = IR.new(ToString, [ir])
    infer(ir)
    run(ir,output,10000,step_limit)
    output.puts unless $last_was_newline
end