test_cases = {
  "asdf" => "(ParseError)\n1:1 (asdf) unset identifier",
  "/ 1 0" => "(DynamicError)\n1:1 (/) div 0",
  "+3 !+4 3" => "(AtlasTypeError)\n1:4 (!+) cant manual zip any more dims",

# thats probably enough but here are more ideas

# +`3 `4
# !~ ;5
# )$
# 2d version of invalid char,e.g. "g"
# :5 5
#? 1 'a 2
#a=+1 a
#unset
# # both lines are 1 test
# 1
# 2
#1 2

}

test_cases.each{|code,expected|
  file_name = "test/1d_error_functional_test.a1d"
  error_file = "test/error.out"
  File.open(file_name,"w"){|f|f<<code}
  out = `echo hello | ruby atlas.rb #{file_name} 2> #{error_file}`
  found = File.read(error_file)
  if out != "" || !found[expected]
    puts "FAIL 1d error functional test"
    puts out
    puts "STDERR", found
    #puts expected
    exit
  end
}

puts "PASS %d 1d error functional test" % test_cases.size