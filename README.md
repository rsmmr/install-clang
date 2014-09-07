install-clang
=============

This script installs self-contained standalone versions of [clang][1],
[LLVM][2], [libc++][3], and [compiler-rt][4] on Darwin and Linux,
including linking clang and LLVM themselves against libc++ as well. The
script keeps all of the installation within a given target prefix (e.g.,
`/opt/llvm`), and hence separate from any already installed compilers,
libraries, and include files. In particular, you can later deinstall
everything easily by just deleting, e.g., `/opt/llvm`. Furthermore, as
long as the prefix path is writable, the installation doesn't need root
privileges.

If you have used older version of the script before, see News below
for changes.

Usage
-----

To see the available options, use `-h`:

    > ./install-clang -h
    Usage: install-clang [<options>] <install-prefix>

    Available options:
        -A         enables assertions in LLVM libraries
        -b         build type (Release, Debug, RelWithDebInfo) [default: RelWithDebInfo]
        -c         skip cloning repositories, assume they are in place
        -h|-?      display this help
        -j <n>     build with <n> threads in parallel [default: 1]
        -m         use git/master instead of preconfigured versions
        -s <stage> begin build from <stage> [1, 2]
        -u         update an existing build in <prefix> instead of installing new

    Environment variables:
        CC         path to the C compiler for bootstrapping
        CXX        path to the C++ compiler for bootstrapping

For example, to build Clang on a machine with multiple cores and
install it in `/opt/llvm`, you can use:

    > ./install-clang -j 16 /opt/llvm

Once finished, just prefix your PATH with `<prefix>/bin` and you're
ready to use the new binaries:

    > clang++ --std=c++11 --stdlib=libc++ test.cc -o a.out && ./a.out
    Hello, Clang!

By default, install-clang currently installs the 3.5 release branches
of the relevant llvm.org projects. Adding `-m` on the command line
instructs the script to use the current git master versions instead.
The script downloads all the sources from the corresponding git
repositories and compiles the pieces as needed. Other OSs than Darwin
and Linux are not currently supported.

The script also has an update option `-u` that allows for catching up
with upstream repository changes without doing the complete
compile/install-from-scratch cycle again. Note, however, that unless
coupled with `-m`, this flag has no immediate effect since the git
versions to use are hardcoded to the LLVM/clang release versions.

Doing a self-contained clang/LLVM installation is a bit more messy
than one would hope because the projects make assumptions about
specific system-wide installation paths to use. The install-clang
script captures some trial-and-error I (and others) went through to
get an independent setup working. Specifically, it compiles clang/LLVM
twice, once to boostrap with the system compiler and then again with
itself linking against the new libraries. It also patches some of the
LLVM projects to incorporate the installation prefix into
configuration and search paths, and also fixes/tweak a few other
things as well.

News
----

The install-clang script for LLVM 3.5 comes with a few changes
compared to earlier version:

* The script now generally shared libraries for LLVM and clang, rather
  than static ones.

* As libc++abi now works well on Linux as well, we use it generally
  and no longer support libcxxrt.

* There's no 3rd phase anymore building assertion-enabled LLVM
  libraries, as changing compilation options isn't useful with shared
  libraries.

* There are now command line options to select build mode and
  assertions explicitly.

[1]: http://clang.llvm.org
[2]: http://www.llvm.org
[3]: http://libcxx.llvm.org
[4]: http://compiler-rt.llvm.org
[5]: http://libcxxabi.llvm.org
