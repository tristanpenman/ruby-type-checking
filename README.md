# Ruby Type Checking

This repo contains some experimental code that I've written while learning about type checking in Ruby. The aim of these experiments has been to better understand Ruby, and to reason about how runtime type checking works in [Sorbet](https://sorbet.org).

My findings have been written up as a series of posts, _Roll Your Own Ruby Type Checking_, on my blog:
* [Part 1](https://tristanpenman.com/blog/posts/2022/12/26/roll-your-own-ruby-type-checking-part-1/)
* [Part 2](https://tristanpenman.com/blog/posts/2023/05/13/roll-your-own-ruby-type-checking-part-2/)
* [Part 3](https://tristanpenman.com/blog/posts/2023/05/20/roll-your-own-ruby-type-checking-part-3/)

The code examples here roughly follow the structure of these posts.

## Part 1 - Annotations, Hooks and Type Checking

The code for part 1 can be found in [part-1.rb](part-1.rb). This code demonstrates a technique for implementing method annotations in Ruby, allowing a method to be annotated with hooks that are run before and after the method body. This is then adapted for type-checking.

This code can be run from the command line with no arguments:

    ruby part-1.rb

Current output is expected to look like this:

    Example 1:
    test, test, test

    Example 2:
    before: ["test", 3], {:separator=>", "}
    after: test, test, test
    test, test, test

    Example 3:
    before: ["test", 3], {:separator=>", "}
    after: test, test, test
    test, test, test

    Example 4:
    testtesttest

    Error: Invalid type for arg 1; expected: Numeric

## Part 2 - Optional and Additional Parameters

The code for part 2 can be found in [part-2.rb](part-2.rb). This code addresses some of the limitations of the type checker implemented in part 1, while also making it more robust.

This code can be run from the command line with no arguments:

    ruby part-2.rb

There are quite a few examples in part 2. The beginning of the output should look like this:

    Example 1a:
    [:req, :a]
    [:opt, :b]
    [:rest, :c]
    [:keyreq, :d]
    [:key, :e]
    [:keyrest, :f]

    Example 1b:
    [:req, :a]
    [:opt, :b]
    [:rest, :c]
    [:keyreq, :d]
    [:key, :e]
    [:keyrest, :f]

    Example 2a:
    ["a", 1]
    ["b", 2]
    ["c", [3, 4]]
    ["d", 5]
    ["e", 6]
    ["f", {:f=>7, :g=>8}]

    ... SNIP! ...

## Part 3 - Breaking Sorbet

While experimenting with my own type checker, I found that there were some fundamental limitations on how runtime type checking can be performed in Ruby. Specifically, it's not possible to verify the types for parameters with default arguments, when those arguments are omitted.

This has been demonstrated using Sorbet in [part-3.rb](part-3.rb). You'll need to install the `sorbet-runtime` gem to run this code.

To illustrate how this differs from Python, [part-3.py](part-3.py) has also been included. This highlights the fact that, no matter which approach you choose, you end up with surprising behaviour.

## License

These examples are in the public domain.
