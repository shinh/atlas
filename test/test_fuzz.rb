require 'stringio'
require_relative "../repl.rb"
require_relative "../lex.rb"
require_relative "../lazylib.rb"
require_relative "../parse.rb"
require_relative "../infer.rb"
require_relative "../to_infix.rb"

#symbols = "~`!@#$%^&*()_-+={[}]|\\'\";:,<.>/?"
symbols = "~!!$()-=[]';?"
numbers = "012"
letters = "ab"
spaces = "  \n" # twice as likely
all = (symbols+numbers+letters+spaces).chars.to_a

srand 777
n = 100000
step_limit = 1000

1.upto(8){|program_size|
  n.times{
    program = program_size.times.map{all[(rand*all.size).to_i]}*""
    program_io=StringIO.new(program)
    output_io=StringIO.new
    begin
      repl(program_io,output_io,step_limit)
    rescue AtlasError => e
    rescue SystemStackError => e # todo some of these are bad though (e.g. if in infer)
    rescue => e
      STDERR.puts "failed, program was"
      STDERR.puts program
      raise e
    end
  }
}
