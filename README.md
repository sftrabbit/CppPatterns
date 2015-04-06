# C++ Samples

[C++ Samples](http://cppsamples.com) is a repository of code samples
illustrating a modern
and idiomatic approach to writing C++. The aim is to provide
beginner to intermediate C++ developers a reference for solving common
problems in C++. As the C++ language and library evolve, which they
have been doing rapidly since the release of C++11, these samples
will be updated to match the current state-of-the-art in idiomatic C++
development.

This repository contains the source for the web front-end, providing a
simple web interface for browsing the samples. It is a static website
built with [Jekyll](http://jekyllrb.com/) and uses custom Jekyll
plugins to generate the sample pages from their source.

## Contributing

If you wish to contribute to the front-end itself, please fork this
repository on GitHub. If you'd like to provide some samples or edit
existing samples, please take a look at the
[samples repository](https://github.com/sftrabbit/CppSamples-Samples).

## Samples

Sample pages are generated from a collection of `.cpp` files. These
files are kept in a separate repository, namely
[sftrabbit/CppSamples-Samples](https://github.com/sftrabbit/CppSamples-Samples).
To build this website, you will need to clone this repository into
the `_samples` subdirectory:

    $ git clone https://github.com/sftrabbit/CppSamples-Samples.git _samples

## Build

After cloning the sample sources into `_samples`, the site can be
built with:

    $ jekyll build

The site will be built to the `_site` directory.
