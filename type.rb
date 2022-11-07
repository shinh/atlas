Type = Struct.new(:dim,:base_elem) # base_elem is :int, :char, or :nil
class Type
  def inspect
    d = is_nil ? dim - 1 : dim
    return "nerg" if d < 0
    "["*d+ base_elem.to_s.capitalize + "]"*d
  end
  def -(rhs)
#     raise AtlasTypeError.new "internal type error, can't take elem", nil if dim - rhs < 0
    Type.new(dim - rhs.to_i, base_elem)
  end
  def +(zip_level)
    Type.new(dim+zip_level, base_elem)
  end
  def to_i
    dim
  end
  def elem
    self-1
  end
  def string_dim # dim but string = 0
    dim + (base_elem == :char ? -1 : 0)
  end
  def is_char
    base_elem == :char
  end
  def is_nil
    base_elem == :nil
  end
  def can_be(rhs)
    return true if base_elem == :nil && rhs.base_elem == :nil
    return true if base_elem == :nil && rhs.dim >= 0
    return true if rhs.base_elem == :nil && dim >= 0
    return base_elem == rhs.base_elem && dim == rhs.dim
  end
end

Int = Type.new(0,:int)
Char = Type.new(0,:char)
Str = Type.new(1,:char)
Nil = Type.new(1,:nil)

class TypeSpec
  attr_reader :constraints
  def initialize(constraints = [])
    @constraints = constraints
  end
end

class ExactTypeSpec < TypeSpec
  attr_reader :req_dim
  def initialize(req_dim, constraints = [])
    @req_dim = req_dim
    super(constraints)
  end
end

class VarTypeSpec < TypeSpec
  attr_reader :var_name
  attr_reader :extra_dims
  def initialize(var_name, extra_dims, constraints = []) # e.g. [[a]] is .new(:a, 2)
    @var_name = var_name
    @extra_dims = extra_dims
    super(constraints)
  end
end

Scalar = ExactTypeSpec.new(0)
A = :a
B = :b
def no_nil(a)
  ret=Op.parse_raw_arg_spec(a)
  ret.constraints << lambda{|t| t != Nil }
  ret
end

# type spec ================================
# { from => to } or just "to" if no args
# fyi you can't use [type] unless you mean list of type (doesn't mean 1)
# to can be a list for multiple rets or a type
# from can be a list for multiple args or a conditional type
# conditional type can be a type or a type qualifier of a type
# type can be an actual type or a list of a type (recursively) or a type var e.g. :a
FnType = Struct.new(:specs,:ret)

###############################
# Solve for the minimum possible zip level that satisfies all constraints
# constraints:
#   0 <= rep levels <= z
#   type vars satisfiable
def min_zip_level(arg_types, specs)
  vars = {}
  min_z = 0
  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (vars[spec.var_name]||=[]) << (arg - spec.extra_dims)
    when ExactTypeSpec
      this_z = arg.is_nil ?
        arg.dim - spec.req_dim : # nil has only min req rank
        (arg.dim - spec.req_dim).abs
      min_z = [min_z, this_z].max
    else
      error
    end
  }
  vars.each{|_,uses|
    non_nil_bases = uses.reject(&:is_nil)
    min_use = non_nil_bases.map{|t| t.dim }.min || 1 # 1 because that means bases are nil which
    max_use = [uses.map{|t| t.dim }.max, 0].max
    min_z = [min_z, max_use-min_use].max
  }
  return min_z
end

def solve_type_vars(arg_types, specs)
  vars = {}

  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (vars[spec.var_name]||=[]) << arg - spec.extra_dims
    when ExactTypeSpec
    else
      error
    end
  }

  vars.each{|name,uses|
    max_min_dim = uses.map(&:dim).max
    base_elems = uses.map(&:base_elem).uniq
    base_elem = if base_elems == [:nil]
      :nil
    else
      base_elems -= [:nil]
      raise AtlasTypeError.new("inconsistant base elem", nil) if base_elems.size > 1
      base_elems[0]
    end

#     raise AtlasTypeError.new "type var would need to be negative",nil if max_min_dim < 0
    vars[name] = Type.new([max_min_dim,0].max, base_elem)
  }
  vars
end

def rank_deficits(arg_types, specs, vars, zip_level)
  arg_types.zip(specs).map{|arg,spec|
    if arg.is_nil && arg.dim > zip_level
      0
    else
      spec_dim = case spec
        when VarTypeSpec
          vars[spec.var_name].dim + spec.extra_dims
        when ExactTypeSpec
          spec.req_dim
        else
          error
        end
      spec_dim - arg.dim
    end
  }
end

def spec_to_type(spec, vars)
  case spec
  when Type
    spec
  when Array
    raise "asdfasdf" if spec.size != 1
    spec_to_type(spec[0], vars) + 1
#   when Constraint
#     spec_to_type(t.spec, vars)
  when Symbol
    vars[spec]
  else
    p spec
    unknown
  end
end

def check_constraints(specs, arg_types)
  specs.zip(arg_types){|spec,type|
    spec.constraints.each{|constraint|
      raise AtlasTypeError.new("constraint failed",nil) if !constraint[type]
    }
  }
end