# C++ Patterns

[C++ Patterns](https://cpppatterns.com) is a repository of code patterns
illustrating a modern
and idiomatic approach to writing C++. The aim is to provide
beginner to intermediate C++ developers a reference for solving common
problems in C++. As the C++ language and library evolve, which they
have been doing rapidly since the release of C++11, these patterns
will be updated to match the current state-of-the-art in idiomatic C++
development.

This repository contains the source for the web front-end, providing a
simple web interface for browsing the patterns. It is a static website
built with [Jekyll](http://jekyllrb.com/) and uses custom Jekyll
plugins to generate the pattern pages from their source.

## Contributing

If you wish to contribute to the front-end itself, please fork this
repository on GitHub. If you'd like to provide some patterns or edit
existing patterns, please take a look at the
[patterns repository](https://github.com/sftrabbit/CppPatterns-Patterns).

## Patterns

Pattern pages are generated from a collection of `.cpp` files. These
files are kept in a separate repository, namely
[sftrabbit/CppPatterns-Patterns](https://github.com/sftrabbit/CppPatterns-Patterns).
To build this website, you will need to clone this repository into
the `_samples` subdirectory:

    $ git clone https://github.com/sftrabbit/CppPatterns-Patterns.git _samples

## Build

After cloning the pattern sources into `_samples`, the site can be
built with:

    $ jekyll build

The site will be built to the `_site` directory.
