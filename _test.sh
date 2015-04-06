#!/usr/bin/env sh

find _samples/ -iname '*.cpp' -print0 | xargs -0 -I "{}" clang++-3.5 -std=c++1y -stdlib=libc++ {}
rm a.out
