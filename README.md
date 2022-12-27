# Ruby Type-Checking

This repo contains some experimental code that I've written while learning about type-checking in Ruby. The aim of these experiments was to better understand how [Sorbet](https://sorbet.org) works under-the-hood.

These have been written up as posts on my blog:
* [Roll Your Own Ruby Type Checking: Part 1](https://tristanpenman.com/blog/posts/2022/12/26/roll-your-own-ruby-type-checking-part-1/)
* [Roll Your Own Ruby Type Checking: Part 2](https://tristanpenman.com/blog/posts/2022/12/31/roll-your-own-ruby-type-checking-part-2/)

The code examples here roughly follow the structure of the posts.

## Part 1

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

## Part 2

The code for part 2 can be found in [part-2.rb](part-2.rb). This code addresses some of the limitations of the type-checking implementation in part 1, while also making it more robust.

This code can be run from the command line with no arguments:

    ruby part-2.rb

## Breaking Sorbet

While experimenting with my own Ruby Type Checking implementation, I found that there were some fundamental limitations on how runtime type checking can be implemented in Ruby. These cases have been tested against Sorbet in [breaking-sorbet.rb](breaking-sorbet.rb).

## License

These examples are in the public domain.
