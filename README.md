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

Usage
-----

    > ./install-clang --install <prefix>

Once finished, just prefix your PATH with `<prefix>/bin` and you're
ready to use the new binaries:

    > clang++ --std=c++11 --stdlib=libc++ test.cc -o a.out && ./a.out
    Hello, Clang!

By default, install-clang currently installs the 3.4 (git) branches of the
relevant llvm.org projects; the versions can be changed by editing the
definitions at the beginning of the script. The installation process
downloads all the sources directly from their corresponding master git
repositories and then compiles the pieces as needed. Other OSs than
Darwin and Linux are not currently supported.

Doing a self-contained clang/LLVM installation is a bit more messy
than one would hope because the projects make assumptions about
specific system-wide installation paths to use. The install-clang
script captures some trial-and-error I went through to get an
independent setup working. Specifically:

    - It compiles clang/LLVM twice, once to boostrap with the system
      compiler and then again with itself linking against the new
      libraries. (By default, it indeed compiles LLVM a third time
      with assertions enabled and debug information included. In the
      end, the installed LLVM libraries have assertions enabled, while
      the clang binary has not. The 3rd stage can be disabled at the
      beginning of the script.)

    - It uses [libabi++][5] on Darwin, and pathscale's [libcxxrt][6] on
      Linux.

    - It patches clang to search libc++ headers relative to the
      installation prefix.

    - It patches the build script for libc++abi to accept a prefix
      specification.

**Note**: the script also has an `--update` option that's allows to
catch up with upstream repository changes without doing the complete
2-stage compile/install cycle again. However, that option hasn't been
tried recently and might be broken. By default it also has no immediate
effect since the git versions to use are hardcoded to the LLVM/clang
release versions. If you want to try `--update`, change the versions at
the beginning of the script to "master" (but again, update mode may just
be broken right now).

[1]: http://clang.llvm.org
[2]: http://www.llvm.org
[3]: http://libcxx.llvm.org
[4]: http://compiler-rt.llvm.org
[5]: http://libcxxabi.llvm.org
[6]: https://github.com/pathscale/libcxxrt
