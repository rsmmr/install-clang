#! /usr/bin/env bash
#
# TODO:
#    - Try adding lldb once again.

OS=`uname`
if [ "$OS" == "Linux" ]; then
    triple=""
    soext="so"
    somask="so.%s"
    addl_ldflags="-ldl"
    addl_cmake=""

elif [ "$OS" == "FreeBSD" ]; then
    triple=""
    soext="so"
    somask="so.%s"
    addl_ldflags=""
    addl_cmake=""

elif [ "$OS" == "Darwin" ]; then
    triple="-apple-"
    soext="dylib"
    somask="%d.dylib"
    addl_ldflags=""
    addl_cmake="-DCMAKE_OSX_ARCHITECTURES=x86_64;i386"

else
    echo "OS $OS not supported by this script."
    exit 1
fi

if [ -n "$CC" ]; then
    cc=$CC
elif which clang > /dev/null 2>&1; then
    cc=clang
elif which gcc > /dev/null 2>&1; then
    cc=gcc
else
    echo could not find clang or gcc in '$PATH'
    exit 1
fi

if [ -n "$CXX" ]; then
    cxx=$CXX
elif which clang++ > /dev/null 2>&1; then
    cxx=clang++
elif which g++ > /dev/null 2>&1; then
    cxx=g++
else
    echo could not find clang++ or g++ in '$PATH'
    exit 1
fi

use_master=0
perform_clone=1            # If 0, skip the cloning (for testing only).
perform_stage1=1           # If 0, skip the 1st bootstrap stage (for testing only).
perform_stage2=1           # If 0, skip the 2nd stage compiling LLVM/clang against libc++ (for testing only).
perform_lldb_build=0       # If 1, attempt to build LLDB.
perform_lld_build=0        # If 1, attempt to build LLDB.
perform_extra_build=1      # If 1, attempt to build clang-extra tools.
perform_cleanup=0          # If 1, delete all source and build directories.
assertions=off             # If "on", enable LLVM assertions.
parallelism=1              # The value X to pass to make -j X to build in parallel.
buildtype=RelWithDebInfo   # LLVM/clang build type.
mode=install               # Install from scratch.
targets=host               # LLVM_TARGETS_TO_BUILD ("all" builds them all).

if eval ${cxx} --version | grep -q clang; then
    perform_stage0=0
    have_clang=1
else
    perform_stage0=1
    have_clang=0
fi

usage()
{
    printf "Usage: %s [<options>] <install-prefix>\n" $(basename $0)
    echo ""
    echo "Available options:"
    echo "    -A         enables assertions in LLVM libraries"
    echo "    -b         build type (Release, Debug, RelWithDebInfo) [default: ${buildtype}]"
    echo "    -c         skip cloning repositories, assume they are in place"
    echo "    -C         clean up after build by deleting the LLVM/clang source/build directories"
    echo "    -h|-?      display this help"
    echo "    -j <n>     build with <n> threads in parallel [default: ${parallelism}]"
    echo "    -m         use git/master instead of preconfigured versions"
    echo "    -s <stage> begin build from <stage> [0, 1, 2]"
    echo "    -u         update an existing build in <prefix> instead of installing new"
    echo ""
    echo "Environment variables:"
    echo "    CC         path to the C compiler for bootstrapping"
    echo "    CXX        path to the C++ compiler for bootstrapping"
}

while getopts "Ab::j:lms:ucCh?" opt ; do
    case "$opt" in
        c)
            perform_clone=0
            ;;
        C)
            perform_cleanup=1
            ;;
        h|\?)
            usage
            exit 0
            ;;
        j)
            parallelism=$OPTARG
            ;;
        m)
            use_master=1
            ;;
        s)
            if [ "$OPTARG" == "0" ]; then
                perform_stage0=1
                perform_stage1=1
                perform_stage2=1
            elif [ "$OPTARG" == "1" ]; then
                perform_stage0=0
                perform_stage1=1
                perform_stage2=1
            elif [ "$OPTARG" == "2" ]; then
                perform_stage0=0
                perform_stage1=0
                perform_stage2=1
            else
                echo 'stage parameter must be in [0,1,2].'
                exit 1
            fi
            ;;
        u)
            mode=update
            ;;

        A)
            assertions=on
            ;;

        b)
            buildtype=$OPTARG
            ;;

    esac
done

shift $(expr $OPTIND - 1)
prefix=`echo $1 | sed 's#/$##'`
shift

if [ "${use_master}" != "1" ]; then
    # git version to checkout.
    version_llvm=release_35
    version_clang=release_35
    version_libcxx=release_35
    version_compilerrt=release_35
    version_libcxxabi=239a032       # No 3.5 branch. Hardcoding.
    version_lldb=master             # No 3.5 branch. Probably won't work.
    version_lld=master              # No 3.5 branch. Probably won't work.
    version_extra=release_35

    cherrypick="projects/libcxx 0c6d1a88 e515bbda f2e8c0454"  # Fix linking against in-tree libc++abi.
    cherrypick="$cherrypick;/ 168d0c143"  # Correctly add libc++abi to project list.
    cherrypick="$cherrypick;/ d9aaca0ec"  # Fix libc++abi build on FreeBSD.

else
    # git version to checkout.
    version_llvm=master
    version_clang=master
    version_libcxx=master
    version_compilerrt=master
    version_libcxxabi=master
    version_lldb=master
    version_lld=master
    version_extra=master
fi

if [ "$mode" == "" -o "$prefix" == "" ]; then
    usage
    exit 1
fi

if [ ! -d $prefix ]; then
    if [ "$mode" == "install" ]; then
        if ! mkdir -p $prefix; then
            echo failed to create directory $prefix
            exit 1
        fi
    else
        echo $prefix does not exist
        exit 1
    fi
fi

#### Copy all output to log file.
log=install.$$.log
echo "Recording log in $log ..."
exec > >(tee $log) # Requires fdescfs mounted to /dev/fd on FreeBSD.
exec 2>&1

#### Set paths and environment.

unset CFLAGS
unset CXXFLAGS
unset CPPFLAGS
unset LDFLAGS
unset LD_LIBRARY_PATH
unset DYLD_LIBRARY_PATH

# Built libraries with RTTI.
export REQUIRES_RTTI=1
export PATH=$prefix/bin:$PATH

src="$prefix/src/llvm"
src_libcxxabi=${src}/projects/libcxxabi
src_libcxx=${src}/projects/libcxx
src_compilerrt=${src}/projects/compiler-rt
src_lldb=${src}/lldb
src_lld=${src}/lld
libcxx_include=$prefix/include/c++/v1
libcxx_lib=$prefix/lib
default_includes=${libcxx_include}:/usr/include

mkdir -p $libcxx_include

function st
{
    eval echo \$\{$1_stage${stage}\}
}

function add_include_path
{
    include=$1
    search_patch=$2

    path=`find "${search_patch}" | grep "${include}$" | awk '{print length, $0;}' | sort -n | head -1 | awk '{printf("%s", $2)}'`

    if [ "$path" != "" ]; then
        path=`echo -n ${path} | sed "s#${include}##g"`
        if [ "${default_includes}" = "" ]; then
            echo -n "${path}"
        else
            echo -n "${default_includes}:${path}"
        fi
    fi
}

function apply_patch
{
    patch=$1
    base=`basename $patch`

    cwd=`pwd`

    cd $src

    if basename "$patch" | grep -q -- '--'; then
        dir=`echo $base | awk -v src=$src -F '--' '{printf("%s/%s/%s", src, $1, $2);}'`
        if [ ! -d "$dir" ]; then
            return
        fi

        cd $dir
    fi

    cat $patch | git am -3
}

#### Clone reposistories.

export GIT_COMMITTER_EMAIL="`whoami`@localhost"
export GIT_COMMITTER_NAME="`whoami`"

d=`dirname $0`
patches=`cd $d; pwd`/patches

if [ "${perform_clone}" == "1" ]; then

    # Get/update the repositories.
    if [ "$mode" == "install" ]; then

        test -d $src && echo "$src already exists, aborting" && exit 1
        mkdir -p $src

        echo Changing directory to `dirname $src` for installing  ...
        cd `dirname $src`

        git clone http://llvm.org/git/llvm.git `basename $src`

        ( cd $src/tools && git clone http://llvm.org/git/clang.git )
        ( cd $src/projects && git clone http://llvm.org/git/libcxx )
        ( cd $src/projects && git clone http://llvm.org/git/compiler-rt )

        ( cd $src && git checkout -q ${version_llvm} )
        ( cd $src/tools/clang && git checkout -q ${version_clang}  )
        ( cd ${src_libcxx} && git checkout -q ${version_libcxx} )
        ( cd ${src_compilerrt} && git checkout -q ${version_compilerrt} )

        ( cd $src/projects && git clone http://llvm.org/git/libcxxabi )
        ( cd ${src_libcxxabi} && git checkout -q ${version_libcxxabi} )

        if [ "${perform_extra_build}" == "1" ]; then
            ( cd $src/tools && git clone http://llvm.org/git/clang-tools-extra.git extra )
            ( cd $src/tools/extra && git checkout -q ${version_extra} )
        fi

        if [ "${perform_lldb_build}" == "1" ]; then
            ( cd `dirname ${src_lldb}` && git clone http://llvm.org/git/lldb `basename ${src_lldb}`)
            ( cd ${src_lldb} && git checkout -q ${version_lldb}  )
        fi

        if [ "${perform_lld_build}" == "1" ]; then
            ( cd `dirname ${src_lld}` && git clone http://llvm.org/git/lld `basename ${src_lld}`)
            ( cd ${src_lld} && git checkout -q ${version_lld}  )
        fi

    else
        echo Changing directory to `dirname $src` for updating ...
        cd `dirname $src`

        ( cd ${src} && git pull --rebase )
        ( cd ${src}/tools/clang && git pull --rebase )
        ( cd ${src_libcxx} && git pull --rebase )
        ( cd ${src_compilerrt} && git pull --rebase )

        ( cd $src && git checkout -q ${version_llvm} )
        ( cd $src/tools/clang && git checkout -q ${version_clang}  )
        ( cd ${src_libcxx} && git checkout -q ${version_libcxx} )
        ( cd ${src_compilerrt} && git checkout -q ${version_compilerrt} )

        ( cd ${src_libcxxabi} && git pull --rebase )
        ( cd ${src_libcxxabi} && git checkout -q ${version_libcxxabi} )

        if [ "${perform_extra_build}" == "1" ]; then
            ( cd $src/tools/extra && git pull --rebase )
            ( cd $src/tools/extra && git checkout -q ${version_extra} )
        fi

        if [ "${perform_lldb_build}" == "1" ]; then
            ( cd ${src_lldb} && git pull --rebase )
            ( cd ${src_lldb} && git checkout -q ${version_lldb}  )
        fi

        if [ "${perform_lld_build}" == "1" ]; then
            ( cd ${src_lld} && git pull --rebase )
            ( cd ${src_lld} && git checkout -q ${version_lld}  )
        fi
    fi

    # Cherry pick additional commits from master.
    echo "${cherrypick}" | awk -v RS=\; '{print}' | while read line; do
        if [ "$line" != "" ]; then
            repo=`echo $line | cut -d ' ' -f 1`
            commits=`echo $line | cut -d ' ' -f 2-`
            echo "Cherry-picking $commits in $repo"
            ( cd ${src}/$repo \
              && git cherry-pick --strategy=recursive -X theirs $commits )
        fi
    done

    # Apply any patches we might need.
    for i in $patches/*; do
        apply_patch $i
    done

    echo === Done applying patches

fi

if [ "$OS" == "Darwin" ]; then
    CMAKE_stage1="-DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++"

elif [ "$OS" == "Linux" ] || [ "$OS" == "FreeBSD" ]; then
    CMAKE_stage1="-DLIBCXX_LIBCXXABI_WHOLE_ARCHIVE=on -DLIBCXXABI_ENABLE_SHARED=off -DBUILD_SHARED_LIBS=on"
    CMAKE_stage2=$CMAKE_stage1
    CMAKE_stage3=$CMAKE_stage1

    default_includes=`add_include_path features.h /usr/include`
    default_includes=`add_include_path sys/cdefs.h /usr/include`

else
    echo "OS $OS not supported"
    exit 1
fi

CMAKE_common="-DBUILD_SHARED_LIBS=on -DLLVM_TARGETS_TO_BUILD=${targets}"
CMAKE_stage0="${CMAKE_common} ${CMAKE_stage0} -DLLVM_INCLUDE_TOOLS=bootstrap-only  -DLLVM_EXTERNAL_LIBCXX_BUILD=off -DLLVM_EXTERNAL_LIBCXXABI_BUILD=off -DLLVM_EXTERNAL_COMPILER_RT_BUILD=off"
CMAKE_stage1="${CMAKE_common} ${CMAKE_stage1} -DLLVM_INCLUDE_TOOLS=bootstrap-only -DLLVM_ENABLE_ASSERTIONS=${assertions} -DLLVM_EXTERNAL_LIBCXXABI_BUILD=on"
CMAKE_stage2="${CMAKE_common} ${CMAKE_stage2} -DLLVM_ENABLE_ASSERTIONS=${assertions}"

#### Configure the stages.

# Stage 0 options. Get us a clang.

CC_stage0="$cc"
CXX_stage0="$cxx"
CXXFLAGS_stage0=""
CMAKE_stage0="${CMAKE_stage0}"
BUILD_TYPE_stage0=${buildtype}

# Stage 1 options. Compile against standard libraries.

if [ "${have_clang}" == "1" ]; then
    CC_stage1="$cc"
    CXX_stage1="$cxx"
else
    CC_stage1=$prefix/bin/clang
    CXX_stage1=$prefix/bin/clang++
fi

CXXFLAGS_stage1=""
BUILD_TYPE_stage1=${buildtype}

# Stage 2 options. Compile against our own libraries.

CC_stage2=$prefix/bin/clang
CXX_stage2=$prefix/bin/clang++
CFLAGS_stage2="-stdlib=libc++"
CXXFLAGS_stage2="-stdlib=libc++"
CMAKE_stage2="${CMAKE_stage2}"
BUILD_TYPE_stage2=${buildtype}

#### Compile the stages.

echo Changing directory to $src ...
cd $src

for stage in 0 1 2; do
     if [ "`st perform`" == "0" ]; then
         continue
     fi

     echo ===
     echo === Building LLVM/clang, stage ${stage} ...
     echo ===

     ( cd $src &&\
       mkdir -p build-stage${stage} && \
       cd build-stage${stage} && \
       CC=`st CC` \
       CXX=`st CXX` \
       CFLAGS="`st CFLAGS`" \
       CXXFLAGS="`st CXXFLAGS`" \
       LDFLAGS="${addl_ldflags}" \
       cmake -DCMAKE_BUILD_TYPE=`st BUILD_TYPE` \
             -DLLVM_REQUIRES_RTTI=1 \
             -DCMAKE_INSTALL_PREFIX=${prefix} \
             -DC_INCLUDE_DIRS=${default_includes} \
             ${addl_cmake} \
             `st CMAKE` \
             .. && \
       make -j $parallelism && \
       make install \
     )

    if [ "$?" != "0" ] ; then
        echo ===
        echo === Failed building LLVM/clang at stage ${stage}
        echo ===
        exit 1
    fi
done

if [ "${perform_cleanup}" == "1" ]; then
    echo Deleting $src ...
    rm -rf "${src}"
fi

echo "===="
echo "==== Complete log in $log"
echo "===="
