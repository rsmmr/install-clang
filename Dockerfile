FROM        ubuntu:xenial
MAINTAINER  Robin Sommer <robin@icir.org>

# Setup environment.
ENV PATH /opt/clang/bin:$PATH

# Default command on startup.
CMD bash

# Setup packages.
RUN apt-get update && apt-get -y install cmake git build-essential vim python libncurses5-dev libedit-dev libpthread-stubs0-dev

# Copy install-clang over.
ADD . /opt/install-clang

# Compile and install Clang/LLVM. We delete the source directory to
# avoid committing it to the image.
RUN /opt/install-clang/install-clang -j 6 -C /opt/clang

