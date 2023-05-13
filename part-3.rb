#!/usr/bin/env ruby

#
# Ruby Type Checking - Part 3
# ===========================
#
# Breaking Sorbet
# ---------------
#
# I'll preface this by saying that it's not really fair to target Sorbet for
# this, because it is a limitation of runtime type checking that is due to
# decisions made when the Ruby's optional parameter types were designed.
#
# Specifically, default values for optional parameters are evaluated at the
# time that a method is called, NOT at the time that the method is defined.
# This is in constrast to Python, in which default values are evaluated at the
# time that a method is defined. This is demonstrated in part-3.py, which
# also shows how this behaviour can be quite surprising...
#
# To see how this affects type checking in Ruby, check out the following
# example:
#

require 'sorbet-runtime'

class Main
  extend T::Sig

  sig do
    params(kw: String).void
  end
  def self.main(kw = Time.now)
    puts "kw: #{kw}"
    puts "kw.is_a?(String): #{kw.is_a?(String)}"
  end
end

#
# First we'll try calling the `main` method with an invalid argument:
#

begin
  Main.main(123)
rescue StandardError => e
  puts "Error: #{e}"
end

#
# This will fail as expected:
#
#   Error: Parameter 'kw': Expected type String, got type Integer with value 123
#   Caller: ./part-3.rb:36
#   Definition: ./part-3.rb:29
#
# But what if we call it without an argument, relying instead on the default
# value?
#

loop do
  Main.main
  sleep 1
end

#
# The type check is satisfied!
#
#   kw: 2023-05-13 09:49:07 +1000
#   kw.is_a?(String): false
#   kw: 2023-05-13 09:49:08 +1000
#   kw.is_a?(String): false
#   kw: 2023-05-13 09:49:09 +1000
#   kw.is_a?(String): false
#
# This is because the Ruby interpreter evaluates the expression for the
# default value just before the method is called. However, our runtime hooks
# can only _wrap_ a method with additional code. They don't inject code _into_
# the method, and so never get to inspect the default value.
#