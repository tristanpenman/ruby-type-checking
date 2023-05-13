#!/usr/bin/env ruby

#
# Ruby Type Checking - Part 2
# ===========================
#
# Optional and Additional Parameters
# ----------------------------------
#
# In the first set of examples (part-1.rb) we finished with a simple type-
# checking module called `Types`. Classes could extend from `Types`, to take
# advantage of simple Sorbet-inspired type checking:
#
#   class Repeater4
#     extend Types
#
#     typedef { params(String, Numeric, separator: String).returns(String) }
#     def repeat(str, count, separator: '')
#       Array.new(str, count).join(separator)
#     end
#   end
#
# One short-coming of this module is that it does not support combinations of
# positional arguments and variable argument lists, e.g:
#
#   def send_messages(recipient, *messages)
#     ...
#   end
#
# Specifically, we cannot directly assign a type to `*messages`, because it
# may be representative of multiple positional arguments. We can only specify
# types for a fixed number of arguments.
#
# Let's try a little metaprogramming experiment to better understand how we may
# be able to support this. Our first example will use reflection to inspect the
# parameters belonging to the current method:
#

def test1(a, b = 2, *c, d:, e: 6, **f)
  method(__method__).parameters.each do |param|
    puts param.to_s
  end
  nil
end

#
# We can test this with a call that provides arguments for all parameters:
#

puts "Example 1a:"
test1(1, 2, 3, 4, d: 5, e: 6, f: 7, g: 8)

#
# This should give us an output that looks like this:
#
#   [:req, :a]
#   [:opt, :b]
#   [:rest, :c]
#   [:keyreq, :d]
#   [:key, :e]
#   [:keyrest, :f]
#   => nil
#
# Each row begins with the kind of parameter, followed by its name.
#
# There are six different parameter types here:
#
#   req     - required positional argument
#   opt     - optional positional argument
#   rest    - variable length array of positional arguments
#   keyreq  - required keyword argument
#   key     - optional keyword argument
#   keyrest - additional keyword arguments
#
# Lets see what happens when we omit the optional parameters:
#

puts "\nExample 1b:"
test1(1, 3, 4, d: 5, f: 7, g: 8)

#
# We should get the same output above, as the omission of optional parameters
# does not change the fact that default arguments will be provided for those
# parameters.
#
# Now we can generate a hash, mapping parameters to their arguments. This is a
# useful way to see how Ruby handles 'optional' and 'rest' parameters:
#

def test2(a, b = 2, *c, d:, e: 6, **f)
  method(__method__).parameters.each do |param|
    puts [
      # parameter name
      param[1].to_s,
      # argument
      binding.local_variable_get(param[1].to_s)
    ].to_s
  end
  nil
end

#
# We can start with the same arguments as our first call to test1:
#

puts "\nExample 2a:"
test2(1, 2, 3, 4, d: 5, e: 6, f: 7, g: 8)

#
# The output should look like this:
#
#   ["a", 1]
#   ["b", 2]
#   ["c", [3, 4]]
#   ["d", 5]
#   ["e", 6]
#   ["f", {:f=>7, :g=>8}]
#   => nil
#
# The key thing to note here is that `2` has been bound to parameter `b`, which
# is an optional positional parameter. The value `6` has also been bound to
# parameter `e`, which is an optional keyword parameter.
#
# Now we can try again with those omitted:
#

puts "\nExample 2b:"
test2(1, 3, 4, d: 5, f: 7, g: 8)

#
# This time we get this output:
#
#   ["a", 1]
#   ["b", 3]
#   ["c", [4]]
#   ["d", 5]
#   ["e", 6]
#   ["f", {:f=>7, :g=>8}]
#   => nil
#
# Note that the values bound to parameters `b` and `c` have changed. Due to
# positional argument constraints, the value `3` has been bound to `b`. And the
# value `4` has been bound to `c`. What we can take away from this is that Ruby
# will attempt to bind all required and optional positional parameters before
# binding remaining arguments to rest parameters.
#
# In this case `e` remains unchanged, because keyword parameters do not need to
# take position into account.
#
# The next step is to build some validation into this. We will start by
# validating positional arguments, making use of a technical we first saw in
# part 1, we were wrap an existing method with some validation logic:
#

def test3(*args, **kwargs)
  meth = method(:test2)
  params = meth.parameters

  # Cheat a little by defining our parameter types as a hash
  arg_types = {
    a: Numeric,
    b: Numeric,
    c: Numeric
  }

  # Tracked to help with rest parameters
  param_type = nil
  param_name = nil
  arg_type = nil

  # Check each argument
  args.each_with_index do |arg, idx|
    param = params[idx]
    if param && [:req, :opt, :rest].include?(param[0])
      param_type = param[0]
      param_name = param[1]
      arg_type = arg_types[param_name]

      # Happens if there are positional arguments without a corresponding
      # type for the rest parameter
      raise "Missing type for #{param[0]} parameter `#{param_name}`" \
        if arg_type.nil?
    end

    raise "Invalid arg at position #{idx}, expected #{arg_type}" \
      unless arg.is_a?(arg_type)
  end

  # Call the original method (without checking kwargs)
  meth.call(*args, **kwargs)
end

#
# Test it out by intentionally passing an incorrect value for `a`:
#

puts "\nExample 3a:"
begin
  test3("A", 2, 3, 4, d: 5, e: 6, f: 7, g: 8)
rescue StandardError => e
  # Expected to fail with: Invalid arg at position 0, expected Numeric
  puts "Error: #{e}"
end

#
# This should fail with:
#
#   Error: Invalid arg at position 0, expected Numeric
#    => nil
#
# We can try again with an invalid argument for one of the 'rest' parameters:
#

puts "\nExample 3b:"
begin
  test3(1, 2, 3, "C", d: 5, e: 6, f: 7, g: 8)
rescue StandardError => e
  # Expected to fail with: Invalid arg at position 3, expected Numeric
  puts "Error: #{e}"
end

#
# As we would expect, this fails at position 3, since we've passed in a String:
#
#   Error: Invalid arg at position 3, expected Numeric
#    => nil
#
# Finally we can it with valid arguments:
#

puts "\nExample 3c:"
begin
  test3(1, 2, 3, 4, d: 5, e: 6, f: 7, g: 8)
rescue StandardError => e
  puts "Error: #{e}"
end

#
# We can now rewrite `Types` to take advantage of position argument validation.
#
# The first step is to validate types by parameter name, rather than position.
#
# Our goal is to write something like this:
#
#   class Repeater4
#     extend Types
#
#     typedef do
#       params(
#         str: String,
#         count: Numeric,
#         separator: String
#       ).returns(
#         String
#       )
#     end
#     def repeat(str, count, separator: '')
#       Array.new(str, count).join(separator)
#     end
#   end
#

module Types
  # we accept just a hash of key-values, mapping parameters to argument types
  def params(**arg_types)
    @arg_types = arg_types
    self
  end

  def returns(ret_type)
    @ret_type = ret_type
    self
  end

  def typedef
    yield
  end

  def method_added(name)
    # short-circuit, to avoid infinite loop
    return unless @arg_types || @ret_type

    # reset hook context, but store current values
    arg_types, ret_type = @arg_types, @ret_type
    @arg_types, @ret_type = nil, nil

    # capture the original method
    meth = instance_method(name)
    params = meth.parameters

    # wrap the original method with type checks
    define_method(name) do |*args, **kwargs, &block|
      Helpers::check_positional_args(args, arg_types, params)
      Helpers::check_keyword_args(kwargs, arg_types, params)
      ret = meth.bind(self).call(*args, **kwargs, &block)
      Helpers::check_return_value(ret, ret_type) if ret_type
      ret
    end
  end
end

#
# This has been written to use a Helpers module. This is intended to make it
# more maintainable, and easier to test in isolation:
#

module Types
  module Helpers
    class << self
      def check_positional_args(args, arg_types, params)
        arg_type = nil
        args.each_with_index do |arg, idx|
          param = params[idx]
          if param && [:req, :opt, :rest].include?(param[0])
            param_type = param[0]
            param_name = param[1]

            # Updated as long as their are positional parameter names to
            # consume. Once there aren't any more to consume, we must be
            # checking additional arguments, and can keep using whatever
            # the last type was for that.
            arg_type = arg_types[param_name] unless arg_types[param_name].nil?

            # Happens if there are positional arguments without a corresponding
            # type for the rest parameter
            raise "Missing type for #{param[0]} parameter `#{param_name}`" \
              if arg_type.nil?
          end

          raise "Invalid arg at position #{idx}, expected #{arg_type}" \
            unless arg.is_a?(arg_type)
        end
      end

      def check_keyword_args(_kwargs, _arg_types, _params)
        # TODO: not implemented
      end

      def check_return_value(ret, ret_type)
        raise "Invalid return type, expected #{ret_type.name}" \
          unless ret.is_a? ret_type
      end
    end
  end
end

class Repeater5
  extend Types

  typedef do
    params(
      str: String,
      count: Numeric,
      multiples: Numeric,
      separator: String
    ).returns(
      String
    )
  end
  def repeat(str, count = 1, *multiples, separator: '', **kw_rest)
    size = [count, *multiples].reduce(&:*)
    Array.new(size, str).join(separator)
  end
end

puts "\nExample 4a:"
puts Repeater5.new.repeat("test", separator: ", ")

puts "\nExample 4b:"
puts Repeater5.new.repeat("test", 3, 2, separator: ", ")

puts "\nExample 4c:"
puts Repeater5.new.repeat("test", 3, 2)

puts "\nExample 4d:"
puts Repeater5.new.repeat("test", 3)

puts "\nExample 4e:"
begin
  puts Repeater5.new.repeat("test", 3, 2, "a")
rescue StandardError => e
  # Expected to fail with: Missing type for rest parameter `multiples`
  puts "Error: #{e}"
end

#
# It's also worth noting what happens when rest arguments are present, but
# the name of the parameter in the method signature does not match the type
# signature
#

class Repeater6
  extend Types

  typedef do
    params(
      str: String,
      count: Numeric,
      counts: Numeric,   # <--- This has changed from `multiples` to `counts`
      separator: String
    ).returns(
      String
    )
  end
  def repeat(str, count = 1, *multiples, separator: '', **kw_rest)
    size = [count, *multiples].reduce(&:*)
    Array.new(size, str).join(separator)
  end
end

puts "\nExample 5:"
begin
  puts Repeater6.new.repeat("test", 3, 2)
rescue StandardError => e
  # Expected to fail with: Missing type for rest parameter `multiples`
  puts "Error: #{e}"
end

#
# Something similar occurs if other positional arguments have missing or
# incorrectly named types:
#

class Repeater7
  extend Types

  typedef do
    params(
      str: String,
      times: Numeric,    # <--- This has changed from `count` to `times`
      multiple: Numeric,
      separator: String
    ).returns(
      String
    )
  end
  def repeat(str, count = 1, *multiples, separator: '', **kw_rest)
    size = [count, *multiples].reduce(&:*)
    Array.new(size, str).join(separator)
  end
end

puts "\nExample 6:"
begin
  puts Repeater7.new.repeat("test", 3, 2)
rescue StandardError => e
  # Expected to failed with: Missing type for opt parameter `count`
  puts "Error: #{e}"
end

#
# The final peice of the puzzle is to support keyword arguments. Specifically,
# we want to complete the method `check_keyword_args` in the `Helpers` module.
#
# We'll reopen the module/class to do that here:
#

module Types
  module Helpers
    class << self
      def check_keyword_args(_kwargs, _arg_types, _params)
        raise 'Not implemented'
      end
    end
  end
end

#
# This allows us to re-use one of our earlier Repeater classes to test our
# implementation:
#

puts "\nExample 8a:"
begin
  puts Repeater5.new.repeat("test", 3, 2)
rescue StandardError => e
  # Expected to fail with: Not implemented
  puts "Error: #{e}"
end

#
# Now we can implement it. Recall that the three parameter types we need to
# account for are:
#
#   keyreq  - required keyword argument
#   key     - optional keyword argument
#   keyrest - additional keyword arguments
#

module Types
  module Helpers
    class << self
      def check_keyword_args(kwargs, arg_types, params)
        # don't modify the original hash
        kwargs = kwargs.clone

        arg_type = nil
        params.each do |param|
          param_type = param[0]
          param_name = param[1]
          arg_type = arg_types[param_name] unless arg_types[param_name].nil?

          # only have keyrest params left, so we can break out
          break if param_type == :keyrest

          if param_type == :keyreq
            raise "Invalid value for required kw param `#{param_name}`; expected #{arg_type}" unless kwargs[param_name].is_a?(arg_type)
          elsif param_type == :key
            raise "Invalid value for optional kw param `#{param_name}`; expected #{arg_type}" unless \
              !kwargs.include?(param_name) || kwargs[param_name].is_a?(arg_type)
          end

          # make sure we can detect extra kw params when they're not expected
          arg_type = nil
          kwargs.delete(param_name)
        end

        raise 'Unexpected extra kw params' \
          if kwargs.keys.length > 0 && arg_type.nil?

        kwargs.keys.each do |kwarg|
          raise "Invalid value for extra kw param `#{kwarg}`; expected #{arg_type}" unless \
            kwargs[kwarg].is_a?(arg_type)
        end
      end
    end
  end
end

class Logger
  extend Types

  typedef do
    params(
      msg: String,
      severity: Numeric,
      extra: String
    )
  end
  def log(msg:, severity: 3, **extra)
    puts "#{msg} [#{severity}] #{extra.to_s}"
  end
end

puts "\nExample 9a:"
Logger.new.log(msg: 'Hello world', severity: 2, hello: "world")

puts "\nExample 9b:"
begin
  Logger.new.log(msg: 123, severity: 2, hello: "world")
rescue StandardError => e
  # Expected to fail with: Invalid value for required kw param msg; expected String
  puts "Error: #{e}"
end

puts "\nExample 9c:"
begin
  Logger.new.log(msg: 'Hello world', severity: 'Three', hello: "world")
rescue StandardError => e
  # Expected to fail with: Invalid value for optional kw param severity; expected Numeric
  puts "Error: #{e}"
end

puts "\nExample 9d:"
Logger.new.log(msg: 'Hello world', hello: "world")

puts "\nExample 9e:"
begin
  Logger.new.log(msg: 'Hello world', severity: 3, hello: "world", foo: 2)
rescue StandardError => e
  # Expected to fail with: Invalid value for extra kw param foo; expected String
  puts "Error: #{e}"
end
