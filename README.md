# Ruby Type-Checking

Experiments in Ruby type-checking.

## Background

This repo contains some experimental code that I've written while learning about type-checking in Ruby. The aim of these experiments was to better understand how [Sorbet](https://sorbet.org) works under-the-hood.

So far, all of my experimental code can be found in [experiments.rb](experiments.rb). This can be run from the command line:

    ruby experiments.rb

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

## Interested in more?

I'm currently writing a blog post on this topic, and will include a link here once it is published. _Watch this space._

## License

These examples are in the public domain.
