#!/usr/bin/python3

def arr():
  return [1,2,3]

def test(a = arr()):
  a.append(4)
  print(a)

test()
test([8,9,10])
test()

#
# If we didn't know that Python evaluates default values at the time that a
# method is defined, we might expect this to be the output:
#
#   [1, 2, 3, 4]
#   [8, 9, 10, 4]
#   [1, 2, 3, 4]
#
# But instead we get this:
#
#   [1, 2, 3, 4]
#   [8, 9, 10, 4]
#   [1, 2, 3, 4, 4]
#
# Which shows that:
#
#   1. The array has been passed to the method body by-reference.
#   2. The arr() method is only called once, at the time that the `test` method
#      was defined.
#