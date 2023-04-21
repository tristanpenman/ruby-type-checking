#!/usr/bin/env ruby

#
# Ruby Type Checking - Part 1
# ---------------------------
#
# Lets begin with a simple example, that illustrates the shape of the output
# that we would like to achieve. We will define a class called `Repeater1`
# which knows how to repeat a string `str` a given number times `count`,
# with each copy of the string separated by `separator`. This final argument
# is a keyword argument, that has a default value of ''.
#

class Repeater1
  def repeat(str, count, separator: '')
    Array.new(count, str).join(separator)
  end
end

#
# We can test the Repeater1 class as follows:
#

puts "Example 1:"
puts Repeater1.new.repeat("test", 3, separator: ", ")

#
# As you might have guessed, the output should look something like this:
#
#   test, test, test
#
#
# Now let's say we want to add some functionality to this class, so that we
# print its arguments before the body is executed, and print out the return
# value before it is returned to the caller. We could write this as:
#

class Repeater2
  def repeat(*args, **kwargs, &block)
    puts "before: #{args}, #{kwargs}"
    fn = -> (str, count, separator: '') do
      Array.new(count, str).join(separator)
    end
    ret = fn.call(*args, **kwargs, &block)
    puts "after: #{ret}"
    ret
  end
end

#
# There's something unusual about this code, which is the lambda literal in
# the middle of the code block, that we call using `.call()`. This is used
# to illustrate that we'll be wrapping our original method in a block that
# performs extra work before and after it is executed.
#
# Also note that the method parameters have been changed to use `*args`,
# `**kwargs`, and `&block`. So the method signature does not actually tell
# us anything about the expected arguments. This is necessary if we want to
# print out the actual arguments supplied.
#
# We can test the Repeater2 class as follows:
#

puts "\nExample 2:"
puts Repeater2.new.repeat("test", 3, separator: ", ")

#
# The output should be the similar to example 1, but now it will include the
# arguments and return value:
#
#   before: ["test", 3], {:separator=>", "}
#   after: test, test, test
#   test, test, test
#
# What if we would like to simplify `Repeater2` so that the code to run 
# before and after the method body is more clearly separated, using an 
# annotative style.
#
# Ideally, it should look something like this:
#
#   before -> (*args, **kwargs) { puts "before: #{args}, #{kwargs}" }
#   after -> (returns) { puts "after: #{returns}" }
#   def repeat(str, count, separator: '')
#     Array.new(str, count).join(separator)
#   end
#
# The `before` and `after` annotations are actually method calls, which
# bind a lambda to the current 'hook context'. The `before` lambda is called
# with the arguments specified to the method. And the `after` lambda is
# called with the return value.
#
# We can achieve this using the following `Hooks` module:
#

module Hooks
  def before(tag)
    @before = tag
  end

  def after(tag)
    @after = tag
  end

  def method_added(name)
    return unless @before || @after

    before = @before
    @before = nil
    after = @after
    @after = nil

    meth = instance_method(name)

    define_method(name) do |*args, **kwargs, &block|
      before.call(*args, **kwargs) if before
      ret = meth.bind(self).call(*args, **kwargs, &block)
      after.call(ret) if after
      ret
    end
  end
end

#
# This module uses Ruby’s powerful meta-programming functionality to override
# method declaration. In this case, we're making use of `method_added`, which
# is called whenever a method is added to a class.
#
# Inside the block passed to `method_added`, we first call the `before` hook,
# then the original method, before finally calling the `after` hook.
#
# Here is the Repeater class re-written to use the Hooks module:
#

class Repeater3
  extend Hooks

  before -> (*args, **kwargs) { puts "before: #{args}, #{kwargs}" }
  after -> (val) { puts "after: #{val}" }
  def repeat(str, count, separator: '')
    Array.new(count, str).join(separator)
  end
end

#
# We can test this out using the same snippet as earlier, modified to refer to
# the new `Repeater3` class:
#

puts "\nExample 3:"
puts Repeater3.new.repeat("test", 3, separator: ", ")

#
# Once again, this should produce the same output.
#
# Now we're ready to build on this, and implement primitive type-checking,
# loosely inspired by Sorbet.
#
# If we were to take a naive approach, we could do this using our existing
# Hooks module:
#
#   before do |str, count, separator|
#     raise “invalid str” unless str.is_a? String
#     raise “invalid count” unless count.is_a? Number
#     raise “invalid separator” \
#       unless separator.is_a? String || separator.nil?
#   end
#   after begin |ret|
#     raise “invalid return value” unless ret.is_a? String
#   end
#   def repeat(str, count, separator: '')
#     Array.new(str, count).join(separator)
#   end
#
# However, this is time-consuming, error prone, and hard to maintain. Wouldn't
# it be nice if we could have something purpose-fit, like this?
#
#   typedef { params(String, Numeric, separator: String).returns(String) }
#   def repeat(str, count, separator)
#     Array.new(count, str).join(separator)
#   end
#
# It turns out we can, by defining a new module called `Types`:
#

module Types
  def params(*arg_types, **kwarg_types)
    @arg_types, @kwarg_types = arg_types, kwarg_types
    self
  end

  def returns(ret_type)
    @ret_type = ret_type
    self
  end

  # syntactic sugar, so that everything is wrapped up nicely
  def typedef
    yield
  end

  def method_added(name)
    # short-circuit, to avoid infinite loop
    return unless @arg_types || @kwarg_types || @ret_type

    # reset hook context, but store current values
    arg_types, kwarg_types, ret_type = @arg_types, @kwarg_types, @ret_type
    @arg_types, @kwarg_types, @ret_type = nil, nil, nil

    # capture the original method
    meth = instance_method(name)

    # wrap the original method with type checks
    define_method(name) do |*args, **kwargs, &block|
      Helpers::call_checked(
        meth.bind(self), args, kwargs, arg_types, kwarg_types, ret_type, block)
    end
  end
end

#
# This is how check_types is implemented:
#

module Types::Helpers
  def self.call_checked(meth, args, kwargs, arg_types, kwarg_types, ret_type, block)
    # check positional arguments
    arg_types.each_with_index do |type, idx|
      raise "Invalid type for arg in pos #{idx}; expected: #{arg_types[idx]}" \
        unless args[idx].is_a? type
    end

    # check keyword arguments
    kwarg_types.each do |key, type|
      raise "Invalid type for kwarg '#{key}`; expected #{kwarg_types[key]}" \
        unless kwargs[key].is_a? type
    end

    # call method and check return type
    ret = meth.call(*args, &block)
    raise "Invalid return type, expected #{ret.name}" \
      unless ret.is_a? ret_type
    ret
  end
end

#
# Now we can re-implement the Repeater class by extending the Types module:
#

class Repeater4
  extend Types

  typedef { params(String, Numeric, separator: String).returns(String) }
  def repeat(str, count, separator: '')
    Array.new(count, str).join(separator)
  end
end

#
# If we run the same snippet as above:
#

puts "\nExample 4a:"
puts Repeater4.new.repeat("test", 3, separator: ", ")

#
# We should simply see the output of the `repeat` method.
#
# However, if we supply the wrong types...
#

puts "\nExample 4b:"
begin
  puts Repeater4.new.repeat("test", "3", separator: ", ")
rescue StandardError => e
  # Expected to fail with: Invalid type for arg in pos 1; expected: Numeric
  puts "Error: #{e}"
end

#
# We will get an appropriate type error:
#
#   Error: Invalid type for arg in pos 1; expected: Numeric
#
